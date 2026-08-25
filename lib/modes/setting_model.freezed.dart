// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setting_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingsModel {

 double get sfxVolume; bool get isSfxOn; bool get isVibrationOn;
/// Create a copy of SettingsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsModelCopyWith<SettingsModel> get copyWith => _$SettingsModelCopyWithImpl<SettingsModel>(this as SettingsModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsModel&&(identical(other.sfxVolume, sfxVolume) || other.sfxVolume == sfxVolume)&&(identical(other.isSfxOn, isSfxOn) || other.isSfxOn == isSfxOn)&&(identical(other.isVibrationOn, isVibrationOn) || other.isVibrationOn == isVibrationOn));
}


@override
int get hashCode => Object.hash(runtimeType,sfxVolume,isSfxOn,isVibrationOn);

@override
String toString() {
  return 'SettingsModel(sfxVolume: $sfxVolume, isSfxOn: $isSfxOn, isVibrationOn: $isVibrationOn)';
}


}

/// @nodoc
abstract mixin class $SettingsModelCopyWith<$Res>  {
  factory $SettingsModelCopyWith(SettingsModel value, $Res Function(SettingsModel) _then) = _$SettingsModelCopyWithImpl;
@useResult
$Res call({
 double sfxVolume, bool isSfxOn, bool isVibrationOn
});




}
/// @nodoc
class _$SettingsModelCopyWithImpl<$Res>
    implements $SettingsModelCopyWith<$Res> {
  _$SettingsModelCopyWithImpl(this._self, this._then);

  final SettingsModel _self;
  final $Res Function(SettingsModel) _then;

/// Create a copy of SettingsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sfxVolume = null,Object? isSfxOn = null,Object? isVibrationOn = null,}) {
  return _then(SettingsModel(
sfxVolume: null == sfxVolume ? _self.sfxVolume : sfxVolume // ignore: cast_nullable_to_non_nullable
as double,isSfxOn: null == isSfxOn ? _self.isSfxOn : isSfxOn // ignore: cast_nullable_to_non_nullable
as bool,isVibrationOn: null == isVibrationOn ? _self.isVibrationOn : isVibrationOn // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingsModel].
extension SettingsModelPatterns on SettingsModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingsModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingsModel value)  $default,){
final _that = this;
switch (_that) {
case _SettingsModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingsModel value)?  $default,){
final _that = this;
switch (_that) {
case _SettingsModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double sfxVolume,  bool isSfxOn,  bool isVibrationOn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsModel() when $default != null:
return $default(_that.sfxVolume,_that.isSfxOn,_that.isVibrationOn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double sfxVolume,  bool isSfxOn,  bool isVibrationOn)  $default,) {final _that = this;
switch (_that) {
case _SettingsModel():
return $default(_that.sfxVolume,_that.isSfxOn,_that.isVibrationOn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double sfxVolume,  bool isSfxOn,  bool isVibrationOn)?  $default,) {final _that = this;
switch (_that) {
case _SettingsModel() when $default != null:
return $default(_that.sfxVolume,_that.isSfxOn,_that.isVibrationOn);case _:
  return null;

}
}

}

/// @nodoc


class _SettingsModel implements SettingsModel {
  const _SettingsModel({this.sfxVolume = 0.8, this.isSfxOn = true, this.isVibrationOn = true});
  

@override@JsonKey() final  double sfxVolume;
@override@JsonKey() final  bool isSfxOn;
@override@JsonKey() final  bool isVibrationOn;

/// Create a copy of SettingsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsModelCopyWith<_SettingsModel> get copyWith => __$SettingsModelCopyWithImpl<_SettingsModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsModel&&(identical(other.sfxVolume, sfxVolume) || other.sfxVolume == sfxVolume)&&(identical(other.isSfxOn, isSfxOn) || other.isSfxOn == isSfxOn)&&(identical(other.isVibrationOn, isVibrationOn) || other.isVibrationOn == isVibrationOn));
}


@override
int get hashCode => Object.hash(runtimeType,sfxVolume,isSfxOn,isVibrationOn);

@override
String toString() {
  return 'SettingsModel(sfxVolume: $sfxVolume, isSfxOn: $isSfxOn, isVibrationOn: $isVibrationOn)';
}


}

/// @nodoc
abstract mixin class _$SettingsModelCopyWith<$Res> implements $SettingsModelCopyWith<$Res> {
  factory _$SettingsModelCopyWith(_SettingsModel value, $Res Function(_SettingsModel) _then) = __$SettingsModelCopyWithImpl;
@override @useResult
$Res call({
 double sfxVolume, bool isSfxOn, bool isVibrationOn
});




}
/// @nodoc
class __$SettingsModelCopyWithImpl<$Res>
    implements _$SettingsModelCopyWith<$Res> {
  __$SettingsModelCopyWithImpl(this._self, this._then);

  final _SettingsModel _self;
  final $Res Function(_SettingsModel) _then;

/// Create a copy of SettingsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sfxVolume = null,Object? isSfxOn = null,Object? isVibrationOn = null,}) {
  return _then(_SettingsModel(
sfxVolume: null == sfxVolume ? _self.sfxVolume : sfxVolume // ignore: cast_nullable_to_non_nullable
as double,isSfxOn: null == isSfxOn ? _self.isSfxOn : isSfxOn // ignore: cast_nullable_to_non_nullable
as bool,isVibrationOn: null == isVibrationOn ? _self.isVibrationOn : isVibrationOn // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
