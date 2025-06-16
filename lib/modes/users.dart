import 'package:freezed_annotation/freezed_annotation.dart';

part 'users.freezed.dart';

@freezed
class Users with _$Users {
  const factory Users({
    required String id,
    String? name,
    required int trophy,
    int? win,
    int? lose,
    String? avatar_url,
    bool? status,
  }) = _Users;

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      id: map['id']!.toString(),
      name: map['name'].toString(),
      trophy: map['trophy']?.toInt(),
      win: map['win']?.toInt(),
      lose: map['lose']?.toInt(),
      avatar_url: map['avatar_url']?.toString(),
       status: map['status'] as bool?,
    );
  }
}