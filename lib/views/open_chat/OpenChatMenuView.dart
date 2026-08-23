import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
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
    final currentUserId = ref.watch(supabaseProvider).auth.currentUser?.id;
    final isOwner = currentUserId == room.ownerId;

    // 最新のルーム情報を取得
    final roomDetailAsync = ref.watch(openChatRoomDetailProvider(room.id));
    final currentRoom = roomDetailAsync.valueOrNull ?? room;

    // 自分のメンバー情報（ミュート状態など）を取得
    final myMemberAsync = ref.watch(openChatMyMemberProvider(room.id));
    final isMuted = myMemberAsync.valueOrNull?.isMuted ?? false;

    // メンバー一覧を取得（人数カウント用）
    final membersAsync = ref.watch(openChatMembersProvider(room.id));
    final memberCount = membersAsync.valueOrNull?.length ?? currentRoom.memberCount ?? 1;

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
        await showAppConfirmDialog(
          context: context,
          title: 'オーナーは退会できません',
          message: 'あなたはこのクラブの管理者（オーナー）です。\n退室する前にクラブを削除するか、管理権限を移行してください。',
          confirmText: 'OK',
          cancelText: null,
        );
        return;
      }

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
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

            // ③ レスバ履歴 (🔥 専用項目)
            _buildLineTile(
              icon: Icons.offline_bolt_outlined,
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
                  opponentId: currentRoom.ownerId,
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
    required IconData icon,
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
