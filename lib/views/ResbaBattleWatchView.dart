// ignore_for_file: file_names, use_build_context_synchronously
import 'dart:async';
import 'dart:developer';

import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// レスバの観戦画面
///  - 対戦中（winner 未確定）: rooms_v2 / messages を Realtime 購読してライブ観戦
///  - 終了後（winner 確定）  : 保存された rooms_v2 + messages で観戦ログを閲覧
/// 読み取り専用（投票・発言などの操作は一切なし）
class ResbaBattleWatchView extends ConsumerStatefulWidget {
  final ResbaInvite invite;

  const ResbaBattleWatchView({super.key, required this.invite});

  @override
  ConsumerState<ResbaBattleWatchView> createState() =>
      _ResbaBattleWatchViewState();
}

class _ResbaBattleWatchViewState extends ConsumerState<ResbaBattleWatchView> {
  /// GamePage と同じ試合制限時間
  static const int _matchDurationSeconds = 600;

  SupabaseClient get supabase => ref.read(supabaseProvider);

  MatchingRoom? _room;
  final Map<String, Users> _players = {};
  List<Chat> _messages = []; // 新しい順（index 0 が最新）
  String? _error;
  DateTime? _deadline;
  Timer? _countdownTimer;

  RealtimeChannel? _roomChannel;
  StreamSubscription<dynamic>? _messagesSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    if (_roomChannel != null) supabase.removeChannel(_roomChannel!);
    _messagesSub?.cancel();
    super.dispose();
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
        setState(() => _error = 'この対戦のログは保存されていません');
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
            setState(() => _room = MatchingRoom.fromMap(payload.newRecord));
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

  /// winner（A/B/C）→ 勝者ユーザーID。C（引き分け）や未確定は null
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

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final isLive = room != null && room.winner == null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive)
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            if (isLive) const SizedBox(width: 7),
            Text(
              isLive ? 'ライブ観戦' : '観戦ログ',
              style: AppTextStyles.bold(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 44, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    final room = _room;
    if (room == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        // 結果バナー（終了時のみ）
        if (room.winner != null) _buildResultBanner(room),
        // テーマカード
        _buildThemeCard(room),
        const SizedBox(height: 8),
        // 対戦者
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildPlayerRow(room, isPlayer1: true),
              const SizedBox(height: 8),
              _buildPlayerRow(room, isPlayer1: false),
            ],
          ),
        ),
        const Divider(height: 24),
        // 対戦ログ（チャット）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('⚔️ 対戦ログ',
                  style:
                      AppTextStyles.bold(fontSize: 14, color: Colors.black87)),
              const Spacer(),
              Text('${_messages.length}件',
                  style:
                      AppTextStyles.notoSans(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _buildChatList()),
        // 観戦を終了
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('観戦を終了'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultBanner(MatchingRoom room) {
    final winnerName = _isDraw ? null : _displayName(_winnerId);
    final reason = room.reason;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7856FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7856FF)),
      ),
      child: Column(
        children: [
          Text(
            _isDraw ? '🤝 引き分け' : '🏆 勝者: $winnerName',
            style: AppTextStyles.bold(
                fontSize: 17, color: const Color(0xFF4A30C4)),
          ),
          if (reason != null && reason.isNotEmpty && reason != 'null') ...[
            const SizedBox(height: 4),
            Text(
              '（$reason）',
              style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeCard(MatchingRoom room) {
    final isLive = room.winner == null;
    final remaining = _remainingSeconds;
    String timeLabel;
    if (!isLive) {
      timeLabel = '終了';
    } else if (remaining != null && remaining > 0) {
      timeLabel = '残り ${_formatTime(remaining)}';
    } else {
      timeLabel = '判定待ち…';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  room.theme ?? 'レスバ対戦',
                  style:
                      AppTextStyles.bold(fontSize: 15, color: Colors.black87),
                ),
              ),
              Text(
                timeLabel,
                style: AppTextStyles.bold(
                  fontSize: 12,
                  color: isLive
                      ? (remaining != null && remaining <= 10
                          ? Colors.redAccent
                          : Colors.grey[700])
                      : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '選択肢: ${room.choice1 ?? '賛成'} vs ${room.choice2 ?? '反対'}',
            style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(MatchingRoom room, {required bool isPlayer1}) {
    final id = isPlayer1 ? room.player1Id : room.player2Id;
    final choice = isPlayer1 ? room.player1Choice : room.player2Choice;
    final finishFlag = isPlayer1 ? room.player1_finish : room.player2_finish;
    final side =
        choice == null ? null : (choice == true ? room.choice1 : room.choice2);

    final winnerLabel = room.winner?.trim();
    String statusText;
    Color statusColor;
    if (winnerLabel != null) {
      if (winnerLabel == 'C') {
        statusText = '引き分け';
        statusColor = Colors.grey;
      } else {
        final isWinner = _winnerId == id;
        statusText = isWinner ? '勝利' : '敗北';
        statusColor = isWinner ? const Color(0xFF00BA7C) : Colors.grey;
      }
    } else if (finishFlag == true) {
      statusText = '判定申込中';
      statusColor = Colors.orange[800]!;
    } else if (choice != null) {
      statusText = '回答済み';
      statusColor = const Color(0xFF7856FF);
    } else {
      statusText = '対戦中';
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF7856FF).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: _avatarOf(id) != null && _avatarOf(id)!.isNotEmpty
                ? NetworkImage(_avatarOf(id)!)
                : null,
            child: _avatarOf(id) == null || _avatarOf(id)!.isEmpty
                ? const Icon(Icons.person, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isPlayer1 ? 'A' : 'B'} ・ ${_displayName(id)}',
                  style:
                      AppTextStyles.bold(fontSize: 13.5, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '🏆 ${_trophyOf(id) ?? '-'}'
                  '${side != null ? ' ・ $side側' : ''}',
                  style:
                      AppTextStyles.notoSans(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: AppTextStyles.bold(fontSize: 11, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'まだ発言はありません',
          style: AppTextStyles.notoSans(fontSize: 13, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildMessageBubble(Chat chat) {
    final isPlayer1 = chat.senderId == _room?.player1Id;
    final isPlayer2 = chat.senderId == _room?.player2Id;
    final bubbleColor = isPlayer1
        ? const Color(0xFFE3F0FF)
        : (isPlayer2 ? const Color(0xFFE6F9EF) : const Color(0xFFF3F3F3));

    final time = chat.createdAt;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundImage: _avatarOf(chat.senderId) != null &&
                    _avatarOf(chat.senderId)!.isNotEmpty
                ? NetworkImage(_avatarOf(chat.senderId)!)
                : null,
            child: _avatarOf(chat.senderId) == null ||
                    _avatarOf(chat.senderId)!.isEmpty
                ? const Icon(Icons.person, size: 14)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_displayName(chat.senderId)} ・ $timeStr',
                  style: AppTextStyles.notoSans(
                      fontSize: 10.5, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    chat.content,
                    style: AppTextStyles.notoSans(
                        fontSize: 13.5, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
