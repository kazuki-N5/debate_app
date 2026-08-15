// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart'; // 実際のパスに合わせて変更してください

// 広告の状態を管理する StateNotifier (autoDisposeなし)
class BannerAdNotifier extends StateNotifier<BannerAd?> {
  BannerAdNotifier() : super(null);

  BannerAd? _bannerAd;

  void loadAd() {
    print('Attempting to load banner ad...');
    // 既存の広告があれば破棄 (再ロードの場合に必要)
    _bannerAd?.dispose();
    _bannerAd = null;
    state = null; // ロード開始前に状態をリセット

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('BannerAd loaded successfully.');
          _bannerAd = ad as BannerAd;
          state = _bannerAd; // 状態を更新
        },
        onAdFailedToLoad: (ad, err) {
          print('BannerAd failed to load: ${err.message}');
          ad.dispose();
          _bannerAd = null;
          state = null; // 状態をクリア
        },
      ),
    )..load();
  }

  // StateNotifier が手動で破棄されるか、ProviderScopeが破棄されるときに呼ばれる
  @override
  void dispose() {
    print('Disposing BannerAdNotifier and BannerAd.');
    _bannerAd?.dispose();
    _bannerAd = null;
    state = null;
    super.dispose();
  }
}

// BannerAdNotifier を提供する Provider (autoDispose なし)
// アプリの生存期間中、または ProviderScope の生存期間中存在し続けます。
final bannerAdProvider = StateNotifierProvider<BannerAdNotifier, BannerAd?>(
  (ref) => BannerAdNotifier(),
);

// MatchingPage 専用の広告プロバイダー（HomePage との競合を避けるため）
final matchingBannerAdProvider = StateNotifierProvider<BannerAdNotifier, BannerAd?>(
  (ref) => BannerAdNotifier(),
);
