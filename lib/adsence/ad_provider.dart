// ファイル名: provider/ad_notifier.dart
import 'dart:async';
import 'package:debate_project/adsence/ad_helper.dart'; // AdHelperのimportを仮定
import 'package:flutter/foundation.dart'; // debugPrint用
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// InterstitialAd? の状態を管理するプロバイダー
final adNotifierProvider = StateNotifierProvider<AdNotifier, bool>((ref) {
  return AdNotifier();
});

class AdNotifier extends StateNotifier<bool> {
  AdNotifier() : super(true); // 初期状態は広告なし

  static const String _adCountKey = 'ad_display_count';
  // 内部で広告インスタンスを保持。Stateは外部に公開する参照
  InterstitialAd? _interstitialAd;
  bool _isLoading = false; // 広告ロード中かどうかを示すフラグ

  // Shared Preferencesから広告表示機会のカウントを取得
  Future<int> _getAdDisplayCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_adCountKey) ?? 0;
    } catch (e) {
      debugPrint('Error getting ad display count: $e');
      return 0; // エラー時はデフォルトで0を返す
    }
  }

  // 広告表示機会のカウントをインクリメント
  Future<void> _incrementAdDisplayCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentCount = prefs.getInt(_adCountKey) ?? 0;
      await prefs.setInt(_adCountKey, currentCount + 1);
      debugPrint('Interstitial Ad Count incremented to ${currentCount + 1}');
    } catch (e) {
      debugPrint('Error incrementing ad display count: $e');
    }
  }

  // 広告を表示すべきかどうかの判定ロジック
  Future<bool> _shouldShowInterstitialAd() async {
    final count = await _getAdDisplayCount();
    // 初回3回 (カウントが0, 1, 2 の時) は表示しない
    if (count < 3) {
      debugPrint(
          'Interstitial Ad Logic: Count ${count}. Not showing (first 3).');
      return false;
    }
    // 3回目以降 (カウントが 3, 4, 5... の時) は交互に表示
    // カウント 3, 5, 7... の時に表示する
    // (count - 3) は 0, 1, 2, 3, 4, 5... となる
    // これの偶数 (0, 2, 4...) に対応するのは (count - 3) % 2 == 0
    if ((count - 3) % 3 == 0) {
      debugPrint(
          'Interstitial Ad Logic: Count ${count}. Showing (alternating).');
      return true;
    } else {
      debugPrint(
          'Interstitial Ad Logic: Count ${count}. Not showing (alternating).');
      return false;
    }
  }

  // 広告をロードするメソッド
  Future<void> loadAd() async {
    if (_interstitialAd != null || _isLoading) {
      debugPrint(
          'Interstitial Ad: Load requested, but already loaded or loading.');
      return;
    }

    _isLoading = true; // ロード開始フラグを立てる

    // 広告表示機会のカウントをインクリメント（ロードを試みる度にカウント）

    // 広告を表示すべきか判定
    final shouldShow = await _shouldShowInterstitialAd();

    // 表示しない場合はロードもスキップ
    if (!shouldShow) {
      debugPrint('Interstitial Ad: Load skipped based on logic.');
      _isLoading = false; // ロードは行わないのでフラグを下ろす
      state = false; // Stateはnullのまま
      return;
    }

    _disposeAdInternal();

    state = true;

    debugPrint('Interstitial Ad: Start loading...');
    // ロード開始時にStateをnullにしても良いが、今回はシンプルに完了時のみ更新

    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId, // AdHelperから広告ユニットIDを取得
      request: const AdRequest(), // 広告リクエスト
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Interstitial Ad: Load successful. ydydydydydydydy');
          _interstitialAd = ad; // StateNotifierの状態を更新（リスナーに通知）
          _isLoading = false;

          // ロードされた広告にフルスクリーンコンテンツコールバックを設定
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('Interstitial Ad: Dismissed.');
             _disposeAdInternal();

              state = false;
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              debugPrint('Interstitial Ad: Failed to show: ${err.message}');
              _disposeAdInternal();
              state = false;
              // 内部でdisposeとstateクリア
              // 表示失敗時も同様にFinishPageからの遷移はここでは行わない
            },
            onAdImpression: (ad) => debugPrint('Interstitial Ad: Impression.'),
            onAdShowedFullScreenContent: (ad) =>
                debugPrint('Interstitial Ad: Shown.'),
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial Ad: Failed to load: ${err.message}');
          _interstitialAd = null; // 内部変数もクリア
          state = false; // StateNotifierの状態を更新
          _isLoading = false; // ロード完了（失敗）
          // ロード失敗時は特に何もしない（FinishPageに遷移して広告が表示されないだけ）
        },
      ),
    );
  }

  // ロード済みの広告を表示するメソッド
  void showAd() {
    if (_interstitialAd != null) {
      debugPrint('Interstitial Ad: Showing...');
      _interstitialAd!.show();
      _incrementAdDisplayCount();
    } else {
      debugPrint('Interstitial Ad: No ad loaded to show or load failed.');
      _disposeAdInternal();
      _incrementAdDisplayCount();
      // 表示する広告がない場合、特に何もせずFinishPageに留まる
    }
  }

  // 広告を破棄するメソッド（Widgetのdisposeなどで呼ばれる用）
  void disposeAd() {
    debugPrint('Interstitial Ad: Manual dispose requested.');
    _disposeAdInternal();
  }

  // 内部的な広告破棄処理とStateクリア
  void _disposeAdInternal() {
    _interstitialAd?.dispose(); // 広告インスタンスを破棄
    _interstitialAd = null; // 内部変数もクリア
    // StateNotifierのStateもクリア
    // StateNotifierの状態と内部変数を一致させる
    state = false;
    _isLoading = false; // ロード中フラグもリセット
  }

  // Notifier破棄時のクリーンアップ
  @override
  void dispose() {
    debugPrint('AdNotifier: Disposing.');
    _disposeAdInternal(); // Notifier破棄時に広告も破棄
    super.dispose();
  }
}
