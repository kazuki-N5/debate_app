// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/adsence/ad_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class MediumRectangleAdNotifier extends StateNotifier<BannerAd?> {
  // コンストラクタ名と StateNotifier 型は異なるが、状態は同じ BannerAd?
  MediumRectangleAdNotifier() : super(null);

  // 管理する Medium Rectangle Ad インスタンス（型は BannerAd のまま）
  BannerAd? _mediumRectangleAd;

  void loadAd() {
    print('Attempting to load medium rectangle ad...');
    // 既存の広告があれば破棄
    _mediumRectangleAd?.dispose();
    _mediumRectangleAd = null;
    state = null; // ロード開始前に状態をリセット

    _mediumRectangleAd = BannerAd(
      // AdHelper から Medium Rectangle Ad 用の広告ユニットIDを取得
      // AdHelper に mediumRectangleAdUnitId を追加する必要があります
      adUnitId: AdHelper.mbannerAdUnitId,
      request: const AdRequest(),
      // 広告サイズを mediumRectangle に指定 ← ★変更点
      size: AdSize.mediumRectangle,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Medium Rectangle Ad loaded successfully.');
          // ロードされた広告をインスタンス変数と状態に設定
          _mediumRectangleAd = ad as BannerAd;
          state = _mediumRectangleAd; // 状態を更新
        },
        onAdFailedToLoad: (ad, err) {
          print('Medium Rectangle Ad failed to load: ${err.message}');
          // ロード失敗時は広告を破棄し、インスタンス変数と状態をクリア
          ad.dispose();
          _mediumRectangleAd = null;
          state = null; // 状態をクリア
        },
         // その他のリスナーイベントも必要に応じて追加
        // onAdOpened: (ad) => print('Medium Rectangle Ad opened.'),
        // onAdClosed: (ad) => print('Medium Rectangle Ad closed.'),
      ),
    )..load();
  }

  // dispose もNotifier名、変数名、print文を変更
  @override
  void dispose() {
    print('Disposing MediumRectangleAdNotifier and medium rectangle ad.');
    _mediumRectangleAd?.dispose();
    _mediumRectangleAd = null;
    state = null;
    super.dispose();
  }
}

// MediumRectangleAdNotifier を提供する Provider (autoDispose なし)
final mediumRectangleAdProvider = StateNotifierProvider<MediumRectangleAdNotifier, BannerAd?>(
  // StateNotifier のインスタンスを返す部分を変更
  (ref) => MediumRectangleAdNotifier(),
);
