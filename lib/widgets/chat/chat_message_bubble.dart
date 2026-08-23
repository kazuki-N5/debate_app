import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/full_screen_image_viewer.dart';
import 'package:debate_project/widgets/chat_message_action_menu.dart';

/// 全チャット画面（オープンチャット、DM、対戦、観戦、履歴）共通のメッセージ吹き出しコンポーネント
class ChatMessageBubble extends StatelessWidget {
  final String id;
  final String content;
  final String? imageUrl;
  final bool isUserMessage;
  final bool isDeleted;
  final bool isAdminDeleted;
  final String? senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final bool showAvatar;
  final bool showSenderName;
  final bool showMyAvatar; // 観戦者用: 自分のアバターも描画するか
  final bool hasMyAvatarColumn; // 観戦者用: 右側のアバター列スペースを確保するか
  final bool isSending;
  final Widget? statusWidget;
  final Widget? attachedWidget;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToUserName;
  final VoidCallback? onTapReplyQuote;
  final bool isHighlighted;
  final bool canDelete;
  final String? deleteLabel;
  final VoidCallback? onReply;
  final VoidCallback? onHide;
  final VoidCallback? onReport;
  final Future<void> Function()? onDelete;
  final VoidCallback? onAvatarTap;

  const ChatMessageBubble({
    super.key,
    required this.id,
    required this.content,
    this.imageUrl,
    required this.isUserMessage,
    this.isDeleted = false,
    this.isAdminDeleted = false,
    this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    this.showAvatar = true,
    this.showSenderName = true,
    this.showMyAvatar = false,
    this.hasMyAvatarColumn = false,
    this.isSending = false,
    this.statusWidget,
    this.attachedWidget,
    this.replyToId,
    this.replyToContent,
    this.replyToUserName,
    this.onTapReplyQuote,
    this.isHighlighted = false,
    this.canDelete = false,
    this.deleteLabel,
    this.onReply,
    this.onHide,
    this.onReport,
    this.onDelete,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ShakeWidget(
      shake: isHighlighted,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
        child: Column(
          crossAxisAlignment:
              isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // ① 削除済みメッセージ表示
            if (isDeleted) ...[
              _buildDeletedBubble(context),
            ] else ...[
              // ② 通常メッセージ（画像/テキスト/付属カード）
              _buildNormalBubble(context),
            ],
          ],
        ),
      ),
    );
  }

  /// 削除されたメッセージ（LINE風送信取消 or 管理者削除）
  Widget _buildDeletedBubble(BuildContext context) {
    return Row(
      crossAxisAlignment:
          isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisAlignment:
          isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isUserMessage) ...[
          _buildAvatarWidget(context),
          const SizedBox(width: 8),
        ],
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isAdminDeleted ? const Color(0xFFFFF1F2) : Colors.grey[200],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAdminDeleted
                  ? const Color(0xFFFECDD3)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAdminDeleted ? Icons.shield_outlined : Icons.block_flipped,
                size: 13,
                color: isAdminDeleted ? Colors.red[700] : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                isAdminDeleted
                    ? '管理者によって削除されました'
                    : (isUserMessage ? 'メッセージを削除しました' : 'メッセージが削除されました'),
                style: TextStyle(
                  fontSize: 13,
                  color: isAdminDeleted ? Colors.red[700] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        if (isUserMessage && showMyAvatar) ...[
          const SizedBox(width: 8),
          _buildAvatarWidget(context),
        ],
      ],
    );
  }

  /// 通常メッセージの描画
  Widget _buildNormalBubble(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final hasText = content.isNotEmpty;
    final hasReply = (replyToContent != null && replyToContent!.isNotEmpty) ||
        (replyToUserName != null && replyToUserName!.isNotEmpty);
    final hasBubbleContent = hasImage || hasText || hasReply;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        // 相手のアバター
        if (!isUserMessage) ...[
          _buildAvatarWidget(context),
          const SizedBox(width: 6),
        ],

        // メッセージコンテンツ（名前 ＋ 吹き出し本体 ＋ ステータス ＋ 付属カード）
        Flexible(
          child: Column(
            crossAxisAlignment: isUserMessage
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // 送信者名の表示（アイコンを表示するときのみ）
              if (showSenderName &&
                  senderName != null &&
                  senderName!.isNotEmpty &&
                  (isUserMessage ? showMyAvatar : showAvatar))
                Padding(
                  padding: EdgeInsets.only(
                    left: isUserMessage ? 0 : 2,
                    right: isUserMessage ? 2 : 0,
                    bottom: 3,
                  ),
                  child: Text(
                    senderName!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

              // 吹き出し ＋ ステータス（下揃えで横並び）
              if (hasBubbleContent) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 自分の場合のステータス（吹き出しの左下）
                    if (isUserMessage && statusWidget != null) ...[
                      statusWidget!,
                      const SizedBox(width: 4),
                    ],
                    Flexible(child: _buildBubbleBody(context)),
                    // 相手の場合のステータス（必要時）
                    if (!isUserMessage && statusWidget != null) ...[
                      const SizedBox(width: 4),
                      statusWidget!,
                    ],
                  ],
                ),
              ],

              // 付属カード（レスバ招待など）
              if (attachedWidget != null) ...[
                if (hasBubbleContent) const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!hasBubbleContent && isUserMessage && statusWidget != null) ...[
                      statusWidget!,
                      const SizedBox(width: 4),
                    ],
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: attachedWidget!,
                    ),
                    if (!hasBubbleContent && !isUserMessage && statusWidget != null) ...[
                      const SizedBox(width: 4),
                      statusWidget!,
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),

        // 観戦者（自分）のアバター
        if (isUserMessage && (showMyAvatar || hasMyAvatarColumn)) ...[
          const SizedBox(width: 6),
          if (showMyAvatar)
            _buildAvatarWidget(context)
          else
            const SizedBox(width: 32),
        ],
      ],
    );
  }

  /// 吹き出し本体（画像 or テキスト ＋ しっぽ ＋ 長押しメニュー）
  Widget _buildBubbleBody(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final hasText = content.isNotEmpty;

    return Builder(
      builder: (bubbleContext) {
        return GestureDetector(
          onLongPress: () => _showMenu(bubbleContext),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: hasImage && !hasText
                    ? EdgeInsets.zero
                    : const EdgeInsets.fromLTRB(12, 6, 12, 8),
                decoration: BoxDecoration(
                  color: (hasImage && !hasText)
                      ? Colors.transparent
                      : (isUserMessage
                          ? const Color(0xff95eb7c)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 返信（リプライ）元の引用プレビューブロック
                    if ((replyToContent != null && replyToContent!.isNotEmpty) ||
                        (replyToUserName != null && replyToUserName!.isNotEmpty))
                      _buildReplyQuoteBlock(context),

                    // 写真がある場合
                    if (hasImage) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: hasText ? 4.0 : 0.0),
                        child: GestureDetector(
                          onTap: () {
                            FullScreenImageViewer.show(
                              context,
                              imageUrls: [imageUrl!],
                              initialIndex: 0,
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.5,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 900,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholder: (context, url) => Container(
                                  height: 150,
                                  width: 200,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 120,
                                  width: 160,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    // テキストがある場合
                    if (hasText)
                      Text(
                        content,
                        style: AppTextStyles.notoSans(
                          color: Colors.black87,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),

              // 吹き出しのしっぽ（テキストがある場合のみ表示）
              if (hasText)
                Positioned(
                  top: 6,
                  left: isUserMessage ? null : -6,
                  right: isUserMessage ? -6 : null,
                  child: CustomPaint(
                    painter: _UniversalBubbleTailPainter(
                      isUserMessage
                          ? const Color(0xff95eb7c)
                          : Colors.white,
                      isUserMessage,
                    ),
                    size: const Size(10, 10),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 返信（リプライ）元の引用プレビューブロック
  Widget _buildReplyQuoteBlock(BuildContext context) {
    final quoteAuthor = (replyToUserName != null && replyToUserName!.isNotEmpty)
        ? replyToUserName!
        : 'メッセージ';
    final quoteText = (replyToContent != null && replyToContent!.isNotEmpty)
        ? replyToContent!
        : '返信先メッセージ';

    return GestureDetector(
      onTap: onTapReplyQuote,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: isUserMessage
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.reply,
                  size: 13,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    quoteAuthor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              quoteText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// アバターウィジェット
  Widget _buildAvatarWidget(BuildContext context) {
    if (!showAvatar && !showMyAvatar) {
      return const SizedBox(width: 32);
    }

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[300],
      backgroundImage: senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty
          ? NetworkImage(senderAvatarUrl!)
          : null,
      child: (senderAvatarUrl == null || senderAvatarUrl!.isEmpty)
          ? Icon(Icons.person, size: 18, color: Colors.grey[600])
          : null,
    );

    if (onAvatarTap != null) {
      return GestureDetector(onTap: onAvatarTap, child: avatar);
    } else if (senderId != null && senderId!.isNotEmpty) {
      return GestureDetector(
        onTap: () => context.push('/userProfile', extra: senderId),
        child: avatar,
      );
    }

    return avatar;
  }

  /// 長押しメニューの表示（Builder の context により完全な中央・真上位置に表示）
  void _showMenu(BuildContext bubbleContext) {
    showChatMessageActionMenu(
      context: bubbleContext,
      messageText: content,
      isMyMessage: isUserMessage,
      canDelete: canDelete,
      deleteLabel: deleteLabel ?? (isUserMessage ? '削除' : '強制削除'),
      onReply: onReply,
      onHide: onHide,
      onReport: onReport,
      onDelete: onDelete != null
          ? () async {
              await onDelete!();
            }
          : null,
    );
  }
}

/// 共通吹き出ししっぽペインター
class _UniversalBubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isUserMessage;

  _UniversalBubbleTailPainter(this.color, this.isUserMessage);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isUserMessage) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height * 0.8);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(size.width, size.height * 0.8);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ハイライト時にブルブルと横に振動（シェイク）させるアニメーションウィジェット
class _ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;

  const _ShakeWidget({
    required this.child,
    required this.shake,
  });

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -4.5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.5, end: 4.5), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 4.5, end: -2.5), weight: 3),
      TweenSequenceItem(tween: Tween(begin: -2.5, end: 1.5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

    if (widget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant _ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}