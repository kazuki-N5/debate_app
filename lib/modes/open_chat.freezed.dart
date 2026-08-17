// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

OpenChatRoom _$OpenChatRoomFromJson(Map<String, dynamic> json) {
  return _OpenChatRoom.fromJson(json);
}

/// @nodoc
mixin _$OpenChatRoom {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'icon_url')
  String? get iconUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'background_url')
  String? get backgroundUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'password')
  String? get password => throw _privateConstructorUsedError;
  @JsonKey(name: 'owner_id')
  String get ownerId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError; // 追加情報（一覧表示用など）
  @JsonKey(name: 'member_count')
  int? get memberCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_joined')
  bool? get isJoined => throw _privateConstructorUsedError;

  /// Serializes this OpenChatRoom to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OpenChatRoom
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OpenChatRoomCopyWith<OpenChatRoom> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OpenChatRoomCopyWith<$Res> {
  factory $OpenChatRoomCopyWith(
          OpenChatRoom value, $Res Function(OpenChatRoom) then) =
      _$OpenChatRoomCopyWithImpl<$Res, OpenChatRoom>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      @JsonKey(name: 'icon_url') String? iconUrl,
      @JsonKey(name: 'background_url') String? backgroundUrl,
      @JsonKey(name: 'password') String? password,
      @JsonKey(name: 'owner_id') String ownerId,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'member_count') int? memberCount,
      @JsonKey(name: 'is_joined') bool? isJoined});
}

/// @nodoc
class _$OpenChatRoomCopyWithImpl<$Res, $Val extends OpenChatRoom>
    implements $OpenChatRoomCopyWith<$Res> {
  _$OpenChatRoomCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OpenChatRoom
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? iconUrl = freezed,
    Object? backgroundUrl = freezed,
    Object? password = freezed,
    Object? ownerId = null,
    Object? createdAt = null,
    Object? memberCount = freezed,
    Object? isJoined = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      iconUrl: freezed == iconUrl
          ? _value.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      backgroundUrl: freezed == backgroundUrl
          ? _value.backgroundUrl
          : backgroundUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      password: freezed == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: null == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      memberCount: freezed == memberCount
          ? _value.memberCount
          : memberCount // ignore: cast_nullable_to_non_nullable
              as int?,
      isJoined: freezed == isJoined
          ? _value.isJoined
          : isJoined // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OpenChatRoomImplCopyWith<$Res>
    implements $OpenChatRoomCopyWith<$Res> {
  factory _$$OpenChatRoomImplCopyWith(
          _$OpenChatRoomImpl value, $Res Function(_$OpenChatRoomImpl) then) =
      __$$OpenChatRoomImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      @JsonKey(name: 'icon_url') String? iconUrl,
      @JsonKey(name: 'background_url') String? backgroundUrl,
      @JsonKey(name: 'password') String? password,
      @JsonKey(name: 'owner_id') String ownerId,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'member_count') int? memberCount,
      @JsonKey(name: 'is_joined') bool? isJoined});
}

/// @nodoc
class __$$OpenChatRoomImplCopyWithImpl<$Res>
    extends _$OpenChatRoomCopyWithImpl<$Res, _$OpenChatRoomImpl>
    implements _$$OpenChatRoomImplCopyWith<$Res> {
  __$$OpenChatRoomImplCopyWithImpl(
      _$OpenChatRoomImpl _value, $Res Function(_$OpenChatRoomImpl) _then)
      : super(_value, _then);

  /// Create a copy of OpenChatRoom
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? iconUrl = freezed,
    Object? backgroundUrl = freezed,
    Object? password = freezed,
    Object? ownerId = null,
    Object? createdAt = null,
    Object? memberCount = freezed,
    Object? isJoined = freezed,
  }) {
    return _then(_$OpenChatRoomImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      iconUrl: freezed == iconUrl
          ? _value.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      backgroundUrl: freezed == backgroundUrl
          ? _value.backgroundUrl
          : backgroundUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      password: freezed == password
          ? _value.password
          : password // ignore: cast_nullable_to_non_nullable
              as String?,
      ownerId: null == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      memberCount: freezed == memberCount
          ? _value.memberCount
          : memberCount // ignore: cast_nullable_to_non_nullable
              as int?,
      isJoined: freezed == isJoined
          ? _value.isJoined
          : isJoined // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OpenChatRoomImpl implements _OpenChatRoom {
  _$OpenChatRoomImpl(
      {required this.id,
      required this.name,
      this.description,
      @JsonKey(name: 'icon_url') this.iconUrl,
      @JsonKey(name: 'background_url') this.backgroundUrl,
      @JsonKey(name: 'password') this.password,
      @JsonKey(name: 'owner_id') required this.ownerId,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'member_count') this.memberCount,
      @JsonKey(name: 'is_joined') this.isJoined});

  factory _$OpenChatRoomImpl.fromJson(Map<String, dynamic> json) =>
      _$$OpenChatRoomImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey(name: 'icon_url')
  final String? iconUrl;
  @override
  @JsonKey(name: 'background_url')
  final String? backgroundUrl;
  @override
  @JsonKey(name: 'password')
  final String? password;
  @override
  @JsonKey(name: 'owner_id')
  final String ownerId;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
// 追加情報（一覧表示用など）
  @override
  @JsonKey(name: 'member_count')
  final int? memberCount;
  @override
  @JsonKey(name: 'is_joined')
  final bool? isJoined;

  @override
  String toString() {
    return 'OpenChatRoom(id: $id, name: $name, description: $description, iconUrl: $iconUrl, backgroundUrl: $backgroundUrl, password: $password, ownerId: $ownerId, createdAt: $createdAt, memberCount: $memberCount, isJoined: $isJoined)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OpenChatRoomImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.backgroundUrl, backgroundUrl) ||
                other.backgroundUrl == backgroundUrl) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.memberCount, memberCount) ||
                other.memberCount == memberCount) &&
            (identical(other.isJoined, isJoined) ||
                other.isJoined == isJoined));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description, iconUrl,
      backgroundUrl, password, ownerId, createdAt, memberCount, isJoined);

  /// Create a copy of OpenChatRoom
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OpenChatRoomImplCopyWith<_$OpenChatRoomImpl> get copyWith =>
      __$$OpenChatRoomImplCopyWithImpl<_$OpenChatRoomImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OpenChatRoomImplToJson(
      this,
    );
  }
}

