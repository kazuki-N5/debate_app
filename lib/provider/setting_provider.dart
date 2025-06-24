import 'package:debate_project/modes/setting_model.dart'; // パスを修正してください
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SharedPreferencesで使用するキー (サウンド関連を削除)
// const String _keySoundVolume = 'soundVolume';
// const String _keyIsSoundOn = 'isSoundOn';
const String _keySfxVolume = 'sfxVolume';
const String _keyIsSfxOn = 'isSfxOn';
const String _keyIsVibrationOn = 'isVibrationOn';
const String _keyIsPremiumUser = 'isPremiumUser';

// StateNotifierProviderの定義 (変更なし)
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<SettingsModel> {
  SharedPreferences? _prefs;

  // コンストラクタ: 初期状態は変更されたSettingsModelに合わせる
  SettingsNotifier() : super(const SettingsModel()) {
    loadSettings();
  }

  // 設定を非同期で読み込む (サウンド関連を削除)
  Future<void> loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // 各キーから値を読み込み、存在しない場合は現在のstateのデフォルト値を使用
      final loadedState = SettingsModel(
        // soundVolume: _prefs?.getDouble(_keySoundVolume) ?? state.soundVolume, // 削除
        // isSoundOn: _prefs?.getBool(_keyIsSoundOn) ?? state.isSoundOn,       // 削除
        sfxVolume: _prefs?.getDouble(_keySfxVolume) ?? state.sfxVolume,
        isSfxOn: _prefs?.getBool(_keyIsSfxOn) ?? state.isSfxOn,
        isVibrationOn: _prefs?.getBool(_keyIsVibrationOn) ?? state.isVibrationOn,
        isPremiumUser: _prefs?.getBool(_keyIsPremiumUser) ?? state.isPremiumUser,
      );
      // 読み込んだ値で状態を更新
      // `mounted` プロパティは StateNotifier にはないためチェック不要
      if (mounted) {
         state = loadedState;
      }


      // もしSharedPreferencesに何も保存されていなければ、
      // 現在のデフォルト状態を保存しておく
      if (_prefs?.getKeys().isEmpty ?? true) {
          await _saveSettings(state);
      }

    } catch (e) {
      if (kDebugMode) {
        print("Error loading settings: $e");
      }
      // エラー時もデフォルト値で続行し、可能ならデフォルト値を保存
      if (_prefs != null && mounted) {
        await _saveSettings(state); // デフォルト値を保存試行
      }
    }
  }

  // 設定をSharedPreferencesに保存する (サウンド関連を削除)
  Future<void> _saveSettings(SettingsModel newState) async {
    // SharedPreferencesが初期化されるまで待つか、初期化を試みる
    _prefs ??= await SharedPreferences.getInstance();
    // それでもnullなら保存できない
    if (_prefs == null) {
      if (kDebugMode) {
        print("Failed to initialize SharedPreferences. Cannot save settings.");
      }
      return;
    }

    // 各値を個別のキーで保存
    // await _prefs?.setDouble(_keySoundVolume, newState.soundVolume); // 削除
    // await _prefs?.setBool(_keyIsSoundOn, newState.isSoundOn);       // 削除
    await _prefs?.setDouble(_keySfxVolume, newState.sfxVolume);
    await _prefs?.setBool(_keyIsSfxOn, newState.isSfxOn);
    await _prefs?.setBool(_keyIsVibrationOn, newState.isVibrationOn);
    await _prefs?.setBool(_keyIsPremiumUser, newState.isPremiumUser);
  }

  // サウンド関連の更新メソッドを削除
  // Future<void> setSoundVolume(double volume) async { ... } // 削除
  // Future<void> toggleSound(bool isOn) async { ... }      // 削除

  // 効果音の音量を更新するメソッド
  Future<void> setSfxVolume(double volume) async {
    final newState = state.copyWith(sfxVolume: volume);
     if (mounted) {
      state = newState;
      await _saveSettings(newState);
    }
  }

  // 効果音のオン/オフを切り替えるメソッド
  Future<void> toggleSfx(bool isOn) async {
    final newState = state.copyWith(isSfxOn: isOn);
     if (mounted) {
      state = newState;
      await _saveSettings(newState);
    }
  }

  // 振動のオン/オフを切り替えるメソッド
  Future<void> toggleVibration(bool isOn) async {
    final newState = state.copyWith(isVibrationOn: isOn);
    if (mounted) {
      state = newState;
      await _saveSettings(newState);
    }
  }

  // 課金状態を更新するメソッド
  Future<void> setPremiumStatus(bool isPremium) async {
    final newState = state.copyWith(isPremiumUser: isPremium);
    if (mounted) {
      state = newState;
      await _saveSettings(newState);
    }
    // 必要に応じて、広告非表示などの関連ロジックをトリガー
  }
}