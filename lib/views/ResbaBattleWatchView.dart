// ignore_for_file: file_names, use_build_context_synchronously
import 'dart:async';
import 'dart:developer';

import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/modes/debate_scores.dart';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/floating_spectator_comments.dart';
import 'package:debate_project/widgets/radar_chart_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// レスバの観戦画面
/// - 挑戦者（応募者/player2）視点の GamePage と全く同じUIでリアルタイムに観戦
/// - 左上の選択肢アイコンをタップすると両者の選択肢（ホスト / 挑戦者）を確認可能
/// - タイマーは対戦側と完全に同期（サーバー時刻オフセット ＆ 選択確定後のupdated_atを基準に計算）
/// - 判定中はロボットアイコンが点滅して判定中オーバーレイを表示（対戦側と完全同期）
/// - 試合終了後は画面遷移なしで FinishPage と同様のレーダーチャート＆勝敗理由付きリザルト画面を表示
class ResbaBattleWatchView extends ConsumerStatefulWidget {
  final ResbaInvite invite;

  const ResbaBattleWatchView({super.key, required this.invite});

  @override
  ConsumerState<ResbaBattleWatchView> createState() =>
      _ResbaBattleWatchViewState();
}

class _ResbaBattleWatchViewState extends ConsumerState<ResbaBattleWatchView>
    with SingleTickerProviderStateMixin {
  static const int _matchDurationSeconds = 600;
  static const String _prefMuteKey = 'spectator_comments_muted';

  SupabaseClient get supabase => ref.read(supabaseProvider);

  MatchingRoom? _room;
  final Map<String, Users> _players = {};
  List<Chat> _messages = []; // 新しい順（index 0 が最新）
  String? _error;
  DateTime? _deadline;
  Duration? _timeOffset;
  Timer? _countdownTimer;

  RealtimeChannel? _roomChannel;
  RealtimeChannel? _spectatorBroadcastChannel;
  StreamSubscription<dynamic>? _messagesSub;

  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<FloatingSpectatorCommentsOverlayState> _overlayKey =
      GlobalKey<FloatingSpectatorCommentsOverlayState>();

  late AnimationController _robotAnimationController;

  bool _isCommentMuted = false;
  bool _isSendingComment = false;
  bool _showFullChoice = false;

  @override
  void initState() {
    super.initState();
    _robotAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadMutePreference();
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _robotAnimationController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    if (_roomChannel != null) supabase.removeChannel(_roomChannel!);
    if (_spectatorBroadcastChannel != null) {
      supabase.removeChannel(_spectatorBroadcastChannel!);
    }
    _messagesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMutePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isCommentMuted = prefs.getBool(_prefMuteKey) ?? false;
      });
    }
  }

  Future<void> _toggleMute() async {
    final nextMute = !_isCommentMuted;
    setState(() {
      _isCommentMuted = nextMute;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefMuteKey, nextMute);
  }

  Future<DateTime> _getServerTime() async {
    final response = await supabase.rpc('get_server_time');
    return DateTime.parse(response);
  }

  Future<void> _fetchServerTimeOffset() async {
    try {
      final serverTime = await _getServerTime();
      _timeOffset = serverTime.difference(DateTime.now());
    } catch (e) {
      log('サーバー時刻取得エラー: $e');
      _timeOffset = Duration.zero;
    }
  }

  bool get _isBattleStarted {
    final room = _room;
    if (room == null) return false;
    return room.player1Choice != null &&
        room.player2Choice != null &&
        room.player1Choice != room.player2Choice;
  }

  /// 判定中（判定待ち）かどうか
  bool get _isEvaluating {
    final room = _room;
    if (room == null) return false;
    if (room.winner != null) return false; // 勝敗確定後は判定中ではない
    if (!_isBattleStarted) return false; // 試合前は判定中ではない

    // 制限時間切れ、または両プレイヤーが判定に進むを選択している場合
    final isTimeUp = _remainingSeconds == 0;
    final isBothFinished =
        room.player1_finish == true && room.player2_finish == true;
    return isTimeUp || isBothFinished;
  }

  void _checkRobotAnimation() {
    if (_isEvaluating) {
      if (!_robotAnimationController.isAnimating) {
        _robotAnimationController.repeat(reverse: true);
      }
    } else {
      if (_robotAnimationController.isAnimating) {
        _robotAnimationController.stop();
      }
    }
  }

  void _updateDeadline(MatchingRoom room) {
    final isStarted = room.player1Choice != null &&
        room.player2Choice != null &&
        room.player1Choice != room.player2Choice;
    if (isStarted && room.updatedAt != null) {
      _deadline = room.updatedAt!.add(
        const Duration(seconds: _matchDurationSeconds + 2),
      );
    } else {
      _deadline = null;
    }
  }

  Future<void> _load() async {
    final roomId = widget.invite.battleRoomId;
    if (roomId == null) {
      setState(() => _error = 'この対戦のログは保存されていません');
      return;
    }
    try {
      await _fetchServerTimeOffset();

      final roomData = await supabase
          .from('rooms_v2')
          .select()
          .eq('id', roomId)
          .maybeSingle();
      if (roomData == null) {
        setState(() => _error = 'この対戦のデータが見つかりませんでした');
        return;
      }
      final room = MatchingRoom.fromMap(roomData);
      if (!mounted) return;
      setState(() {
        _room = room;
        _updateDeadline(room);
      });
      _checkRobotAnimation();
      await _fetchPlayers(room);
      if (!mounted) return;
      _subscribeRoom(roomId);
      _subscribeMessages(roomId);
      _subscribeSpectatorBroadcast(roomId);
      _startCountdown();
    } catch (e) {
      log('観戦データの取得に失敗: $e');
      if (mounted) setState(() => _error = '観戦データの取得に失敗しました');
    }
  }

  Future<void> _fetchPlayers(MatchingRoom room) async {
    final ids = <String>[
      if (room.player1Id != null) room.player1Id!,
      if (room.player2Id != null) room.player2Id!,
    ];
    if (ids.isEmpty) return;
    try {
      final rows = await supabase
          .from('users')
          .select('id, name, avatar_url, trophy')
          .inFilter('id', ids);
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          final id = r['id']?.toString();
          if (id == null) continue;
          _players[id] = Users.fromMap(r);
        }
      });
    } catch (e) {
      log('プレイヤー情報の取得に失敗: $e');
    }
  }

  void _subscribeRoom(String roomId) {
    _roomChannel = supabase
        .channel('watch-room-$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rooms_v2',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newRoom = MatchingRoom.fromMap(payload.newRecord);
            setState(() {
              if (_room?.updatedAt != newRoom.updatedAt || _deadline == null) {
                _updateDeadline(newRoom);
              }
              _room = newRoom;
            });
            _checkRobotAnimation();
          },
        )
        .subscribe();
  }

  void _subscribeMessages(String roomId) {
    _messagesSub = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .listen((data) {
          if (!mounted) return;
          setState(() => _messages = data.map((e) => Chat.fromMap(e)).toList());
        });
  }

  void _subscribeSpectatorBroadcast(String roomId) {
    _spectatorBroadcastChannel = supabase.channel('spectator:room:$roomId');
    _spectatorBroadcastChannel!
        .onBroadcast(
          event: 'spectator_comment',
          callback: (payload) {
            final text = payload['text'] as String?;
            if (text != null && text.isNotEmpty) {
              _overlayKey.currentState?.addComment(text);
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment) return;

    final roomId = widget.invite.battleRoomId;
    if (roomId == null) return;

    setState(() => _isSendingComment = true);
    try {
      final commentText = text.length > 20 ? text.substring(0, 20) : text;

      // 自身の画面に即時表示
      _overlayKey.currentState?.addComment(commentText);

      // 他の観戦者および対戦者へブロードキャスト
      if (_spectatorBroadcastChannel != null) {
        await _spectatorBroadcastChannel!.sendBroadcastMessage(
          event: 'spectator_comment',
          payload: {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'text': commentText,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      }

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      log('コメント送信エラー: $e');
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkRobotAnimation();
      setState(() {});
    });
  }

  int? get _remainingSeconds {
    if (!_isBattleStarted) return null;
    final deadline = _deadline;
    if (deadline == null) return null;
    final estimatedServerTime =
        DateTime.now().add(_timeOffset ?? Duration.zero);
    final diff = deadline.difference(estimatedServerTime).inSeconds;
    return diff >= 0 ? diff : 0;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString()}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _displayName(String? id) {
    if (id == null) return '名無し';
    final name = _players[id]?.name;
    if (name == null || name.isEmpty || name == 'null') return '名無し';
    return name;
  }

  String? _avatarOf(String? id) => _players[id]?.avatar_url;

  String _getChoiceText(MatchingRoom room, {required bool isPlayer1}) {
    final choiceBool = isPlayer1 ? room.player1Choice : room.player2Choice;
    if (choiceBool == null) return '選択中...';
    return choiceBool ? (room.choice1 ?? '選択肢1') : (room.choice2 ?? '選択肢2');
  }

  String _formatName(String name) {
    return "'$name'";
  }

  String _formatResult(MatchingRoom room) {
    String result = room.reason ?? "";
    final hostName = _displayName(room.player1Id);
    final challengerName = _displayName(room.player2Id);
    result = result
        .replaceAll('A', _formatName(hostName))
        .replaceAll('B', _formatName(challengerName));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('観戦', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.notoSans(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final room = _room;
    if (room == null) {
      return const Scaffold(
        backgroundColor: Colors.blue,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 試合終了（勝敗確定）時は、画面遷移なしで FinishPage と同様の全画面リザルトを表示
    if (room.winner != null) {
      return _buildResultView(room);
    }

    final isStarted = _isBattleStarted;
    final remaining = _remainingSeconds;
    final isUrgent = isStarted && remaining != null && remaining <= 3;
    final isEvaluating = _isEvaluating;

    return FloatingSpectatorCommentsOverlay(
      key: _overlayKey,
      isMuted: _isCommentMuted,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_showFullChoice) {
            setState(() => _showFullChoice = false);
          }
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.blue,
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.blue,
                automaticallyImplyLeading: false,
                title: Stack(
                  children: [
                    Row(
                      children: [
                        // 左に配置する選択肢アイコン・テキスト（タップで両者の選択肢確認）
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showFullChoice = true;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 15),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.category_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '選択肢',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.notoSans(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 中央に配置するタイマー
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer,
                                    size: 20,
                                    color: isUrgent
                                        ? Colors.red
                                        : Colors.grey[800],
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    !isStarted || remaining == null
                                        ? '-'
                                        : _formatTime(remaining),
                                    style: AppTextStyles.notoSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isUrgent
                                          ? Colors.red
                                          : Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 右に配置するボタン（コメント非表示 ＆ 退出）
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: _isCommentMuted
                                      ? '観戦コメントを表示'
                                      : '観戦コメントを非表示',
                                  icon: Icon(
                                    _isCommentMuted
                                        ? Icons.speaker_notes_off
                                        : Icons.speaker_notes,
                                    color: _isCommentMuted
                                        ? Colors.white.withValues(alpha: 0.4)
                                        : Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: _toggleMute,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.door_back_door,
                                    color: Colors.white,
                                  ),
                                  iconSize: 29,
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 選択肢展開オーバーレイ
                    if (_showFullChoice)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showFullChoice = false),
                          child: Container(
                            color: Colors.blue,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.category_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ホスト: ${_getChoiceText(room, isPlayer1: true)}  /  挑戦者: ${_getChoiceText(room, isPlayer1: false)}',
                                    style: AppTextStyles.notoSans(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              body: Column(
                children: [
                  // テーマ表示カード
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        room.theme ?? '',
                        style: AppTextStyles.notoSans(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                  // 対戦チャットエリア
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: _messages.isEmpty
                                ? Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        '対戦開始！発言を待っています...',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 13),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    reverse: true,
                                    itemCount: _messages.length,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 4),
                                    itemBuilder: (context, index) {
                                      final chat = _messages[index];
                                      // 挑戦者側（応募者側＝player2）を自分側として右に配置
                                      final isUserMessage =
                                          chat.senderId == room.player2Id;

                                      // アバター表示：相手（player1）の発言かつ、一つ前（古い方）の送信者と異なる場合に表示
                                      final showAvatar = !isUserMessage &&
                                          (index == _messages.length - 1 ||
                                              _messages[index + 1].senderId !=
                                                  chat.senderId);

                                      final opponentAvatarUrl =
                                          _avatarOf(room.player1Id);

                                      return _buildMessageBubble(
                                        chat: chat,
                                        isUserMessage: isUserMessage,
                                        opponentAvatarUrl: opponentAvatarUrl,
                                        showAvatar: showAvatar,
                                      );
                                    },
                                  ),
                          ),
                          // 下部：コメント入力欄
                          _buildCommentInputBar(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 判定中のロボット点滅オーバーレイ（対戦側と完全同一）
            if (isEvaluating)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.4),
                  child: Center(
                    child: FadeTransition(
                      opacity: _robotAnimationController,
                      child: Image.asset(
                        'assets/images/robot.png',
                        width: 140,
                        height: 140,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // メッセージ吹き出し（GamePageと同一デザイン）
  // ==========================================
  Widget _buildMessageBubble({
    required Chat chat,
    required bool isUserMessage,
    required String? opponentAvatarUrl,
    required bool showAvatar,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 相手（ホスト/player1）の場合のアバター
          if (!isUserMessage) ...[
            if (showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                backgroundImage: opponentAvatarUrl != null &&
                        opponentAvatarUrl.isNotEmpty
                    ? NetworkImage(opponentAvatarUrl)
                    : null,
                child: opponentAvatarUrl == null || opponentAvatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          // メッセージ本文
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUserMessage ? const Color(0xFF0D47A1) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUserMessage ? 16 : 4),
                  bottomRight: Radius.circular(isUserMessage ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                chat.content,
                style: AppTextStyles.notoSans(
                  color: isUserMessage ? Colors.white : Colors.black87,
                  fontSize: 14.5,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 下部：観戦コメント入力バー（GamePage準拠）
  // ==========================================
  Widget _buildCommentInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 2,
        top: 4,
        bottom: MediaQuery.of(context).padding.bottom + 4,
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _commentController,
                maxLength: 20,
                textAlignVertical: TextAlignVertical.center,
                style: AppTextStyles.notoSans(
                  color: Colors.black,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'コメントする',
                  counterText: '',
                  hintStyle: AppTextStyles.notoSans(
                    color: Colors.grey[400],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendComment(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Transform.translate(
            offset: const Offset(4, 0),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _commentController,
              builder: (context, value, child) {
                final remaining = 20 - value.text.length;
                return Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    '$remaining',
                    style: AppTextStyles.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: remaining <= 0 ? Colors.red : Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            onPressed: _sendComment,
            icon: _isSendingComment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, color: Colors.blue, size: 24),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 試合終了後のリザルト画面（FinishPage準拠・画面遷移なし）
  // ==========================================
  Widget _buildResultView(MatchingRoom room) {
    final winner = room.winner?.trim();
    final isDraw = winner == 'C';
    final hostName = _displayName(room.player1Id);
    final challengerName = _displayName(room.player2Id);

    String resultTitle;
    Color resultColor;

    if (isDraw) {
      resultTitle = '引き分け';
      resultColor = Colors.grey[700]!;
    } else if (winner == 'A') {
      resultTitle = '$hostName の勝利';
      resultColor = Colors.red;
    } else if (winner == 'B') {
      resultTitle = '$challengerName の勝利';
      resultColor = Colors.red;
    } else {
      resultTitle = '試合終了';
      resultColor = Colors.grey[700]!;
    }

    final reasonText = _formatResult(room);

    // スコア情報の取得
    final scores = room.scores;
    final challengerScore = scores?.playerB ?? const PlayerScore();
    final hostScore = scores?.playerA ?? const PlayerScore();

    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // --- 固定ヘッダーエリア ---
                const SizedBox(height: 24),
                Text(
                  '結果発表',
                  style: AppTextStyles.bold(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      resultTitle,
                      style: AppTextStyles.notoSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- スクロール可能中央エリア（レーダーチャート ＆ 勝敗理由） ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        // レーダーチャート（挑戦者 vs ホスト）
                        RadarChartView(
                          myScore: challengerScore,
                          opponentScore: hostScore,
                          myName: challengerName,
                          opponentName: hostName,
                        ),
                        const SizedBox(height: 16),
                        // 勝敗の理由
                        if (reasonText.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '勝敗の理由:',
                                  style: AppTextStyles.bold(
                                    fontSize: 16,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  reasonText,
                                  style: AppTextStyles.notoSans(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // --- 下部固定ボタンエリア ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '観戦を終了する',
                        style: AppTextStyles.notoSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
