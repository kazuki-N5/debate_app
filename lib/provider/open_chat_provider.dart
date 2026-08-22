import 'dart:developer';
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
  bool _isDisposed = false;
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

  Future<void> _fetchLatestOrCatchUp() async {
    final supabase = _ref.read(supabaseProvider);
    try {
      if (state is AsyncData && state.value != null && state.value!.isNotEmpty) {
        // すでにメッセージがある場合は、手元の最新メッセージ以降の差分のみ取得
        final currentList = state.value!;
        // reverse: true なので index 0 が最も新しいメッセージ
        final latestMessage = currentList.first;
        final response = await supabase
            .from('open_chat_messages')
            .select('*')
            .eq('room_id', roomId)
            .gt('created_at', latestMessage.createdAt.toIso8601String())
            .order('created_at', ascending: false);

        final newMessages = (response as List)
            .map((e) => OpenChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();

        final filteredNew = _filter(newMessages);
        if (filteredNew.isNotEmpty) {
          final existingIds = currentList.map((m) => m.id).toSet();
          final uniqueNew = filteredNew.where((m) => !existingIds.contains(m.id)).toList();
          state = AsyncValue.data([...uniqueNew, ...currentList]);
        }
      } else {
        // 初回取得（直近50件）
        final response = await supabase
            .from('open_chat_messages')
            .select('*')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(50);

        final messages = (response as List)
            .map((e) => OpenChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();

        state = AsyncValue.data(_filter(messages));

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
    log('🔌 [オプチャメッセージ] 接続開始 (理由: $reason, roomId: $roomId)');

    // 1. ストリームの購読を開始する
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
            // 重複チェック (送信時の楽観的UIで追加済みの場合は無視)
            if (!currentList.any((msg) => msg.id == newMsg.id)) {
              state = AsyncValue.data([newMsg, ...currentList]);
            }
          }
        }
      )
      .subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          log('✅ [オプチャメッセージ] 接続成功 (理由: $reason, roomId: $roomId)');
          await _fetchLatestOrCatchUp();
        } else if (!_isDisposed && mounted &&
            (status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut)) {
          log('⚠️ [オプチャメッセージ] 切断/エラー/タイムアウト検知 (status: $status, error: $error) ➔ 3秒後に再接続');
          await Future.delayed(const Duration(seconds: 3));
          if (!mounted || _isDisposed) return;
          if (_channel != null) {
            try {
              await supabase.removeChannel(_channel!);
            } catch (_) {}
            _channel = null;
          }
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

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = OpenChatMessage(
      id: tempId,
      roomId: roomId,
      userId: myId,
      content: content,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
    );

    if (state is AsyncData) {
      final currentList = state.value!;
      state = AsyncValue.data([tempMsg, ...currentList]);
    }

    try {
      final response = await supabase.from('open_chat_messages').insert({
        'room_id': roomId,
        'user_id': myId,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
      }).select().single();

      if (state is AsyncData) {
        final currentList = state.value!;
        final realMsg = OpenChatMessage.fromJson(response);
        state = AsyncValue.data(
          currentList.map((m) => m.id == tempId ? realMsg : m).toList(),
        );
      }
      return response['id'] as String?;
    } catch (e) {
      if (state is AsyncData) {
        final currentList = state.value!;
        state = AsyncValue.data(
          currentList.map((m) => m.id == tempId ? m.copyWith(id: 'error_$tempId') : m).toList(),
        );
      }
      rethrow;
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

/// 説明文などから #ハッシュタグ を抽出するユーティリティ関数
List<String> extractTagsFromDescription(String text) {
  final regExp = RegExp(r'#([^\s#]+)');
  final matches = regExp.allMatches(text);
  return matches.map((m) => m.group(1)!).toSet().toList();
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

  Future<String?> createRoom(
    String name,
    String description,
    String? iconUrl, {
    String? backgroundUrl,
    String? password,
    List<String>? tags,
  }) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final effectiveTags = tags ?? extractTagsFromDescription(description);
      final response = await supabase.rpc('create_open_chat_room', params: {
        'p_name': name,
        'p_description': description,
        'p_icon_url': iconUrl,
        'p_background_url': backgroundUrl,
        'p_password': password,
        'p_tags': effectiveTags,
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