abstract class _OpenChatRoom implements OpenChatRoom {
  factory _OpenChatRoom(
      {required final String id,
      required final String name,
      final String? description,
      @JsonKey(name: 'icon_url') final String? iconUrl,
      @JsonKey(name: 'background_url') final String? backgroundUrl,
      @JsonKey(name: 'password') final String? password,
      @JsonKey(name: 'owner_id') required final String ownerId,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'member_count') final int? memberCount,
      @JsonKey(name: 'is_joined') final bool? isJoined}) = _$OpenChatRoomImpl;

  factory _OpenChatRoom.fromJson(Map<String, dynamic> json) =
      _$OpenChatRoomImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  @JsonKey(name: 'icon_url')
  String? get iconUrl;
  @override
  @JsonKey(name: 'background_url')
  String? get backgroundUrl;
  @override
  @JsonKey(name: 'password')
  String? get password;
  @override
  @JsonKey(name: 'owner_id')
  String get ownerId;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt; // 追加情報（一覧表示用など）
  @override
  @JsonKey(name: 'member_count')
  int? get memberCount;
  @override
  @JsonKey(name: 'is_joined')
  bool? get isJoined;

  /// Create a copy of OpenChatRoom
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OpenChatRoomImplCopyWith<_$OpenChatRoomImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OpenChatMember _$OpenChatMemberFromJson(Map<String, dynamic> json) {
  return _OpenChatMember.fromJson(json);
}

/// @nodoc
mixin _$OpenChatMember {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'room_id')
  String get roomId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt => throw _privateConstructorUsedError;

  /// Serializes this OpenChatMember to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OpenChatMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OpenChatMemberCopyWith<OpenChatMember> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OpenChatMemberCopyWith<$Res> {
  factory $OpenChatMemberCopyWith(
          OpenChatMember value, $Res Function(OpenChatMember) then) =
      _$OpenChatMemberCopyWithImpl<$Res, OpenChatMember>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'room_id') String roomId,
      @JsonKey(name: 'user_id') String userId,
      String role,
      @JsonKey(name: 'joined_at') DateTime joinedAt});
}

/// @nodoc
class _$OpenChatMemberCopyWithImpl<$Res, $Val extends OpenChatMember>
    implements $OpenChatMemberCopyWith<$Res> {
  _$OpenChatMemberCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OpenChatMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? userId = null,
    Object? role = null,
    Object? joinedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      joinedAt: null == joinedAt
          ? _value.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OpenChatMemberImplCopyWith<$Res>
    implements $OpenChatMemberCopyWith<$Res> {
  factory _$$OpenChatMemberImplCopyWith(_$OpenChatMemberImpl value,
          $Res Function(_$OpenChatMemberImpl) then) =
      __$$OpenChatMemberImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'room_id') String roomId,
      @JsonKey(name: 'user_id') String userId,
      String role,
      @JsonKey(name: 'joined_at') DateTime joinedAt});
}

