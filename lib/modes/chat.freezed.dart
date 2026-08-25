// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Chat {

 String get id; String get roomId; String get senderId; String get content; DateTime get createdAt; String? get imageUrl; String? get replyToId; String? get replyToContent; String? get replyToUserName;
/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatCopyWith<Chat> get copyWith => _$ChatCopyWithImpl<Chat>(this as Chat, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Chat&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToContent, replyToContent) || other.replyToContent == replyToContent)&&(identical(other.replyToUserName, replyToUserName) || other.replyToUserName == replyToUserName));
}


@override
int get hashCode => Object.hash(runtimeType,id,roomId,senderId,content,createdAt,imageUrl,replyToId,replyToContent,replyToUserName);

@override
String toString() {
  return 'Chat(id: $id, roomId: $roomId, senderId: $senderId, content: $content, createdAt: $createdAt, imageUrl: $imageUrl, replyToId: $replyToId, replyToContent: $replyToContent, replyToUserName: $replyToUserName)';
}


}

/// @nodoc
abstract mixin class $ChatCopyWith<$Res>  {
  factory $ChatCopyWith(Chat value, $Res Function(Chat) _then) = _$ChatCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, String senderId, String content, DateTime createdAt, String? imageUrl, String? replyToId, String? replyToContent, String? replyToUserName
});




}
/// @nodoc
class _$ChatCopyWithImpl<$Res>
    implements $ChatCopyWith<$Res> {
  _$ChatCopyWithImpl(this._self, this._then);

  final Chat _self;
  final $Res Function(Chat) _then;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? senderId = null,Object? content = null,Object? createdAt = null,Object? imageUrl = freezed,Object? replyToId = freezed,Object? replyToContent = freezed,Object? replyToUserName = freezed,}) {
  return _then(Chat(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToContent: freezed == replyToContent ? _self.replyToContent : replyToContent // ignore: cast_nullable_to_non_nullable
as String?,replyToUserName: freezed == replyToUserName ? _self.replyToUserName : replyToUserName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Chat].
extension ChatPatterns on Chat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Chat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Chat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Chat value)  $default,){
final _that = this;
switch (_that) {
case _Chat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Chat value)?  $default,){
final _that = this;
switch (_that) {
case _Chat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  String senderId,  String content,  DateTime createdAt,  String? imageUrl,  String? replyToId,  String? replyToContent,  String? replyToUserName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Chat() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.content,_that.createdAt,_that.imageUrl,_that.replyToId,_that.replyToContent,_that.replyToUserName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  String senderId,  String content,  DateTime createdAt,  String? imageUrl,  String? replyToId,  String? replyToContent,  String? replyToUserName)  $default,) {final _that = this;
switch (_that) {
case _Chat():
return $default(_that.id,_that.roomId,_that.senderId,_that.content,_that.createdAt,_that.imageUrl,_that.replyToId,_that.replyToContent,_that.replyToUserName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  String senderId,  String content,  DateTime createdAt,  String? imageUrl,  String? replyToId,  String? replyToContent,  String? replyToUserName)?  $default,) {final _that = this;
switch (_that) {
case _Chat() when $default != null:
return $default(_that.id,_that.roomId,_that.senderId,_that.content,_that.createdAt,_that.imageUrl,_that.replyToId,_that.replyToContent,_that.replyToUserName);case _:
  return null;

}
}

}

/// @nodoc


class _Chat implements Chat {
   _Chat({required this.id, required this.roomId, required this.senderId, required this.content, required this.createdAt, this.imageUrl, this.replyToId, this.replyToContent, this.replyToUserName});
  

@override final  String id;
@override final  String roomId;
@override final  String senderId;
@override final  String content;
@override final  DateTime createdAt;
@override final  String? imageUrl;
@override final  String? replyToId;
@override final  String? replyToContent;
@override final  String? replyToUserName;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatCopyWith<_Chat> get copyWith => __$ChatCopyWithImpl<_Chat>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Chat&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToContent, replyToContent) || other.replyToContent == replyToContent)&&(identical(other.replyToUserName, replyToUserName) || other.replyToUserName == replyToUserName));
}


@override
int get hashCode => Object.hash(runtimeType,id,roomId,senderId,content,createdAt,imageUrl,replyToId,replyToContent,replyToUserName);

@override
String toString() {
  return 'Chat(id: $id, roomId: $roomId, senderId: $senderId, content: $content, createdAt: $createdAt, imageUrl: $imageUrl, replyToId: $replyToId, replyToContent: $replyToContent, replyToUserName: $replyToUserName)';
}


}

/// @nodoc
abstract mixin class _$ChatCopyWith<$Res> implements $ChatCopyWith<$Res> {
  factory _$ChatCopyWith(_Chat value, $Res Function(_Chat) _then) = __$ChatCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, String senderId, String content, DateTime createdAt, String? imageUrl, String? replyToId, String? replyToContent, String? replyToUserName
});




}
/// @nodoc
class __$ChatCopyWithImpl<$Res>
    implements _$ChatCopyWith<$Res> {
  __$ChatCopyWithImpl(this._self, this._then);

  final _Chat _self;
  final $Res Function(_Chat) _then;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? senderId = null,Object? content = null,Object? createdAt = null,Object? imageUrl = freezed,Object? replyToId = freezed,Object? replyToContent = freezed,Object? replyToUserName = freezed,}) {
  return _then(_Chat(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToContent: freezed == replyToContent ? _self.replyToContent : replyToContent // ignore: cast_nullable_to_non_nullable
as String?,replyToUserName: freezed == replyToUserName ? _self.replyToUserName : replyToUserName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
