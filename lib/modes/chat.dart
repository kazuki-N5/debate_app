// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';

@freezed
abstract class Chat with _$Chat {
  // クラス名は大文字始まり
  factory Chat({
    // コンストラクタも大文字
    required String id, // セミコロンではなくカンマ
    required String roomId,
    required String senderId,
    required String content,
    required DateTime createdAt,
    String? imageUrl,
    String? replyToId,
    String? replyToContent,
    String? replyToUserName,
  }) = _Chat;

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'].toString(),
      createdAt: DateTime.parse(map['created_at']),
      roomId: map['room_id'].toString(),
      content: map['content'],
      senderId: map['sender_id'].toString(),
      imageUrl: map['image_url']?.toString(),
      replyToId: map['reply_to_id']?.toString(),
      replyToContent: map['reply_to_content']?.toString(),
      replyToUserName: map['reply_to_user_name']?.toString(),
    );
  }

  
  // _Chatも大文字
}
