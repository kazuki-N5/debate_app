// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/provider/bbs_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/views/bbs/BbsTimelineView.dart';
import 'package:debate_project/views/open_chat/OpenChatRoomsView.dart';
import 'package:debate_project/widgets/fast_page_scroll_physics.dart';
import 'package:debate_project/widgets/keep_alive_page.dart';
import 'package:go_router/go_router.dart';
import 'package:debate_project/utils/date_formatter.dart';

class CommunityPage extends HookConsumerWidget {
  final PageController? parentPageController;
  const CommunityPage({super.key, this.parentPageController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bbsRooms = ref.watch(bbsListProvider);
    final bbsListNotifier = ref.read(bbsListProvider.notifier);
    final currentUserId = ref.watch(currentUserIdProvider);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bbsListNotifier.fetchRooms();
      });
      return null;
    }, []);

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
        floatingActionButton: Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 70.0),
              child: FloatingActionButton(
                heroTag: null, // Heroアニメーションを無効化
                onPressed: () {
                  final index = tabController.index;
                  if (index == 0) {
                    _showCreateRoomDialog(context, ref);
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
          }
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
                  // 対戦募集タブ
                  // RepaintBoundary: タブ切替中もこのページのレイヤーをキャッシュしてカクつきを防ぐ
                  RepaintBoundary(
                    child: KeepAlivePage(
                      child: Scaffold(
                      backgroundColor: Colors.white,
                      body: RefreshIndicator(
              onRefresh: bbsListNotifier.fetchRooms,
              child: bbsRooms.isEmpty
                  ? Center(
                      child: Text(
                        '現在募集中のルームはありません',
                        style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: MediaQuery.of(context).padding.bottom + 80,
                      ),
                itemCount: bbsRooms.length,
                itemBuilder: (context, index) {
                  final room = bbsRooms[index];
                  return Card(
                    color: const Color(0xFFF3F3F3),
                    elevation: 0, // フラットなカードデザイン
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final hostName = room.hostUser?.name ?? '名無し';
                              final hostAvatar = room.hostUser?.avatar_url;
                              final dateStr = DateFormatter.formatBbsDate(room.createdAt);
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        context.push('/userProfile', extra: room.player1Id);
                                      },
                                      child: CircleAvatar(
                                        backgroundImage: hostAvatar != null && hostAvatar.isNotEmpty
                                            // 表示サイズ(radius16=32px)に縮小デコードしてカクつきを抑える
                                            ? ResizeImage(NetworkImage(hostAvatar), width: 96)
                                            : null,
                                        child: hostAvatar == null || hostAvatar.isEmpty ? const Icon(Icons.person, size: 20) : null,
                                        radius: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(hostName, style: AppTextStyles.bold(fontSize: 14)),
                                          Text(dateStr, style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  room.theme.isEmpty ? 'テーマなし' : room.theme,
                                  style: AppTextStyles.bold(fontSize: 18),
                                ),
                              ),
                              if (room.hasPassword)
                                const Icon(Icons.lock, color: Colors.orange, size: 20),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '選択肢: ${room.choice1} vs ${room.choice2}',
                            style: AppTextStyles.notoSans(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: room.player1Id == currentUserId
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: null,
                                    child: Text(
                                      '自分の募集です',
                                      style: AppTextStyles.bold(color: Colors.white),
                                    ),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: () {
                                      _showApplyDialog(context, ref, room);
                                    },
                                    child: Text(
                                      '申し込む',
                                      style: AppTextStyles.bold(color: Colors.white),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

  void _showApplyDialog(BuildContext context, WidgetRef ref, BbsRoomInfo room) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            room.hasPassword ? 'パスワードを入力' : 'このルームに申し込みますか？',
            style: AppTextStyles.bold(fontSize: 18),
          ),
          content: room.hasPassword
              ? TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(hintText: 'パスワード'),
                  obscureText: true,
                )
              : null,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text;
                if (room.hasPassword && password.isEmpty) return;

                Navigator.pop(context);
                final error = await ref.read(bbsGuestProvider.notifier).applyToRoom(room.id, password);
                if (error != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('申し込みました。ホストの承認を待っています...')));
                  }
                }
              },
              child: const Text('申し込む'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref) {
    final themeController = TextEditingController();
    final choice1Controller = TextEditingController();
    final choice2Controller = TextEditingController();
    final passwordController = TextEditingController();
    
    bool isCustomTheme = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('新規募集作成', style: AppTextStyles.bold(fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: isCustomTheme,
                          onChanged: (val) {
                            setState(() {
                              isCustomTheme = val ?? false;
                            });
                          },
                        ),
                        Text('テーマを自分で設定する', style: AppTextStyles.notoSans(fontSize: 14)),
                      ],
                    ),
                    if (isCustomTheme) ...[
                      TextField(
                        controller: themeController,
                        decoration: const InputDecoration(labelText: 'テーマ'),
                      ),
                      TextField(
                        controller: choice1Controller,
                        decoration: const InputDecoration(labelText: '選択肢1'),
                      ),
                      TextField(
                        controller: choice2Controller,
                        decoration: const InputDecoration(labelText: '選択肢2'),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          '※テーマと選択肢はランダムに決定されます。',
                          style: AppTextStyles.notoSans(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    ],
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'パスワード(任意)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final theme = isCustomTheme ? themeController.text : '';
                    final choice1 = isCustomTheme ? choice1Controller.text : '';
                    final choice2 = isCustomTheme ? choice2Controller.text : '';
                    final password = passwordController.text;

                    if (isCustomTheme && (theme.isEmpty || choice1.isEmpty || choice2.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('入力されていない項目があります')));
                      return;
                    }

                    Navigator.pop(context);
                    final error = await ref.read(bbsHostProvider.notifier).createRoom(theme, choice1, choice2, password);

                    if (error == 'ALREADY_EXISTS') {
                      if (context.mounted) {
                        _showAlreadyExistsDialog(context, ref);
                      }
                    } else if (error != null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('募集を作成しました')));
                      }
                    }
                  },
                  child: const Text('作成'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showAlreadyExistsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('すでに募集中です', style: AppTextStyles.bold(fontSize: 18)),
          content: const Text('自分が立てた募集がすでに存在します。新しい募集を作成するには、前の募集を削除してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(bbsHostProvider.notifier).deleteRoom();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('前の募集を削除しました')));
                }
              },
              child: const Text('削除する', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
