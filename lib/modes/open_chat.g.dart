// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OpenChatRoomImpl _$$OpenChatRoomImplFromJson(Map<String, dynamic> json) =>
    _$OpenChatRoomImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      backgroundUrl: json['background_url'] as String?,
      password: json['password'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      memberCount: (json['member_count'] as num?)?.toInt(),
      isJoined: json['is_joined'] as bool?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      rules: json['rules'] as String?,
    );

Map<String, dynamic> _$$OpenChatRoomImplToJson(_$OpenChatRoomImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'icon_url': instance.iconUrl,
      'background_url': instance.backgroundUrl,
      'password': instance.password,
      'created_at': instance.createdAt.toIso8601String(),
      'member_count': instance.memberCount,
      'is_joined': instance.isJoined,
      'tags': instance.tags,
      'rules': instance.rules,
    };

_$OpenChatMemberImpl _$$OpenChatMemberImplFromJson(Map<String, dynamic> json) =>
    _$OpenChatMemberImpl(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isMuted: json['is_muted'] as bool? ?? false,
    );

Map<String, dynamic> _$$OpenChatMemberImplToJson(
  _$OpenChatMemberImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'room_id': instance.roomId,
  'user_id': instance.userId,
  'role': instance.role,
  'joined_at': instance.joinedAt.toIso8601String(),
  'is_muted': instance.isMuted,
};

_$OpenChatMessageImpl _$$OpenChatMessageImplFromJson(
  Map<String, dynamic> json,
) => _$OpenChatMessageImpl(
  id: json['id'] as String,
  roomId: json['room_id'] as String,
  userId: json['user_id'] as String,
  content: json['content'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  imageUrl: json['image_url'] as String?,
  isDeleted: json['is_deleted'] as bool? ?? false,
  isAdminDeleted: json['is_admin_deleted'] as bool? ?? false,
  replyToId: json['reply_to_id'] as String?,
  replyToContent: json['reply_to_content'] as String?,
  replyToUserName: json['reply_to_user_name'] as String?,
);

Map<String, dynamic> _$$OpenChatMessageImplToJson(
  _$OpenChatMessageImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'room_id': instance.roomId,
  'user_id': instance.userId,
  'content': instance.content,
  'created_at': instance.createdAt.toIso8601String(),
  'image_url': instance.imageUrl,
  'is_deleted': instance.isDeleted,
  'is_admin_deleted': instance.isAdminDeleted,
  'reply_to_id': instance.replyToId,
  'reply_to_content': instance.replyToContent,
  'reply_to_user_name': instance.replyToUserName,
};
