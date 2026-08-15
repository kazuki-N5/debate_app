// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/provider/bbs_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CommunityPage extends HookConsumerWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bbsRooms = ref.watch(bbsListProvider);
    final bbsListNotifier = ref.read(bbsListProvider.notifier);
    
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bbsListNotifier.fetchRooms();
      });
      return null;
    }, []);

    return Scaffold(
      backgroundColor: Colors.blue[50], // 背景色
      appBar: AppBar(
        title: Text(
          'コミュニティ',
          style: AppTextStyles.bold(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
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
                padding: const EdgeInsets.all(16),
                itemCount: bbsRooms.length,
                itemBuilder: (context, index) {
                  final room = bbsRooms[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  room.theme.isEmpty ? 'テーマなし' : room.theme,
                                  style: AppTextStyles.bold(fontSize: 18),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (room.hasPassword)
                                const Icon(Icons.lock, color: Colors.orange, size: 20),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '選択肢: ${room.choice1} vs ${room.choice2}',
                            style: AppTextStyles.notoSans(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateRoomDialog(context, ref);
        },
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('新規募集', style: AppTextStyles.bold(color: Colors.white)),
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('新規募集作成', style: AppTextStyles.bold(fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                final theme = themeController.text;
                final choice1 = choice1Controller.text;
                final choice2 = choice2Controller.text;
                final password = passwordController.text;

                if (theme.isEmpty || choice1.isEmpty || choice2.isEmpty) {
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
                  ref.read(bbsListProvider.notifier).fetchRooms();
                }
              },
              child: const Text('作成'),
            ),
          ],
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
                ref.read(bbsListProvider.notifier).fetchRooms();
              },
              child: const Text('削除する', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
