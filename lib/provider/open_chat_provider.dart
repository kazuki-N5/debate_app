import 'dart:developer';
import 'dart:io';
import 'package:debate_project/modes/open_chat.dart';
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
  bool _isReconnecting = false;
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

  /// メッセージを「論理削除」する（自分または管理者）
  Future<String?> deleteMessage(String messageId) async {
    final supabase = _ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    log('🗑️ [削除開始] messageId: $messageId, roomId: $roomId');

    // 楽観的UI: 手元のメッセージを即時削除状態に更新
    if (state is AsyncData) {
      final currentList = state.value!;
      state = AsyncValue.data(
        currentList.map((m) => m.id == messageId
            ? m.copyWith(isDeleted: true, isAdminDeleted: m.userId != myId)
            : m).toList(),
      );
    }

    try {
      final response = await supabase.rpc('delete_open_chat_message', params: {
        'p_message_id': messageId,
      });

      log('📡 [削除RPC結果] response: $response');

      if (response != null && response['success'] == true) {
        log('✅ [削除成功] messageId: $messageId');
        return null; // 成功
      } else {
        final errorMsg = response?['error'] as String? ?? '削除に失敗しました';
        log('❌ [削除拒否/失敗] error: $errorMsg');
        // 失敗時は手元の楽観的UIをロールバック
        if (state is AsyncData) {
          final currentList = state.value!;
          state = AsyncValue.data(
            currentList.map((m) => m.id == messageId ? m.copyWith(isDeleted: false) : m).toList(),
          );
        }
        return errorMsg;
      }
    } catch (e, st) {
      log('❌ [オプチャメッセージ削除例外] $e\n$st');
      // 失敗時はロールバック
      if (state is AsyncData) {
        final currentList = state.value!;
        state = AsyncValue.data(
          currentList.map((m) => m.id == messageId ? m.copyWith(isDeleted: false) : m).toList(),
        );
      }
      return e.toString();
    }
  }

  /// 非表示メッセージを除外（オプチャではブロックに関わらず全メッセージを表示）
  List<OpenChatMessage> _filter(List<OpenChatMessage> messages) {
    return messages
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

        if (newMessages.isNotEmpty) {
          final existingIds = currentList.map((m) => m.id).toSet();
          final uniqueNew = _filter(newMessages.where((m) => !existingIds.contains(m.id)).toList());
          if (uniqueNew.isNotEmpty) {
            state = AsyncValue.data([...uniqueNew, ...currentList]);
          }
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

        log('📥 [メッセージ初回取得] 件数: ${messages.length}, 削除済み件数: ${messages.where((m) => m.isDeleted).length}');
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

    if (_channel != null) {
      final old = _channel!;
      _channel = null;
      try {
        await supabase.removeChannel(old);
      } catch (_) {}
    }
    if (_isDisposed || !mounted) return;

    log('🔌 [オプチャメッセージ] 接続開始 (理由: $reason, roomId: $roomId)');

    // 1. ストリームの購読を開始する
    final channel = supabase.channel('public:open_chat_messages:room_id=$roomId');
    _channel = channel;

    channel
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
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'open_chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          log('⚡ [Realtime UPDATE受信] payload: ${payload.newRecord}');
          final updatedMsg = OpenChatMessage.fromJson(payload.newRecord);
          log('⚡ [Realtime UPDATE適用] id: ${updatedMsg.id}, isDeleted: ${updatedMsg.isDeleted}');
          if (state is AsyncData) {
            final currentList = state.value!;
            state = AsyncValue.data(
              currentList.map((m) => m.id == updatedMsg.id ? updatedMsg : m).toList(),
            );
          }
        }
      )
      .subscribe((status, [error]) async {
        if (_isDisposed || !mounted || _channel != channel) return;

        if (status == RealtimeSubscribeStatus.subscribed) {
          log('✅ [オプチャメッセージ] 接続成功 (理由: $reason, roomId: $roomId)');
          _isReconnecting = false;
          await _fetchLatestOrCatchUp();
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          if (_isReconnecting) return;
          _isReconnecting = true;
          log('⚠️ [オプチャメッセージ] 切断/エラー/タイムアウト検知 (status: $status, error: $error) ➔ 3秒後に再接続');
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

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = OpenChatMessage(
      id: tempId,
      roomId: roomId,
      userId: myId,
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
      final response = await supabase.from('open_chat_messages').insert({
        'room_id': roomId,
        'user_id': myId,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (replyToContent != null) 'reply_to_content': replyToContent,
        if (replyToUserName != null) 'reply_to_user_name': replyToUserName,
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

  Future<String?> kickMember(String roomId, String targetUserId, {bool ban = false}) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('kick_open_chat_member', params: {
        'p_room_id': roomId,
        'p_target_user_id': targetUserId,
        'p_ban': ban,
      });
      if (response['success'] == true) {
        ref.invalidate(openChatMembersProvider(roomId));
        if (ban) {
          ref.invalidate(openChatBannedUsersProvider(roomId));
        }
        return null;
      } else {
        return response['error'] ?? '削除に失敗しました';
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// 再参加禁止（BAN）を解除する
  Future<String?> unbanMember(String roomId, String targetUserId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('unban_open_chat_member', params: {
        'p_room_id': roomId,
        'p_target_user_id': targetUserId,
      });
      if (response['success'] == true) {
        ref.invalidate(openChatBannedUsersProvider(roomId));
        return null;
      } else {
        return response['error'] ?? '解除に失敗しました';
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// 管理人権限を別のメンバーに譲渡する（RPC: transfer_room_ownership）
  /// 旧オーナーは副管理人(admin)に降格、新オーナーは管理人(owner)に昇格
  Future<String?> transferOwnership(String roomId, String newOwnerId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('transfer_room_ownership', params: {
        'p_room_id': roomId,
        'p_new_owner_id': newOwnerId,
      });
      if (response['success'] == true) {
        ref.invalidate(openChatRoomDetailProvider(roomId));
        ref.invalidate(openChatMyMemberProvider(roomId));
        ref.invalidate(openChatMembersProvider(roomId));
        return null;
      }
      return response['error'] ?? '譲渡に失敗しました';
    } catch (e) {
      return e.toString();
    }
  }

  /// 一般メンバーを副管理人(admin)に任命する（RPC: assign_admin_role / オーナーのみ）
  Future<String?> assignAdmin(String roomId, String targetUserId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('assign_admin_role', params: {
        'p_room_id': roomId,
        'p_target_user_id': targetUserId,
      });
      if (response['success'] == true) {
        ref.invalidate(openChatMembersProvider(roomId));
        return null;
      }
      return response['error'] ?? '任命に失敗しました';
    } catch (e) {
      return e.toString();
    }
  }

  /// 副管理人(admin)を一般メンバーに解任する（RPC: revoke_admin_role / オーナーのみ）
  Future<String?> revokeAdmin(String roomId, String targetUserId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase.rpc('revoke_admin_role', params: {
        'p_room_id': roomId,
        'p_target_user_id': targetUserId,
      });
      if (response['success'] == true) {
        ref.invalidate(openChatMembersProvider(roomId));
        return null;
      }
      return response['error'] ?? '解任に失敗しました';
    } catch (e) {
      return e.toString();
    }
  }

  /// ルーム情報の更新（管理者用）
  Future<String?> updateRoom(
    String roomId,
    String name,
    String description,
    String? iconUrl, {
    String? backgroundUrl,
    String? password,
    List<String>? tags,
  }) async {
    final supabase = ref.read(supabaseProvider);
    try {
      await supabase.from('open_chat_rooms').update({
        'name': name,
        'description': description,
        if (iconUrl != null) 'icon_url': iconUrl,
        'background_url': backgroundUrl,
        'password': password,
        if (tags != null) 'tags': tags,
      }).eq('id', roomId);
      ref.invalidate(openChatRoomDetailProvider(roomId));
      ref.invalidate(openChatRoomsProvider);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// ルールの更新（管理者用）
  Future<String?> updateRules(String roomId, String rules) async {
    final supabase = ref.read(supabaseProvider);
    try {
      await supabase.from('open_chat_rooms').update({
        'rules': rules,
      }).eq('id', roomId);
      ref.invalidate(openChatRoomDetailProvider(roomId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// ルーム個別通知のミュート切り替え
  Future<String?> toggleRoomMute(String roomId, bool isMuted) async {
    final supabase = ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return 'ログインが必要です';
    try {
      await supabase.from('open_chat_members').update({
        'is_muted': isMuted,
      }).match({
        'room_id': roomId,
        'user_id': myId,
      });
      ref.invalidate(openChatMyMemberProvider(roomId));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// クラブ（ルーム）の削除（オーナー用）
  Future<String?> deleteRoom(String roomId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      await supabase.from('open_chat_rooms').delete().eq('id', roomId);
      ref.invalidate(openChatRoomsProvider);
      return null;
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

// 5. 指定ルームの最新詳細情報を取得する
final openChatRoomDetailProvider = FutureProvider.family.autoDispose<OpenChatRoom?, String>((ref, roomId) async {
  final supabase = ref.read(supabaseProvider);
  final response = await supabase
      .from('open_chat_rooms')
      .select('*')
      .eq('id', roomId)
      .maybeSingle();

  if (response == null) return null;
  return OpenChatRoom.fromJson(response);
});

// 6. 指定ルームにおける現在の自分のメンバー情報を取得する (isMutedやrole判定用)
final openChatMyMemberProvider = FutureProvider.family.autoDispose<OpenChatMember?, String>((ref, roomId) async {
  final supabase = ref.read(supabaseProvider);
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return null;

  final response = await supabase
      .from('open_chat_members')
      .select('*')
      .match({
        'room_id': roomId,
        'user_id': myId,
      })
      .maybeSingle();

  if (response == null) return null;
  return OpenChatMember.fromJson(response);
});

// 7. 指定ルームの再参加禁止メンバー一覧を取得する (管理者専用)
final openChatBannedUsersProvider = FutureProvider.family.autoDispose<List<OpenChatBannedUser>, String>((ref, roomId) async {
  final supabase = ref.read(supabaseProvider);
  try {
    final response = await supabase.rpc('get_open_chat_banned_users', params: {
      'p_room_id': roomId,
    });
    if (response['success'] == true && response['data'] != null) {
      return (response['data'] as List<dynamic>)
          .map((e) => OpenChatBannedUser.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

// 8. 自分がこのルームから追放されたかをリアルタイムで保持するプロバイダー
//    - open_chat_members の DELETE イベント (自分) を検知したら true になる
//    - 初回チェックで自分がメンバーに存在しない場合も追放済みとして true になる
final openChatKickedProvider = StateNotifierProvider.family.autoDispose<
    OpenChatKickedNotifier, bool, String>(
  (ref, roomId) => OpenChatKickedNotifier(ref, roomId),
);

class OpenChatKickedNotifier extends StateNotifier<bool> {
  final Ref _ref;
  final String roomId;
  RealtimeChannel? _channel;
  bool _disposed = false;
  // 自分のメンバー行の主キー(id)
  // ※ 開発サーバーのRealtimeは DELETE の old_record に id(主キー)しか
  //   含めないことがあるため、user_id ではなくこの id で一致判定する
  String? _myMemberRowId;

  OpenChatKickedNotifier(this._ref, this.roomId) : super(false) {
    _init();
  }

  /// サーバー上で自分がメンバーでなくなったかを確認する
  /// (リアルタイムイベントを取りこぼした場合や再接続時のフォールバック)
  Future<void> _checkMembership() async {
    if (state) { print('🔎 [退会検知] 既に退会状態のためスキップ (room=$roomId)'); return; }
    final supabase = _ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final mine = await supabase
          .from('open_chat_members')
          .select('id, user_id')
          .match({'room_id': roomId, 'user_id': myId})
          .maybeSingle();
      if (mine == null) {
        print('🔎 [退会検知] メンバー確認 room=$roomId myId=$myId → メンバーに存在しない(退会済み)');
        state = true;
        _ref.invalidate(openChatMembersProvider(roomId));
        _ref.invalidate(openChatMyMemberProvider(roomId));
      } else {
        _myMemberRowId = mine['id'] as String?;
        print('🔎 [退会検知] メンバー確認 room=$roomId myId=$myId → メンバーに存在 (myRowId=$_myMemberRowId)');
      }
    } catch (e) {
      print('🔎 [退会検知] メンバー確認エラー: $e');
    }
  }

  /// 追放(退会させられた)状態を確定する。
  /// 送信時に RLS エラー(42501)が出た場合など、リアルタイム検知の
  /// フォールバックとして UI から呼び出す。
  void markKicked() {
    if (state) return;
    print('📛 [退会検知] markKicked() 呼び出し (room=$roomId)');
    state = true;
    _ref.invalidate(openChatMembersProvider(roomId));
    _ref.invalidate(openChatMyMemberProvider(roomId));
  }

  Future<void> _init() async {
    final supabase = _ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) {
      print('🔌 [退会検知] ログインしていないため監視しない (room=$roomId)');
      return;
    }

    // 初回チェック: 自分が既にメンバーに存在しない場合は退会済みとみなす
    print('🔌 [退会検知] 監視開始 room=$roomId myId=$myId');
    await _checkMembership();
    if (state || _disposed) return;

    // リアルタイム購読: 自分がメンバーから削除された (退会させられた) ら true
    final channel =
        supabase.channel('public:open_chat_members:room_id=$roomId');
    _channel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'open_chat_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final oldRecord = payload.oldRecord;
            print('📡 [退会検知] DELETEイベント受信 room=$roomId oldRecord=$oldRecord myId=$myId myRowId=$_myMemberRowId');
            // old_record には id(主キー)は必ず含まれる(user_id等はサーバー
            // 設定により欠けることがある)ため、自分のメンバー行 id で判定する
            final matchedById = oldRecord['id'] != null && oldRecord['id'] == _myMemberRowId;
            final matchedByUser = oldRecord['user_id'] != null && oldRecord['user_id'] == myId;
            if (matchedById || matchedByUser) {
              print('📡 [退会検知] 自分($myId)の削除を検知 (byId=$matchedById byUser=$matchedByUser) → 退会状態へ');
              markKicked();
            }
          },
        )
        .subscribe((status, [error]) {
          // 再接続時にもメンバー状態を再確認する (イベント取りこぼし対策)
          print('🔌 [退会検知] チャンネルstatus: $status room=$roomId error=$error');
          if (status == RealtimeSubscribeStatus.subscribed) {
            _checkMembership();
          }
        });
  }

  @override
  void dispose() {
    _disposed = true;
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
