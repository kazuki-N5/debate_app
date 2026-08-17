// ignore_for_file: file_names, avoid_print
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// メッセージタブの一覧に表示する1件分のデータ
/// (DM or オプチャ の区別は [type] で判定)
class ChatInboxItem {
  final String type; // 'dm' | 'open_chat'
  final String roomId;
  final String title; // 相手名 or オプチャルーム名
  final String? avatarUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  // DM用
  final String? otherUserId;
  final String? otherUserName;

  // オプチャ用
  final OpenChatRoom? openChatRoom;

  const ChatInboxItem({
    required this.type,
    required this.roomId,
    required this.title,
    this.avatarUrl,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.otherUserId,
    this.otherUserName,
    this.openChatRoom,
  });

  bool get isDm => type == 'dm';
  bool get isOpenChat => type == 'open_chat';
}

/// DMとオプチャを1リストに統合したメッセージ一覧
/// 一括取得RPC (get_dm_inbox / get_open_chat_inbox) を利用して N+1 を回避。
/// RPC が未作成の環境(旧SQLのまま)では従来の個別クエリにフォールバックする。
final chatInboxProvider =
    FutureProvider.autoDispose<List<ChatInboxItem>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final myId = ref.read(currentUserIdProvider);
  if (myId == null) return [];

  final items = <ChatInboxItem>[];

  // ---------- DM ----------
  var dmRpcOk = false;
  try {
    final rows = await supabase.rpc('get_dm_inbox', params: {
      'p_user_id': myId,
    });
    for (final row in rows as List<dynamic>) {
      final r = row as Map<String, dynamic>;
      final otherName = r['other_user_name']?.toString() ?? '不明なユーザー';
      items.add(ChatInboxItem(
        type: 'dm',
        roomId: r['room_id'] as String,
        title: otherName,
        avatarUrl: r['other_avatar_url']?.toString(),
        lastMessage: r['last_message']?.toString() ?? '',
        lastMessageAt: r['last_message_at'] != null
            ? DateTime.parse(r['last_message_at'] as String).toLocal()
            : null,
        unreadCount: (r['unread_count'] as num?)?.toInt() ?? 0,
        otherUserId: r['other_user_id']?.toString(),
        otherUserName: otherName,
      ));
    }
    dmRpcOk = true;
  } catch (e) {
    print('get_dm_inbox RPC error: $e');
  }

  // RPC が無い場合は従来の個別クエリで取得 (フォールバック)
  if (!dmRpcOk) {
    try {
      final memberships = await supabase
          .from('dm_room_members')
          .select('room_id')
          .eq('user_id', myId);

      final roomIds = (memberships as List<dynamic>)
          .map((m) => m['room_id'] as String)
          .toList();

      for (final roomId in roomIds) {
        final members = await supabase
            .from('dm_room_members')
            .select('user_id')
            .eq('room_id', roomId);
        final otherId = (members as List<dynamic>)
            .map((m) => m['user_id'] as String)
            .where((uid) => uid != myId)
            .firstOrNull;
        if (otherId == null) continue;

        final otherUser = await supabase
            .from('users')
            .select()
            .eq('id', otherId)
            .maybeSingle();

        final lastMsg = await supabase
            .from('dm_messages')
            .select()
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        // 未読数 (フォールバックは is_read ベース。本番は RPC 側で last_read_at 方式)
        int unread = 0;
        try {
          final unreadRows = await supabase
              .from('dm_messages')
              .select('id')
              .eq('room_id', roomId)
              .eq('sender_id', otherId)
              .eq('is_read', false);
          unread = (unreadRows as List<dynamic>).length;
        } catch (e) {
          print('dm unread count error: $e');
        }

        final otherName = otherUser?['name']?.toString() ?? '不明なユーザー';
        items.add(ChatInboxItem(
          type: 'dm',
          roomId: roomId,
          title: otherName,
          avatarUrl: otherUser?['avatar_url']?.toString(),
          lastMessage: lastMsg?['content']?.toString() ?? '',
          lastMessageAt: lastMsg != null
              ? DateTime.parse(lastMsg['created_at'] as String).toLocal()
              : null,
          unreadCount: unread,
          otherUserId: otherId,
          otherUserName: otherName,
        ));
      }
    } catch (e) {
      print('DM inbox fallback error: $e');
    }
  }

  // ---------- オプチャ ----------
  var ocRpcOk = false;
  try {
    final rows = await supabase.rpc('get_open_chat_inbox', params: {
      'p_user_id': myId,
    });
    for (final row in rows as List<dynamic>) {
      final r = row as Map<String, dynamic>;
      final room = OpenChatRoom.fromJson(r['room'] as Map<String, dynamic>);
      String preview = '';
      if (r['last_message'] != null) {
        final senderName = r['last_message_user_name']?.toString() ?? '';
        final content = r['last_message']?.toString() ?? '';
        preview = senderName.isNotEmpty ? '$senderName: $content' : content;
      }
      items.add(ChatInboxItem(
        type: 'open_chat',
        roomId: room.id,
        title: room.name,
        avatarUrl: room.iconUrl,
        lastMessage: preview,
        lastMessageAt: r['last_message_at'] != null
            ? DateTime.parse(r['last_message_at'] as String).toLocal()
            : null,
        unreadCount: (r['unread_count'] as num?)?.toInt() ?? 0,
        openChatRoom: room,
      ));
    }
    ocRpcOk = true;
  } catch (e) {
    print('get_open_chat_inbox RPC error: $e');
  }

  // RPC が無い場合は従来の個別クエリで取得 (フォールバック)
  if (!ocRpcOk) {
    try {
      final memberships = await supabase
          .from('open_chat_members')
          .select('room_id')
          .eq('user_id', myId);

      final roomIds = (memberships as List<dynamic>)
          .map((m) => m['room_id'] as String)
          .toList();

      if (roomIds.isNotEmpty) {
        final roomsRes = await supabase
            .from('open_chat_rooms')
            .select()
            .inFilter('id', roomIds);

        for (final roomData in roomsRes as List<dynamic>) {
          final room = OpenChatRoom.fromJson(roomData as Map<String, dynamic>);
          final lastMsg = await supabase
              .from('open_chat_messages')
              .select('*, users!open_chat_messages_user_id_fkey(name)')
              .eq('room_id', room.id)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          String preview = '';
          if (lastMsg != null) {
            final senderName = lastMsg['users']?['name']?.toString() ?? '';
            final content = lastMsg['content']?.toString() ?? '';
            preview = senderName.isNotEmpty ? '$senderName: $content' : content;
          }

          items.add(ChatInboxItem(
            type: 'open_chat',
            roomId: room.id,
            title: room.name,
            avatarUrl: room.iconUrl,
            lastMessage: preview,
            lastMessageAt: lastMsg != null
                ? DateTime.parse(lastMsg['created_at'] as String).toLocal()
                : null,
            openChatRoom: room,
          ));
        }
      }
    } catch (e) {
      print('open chat inbox fallback error: $e');
    }
  }

  // 最新メッセージ順にソート (メッセージ無しは末尾)
  items.sort((a, b) {
    final at = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });

  return items;
});

/// DMルームを開いたときに既読化するヘルパー
final markDmReadProvider = Provider<MarkDmRead>((ref) {
  return MarkDmRead(ref.read(supabaseProvider));
});

class MarkDmRead {
  final SupabaseClient _supabase;
  MarkDmRead(this._supabase);

  Future<void> call(String roomId) async {
    try {
      await _supabase.rpc('mark_dm_room_read', params: {'p_room_id': roomId});
    } catch (e) {
      print('markDmRead error: $e');
    }
  }
}

/// オプチャルームを開いたときに既読化するヘルパー
final markOpenChatReadProvider = Provider<MarkOpenChatRead>((ref) {
  return MarkOpenChatRead(ref.read(supabaseProvider));
});

class MarkOpenChatRead {
  final SupabaseClient _supabase;
  MarkOpenChatRead(this._supabase);

  Future<void> call(String roomId) async {
    try {
      await _supabase
          .rpc('mark_open_chat_room_read', params: {'p_room_id': roomId});
    } catch (e) {
      print('markOpenChatRead error: $e');
    }
  }
}
