// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/views/bbs/BbsTimelineView.dart';
import 'package:debate_project/views/open_chat/OpenChatRoomsView.dart';
import 'package:debate_project/widgets/fast_page_scroll_physics.dart';
import 'package:debate_project/widgets/keep_alive_page.dart';
import 'package:debate_project/widgets/resba_attach_sheet.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:go_router/go_router.dart';

class CommunityPage extends HookConsumerWidget {
  final PageController? parentPageController;
  const CommunityPage({super.key, this.parentPageController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 対戦募集(レスバ募集型)一覧
    final recruitAsync = ref.watch(recruitResbasProvider);

    final tabController = useTabController(initialLength: 3);

    useEffect(() {
      void listener() {
        if (tabController.indexIsChanging) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      }
      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFF3F3F3), // 背景色
        floatingActionButton: ListenableBuilder(
          listenable: tabController,
          builder: (context, _) {
            // 対戦募集タブは内側の⚔️FABで作成するため外側FABは非表示
            if (tabController.index == 0) return const SizedBox.shrink();
            return Builder(
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 70.0),
                  child: FloatingActionButton(
                    heroTag: null, // Heroアニメーションを無効化
                    onPressed: () {
                      final index = tabController.index;
                      if (index == 1) {
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
            );
          },
        ),
        appBar: AppBar(
          title: Text(
            'コミュニティ',
            style: AppTextStyles.bold(color: Colors.white, fontSize: 20),
          ),
          backgroundColor: Colors.blue,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          bottom: TabBar(
            controller: tabController,
            onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            dividerColor: Colors.white30,
            tabs: [
              Tab(text: '対戦募集'),
              Tab(text: '掲示板'),
              Tab(text: 'オープンチャット'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  return NotificationListener<OverscrollNotification>(
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
                    child: TabBarView(
                      controller: tabController,
                      physics: const FastPageScrollPhysics(parent: ClampingScrollPhysics()),
                      children: [
                  // 対戦募集タブ(レスバ募集型: ポスト/コメントと同じ応募制)
                  // RepaintBoundary: タブ切替中もこのページのレイヤーをキャッシュしてカクつきを防ぐ
                  RepaintBoundary(
                    child: KeepAlivePage(
                      child: Scaffold(
                        backgroundColor: Colors.white,
                        floatingActionButton: FloatingActionButton(
                          backgroundColor: const Color(0xFF7856FF),
                          child: const Text('⚔️', style: TextStyle(fontSize: 22)),
                          onPressed: () => _showCreateResbaDialog(context, ref),
                        ),
                        body: RefreshIndicator(
                          onRefresh: () =>
                              ref.read(recruitResbasProvider.notifier).fetch(),
                          child: recruitAsync.when(
                            data: (invites) {
                              if (invites.isEmpty) {
                                return ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 160),
                                    Center(
                                      child: Text(
                                        '募集中のレスバはありません',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: invites.length,
                                itemBuilder: (context, index) => ResbaCard(
                                  invite: invites[index],
                                  onChanged: () => ref
                                      .read(recruitResbasProvider.notifier)
                                      .fetch(),
                                ),
                              );
                            },
                            loading: () =>
                                const Center(child: CircularProgressIndicator()),
                            error: (e, st) => Center(
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
             );
            },
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