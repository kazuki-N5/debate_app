// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

/// コミュニティタブ用の Medium Rectangle 広告 Notifier。
///
/// 1つの `BannerAd` は同時に1箇所にしか表示できない(`AdWidget` を2箇所以上に
/// マウントすると `This widget is already in the widget tree` になる)。
/// そのため、リスト内の**広告スロットごとに個別の `BannerAd`** をロードして、
/// スロット index をキーにした [Map] で保持する。
///
/// タブ(対戦募集/掲示板/クラブ)ごとに独立した Provider を作ることで、
/// タブ間でのインスタンス共有も回避している。
class CommunityAdNotifier extends StateNotifier<Map<int, BannerAd>> {
  CommunityAdNotifier() : super({});

  // ロード中スロット(多重ロード防止)
  final Set<int> _loading = {};
  final Random _random = Random();
  int? _firstAdOffset; // 現在のコンテンツに対する1件目の広告位置(コンテンツ量基準)
  int _lastContentLength = -1;

  /// 指定スロットの広告を返す(まだ未ロードなら null)。
  BannerAd? adForSlot(int slot) => state[slot];

  /// 1件目の広告の開始位置(コンテンツindex)を乱数で決める。
  /// [maxFirstOffset] は「1件目から最大何個後ろまで入れられるか」
  /// (例: 対戦募集・掲示板=1 → 1-2 / 2-3 の間、クラブ=2 → 1-2 / 2-3 / 3-4 の間)。
  /// ビルド毎に位置が飛ばないよう、コンテンツ量が変わったときだけ抽選し直す。
  int resolveFirstAdOffset(int contentLength, int maxFirstOffset) {
    if (contentLength <= 0) return 0;
    final maxStart = min(maxFirstOffset, contentLength - 1);
    if (_lastContentLength != contentLength) {
      _lastContentLength = contentLength;
      _firstAdOffset = _random.nextInt(maxStart + 1);
    }
    return _firstAdOffset!;
  }

  /// 各スロットに**別々の**広告をロードする。既にロード済み/ロード中はスキップ。
  void prepare(Set<int> slots) {
    for (final slot in slots) {
      if (state.containsKey(slot) || _loading.contains(slot)) continue;
      _loading.add(slot);

      BannerAd(
        // テスト/本番切り替えは AdHelper.mbannerAdUnitId が吸収する
        adUnitId: AdHelper.mbannerAdUnitId,
        request: const AdRequest(),
        size: AdSize.mediumRectangle,
        listener: BannerAdListener(
          onAdLoaded: (loaded) {
            final banner = loaded as BannerAd;
            state = <int, BannerAd>{...state, slot: banner};
            _loading.remove(slot);
          },
          onAdFailedToLoad: (ad, err) {
            print('Community Ad($slot) failed: ${err.message}');
            ad.dispose();
            _loading.remove(slot);
          },
        ),
      ).load();
    }
  }

  @override
  void dispose() {
    for (final ad in state.values) {
      ad.dispose();
    }
    super.dispose();
  }
}

// 対戦募集タブ用 (CommunityPage 内の ListView)
final communityRecruitAdProvider =
    StateNotifierProvider<CommunityAdNotifier, Map<int, BannerAd>>(
  (ref) => CommunityAdNotifier(),
);

// 掲示板タブ用 (BbsTimelineView)
final communityBbsAdProvider =
    StateNotifierProvider<CommunityAdNotifier, Map<int, BannerAd>>(
  (ref) => CommunityAdNotifier(),
);

// クラブタブ用 (OpenChatRoomsView)
final communityClubAdProvider =
    StateNotifierProvider<CommunityAdNotifier, Map<int, BannerAd>>(
  (ref) => CommunityAdNotifier(),
);
