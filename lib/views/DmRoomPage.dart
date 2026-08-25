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
import 'package:debate_project/utils/date_formatter.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:debate_project/widgets/resba_attach_sheet.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/views/dm/DmMenuView.dart';
import 'package:debate_project/widgets/ios_swipe_back.dart';
import 'package:debate_project/widgets/chat/chat_message_bubble.dart';

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
    // リプライ対象メッセージの状態
    final replyTarget = useState<DmMessage?>(null);
    // ハイライト表示するメッセージIDの状態
    final highlightedDmId = useState<String?>(null);

    // 返信先メッセージへジャンプしてハイライトする関数
    void jumpToMessage(String messageId, List<DmMessage> messages) {
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
      highlightedDmId.value = messageId;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (highlightedDmId.value == messageId) {
          highlightedDmId.value = null;
        }
      });
    }

    useEffect(() {
      Future<void> load() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          hiddenMessageIds.value =
              (prefs.getStringList('hidden_dm_message_ids') ?? const [])
                  .toSet();
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

    final myId = ref.read(supabaseProvider).auth.currentUser?.id;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.blue,
        appBar: AppBar(
          backgroundColor: Colors.blue,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              GestureDetector(
                onTap: () {
                  context.push('/userProfile', extra: otherUserId);
                },
                child: CircleAvatar(
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
          actions: [
            if (roomId != null)
              IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () {
                  final otherUser = Users(
                    id: otherUserId,
                    name: otherUserName,
                    trophy: 0,
                    avatar_url: otherUserAvatar,
                  );
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, _, __) => IosSwipeBack(
                        child: DmMenuView(roomId: roomId, otherUser: otherUser),
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
          ],
        ),
        body: roomIdAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (err, stack) {
            // ブロックされている場合は専用メッセージを表示
            if (err.toString().contains('BLOCKED')) {
              return Center(
                child: Text(
                  blockedByThem ? 'ブロックされてます' : 'ブロックしてます',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }
            return Center(
              child: Text(
                'エラー: $err',
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
          data: (rId) {
            final resbasAsync = ref.watch(dmResbaProvider(rId));
            final resbas = resbasAsync.valueOrNull ?? const <ResbaInvite>[];
            return Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.blue,
                    child: messagesAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      error: (err, stack) => Center(
                        child: Text(
                          'エラー: $err',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      data: (rawMessages) {
                        // 非表示にしたメッセージは一覧から除外する
                        // (アイコン・名前の表示判定も「表示中のメッセージ」基準にするため、
                        //  非表示1件を挟んだ隣接メッセージにも正しくアイコンが出る)
                        final messages = rawMessages
                            .where(
                              (m) => !hiddenMessageIds.value.contains(m.id),
                            )
                            .toList();
                        if (messages.isEmpty) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'まだメッセージはありません',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          reverse: true,
                          itemCount: messages.length,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final isMe = msg.senderId == myId;

                            final isSending = msg.id.startsWith('temp_');

                            // アバター表示ロジック：相手の発言かつ、一つ前（古い方）の送信者と異なる場合に表示
                            final showAvatar =
                                !isMe &&
                                (index == messages.length - 1 ||
                                    messages[index + 1].senderId !=
                                        msg.senderId);

                            // このメッセージに付いたレスバ（アクティブのみ）
                            // 終了(finished)も残して観戦ログを見られるようにする（掲示板・オプチャと同じ）
                            final msgResbas = resbas
                                .where(
                                  (r) =>
                                      r.attachType == 'dm' &&
                                      r.attachId == msg.id &&
                                      (r.isPending ||
                                          r.isAccepted ||
                                          r.status == 'finished'),
                                )
                                .toList();

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
                                        onChanged: () {
                                          ref.invalidate(dmResbaProvider(rId));
                                        },
                                      ),
                                    ),
                                ],
                              );
                            }

                            return Opacity(
                              opacity: isSending ? 0.6 : 1.0,
                              child: ChatMessageBubble(
                                id: msg.id,
                                content: msg.content,
                                imageUrl: msg.imageUrl,
                                isUserMessage: isMe,
                                senderId: isMe ? myId : otherUserId,
                                senderName: isMe ? 'あなた' : otherUserName,
                                senderAvatarUrl: isMe ? null : otherUserAvatar,
                                showAvatar: showAvatar,
                                showSenderName: !isMe,
                                replyToId: msg.replyToId,
                                replyToContent: msg.replyToContent,
                                replyToUserName: msg.replyToUserName,
                                onReply: () {
                                  replyTarget.value = msg;
                                },
                                onTapReplyQuote: msg.replyToId != null
                                    ? () => jumpToMessage(
                                        msg.replyToId!,
                                        messages,
                                      )
                                    : null,
                                isHighlighted: highlightedDmId.value == msg.id,
                                statusWidget: isMe
                                    ? _buildStatus(msg.id)
                                    : null,
                                timeLabel: DateFormatter.formatChatTime(
                                  msg.createdAt,
                                ),
                                attachedWidget: attachedWidget,
                                onHide: () => hideDmMessage(msg.id),
                                onReport: () async {
                                  await showReportDialog(
                                    context: context,
                                    ref: ref,
                                    opponentId: msg.senderId,
                                    contentId: msg.id,
                                    contentType: 'dm_message',
                                    contentSnapshot: msg.imageUrl != null
                                        ? '[画像]'
                                        : msg.content,
                                  );
                                },
                                onDelete: isMe
                                    ? () async {
                                        hideDmMessage(msg.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('メッセージを削除しました'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Text(
                      blockedByThem ? 'ブロックされてます' : 'ブロックしてます',
                      style: AppTextStyles.notoSans(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!isBlocked)
                  _MessageInputWidget(
                    roomId: rId,
                    replyTarget: replyTarget,
                    otherUserName: otherUserName,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatus(String messageId) {
    String statusText;
    Color statusColor = Colors.white70;

    if (messageId.startsWith('temp_')) {
      statusText = '送信中';
      statusColor = Colors.white60;
    } else if (messageId.startsWith('error_')) {
      statusText = '✕';
      statusColor = Colors.redAccent;
    } else {
      statusText = '送信';
    }

    return Text(
      statusText,
      style: AppTextStyles.notoSans(fontSize: 9, color: statusColor),
    );
  }
}

class _MessageInputWidget extends HookConsumerWidget {
  final String roomId;
  final ValueNotifier<DmMessage?> replyTarget;
  final String otherUserName;

  const _MessageInputWidget({
    required this.roomId,
    required this.replyTarget,
    required this.otherUserName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageController = useTextEditingController();
    final selectedImage = useState<File?>(null);
    final isUploading = useState(false);
    final resbaAttachment = useState<ResbaAttachment?>(null);
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;

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

        final target = replyTarget.value;
        final targetUserName = target == null
            ? null
            : (target.senderId == myId ? 'あなた' : otherUserName);

        String? messageId;
        if (uploadedUrl != null && sendText.isNotEmpty) {
          // 画像とテキストの両方がある場合は2通に分けて送信（オプチャと同じ仕様）
          await ref
              .read(dmMessagesProvider(roomId).notifier)
              .sendMessage('', imageUrl: uploadedUrl);
          messageId = await ref
              .read(dmMessagesProvider(roomId).notifier)
              .sendMessage(
                sendText,
                replyToId: target?.id,
                replyToContent: target?.content,
                replyToUserName: targetUserName,
              );
        } else if (uploadedUrl != null) {
          // 画像単体
          messageId = await ref
              .read(dmMessagesProvider(roomId).notifier)
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
              .read(dmMessagesProvider(roomId).notifier)
              .sendMessage(
                sendText,
                replyToId: target?.id,
                replyToContent: target?.content,
                replyToUserName: targetUserName,
              );
        } else if (resbaAttachment.value != null) {
          // ⚔️ レスバ単体（テキストも画像もない場合）
          messageId = await ref
              .read(dmMessagesProvider(roomId).notifier)
              .sendMessage(
                '',
                replyToId: target?.id,
                replyToContent: target?.content,
                replyToUserName: targetUserName,
              );
        }

        // レスバ（写真）を送る感覚でレスバを添付
        final attachment = resbaAttachment.value;
        if (attachment != null && messageId != null) {
          final result = await ref
              .read(resbaActionsProvider)
              .sendDmResba(
                messageId: messageId,
                theme: attachment.theme,
                choice1: attachment.choice1,
                choice2: attachment.choice2,
              );
          if (result.error != null && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(result.error!)));
          }
          ref.invalidate(dmResbaProvider(roomId));
        }

        replyTarget.value = null;
        messageController.clear();
        selectedImage.value = null;
        resbaAttachment.value = null;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('送信エラー: $e')));
        }
      } finally {
        isUploading.value = false;
      }
    }

    return Container(
      decoration: const BoxDecoration(color: Colors.white),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Color(0xFF4F46E5)),
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
                            text: replyTarget.value!.senderId == myId
                                ? '自分'
                                : otherUserName,
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
                      child: Icon(Icons.close, size: 16, color: Colors.black54),
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
                // ⚔️ レスバ（写真）を送る
                IconButton(
                  icon: const Text(
                    '⚔️',
                    style: TextStyle(fontSize: 20, color: Color(0xFF7856FF)),
                  ),
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
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'メッセージを入力',
                        counterText: '',
                        hintStyle: AppTextStyles.notoSans(
                          color: Colors.grey[400],
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      onSubmitted: isUploading.value
                          ? null
                          : (_) => sendMessage(),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.blue, size: 24),
                  onPressed: isUploading.value ? null : sendMessage,
                ),
              ],
            ),
          ),
          if (selectedImage.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 48.0, bottom: 8.0),
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
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (resbaAttachment.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 48.0, bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey,
                      ),
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
