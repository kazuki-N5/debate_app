import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/image_upload_provider.dart';
import 'package:debate_project/views/open_chat/OpenChatMembersView.dart';
import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/view_model/prohibited_view_model.dart'; // MessageBubble

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

    useEffect(() {
      void scrollListener() {
        if (scrollController.position.pixels <= scrollController.position.minScrollExtent) {
          // 一番上（過去）にスクロールした時
          ref.read(openChatMessagesProvider(room.id).notifier).loadMore();
        }
      }
      scrollController.addListener(scrollListener);
      return () => scrollController.removeListener(scrollListener);
    }, [scrollController]);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(room.name, style: AppTextStyles.bold(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'members') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OpenChatMembersView(room: room)),
                );
              } else if (value == 'leave') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('退室の確認'),
                    content: const Text('このオープンチャットから退室しますか？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('退室する', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                
                if (confirm == true && context.mounted) {
                  final error = await ref.read(openChatActionProvider.notifier).leaveRoom(room.id);
                  if (error == null) {
                    if (context.mounted) {
                      Navigator.pop(context); // チャット画面を閉じる
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('退室しました')));
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $error')));
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'members',
                child: Row(children: [Icon(Icons.people, color: Colors.black87), SizedBox(width: 8), Text('メンバー管理')]),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: Row(children: [Icon(Icons.exit_to_app, color: Colors.red), SizedBox(width: 8), Text('退室する', style: TextStyle(color: Colors.red))]),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(child: Text('まだメッセージはありません', style: AppTextStyles.notoSans(color: Colors.grey)));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    reverse: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isUserMessage = message.userId == currentUserId;
                      
                      final chat = Chat(
                        id: message.id,
                        roomId: message.roomId,
                        senderId: message.userId,
                        content: message.content,
                        createdAt: message.createdAt,
                        imageUrl: message.imageUrl,
                      );

                      // アバター表示ロジック：相手の発言かつ、一つ前（古い方）の送信者と異なる場合に表示
                      bool showAvatar = !isUserMessage &&
                          (index == 0 || messages[index - 1].userId != message.userId);

                      return MessageBubble(
                        chat: chat,
                        isUserMessage: isUserMessage,
                        opponentAvatarUrl: null, // 今回はアバター表示を簡易化
                        myAvatarUrl: null,
                        showAvatar: showAvatar,
                        roomId: room.id,
                        onHide: () {}, // 非表示処理が必要な場合は実装
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('エラー: $error')),
              ),
            ),
            // 入力エリア
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, offset: Offset(0, -1), blurRadius: 4),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            focusNode: textFieldFocusNode,
                            controller: textController,
                            maxLength: 50,
                            style: AppTextStyles.notoSans(color: Colors.black, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'メッセージを入力',
                              counterText: '',
                              hintStyle: AppTextStyles.notoSans(color: Colors.grey[400]),
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
                      const SizedBox(width: 4),
                      Transform.translate(
                        offset: const Offset(4, 0),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: textController,
                          builder: (context, value, child) {
                            final remaining = 50 - value.text.length;
                            return Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                '$remaining',
                                style: AppTextStyles.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: remaining <= 0 ? Colors.red : Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        onPressed: isUploading.value ? null : () async {
                          if (textController.text.trim().isNotEmpty || selectedImage.value != null) {
                            isUploading.value = true;
                            try {
                              String? uploadedUrl;
                              if (selectedImage.value != null) {
                                final uploader = ref.read(imageUploadProvider);
                                uploadedUrl = await uploader.uploadImage(
                                  file: selectedImage.value!,
                                  bucketName: 'chat_images',
                                  folderName: 'open_chat',
                                );
                              }

                              await ref.read(openChatActionProvider.notifier).sendMessage(
                                    room.id,
                                    textController.text.trim(),
                                    imageUrl: uploadedUrl,
                                  );
                              textController.clear();
                              selectedImage.value = null;
                              if (scrollController.hasClients) {
                                scrollController.animateTo(
                                  scrollController.position.maxScrollExtent + 100, // 末尾へスクロール
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('送信エラー: $e')));
                            } finally {
                              isUploading.value = false;
                            }
                          }
                        },
                        icon: isUploading.value
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.blue, size: 24),
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
          ],
        ),
      ),
    );
  }
}
