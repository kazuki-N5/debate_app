// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mathing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MatchingRoom {

 String? get roomId; String? get player1Id; String? get player2Id; bool? get isMatched; DateTime? get createdAt; String? get winner; String? get reason; bool? get player1Choice; bool? get player2Choice; DateTime? get updatedAt; bool? get change; bool? get go; bool? get player1_finish; bool? get player2_finish; bool? get player1_go; bool? get player2_go; DateTime? get player1_time; DateTime? get player2_time; String? get theme; String? get choice1; String? get choice2; String? get password; MatchScores? get scores; bool? get isBbs;
/// Create a copy of MatchingRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchingRoomCopyWith<MatchingRoom> get copyWith => _$MatchingRoomCopyWithImpl<MatchingRoom>(this as MatchingRoom, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchingRoom&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.player1Id, player1Id) || other.player1Id == player1Id)&&(identical(other.player2Id, player2Id) || other.player2Id == player2Id)&&(identical(other.isMatched, isMatched) || other.isMatched == isMatched)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.winner, winner) || other.winner == winner)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.player1Choice, player1Choice) || other.player1Choice == player1Choice)&&(identical(other.player2Choice, player2Choice) || other.player2Choice == player2Choice)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.change, change) || other.change == change)&&(identical(other.go, go) || other.go == go)&&(identical(other.player1_finish, player1_finish) || other.player1_finish == player1_finish)&&(identical(other.player2_finish, player2_finish) || other.player2_finish == player2_finish)&&(identical(other.player1_go, player1_go) || other.player1_go == player1_go)&&(identical(other.player2_go, player2_go) || other.player2_go == player2_go)&&(identical(other.player1_time, player1_time) || other.player1_time == player1_time)&&(identical(other.player2_time, player2_time) || other.player2_time == player2_time)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.choice1, choice1) || other.choice1 == choice1)&&(identical(other.choice2, choice2) || other.choice2 == choice2)&&(identical(other.password, password) || other.password == password)&&(identical(other.scores, scores) || other.scores == scores)&&(identical(other.isBbs, isBbs) || other.isBbs == isBbs));
}


@override
int get hashCode => Object.hashAll([runtimeType,roomId,player1Id,player2Id,isMatched,createdAt,winner,reason,player1Choice,player2Choice,updatedAt,change,go,player1_finish,player2_finish,player1_go,player2_go,player1_time,player2_time,theme,choice1,choice2,password,scores,isBbs]);

@override
String toString() {
  return 'MatchingRoom(roomId: $roomId, player1Id: $player1Id, player2Id: $player2Id, isMatched: $isMatched, createdAt: $createdAt, winner: $winner, reason: $reason, player1Choice: $player1Choice, player2Choice: $player2Choice, updatedAt: $updatedAt, change: $change, go: $go, player1_finish: $player1_finish, player2_finish: $player2_finish, player1_go: $player1_go, player2_go: $player2_go, player1_time: $player1_time, player2_time: $player2_time, theme: $theme, choice1: $choice1, choice2: $choice2, password: $password, scores: $scores, isBbs: $isBbs)';
}


}

