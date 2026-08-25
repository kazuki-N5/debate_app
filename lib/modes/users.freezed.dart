// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'users.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Users {

 String get id; String? get name; int get trophy; int? get win; int? get lose; String? get avatar_url; bool? get status; String? get fcm_token; bool? get is_notification_enabled; String? get bio; String? get header_url;
/// Create a copy of Users
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsersCopyWith<Users> get copyWith => _$UsersCopyWithImpl<Users>(this as Users, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Users&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.trophy, trophy) || other.trophy == trophy)&&(identical(other.win, win) || other.win == win)&&(identical(other.lose, lose) || other.lose == lose)&&(identical(other.avatar_url, avatar_url) || other.avatar_url == avatar_url)&&(identical(other.status, status) || other.status == status)&&(identical(other.fcm_token, fcm_token) || other.fcm_token == fcm_token)&&(identical(other.is_notification_enabled, is_notification_enabled) || other.is_notification_enabled == is_notification_enabled)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.header_url, header_url) || other.header_url == header_url));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,trophy,win,lose,avatar_url,status,fcm_token,is_notification_enabled,bio,header_url);

@override
String toString() {
  return 'Users(id: $id, name: $name, trophy: $trophy, win: $win, lose: $lose, avatar_url: $avatar_url, status: $status, fcm_token: $fcm_token, is_notification_enabled: $is_notification_enabled, bio: $bio, header_url: $header_url)';
}


}

/// @nodoc
abstract mixin class $UsersCopyWith<$Res>  {
  factory $UsersCopyWith(Users value, $Res Function(Users) _then) = _$UsersCopyWithImpl;
@useResult
$Res call({
 String id, String? name, int trophy, int? win, int? lose, String? avatar_url, bool? status, String? fcm_token, bool? is_notification_enabled, String? bio, String? header_url
});




}
/// @nodoc
class _$UsersCopyWithImpl<$Res>
    implements $UsersCopyWith<$Res> {
  _$UsersCopyWithImpl(this._self, this._then);

  final Users _self;
  final $Res Function(Users) _then;

/// Create a copy of Users
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? trophy = null,Object? win = freezed,Object? lose = freezed,Object? avatar_url = freezed,Object? status = freezed,Object? fcm_token = freezed,Object? is_notification_enabled = freezed,Object? bio = freezed,Object? header_url = freezed,}) {
  return _then(Users(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,trophy: null == trophy ? _self.trophy : trophy // ignore: cast_nullable_to_non_nullable
as int,win: freezed == win ? _self.win : win // ignore: cast_nullable_to_non_nullable
as int?,lose: freezed == lose ? _self.lose : lose // ignore: cast_nullable_to_non_nullable
as int?,avatar_url: freezed == avatar_url ? _self.avatar_url : avatar_url // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as bool?,fcm_token: freezed == fcm_token ? _self.fcm_token : fcm_token // ignore: cast_nullable_to_non_nullable
as String?,is_notification_enabled: freezed == is_notification_enabled ? _self.is_notification_enabled : is_notification_enabled // ignore: cast_nullable_to_non_nullable
as bool?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,header_url: freezed == header_url ? _self.header_url : header_url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Users].
extension UsersPatterns on Users {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Users value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Users() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Users value)  $default,){
final _that = this;
switch (_that) {
case _Users():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Users value)?  $default,){
final _that = this;
switch (_that) {
case _Users() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? name,  int trophy,  int? win,  int? lose,  String? avatar_url,  bool? status,  String? fcm_token,  bool? is_notification_enabled,  String? bio,  String? header_url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Users() when $default != null:
return $default(_that.id,_that.name,_that.trophy,_that.win,_that.lose,_that.avatar_url,_that.status,_that.fcm_token,_that.is_notification_enabled,_that.bio,_that.header_url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? name,  int trophy,  int? win,  int? lose,  String? avatar_url,  bool? status,  String? fcm_token,  bool? is_notification_enabled,  String? bio,  String? header_url)  $default,) {final _that = this;
switch (_that) {
case _Users():
return $default(_that.id,_that.name,_that.trophy,_that.win,_that.lose,_that.avatar_url,_that.status,_that.fcm_token,_that.is_notification_enabled,_that.bio,_that.header_url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? name,  int trophy,  int? win,  int? lose,  String? avatar_url,  bool? status,  String? fcm_token,  bool? is_notification_enabled,  String? bio,  String? header_url)?  $default,) {final _that = this;
switch (_that) {
case _Users() when $default != null:
return $default(_that.id,_that.name,_that.trophy,_that.win,_that.lose,_that.avatar_url,_that.status,_that.fcm_token,_that.is_notification_enabled,_that.bio,_that.header_url);case _:
  return null;

}
}

}

/// @nodoc


class _Users implements Users {
  const _Users({required this.id, this.name, required this.trophy, this.win, this.lose, this.avatar_url, this.status, this.fcm_token, this.is_notification_enabled, this.bio, this.header_url});
  

@override final  String id;
@override final  String? name;
@override final  int trophy;
@override final  int? win;
@override final  int? lose;
@override final  String? avatar_url;
@override final  bool? status;
@override final  String? fcm_token;
@override final  bool? is_notification_enabled;
@override final  String? bio;
@override final  String? header_url;

/// Create a copy of Users
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsersCopyWith<_Users> get copyWith => __$UsersCopyWithImpl<_Users>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Users&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.trophy, trophy) || other.trophy == trophy)&&(identical(other.win, win) || other.win == win)&&(identical(other.lose, lose) || other.lose == lose)&&(identical(other.avatar_url, avatar_url) || other.avatar_url == avatar_url)&&(identical(other.status, status) || other.status == status)&&(identical(other.fcm_token, fcm_token) || other.fcm_token == fcm_token)&&(identical(other.is_notification_enabled, is_notification_enabled) || other.is_notification_enabled == is_notification_enabled)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.header_url, header_url) || other.header_url == header_url));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,trophy,win,lose,avatar_url,status,fcm_token,is_notification_enabled,bio,header_url);

