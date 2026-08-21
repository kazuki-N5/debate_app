// ignore_for_file: file_names, use_build_context_synchronously
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/modes/app_notification.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// レスバの申込（対戦招待）を1件表示する画面
/// 通知タップから遷移し、承諾/拒否・取り下げ・対戦へ戻る の操作ができる
class ResbaRequestPage extends ConsumerWidget {
  final String inviteId;

  /// 通知元の情報（ヘッダー表示用。旧通知でinvite_idが無い場合のフォールバック表示にも使う）
  final AppNotification? notification;

  const ResbaRequestPage({
    super.key,
    required this.inviteId,
    this.notification,
  });

  Future<void> _resumeBattle(
      BuildContext context, WidgetRef ref, String roomId) async {
    try {
      await ref.read(matchingRoomProvider.notifier).joinBbsRoom(roomId);
      if (context.mounted) router.go('/wait');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('対戦を開始できませんでした')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteAsync = ref.watch(resbaInviteProvider(inviteId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('⚔️ レスバの申込',
            style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: inviteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'レスバ情報の取得に失敗しました',
                style: AppTextStyles.notoSans(
                    fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(resbaInviteProvider(inviteId)),
                child: const Text('再読み込み'),
              ),
            ],
          ),
        ),
        data: (invite) {
          if (invite == null) {
            return Center(
              child: Text(
                'このレスバは見つかりませんでした',
                style: AppTextStyles.notoSans(
                    fontSize: 14, color: Colors.grey),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(resbaInviteProvider(inviteId).notifier)
                  .fetch();
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (notification != null)
                  _NotificationHeader(notification: notification!),
                ResbaCard(
                  invite: invite,
                  onChanged: () =>
                      ref.invalidate(resbaInviteProvider(inviteId)),
                ),
                if (invite.isAccepted && invite.battleRoomId != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _resumeBattle(context, ref, invite.battleRoomId!),
                      icon: const Icon(Icons.sports_kabaddi,
                          color: Colors.white),
                      label: const Text('⚔️ 対戦へ戻る'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7856FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 通知元のヘッダー（アクター・日時・対象の引用）
class _NotificationHeader extends StatelessWidget {
  final AppNotification notification;

  const _NotificationHeader({required this.notification});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = notification.actorAvatarUrl;
    final quote = notification.quoteText;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? ResizeImage(CachedNetworkImageProvider(avatarUrl),
                        width: 108)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Icon(Icons.person, color: Colors.grey[600])
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.actorName,
                      style: AppTextStyles.bold(
                          fontSize: 14, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      DateFormatter.formatBbsDate(notification.createdAt),
                      style: AppTextStyles.notoSans(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (quote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD6E6FF)),
              ),
              child: Text(
                quote,
                style: AppTextStyles.notoSans(
                    fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
