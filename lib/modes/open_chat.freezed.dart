// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenChatRoom {

 String get id; String get name; String? get description;@JsonKey(name: 'icon_url') String? get iconUrl;@JsonKey(name: 'background_url') String? get backgroundUrl;@JsonKey(name: 'password') String? get password;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'member_count') int? get memberCount;@JsonKey(name: 'is_joined') bool? get isJoined;@JsonKey(name: 'tags') List<String>? get tags;@JsonKey(name: 'rules') String? get rules;
/// Create a copy of OpenChatRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenChatRoomCopyWith<OpenChatRoom> get copyWith => _$OpenChatRoomCopyWithImpl<OpenChatRoom>(this as OpenChatRoom, _$identity);

  /// Serializes this OpenChatRoom to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenChatRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.backgroundUrl, backgroundUrl) || other.backgroundUrl == backgroundUrl)&&(identical(other.password, password) || other.password == password)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.isJoined, isJoined) || other.isJoined == isJoined)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.rules, rules) || other.rules == rules));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,iconUrl,backgroundUrl,password,createdAt,memberCount,isJoined,const DeepCollectionEquality().hash(tags),rules);

@override
String toString() {
  return 'OpenChatRoom(id: $id, name: $name, description: $description, iconUrl: $iconUrl, backgroundUrl: $backgroundUrl, password: $password, createdAt: $createdAt, memberCount: $memberCount, isJoined: $isJoined, tags: $tags, rules: $rules)';
}


}

/// @nodoc
abstract mixin class $OpenChatRoomCopyWith<$Res>  {
  factory $OpenChatRoomCopyWith(OpenChatRoom value, $Res Function(OpenChatRoom) _then) = _$OpenChatRoomCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description,@JsonKey(name: 'icon_url') String? iconUrl,@JsonKey(name: 'background_url') String? backgroundUrl,@JsonKey(name: 'password') String? password,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'member_count') int? memberCount,@JsonKey(name: 'is_joined') bool? isJoined,@JsonKey(name: 'tags') List<String>? tags,@JsonKey(name: 'rules') String? rules
});




}
/// @nodoc
class _$OpenChatRoomCopyWithImpl<$Res>
    implements $OpenChatRoomCopyWith<$Res> {
  _$OpenChatRoomCopyWithImpl(this._self, this._then);

  final OpenChatRoom _self;
  final $Res Function(OpenChatRoom) _then;

/// Create a copy of OpenChatRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? iconUrl = freezed,Object? backgroundUrl = freezed,Object? password = freezed,Object? createdAt = null,Object? memberCount = freezed,Object? isJoined = freezed,Object? tags = freezed,Object? rules = freezed,}) {
  return _then(OpenChatRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,backgroundUrl: freezed == backgroundUrl ? _self.backgroundUrl : backgroundUrl // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,memberCount: freezed == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int?,isJoined: freezed == isJoined ? _self.isJoined : isJoined // ignore: cast_nullable_to_non_nullable
as bool?,tags: freezed == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,rules: freezed == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OpenChatRoom].
extension OpenChatRoomPatterns on OpenChatRoom {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpenChatRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpenChatRoom() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpenChatRoom value)  $default,){
final _that = this;
switch (_that) {
case _OpenChatRoom():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpenChatRoom value)?  $default,){
final _that = this;
switch (_that) {
case _OpenChatRoom() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description, @JsonKey(name: 'icon_url')  String? iconUrl, @JsonKey(name: 'background_url')  String? backgroundUrl, @JsonKey(name: 'password')  String? password, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'member_count')  int? memberCount, @JsonKey(name: 'is_joined')  bool? isJoined, @JsonKey(name: 'tags')  List<String>? tags, @JsonKey(name: 'rules')  String? rules)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpenChatRoom() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.iconUrl,_that.backgroundUrl,_that.password,_that.createdAt,_that.memberCount,_that.isJoined,_that.tags,_that.rules);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description, @JsonKey(name: 'icon_url')  String? iconUrl, @JsonKey(name: 'background_url')  String? backgroundUrl, @JsonKey(name: 'password')  String? password, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'member_count')  int? memberCount, @JsonKey(name: 'is_joined')  bool? isJoined, @JsonKey(name: 'tags')  List<String>? tags, @JsonKey(name: 'rules')  String? rules)  $default,) {final _that = this;
switch (_that) {
case _OpenChatRoom():
return $default(_that.id,_that.name,_that.description,_that.iconUrl,_that.backgroundUrl,_that.password,_that.createdAt,_that.memberCount,_that.isJoined,_that.tags,_that.rules);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description, @JsonKey(name: 'icon_url')  String? iconUrl, @JsonKey(name: 'background_url')  String? backgroundUrl, @JsonKey(name: 'password')  String? password, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'member_count')  int? memberCount, @JsonKey(name: 'is_joined')  bool? isJoined, @JsonKey(name: 'tags')  List<String>? tags, @JsonKey(name: 'rules')  String? rules)?  $default,) {final _that = this;
switch (_that) {
case _OpenChatRoom() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.iconUrl,_that.backgroundUrl,_that.password,_that.createdAt,_that.memberCount,_that.isJoined,_that.tags,_that.rules);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OpenChatRoom implements OpenChatRoom {
   _OpenChatRoom({required this.id, required this.name, this.description, @JsonKey(name: 'icon_url') this.iconUrl, @JsonKey(name: 'background_url') this.backgroundUrl, @JsonKey(name: 'password') this.password, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'member_count') this.memberCount, @JsonKey(name: 'is_joined') this.isJoined, @JsonKey(name: 'tags')  List<String>? tags, @JsonKey(name: 'rules') this.rules}): _tags = tags;
  factory _OpenChatRoom.fromJson(Map<String, dynamic> json) => _$OpenChatRoomFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override@JsonKey(name: 'icon_url') final  String? iconUrl;
@override@JsonKey(name: 'background_url') final  String? backgroundUrl;
@override@JsonKey(name: 'password') final  String? password;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'member_count') final  int? memberCount;
@override@JsonKey(name: 'is_joined') final  bool? isJoined;
 final  List<String>? _tags;
