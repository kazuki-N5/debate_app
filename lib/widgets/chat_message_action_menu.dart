import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popover/popover.dart';

/// 長押しメニューのアクション項目定義
class ChatMessageActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? iconColor;
  final Color? textColor;

  const ChatMessageActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.iconColor,
    this.textColor,
  });
}

/// LINE風のダークフローティングメッセージ長押しメニューを表示する関数
void showChatMessageActionMenu({
  required BuildContext context,
  String? messageText,
  bool isMyMessage = false,
  bool canDelete = false,
  String deleteLabel = '削除',
  VoidCallback? onReply,
  VoidCallback? onCopy,
  VoidCallback? onHide,
  VoidCallback? onReport,
  VoidCallback? onDelete,
  List<ChatMessageActionItem>? customItems,
  PopoverDirection direction = PopoverDirection.top,
}) {
  final items = <ChatMessageActionItem>[];

  if (customItems != null) {
    items.addAll(customItems);
  } else {
    // 1. リプライ（自分・相手どちらでも可能）
    if (onReply != null) {
      items.add(
        ChatMessageActionItem(
          icon: Icons.reply_rounded,
          label: 'リプライ',
          iconColor: Colors.white,
          textColor: Colors.white,
          onTap: onReply,
        ),
      );
    }

    // 2. コピー（テキストが存在する場合）
    if (messageText != null && messageText.isNotEmpty) {
      items.add(
        ChatMessageActionItem(
          icon: Icons.content_copy_rounded,
          label: 'コピー',
          iconColor: const Color(0xFFE2E8F0),
          textColor: const Color(0xFFCBD5E1),
          onTap: () {
            if (onCopy != null) {
              onCopy();
            } else {
              Clipboard.setData(ClipboardData(text: messageText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('メッセージをコピーしました'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
        ),
      );
    }

    // 3. 非表示（相手のメッセージのみ）
    if (!isMyMessage && onHide != null) {
      items.add(
        ChatMessageActionItem(
          icon: Icons.visibility_off_outlined,
          label: '非表示',
          iconColor: const Color(0xFFE2E8F0),
          textColor: const Color(0xFFCBD5E1),
          onTap: onHide,
        ),
      );
    }

    // 4. 通報（相手のメッセージのみ）
    if (!isMyMessage && onReport != null) {
      items.add(
        ChatMessageActionItem(
          icon: Icons.warning_amber_rounded,
          label: '通報',
          iconColor: const Color(0xFFFBBF24),
          textColor: const Color(0xFFFDE68A),
          onTap: onReport,
        ),
      );
    }

    // 5. 削除（自分のメッセージ、またはオプチャ管理者権限がある場合）
    if ((isMyMessage || canDelete) && onDelete != null) {
      items.add(
        ChatMessageActionItem(
          icon: Icons.delete_outline_rounded,
          label: deleteLabel,
          isDestructive: true,
          iconColor: const Color(0xFFFB7185),
          textColor: const Color(0xFFFDA4AF),
          onTap: onDelete,
        ),
      );
    }
  }

  if (items.isEmpty) return;

  // ボタン数に応じた横幅の計算
  const double itemWidth = 52.0;
  const double horizontalPadding = 12.0;
  final double totalWidth = (items.length * itemWidth) + horizontalPadding;
  const double totalHeight = 54.0;

  showPopover(
    context: context,
    direction: direction,
    backgroundColor: const Color(0xF2232328), // 半透明ダークグレー (#232328)
    barrierColor: Colors.transparent,
    radius: 14.0,
    arrowHeight: 6.0,
    arrowWidth: 12.0,
    width: totalWidth,
    height: totalHeight,
    shadow: const [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 16,
        spreadRadius: 2,
        offset: Offset(0, 4),
      ),
    ],
    transitionDuration: const Duration(milliseconds: 140),
    bodyBuilder: (popoverContext) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.map((item) {
            return _buildActionButton(
              popoverContext: popoverContext,
              item: item,
              itemWidth: itemWidth,
            );
          }).toList(),
        ),
      );
    },
  );
}

Widget _buildActionButton({
  required BuildContext popoverContext,
  required ChatMessageActionItem item,
  required double itemWidth,
}) {
  final content = InkWell(
    onTap: () {
      Navigator.of(popoverContext).pop();
      item.onTap();
    },
    borderRadius: BorderRadius.circular(10),
    splashColor: Colors.white12,
    highlightColor: Colors.white10,
    child: Container(
      width: itemWidth - 4,
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: item.isDestructive
          ? BoxDecoration(
              color: const Color(0x38F43F5E), // 赤い半透明背景
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0x66F43F5E),
                width: 1,
              ),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            size: 19,
            color: item.iconColor ?? Colors.white70,
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: item.isDestructive ? FontWeight.bold : FontWeight.w500,
              color: item.textColor ?? const Color(0xFFCBD5E1),
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  return content;
}
