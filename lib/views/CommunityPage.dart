// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/views/bbs/BbsTimelineView.dart';
import 'package:debate_project/views/open_chat/OpenChatRoomsView.dart';
import 'package:debate_project/widgets/keep_alive_page.dart';
import 'package:debate_project/widgets/resba_attach_sheet.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:debate_project/widgets/community_ad.dart';
import 'package:debate_project/adsence/ad_community_provider.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:go_router/go_router.dart';

/// 常時表示のバナー広告(非課金時のみ下部に浮かぶ)との重なりを避けるための余白。
/// HomePage 側の計算(CircleNavBar 高さ 60 + 中央円の張り出し 19.2 + バナー高さ 50 =
/// バナー上端が画面底から約 129)を確実にクリアできる値。
/// 課金(広告なし)時はバナーが無いため、この余白は使わない。
const double _floatingBannerClearance = 150.0;

class CommunityPage extends HookConsumerWidget {
  final PageController? parentPageController;
  const CommunityPage({super.key, this.parentPageController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 対戦募集(レスバ募集型)一覧
    final recruitAsync = ref.watch(recruitResbasProvider);

    final tabController = useTabController(initialLength: 3);
    final pageController = usePageController(initialPage: 0);

    // --- コミュニティ(対戦募集タブ)用の Medium Rectangle 広告 ---
    // スロット index -> 個別の BannerAd(スロットごとに別インスタンス)
    final recruitAds = ref.watch(communityRecruitAdProvider);
    final isSubscribed = ref.watch(inAppPurchaseManagerProvider).isSubscribed;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF3F3F3), // 背景色
      floatingActionButton: ListenableBuilder(
        listenable: tabController,
        builder: (context, _) {
          // 常時表示バナー広告(非課金時)にプラスボタンが隠れないよう上へずらす。
          // 課金(広告なし)時は従来どおりの位置に戻す。
          final fabBottom = isSubscribed ? 70.0 : _floatingBannerClearance;
          return Padding(
            padding: EdgeInsets.only(bottom: fabBottom),
            child: FloatingActionButton(
              heroTag: null, // Heroアニメーションを無効化
              onPressed: () {
                final index = tabController.index;
                if (index == 0) {
                  _showCreateResbaDialog(context, ref);
                } else if (index == 1) {
                  context.push('/bbsPostCreate');
                } else if (index == 2) {
                  context.push('/createOpenChat');
                }
              },
              backgroundColor: Colors.blue,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          );
        },
      ),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'コミュニティ',
          style: AppTextStyles.bold(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: tabController,
              onTap: (index) {
                FocusManager.instance.primaryFocus?.unfocus();
                pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
              },
              labelColor: const Color(0xFF1D9BF0),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF1D9BF0),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: AppTextStyles.bold(fontSize: 14),
              unselectedLabelStyle: AppTextStyles.bold(fontSize: 14),
              dividerColor: const Color(0xFFE6E6E6),
              tabs: const [
                Tab(text: '対戦募集'),
                Tab(text: '掲示板'),
                Tab(text: 'クラブ'),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<OverscrollNotification>(
              onNotification: (OverscrollNotification notification) {
                // インデックス2(オープンチャット)で右から左へスワイプしたとき(overscroll > 0)
                if (tabController.index == 2 && notification.overscroll > 0) {
                  if (parentPageController != null && (parentPageController!.page ?? 0) < 1) {
                    parentPageController!.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                  return true;
                }
                return false;
              },
              child: PageView(
                controller: pageController,
                onPageChanged: (index) {
                  tabController.animateTo(index);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                children: [
                  // 対戦募集タブ(レスバ募集型: ポスト/コメントと同じ応募制)
                  // RepaintBoundary: タブ切替中もこのページのレイヤーをキャッシュしてカクつきを防ぐ
                  RepaintBoundary(
                    child: KeepAlivePage(
                      child: Scaffold(
                        backgroundColor: Colors.white,
                        body: RefreshIndicator(
                          onRefresh: () =>
                              ref.read(recruitResbasProvider.notifier).fetch(),
                          child: recruitAsync.when(
                            data: (invites) {
                              if (invites.isEmpty) {
                                // 0件のときは広告のみ表示(課金で広告なしなら従来の空メッセージ)
                                if (!isSubscribed) {
                                  ref
                                      .read(communityRecruitAdProvider
                                          .notifier)
                                      .prepare({0});
                                  return ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      const SizedBox(height: 60),
                                      Padding(
                                        padding:
                                            const EdgeInsets.fromLTRB(
                                                16, 8, 16, 96),
                                        child: recruitAds[0] != null
                                            ? communityAdWidget(
                                                recruitAds[0]!)
                                            : communityAdPlaceholder(),
                                      ),
                                    ],
                                  );
                                }
                                return ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 160),
                                    Center(
                                      child: Text(
                                        '募集中・対戦中のレスバはありません',
                                        style:
                                            TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Builder(builder: (context) {
                                // 対戦募集は件数が少ないので「5件ごとに1個」広告を挟む(開始位置はランダム)
                                final adSlots = !isSubscribed
                                    ? communityAdSlotIndexes(
                                        invites.length,
                                        5,
                                        startContentIndex: ref
                                            .read(
                                                communityRecruitAdProvider
                                                    .notifier)
                                            .resolveFirstAdOffset(
                                                invites.length, 1),
                                      )
                                    : <int>{};
                                final totalItems =
                                    invites.length + adSlots.length;

                                // 各広告スロットに個別の広告をロード(多重ロードはProvider側で防止)
                                if (adSlots.isNotEmpty) {
                                  ref
                                      .read(communityRecruitAdProvider.notifier)
                                      .prepare(adSlots);
                                }

                                return ListView.builder(
                                  // 常時表示バナー広告(非課金時)が下部に浮かぶため、その分
                                  // スクロール下余白を増やし、一番下のカードまで隠れずに
                                  // 表示できるようにする。課金(広告なし)は従来どおり。
                                  padding: EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      isSubscribed
                                          ? 96.0
                                          : _floatingBannerClearance),
                                  itemCount: totalItems,
                                  itemBuilder: (context, index) {
                                    if (adSlots.contains(index)) {
                                      final slotAd = recruitAds[index];
                                      return slotAd != null
                                          ? communityAdWidget(slotAd)
                                          : communityAdPlaceholder();
                                    }
                                    final inviteValue = invites[
                                        communityContentIndex(
                                            index, adSlots)];
                                    return ResbaCard(
                                      invite: inviteValue,
                                      onChanged: () => ref
                                          .read(recruitResbasProvider.notifier)
                                          .fetch(),
                                    );
                                  },
                                );
                              });
                            },
                            loading: () =>
                                const Center(child: CircularProgressIndicator()),
                            error: (e, st) => const Center(
                              child: Text(
                                '読み込みに失敗しました',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 掲示板タブ
                  const RepaintBoundary(
                    child: KeepAlivePage(child: BbsTimelineView()),
                  ),
                  // オープンチャットタブ
                  const RepaintBoundary(
                    child: KeepAlivePage(child: OpenChatRoomsView()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚔️ 対戦募集(レスバ募集型)を作成する(ポスト/コメントと同じ募集型)
  Future<void> _showCreateResbaDialog(BuildContext context, WidgetRef ref) async {
    final attachment = await showResbaAttachSheet(context);
    if (attachment == null || !context.mounted) return;

    final result = await ref.read(resbaActionsProvider).createRecruitResba(
          theme: attachment.theme,
          choice1: attachment.choice1,
          choice2: attachment.choice2,
        );

    if (result.error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('募集を作成しました')));
    }
    ref.read(recruitResbasProvider.notifier).fetch();
  }
}