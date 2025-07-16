// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setting_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SettingsModel {
  double get sfxVolume => throw _privateConstructorUsedError;
  bool get isSfxOn => throw _privateConstructorUsedError;
  bool get isVibrationOn => throw _privateConstructorUsedError;

  /// Create a copy of SettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SettingsModelCopyWith<SettingsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SettingsModelCopyWith<$Res> {
  factory $SettingsModelCopyWith(
          SettingsModel value, $Res Function(SettingsModel) then) =
      _$SettingsModelCopyWithImpl<$Res, SettingsModel>;
  @useResult
  $Res call({double sfxVolume, bool isSfxOn, bool isVibrationOn});
}

/// @nodoc
class _$SettingsModelCopyWithImpl<$Res, $Val extends SettingsModel>
    implements $SettingsModelCopyWith<$Res> {
  _$SettingsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sfxVolume = null,
    Object? isSfxOn = null,
    Object? isVibrationOn = null,
  }) {
    return _then(_value.copyWith(
      sfxVolume: null == sfxVolume
          ? _value.sfxVolume
          : sfxVolume // ignore: cast_nullable_to_non_nullable
              as double,
      isSfxOn: null == isSfxOn
          ? _value.isSfxOn
          : isSfxOn // ignore: cast_nullable_to_non_nullable
              as bool,
      isVibrationOn: null == isVibrationOn
          ? _value.isVibrationOn
          : isVibrationOn // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SettingsModelImplCopyWith<$Res>
    implements $SettingsModelCopyWith<$Res> {
  factory _$$SettingsModelImplCopyWith(
          _$SettingsModelImpl value, $Res Function(_$SettingsModelImpl) then) =
      __$$SettingsModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double sfxVolume, bool isSfxOn, bool isVibrationOn});
}

/// @nodoc
class __$$SettingsModelImplCopyWithImpl<$Res>
    extends _$SettingsModelCopyWithImpl<$Res, _$SettingsModelImpl>
    implements _$$SettingsModelImplCopyWith<$Res> {
  __$$SettingsModelImplCopyWithImpl(
      _$SettingsModelImpl _value, $Res Function(_$SettingsModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of SettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sfxVolume = null,
    Object? isSfxOn = null,
    Object? isVibrationOn = null,
  }) {
    return _then(_$SettingsModelImpl(
      sfxVolume: null == sfxVolume
          ? _value.sfxVolume
          : sfxVolume // ignore: cast_nullable_to_non_nullable
              as double,
      isSfxOn: null == isSfxOn
          ? _value.isSfxOn
          : isSfxOn // ignore: cast_nullable_to_non_nullable
              as bool,
      isVibrationOn: null == isVibrationOn
          ? _value.isVibrationOn
          : isVibrationOn // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$SettingsModelImpl implements _SettingsModel {
  const _$SettingsModelImpl(
      {this.sfxVolume = 0.8, this.isSfxOn = true, this.isVibrationOn = true});

  @override
  @JsonKey()
  final double sfxVolume;
  @override
  @JsonKey()
  final bool isSfxOn;
  @override
  @JsonKey()
  final bool isVibrationOn;

  @override
  String toString() {
    return 'SettingsModel(sfxVolume: $sfxVolume, isSfxOn: $isSfxOn, isVibrationOn: $isVibrationOn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SettingsModelImpl &&
            (identical(other.sfxVolume, sfxVolume) ||
                other.sfxVolume == sfxVolume) &&
            (identical(other.isSfxOn, isSfxOn) || other.isSfxOn == isSfxOn) &&
            (identical(other.isVibrationOn, isVibrationOn) ||
                other.isVibrationOn == isVibrationOn));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, sfxVolume, isSfxOn, isVibrationOn);

  /// Create a copy of SettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SettingsModelImplCopyWith<_$SettingsModelImpl> get copyWith =>
      __$$SettingsModelImplCopyWithImpl<_$SettingsModelImpl>(this, _$identity);
}

abstract class _SettingsModel implements SettingsModel {
  const factory _SettingsModel(
      {final double sfxVolume,
      final bool isSfxOn,
      final bool isVibrationOn}) = _$SettingsModelImpl;

  @override
  double get sfxVolume;
  @override
  bool get isSfxOn;
  @override
  bool get isVibrationOn;

  /// Create a copy of SettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SettingsModelImplCopyWith<_$SettingsModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
