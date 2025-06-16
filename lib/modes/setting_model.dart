import 'package:freezed_annotation/freezed_annotation.dart';

part 'setting_model.freezed.dart'; // ファイル名を実際のプロジェクトに合わせてください

@freezed
class SettingsModel with _$SettingsModel {
  const factory SettingsModel({
    @Default(0.8) double sfxVolume,
    @Default(true) bool isSfxOn,
    @Default(true) bool isVibrationOn,
    @Default(false) bool isPremiumUser,
  }) = _SettingsModel;
}