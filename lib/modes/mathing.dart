import 'package:freezed_annotation/freezed_annotation.dart';

part 'mathing.freezed.dart';

@freezed
class MatchingRoom with _$MatchingRoom {
  factory MatchingRoom({
    String? roomId,
    String? player1Id,
    String? player2Id,
    bool? isMatched,
    DateTime? createdAt,
    String? result,
    bool? player1Choice,
    bool? player2Choice,
    DateTime? updatedAt,
    bool? change,
    bool? go,
    bool? player1_finish,
    bool? player2_finish,
    DateTime? player1_time,
    DateTime? player2_time,
    String? theme,
    String? choice1,
    String? choice2,
    String? password,
  }) = _MatchingRoom;

  factory MatchingRoom.fromMap(Map<String, dynamic> map) {
    return MatchingRoom(
      roomId: map['id']?.toString(),
      player1Id: map['player1_id']?.toString(),
      player2Id: map['player2_id']?.toString(),
      isMatched: map['is_matched'],
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : null,
      result: map['result']?.toString(),
      player1Choice: map['player1_choice'],
      player2Choice: map['player2_choice'],
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
      change: map['change'],
      player1_finish: map['player1_finish'],
      player2_finish: map['player2_finish'],
      player1_time: map['player1_time'] != null 
          ? DateTime.parse(map['player1_time']) 
          : null,
      player2_time: map['player2_time'] != null 
          ? DateTime.parse(map['player2_time']) 
          : null,
      theme: map['current_theme']?.toString(),
      choice1: map['current_choice1']?.toString(),
      choice2: map['current_choice2']?.toString(),
      password: map['password']?.toString(),
    );
  }
}