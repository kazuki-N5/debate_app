import 'package:freezed_annotation/freezed_annotation.dart';

part 'setting_model.freezed.dart';
// オプション: SharedPreferences にJSONとして保存する場合
// part 'settings_model.g.dart';

@freezed
class SettingsModel with _$SettingsModel {
  const factory SettingsModel({
    @Default(0.8) double soundVolume,
    @Default(true) bool isSoundOn,
    @Default(0.8) double sfxVolume,
    @Default(true) bool isSfxOn,
    @Default(true) bool isVibrationOn,
    // 課金状態など、必要に応じて追加
    @Default(false) bool isPremiumUser,
  }) = _SettingsModel;

  // オプション: SharedPreferences にJSONとして保存する場合
  // factory SettingsModel.fromJson(Map<String, dynamic> json) =>
  //     _$SettingsModelFromJson(json);
}