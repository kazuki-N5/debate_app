// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_config_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppConfig {

 String? get minVersion; String? get latestVersion; String? get maxVersion; String? get changelog; bool? get isMaintenanceMode; String? get maintenanceMessage;
/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppConfigCopyWith<AppConfig> get copyWith => _$AppConfigCopyWithImpl<AppConfig>(this as AppConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppConfig&&(identical(other.minVersion, minVersion) || other.minVersion == minVersion)&&(identical(other.latestVersion, latestVersion) || other.latestVersion == latestVersion)&&(identical(other.maxVersion, maxVersion) || other.maxVersion == maxVersion)&&(identical(other.changelog, changelog) || other.changelog == changelog)&&(identical(other.isMaintenanceMode, isMaintenanceMode) || other.isMaintenanceMode == isMaintenanceMode)&&(identical(other.maintenanceMessage, maintenanceMessage) || other.maintenanceMessage == maintenanceMessage));
}


@override
int get hashCode => Object.hash(runtimeType,minVersion,latestVersion,maxVersion,changelog,isMaintenanceMode,maintenanceMessage);

@override
String toString() {
  return 'AppConfig(minVersion: $minVersion, latestVersion: $latestVersion, maxVersion: $maxVersion, changelog: $changelog, isMaintenanceMode: $isMaintenanceMode, maintenanceMessage: $maintenanceMessage)';
}


}

/// @nodoc
abstract mixin class $AppConfigCopyWith<$Res>  {
  factory $AppConfigCopyWith(AppConfig value, $Res Function(AppConfig) _then) = _$AppConfigCopyWithImpl;
@useResult
$Res call({
 String? minVersion, String? latestVersion, String? maxVersion, String? changelog, bool? isMaintenanceMode, String? maintenanceMessage
});




}
/// @nodoc
class _$AppConfigCopyWithImpl<$Res>
    implements $AppConfigCopyWith<$Res> {
  _$AppConfigCopyWithImpl(this._self, this._then);

  final AppConfig _self;
  final $Res Function(AppConfig) _then;

/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minVersion = freezed,Object? latestVersion = freezed,Object? maxVersion = freezed,Object? changelog = freezed,Object? isMaintenanceMode = freezed,Object? maintenanceMessage = freezed,}) {
  return _then(AppConfig(
minVersion: freezed == minVersion ? _self.minVersion : minVersion // ignore: cast_nullable_to_non_nullable
as String?,latestVersion: freezed == latestVersion ? _self.latestVersion : latestVersion // ignore: cast_nullable_to_non_nullable
as String?,maxVersion: freezed == maxVersion ? _self.maxVersion : maxVersion // ignore: cast_nullable_to_non_nullable
as String?,changelog: freezed == changelog ? _self.changelog : changelog // ignore: cast_nullable_to_non_nullable
as String?,isMaintenanceMode: freezed == isMaintenanceMode ? _self.isMaintenanceMode : isMaintenanceMode // ignore: cast_nullable_to_non_nullable
as bool?,maintenanceMessage: freezed == maintenanceMessage ? _self.maintenanceMessage : maintenanceMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppConfig].
extension AppConfigPatterns on AppConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppConfig value)  $default,){
final _that = this;
switch (_that) {
case _AppConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppConfig value)?  $default,){
final _that = this;
switch (_that) {
case _AppConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? minVersion,  String? latestVersion,  String? maxVersion,  String? changelog,  bool? isMaintenanceMode,  String? maintenanceMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppConfig() when $default != null:
return $default(_that.minVersion,_that.latestVersion,_that.maxVersion,_that.changelog,_that.isMaintenanceMode,_that.maintenanceMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? minVersion,  String? latestVersion,  String? maxVersion,  String? changelog,  bool? isMaintenanceMode,  String? maintenanceMessage)  $default,) {final _that = this;
switch (_that) {
case _AppConfig():
return $default(_that.minVersion,_that.latestVersion,_that.maxVersion,_that.changelog,_that.isMaintenanceMode,_that.maintenanceMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? minVersion,  String? latestVersion,  String? maxVersion,  String? changelog,  bool? isMaintenanceMode,  String? maintenanceMessage)?  $default,) {final _that = this;
switch (_that) {
case _AppConfig() when $default != null:
return $default(_that.minVersion,_that.latestVersion,_that.maxVersion,_that.changelog,_that.isMaintenanceMode,_that.maintenanceMessage);case _:
  return null;

}
}

}

/// @nodoc


class _AppConfig implements AppConfig {
  const _AppConfig({this.minVersion, this.latestVersion, this.maxVersion, this.changelog, this.isMaintenanceMode, this.maintenanceMessage});
  

@override final  String? minVersion;
@override final  String? latestVersion;
@override final  String? maxVersion;
@override final  String? changelog;
@override final  bool? isMaintenanceMode;
@override final  String? maintenanceMessage;

/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppConfigCopyWith<_AppConfig> get copyWith => __$AppConfigCopyWithImpl<_AppConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppConfig&&(identical(other.minVersion, minVersion) || other.minVersion == minVersion)&&(identical(other.latestVersion, latestVersion) || other.latestVersion == latestVersion)&&(identical(other.maxVersion, maxVersion) || other.maxVersion == maxVersion)&&(identical(other.changelog, changelog) || other.changelog == changelog)&&(identical(other.isMaintenanceMode, isMaintenanceMode) || other.isMaintenanceMode == isMaintenanceMode)&&(identical(other.maintenanceMessage, maintenanceMessage) || other.maintenanceMessage == maintenanceMessage));
}


