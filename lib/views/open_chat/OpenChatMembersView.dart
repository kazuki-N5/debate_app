// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/widgets/moderation.dart';

class OpenChatMembersView extends HookConsumerWidget {
  final OpenChatRoom room;

  const OpenChatMembersView({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(openChatMembersProvider(room.id));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバー管理', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
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
                    child: const Icon(Icons.person, color: Colors.white),
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
                      if (!isMe) ...[
                        TextButton(
                          onPressed: () => _confirmBlock(context, ref, member),
                          child: const Text('ブロック', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                        if (isAdmin)
                          TextButton(
                            onPressed: () => _confirmKick(context, ref, member),
                            child: const Text('削除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                      ],
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

  void _confirmBlock(BuildContext context, WidgetRef ref, OpenChatMember targetMember) {
    showBlockUserDialog(
      context: context,
      ref: ref,
      targetUserId: targetMember.userId,
      targetName: 'このユーザー',
    );
  }

  void _confirmKick(BuildContext context, WidgetRef ref, OpenChatMember targetMember) {
    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('メンバーの削除'),
              content: const Text('このメンバーをオープンチャットから削除しますか？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isLoading ? null : () async {
                    setState(() => isLoading = true);
                    final error = await ref.read(openChatActionProvider.notifier).kickMember(room.id, targetMember.userId);
                    setState(() => isLoading = false);
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('メンバーを削除しました')));
                        ref.invalidate(openChatMembersProvider(room.id));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $error')));
                      }
                    }
                  },
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('削除する', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }
}
