import 'dart:io';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 検索クエリを保持するプロバイダー
final openChatSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// 1. ルーム一覧を取得するプロバイダー
final openChatRoomsProvider = FutureProvider.autoDispose<List<OpenChatRoom>>((ref) async {
  final searchQuery = ref.watch(openChatSearchQueryProvider);
  final supabase = ref.read(supabaseProvider);
  
  final response = await supabase.rpc('get_open_chat_rooms_with_status', params: {
    'p_search_query': searchQuery.isEmpty ? null : searchQuery,
  });

  return (response as List<dynamic>)
      .map((e) => OpenChatRoom.fromJson(e as Map<String, dynamic>))
      .toList();
});

// 2. メッセージをリアルタイムで取得するプロバイダー (ページネーション対応)
final openChatMessagesProvider = StateNotifierProvider.family.autoDispose<OpenChatMessagesNotifier, AsyncValue<List<OpenChatMessage>>, String>((ref, roomId) {
  return OpenChatMessagesNotifier(ref, roomId);
});

class OpenChatMessagesNotifier extends StateNotifier<AsyncValue<List<OpenChatMessage>>> {
  final Ref _ref;
  final String roomId;
  RealtimeChannel? _channel;
  bool hasMore = true;
  // 端末内で非表示にしたメッセージID(「非表示」機能)
  Set<String> _hiddenMessageIds = {};

  OpenChatMessagesNotifier(this._ref, this.roomId) : super(const AsyncValue.loading()) {
    _loadHiddenIds();
    _init();
  }

  Future<void> _loadHiddenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hiddenMessageIds =
          (prefs.getStringList('hidden_open_chat_message_ids') ?? const []).toSet();
    } catch (_) {}
  }

  /// メッセージを「非表示」にする(端末内のみ)
  Future<void> hideMessage(String messageId) async {
    _hiddenMessageIds.add(messageId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_open_chat_message_ids', _hiddenMessageIds.toList());
    } catch (_) {}
    if (state is AsyncData) {
      state = AsyncValue.data(
        state.value!.where((m) => m.id != messageId).toList(),
      );
    }
  }

  /// ブロック済みユーザー・非表示メッセージを除外
  List<OpenChatMessage> _filter(List<OpenChatMessage> messages) {
    final blocked = _ref.read(blockedUserIdsProvider).toSet();
    return messages
        .where((m) => !blocked.contains(m.userId))
        .where((m) => !_hiddenMessageIds.contains(m.id))
        .toList();
  }

  Future<void> _init() async {
    final supabase = _ref.read(supabaseProvider);

    // 1. 先にストリームの購読を開始する
    _channel = supabase.channel('public:open_chat_messages:room_id=$roomId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'open_chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          final newMsg = OpenChatMessage.fromJson(payload.newRecord);
          // ブロック済みユーザー・非表示メッセージは追加しない
          if (state is AsyncData) {
            final currentList = state.value!;
            final filtered = _filter([newMsg]);
            if (filtered.isEmpty) return;
            // 重複チェック
            if (!currentList.any((msg) => msg.id == newMsg.id)) {
              state = AsyncValue.data([...currentList, newMsg]);
            }
          }
        }
      ).subscribe();

    // 2. 直近の50件を取得
    try {
      final response = await supabase
          .from('open_chat_messages')
          .select('*')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(50);
          
      final messages = (response as List).map((e) => OpenChatMessage.fromJson(e as Map<String, dynamic>)).toList();
      // created_atが降順で来るので、昇順（古い順）に直して画面表示用に合わせる
      state = AsyncValue.data(_filter(messages.reversed.toList()));
      
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

    final oldestMessage = currentList.first;
    final supabase = _ref.read(supabaseProvider);

    try {
      final response = await supabase
          .from('open_chat_messages')
          .select('*')
          .eq('room_id', roomId)
          .lt('created_at', oldestMessage.createdAt.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      final olderMessages = (response as List).map((e) => OpenChatMessage.fromJson(e as Map<String, dynamic>)).toList();
      
      if (olderMessages.length < 50) {
        hasMore = false;
      }

      state = AsyncValue.data([..._filter(olderMessages.reversed.toList()), ...currentList]);
    } catch (e) {
      print('loadMore error: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

// 3. アクション（作成、参加、送信など）を行うNotifier
class OpenChatActionNotifier extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  Future<String?> uploadImage(String filePath, String folderName) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final fileExtension = filePath.split('.').last.toLowerCase();
      // uuidがインポートされていない場合はここでエラーになる可能性があるため、とりあえずタイムスタンプ等を使用する
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final path = '$folderName/$fileName';

      // バケットは 'open_chat_images' を使用する
      await supabase.storage.from('open_chat_images').upload(
            path,
            File(filePath),
          );

      final publicUrl = supabase.storage.from('open_chat_images').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('画像アップロードエラー: $e');
      return null;
    }
  }

  Future<String?> createRoom(String name, String description, String? iconUrl, {String? backgroundUrl, String? password}) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('create_open_chat_room', params: {
        'p_name': name,
        'p_description': description,
        'p_icon_url': iconUrl,
        'p_background_url': backgroundUrl,
        'p_password': password,
      });
      
      if (response['success'] == true) {
        ref.invalidate(openChatRoomsProvider);
        return null; // 成功
      } else {
        return response['error'] ?? '作成に失敗しました';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> joinRoom(String roomId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('join_open_chat', params: {
        'p_room_id': roomId,
      });
      if (response['success'] == true) {
        return null;
      } else {
        return response['error'] ?? '参加に失敗しました';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> sendMessage(String roomId, String content, {String? imageUrl}) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await supabase
        .from('open_chat_messages')
        .insert({
          'room_id': roomId,
          'user_id': userId,
          'content': content,
          if (imageUrl != null) 'image_url': imageUrl,
        })
        .select('id')
        .single();
    return response['id'] as String?;
  }

  Future<String?> leaveRoom(String roomId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('leave_open_chat_room', params: {
        'p_room_id': roomId,
      });
      if (response['success'] == true) {
        ref.invalidate(openChatRoomsProvider);
        return null;
      } else {
        return response['error'] ?? '退室に失敗しました';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> kickMember(String roomId, String targetUserId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('kick_open_chat_member', params: {
        'p_room_id': roomId,
        'p_target_user_id': targetUserId,
      });
      if (response['success'] == true) {
        return null;
      } else {
        return response['error'] ?? 'キックに失敗しました';
      }
    } catch (e) {
      return e.toString();
    }
  }
}

final openChatActionProvider = NotifierProvider.autoDispose<OpenChatActionNotifier, void>(() {
  return OpenChatActionNotifier();
});

// 4. 指定ルームのメンバー一覧を取得する
final openChatMembersProvider = FutureProvider.family.autoDispose<List<OpenChatMember>, String>((ref, roomId) async {
  final supabase = ref.read(supabaseProvider);
  final response = await supabase
      .from('open_chat_members')
      .select('*')
      .eq('room_id', roomId)
      .order('joined_at', ascending: true);
  
  return (response as List<dynamic>)
      .map((e) => OpenChatMember.fromJson(e as Map<String, dynamic>))
      .toList();
});
