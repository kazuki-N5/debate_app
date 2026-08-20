// ignore_for_file: file_names, use_build_context_synchronously
import 'dart:async';
import 'dart:developer';

import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/floating_spectator_comments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// レスバの観戦画面
/// - A（ホスト） vs B（参加者）において、観戦者は「B視点」でリアルタイムに観戦
/// - テーマ選択フェーズ：相手（A）を赤、自分（B）を青で表示
/// - 対戦フェーズ：GamePage と同様のリッチな対戦チャットUI（B視点）
/// - 観戦コメント（ヤジ）機能：最大15文字の短文を送信でき、画面横からふわっと流れる
/// - コメント非表示ボタン（ローカル管理）
class ResbaBattleWatchView extends ConsumerStatefulWidget {
  final ResbaInvite invite;

  const ResbaBattleWatchView({super.key, required this.invite});

  @override
  ConsumerState<ResbaBattleWatchView> createState() =>
      _ResbaBattleWatchViewState();
}

class _ResbaBattleWatchViewState extends ConsumerState<ResbaBattleWatchView> {
  static const int _matchDurationSeconds = 600;
  static const String _prefMuteKey = 'spectator_comments_muted';

  SupabaseClient get supabase => ref.read(supabaseProvider);

  MatchingRoom? _room;
  final Map<String, Users> _players = {};
  List<Chat> _messages = []; // 新しい順（index 0 が最新）
  String? _error;
  DateTime? _deadline;
  Timer? _countdownTimer;

  RealtimeChannel? _roomChannel;
  RealtimeChannel? _spectatorBroadcastChannel;
  StreamSubscription<dynamic>? _messagesSub;

  final TextEditingController _commentController = TextEditingController();
  final GlobalKey<FloatingSpectatorCommentsOverlayState> _overlayKey =
      GlobalKey<FloatingSpectatorCommentsOverlayState>();

  bool _isCommentMuted = false;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _loadMutePreference();
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _commentController.dispose();
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

