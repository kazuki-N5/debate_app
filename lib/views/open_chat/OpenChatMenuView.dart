import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user_profile_provider.dart';
import 'package:debate_project/views/open_chat/OpenChatBannedMembersView.dart';
import 'package:debate_project/views/open_chat/OpenChatCreateRoomPage.dart';
import 'package:debate_project/views/open_chat/OpenChatMembersView.dart';
import 'package:debate_project/views/open_chat/OpenChatRulesView.dart';
import 'package:debate_project/views/resba/ResbaRoomHistoryView.dart';
import 'package:debate_project/widgets/app_confirm_dialog.dart';
import 'package:debate_project/widgets/full_screen_image_viewer.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// クラブ（オプチャ）のサイドメニュー・設定画面 (LINEオープンチャットUI完全再現版)
class OpenChatMenuView extends HookConsumerWidget {
  final OpenChatRoom room;

  const OpenChatMenuView({
    super.key,
    required this.room,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);

    // 最新のルーム情報を取得
    final roomDetailAsync = ref.watch(openChatRoomDetailProvider(room.id));
    final currentRoom = roomDetailAsync.valueOrNull ?? room;

    // 自分のメンバー情報（ミュート状態・ロールなど）を取得
    final myMemberAsync = ref.watch(openChatMyMemberProvider(room.id));
    final isOwner = myMemberAsync.valueOrNull?.role == 'owner';
    final isMuted = myMemberAsync.valueOrNull?.isMuted ?? false;

    // メンバー一覧を取得（人数カウント用・オーナー特定用）
    final membersAsync = ref.watch(openChatMembersProvider(room.id));
    final memberCount = membersAsync.valueOrNull?.length ?? currentRoom.memberCount ?? 1;
    // 通報対象: このクラブの管理人(owner)
    final ownerMember = membersAsync.valueOrNull?.where((m) => m.role == 'owner').firstOrNull;

    // このクラブ内のレスバ一覧を取得（件数表示用）
    final resbasAsync = ref.watch(openChatResbasProvider(room.id));
    final resbaCount = resbasAsync.valueOrNull?.length ?? 0;

    // 再参加禁止メンバー一覧（管理者用件数表示）
    final bannedUsersAsync = isOwner ? ref.watch(openChatBannedUsersProvider(room.id)) : null;
    final bannedCount = bannedUsersAsync?.valueOrNull?.length ?? 0;

    // ミュート切り替え処理
    Future<void> handleToggleMute() async {
      final newMute = !isMuted;
      final error = await ref
          .read(openChatActionProvider.notifier)
          .toggleRoomMute(room.id, newMute);

      if (context.mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newMute ? 'このクラブの通知をオフにしました' : 'このクラブの通知をオンにしました'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('設定の更新に失敗しました: $error')),
          );
        }
      }
    }

    // 退会処理
    Future<void> handleLeaveRoom() async {
      if (isOwner) {
        // 管理人: 権限移譲 → 退会のフロー
        await _handleOwnerLeaveFlow(context, ref, currentUserId);
        return;
      }

      await _leaveRoomAsRegular(context, ref);
    }

    // クラブの削除処理（オーナー専用）
    Future<void> handleDeleteRoom() async {
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: 'クラブの削除',
        message: '本当にこのクラブを削除しますか？\n\n参加中のメンバー全員が退室となり、これまでのメッセージ履歴や画像はすべて削除されます。この操作は取り消せません。',
        cancelText: 'キャンセル',
        confirmText: '削除する',
        isDestructive: true,
      );

      if (confirmed == true && context.mounted) {
        final error = await ref
            .read(openChatActionProvider.notifier)
            .deleteRoom(room.id);

        if (context.mounted) {
          if (error == null) {
            Navigator.pop(context); // メニューを閉じる
            Navigator.pop(context); // チャット画面を閉じる
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('クラブを削除しました')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('削除に失敗しました: $error')),
            );
          }
        }
      }
    }

    // パッと即座に画面遷移するヘルパー
    void navigateInstantly(Widget destination) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, __) => destination,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                '${currentRoom.name} ($memberCount)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
              size: 20,
              color: isMuted ? Colors.red.shade200 : Colors.white70,
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ==========================================
            // 1. 上部クイックアクション (LINE完全再現: 丸枠なし、直アイコン)
            // ==========================================
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF2F2F7), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // ① 通知オン/オフ
                  _buildQuickActionItem(
                    icon: isMuted ? Icons.notifications_off_outlined : Icons.notifications_outlined,
                    label: isMuted ? '通知オン' : '通知オフ',
                    onTap: handleToggleMute,
                  ),

                  // ② メンバー (パッと即座に表示)
                  _buildQuickActionItem(
                    icon: Icons.people_outline_rounded,
                    label: 'メンバー',
                    onTap: () {
                      navigateInstantly(OpenChatMembersView(room: currentRoom));
                    },
                  ),

                  // ③ 退会
                  _buildQuickActionItem(
                    icon: Icons.logout_rounded,
                    label: '退会',
                    onTap: handleLeaveRoom,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ==========================================
            // 2. リスト項目群 (LINE完全再現: 白背景、黒線アイコン、右矢印)
            // ==========================================

            // ① 写真・動画
            _buildMediaSection(context, ref),

            // ② ルール (必読 / 🟢ポッチ付き)
            _buildLineTile(
              icon: Icons.article_outlined,
              title: 'ルール',
              showGreenDot: true,
              trailingText: (currentRoom.rules != null && currentRoom.rules!.isNotEmpty) ? '設定あり' : '',
              onTap: () {
                navigateInstantly(OpenChatRulesView(room: currentRoom));
              },
            ),

            // ③ レスバ履歴 (⚔️ 専用項目)
            _buildLineTile(
              leading: const Text('⚔️', style: TextStyle(fontSize: 20)),
              title: 'レスバ履歴',
              trailingText: resbaCount > 0 ? '$resbaCount' : '',
              onTap: () {
                navigateInstantly(ResbaRoomHistoryView(
                  roomId: room.id,
                  title: currentRoom.name,
                  isDm: false,
                ));
              },
            ),

            // ④ 設定 (ルーム情報)
            _buildLineTile(
              icon: Icons.settings_outlined,
              title: '設定',
              trailingText: isOwner ? '編集' : '',
              onTap: () {
                navigateInstantly(OpenChatCreateRoomPage(
                  initialRoom: currentRoom,
                  isReadOnly: !isOwner,
                ));
              },
            ),

            // ⑥ 再参加禁止リスト (管理者専用項目)
            if (isOwner)
              _buildLineTile(
                icon: Icons.person_off_outlined,
                title: '再参加禁止リスト',
                trailingText: bannedCount > 0 ? '$bannedCount' : '',
                onTap: () {
                  navigateInstantly(OpenChatBannedMembersView(room: currentRoom));
                },
              ),

            // ⑦ クラブの削除 (オーナー専用)
            if (isOwner)
              _buildLineTile(
                icon: Icons.delete_outline_rounded,
                title: 'クラブの削除',
                titleColor: Colors.red.shade600,
                iconColor: Colors.red.shade600,
                onTap: handleDeleteRoom,
              ),

            const SizedBox(height: 24),

            // ==========================================
            // 3. 下部セクション (情報ヘッダー ＋ 通報)
            // ==========================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'クラブ情報',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            _buildLineTile(
              icon: Icons.flag_outlined,
              title: 'このクラブを通報する',
              titleColor: Colors.red.shade700,
              iconColor: Colors.red.shade600,
              onTap: () {
                showReportDialog(
                  context: context,
                  ref: ref,
                  opponentId: ownerMember?.userId ?? currentUserId ?? '',
                  roomId: currentRoom.id,
                  contentId: currentRoom.id,
                  contentType: 'open_chat_room',
                  contentSnapshot: 'クラブ名: ${currentRoom.name}\n説明: ${currentRoom.description ?? ""}',
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 通常メンバー・副管理人の退会処理
  Future<void> _leaveRoomAsRegular(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'クラブを退会',
      message: 'このクラブから退会しますか？\n退会すると、メッセージの送受信ができなくなります。',
      cancelText: 'キャンセル',
      confirmText: '退会する',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      final error = await ref
          .read(openChatActionProvider.notifier)
          .leaveRoom(room.id);

      if (context.mounted) {
        if (error == null) {
          Navigator.pop(context); // メニューを閉じる
          Navigator.pop(context); // ルーム画面を閉じる
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('クラブから退会しました')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      }
    }
  }

  /// 管理人の退会（フロントエンド主導の移行フロー）
  /// 自動フォールバックは行わず、UIで移行先を選択 → 譲渡RPC → 退会の順で実行
  Future<void> _handleOwnerLeaveFlow(
      BuildContext context, WidgetRef ref, String? currentUserId) async {
    // Step 1: 移行案内ダイアログ
    final shouldTransfer = await showAppConfirmDialog(
      context: context,
      title: '管理人の退会',
      message: 'あなたはこのクラブの管理人です。\n退会するには、先に管理人権限を他のメンバーに移譲する必要があります。\n\n管理人を譲ってから退会しますか？',
      cancelText: 'キャンセル',
      confirmText: '管理人を譲る',
    );
    if (shouldTransfer != true || !context.mounted) return;

    // 移譲候補（自分以外のメンバー）を取得
    List<OpenChatMember> candidates;
    try {
      candidates = (await ref.read(openChatMembersProvider(room.id).future))
          .where((m) => m.userId != currentUserId)
          .toList();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メンバー一覧の取得に失敗しました')),
        );
      }
      return;
    }

    if (candidates.isEmpty) {
      if (context.mounted) {
        await showAppConfirmDialog(
          context: context,
          title: '移譲できるメンバーがいません',
          message: 'メンバーがいないため権限を移譲できません。\n「クラブの削除」からクラブを削除してください。',
          confirmText: 'OK',
          cancelText: null,
        );
      }
      return;
    }

    // Step 2: 新しい管理人を選択
    if (!context.mounted) return;
    final target = await _showSelectOwnerSheet(context, ref, candidates);
    if (target == null || !context.mounted) return;

    final targetName = await _resolveUserName(ref, target.userId);
    if (!context.mounted) return;

    // Step 3: 最終確認
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '管理人権限の譲渡',
      message: '$targetName さんに管理人権限を譲りますか？\nあなたは副管理人になります。\n\nこの操作は取り消せません。',
      cancelText: 'キャンセル',
      confirmText: '譲渡する',
      isDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    // Step 4: 譲渡RPCを実行
    final transferError = await ref
        .read(openChatActionProvider.notifier)
        .transferOwnership(room.id, target.userId);

    if (!context.mounted) return;
    if (transferError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('譲渡に失敗しました: $transferError')),
      );
      return;
    }

    // Step 5: 譲渡完了 → 退会確認 → 退会
    final leaveConfirmed = await showAppConfirmDialog(
      context: context,
      title: 'クラブを退会',
      message: '$targetName さんへの譲渡が完了しました。\nこのクラブから退会しますか？',
      cancelText: 'キャンセル',
      confirmText: '退会する',
      isDestructive: true,
    );
    if (leaveConfirmed != true || !context.mounted) return;

    final error = await ref
        .read(openChatActionProvider.notifier)
        .leaveRoom(room.id);

    if (context.mounted) {
      if (error == null) {
        Navigator.pop(context); // メニューを閉じる
        Navigator.pop(context); // ルーム画面を閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('クラブから退会しました')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  /// ユーザー名を解決するヘルパー
  Future<String> _resolveUserName(WidgetRef ref, String userId) async {
    try {
      final user = await ref.read(userBasicInfoProvider(userId).future);
      return user?.name ?? 'ユーザー';
    } catch (_) {
      return 'ユーザー';
    }
  }

  /// 新しい管理人を選択するボトムシート
  Future<OpenChatMember?> _showSelectOwnerSheet(
    BuildContext context,
    WidgetRef ref,
    List<OpenChatMember> candidates,
  ) async {
    // 候補者のユーザー名・アバターを事前解決
    final userInfos = <String, Users?>{};
    for (final m in candidates) {
      try {
        userInfos[m.userId] =
            await ref.read(userBasicInfoProvider(m.userId).future);
      } catch (_) {}
    }
    if (!context.mounted) return null;

    return showModalBottomSheet<OpenChatMember>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '新しい管理人を選択',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF2F2F7)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF2F2F7)),
                  itemBuilder: (context, index) {
                    final m = candidates[index];
                    final user = userInfos[m.userId];
                    final avatarUrl = user?.avatar_url;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            (avatarUrl != null && avatarUrl.isNotEmpty)
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
                              user?.name ?? 'ユーザー',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (m.isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '副管理人',
                                style: TextStyle(
                                  color: Color(0xFFC2410C),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else if (m.isMember) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'メンバー',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '参加: ${m.joinedAt.month}/${m.joinedAt.day}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFC7C7CC)),
                      onTap: () => Navigator.pop(sheetContext, m),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 上部クイックアクションボタン（LINE完全再現: 丸枠なし、直アイコン）
  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: const Color(0xFF1C1C1E)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 写真・動画セクション
  Widget _buildMediaSection(BuildContext context, WidgetRef ref) {
    // ルーム内のメッセージから画像URLを抽出
    final messagesAsync = ref.watch(openChatMessagesProvider(room.id));
    final messages = messagesAsync.valueOrNull ?? [];
    final imageUrls = messages
        .where((m) => m.imageUrl != null && m.imageUrl!.isNotEmpty)
        .map((m) => m.imageUrl!)
        .toList();

    final hasImages = imageUrls.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasImages
                ? () {
                    FullScreenImageViewer.show(
                      context,
                      imageUrls: imageUrls,
                      initialIndex: 0,
                    );
                  }
                : null,
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 23, color: Color(0xFF1C1C1E)),
                const SizedBox(width: 14),
                const Text(
                  '写真・動画',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const Spacer(),
                if (hasImages) ...[
                  Text(
                    '${imageUrls.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFC7C7CC),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (hasImages)
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = imageUrls[index];
                  return GestureDetector(
                    onTap: () {
                      FullScreenImageViewer.show(
                        context,
                        imageUrls: imageUrls,
                        initialIndex: index,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 84,
                        height: 84,
                        color: Colors.grey.shade100,
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.broken_image,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5EA), width: 0.8),
              ),
              alignment: Alignment.center,
              child: const Text(
                '写真や動画はありません',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// LINE標準のリストタイル（アイコン・タイトル・緑ポッチ・右矢印）
  Widget _buildLineTile({
    IconData? icon,
    Widget? leading,
    required String title,
    required VoidCallback onTap,
    bool showGreenDot = false,
    String? trailingText,
    Color? titleColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            leading ??
                Icon(
                  icon!,
                  size: 23,
                  color: iconColor ?? const Color(0xFF1C1C1E),
                ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: titleColor ?? const Color(0xFF1C1C1E),
                letterSpacing: -0.2,
              ),
            ),
            if (showGreenDot) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
              ),
            ],
            const Spacer(),
            if (trailingText != null && trailingText.isNotEmpty) ...[
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8E8E93),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFFC7C7CC),
            ),
          ],
        ),
      ),
    );
  }
}
