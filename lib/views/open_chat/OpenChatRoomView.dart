import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/image_upload_provider.dart';
import 'package:debate_project/widgets/ios_swipe_back.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:debate_project/widgets/popover_widgets.dart';
import 'package:debate_project/widgets/resba_attach_sheet.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/views/open_chat/OpenChatMenuView.dart';
import 'package:debate_project/widgets/full_screen_image_viewer.dart';
import 'package:go_router/go_router.dart';

class OpenChatRoomView extends HookConsumerWidget {
  final OpenChatRoom room;

  const OpenChatRoomView({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(openChatMessagesProvider(room.id));
    final currentUserId = ref.watch(currentUserIdProvider);
    final textController = useTextEditingController();
    final textFieldFocusNode = useFocusNode();
    final scrollController = useScrollController();

    final selectedImage = useState<File?>(null);
    final isUploading = useState(false);
    // ⚔️ レスバ添付(募集型: 誰でも応募可)
    final resbaAttachment = useState<ResbaAttachment?>(null);

    // このルームのメッセージに付いたレスバ一覧
    final resbasAsync = ref.watch(openChatResbasProvider(room.id));
    final resbas = resbasAsync.valueOrNull ?? const <ResbaInvite>[];
    void refreshResbas() {
      ref.invalidate(openChatResbasProvider(room.id));
    }

    // 最新のルーム情報（名前更新等の即時反映）
    final roomDetailAsync = ref.watch(openChatRoomDetailProvider(room.id));
    final currentRoom = roomDetailAsync.valueOrNull ?? room;

    useEffect(() {
      void scrollListener() {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent) {
          // 一番上（過去）にスクロールした時
          ref.read(openChatMessagesProvider(room.id).notifier).loadMore();
        }
      }

      scrollController.addListener(scrollListener);
      return () => scrollController.removeListener(scrollListener);
    }, [scrollController, room.id]);

    final hasBgImage = currentRoom.backgroundUrl != null && currentRoom.backgroundUrl!.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: hasBgImage,
      backgroundColor: Colors.blue,
      appBar: AppBar(
        backgroundColor: hasBgImage ? Colors.transparent : Colors.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          currentRoom.name,
          style: AppTextStyles.bold(color: Colors.white, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, _, __) => IosSwipeBack(
                    child: OpenChatMenuView(room: currentRoom),
                  ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.blue,
          image: hasBgImage
              ? DecorationImage(
                  image: CachedNetworkImageProvider(room.backgroundUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.15),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: SafeArea(
          top: hasBgImage,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                error: (error, stack) => Center(
                    child: Text('エラー: $error',
                        style: const TextStyle(color: Colors.white))),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'まだメッセージはありません',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isUserMessage = message.userId == currentUserId;
                      final isSending = message.id.startsWith('temp_');

                      // アバター表示ロジック：相手の発言かつ、一つ前（古い方）の送信者と異なる場合に表示
                      final showAvatar = !isUserMessage &&
                          (index == messages.length - 1 ||
                              messages[index + 1].userId != message.userId);

                      // このメッセージに付いたレスバ(募集型)
                      final msgResbas = resbas
                          .where((r) =>
                              r.attachType == 'open_chat' &&
                              r.attachId == message.id &&
                              (r.isPending || r.isAccepted || r.isFinished))
                          .toList();

                      final hasBubbleContent =
                          message.content.isNotEmpty || message.imageUrl != null;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 4.0),
                        child: Column(
                            crossAxisAlignment: isUserMessage
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (hasBubbleContent) ...[
                              // ① 写真がある場合
                              if (message.imageUrl != null)
                                Padding(
                                  padding: EdgeInsets.only(
                                      bottom: message.content.isNotEmpty ? 4.0 : 0.0),
                                  child: Row(
                                    crossAxisAlignment: isUserMessage
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    mainAxisAlignment: isUserMessage
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      if (!isUserMessage) ...[
                                        if (showAvatar)
                                          GestureDetector(
                                            onTap: () {
                                              context.push('/userProfile',
                                                  extra: message.userId);
                                            },
                                            child: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Colors.grey[300],
                                              child: Icon(Icons.person,
                                                  size: 16, color: Colors.grey[600]),
                                            ),
                                          )
                                        else
                                          const SizedBox(width: 32),
                                        const SizedBox(width: 8),
                                      ],
                                      // テキストがない場合のみ写真の左横に送信ステータスを表示
                                      if (isUserMessage && message.content.isEmpty) ...[
                                        _buildStatus(message.id),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Opacity(
                                          opacity: isSending ? 0.6 : 1.0,
                                          child: Builder(
                                            builder: (bubbleContext) {
                                              return GestureDetector(
                                                onLongPress: isUserMessage
                                                    ? null
                                                    : () {
                                                        showCustomPopover(
                                                          context: bubbleContext,
                                                          height: 130,
                                                          children: [
                                                            PopoverButton(
                                                              text: '通報',
                                                              onTap: () async {
                                                                Navigator.of(context).pop();
                                                                await showReportDialog(
                                                                  context: context,
                                                                  ref: ref,
                                                                  opponentId: message.userId,
                                                                  contentId: message.id,
                                                                  contentType: 'open_chat_message',
                                                                  contentSnapshot: message.content,
                                                                );
                                                              },
                                                            ),
                                                            const SizedBox(height: 4),
                                                            PopoverButton(
                                                              text: '非表示',
                                                              onTap: () {
                                                                Navigator.of(context).pop();
                                                                ref
                                                                    .read(openChatMessagesProvider(
                                                                            room.id)
                                                                        .notifier)
                                                                    .hideMessage(message.id);
                                                              },
                                                            ),
                                                            const SizedBox(height: 4),
                                                            PopoverButton(
                                                              text: 'ブロック',
                                                              onTap: () {
                                                                Navigator.of(context).pop();
                                                                showBlockUserDialog(
                                                                  context: context,
                                                                  ref: ref,
                                                                  targetUserId: message.userId,
                                                                  targetName: 'このユーザー',
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                onTap: () {
                                                  FullScreenImageViewer.show(
                                                    context,
                                                    imageUrls: [message.imageUrl!],
                                                    initialIndex: 0,
                                                  );
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Container(
                                                    constraints: BoxConstraints(
                                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                                                    ),
                                                    child: CachedNetworkImage(
                                                      imageUrl: message.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      memCacheWidth: 900,
                                                      fadeInDuration: Duration.zero,
                                                      fadeOutDuration: Duration.zero,
                                                      placeholder: (context, url) => Container(
                                                        height: 150,
                                                        width: 200,
                                                        color: Colors.grey[300],
                                                        child: const Center(
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        ),
                                                      ),
                                                      errorWidget: (context, url, error) => Container(
                                                        height: 120,
                                                        width: 160,
                                                        color: Colors.grey[200],
                                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // ② テキストがある場合
                              if (message.content.isNotEmpty)
                                Row(
                                  crossAxisAlignment: isUserMessage
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisAlignment: isUserMessage
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    if (!isUserMessage) ...[
                                      // 写真が上に表示されていてアバターが表示済みの場合はアバター幅(32)をインデント
                                      if (message.imageUrl != null)
                                        const SizedBox(width: 32)
                                      else if (showAvatar)
                                        GestureDetector(
                                          onTap: () {
                                            context.push('/userProfile',
                                                extra: message.userId);
                                          },
                                          child: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.grey[300],
                                            child: Icon(Icons.person,
                                                size: 16, color: Colors.grey[600]),
                                          ),
                                        )
                                      else
                                        const SizedBox(width: 32),
                                      const SizedBox(width: 8),
                                    ],
                                    // ユーザーメッセージの場合、テキスト吹き出しのすぐ左下に送信ステータスを配置
                                    if (isUserMessage) ...[
                                      _buildStatus(message.id),
                                      const SizedBox(width: 4),
                                    ],
                                    Flexible(
                                      child: Opacity(
                                        opacity: isSending ? 0.6 : 1.0,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Builder(
                                              builder: (bubbleContext) {
                                                return GestureDetector(
                                                  onLongPress: isUserMessage
                                                      ? null
                                                      : () {
                                                          showCustomPopover(
                                                            context: bubbleContext,
                                                            height: 130,
                                                            children: [
                                                              PopoverButton(
                                                                text: '通報',
                                                                onTap: () async {
                                                                  Navigator.of(context).pop();
                                                                  await showReportDialog(
                                                                    context: context,
                                                                    ref: ref,
                                                                    opponentId: message.userId,
                                                                    contentId: message.id,
                                                                    contentType: 'open_chat_message',
                                                                    contentSnapshot: message.content,
                                                                  );
                                                                },
                                                              ),
                                                              const SizedBox(height: 4),
                                                              PopoverButton(
                                                                text: '非表示',
                                                                onTap: () {
                                                                  Navigator.of(context).pop();
                                                                  ref
                                                                      .read(openChatMessagesProvider(
                                                                              room.id)
                                                                          .notifier)
                                                                      .hideMessage(message.id);
                                                                },
                                                              ),
                                                              const SizedBox(height: 4),
                                                              PopoverButton(
                                                                text: 'ブロック',
                                                                onTap: () {
                                                                  Navigator.of(context).pop();
                                                                  showBlockUserDialog(
                                                                    context: context,
                                                                    ref: ref,
                                                                    targetUserId: message.userId,
                                                                    targetName: 'このユーザー',
                                                                  );
                                                                },
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                  child: Container(
                                                    constraints: BoxConstraints(
                                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                                    ),
                                                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                                                    decoration: BoxDecoration(
                                                      color: isUserMessage
                                                          ? const Color(0xff95eb7c)
                                                          : Colors.white,
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Text(
                                                      message.content,
                                                      style: AppTextStyles.notoSans(
                                                        color: Colors.black,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            // しっぽ（テキスト用）
                                            Positioned(
                                              top: 6,
                                              left: isUserMessage ? null : -6,
                                              right: isUserMessage ? -6 : null,
                                              child: CustomPaint(
                                                painter: _OpenChatBubbleTailPainter(
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
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                            for (final invite in msgResbas)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: hasBubbleContent ? 6 : 0,
                                  left: isUserMessage ? 0 : (hasBubbleContent ? 40 : 0),
                                  right: isUserMessage ? 8 : 0,
                                ),
                                child: ResbaCard(
                                  invite: invite,
                                  onChanged: refreshResbas,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // 入力エリア
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            padding: EdgeInsets.only(
              left: 8,
              right: 2,
              top: 4,
              bottom: MediaQuery.of(context).padding.bottom + 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.grey),
                      onPressed: isUploading.value
                          ? null
                          : () async {
                              final picker = ref.read(imageUploadProvider);
                              final image = await picker.pickImage();
                              if (image != null) {
                                selectedImage.value = image;
                              }
                            },
                    ),
                    // ⚔️ レスバ添付(募集型: 誰でも応募可)
                    IconButton(
                      icon: const Text('⚔️',
                          style: TextStyle(
                              fontSize: 20, color: Color(0xFF7856FF))),
                      onPressed: isUploading.value
                          ? null
                          : () async {
                              final attachment = await showResbaAttachSheet(
                                context,
                                presetTheme: textController.text.trim(),
                              );
                              if (attachment != null) {
                                resbaAttachment.value = attachment;
                              }
                            },
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          focusNode: textFieldFocusNode,
                          controller: textController,
                          maxLength: 200,
                          textAlignVertical: TextAlignVertical.center,
                          style: AppTextStyles.notoSans(
                              color: Colors.black, fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'メッセージを入力',
                            counterText: '',
                            hintStyle:
                                AppTextStyles.notoSans(color: Colors.grey[400]),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      onPressed: isUploading.value
                          ? null
                          : () async {
                              final rawText = textController.text.trim();
                              if (rawText.isNotEmpty ||
                                  selectedImage.value != null ||
                                  resbaAttachment.value != null) {
                                isUploading.value = true;
                                try {
                                  // 裏側で最大200文字制限
                                  final sendText = rawText.length > 200
                                      ? rawText.substring(0, 200)
                                      : rawText;

                                  String? uploadedUrl;
                                  if (selectedImage.value != null) {
                                    final uploader =
                                        ref.read(imageUploadProvider);
                                    uploadedUrl = await uploader.uploadImage(
                                      file: selectedImage.value!,
                                      bucketName: 'chat_images',
                                      folderName: 'open_chat',
                                    );
                                  }

                                  final messageId = await ref
                                      .read(openChatMessagesProvider(room.id).notifier)
                                      .sendMessage(
                                        sendText,
                                        imageUrl: uploadedUrl,
                                      );

                                  // ⚔️ レスバを添付(募集型)
                                  final attachment = resbaAttachment.value;
                                  if (attachment != null &&
                                      messageId != null) {
                                    final result = await ref
                                        .read(resbaActionsProvider)
                                        .createOpenChatResba(
                                          messageId: messageId,
                                          theme: attachment.theme,
                                          choice1: attachment.choice1,
                                          choice2: attachment.choice2,
                                        );
                                    if (result.error != null &&
                                        context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(result.error!)),
                                      );
                                    }
                                    refreshResbas();
                                  }

                                  textController.clear();
                                  selectedImage.value = null;
                                  resbaAttachment.value = null;
                                  if (scrollController.hasClients) {
                                    scrollController.animateTo(
                                      0, // reverse: true のため先頭（最新）へスクロール
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('送信エラー: $e')));
                                  }
                                } finally {
                                  isUploading.value = false;
                                }
                              }
                            },
                      icon: isUploading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send,
                              color: Colors.blue, size: 24),
                    ),
                  ],
                ),
                if (selectedImage.value != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 8.0, left: 48.0, bottom: 8.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            selectedImage.value!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: -8,
                          top: -8,
                          child: GestureDetector(
                            onTap: () {
                              selectedImage.value = null;
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (resbaAttachment.value != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 8.0, left: 48.0, bottom: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF8FF),
                        border: Border.all(color: const Color(0xFF7856FF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text('⚔️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'レスバ: ${resbaAttachment.value!.theme}',
                              style: AppTextStyles.bold(
                                  fontSize: 12.5,
                                  color: const Color(0xFF7856FF)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              resbaAttachment.value = null;
                            },
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildStatus(String messageId) {
    String? statusText;
    Color statusColor = Colors.white70;

    if (messageId.startsWith('temp_')) {
      statusText = null;
    } else if (messageId.startsWith('error_')) {
      statusText = '✕';
      statusColor = Colors.redAccent;
    } else {
      statusText = '送信';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (statusText != null)
          Text(
            statusText,
            style: AppTextStyles.notoSans(fontSize: 9, color: statusColor),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _OpenChatBubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isUserMessage;

  _OpenChatBubbleTailPainter(this.color, this.isUserMessage);

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
