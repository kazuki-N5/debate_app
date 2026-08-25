import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:debate_project/provider/match_error_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';

// 1. ルームIDを取得・作成するプロバイダー
// 既存ルームがある場合はブロック中でもルームIDを返す（RPC側仕様）
final dmRoomIdProvider = FutureProvider.family.autoDispose<String, String>((ref, otherUserId) async {
  final supabase = ref.read(supabaseProvider);
  final response = await supabase.rpc(
    'get_or_create_dm_room',
    params: {'other_user_id': otherUserId},
  );
  return response as String;
});

// DMメッセージのモデル
class DmMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? imageUrl;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToUserName;

  DmMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.imageUrl,
    this.replyToId,
    this.replyToContent,
    this.replyToUserName,
  });

  factory DmMessage.fromJson(Map<String, dynamic> json) {
    return DmMessage(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      imageUrl: json['image_url'],
      replyToId: json['reply_to_id']?.toString(),
      replyToContent: json['reply_to_content']?.toString(),
      replyToUserName: json['reply_to_user_name']?.toString(),
    );
  }
}

// 2. DMメッセージを取得・管理するプロバイダー (ページネーション、楽観的UI対応)
final dmMessagesProvider = StateNotifierProvider.family.autoDispose<DmMessagesNotifier, AsyncValue<List<DmMessage>>, String>((ref, roomId) {
  return DmMessagesNotifier(ref, roomId);
});

class DmMessagesNotifier extends StateNotifier<AsyncValue<List<DmMessage>>> {
  final Ref _ref;
  final String roomId;
  RealtimeChannel? _channel;
  bool hasMore = true;
  bool _isDisposed = false;
  bool _isReconnecting = false;