@override@JsonKey(name: 'tags') List<String>? get tags {
  final value = _tags;
  if (value == null) return null;
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'rules') final  String? rules;

/// Create a copy of OpenChatRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenChatRoomCopyWith<_OpenChatRoom> get copyWith => __$OpenChatRoomCopyWithImpl<_OpenChatRoom>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenChatRoomToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenChatRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.backgroundUrl, backgroundUrl) || other.backgroundUrl == backgroundUrl)&&(identical(other.password, password) || other.password == password)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.isJoined, isJoined) || other.isJoined == isJoined)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.rules, rules) || other.rules == rules));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,iconUrl,backgroundUrl,password,createdAt,memberCount,isJoined,const DeepCollectionEquality().hash(_tags),rules);

@override
String toString() {
  return 'OpenChatRoom(id: $id, name: $name, description: $description, iconUrl: $iconUrl, backgroundUrl: $backgroundUrl, password: $password, createdAt: $createdAt, memberCount: $memberCount, isJoined: $isJoined, tags: $tags, rules: $rules)';
}


}

/// @nodoc
abstract mixin class _$OpenChatRoomCopyWith<$Res> implements $OpenChatRoomCopyWith<$Res> {
  factory _$OpenChatRoomCopyWith(_OpenChatRoom value, $Res Function(_OpenChatRoom) _then) = __$OpenChatRoomCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description,@JsonKey(name: 'icon_url') String? iconUrl,@JsonKey(name: 'background_url') String? backgroundUrl,@JsonKey(name: 'password') String? password,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'member_count') int? memberCount,@JsonKey(name: 'is_joined') bool? isJoined,@JsonKey(name: 'tags') List<String>? tags,@JsonKey(name: 'rules') String? rules
});




}
/// @nodoc
class __$OpenChatRoomCopyWithImpl<$Res>
    implements _$OpenChatRoomCopyWith<$Res> {
  __$OpenChatRoomCopyWithImpl(this._self, this._then);

  final _OpenChatRoom _self;
  final $Res Function(_OpenChatRoom) _then;

/// Create a copy of OpenChatRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? iconUrl = freezed,Object? backgroundUrl = freezed,Object? password = freezed,Object? createdAt = null,Object? memberCount = freezed,Object? isJoined = freezed,Object? tags = freezed,Object? rules = freezed,}) {
  return _then(_OpenChatRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,backgroundUrl: freezed == backgroundUrl ? _self.backgroundUrl : backgroundUrl // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,memberCount: freezed == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int?,isJoined: freezed == isJoined ? _self.isJoined : isJoined // ignore: cast_nullable_to_non_nullable
as bool?,tags: freezed == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,rules: freezed == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OpenChatMember {

 String get id;@JsonKey(name: 'room_id') String get roomId;@JsonKey(name: 'user_id') String get userId; String get role;@JsonKey(name: 'joined_at') DateTime get joinedAt;@JsonKey(name: 'is_muted') bool get isMuted;
/// Create a copy of OpenChatMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenChatMemberCopyWith<OpenChatMember> get copyWith => _$OpenChatMemberCopyWithImpl<OpenChatMember>(this as OpenChatMember, _$identity);

  /// Serializes this OpenChatMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenChatMember&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,userId,role,joinedAt,isMuted);

@override
String toString() {
  return 'OpenChatMember(id: $id, roomId: $roomId, userId: $userId, role: $role, joinedAt: $joinedAt, isMuted: $isMuted)';
}


}

/// @nodoc
abstract mixin class $OpenChatMemberCopyWith<$Res>  {
  factory $OpenChatMemberCopyWith(OpenChatMember value, $Res Function(OpenChatMember) _then) = _$OpenChatMemberCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'room_id') String roomId,@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'joined_at') DateTime joinedAt,@JsonKey(name: 'is_muted') bool isMuted
});




}
/// @nodoc
class _$OpenChatMemberCopyWithImpl<$Res>
    implements $OpenChatMemberCopyWith<$Res> {
  _$OpenChatMemberCopyWithImpl(this._self, this._then);

  final OpenChatMember _self;
  final $Res Function(OpenChatMember) _then;

/// Create a copy of OpenChatMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? userId = null,Object? role = null,Object? joinedAt = null,Object? isMuted = null,}) {
  return _then(OpenChatMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [OpenChatMember].
extension OpenChatMemberPatterns on OpenChatMember {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpenChatMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpenChatMember() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpenChatMember value)  $default,){
final _that = this;
switch (_that) {
case _OpenChatMember():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpenChatMember value)?  $default,){
final _that = this;
switch (_that) {
case _OpenChatMember() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'room_id')  String roomId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  DateTime joinedAt, @JsonKey(name: 'is_muted')  bool isMuted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpenChatMember() when $default != null:
return $default(_that.id,_that.roomId,_that.userId,_that.role,_that.joinedAt,_that.isMuted);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'room_id')  String roomId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  DateTime joinedAt, @JsonKey(name: 'is_muted')  bool isMuted)  $default,) {final _that = this;
switch (_that) {
case _OpenChatMember():
return $default(_that.id,_that.roomId,_that.userId,_that.role,_that.joinedAt,_that.isMuted);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'room_id')  String roomId, @JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'joined_at')  DateTime joinedAt, @JsonKey(name: 'is_muted')  bool isMuted)?  $default,) {final _that = this;
switch (_that) {
case _OpenChatMember() when $default != null:
return $default(_that.id,_that.roomId,_that.userId,_that.role,_that.joinedAt,_that.isMuted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OpenChatMember implements OpenChatMember {
   _OpenChatMember({required this.id, @JsonKey(name: 'room_id') required this.roomId, @JsonKey(name: 'user_id') required this.userId, required this.role, @JsonKey(name: 'joined_at') required this.joinedAt, @JsonKey(name: 'is_muted') this.isMuted = false});
  factory _OpenChatMember.fromJson(Map<String, dynamic> json) => _$OpenChatMemberFromJson(json);

@override final  String id;
@override@JsonKey(name: 'room_id') final  String roomId;
@override@JsonKey(name: 'user_id') final  String userId;
@override final  String role;
@override@JsonKey(name: 'joined_at') final  DateTime joinedAt;
@override@JsonKey(name: 'is_muted') final  bool isMuted;

/// Create a copy of OpenChatMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenChatMemberCopyWith<_OpenChatMember> get copyWith => __$OpenChatMemberCopyWithImpl<_OpenChatMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenChatMemberToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenChatMember&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,userId,role,joinedAt,isMuted);

@override
String toString() {
  return 'OpenChatMember(id: $id, roomId: $roomId, userId: $userId, role: $role, joinedAt: $joinedAt, isMuted: $isMuted)';
}


}

/// @nodoc
abstract mixin class _$OpenChatMemberCopyWith<$Res> implements $OpenChatMemberCopyWith<$Res> {
  factory _$OpenChatMemberCopyWith(_OpenChatMember value, $Res Function(_OpenChatMember) _then) = __$OpenChatMemberCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'room_id') String roomId,@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'joined_at') DateTime joinedAt,@JsonKey(name: 'is_muted') bool isMuted
});




}
/// @nodoc
class __$OpenChatMemberCopyWithImpl<$Res>
    implements _$OpenChatMemberCopyWith<$Res> {
  __$OpenChatMemberCopyWithImpl(this._self, this._then);

  final _OpenChatMember _self;
  final $Res Function(_OpenChatMember) _then;

/// Create a copy of OpenChatMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? userId = null,Object? role = null,Object? joinedAt = null,Object? isMuted = null,}) {
  return _then(_OpenChatMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$OpenChatMessage {

 String get id;@JsonKey(name: 'room_id') String get roomId;@JsonKey(name: 'user_id') String get userId; String get content;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'image_url') String? get imageUrl;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'is_admin_deleted') bool get isAdminDeleted;@JsonKey(name: 'is_system') bool get isSystem;@JsonKey(name: 'reply_to_id') String? get replyToId;@JsonKey(name: 'reply_to_content') String? get replyToContent;@JsonKey(name: 'reply_to_user_name') String? get replyToUserName;
/// Create a copy of OpenChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenChatMessageCopyWith<OpenChatMessage> get copyWith => _$OpenChatMessageCopyWithImpl<OpenChatMessage>(this as OpenChatMessage, _$identity);

  /// Serializes this OpenChatMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isAdminDeleted, isAdminDeleted) || other.isAdminDeleted == isAdminDeleted)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToContent, replyToContent) || other.replyToContent == replyToContent)&&(identical(other.replyToUserName, replyToUserName) || other.replyToUserName == replyToUserName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,userId,content,createdAt,imageUrl,isDeleted,isAdminDeleted,isSystem,replyToId,replyToContent,replyToUserName);

@override
String toString() {
  return 'OpenChatMessage(id: $id, roomId: $roomId, userId: $userId, content: $content, createdAt: $createdAt, imageUrl: $imageUrl, isDeleted: $isDeleted, isAdminDeleted: $isAdminDeleted, isSystem: $isSystem, replyToId: $replyToId, replyToContent: $replyToContent, replyToUserName: $replyToUserName)';
}


}