@override
int get hashCode => Object.hash(runtimeType,minVersion,latestVersion,maxVersion,changelog,isMaintenanceMode,maintenanceMessage);

@override
String toString() {
  return 'AppConfig(minVersion: $minVersion, latestVersion: $latestVersion, maxVersion: $maxVersion, changelog: $changelog, isMaintenanceMode: $isMaintenanceMode, maintenanceMessage: $maintenanceMessage)';
}


}

/// @nodoc
abstract mixin class _$AppConfigCopyWith<$Res> implements $AppConfigCopyWith<$Res> {
  factory _$AppConfigCopyWith(_AppConfig value, $Res Function(_AppConfig) _then) = __$AppConfigCopyWithImpl;
@override @useResult
$Res call({
 String? minVersion, String? latestVersion, String? maxVersion, String? changelog, bool? isMaintenanceMode, String? maintenanceMessage
});




}
/// @nodoc
class __$AppConfigCopyWithImpl<$Res>
    implements _$AppConfigCopyWith<$Res> {
  __$AppConfigCopyWithImpl(this._self, this._then);

  final _AppConfig _self;
  final $Res Function(_AppConfig) _then;

/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minVersion = freezed,Object? latestVersion = freezed,Object? maxVersion = freezed,Object? changelog = freezed,Object? isMaintenanceMode = freezed,Object? maintenanceMessage = freezed,}) {
  return _then(_AppConfig(
minVersion: freezed == minVersion ? _self.minVersion : minVersion // ignore: cast_nullable_to_non_nullable
as String?,latestVersion: freezed == latestVersion ? _self.latestVersion : latestVersion // ignore: cast_nullable_to_non_nullable
as String?,maxVersion: freezed == maxVersion ? _self.maxVersion : maxVersion // ignore: cast_nullable_to_non_nullable
as String?,changelog: freezed == changelog ? _self.changelog : changelog // ignore: cast_nullable_to_non_nullable
as String?,isMaintenanceMode: freezed == isMaintenanceMode ? _self.isMaintenanceMode : isMaintenanceMode // ignore: cast_nullable_to_non_nullable
as bool?,maintenanceMessage: freezed == maintenanceMessage ? _self.maintenanceMessage : maintenanceMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
