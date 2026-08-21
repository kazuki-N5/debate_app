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
  }) = _OpenChatMessage;

  factory OpenChatMessage.fromJson(Map<String, dynamic> json) => _$OpenChatMessageFromJson(json);
}