  Future<void> _load() async {
    final roomId = widget.invite.battleRoomId;
    if (roomId == null) {
      setState(() => _error = 'この対戦のログは保存されていません');
      return;
    }
    try {
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
        _deadline = room.updatedAt?.add(
          const Duration(seconds: _matchDurationSeconds + 2),
        );
      });
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
            setState(() {
              _room = MatchingRoom.fromMap(payload.newRecord);
            });
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
      final commentText = text.length > 15 ? text.substring(0, 15) : text;

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
      setState(() {});
    });
  }

  int? get _remainingSeconds {
    final deadline = _deadline;
    if (deadline == null) return null;
    return deadline.difference(DateTime.now()).inSeconds;
  }

  String _formatTime(int seconds) {
    if (seconds < 0) return '0:00';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _displayName(String? id) {
    if (id == null) return '名無し';
    final name = _players[id]?.name;
    if (name == null || name.isEmpty || name == 'null') return '名無し';
    return name;
  }

  String? _avatarOf(String? id) => _players[id]?.avatar_url;
  int? _trophyOf(String? id) => _players[id]?.trophy;

  /// winner（A/B/C）→ 勝者ユーザーID
  String? get _winnerId {
    final room = _room;
    if (room == null) return null;
    final winner = room.winner?.trim();
    if (winner == 'A') return room.player1Id;
    if (winner == 'B') return room.player2Id;
    return null;
  }

  bool get _isDraw {
    final room = _room;
    return room != null && room.winner != null && room.winner!.trim() == 'C';
  }

  bool get _isThemeChoosingPhase {
    final room = _room;
    if (room == null) return false;
    if (room.winner != null) return false;
    // 選択肢が確定して対戦に進む前
    if (room.player1Choice == null ||
        room.player2Choice == null ||
        room.player1Choice == room.player2Choice) {
      return true;
    }
    return false;
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
                  style: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey),
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

    return FloatingSpectatorCommentsOverlay(
      key: _overlayKey,
      isMuted: _isCommentMuted,
      child: Scaffold(
        backgroundColor: Colors.blue,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: _isThemeChoosingPhase
              ? _buildThemeChoosingView(room)
              : _buildBattleView(room),
        ),
      ),
    );
  }

  // ==========================================
  // 1. テーマ選択フェーズ (B視点：相手=赤、自分=青)
  // ==========================================
  Widget _buildThemeChoosingView(MatchingRoom room) {
    final p1Choice = room.player1Choice; // A（相手）の選択
    final p2Choice = room.player2Choice; // B（自分視点）の選択
    final choice1Text = room.choice1 ?? '選択肢1';
    final choice2Text = room.choice2 ?? '選択肢2';

    return Column(
      children: [
        // 上部バー
        _buildWatchAppBar(room, isLive: true),
        const SizedBox(height: 20),
        // 観戦バッジ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'B視点で観戦中（相手: 赤 / 自分: 青）',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // テーマ
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            room.theme ?? 'テーマ選択中...',
            textAlign: TextAlign.center,
            style: AppTextStyles.bold(
              fontSize: 28,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 36),
        // 選択肢カード（相手: 赤 / 自分: 青）
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSpectatorChoiceCard(
              title: choice1Text,
              isBChosen: p2Choice == true,
              isAChosen: p1Choice == true,
            ),
            const SizedBox(width: 24),
            _buildSpectatorChoiceCard(
              title: choice2Text,
              isBChosen: p2Choice == false,
              isAChosen: p1Choice == false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 状態メッセージ
        if (p1Choice != null && p2Choice != null && p1Choice == p2Choice)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '選択が被りました！再選択中...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          )
        else
          Text(
            'プレイヤーがテーマを選択しています...',
            style: AppTextStyles.notoSans(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        const Spacer(),
        // 観戦コメント送信バー
        _buildCommentInputBar(),
      ],
    );
  }

  Widget _buildSpectatorChoiceCard({
    required String title,
    required bool isBChosen,
    required bool isAChosen,
  }) {
    Color cardBgColor = Colors.white.withValues(alpha: 0.15);
    Color borderColor = Colors.white.withValues(alpha: 0.3);

    if (isBChosen && isAChosen) {
      // 両方選択（被り）
      cardBgColor = Colors.purple.withValues(alpha: 0.5);
      borderColor = Colors.purpleAccent;
    } else if (isBChosen) {
      // B（自分視点）が選択 → 青
      cardBgColor = Colors.blueAccent.withValues(alpha: 0.7);
      borderColor = Colors.cyanAccent;
    } else if (isAChosen) {
      // A（相手）が選択 → 赤
      cardBgColor = Colors.redAccent.withValues(alpha: 0.7);
      borderColor = Colors.redAccent;
    }

    return Container(
      width: 140,
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          if (isBChosen || isAChosen)
            BoxShadow(
              color: (isBChosen ? Colors.cyanAccent : Colors.redAccent)
                  .withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 選択バッジ
          if (isBChosen || isAChosen)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                if (isBChosen)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '自分(B)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isAChosen)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '相手(A)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          const Spacer(),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ==========================================
  // 2. 対戦中 / 終了後フェーズ (GamePage風UI)
  // ==========================================
  Widget _buildBattleView(MatchingRoom room) {
    final isLive = room.winner == null;
    final opponentId = room.player1Id; // A（相手）
    final mySideId = room.player2Id; // B（自分視点）

    return Column(
      children: [
        // 上部ヘッダー（AppBar）
        _buildWatchAppBar(room, isLive: isLive),
        // 結果バナー（試合終了時）
        if (!isLive) _buildResultHeader(room),
        // テーマ表示カード
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  room.theme ?? 'レスバ対戦',
                  style: AppTextStyles.notoSans(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '相手(A:赤): ${room.player1Choice == true ? room.choice1 : room.choice2}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('  vs  ',
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(
                      '自分(B:青): ${room.player2Choice == true ? room.choice1 : room.choice2}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 対戦チャットメインエリア
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: _buildBattleChatList(
              opponentId: opponentId,
              mySideId: mySideId,
            ),
          ),
        ),
        // 下部：コメント入力欄（対戦中はコメント送信、終了後は終了ボタン）
        if (isLive)
          _buildCommentInputBar()
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '観戦を終了する',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // 上部 AppBar
  // ==========================================
  Widget _buildWatchAppBar(MatchingRoom room, {required bool isLive}) {
    final opponentId = room.player1Id; // A（相手）
    final remaining = _remainingSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // 左側: 相手（A）の情報
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      backgroundImage: _avatarOf(opponentId) != null &&
                              _avatarOf(opponentId)!.isNotEmpty
                          ? NetworkImage(_avatarOf(opponentId)!)
                          : null,
                      child: _avatarOf(opponentId) == null ||
                              _avatarOf(opponentId)!.isEmpty
                          ? const Icon(Icons.person,
                              size: 20, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName(opponentId),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.trophy,
                            size: 11,
                            color: Color(0xFFFFD700),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${_trophyOf(opponentId) ?? 0}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 中央: タイマー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 18,
                  color: isLive && remaining != null && remaining <= 10
                      ? Colors.red
                      : Colors.grey[800],
                ),
                const SizedBox(width: 4),
                Text(
                  !isLive
                      ? '終了'
                      : (remaining != null ? _formatTime(remaining) : '-'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isLive && remaining != null && remaining <= 10
                        ? Colors.red
                        : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          // 右側: コメント非表示ボタン ＆ 退室ボタン
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // コメント非表示トグルボタン
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _isCommentMuted ? 'コメントを表示する' : 'コメントを非表示にする',
                  icon: Icon(
                    _isCommentMuted
                        ? Icons.speaker_notes_off
                        : Icons.speaker_notes,
                    color: _isCommentMuted
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.white,
                    size: 22,
                  ),
                  onPressed: _toggleMute,
                ),
                const SizedBox(width: 10),
                // 退出ボタン
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '観戦を終了',
                  icon: const Icon(
                    Icons.door_back_door,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 結果バナー（試合終了時）
  // ==========================================
  Widget _buildResultHeader(MatchingRoom room) {
    final isDraw = _isDraw;
    final winnerName = isDraw ? null : _displayName(_winnerId);
    final isBWinner = _winnerId == room.player2Id;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isDraw
                    ? '🤝 引き分け'
                    : (isBWinner
                        ? '🎉 自分側(B)の勝利！'
                        : '🏆 相手側(A)の勝利！'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDraw
                      ? Colors.grey[800]
                      : (isBWinner ? Colors.blue[800] : Colors.red[800]),
                ),
              ),
              if (!isDraw) ...[
                const SizedBox(width: 6),
                Text(
                  '($winnerName)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ],
          ),
          if (room.reason != null &&
              room.reason!.isNotEmpty &&
              room.reason != 'null') ...[
            const SizedBox(height: 3),
            Text(
              '判定理由: ${room.reason}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 対戦チャット一覧 (B視点：B=右/青、A=左/白)
  // ==========================================
  Widget _buildBattleChatList({
    required String? opponentId,
    required String? mySideId,
  }) {
    if (_messages.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            '対戦開始！発言を待っています...',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final chat = _messages[index];
        final isMySide = chat.senderId == mySideId; // B視点側

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment:
                isMySide ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 相手（A）の場合のみ左側にアバター
              if (!isMySide) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundImage: _avatarOf(chat.senderId) != null &&
                          _avatarOf(chat.senderId)!.isNotEmpty
                      ? NetworkImage(_avatarOf(chat.senderId)!)
                      : null,
                  child: _avatarOf(chat.senderId) == null ||
                          _avatarOf(chat.senderId)!.isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              // メッセージ吹き出し
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isMySide ? const Color(0xFF0D47A1) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMySide ? 16 : 4),
                      bottomRight: Radius.circular(isMySide ? 4 : 16),
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
                    style: TextStyle(
                      color: isMySide ? Colors.white : Colors.black87,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              // 自分側（B）の場合のアバター（右側）
              if (isMySide) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundImage: _avatarOf(chat.senderId) != null &&
                          _avatarOf(chat.senderId)!.isNotEmpty
                      ? NetworkImage(_avatarOf(chat.senderId)!)
                      : null,
                  child: _avatarOf(chat.senderId) == null ||
                          _avatarOf(chat.senderId)!.isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 下部：観戦コメント（ヤジ）入力バー（最大15文字）
  // ==========================================
  Widget _buildCommentInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom + 6,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.campaign,
            color: Colors.orange,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLength: 15,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ヤジ・応援を送信（15文字以内）',
                hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendComment(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: _isSendingComment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, color: Colors.blue),
            onPressed: _sendComment,
          ),
        ],
      ),
    );
  }
}
