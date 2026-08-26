// ignore_for_file: file_names
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/modes/app_notification.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 通知1件分のタイル (種別アイコン・引用・未読表示付き)
class NotificationListTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const NotificationListTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  /// 種別に応じたアクション文
  String get _actionText {
    switch (notification.type) {
      case 'like_post':
        return notification.count > 1
            ? '${notification.count}件のいいねが来ました'
            : 'あなたのポストにいいねしました';
      case 'like_comment':
        return notification.count > 1
            ? '${notification.count}件のいいねが来ました'
            : 'あなたのコメントにいいねしました';
      case 'follow':
        return 'あなたをフォローしました';
      case 'reply_comment':
        return 'あなたのコメントに返信しました';
      case 'comment':
        return 'あなたのポストにコメントしました';
      case 'resba_invite':
        // 返信・コメントにレスバを添付して送信された（メッセージ扱い）
        return 'レスバが届きました';
      case 'resba_apply':
        return 'あなたのレスバに応募しました';
      case 'resba_accepted':
        return 'あなたのレスバを承諾しました';
      case 'resba_declined':
        return 'あなたのレスバを拒否しました';
      default:
        return '新しい通知があります';
    }
  }

  /// 種別に応じたバッジアイコン
  (IconData, Color) get _badge {
    switch (notification.type) {
      case 'like_post':
      case 'like_comment':
        return (CupertinoIcons.heart_fill, const Color(0xFFF91880));
      case 'follow':
        return (Icons.person_add, const Color(0xFF1D9BF0));
      case 'reply_comment':
      case 'comment':
        return (Icons.chat_bubble, const Color(0xFF00BA7C));
      case 'resba_invite':
      case 'resba_apply':
        return (Icons.sports_kabaddi, const Color(0xFF7856FF));
      case 'resba_accepted':
        return (Icons.sports_kabaddi, const Color(0xFF00BA7C));
      case 'resba_declined':
        return (Icons.sports_kabaddi, const Color(0xFFE0245E));
      default:
        return (Icons.notifications, Colors.blueGrey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = notification.actorAvatarUrl;
    final isUnread = !notification.isRead;
    final quote = notification.quoteText;

    final (badgeIcon, badgeColor) = _badge;

    return Material(
      color: isUnread ? const Color(0xFFF0F7FF) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // アクターアバター + 種別バッジ
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? ResizeImage(CachedNetworkImageProvider(avatarUrl),
                            width: 132)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Icon(Icons.person, color: Colors.grey[600])
                        : null,
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(badgeIcon, color: Colors.white, size: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // 本文
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.actorName,
                            style: AppTextStyles.bold(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormatter.formatBbsDate(notification.createdAt),
                          style: AppTextStyles.notoSans(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _actionText,
                      style: AppTextStyles.notoSans(
                        fontSize: 13,
                        color: isUnread ? Colors.black87 : Colors.grey[700],
                        fontWeight:
                            isUnread ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    // レスバ付きバッジ（返信通知の対象コメントにレスバが付いている）
                    if (notification.hasResba) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1EBFF),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFCFC4FF)),
                            ),
                            child: const Text(
                              '⚔️ レスバ付き',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7856FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // 引用(対象のポスト/コメント本文)
                    if (quote.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
