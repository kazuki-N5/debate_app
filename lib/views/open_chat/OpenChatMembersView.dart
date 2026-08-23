// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/widgets/app_confirm_dialog.dart';

class OpenChatMembersView extends HookConsumerWidget {
  final OpenChatRoom room;

  const OpenChatMembersView({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(openChatMembersProvider(room.id));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('メンバー管理', style: AppTextStyles.bold(color: Colors.white, fontSize: 17)),
        backgroundColor: Colors.blue,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('メンバーがいません'));
          }

          // 自分のロールを確認
          final myMemberData = members.where((m) => m.userId == currentUserId).firstOrNull;
          final isAdmin = myMemberData?.role == 'admin';

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(openChatMembersProvider(room.id)),
            child: ListView.separated(
              itemCount: members.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                final isMe = member.userId == currentUserId;
                final isMemberAdmin = member.role == 'admin';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    child: Icon(Icons.person, color: Colors.grey[600]),
                  ),
                  title: Row(
                    children: [
                      Text(isMe ? 'あなた' : 'ユーザー', style: AppTextStyles.bold(fontSize: 16)),
                      if (isMemberAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('管理者', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text('参加: ${member.joinedAt.month}/${member.joinedAt.day}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMe && isAdmin)
                        TextButton(
                          onPressed: () => _confirmKick(context, ref, member),
                          child: const Text('削除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
      ),
    );
  }

  Future<void> _confirmKick(
      BuildContext context, WidgetRef ref, OpenChatMember targetMember) async {
    final result = await showKickMemberConfirmDialog(
      context: context,
    );

    if (result == null || !context.mounted) return;

    final isBan = result == true;
    final error = await ref
        .read(openChatActionProvider.notifier)
        .kickMember(room.id, targetMember.userId, ban: isBan);

    if (!context.mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isBan ? 'メンバーを強制退会（再参加禁止）にしました' : 'メンバーを退出させました'),
          duration: const Duration(seconds: 2),
        ),
      );
      ref.invalidate(openChatMembersProvider(room.id));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('エラー: $error')));
    }
  }
}