/// @nodoc
abstract mixin class $OpenChatMessageCopyWith<$Res>  {
  factory $OpenChatMessageCopyWith(OpenChatMessage value, $Res Function(OpenChatMessage) _then) = _$OpenChatMessageCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'room_id') String roomId,@JsonKey(name: 'user_id') String userId, String content,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'image_url') String? imageUrl,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'is_admin_deleted') bool isAdminDeleted,@JsonKey(name: 'is_system') bool isSystem,@JsonKey(name: 'reply_to_id') String? replyToId,@JsonKey(name: 'reply_to_content') String? replyToContent,@JsonKey(name: 'reply_to_user_name') String? replyToUserName
});




}
/// @nodoc
class _$OpenChatMessageCopyWithImpl<$Res>
    implements $OpenChatMessageCopyWith<$Res> {
  _$OpenChatMessageCopyWithImpl(this._self, this._then);

  final OpenChatMessage _self;
  final $Res Function(OpenChatMessage) _then;

/// Create a copy of OpenChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? userId = null,Object? content = null,Object? createdAt = null,Object? imageUrl = freezed,Object? isDeleted = null,Object? isAdminDeleted = null,Object? isSystem = null,Object? replyToId = freezed,Object? replyToContent = freezed,Object? replyToUserName = freezed,}) {
  return _then(OpenChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isAdminDeleted: null == isAdminDeleted ? _self.isAdminDeleted : isAdminDeleted // ignore: cast_nullable_to_non_nullable
as bool,isSystem: null == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToContent: freezed == replyToContent ? _self.replyToContent : replyToContent // ignore: cast_nullable_to_non_nullable
as String?,replyToUserName: freezed == replyToUserName ? _self.replyToUserName : replyToUserName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OpenChatMessage].
extension OpenChatMessagePatterns on OpenChatMessage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpenChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpenChatMessage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpenChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _OpenChatMessage():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpenChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _OpenChatMessage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'room_id')  String roomId, @JsonKey(name: 'user_id')  String userId,  String content, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'is_admin_deleted')  bool isAdminDeleted, @JsonKey(name: 'is_system')  bool isSystem, @JsonKey(name: 'reply_to_id')  String? replyToId, @JsonKey(name: 'reply_to_content')  String? replyToContent, @JsonKey(name: 'reply_to_user_name')  String? replyToUserName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpenChatMessage() when $default != null:
return $default(_that.id,_that.roomId,_that.userId,_that.content,_that.createdAt,_that.imageUrl,_that.isDeleted,_that.isAdminDeleted,_that.isSystem,_that.replyToId,_that.replyToContent,_that.replyToUserName);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'room_id')  String roomId, @JsonKey(name: 'user_id')  String userId,  String content, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'is_admin_deleted')  bool isAdminDeleted, @JsonKey(name: 'is_system')  bool isSystem, @JsonKey(name: 'reply_to_id')  String? replyToId, @JsonKey(name: 'reply_to_content')  String? replyToContent, @JsonKey(name: 'reply_to_user_name')  String? replyToUserName)  $default,) {final _that = this;
switch (_that) {
case _OpenChatMessage():
return $default(_that.id,_that.roomId,_that.userId,_that.content,_that.createdAt,_that.imageUrl,_that.isDeleted,_that.isAdminDeleted,_that.isSystem,_that.replyToId,_that.replyToContent,_that.replyToUserName);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'room_id')  String roomId, @JsonKey(name: 'user_id')  String userId,  String content, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'is_admin_deleted')  bool isAdminDeleted, @JsonKey(name: 'is_system')  bool isSystem, @JsonKey(name: 'reply_to_id')  String? replyToId, @JsonKey(name: 'reply_to_content')  String? replyToContent, @JsonKey(name: 'reply_to_user_name')  String? replyToUserName)?  $default,) {final _that = this;
switch (_that) {
case _OpenChatMessage() when $default != null:
return $default(_that.id,_that.roomId,_that.userId,_that.content,_that.createdAt,_that.imageUrl,_that.isDeleted,_that.isAdminDeleted,_that.isSystem,_that.replyToId,_that.replyToContent,_that.replyToUserName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OpenChatMessage implements OpenChatMessage {
   _OpenChatMessage({required this.id, @JsonKey(name: 'room_id') required this.roomId, @JsonKey(name: 'user_id') required this.userId, required this.content, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'image_url') this.imageUrl, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'is_admin_deleted') this.isAdminDeleted = false, @JsonKey(name: 'is_system') this.isSystem = false, @JsonKey(name: 'reply_to_id') this.replyToId, @JsonKey(name: 'reply_to_content') this.replyToContent, @JsonKey(name: 'reply_to_user_name') this.replyToUserName});
  factory _OpenChatMessage.fromJson(Map<String, dynamic> json) => _$OpenChatMessageFromJson(json);

@override final  String id;
@override@JsonKey(name: 'room_id') final  String roomId;
@override@JsonKey(name: 'user_id') final  String userId;
@override final  String content;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'image_url') final  String? imageUrl;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'is_admin_deleted') final  bool isAdminDeleted;
@override@JsonKey(name: 'is_system') final  bool isSystem;
@override@JsonKey(name: 'reply_to_id') final  String? replyToId;
@override@JsonKey(name: 'reply_to_content') final  String? replyToContent;
@override@JsonKey(name: 'reply_to_user_name') final  String? replyToUserName;

