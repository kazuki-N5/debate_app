import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/dm_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/views/resba/ResbaRoomHistoryView.dart';
import 'package:debate_project/widgets/app_confirm_dialog.dart';
import 'package:debate_project/widgets/full_screen_image_viewer.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 1対1 DMのサイドメニュー・設定画面 (LINE UI完全再現版)
class DmMenuView extends HookConsumerWidget {
  final String roomId;
  final Users otherUser;

  const DmMenuView({
    super.key,
    required this.roomId,
    required this.otherUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserName = otherUser.name ?? 'ユーザー';
    final avatarUrl = otherUser.avatar_url;

    // 自分のDMミュート状態を取得
    final isMutedAsync = ref.watch(dmMyMemberMuteProvider(roomId));
    final isMuted = isMutedAsync.valueOrNull ?? false;

    // ブロック状態の確認
    final isBlocked = ref.watch(blockedUserIdsProvider).contains(otherUser.id);

    // このDM内のレスバ一覧を取得（件数表示用）
    final resbasAsync = ref.watch(dmResbaProvider(roomId));
    final resbaCount = resbasAsync.valueOrNull?.length ?? 0;

    // ミュート切り替え処理
    Future<void> handleToggleMute() async {
      final newMute = !isMuted;
      final error = await ref
          .read(dmActionProvider.notifier)
          .toggleDmMute(roomId, newMute);

      if (context.mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newMute ? '$otherUserName さんの通知をオフにしました' : '$otherUserName さんの通知をオンにしました'),
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

    // ブロック処理
    Future<void> handleBlockUser() async {
      final confirmed = await showAppConfirmDialog(
        context: context,
        title: isBlocked ? 'ブロック解除' : 'ユーザーをブロック',
        message: isBlocked
            ? '$otherUserName さんのブロックを解除しますか？'
            : '$otherUserName さんをブロックしますか？\nブロックすると、このユーザーからのメッセージや通知が届かなくなります。',
        confirmText: isBlocked ? '解除する' : 'ブロックする',
        isDestructive: !isBlocked,
      );

      if (confirmed == true && context.mounted) {
        if (isBlocked) {
          await ref.read(blockedUserIdsProvider.notifier).unblock(otherUser.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$otherUserName さんのブロックを解除しました')),
            );
          }
        } else {
          await ref.read(blockedUserIdsProvider.notifier).block(otherUser.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$otherUserName さんをブロックしました')),
            );
          }
        }
      }
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
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                      otherUserName.isNotEmpty ? otherUserName[0] : '?',
                      style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                otherUserName,
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

                  // ② プロフィール
                  _buildQuickActionItem(
                    icon: Icons.person_outline_rounded,
                    label: 'プロフィール',
                    onTap: () {
                      context.push('/userProfile', extra: otherUser.id);
                    },
                  ),

                  // ③ ブロック
                  _buildQuickActionItem(
                    icon: Icons.block_rounded,
                    label: isBlocked ? '解除' : 'ブロック',
                    iconColor: isBlocked ? Colors.grey.shade600 : Colors.red.shade600,
                    labelColor: isBlocked ? Colors.grey.shade600 : Colors.red.shade600,
                    onTap: handleBlockUser,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ==========================================
            // 2. DM用リスト項目群 (LINE完全再現)
            // ==========================================
            // ① 写真・動画
            _buildMediaSection(context, ref),

            // ② レスバ履歴 (🔥 専用項目)
            _buildLineTile(
              icon: Icons.offline_bolt_outlined,
              title: 'レスバ履歴',
              trailingText: resbaCount > 0 ? '$resbaCount' : '',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResbaRoomHistoryView(
                      roomId: roomId,
                      title: otherUserName,
                      isDm: true,
                    ),
                  ),
                );
              },
            ),

            // ③ 設定
            _buildLineTile(
              icon: Icons.settings_outlined,
              title: '設定',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('背景・チャット設定を開きます')),
                );
              },
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 3. 下部セクション (通報)
            // ==========================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'その他',
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
              title: 'このユーザーを通報する',
              titleColor: Colors.red.shade700,
              iconColor: Colors.red.shade600,
              onTap: () {
                showReportDialog(
                  context: context,
                  ref: ref,
                  opponentId: otherUser.id,
                  roomId: roomId,
                  contentType: 'dm',
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 上部クイックアクションボタン（LINE完全再現: 丸枠なし、直アイコン）
  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF1C1C1E),
    Color labelColor = const Color(0xFF1C1C1E),
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
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: labelColor,
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
    // DM内のメッセージから画像URLを抽出
    final messagesAsync = ref.watch(dmMessagesProvider(roomId));
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

  /// LINE標準のリストタイル
  Widget _buildLineTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
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
            Icon(icon, size: 23, color: iconColor ?? const Color(0xFF1C1C1E)),
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
