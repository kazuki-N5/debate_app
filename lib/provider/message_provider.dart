// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:async';
import 'dart:developer';

import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final chatProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, List<Chat>>((ref) {
  return ChatNotifier(ref);
});

class ChatNotifier extends StateNotifier<List<Chat>> {
  ChatNotifier(this._ref) : super([]);
  final Ref _ref;
  SupabaseClient get supabase => _ref.read(supabaseProvider);
  StreamSubscription? _messagesSubscription;

  /// ローカル専用メッセージかどうかを判定
  bool _isLocalMessage(Chat chat) {
    return chat.id.startsWith('temp_') ||
        chat.id.startsWith('sent_') ||
        chat.id.startsWith('error_');
  }

  Future<void> sendMesage(
    String roomId,
    String content, {
    String? replyToId,
    String? replyToContent,
    String? replyToUserName,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Optimistic UI: 生成した一時的なメッセージを即座にStateに追加
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempChat = Chat(
      id: tempId,
      roomId: roomId,
      senderId: userId,
      content: content,
      createdAt: DateTime.now(),
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToUserName: replyToUserName,
    );

    // インデックス0が最新になるように先頭に追加
    state = [tempChat, ...state];

    try {
      await supabase.from('messages').insert({
        'room_id': roomId,
        'sender_id': userId,
        'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (replyToContent != null) 'reply_to_content': replyToContent,
        if (replyToUserName != null) 'reply_to_user_name': replyToUserName,
      });
      // insert成功 → 仮IDを「sent_」に書き換えて即座に「送信」を表示
      state = state.map((chat) {
        if (chat.id == tempId) {
          return Chat(
            id: 'sent_$tempId',
            roomId: chat.roomId,
            senderId: chat.senderId,
            content: chat.content,
            createdAt: chat.createdAt,
            replyToId: chat.replyToId,
            replyToContent: chat.replyToContent,
            replyToUserName: chat.replyToUserName,
          );
        }
        return chat;
      }).toList();
    } catch (e) {
      log('メッセージ送信失敗: $e');
      // 送信失敗 → IDを「error_」に変更して位置を固定
      state = state.map((chat) {
        if (chat.id == tempId) {
          return Chat(
            id: 'error_$tempId',
            roomId: chat.roomId,
            senderId: chat.senderId,
            content: chat.content,
            createdAt: chat.createdAt,
            replyToId: chat.replyToId,
            replyToContent: chat.replyToContent,
            replyToUserName: chat.replyToUserName,
          );
        }
        return chat;
      }).toList();
    }
  }

  void subscribeToMessages(String roomId) {
    _messagesSubscription?.cancel();

    _messagesSubscription = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .listen(
          (data) {
            log('📩 メッセージデータを受信: ${data.length}件');
            for (final msg in data) {
              log('  ID: ${msg['id']}, sender: ${msg['sender_id']}, content: ${msg['content']}');
            }

            final dbMessages = data.map((e) => Chat.fromMap(e)).toList();

            // 現在のstateからローカル専用メッセージを抽出
            final localMessages =
                state.where((chat) => _isLocalMessage(chat)).toList();
            log('🔍 現在のstate内ローカルメッセージ: ${localMessages.length}件');
            for (final lm in localMessages) {
              log('  ローカル: ID=${lm.id}, content=${lm.content}');
            }

            // sent_ メッセージのうち、DBに同じ内容が存在するものは除外
            final remainingLocal = localMessages.where((local) {
              if (local.id.startsWith('sent_')) {
                return !dbMessages.any((db) =>
                    db.senderId == local.senderId &&
                    db.content == local.content);
              }
              return true;
            }).toList();
            log('🔍 マージ後に残すローカルメッセージ: ${remainingLocal.length}件');

            final tempAndSent = remainingLocal
                .where((c) =>
                    c.id.startsWith('temp_') || c.id.startsWith('sent_'))
                .toList();

            final errorMessages = remainingLocal
                .where((c) => c.id.startsWith('error_'))
                .toList();
            log('🔍 error_メッセージ: ${errorMessages.length}件');

            final merged = [...tempAndSent, ...dbMessages];

            for (final errMsg in errorMessages) {
              int insertIndex = merged.length;
              for (int i = 0; i < merged.length; i++) {
                if (errMsg.createdAt.isAfter(merged[i].createdAt) ||
                    errMsg.createdAt.isAtSameMomentAs(merged[i].createdAt)) {
                  insertIndex = i;
                  break;
                }
              }
              merged.insert(insertIndex, errMsg);
            }

            log('🔍 最終マージ結果: ${merged.length}件');
            state = merged;
          },
        );
  }

  void unsubscribeFromMessages() {
    _messagesSubscription?.cancel();
  }

  @override
  void dispose() {
    unsubscribeFromMessages();
    log('ChatNotifier disposed.');
    super.dispose();
  }
}
