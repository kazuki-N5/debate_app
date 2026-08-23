// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'open_chat.freezed.dart';
part 'open_chat.g.dart';

@freezed
class OpenChatRoom with _$OpenChatRoom {
  factory OpenChatRoom({
    required String id,
    required String name,
    String? description,
    @JsonKey(name: 'icon_url') String? iconUrl,
    @JsonKey(name: 'background_url') String? backgroundUrl,
    @JsonKey(name: 'password') String? password,
    @JsonKey(name: 'owner_id') required String ownerId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    // 追加情報（一覧表示用など）
    @JsonKey(name: 'member_count') int? memberCount,
    @JsonKey(name: 'is_joined') bool? isJoined,
    @JsonKey(name: 'tags') List<String>? tags,
    @JsonKey(name: 'rules') String? rules,
  }) = _OpenChatRoom;

  factory OpenChatRoom.fromJson(Map<String, dynamic> json) => _$OpenChatRoomFromJson(json);
}

@freezed
class OpenChatMember with _$OpenChatMember {
  factory OpenChatMember({
    required String id,
    @JsonKey(name: 'room_id') required String roomId,
    @JsonKey(name: 'user_id') required String userId,
    required String role,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
    @JsonKey(name: 'is_muted') @Default(false) bool isMuted,
  }) = _OpenChatMember;

  factory OpenChatMember.fromJson(Map<String, dynamic> json) => _$OpenChatMemberFromJson(json);
}

@freezed
class OpenChatMessage with _$OpenChatMessage {
  factory OpenChatMessage({
    required String id,
    @JsonKey(name: 'room_id') required String roomId,
    @JsonKey(name: 'user_id') required String userId,
    required String content,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'is_admin_deleted') @Default(false) bool isAdminDeleted,
    @JsonKey(name: 'reply_to_id') String? replyToId,
    @JsonKey(name: 'reply_to_content') String? replyToContent,
    @JsonKey(name: 'reply_to_user_name') String? replyToUserName,
  }) = _OpenChatMessage;

  factory OpenChatMessage.fromJson(Map<String, dynamic> json) => _$OpenChatMessageFromJson(json);
}

/// 再参加禁止（BAN）されたユーザーのモデル
class OpenChatBannedUser {
  final String id;
  final String roomId;
  final String userId;
  final DateTime createdAt;
  final String userName;
  final String? avatarUrl;

  const OpenChatBannedUser({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.createdAt,
    required this.userName,
    this.avatarUrl,
  });

  factory OpenChatBannedUser.fromJson(Map<String, dynamic> json) {
    return OpenChatBannedUser(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      userName: json['user_name'] as String? ?? '名無しユーザー',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
