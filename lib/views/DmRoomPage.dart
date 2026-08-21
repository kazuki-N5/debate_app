import 'dart:io';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/chat_inbox_provider.dart';
import 'package:debate_project/provider/dm_provider.dart';
import 'package:debate_project/provider/image_upload_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:debate_project/widgets/popover_widgets.dart';
import 'package:debate_project/widgets/resba_attach_sheet.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/widgets/full_screen_image_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DmRoomPage extends HookConsumerWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const DmRoomPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomIdAsync = ref.watch(dmRoomIdProvider(otherUserId));
    final scrollController = useScrollController();

    // ブロック状態(自分がブロック / 相手からブロック)
    final blockedByMe = ref.watch(blockedUserIdsProvider).contains(otherUserId);
    final blockedByThem =
        ref.watch(isBlockedByProvider(otherUserId)).valueOrNull ?? false;
    final isBlocked = blockedByMe || blockedByThem;

    // 端末内で非表示にしたメッセージID(「非表示」機能)
    final hiddenMessageIds = useState<Set<String>>({});
    useEffect(() {
      Future<void> load() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          hiddenMessageIds.value =
              (prefs.getStringList('hidden_dm_message_ids') ?? const []).toSet();
        } catch (_) {}
      }

      load();
      return null;
    }, []);

    Future<void> hideDmMessage(String messageId) async {
      final next = {...hiddenMessageIds.value, messageId};
      hiddenMessageIds.value = next;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('hidden_dm_message_ids', next.toList());
      } catch (_) {}
    }

    // roomIdが取得できている場合のみメッセージをwatchする
    final roomId = roomIdAsync.valueOrNull;
    final messagesAsync = roomId != null
        ? ref.watch(dmMessagesProvider(roomId))
        : const AsyncValue.loading();

    // 画面を開いた時および新着メッセージ受信時に既読化
    useEffect(() {
      if (roomId != null && messagesAsync.hasValue) {
        ref.read(markDmReadProvider)(roomId);
      }
      return null;
    }, [roomId, messagesAsync.valueOrNull?.length]);

    // 過去メッセージの読み込みトリガー
    useEffect(() {
      void scrollListener() {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent) {
          // 一番上（過去）にスクロールした時
          if (roomId != null) {
            ref.read(dmMessagesProvider(roomId).notifier).loadMore();
          }
        }
      }

      scrollController.addListener(scrollListener);
      return () => scrollController.removeListener(scrollListener);
    }, [scrollController, roomId]);

    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage:
                  otherUserAvatar != null && otherUserAvatar!.isNotEmpty
                      ? NetworkImage(otherUserAvatar!)
                      : null,
              child: otherUserAvatar == null || otherUserAvatar!.isEmpty
                  ? Icon(Icons.person, size: 16, color: Colors.grey[600])
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                otherUserName,
                style: AppTextStyles.notoSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: roomIdAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (err, stack) {
          // ブロックされている場合は専用メッセージを表示
          if (err.toString().contains('BLOCKED')) {
            return Center(
              child: Text(
                blockedByThem
                    ? 'ブロックされているためDMを開始できません'
                    : 'ブロックしたユーザーとのDMは開始できません',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          return Center(
              child:
                  Text('エラー: $err', style: const TextStyle(color: Colors.white)));
        },
        data: (rId) {
          final resbasAsync = ref.watch(dmResbaProvider(rId));
          final resbas = resbasAsync.valueOrNull ?? const <ResbaInvite>[];
          return Column(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: messagesAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                    error: (err, stack) => Center(
                        child: Text('エラー: $err',
                            style: const TextStyle(color: Colors.white))),
                    data: (messages) {
                      final myId =
                          ref.read(supabaseProvider).auth.currentUser?.id;
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
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        reverse: true,
                        itemCount: messages.length,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId == myId;

                          // 非表示にしたメッセージは表示しない
                          if (hiddenMessageIds.value.contains(msg.id)) {
                            return const SizedBox.shrink();
                          }

                          final isSending = msg.id.startsWith('temp_');

                          // アバター表示ロジック：相手の発言かつ、一つ前（古い方）の送信者と異なる場合に表示
                          final showAvatar = !isMe &&
                              (index == messages.length - 1 ||
                                  messages[index + 1].senderId != msg.senderId);

                          // このメッセージに付いたレスバ（アクティブのみ）
                          final msgResbas = resbas
                              .where((r) =>
                                  r.attachType == 'dm' &&
                                  r.attachId == msg.id &&
                                  (r.isPending || r.isAccepted))
                              .toList();

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 4.0),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    if (!isMe) ...[
                                      if (showAvatar)
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.grey[300],
                                          backgroundImage: otherUserAvatar !=
                                                      null &&
                                                  otherUserAvatar!.isNotEmpty
                                              ? NetworkImage(otherUserAvatar!)
                                              : null,
                                          child: otherUserAvatar == null ||
                                                  otherUserAvatar!.isEmpty
                                              ? Icon(Icons.person,
                                                  color: Colors.grey[600], size: 16)
                                              : null,
                                        )
                                      else
                                        const SizedBox(width: 32),
                                      const SizedBox(width: 8),
                                    ],
                                    if (isMe) ...[
                                      _buildStatus(msg.id),
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
                                                  onLongPress: isMe
                                                      ? null
                                                      : () {
                                                          showCustomPopover(
                                                            context:
                                                                bubbleContext,
                                                            height: 130,
                                                            children: [
                                                              PopoverButton(
                                                                text: '通報',
                                                                onTap:
                                                                    () async {
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop();
                                                                  await showReportDialog(
                                                                    context:
                                                                        context,
                                                                    ref: ref,
                                                                    opponentId:
                                                                        msg.senderId,
                                                                    contentId:
                                                                        msg.id,
                                                                    contentType:
                                                                        'dm_message',
                                                                    contentSnapshot:
                                                                        msg.content,
                                                                  );
                                                                },
                                                              ),
                                                              const SizedBox(
                                                                  height: 4),
                                                              PopoverButton(
                                                                text: '非表示',
                                                                onTap: () {
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop();
                                                                  hideDmMessage(
                                                                      msg.id);
                                                                },
                                                              ),
                                                              const SizedBox(
                                                                  height: 4),
                                                              PopoverButton(
                                                                text: 'ブロック',
                                                                onTap: () {
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop();
                                                                  showBlockUserDialog(
                                                                    context:
                                                                        context,
                                                                    ref: ref,
                                                                    targetUserId:
                                                                        msg.senderId,
                                                                    targetName:
                                                                        otherUserName,
                                                                  );
                                                                },
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                  child: Container(
                                                    constraints: BoxConstraints(
                                                      maxWidth:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.75,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                            12, 6, 12, 8),
                                                    decoration: BoxDecoration(
                                                      color: isMe
                                                          ? const Color(
                                                              0xff95eb7c)
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (msg.imageUrl !=
                                                            null)
                                                          Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                    bottom: msg
                                                                            .content
                                                                            .isNotEmpty
                                                                        ? 4.0
                                                                        : 0.0),
                                                            child:
                                                                GestureDetector(
                                                              onTap: () {
                                                                FullScreenImageViewer
                                                                    .show(
                                                                  context,
                                                                  imageUrls: [
                                                                    msg.imageUrl!
                                                                  ],
                                                                  initialIndex:
                                                                      0,
                                                                );
                                                              },
                                                              child: ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                child:
                                                                    CachedNetworkImage(
                                                                  imageUrl: msg
                                                                      .imageUrl!,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  memCacheWidth:
                                                                      900,
                                                                  fadeInDuration:
                                                                      Duration
                                                                          .zero,
                                                                  fadeOutDuration:
                                                                      Duration
                                                                          .zero,
                                                                  placeholder: (context,
                                                                          url) =>
                                                                      Container(
                                                                          height:
                                                                              150,
                                                                          color: Colors.grey[300]),
                                                                  errorWidget: (context,
                                                                          url,
                                                                          error) =>
                                                                      const Icon(
                                                                          Icons.error),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        if (msg.content
                                                            .isNotEmpty)
                                                          Text(
                                                            msg.content,
                                                            style:
                                                                AppTextStyles
                                                                    .notoSans(
                                                              color:
                                                                  Colors.black,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            // しっぽ（ゲーム画面と同一）
                                            Positioned(
                                              top: 6,
                                              left: isMe ? null : -6,
                                              right: isMe ? -6 : null,
                                              child: CustomPaint(
                                                painter: _BubbleTailPainter(
                                                  isMe
                                                      ? const Color(0xff95eb7c)
                                                      : Colors.white,
                                                  isMe,
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
                                // レスバカード（承諾/拒否・相手待ち表示）
                                for (final invite in msgResbas)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: 6,
                                      left: isMe ? 0 : 40,
                                      right: isMe ? 8 : 0,
                                    ),
                                    child: ResbaCard(
                                      invite: invite,
                                      onChanged: () {
                                        ref.invalidate(dmResbaProvider(rId));
                                      },
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
              ),
              if (isBlocked)
                Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    blockedByThem
                        ? 'ブロックされているためDMを送信できません'
                        : 'ブロックしたユーザーです。DMを送信できません',
                    style:
                        AppTextStyles.notoSans(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!isBlocked) _MessageInputWidget(roomId: rId),
            ],
          );
        },
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

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isUserMessage;

  _BubbleTailPainter(this.color, this.isUserMessage);

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

class _MessageInputWidget extends HookConsumerWidget {
  final String roomId;

  const _MessageInputWidget({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageController = useTextEditingController();
    final selectedImage = useState<File?>(null);
    final isUploading = useState(false);
    final resbaAttachment = useState<ResbaAttachment?>(null);

    void sendMessage() async {
      final text = messageController.text.trim();
      if (text.isEmpty &&
          selectedImage.value == null &&
          resbaAttachment.value == null) {
        return;
      }

      isUploading.value = true;
      try {
        // 裏側で最大200文字制限
        final sendText = text.length > 200 ? text.substring(0, 200) : text;

        String? uploadedUrl;
        if (selectedImage.value != null) {
          final uploader = ref.read(imageUploadProvider);
          uploadedUrl = await uploader.uploadImage(
            file: selectedImage.value!,
            bucketName: 'chat_images',
            folderName: 'dm',
          );
        }

        // 楽観的UIによる即時反映のためProviderに依頼
        final messageId = await ref
            .read(dmMessagesProvider(roomId).notifier)
            .sendMessage(sendText, imageUrl: uploadedUrl);

        // レスバ（写真）を送る感覚でレスバを添付
        final attachment = resbaAttachment.value;
        if (attachment != null && messageId != null) {
          final result = await ref.read(resbaActionsProvider).sendDmResba(
                messageId: messageId,
                theme: attachment.theme,
                choice1: attachment.choice1,
                choice2: attachment.choice2,
              );
          if (result.error != null && context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(result.error!)));
          }
          ref.invalidate(dmResbaProvider(roomId));
        }

        messageController.clear();
        selectedImage.value = null;
        resbaAttachment.value = null;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('送信エラー: $e')));
        }
      } finally {
        isUploading.value = false;
      }
    }

    return Container(
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
              // ⚔️ レスバ（写真）を送る
              IconButton(
                icon: const Text('⚔️',
                    style: TextStyle(fontSize: 20, color: Color(0xFF7856FF))),
                onPressed: isUploading.value
                    ? null
                    : () async {
                        final attachment = await showResbaAttachSheet(
                          context,
                          presetTheme: messageController.text.trim(),
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
                    controller: messageController,
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
                    textInputAction: TextInputAction.send,
                    onSubmitted:
                        isUploading.value ? null : (_) => sendMessage(),
                  ),
                ),
              ),
              IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                icon: isUploading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.blue, size: 24),
                onPressed: isUploading.value ? null : sendMessage,
              ),
            ],
          ),
          if (selectedImage.value != null)
            Padding(
              padding:
                  const EdgeInsets.only(top: 8.0, left: 48.0, bottom: 8.0),
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
              padding:
                  const EdgeInsets.only(top: 8.0, left: 48.0, bottom: 8.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7856FF),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        resbaAttachment.value = null;
                      },
                      child:
                          const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