/// @nodoc
class __$$OpenChatMemberImplCopyWithImpl<$Res>
    extends _$OpenChatMemberCopyWithImpl<$Res, _$OpenChatMemberImpl>
    implements _$$OpenChatMemberImplCopyWith<$Res> {
  __$$OpenChatMemberImplCopyWithImpl(
      _$OpenChatMemberImpl _value, $Res Function(_$OpenChatMemberImpl) _then)
      : super(_value, _then);

  /// Create a copy of OpenChatMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? userId = null,
    Object? role = null,
    Object? joinedAt = null,
  }) {
    return _then(_$OpenChatMemberImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      joinedAt: null == joinedAt
          ? _value.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OpenChatMemberImpl implements _OpenChatMember {
  _$OpenChatMemberImpl(
      {required this.id,
      @JsonKey(name: 'room_id') required this.roomId,
      @JsonKey(name: 'user_id') required this.userId,
      required this.role,
      @JsonKey(name: 'joined_at') required this.joinedAt});

  factory _$OpenChatMemberImpl.fromJson(Map<String, dynamic> json) =>
      _$$OpenChatMemberImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'room_id')
  final String roomId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final String role;
  @override
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;

  @override
  String toString() {
    return 'OpenChatMember(id: $id, roomId: $roomId, userId: $userId, role: $role, joinedAt: $joinedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OpenChatMemberImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, roomId, userId, role, joinedAt);

  /// Create a copy of OpenChatMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OpenChatMemberImplCopyWith<_$OpenChatMemberImpl> get copyWith =>
      __$$OpenChatMemberImplCopyWithImpl<_$OpenChatMemberImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OpenChatMemberImplToJson(
      this,
    );
  }
}

abstract class _OpenChatMember implements OpenChatMember {
  factory _OpenChatMember(
          {required final String id,
          @JsonKey(name: 'room_id') required final String roomId,
          @JsonKey(name: 'user_id') required final String userId,
          required final String role,
          @JsonKey(name: 'joined_at') required final DateTime joinedAt}) =
      _$OpenChatMemberImpl;

  factory _OpenChatMember.fromJson(Map<String, dynamic> json) =
      _$OpenChatMemberImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'room_id')
  String get roomId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  String get role;
  @override
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt;

  /// Create a copy of OpenChatMember
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OpenChatMemberImplCopyWith<_$OpenChatMemberImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OpenChatMessage _$OpenChatMessageFromJson(Map<String, dynamic> json) {
  return _OpenChatMessage.fromJson(json);
}

/// @nodoc
mixin _$OpenChatMessage {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'room_id')
  String get roomId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;

  /// Serializes this OpenChatMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OpenChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OpenChatMessageCopyWith<OpenChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OpenChatMessageCopyWith<$Res> {
  factory $OpenChatMessageCopyWith(
          OpenChatMessage value, $Res Function(OpenChatMessage) then) =
      _$OpenChatMessageCopyWithImpl<$Res, OpenChatMessage>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'room_id') String roomId,
      @JsonKey(name: 'user_id') String userId,
      String content,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'image_url') String? imageUrl});
}

/// @nodoc
class _$OpenChatMessageCopyWithImpl<$Res, $Val extends OpenChatMessage>
    implements $OpenChatMessageCopyWith<$Res> {
  _$OpenChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OpenChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? userId = null,
    Object? content = null,
    Object? createdAt = null,
    Object? imageUrl = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OpenChatMessageImplCopyWith<$Res>
    implements $OpenChatMessageCopyWith<$Res> {
  factory _$$OpenChatMessageImplCopyWith(_$OpenChatMessageImpl value,
          $Res Function(_$OpenChatMessageImpl) then) =
      __$$OpenChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'room_id') String roomId,
      @JsonKey(name: 'user_id') String userId,
      String content,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'image_url') String? imageUrl});
}

/// @nodoc
class __$$OpenChatMessageImplCopyWithImpl<$Res>
    extends _$OpenChatMessageCopyWithImpl<$Res, _$OpenChatMessageImpl>
    implements _$$OpenChatMessageImplCopyWith<$Res> {
  __$$OpenChatMessageImplCopyWithImpl(
      _$OpenChatMessageImpl _value, $Res Function(_$OpenChatMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of OpenChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? userId = null,
    Object? content = null,
    Object? createdAt = null,
    Object? imageUrl = freezed,
  }) {
    return _then(_$OpenChatMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OpenChatMessageImpl implements _OpenChatMessage {
  _$OpenChatMessageImpl(
      {required this.id,
      @JsonKey(name: 'room_id') required this.roomId,
      @JsonKey(name: 'user_id') required this.userId,
      required this.content,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'image_url') this.imageUrl});

  factory _$OpenChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$OpenChatMessageImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'room_id')
  final String roomId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final String content;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;

  @override
  String toString() {
    return 'OpenChatMessage(id: $id, roomId: $roomId, userId: $userId, content: $content, createdAt: $createdAt, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OpenChatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, roomId, userId, content, createdAt, imageUrl);

  /// Create a copy of OpenChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OpenChatMessageImplCopyWith<_$OpenChatMessageImpl> get copyWith =>
      __$$OpenChatMessageImplCopyWithImpl<_$OpenChatMessageImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OpenChatMessageImplToJson(
      this,
    );
  }
}

abstract class _OpenChatMessage implements OpenChatMessage {
  factory _OpenChatMessage(
          {required final String id,
          @JsonKey(name: 'room_id') required final String roomId,
          @JsonKey(name: 'user_id') required final String userId,
          required final String content,
          @JsonKey(name: 'created_at') required final DateTime createdAt,
          @JsonKey(name: 'image_url') final String? imageUrl}) =
      _$OpenChatMessageImpl;

  factory _OpenChatMessage.fromJson(Map<String, dynamic> json) =
      _$OpenChatMessageImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'room_id')
  String get roomId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  String get content;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;

  /// Create a copy of OpenChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OpenChatMessageImplCopyWith<_$OpenChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