/// @nodoc
abstract mixin class $MatchingRoomCopyWith<$Res>  {
  factory $MatchingRoomCopyWith(MatchingRoom value, $Res Function(MatchingRoom) _then) = _$MatchingRoomCopyWithImpl;
@useResult
$Res call({
 String? roomId, String? player1Id, String? player2Id, bool? isMatched, DateTime? createdAt, String? winner, String? reason, bool? player1Choice, bool? player2Choice, DateTime? updatedAt, bool? change, bool? go, bool? player1_finish, bool? player2_finish, bool? player1_go, bool? player2_go, DateTime? player1_time, DateTime? player2_time, String? theme, String? choice1, String? choice2, String? password, MatchScores? scores, bool? isBbs
});




}
/// @nodoc
class _$MatchingRoomCopyWithImpl<$Res>
    implements $MatchingRoomCopyWith<$Res> {
  _$MatchingRoomCopyWithImpl(this._self, this._then);

  final MatchingRoom _self;
  final $Res Function(MatchingRoom) _then;

/// Create a copy of MatchingRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = freezed,Object? player1Id = freezed,Object? player2Id = freezed,Object? isMatched = freezed,Object? createdAt = freezed,Object? winner = freezed,Object? reason = freezed,Object? player1Choice = freezed,Object? player2Choice = freezed,Object? updatedAt = freezed,Object? change = freezed,Object? go = freezed,Object? player1_finish = freezed,Object? player2_finish = freezed,Object? player1_go = freezed,Object? player2_go = freezed,Object? player1_time = freezed,Object? player2_time = freezed,Object? theme = freezed,Object? choice1 = freezed,Object? choice2 = freezed,Object? password = freezed,Object? scores = freezed,Object? isBbs = freezed,}) {
  return _then(MatchingRoom(
roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,player1Id: freezed == player1Id ? _self.player1Id : player1Id // ignore: cast_nullable_to_non_nullable
as String?,player2Id: freezed == player2Id ? _self.player2Id : player2Id // ignore: cast_nullable_to_non_nullable
as String?,isMatched: freezed == isMatched ? _self.isMatched : isMatched // ignore: cast_nullable_to_non_nullable
as bool?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,winner: freezed == winner ? _self.winner : winner // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,player1Choice: freezed == player1Choice ? _self.player1Choice : player1Choice // ignore: cast_nullable_to_non_nullable
as bool?,player2Choice: freezed == player2Choice ? _self.player2Choice : player2Choice // ignore: cast_nullable_to_non_nullable
as bool?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,change: freezed == change ? _self.change : change // ignore: cast_nullable_to_non_nullable
as bool?,go: freezed == go ? _self.go : go // ignore: cast_nullable_to_non_nullable
as bool?,player1_finish: freezed == player1_finish ? _self.player1_finish : player1_finish // ignore: cast_nullable_to_non_nullable
as bool?,player2_finish: freezed == player2_finish ? _self.player2_finish : player2_finish // ignore: cast_nullable_to_non_nullable
as bool?,player1_go: freezed == player1_go ? _self.player1_go : player1_go // ignore: cast_nullable_to_non_nullable
as bool?,player2_go: freezed == player2_go ? _self.player2_go : player2_go // ignore: cast_nullable_to_non_nullable
as bool?,player1_time: freezed == player1_time ? _self.player1_time : player1_time // ignore: cast_nullable_to_non_nullable
as DateTime?,player2_time: freezed == player2_time ? _self.player2_time : player2_time // ignore: cast_nullable_to_non_nullable
as DateTime?,theme: freezed == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String?,choice1: freezed == choice1 ? _self.choice1 : choice1 // ignore: cast_nullable_to_non_nullable
as String?,choice2: freezed == choice2 ? _self.choice2 : choice2 // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,scores: freezed == scores ? _self.scores : scores // ignore: cast_nullable_to_non_nullable
as MatchScores?,isBbs: freezed == isBbs ? _self.isBbs : isBbs // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [MatchingRoom].
extension MatchingRoomPatterns on MatchingRoom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchingRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchingRoom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchingRoom value)  $default,){
final _that = this;
switch (_that) {
case _MatchingRoom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchingRoom value)?  $default,){
final _that = this;
switch (_that) {
case _MatchingRoom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? roomId,  String? player1Id,  String? player2Id,  bool? isMatched,  DateTime? createdAt,  String? winner,  String? reason,  bool? player1Choice,  bool? player2Choice,  DateTime? updatedAt,  bool? change,  bool? go,  bool? player1_finish,  bool? player2_finish,  bool? player1_go,  bool? player2_go,  DateTime? player1_time,  DateTime? player2_time,  String? theme,  String? choice1,  String? choice2,  String? password,  MatchScores? scores,  bool? isBbs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchingRoom() when $default != null:
return $default(_that.roomId,_that.player1Id,_that.player2Id,_that.isMatched,_that.createdAt,_that.winner,_that.reason,_that.player1Choice,_that.player2Choice,_that.updatedAt,_that.change,_that.go,_that.player1_finish,_that.player2_finish,_that.player1_go,_that.player2_go,_that.player1_time,_that.player2_time,_that.theme,_that.choice1,_that.choice2,_that.password,_that.scores,_that.isBbs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? roomId,  String? player1Id,  String? player2Id,  bool? isMatched,  DateTime? createdAt,  String? winner,  String? reason,  bool? player1Choice,  bool? player2Choice,  DateTime? updatedAt,  bool? change,  bool? go,  bool? player1_finish,  bool? player2_finish,  bool? player1_go,  bool? player2_go,  DateTime? player1_time,  DateTime? player2_time,  String? theme,  String? choice1,  String? choice2,  String? password,  MatchScores? scores,  bool? isBbs)  $default,) {final _that = this;
switch (_that) {
case _MatchingRoom():
return $default(_that.roomId,_that.player1Id,_that.player2Id,_that.isMatched,_that.createdAt,_that.winner,_that.reason,_that.player1Choice,_that.player2Choice,_that.updatedAt,_that.change,_that.go,_that.player1_finish,_that.player2_finish,_that.player1_go,_that.player2_go,_that.player1_time,_that.player2_time,_that.theme,_that.choice1,_that.choice2,_that.password,_that.scores,_that.isBbs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? roomId,  String? player1Id,  String? player2Id,  bool? isMatched,  DateTime? createdAt,  String? winner,  String? reason,  bool? player1Choice,  bool? player2Choice,  DateTime? updatedAt,  bool? change,  bool? go,  bool? player1_finish,  bool? player2_finish,  bool? player1_go,  bool? player2_go,  DateTime? player1_time,  DateTime? player2_time,  String? theme,  String? choice1,  String? choice2,  String? password,  MatchScores? scores,  bool? isBbs)?  $default,) {final _that = this;
switch (_that) {
case _MatchingRoom() when $default != null:
return $default(_that.roomId,_that.player1Id,_that.player2Id,_that.isMatched,_that.createdAt,_that.winner,_that.reason,_that.player1Choice,_that.player2Choice,_that.updatedAt,_that.change,_that.go,_that.player1_finish,_that.player2_finish,_that.player1_go,_that.player2_go,_that.player1_time,_that.player2_time,_that.theme,_that.choice1,_that.choice2,_that.password,_that.scores,_that.isBbs);case _:
  return null;

}
}

}

/// @nodoc


class _MatchingRoom implements MatchingRoom {
   _MatchingRoom({this.roomId, this.player1Id, this.player2Id, this.isMatched, this.createdAt, this.winner, this.reason, this.player1Choice, this.player2Choice, this.updatedAt, this.change, this.go, this.player1_finish, this.player2_finish, this.player1_go, this.player2_go, this.player1_time, this.player2_time, this.theme, this.choice1, this.choice2, this.password, this.scores, this.isBbs});
  

@override final  String? roomId;
@override final  String? player1Id;
@override final  String? player2Id;
@override final  bool? isMatched;
@override final  DateTime? createdAt;
@override final  String? winner;
@override final  String? reason;
@override final  bool? player1Choice;
@override final  bool? player2Choice;
@override final  DateTime? updatedAt;
@override final  bool? change;
@override final  bool? go;
@override final  bool? player1_finish;
@override final  bool? player2_finish;
@override final  bool? player1_go;
@override final  bool? player2_go;
@override final  DateTime? player1_time;
@override final  DateTime? player2_time;
@override final  String? theme;
@override final  String? choice1;
@override final  String? choice2;
@override final  String? password;
@override final  MatchScores? scores;
@override final  bool? isBbs;

/// Create a copy of MatchingRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchingRoomCopyWith<_MatchingRoom> get copyWith => __$MatchingRoomCopyWithImpl<_MatchingRoom>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchingRoom&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.player1Id, player1Id) || other.player1Id == player1Id)&&(identical(other.player2Id, player2Id) || other.player2Id == player2Id)&&(identical(other.isMatched, isMatched) || other.isMatched == isMatched)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.winner, winner) || other.winner == winner)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.player1Choice, player1Choice) || other.player1Choice == player1Choice)&&(identical(other.player2Choice, player2Choice) || other.player2Choice == player2Choice)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.change, change) || other.change == change)&&(identical(other.go, go) || other.go == go)&&(identical(other.player1_finish, player1_finish) || other.player1_finish == player1_finish)&&(identical(other.player2_finish, player2_finish) || other.player2_finish == player2_finish)&&(identical(other.player1_go, player1_go) || other.player1_go == player1_go)&&(identical(other.player2_go, player2_go) || other.player2_go == player2_go)&&(identical(other.player1_time, player1_time) || other.player1_time == player1_time)&&(identical(other.player2_time, player2_time) || other.player2_time == player2_time)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.choice1, choice1) || other.choice1 == choice1)&&(identical(other.choice2, choice2) || other.choice2 == choice2)&&(identical(other.password, password) || other.password == password)&&(identical(other.scores, scores) || other.scores == scores)&&(identical(other.isBbs, isBbs) || other.isBbs == isBbs));
}


@override
int get hashCode => Object.hashAll([runtimeType,roomId,player1Id,player2Id,isMatched,createdAt,winner,reason,player1Choice,player2Choice,updatedAt,change,go,player1_finish,player2_finish,player1_go,player2_go,player1_time,player2_time,theme,choice1,choice2,password,scores,isBbs]);

@override
String toString() {
  return 'MatchingRoom(roomId: $roomId, player1Id: $player1Id, player2Id: $player2Id, isMatched: $isMatched, createdAt: $createdAt, winner: $winner, reason: $reason, player1Choice: $player1Choice, player2Choice: $player2Choice, updatedAt: $updatedAt, change: $change, go: $go, player1_finish: $player1_finish, player2_finish: $player2_finish, player1_go: $player1_go, player2_go: $player2_go, player1_time: $player1_time, player2_time: $player2_time, theme: $theme, choice1: $choice1, choice2: $choice2, password: $password, scores: $scores, isBbs: $isBbs)';
}


}

/// @nodoc
abstract mixin class _$MatchingRoomCopyWith<$Res> implements $MatchingRoomCopyWith<$Res> {
  factory _$MatchingRoomCopyWith(_MatchingRoom value, $Res Function(_MatchingRoom) _then) = __$MatchingRoomCopyWithImpl;
@override @useResult
$Res call({
 String? roomId, String? player1Id, String? player2Id, bool? isMatched, DateTime? createdAt, String? winner, String? reason, bool? player1Choice, bool? player2Choice, DateTime? updatedAt, bool? change, bool? go, bool? player1_finish, bool? player2_finish, bool? player1_go, bool? player2_go, DateTime? player1_time, DateTime? player2_time, String? theme, String? choice1, String? choice2, String? password, MatchScores? scores, bool? isBbs
});




}
/// @nodoc
class __$MatchingRoomCopyWithImpl<$Res>
    implements _$MatchingRoomCopyWith<$Res> {
  __$MatchingRoomCopyWithImpl(this._self, this._then);

  final _MatchingRoom _self;
  final $Res Function(_MatchingRoom) _then;

/// Create a copy of MatchingRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = freezed,Object? player1Id = freezed,Object? player2Id = freezed,Object? isMatched = freezed,Object? createdAt = freezed,Object? winner = freezed,Object? reason = freezed,Object? player1Choice = freezed,Object? player2Choice = freezed,Object? updatedAt = freezed,Object? change = freezed,Object? go = freezed,Object? player1_finish = freezed,Object? player2_finish = freezed,Object? player1_go = freezed,Object? player2_go = freezed,Object? player1_time = freezed,Object? player2_time = freezed,Object? theme = freezed,Object? choice1 = freezed,Object? choice2 = freezed,Object? password = freezed,Object? scores = freezed,Object? isBbs = freezed,}) {
  return _then(_MatchingRoom(
roomId: freezed == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String?,player1Id: freezed == player1Id ? _self.player1Id : player1Id // ignore: cast_nullable_to_non_nullable
as String?,player2Id: freezed == player2Id ? _self.player2Id : player2Id // ignore: cast_nullable_to_non_nullable
as String?,isMatched: freezed == isMatched ? _self.isMatched : isMatched // ignore: cast_nullable_to_non_nullable
as bool?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,winner: freezed == winner ? _self.winner : winner // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,player1Choice: freezed == player1Choice ? _self.player1Choice : player1Choice // ignore: cast_nullable_to_non_nullable
as bool?,player2Choice: freezed == player2Choice ? _self.player2Choice : player2Choice // ignore: cast_nullable_to_non_nullable
as bool?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,change: freezed == change ? _self.change : change // ignore: cast_nullable_to_non_nullable
as bool?,go: freezed == go ? _self.go : go // ignore: cast_nullable_to_non_nullable
as bool?,player1_finish: freezed == player1_finish ? _self.player1_finish : player1_finish // ignore: cast_nullable_to_non_nullable
as bool?,player2_finish: freezed == player2_finish ? _self.player2_finish : player2_finish // ignore: cast_nullable_to_non_nullable
as bool?,player1_go: freezed == player1_go ? _self.player1_go : player1_go // ignore: cast_nullable_to_non_nullable
as bool?,player2_go: freezed == player2_go ? _self.player2_go : player2_go // ignore: cast_nullable_to_non_nullable
as bool?,player1_time: freezed == player1_time ? _self.player1_time : player1_time // ignore: cast_nullable_to_non_nullable
as DateTime?,player2_time: freezed == player2_time ? _self.player2_time : player2_time // ignore: cast_nullable_to_non_nullable
as DateTime?,theme: freezed == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String?,choice1: freezed == choice1 ? _self.choice1 : choice1 // ignore: cast_nullable_to_non_nullable
as String?,choice2: freezed == choice2 ? _self.choice2 : choice2 // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,scores: freezed == scores ? _self.scores : scores // ignore: cast_nullable_to_non_nullable
as MatchScores?,isBbs: freezed == isBbs ? _self.isBbs : isBbs // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
