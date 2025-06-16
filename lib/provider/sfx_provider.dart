import 'package:audioplayers/audioplayers.dart';
import 'package:debate_project/provider/setting_provider.dart'; // 必要に応じてパスを調整
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// SoundServiceを提供するProvider (変更なし)
final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService(ref);
});

class SoundService {
  final Ref _ref;
  // 効果音専用のAudioPlayerインスタンスを作成 (変更なし)
  final AudioPlayer _sfxPlayer = AudioPlayer();

  SoundService(this._ref) {
    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
  }

  /// 指定されたパスの効果音を再生します。
  /// 設定に基づいて再生可否と音量を判断します。
  Future<void> playSfx(String assetPath) async {
    // settingsProviderから *現在の* 設定状態を読み込む
    final settings = _ref.read(settingsProvider);

    // 効果音がオフ、または音量が0以下の場合は再生しない
    if (!settings.isSfxOn || settings.sfxVolume <= 0) {
      if (kDebugMode) {
        print("SFX is off or volume is 0. Not playing: $assetPath");
      }
      return;
    }

    try {
      // 再生 *前* に設定に基づいて音量を設定
      await _sfxPlayer.setVolume(settings.sfxVolume);
      // 効果音を再生 (AssetSourceを使用)
      await _sfxPlayer.play(AssetSource(assetPath));
      if (kDebugMode) {
        print("Playing SFX: $assetPath at volume ${settings.sfxVolume}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("効果音の再生中にエラーが発生しました: $e");
      }
      // エラーを適切に処理
    }
  }

  /// AudioPlayerリソースを解放します。
  void dispose() {
     _sfxPlayer.dispose();
     if (kDebugMode) {
        print("SoundService disposed.");
     }
  }
}

/// 効果音アセットのパスを定数で管理するクラス (変更なし)
class SfxAssets {
  static const String go = 'sfx/go.mp3';
  static const String normal = 'sfx/normal.mp3';
  // 他の効果音もここに追加できます
}