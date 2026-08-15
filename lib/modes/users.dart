// ignore_for_file: file_names, avoid_print, use_build_context_synchronously, non_constant_identifier_names
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
    String? fcm_token,
    bool? is_notification_enabled,
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
       fcm_token: map['fcm_token']?.toString(),
       is_notification_enabled: map['is_notification_enabled'] as bool? ?? false,
    );
  }
}
