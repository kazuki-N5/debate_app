import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/widgets/app_confirm_dialog.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/ios_swipe_back.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// クラブの再参加禁止メンバー一覧・解除画面 (管理者専用)
class OpenChatBannedMembersView extends HookConsumerWidget {
  final OpenChatRoom room;

  const OpenChatBannedMembersView({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannedUsersAsync = ref.watch(openChatBannedUsersProvider(room.id));

    // 解除処理
    Future<void> handleUnbanUser(OpenChatBannedUser bannedUser) async {
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: '再参加禁止の解除',
        message: '${bannedUser.userName} さんの再参加禁止を解除しますか？\n解除すると、このユーザーが再びクラブに参加できるようになります。',
        confirmText: '解除する',
        cancelText: 'キャンセル',
      );

      if (confirmed == true && context.mounted) {
        final error = await ref
            .read(openChatActionProvider.notifier)
            .unbanMember(room.id, bannedUser.userId);

        if (context.mounted) {
          if (error == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${bannedUser.userName} さんの再参加禁止を解除しました'),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('解除に失敗しました: $error')),
            );
          }
        }
      }
    }

    return IosSwipeBack(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.blue,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '再参加禁止リスト',
            style: AppTextStyles.bold(color: Colors.white, fontSize: 17),
          ),
          centerTitle: false,
        ),
        body: bannedUsersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'リストの取得に失敗しました',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(openChatBannedUsersProvider(room.id)),
                  child: const Text('再読み込み'),
                ),
              ],
            ),
          ),
          data: (bannedUsers) {
            if (bannedUsers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(
                        Icons.person_off_outlined,
                        size: 32,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '再参加禁止のメンバーはいません',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '強制退会（再参加禁止）にしたメンバーが\nここに表示され、いつでも解除できます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.refresh(openChatBannedUsersProvider(room.id)),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: bannedUsers.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 68),
                itemBuilder: (context, index) {
                  final banned = bannedUsers[index];
                  final avatarUrl = banned.avatarUrl;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                              banned.userName.isNotEmpty ? banned.userName[0] : '?',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      banned.userName,
                      style: AppTextStyles.bold(color: const Color(0xFF1C1C1E), fontSize: 15),
                    ),
                    subtitle: Text(
                      '禁止日時: ${banned.createdAt.month}/${banned.createdAt.day} ${banned.createdAt.hour}:${banned.createdAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                    trailing: TextButton(
                      onPressed: () => handleUnbanUser(banned),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF007AFF), width: 1),
                        ),
                      ),
                      child: const Text(
                        '解除',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
