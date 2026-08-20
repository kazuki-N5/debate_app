import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';

// 1. ルームIDを取得・作成するプロバイダー
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

  DmMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.imageUrl,
  });

  factory DmMessage.fromJson(Map<String, dynamic> json) {
    return DmMessage(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      imageUrl: json['image_url'],
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

  DmMessagesNotifier(this._ref, this.roomId) : super(const AsyncValue.loading()) {
    _init();
  }

  /// ブロック済みユーザーのメッセージを除外
  List<DmMessage> _filter(List<DmMessage> messages) {
    final blocked = _ref.read(blockedUserIdsProvider).toSet();
    return messages.where((m) => !blocked.contains(m.senderId)).toList();
  }

  Future<void> _init() async {
    final supabase = _ref.read(supabaseProvider);

    // 1. 先にストリームの購読を開始
    _channel = supabase.channel('public:dm_messages:room_id=$roomId')
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
          // ブロック済みユーザーのメッセージは追加しない
          if (state is AsyncData) {
            final currentList = state.value!;
            if (_filter([newMsg]).isEmpty) return;
            // 重複チェック (送信時の楽観的UIで追加済みの場合は無視、または上書き)
            if (!currentList.any((msg) => msg.id == newMsg.id)) {
              // reverse: true (最新が0番目) を想定して先頭に追加
              state = AsyncValue.data([newMsg, ...currentList]);
            }
          }
        }
      ).subscribe();

    // 2. 直近の50件を取得
    try {
      final response = await supabase
          .from('dm_messages')
          .select('*')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(50);
          
      final messages = (response as List).map((e) => DmMessage.fromJson(e as Map<String, dynamic>)).toList();
      
      // DmRoomPageのListViewはreverse: trueなので、降順のままでOK
      state = AsyncValue.data(_filter(messages));
      
      if (messages.length < 50) {
        hasMore = false;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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

      state = AsyncValue.data([...currentList, ..._filter(olderMessages)]);
    } catch (e) {
      print('loadMore error: $e');
    }
  }

  /// メッセージを送信し、実際のメッセージIDを返す（レスバ添付時に使用）
  Future<String?> sendMessage(String content, {String? imageUrl}) async {
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
      // エラー処理（本来ならエラー表示などが必要）
      print('sendMessage error: $e');
      if (state is AsyncData) {
        final currentList = state.value!;
        state = AsyncValue.data(
          currentList.where((m) => m.id != tempId).toList() // 送信失敗したら仮メッセージを消す
        );
      }
      return null;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