  DmMessagesNotifier(this._ref, this.roomId) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _fetchLatestOrCatchUp() async {
    final supabase = _ref.read(supabaseProvider);
    try {
      if (state is AsyncData && state.value != null && state.value!.isNotEmpty) {
        // すでにメッセージがある場合は、手元の最新メッセージ以降の差分のみ取得
        final currentList = state.value!;
        // reverse: true なので index 0 が最も新しいメッセージ
        final latestMessage = currentList.first;
        final response = await supabase
            .from('dm_messages')
            .select('*')
            .eq('room_id', roomId)
            .gt('created_at', latestMessage.createdAt.toIso8601String())
            .order('created_at', ascending: false);

        final newMessages = (response as List)
            .map((e) => DmMessage.fromJson(e as Map<String, dynamic>))
            .toList();

        if (newMessages.isNotEmpty) {
          final existingIds = currentList.map((m) => m.id).toSet();
          final uniqueNew = newMessages.where((m) => !existingIds.contains(m.id)).toList();
          state = AsyncValue.data([...uniqueNew, ...currentList]);
        }
      } else {
        // 初回取得（直近50件）
        final response = await supabase
            .from('dm_messages')
            .select('*')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(50);

        final messages = (response as List)
            .map((e) => DmMessage.fromJson(e as Map<String, dynamic>))
            .toList();

        state = AsyncValue.data(messages);
        if (messages.length < 50) {
          hasMore = false;
        }
      }
    } catch (e, st) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> _init({String reason = '初回接続'}) async {
    final supabase = _ref.read(supabaseProvider);

    if (_channel != null) {
      final old = _channel!;
      _channel = null;
      try {
        await supabase.removeChannel(old);
      } catch (_) {}
    }
    if (_isDisposed || !mounted) return;

    log('🔌 [DMメッセージ] 接続開始 (理由: $reason, roomId: $roomId)');

    // 1. ストリームの購読を開始
    final channel = supabase.channel('public:dm_messages:room_id=$roomId');
    _channel = channel;

    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'dm_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          final newMsg = DmMessage.fromJson(payload.newRecord);
          if (state is AsyncData) {
            final currentList = state.value!;
            // 重複チェック (送信時の楽観的UIで追加済みの場合は無視、または上書き)
            if (!currentList.any((msg) => msg.id == newMsg.id)) {
              // reverse: true (最新が0番目) を想定して先頭に追加
              state = AsyncValue.data([newMsg, ...currentList]);
            }
          }
        }
      )
      .subscribe((status, [error]) async {
        if (_isDisposed || !mounted || _channel != channel) return;

        if (status == RealtimeSubscribeStatus.subscribed) {
          log('✅ [DMメッセージ] 接続成功 (理由: $reason, roomId: $roomId)');
          _isReconnecting = false;
          await _fetchLatestOrCatchUp();
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          if (_isReconnecting) return;
          _isReconnecting = true;
          log('⚠️ [DMメッセージ] 切断/エラー/タイムアウト検知 (status: $status, error: $error) ➔ 3秒後に再接続');
          await Future.delayed(const Duration(seconds: 3));
          if (!mounted || _isDisposed || _channel != channel) {
            _isReconnecting = false;
            return;
          }
          _isReconnecting = false;
          _init(reason: '再接続 ($status)');
        }
      });
  }

  Future<void> loadMore() async {
    if (!hasMore || state is! AsyncData) return;
    
    final currentList = state.value!;
    if (currentList.isEmpty) return;

    // reverse: true なので、リストの最後 (一番下) が一番古いメッセージ
    final oldestMessage = currentList.last;
    final supabase = _ref.read(supabaseProvider);

    try {
      final response = await supabase
          .from('dm_messages')
          .select('*')
          .eq('room_id', roomId)
          .lt('created_at', oldestMessage.createdAt.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      final olderMessages = (response as List).map((e) => DmMessage.fromJson(e as Map<String, dynamic>)).toList();
      
      if (olderMessages.length < 50) {
        hasMore = false;
      }

      state = AsyncValue.data([...currentList, ...olderMessages]);
    } catch (e) {
      print('loadMore error: $e');
    }
  }

  /// メッセージを送信し、実際のメッセージIDを返す（レスバ添付時に使用）
  Future<String?> sendMessage(
    String content, {
    String? imageUrl,
    String? replyToId,
    String? replyToContent,
    String? replyToUserName,
  }) async {
    final supabase = _ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return null;

    // 楽観的UI (一時的なメッセージをStateに追加)
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = DmMessage(
      id: tempId,
      roomId: roomId,
      senderId: myId,
      content: content,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToUserName: replyToUserName,
    );

    if (state is AsyncData) {
      final currentList = state.value!;
      state = AsyncValue.data([tempMsg, ...currentList]);
    }

    try {
      // 実際の送信処理
      final response = await supabase.from('dm_messages').insert({
        'room_id': roomId,
        'sender_id': myId,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (replyToContent != null) 'reply_to_content': replyToContent,
        if (replyToUserName != null) 'reply_to_user_name': replyToUserName,
      }).select().single();

      // 送信成功後、仮のメッセージを本物のメッセージに置き換える
      if (state is AsyncData) {
        final currentList = state.value!;
        final realMsg = DmMessage.fromJson(response);
        state = AsyncValue.data(
          currentList.map((m) => m.id == tempId ? realMsg : m).toList()
        );
      }
      return response['id'] as String?;
    } catch (e) {
      // エラー処理（一時メッセージを消して共通エラーUIで表示）
      print('sendMessage error: $e');
      if (state is AsyncData) {
        final currentList = state.value!;
        state = AsyncValue.data(
          currentList.where((m) => m.id != tempId).toList() // 送信失敗したら仮メッセージを消す
        );
      }
      // ブロックされている場合は専用文言、それ以外は汎用文言を表示
      var isBlockedRoom = false;
      try {
        isBlockedRoom = await supabase.rpc(
                  'is_dm_room_blocked',
                  params: {'p_room_id': roomId}) as bool? ?? false;
      } catch (_) {}
      _ref.read(matchErrorServiceProvider).showMatchEndMessage(
        isBlockedRoom ? 'ブロックされているので送れません' : '送信に失敗しました',
        0.68,
      );
      return null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_channel != null) {
      try {
        final supabase = _ref.read(supabaseProvider);
        supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
    super.dispose();
  }
}

// 3. DMルームにおける自分のミュート状態を取得するプロバイダー
final dmMyMemberMuteProvider = FutureProvider.family.autoDispose<bool, String>((ref, roomId) async {
  final supabase = ref.read(supabaseProvider);
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return false;

  final response = await supabase
      .from('dm_room_members')
      .select('is_muted')
      .match({
        'room_id': roomId,
        'user_id': myId,
      })
      .maybeSingle();

  if (response == null) return false;
  return response['is_muted'] as bool? ?? false;
});

// 4. DMアクションプロバイダー
class DmActionNotifier extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  /// DM通知の個別ミュート切り替え
  Future<String?> toggleDmMute(String roomId, bool isMuted) async {
    final supabase = ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return 'ログインが必要です';
    try {
      await supabase.from('dm_room_members').update({
        'is_muted': isMuted,
      }).match({
        'room_id': roomId,
        'user_id': myId,
      });
      ref.invalidate(dmMyMemberMuteProvider(roomId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final dmActionProvider = NotifierProvider.autoDispose<DmActionNotifier, void>(() {
  return DmActionNotifier();
});

