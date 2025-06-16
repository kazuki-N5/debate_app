// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'users.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Users {
  String get id => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  int get trophy => throw _privateConstructorUsedError;
  int? get win => throw _privateConstructorUsedError;
  int? get lose => throw _privateConstructorUsedError;
  String? get avatar_url => throw _privateConstructorUsedError;
  bool? get status => throw _privateConstructorUsedError;

  /// Create a copy of Users
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UsersCopyWith<Users> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UsersCopyWith<$Res> {
  factory $UsersCopyWith(Users value, $Res Function(Users) then) =
      _$UsersCopyWithImpl<$Res, Users>;
  @useResult
  $Res call(
      {String id,
      String? name,
      int trophy,
      int? win,
      int? lose,
      String? avatar_url,
      bool? status});
}

/// @nodoc
class _$UsersCopyWithImpl<$Res, $Val extends Users>
    implements $UsersCopyWith<$Res> {
  _$UsersCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Users
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? trophy = null,
    Object? win = freezed,
    Object? lose = freezed,
    Object? avatar_url = freezed,
    Object? status = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      trophy: null == trophy
          ? _value.trophy
          : trophy // ignore: cast_nullable_to_non_nullable
              as int,
      win: freezed == win
          ? _value.win
          : win // ignore: cast_nullable_to_non_nullable
              as int?,
      lose: freezed == lose
          ? _value.lose
          : lose // ignore: cast_nullable_to_non_nullable
              as int?,
      avatar_url: freezed == avatar_url
          ? _value.avatar_url
          : avatar_url // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UsersImplCopyWith<$Res> implements $UsersCopyWith<$Res> {
  factory _$$UsersImplCopyWith(
          _$UsersImpl value, $Res Function(_$UsersImpl) then) =
      __$$UsersImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String? name,
      int trophy,
      int? win,
      int? lose,
      String? avatar_url,
      bool? status});
}

/// @nodoc
class __$$UsersImplCopyWithImpl<$Res>
    extends _$UsersCopyWithImpl<$Res, _$UsersImpl>
    implements _$$UsersImplCopyWith<$Res> {
  __$$UsersImplCopyWithImpl(
      _$UsersImpl _value, $Res Function(_$UsersImpl) _then)
      : super(_value, _then);

  /// Create a copy of Users
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? trophy = null,
    Object? win = freezed,
    Object? lose = freezed,
    Object? avatar_url = freezed,
    Object? status = freezed,
  }) {
    return _then(_$UsersImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      trophy: null == trophy
          ? _value.trophy
          : trophy // ignore: cast_nullable_to_non_nullable
              as int,
      win: freezed == win
          ? _value.win
          : win // ignore: cast_nullable_to_non_nullable
              as int?,
      lose: freezed == lose
          ? _value.lose
          : lose // ignore: cast_nullable_to_non_nullable
              as int?,
      avatar_url: freezed == avatar_url
          ? _value.avatar_url
          : avatar_url // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc

class _$UsersImpl implements _Users {
  const _$UsersImpl(
      {required this.id,
      this.name,
      required this.trophy,
      this.win,
      this.lose,
      this.avatar_url,
      this.status});

  @override
  final String id;
  @override
  final String? name;
  @override
  final int trophy;
  @override
  final int? win;
  @override
  final int? lose;
  @override
  final String? avatar_url;
  @override
  final bool? status;

  @override
  String toString() {
    return 'Users(id: $id, name: $name, trophy: $trophy, win: $win, lose: $lose, avatar_url: $avatar_url, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UsersImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.trophy, trophy) || other.trophy == trophy) &&
            (identical(other.win, win) || other.win == win) &&
            (identical(other.lose, lose) || other.lose == lose) &&
            (identical(other.avatar_url, avatar_url) ||
                other.avatar_url == avatar_url) &&
            (identical(other.status, status) || other.status == status));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, trophy, win, lose, avatar_url, status);

  /// Create a copy of Users
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UsersImplCopyWith<_$UsersImpl> get copyWith =>
      __$$UsersImplCopyWithImpl<_$UsersImpl>(this, _$identity);
}

abstract class _Users implements Users {
  const factory _Users(
      {required final String id,
      final String? name,
      required final int trophy,
      final int? win,
      final int? lose,
      final String? avatar_url,
      final bool? status}) = _$UsersImpl;

  @override
  String get id;
  @override
  String? get name;
  @override
  int get trophy;
  @override
  int? get win;
  @override
  int? get lose;
  @override
  String? get avatar_url;
  @override
  bool? get status;

  /// Create a copy of Users
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UsersImplCopyWith<_$UsersImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
