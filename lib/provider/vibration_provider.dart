// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
// lib/services/vibration_service.dart (新規作成)
import 'package:debate_project/provider/setting_provider.dart'; // settingsProvider のパス
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // HapticFeedback を使う場合
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vibration/vibration.dart';

// VibrationServiceを提供するProvider
final vibrationServiceProvider = Provider<VibrationService>((ref) {
  return VibrationService(ref);
});

class VibrationService {
  final Ref _ref;

  VibrationService(this._ref);

  /// 短いデフォルトのバイブレーションを発生させます。
  /// 設定で振動がオフになっている場合は何もしません。
  Future<void> vibrateShort() async {
    // 設定を読み込む
    final settings = _ref.read(settingsProvider);

    // 振動がオフなら何もしない
    if (!settings.isVibrationOn) {
      if (kDebugMode) {
        print("Vibration is off. Skipping vibration.");
      }
      return;
    }

    try {
      
      
        // 短い振動 (例: 50ミリ秒)
        // Duration を調整してお好みの短さにしてください
        Vibration.vibrate(duration: 50);
        if (kDebugMode) {
          print("Vibrated for 50ms");
        }
     
    } catch (e) {
      if (kDebugMode) {
        print("Error during vibration: $e");
      }
      // エラーハンドリング (必要に応じて)
    }
  }

  /// より軽い触覚フィードバック (クリック感など) を発生させます。
  /// 設定で振動がオフになっている場合は何もしません。
  /// HapticFeedbackはより細かい制御が可能ですが、Vibrationよりサポート状況が限定的かもしれません。
  Future<void> hapticFeedbackLight() async {
    final settings = _ref.read(settingsProvider);
    if (!settings.isVibrationOn) {
      return;
    }
    try {
      await HapticFeedback.lightImpact();
       if (kDebugMode) {
          print("Performed light haptic feedback.");
       }
    } catch (e) {
      if (kDebugMode) {
        print("Error during haptic feedback: $e");
      }
    }
  }

  // 他の種類のバイブレーションや触覚フィードバックメソッドも追加できます
  // 例: Future<void> vibratePattern() async { ... }
  // 例: Future<void> hapticFeedbackMedium() async { ... }
}
