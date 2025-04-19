import 'package:freezed_annotation/freezed_annotation.dart';

part 'users.freezed.dart';

@freezed
class Users with _$Users {
  const factory Users({
    required String id,
    required String name,
    required int trophy,
  }) = _Users;

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      id: map['id']!.toString(),
      name: map['name']!.toString(),
      trophy: map['trophy']?.toInt(),
    );
  }
}