/// Create a copy of OpenChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenChatMessageCopyWith<_OpenChatMessage> get copyWith => __$OpenChatMessageCopyWithImpl<_OpenChatMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenChatMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isAdminDeleted, isAdminDeleted) || other.isAdminDeleted == isAdminDeleted)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToContent, replyToContent) || other.replyToContent == replyToContent)&&(identical(other.replyToUserName, replyToUserName) || other.replyToUserName == replyToUserName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,roomId,userId,content,createdAt,imageUrl,isDeleted,isAdminDeleted,isSystem,replyToId,replyToContent,replyToUserName);

@override
String toString() {
  return 'OpenChatMessage(id: $id, roomId: $roomId, userId: $userId, content: $content, createdAt: $createdAt, imageUrl: $imageUrl, isDeleted: $isDeleted, isAdminDeleted: $isAdminDeleted, isSystem: $isSystem, replyToId: $replyToId, replyToContent: $replyToContent, replyToUserName: $replyToUserName)';
}


}

/// @nodoc
abstract mixin class _$OpenChatMessageCopyWith<$Res> implements $OpenChatMessageCopyWith<$Res> {
  factory _$OpenChatMessageCopyWith(_OpenChatMessage value, $Res Function(_OpenChatMessage) _then) = __$OpenChatMessageCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'room_id') String roomId,@JsonKey(name: 'user_id') String userId, String content,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'image_url') String? imageUrl,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'is_admin_deleted') bool isAdminDeleted,@JsonKey(name: 'is_system') bool isSystem,@JsonKey(name: 'reply_to_id') String? replyToId,@JsonKey(name: 'reply_to_content') String? replyToContent,@JsonKey(name: 'reply_to_user_name') String? replyToUserName
});




}
/// @nodoc
class __$OpenChatMessageCopyWithImpl<$Res>
    implements _$OpenChatMessageCopyWith<$Res> {
  __$OpenChatMessageCopyWithImpl(this._self, this._then);

  final _OpenChatMessage _self;
  final $Res Function(_OpenChatMessage) _then;

/// Create a copy of OpenChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? userId = null,Object? content = null,Object? createdAt = null,Object? imageUrl = freezed,Object? isDeleted = null,Object? isAdminDeleted = null,Object? isSystem = null,Object? replyToId = freezed,Object? replyToContent = freezed,Object? replyToUserName = freezed,}) {
  return _then(_OpenChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isAdminDeleted: null == isAdminDeleted ? _self.isAdminDeleted : isAdminDeleted // ignore: cast_nullable_to_non_nullable
as bool,isSystem: null == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToContent: freezed == replyToContent ? _self.replyToContent : replyToContent // ignore: cast_nullable_to_non_nullable
as String?,replyToUserName: freezed == replyToUserName ? _self.replyToUserName : replyToUserName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
