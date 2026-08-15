// ignore_for_file: file_names, avoid_print, use_build_context_synchronously, non_constant_identifier_names
import 'package:debate_project/modes/debate_scores.dart';
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
    String? winner,
    String? reason,
    bool? player1Choice,
    bool? player2Choice,
    DateTime? updatedAt,
    bool? change,
    bool? go,
    bool? player1_finish,
    bool? player2_finish,
    bool? player1_go,
    bool? player2_go,
    DateTime? player1_time,
    DateTime? player2_time,
    String? theme,
    String? choice1,
    String? choice2,
    String? password,
    MatchScores? scores,
    bool? isBbs,
  }) = _MatchingRoom;

  factory MatchingRoom.fromMap(Map<String, dynamic> map) {
    MatchScores? parsedScores;
    if (map['scores'] != null) {
      if (map['scores'] is Map<String, dynamic>) {
        parsedScores = MatchScores.fromMap(map['scores'] as Map<String, dynamic>);
      } else if (map['scores'] is String) {
        parsedScores = MatchScores.fromJsonString(map['scores'] as String);
      }
    }

    return MatchingRoom(
      roomId: map['id']?.toString(),
      player1Id: map['player1_id']?.toString(),
      player2Id: map['player2_id']?.toString(),
      isMatched: map['is_matched'],
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : null,
      winner: map['winner']?.toString(),
      reason: map['reason']?.toString(),
      player1Choice: map['player1_choice'],
      player2Choice: map['player2_choice'],
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
      change: map['change'],
      go: map['go'],
      player1_finish: map['player1_finish'],
      player2_finish: map['player2_finish'],
      player1_go: map['player1_go'],
      player2_go: map['player2_go'],
      player1_time: map['player1_time'] != null 
          ? DateTime.parse(map['player1_time']) 
          : null,
      player2_time: map['player2_time'] != null 
          ? DateTime.parse(map['player2_time']) 
          : null,
      theme: map['current_theme'],
      choice1: map['current_choice1'],
      choice2: map['current_choice2'],
      password: map['password'],
      scores: parsedScores,
      isBbs: map['is_bbs'],
    );
  }
}
