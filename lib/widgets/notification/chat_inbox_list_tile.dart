// ignore_for_file: file_names
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/provider/chat_inbox_provider.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// メッセージ一覧の1件分タイル (DM / オプチャ共通)
class ChatInboxListTile extends StatelessWidget {
  final ChatInboxItem item;
  final VoidCallback? onTap;

  const ChatInboxListTile({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDm = item.isDm;

    return Material(
      color: item.unreadCount > 0 ? const Color(0xFFF0F7FF) : Colors.white,
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
            children: [
              // アイコン: DMは丸 / オプチャは角丸四角
              _buildIcon(isDm),
              const SizedBox(width: 12),
              // 名前 + プレビュー
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.bold(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.lastMessageAt != null)
                          Text(
                            DateFormatter.formatBbsDate(item.lastMessageAt!),
                            style: AppTextStyles.notoSans(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.lastMessage.isEmpty
                                ? (isDm ? 'DMを送ってみましょう' : 'メッセージがありません')
                                : item.lastMessage,
                            style: AppTextStyles.notoSans(
                              fontSize: 12.5,
                              color: item.unreadCount > 0
                                  ? Colors.black87
                                  : Colors.grey[600],
                              fontWeight: item.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF91880),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(bool isDm) {
    final hasAvatar = item.avatarUrl != null && item.avatarUrl!.isNotEmpty;

    if (isDm) {
      // DM: 丸アイコン
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey[300],
        backgroundImage: hasAvatar
            ? ResizeImage(CachedNetworkImageProvider(item.avatarUrl!),
                width: 132)
            : null,
        child: !hasAvatar
            ? Icon(Icons.person, color: Colors.grey[600])
            : null,
      );
    }

    // オプチャ: 角丸四角アイコン
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: hasAvatar ? null : const Color(0xFF7C4DF0),
        borderRadius: BorderRadius.circular(12),
        image: hasAvatar
            ? DecorationImage(
                image: CachedNetworkImageProvider(item.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: !hasAvatar
          ? const Icon(Icons.chat_bubble, color: Colors.white, size: 22)
          : null,
    );
  }
}
