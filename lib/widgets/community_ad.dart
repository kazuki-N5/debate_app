// ignore_for_file: file_names, avoid_print
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// リスト内に広告を挟む際の共通ヘルパー。
///
/// [startContentIndex](コンテンツindex)の**直後から** [interval] 件ごとに広告スロットを
/// 挟む。結合リスト(コンテンツ+広告)の index を返す。
/// コンテンツが0件でも `{0}`(広告のみ)を返し、広告が消えないようにする。
/// 開始位置(最初の広告をどの範囲に入れるか)は呼び出し側で乱数決定する
/// (`CommunityAdNotifier.resolveFirstAdOffset` を使う)。
///
/// ⚠️ スロットごとに **別々の `BannerAd`**(Provider の `prepare` / `adForSlot`)を
/// 使うこと。同じ `BannerAd` を複数スロットで使い回すと
/// `This widget is already in the widget tree` になる。
Set<int> communityAdSlotIndexes(
  int contentLength,
  int interval, {
  int startContentIndex = 0,
}) {
  // 0件でも広告は1つ表示する(「広告だけ」の状態を許容)
  if (contentLength <= 0) return {0};

  final slots = <int>{};
  int combined = 0;
  for (int c = 0; c < contentLength; c++) {
    combined++; // コンテンツを1つ配置
    // 開始位置から interval 件ごとに広告を挟む
    if (c >= startContentIndex && (c - startContentIndex) % interval == 0) {
      slots.add(combined);
      combined++;
    }
  }
  return slots;
}

/// 結合リストの index [combinedIndex] から、コンテンツ側の index を逆算する。
/// 広告スロット位置の index を渡さないこと(渡すとコンテンツ mapping がずれる)。
int communityContentIndex(int combinedIndex, Set<int> adSlots) {
  return combinedIndex - adSlots.where((s) => s < combinedIndex).length;
}

/// Medium Rectangle 広告スロットを中央寄せで表示する Widget。
/// スロットごとの [ad](個別の `BannerAd`)を渡すこと。
Widget communityAdWidget(BannerAd ad) {
  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(vertical: 16),
    color: Colors.white,
    child: SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    ),
  );
}

/// ホーム下部に常時表示するバナー(オーバーレイ)に被らないよう確保する余白量。
///
/// 各タブのスクロールコンテンツがこのバナーに隠れないよう、スクロールリストの
/// 下端パディングやFABの下余白に用いる。コミュニティの既存定数
/// `_floatingBannerClearance = 150.0` と揃えている(バナー高さ＋ナビバー＋円の張り出し
/// に少し余裕を持たせた値)。
double homeBottomAdClearance() => 150.0;

/// 広告未ロード時は**何も表示しない**。
/// ロード完了時にその場へ広告が表示される。未ロード時は高さ0のため、
/// ロード成功時は下のコンテンツが広告ぶんだけ下がる(「ずれる」)。
Widget communityAdPlaceholder() => const SizedBox.shrink();
