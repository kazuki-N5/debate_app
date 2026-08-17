import 'dart:io';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/dm_provider.dart';
import 'package:debate_project/provider/image_upload_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/widgets/full_screen_image_viewer.dart';

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
        error: (err, stack) => Center(child: Text('エラー: $err')),
        data: (rId) {
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
                        
                        // temp_, sent_ の場合は少し色を薄くするなど工夫も可能
                        final isSending = msg.id.startsWith('temp_');

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Opacity(
                            opacity: isSending ? 0.6 : 1.0,
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
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              _MessageInputWidget(roomId: roomId!),
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

    void sendMessage() async {
      final text = messageController.text.trim();
      if (text.isEmpty && selectedImage.value == null) return;

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
        ref.read(dmMessagesProvider(roomId).notifier).sendMessage(text, imageUrl: uploadedUrl);
        
        messageController.clear();
        selectedImage.value = null;
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
          ],
        ),
      ),
    );
  }
}
