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
import 'package:debate_project/widgets/resba_attach_sheet.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/views/open_chat/OpenChatMenuView.dart';
import 'package:debate_project/widgets/chat/chat_message_bubble.dart';
import 'package:debate_project/provider/user_profile_provider.dart';

class OpenChatRoomView extends HookConsumerWidget {
  final OpenChatRoom room;

  const OpenChatRoomView({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(openChatMessagesProvider(room.id));
    final currentUserId = ref.watch(currentUserIdProvider);
    final membersAsync = ref.watch(openChatMembersProvider(room.id));
    final myMember = membersAsync.valueOrNull?.where((m) => m.userId == currentUserId).firstOrNull;
    final isChatAdmin = myMember?.isModerator ?? false;
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

    // リプライ対象メッセージの状態
    final replyTarget = useState<OpenChatMessage?>(null);
    // ハイライト表示するメッセージIDの状態
    final highlightedMsgId = useState<String?>(null);

    // 返信先メッセージへジャンプしてハイライトする関数
    void jumpToMessage(String messageId, List<OpenChatMessage> messages) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1 && scrollController.hasClients) {
        final targetOffset = (index * 72.0).clamp(
          0.0,
          scrollController.position.maxScrollExtent,
        );
        scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
      highlightedMsgId.value = messageId;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (highlightedMsgId.value == messageId) {
          highlightedMsgId.value = null;
        }
      });
    }

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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      extendBodyBehindAppBar: hasBgImage,
      backgroundColor: Colors.blue,
      appBar: AppBar(
        backgroundColor: hasBgImage ? Colors.transparent : Colors.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
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

                      return _OpenChatBubbleItem(
                        key: ValueKey(message.id),
                        message: message,
                        roomId: room.id,
                        isUserMessage: isUserMessage,
                        isSending: isSending,
                        showAvatar: showAvatar,
                        isChatAdmin: isChatAdmin,
                        msgResbas: msgResbas,
                        onRefreshResbas: refreshResbas,
                        statusWidget: isUserMessage ? _buildStatus(message.id) : null,
                        onReply: () {
                          replyTarget.value = message;
                          textFieldFocusNode.requestFocus();
                        },
                        onTapReplyQuote: message.replyToId != null
                            ? () => jumpToMessage(message.replyToId!, messages)
                            : null,
                        isHighlighted: highlightedMsgId.value == message.id,
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
              bottom: MediaQuery.of(context).padding.bottom + 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // リプライ中の返信先プレビューバー
                if (replyTarget.value != null)
                  Container(
                    color: const Color(0xFFEEF2FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply,
                          size: 16,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: AppTextStyles.notoSans(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              children: [
                                TextSpan(
                                  text: replyTarget.value!.userId == currentUserId
                                      ? '自分'
                                      : (ref.watch(userBasicInfoProvider(replyTarget.value!.userId)).valueOrNull?.name ?? 'ユーザー'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                                const TextSpan(
                                  text: ' に返信: ',
                                  style: TextStyle(color: Colors.black54),
                                ),
                                TextSpan(
                                  text: replyTarget.value!.content.isNotEmpty
                                      ? replyTarget.value!.content
                                      : '[画像]',
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => replyTarget.value = null,
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 2, top: 4),
                  child: Row(
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

                                  final target = replyTarget.value;
                                  final targetUserName = target == null
                                      ? null
                                      : (target.userId == currentUserId
                                          ? '自分'
                                          : (ref.watch(userBasicInfoProvider(target.userId)).valueOrNull?.name ?? 'ユーザー'));

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

                                  String? messageId;
                                  if (uploadedUrl != null && sendText.isNotEmpty) {
                                    // 画像とテキストの両方がある場合は2通に分けて送信
                                    await ref
                                        .read(openChatMessagesProvider(room.id).notifier)
                                        .sendMessage('', imageUrl: uploadedUrl);
                                    messageId = await ref
                                        .read(openChatMessagesProvider(room.id).notifier)
                                        .sendMessage(
                                          sendText,
                                          replyToId: target?.id,
                                          replyToContent: target?.content,
                                          replyToUserName: targetUserName,
                                        );
                                  } else if (uploadedUrl != null) {
                                    // 画像単体
                                    messageId = await ref
                                        .read(openChatMessagesProvider(room.id).notifier)
                                        .sendMessage(
                                          '',
                                          imageUrl: uploadedUrl,
                                          replyToId: target?.id,
                                          replyToContent: target?.content,
                                          replyToUserName: targetUserName,
                                        );
                                  } else if (sendText.isNotEmpty) {
                                    // テキスト単体
                                    messageId = await ref
                                        .read(openChatMessagesProvider(room.id).notifier)
                                        .sendMessage(
                                          sendText,
                                          replyToId: target?.id,
                                          replyToContent: target?.content,
                                          replyToUserName: targetUserName,
                                        );
                                  } else if (resbaAttachment.value != null) {
                                    // ⚔️ レスバ単体（テキストも画像もない場合）
                                    messageId = await ref
                                        .read(openChatMessagesProvider(room.id).notifier)
                                        .sendMessage(
                                          '',
                                          replyToId: target?.id,
                                          replyToContent: target?.content,
                                          replyToUserName: targetUserName,
                                        );
                                  }

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

                                  replyTarget.value = null;
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

class _OpenChatBubbleItem extends ConsumerWidget {
  final OpenChatMessage message;
  final String roomId;
  final bool isUserMessage;
  final bool isSending;
  final bool showAvatar;
  final bool isChatAdmin;
  final List<ResbaInvite> msgResbas;
  final VoidCallback onRefreshResbas;
  final Widget? statusWidget;
  final VoidCallback? onReply;
  final VoidCallback? onTapReplyQuote;
  final bool isHighlighted;

  const _OpenChatBubbleItem({
    super.key,
    required this.message,
    required this.roomId,
    required this.isUserMessage,
    required this.isSending,
    required this.showAvatar,
    required this.isChatAdmin,
    required this.msgResbas,
    required this.onRefreshResbas,
    this.statusWidget,
    this.onReply,
    this.onTapReplyQuote,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ユーザー情報（名前・アバター）を取得
    final userAsync = ref.watch(userBasicInfoProvider(message.userId));
    final user = userAsync.valueOrNull;
    final senderName = user?.name ?? 'ユーザー';
    final senderAvatarUrl = user?.avatar_url;

    Widget? attachedWidget;
    if (msgResbas.isNotEmpty) {
      attachedWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final invite in msgResbas)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ResbaCard(
                invite: invite,
                onChanged: onRefreshResbas,
              ),
            ),
        ],
      );
    }

    return Opacity(
      opacity: isSending ? 0.6 : 1.0,
      child: ChatMessageBubble(
        id: message.id,
        content: message.content,
        imageUrl: message.imageUrl,
        isUserMessage: isUserMessage,
        isDeleted: message.isDeleted,
        isAdminDeleted: message.isAdminDeleted,
        senderId: message.userId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        showAvatar: showAvatar,
        showSenderName: !isUserMessage,
        replyToId: message.replyToId,
        replyToContent: message.replyToContent,
        replyToUserName: message.replyToUserName,
        onReply: onReply,
        onTapReplyQuote: onTapReplyQuote,
        isHighlighted: isHighlighted,
        statusWidget: statusWidget,
        attachedWidget: attachedWidget,
        canDelete: isChatAdmin,
        deleteLabel: isUserMessage ? '削除' : '強制削除',
        onHide: () {
          ref
              .read(openChatMessagesProvider(roomId).notifier)
              .hideMessage(message.id);
        },
        onReport: () async {
          await showReportDialog(
            context: context,
            ref: ref,
            opponentId: message.userId,
            contentId: message.id,
            contentType: 'open_chat_message',
            contentSnapshot: message.imageUrl != null ? '[画像]' : message.content,
          );
        },
        onDelete: () async {
          final error = await ref
              .read(openChatMessagesProvider(roomId).notifier)
              .deleteMessage(message.id);
          if (context.mounted) {
            if (error == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isUserMessage ? 'メッセージを削除しました' : 'メッセージを強制削除しました'),
                  duration: const Duration(seconds: 1),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('削除失敗: $error')),
              );
            }
          }
        },
      ),
    );
  }
}
