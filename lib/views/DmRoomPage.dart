import 'dart:io';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/dm_provider.dart';
import 'package:debate_project/provider/image_upload_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/view_model/prohibited_view_model.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/moderation.dart';
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
    final messagesAsync = roomId != null ? ref.watch(dmMessagesProvider(roomId)) : const AsyncValue.loading();

    // 過去メッセージの読み込みトリガー
    useEffect(() {
      void scrollListener() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent) {
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
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: otherUserAvatar != null && otherUserAvatar!.isNotEmpty
                  ? NetworkImage(otherUserAvatar!)
                  : null,
              child: otherUserAvatar == null || otherUserAvatar!.isEmpty
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(otherUserName),
          ],
        ),
      ),
      body: roomIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          // ブロックされている場合は専用メッセージを表示
          if (err.toString().contains('BLOCKED')) {
            return Center(
              child: Text(
                blockedByThem
                    ? 'ブロックされているためDMを開始できません'
                    : 'ブロックしたユーザーとのDMは開始できません',
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }
          return Center(child: Text('エラー: $err'));
        },
        data: (rId) {
          final resbasAsync = ref.watch(dmResbaProvider(rId));
          final resbas = resbasAsync.valueOrNull ?? const <ResbaInvite>[];
          return Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('エラー: $err')),
                  data: (messages) {
                    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
                    if (messages.isEmpty) {
                      return const Center(child: Text('まだメッセージはありません'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == myId;

                        // 非表示にしたメッセージは表示しない
                        if (hiddenMessageIds.value.contains(msg.id)) {
                          return const SizedBox.shrink();
                        }
                        
                        // temp_, sent_ の場合は少し色を薄くするなど工夫も可能
                        final isSending = msg.id.startsWith('temp_');

                        // このメッセージに付いたレスバ（アクティブのみ）
                        final msgResbas = resbas
                            .where((r) =>
                                r.attachType == 'dm' &&
                                r.attachId == msg.id &&
                                (r.isPending || r.isAccepted))
                            .toList();

                        return Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Opacity(
                                opacity: isSending ? 0.6 : 1.0,
                                child: GestureDetector(
                                  // 相手のメッセージを長押しで通報/非表示/ブロック
                                  onLongPress: isMe
                                      ? null
                                      : () {
                                          showCustomPopover(
                                            context: context,
                                            height: 130,
                                            arrowDxOffset: 0,
                                            children: [
                                              PopoverButton(
                                                text: '通報',
                                                onTap: () async {
                                                  Navigator.of(context).pop();
                                                  await showReportDialog(
                                                    context: context,
                                                    ref: ref,
                                                    opponentId: msg.senderId,
                                                    contentId: msg.id,
                                                    contentType: 'dm_message',
                                                    contentSnapshot: msg.content,
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 4),
                                              PopoverButton(
                                                text: '非表示',
                                                onTap: () {
                                                  Navigator.of(context).pop();
                                                  hideDmMessage(msg.id);
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
                                                    targetUserId: msg.senderId,
                                                    targetName: otherUserName,
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.blueAccent : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (msg.imageUrl != null)
                                          Padding(
                                            padding: EdgeInsets.only(bottom: msg.content.isNotEmpty ? 4.0 : 0.0),
                                            child: GestureDetector(
                                              // タップで画像を拡大表示
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => FullScreenImageViewer(
                                                      imageUrls: [msg.imageUrl!],
                                                      initialIndex: 0,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: msg.imageUrl!,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 900, // 表示サイズでデコードしてカクつきを抑える
                                                  fadeInDuration: Duration.zero, // ふわ〜っと出るフェードを無効化してパッと表示
                                                  fadeOutDuration: Duration.zero,
                                                  placeholder: (context, url) => Container(height: 150, color: Colors.grey[300]),
                                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (msg.content.isNotEmpty)
                                          Text(
                                            msg.content,
                                            style: TextStyle(
                                              color: isMe ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        if (msgResbas.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                ResbaBadge(text: 'レスバ'),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // レスバカード（承諾/拒否・相手待ち表示）
                            for (final invite in msgResbas)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: ResbaCard(
                                  invite: invite,
                                  onChanged: () {
                                    ref.invalidate(dmResbaProvider(rId));
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              if (isBlocked)
                Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    blockedByThem
                        ? 'ブロックされているためDMを送信できません'
                        : 'ブロックしたユーザーです。DMを送信できません',
                    style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 12),
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
      if (text.isEmpty && selectedImage.value == null && resbaAttachment.value == null) return;

      isUploading.value = true;
      try {
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
        final messageId = await ref.read(dmMessagesProvider(roomId).notifier).sendMessage(text, imageUrl: uploadedUrl);

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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
          }
          ref.invalidate(dmResbaProvider(roomId));
        }

        messageController.clear();
        selectedImage.value = null;
        resbaAttachment.value = null;
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('送信エラー: $e')));
      } finally {
        isUploading.value = false;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.grey),
                  onPressed: isUploading.value ? null : () async {
                    final picker = ref.read(imageUploadProvider);
                    final image = await picker.pickImage();
                    if (image != null) {
                      selectedImage.value = image;
                    }
                  },
                ),
                // ⚔️ レスバ（写真）を送る
                IconButton(
                  icon: const Text('⚔️', style: TextStyle(fontSize: 20, color: Color(0xFF7856FF))),
                  onPressed: isUploading.value ? null : () async {
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
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: isUploading.value ? null : (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: isUploading.value
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: isUploading.value ? null : sendMessage,
                ),
              ],
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
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
