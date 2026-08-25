// ignore_for_file: file_names
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user_profile_provider.dart';
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
          final isOwner = myMemberData?.role == 'owner';
          final canManage = myMemberData?.isModerator ?? false;

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(openChatMembersProvider(room.id)),
            child: ListView.separated(
              itemCount: members.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                final isMe = member.userId == currentUserId;
                final user = ref.watch(userBasicInfoProvider(member.userId)).valueOrNull;
                final displayName = user?.name ?? (isMe ? 'あなた' : 'ユーザー');
                final avatarUrl = user?.avatar_url;

                // ロールバッジ
                Widget? roleBadge;
                if (member.isOwner) {
                  roleBadge = _buildRoleBadge('管理人', const Color(0xFF1D4ED8), const Color(0xFFDBEAFE));
                } else if (member.isAdmin) {
                  roleBadge = _buildRoleBadge('副管理人', const Color(0xFFC2410C), const Color(0xFFFFEDD5));
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Icon(Icons.person, color: Colors.grey[600])
                        : null,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe ? 'あなた' : displayName,
                          style: AppTextStyles.bold(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (roleBadge != null) ...[
                        const SizedBox(width: 8),
                        roleBadge,
                      ],
                    ],
                  ),
                  subtitle: Text('参加: ${member.joinedAt.month}/${member.joinedAt.day}', style: const TextStyle(fontSize: 12)),
                  trailing: (!isMe && canManage)
                      ? _buildMemberActionMenu(context, ref, member, displayName, isOwner)
                      : null,
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

  /// ロールバッジ（管理人 / 副管理人）
  Widget _buildRoleBadge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// メンバーに対するアクションメニュー（ロールに応じて表示を出し分け）
  Widget _buildMemberActionMenu(
    BuildContext context,
    WidgetRef ref,
    OpenChatMember target,
    String displayName,
    bool isOwner,
  ) {
    final entries = <PopupMenuEntry<String>>[];

    if (isOwner) {
      if (target.isMember) {
        entries.add(
          const PopupMenuItem(
            value: 'assign',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text('副管理人に任命', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        );
      } else if (target.isAdmin) {
        entries.add(
          const PopupMenuItem(
            value: 'transfer',
            child: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text('管理人を譲る', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        );
        entries.add(
          const PopupMenuItem(
            value: 'revoke',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text('副管理人を外す', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        );
      }
      // オーナーは誰でも強制退会できる（自分以外）
      entries.add(
        const PopupMenuItem(
          value: 'kick',
          child: Row(
            children: [
              Icon(Icons.person_off_outlined, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('強制退会', style: TextStyle(fontSize: 13, color: Colors.red)),
            ],
          ),
        ),
      );
    } else {
      // 副管理人(admin)は一般メンバーのみ強制退会可能
      if (target.isMember) {
        entries.add(
          const PopupMenuItem(
            value: 'kick',
            child: Row(
              children: [
                Icon(Icons.person_off_outlined, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('強制退会', style: TextStyle(fontSize: 13, color: Colors.red)),
              ],
            ),
          ),
        );
      }
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Colors.grey),
      onSelected: (value) =>
          _handleMemberAction(context, ref, target, displayName, value),
      itemBuilder: (_) => entries,
    );
  }

  /// アクションメニューの実行処理
  Future<void> _handleMemberAction(
    BuildContext context,
    WidgetRef ref,
    OpenChatMember target,
    String displayName,
    String action,
  ) async {
    switch (action) {
      case 'assign':
        final confirmed = await showAppConfirmDialog(
          context: context,
          title: '副管理人に任命',
          message: '$displayName さんを副管理人に任命しますか？',
          cancelText: 'キャンセル',
          confirmText: '任命する',
        );
        if (confirmed != true || !context.mounted) return;
        final error = await ref
            .read(openChatActionProvider.notifier)
            .assignAdmin(room.id, target.userId);
        if (!context.mounted) return;
        _showActionResult(context, ref, error, '$displayName さんを副管理人に任命しました');
        break;

      case 'revoke':
        final confirmed = await showAppConfirmDialog(
          context: context,
          title: '副管理人を外す',
          message: '$displayName さんを副管理人から外しますか？\n一般メンバーに戻ります。',
          cancelText: 'キャンセル',
          confirmText: '外す',
          isDestructive: true,
        );
        if (confirmed != true || !context.mounted) return;
        final error = await ref
            .read(openChatActionProvider.notifier)
            .revokeAdmin(room.id, target.userId);
        if (!context.mounted) return;
        _showActionResult(context, ref, error, '$displayName さんを副管理人から外しました');
        break;

      case 'transfer':
        final confirmed = await showAppConfirmDialog(
          context: context,
          title: '管理人を譲る',
          message: '$displayName さんに管理人権限を譲りますか？\nあなたは副管理人になります。\n\nこの操作は取り消せません。',
          cancelText: 'キャンセル',
          confirmText: '譲る',
          isDestructive: true,
        );
        if (confirmed != true || !context.mounted) return;
        final error = await ref
            .read(openChatActionProvider.notifier)
            .transferOwnership(room.id, target.userId);
        if (!context.mounted) return;
        _showActionResult(context, ref, error, '管理人権限を $displayName さんに譲りました');
        break;

      case 'kick':
        await _confirmKick(context, ref, target);
        break;
    }
  }

  /// アクション結果の表示
  void _showActionResult(
      BuildContext context, WidgetRef ref, String? error, String successMessage) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error == null ? successMessage : 'エラー: $error'),
        duration: const Duration(seconds: 2),
      ),
    );
    if (error == null) {
      ref.invalidate(openChatMembersProvider(room.id));
    }
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
          content: Text(isBan ? 'メンバーを強制退会（再参加禁止）にしました' : 'メンバーを追放しました'),
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
