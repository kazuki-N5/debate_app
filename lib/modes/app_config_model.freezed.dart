// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_config_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AppConfig {
  String? get minVersion =>
      throw _privateConstructorUsedError; // 変更: 汎用的な最小サポートバージョン
  String? get latestVersion =>
      throw _privateConstructorUsedError; // 変更: 汎用的な最新バージョン
  String? get maxVersion =>
      throw _privateConstructorUsedError; // 追加: 開発用の最大バージョン
  String? get changelog => throw _privateConstructorUsedError; // 共通の変更ログ
  bool? get isMaintenanceMode => throw _privateConstructorUsedError;
  String? get maintenanceMessage => throw _privateConstructorUsedError;

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppConfigCopyWith<AppConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppConfigCopyWith<$Res> {
  factory $AppConfigCopyWith(AppConfig value, $Res Function(AppConfig) then) =
      _$AppConfigCopyWithImpl<$Res, AppConfig>;
  @useResult
  $Res call(
      {String? minVersion,
      String? latestVersion,
      String? maxVersion,
      String? changelog,
      bool? isMaintenanceMode,
      String? maintenanceMessage});
}

/// @nodoc
class _$AppConfigCopyWithImpl<$Res, $Val extends AppConfig>
    implements $AppConfigCopyWith<$Res> {
  _$AppConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? minVersion = freezed,
    Object? latestVersion = freezed,
    Object? maxVersion = freezed,
    Object? changelog = freezed,
    Object? isMaintenanceMode = freezed,
    Object? maintenanceMessage = freezed,
  }) {
    return _then(_value.copyWith(
      minVersion: freezed == minVersion
          ? _value.minVersion
          : minVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      latestVersion: freezed == latestVersion
          ? _value.latestVersion
          : latestVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      maxVersion: freezed == maxVersion
          ? _value.maxVersion
          : maxVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      changelog: freezed == changelog
          ? _value.changelog
          : changelog // ignore: cast_nullable_to_non_nullable
              as String?,
      isMaintenanceMode: freezed == isMaintenanceMode
          ? _value.isMaintenanceMode
          : isMaintenanceMode // ignore: cast_nullable_to_non_nullable
              as bool?,
      maintenanceMessage: freezed == maintenanceMessage
          ? _value.maintenanceMessage
          : maintenanceMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppConfigImplCopyWith<$Res>
    implements $AppConfigCopyWith<$Res> {
  factory _$$AppConfigImplCopyWith(
          _$AppConfigImpl value, $Res Function(_$AppConfigImpl) then) =
      __$$AppConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? minVersion,
      String? latestVersion,
      String? maxVersion,
      String? changelog,
      bool? isMaintenanceMode,
      String? maintenanceMessage});
}

/// @nodoc
class __$$AppConfigImplCopyWithImpl<$Res>
    extends _$AppConfigCopyWithImpl<$Res, _$AppConfigImpl>
    implements _$$AppConfigImplCopyWith<$Res> {
  __$$AppConfigImplCopyWithImpl(
      _$AppConfigImpl _value, $Res Function(_$AppConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? minVersion = freezed,
    Object? latestVersion = freezed,
    Object? maxVersion = freezed,
    Object? changelog = freezed,
    Object? isMaintenanceMode = freezed,
    Object? maintenanceMessage = freezed,
  }) {
    return _then(_$AppConfigImpl(
      minVersion: freezed == minVersion
          ? _value.minVersion
          : minVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      latestVersion: freezed == latestVersion
          ? _value.latestVersion
          : latestVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      maxVersion: freezed == maxVersion
          ? _value.maxVersion
          : maxVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      changelog: freezed == changelog
          ? _value.changelog
          : changelog // ignore: cast_nullable_to_non_nullable
              as String?,
      isMaintenanceMode: freezed == isMaintenanceMode
          ? _value.isMaintenanceMode
          : isMaintenanceMode // ignore: cast_nullable_to_non_nullable
              as bool?,
      maintenanceMessage: freezed == maintenanceMessage
          ? _value.maintenanceMessage
          : maintenanceMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$AppConfigImpl implements _AppConfig {
  const _$AppConfigImpl(
      {this.minVersion,
      this.latestVersion,
      this.maxVersion,
      this.changelog,
      this.isMaintenanceMode,
      this.maintenanceMessage});

  @override
  final String? minVersion;
// 変更: 汎用的な最小サポートバージョン
  @override
  final String? latestVersion;
// 変更: 汎用的な最新バージョン
  @override
  final String? maxVersion;
// 追加: 開発用の最大バージョン
  @override
  final String? changelog;
// 共通の変更ログ
  @override
  final bool? isMaintenanceMode;
  @override
  final String? maintenanceMessage;

  @override
  String toString() {
    return 'AppConfig(minVersion: $minVersion, latestVersion: $latestVersion, maxVersion: $maxVersion, changelog: $changelog, isMaintenanceMode: $isMaintenanceMode, maintenanceMessage: $maintenanceMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppConfigImpl &&
            (identical(other.minVersion, minVersion) ||
                other.minVersion == minVersion) &&
            (identical(other.latestVersion, latestVersion) ||
                other.latestVersion == latestVersion) &&
            (identical(other.maxVersion, maxVersion) ||
                other.maxVersion == maxVersion) &&
            (identical(other.changelog, changelog) ||
                other.changelog == changelog) &&
            (identical(other.isMaintenanceMode, isMaintenanceMode) ||
                other.isMaintenanceMode == isMaintenanceMode) &&
            (identical(other.maintenanceMessage, maintenanceMessage) ||
                other.maintenanceMessage == maintenanceMessage));
  }

  @override
  int get hashCode => Object.hash(runtimeType, minVersion, latestVersion,
      maxVersion, changelog, isMaintenanceMode, maintenanceMessage);

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppConfigImplCopyWith<_$AppConfigImpl> get copyWith =>
      __$$AppConfigImplCopyWithImpl<_$AppConfigImpl>(this, _$identity);
}

abstract class _AppConfig implements AppConfig {
  const factory _AppConfig(
      {final String? minVersion,
      final String? latestVersion,
      final String? maxVersion,
      final String? changelog,
      final bool? isMaintenanceMode,
      final String? maintenanceMessage}) = _$AppConfigImpl;

  @override
  String? get minVersion; // 変更: 汎用的な最小サポートバージョン
  @override
  String? get latestVersion; // 変更: 汎用的な最新バージョン
  @override
  String? get maxVersion; // 追加: 開発用の最大バージョン
  @override
  String? get changelog; // 共通の変更ログ
  @override
  bool? get isMaintenanceMode;
  @override
  String? get maintenanceMessage;

  /// Create a copy of AppConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppConfigImplCopyWith<_$AppConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