@override
String toString() {
  return 'Users(id: $id, name: $name, trophy: $trophy, win: $win, lose: $lose, avatar_url: $avatar_url, status: $status, fcm_token: $fcm_token, is_notification_enabled: $is_notification_enabled, bio: $bio, header_url: $header_url)';
}


}

/// @nodoc
abstract mixin class _$UsersCopyWith<$Res> implements $UsersCopyWith<$Res> {
  factory _$UsersCopyWith(_Users value, $Res Function(_Users) _then) = __$UsersCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, int trophy, int? win, int? lose, String? avatar_url, bool? status, String? fcm_token, bool? is_notification_enabled, String? bio, String? header_url
});




}
/// @nodoc
class __$UsersCopyWithImpl<$Res>
    implements _$UsersCopyWith<$Res> {
  __$UsersCopyWithImpl(this._self, this._then);

  final _Users _self;
  final $Res Function(_Users) _then;

/// Create a copy of Users
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? trophy = null,Object? win = freezed,Object? lose = freezed,Object? avatar_url = freezed,Object? status = freezed,Object? fcm_token = freezed,Object? is_notification_enabled = freezed,Object? bio = freezed,Object? header_url = freezed,}) {
  return _then(_Users(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,trophy: null == trophy ? _self.trophy : trophy // ignore: cast_nullable_to_non_nullable
as int,win: freezed == win ? _self.win : win // ignore: cast_nullable_to_non_nullable
as int?,lose: freezed == lose ? _self.lose : lose // ignore: cast_nullable_to_non_nullable
as int?,avatar_url: freezed == avatar_url ? _self.avatar_url : avatar_url // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as bool?,fcm_token: freezed == fcm_token ? _self.fcm_token : fcm_token // ignore: cast_nullable_to_non_nullable
as String?,is_notification_enabled: freezed == is_notification_enabled ? _self.is_notification_enabled : is_notification_enabled // ignore: cast_nullable_to_non_nullable
as bool?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,header_url: freezed == header_url ? _self.header_url : header_url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
