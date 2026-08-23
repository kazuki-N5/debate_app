import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'package:debate_project/provider/bbs_timeline_provider.dart';
import 'package:debate_project/provider/image_upload_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/resba_attach_sheet.dart';

class BbsPostCreateView extends StatefulHookConsumerWidget {
  const BbsPostCreateView({super.key});

  @override
  ConsumerState<BbsPostCreateView> createState() => _BbsPostCreateViewState();
}

class _BbsPostCreateViewState extends ConsumerState<BbsPostCreateView> {
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  List<File> selectedImages = [];
  bool isUploading = false;
  ResbaAttachment? resbaAttachment; // ⚔️ レスバ添付（写真を付けるのと同じ感覚）

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final content = textController.text;
    if (content.trim().isEmpty && selectedImages.isEmpty) return;

    setState(() {
      isUploading = true;
    });

    try {
      List<String> imageUrls = [];
      if (selectedImages.isNotEmpty) {
        final uploader = ref.read(imageUploadProvider);
        imageUrls = await uploader.uploadMultiImages(
          files: selectedImages,
          bucketName: 'bbs_images',
          folderName: 'posts',
        );
      }

      final postId = await ref.read(bbsTimelineProvider.notifier).addPost(content, imageUrls: imageUrls);
      debugPrint('[RESBA_UI_LOG] [CreatePost] Created post id: $postId');

      // レスバを付ける（ポストにレスバが付く）
      final attachment = resbaAttachment;
      if (attachment != null && postId != null) {
        debugPrint('[RESBA_UI_LOG] [CreatePost] Attaching resba: theme=${attachment.theme}, choice1=${attachment.choice1}, choice2=${attachment.choice2}');
        final result = await ref.read(resbaActionsProvider).createPostResba(
              postId: postId,
              theme: attachment.theme,
              choice1: attachment.choice1,
              choice2: attachment.choice2,
            );
        debugPrint('[RESBA_UI_LOG] [CreatePost] createPostResba result: error=${result.error}, roomId=${result.roomId}');
        if (result.error != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
        } else {
          // タイムラインの「レスバ付き」バッジを即時反映（再ロード不要にする）
          ref.read(bbsTimelineProvider.notifier).markPostHasResba(postId);
        }
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('投稿に失敗しました: $e')));
      }
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: isUploading ? null : () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {}, // ダミー
            child: const Text('下書き', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              onPressed: isUploading ? null : _post,
              child: isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('ポストする', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final user = ref.watch(userProvider);
                        final avatarUrl = user.avatar_url;
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Icon(Icons.person, color: Colors.grey[600])
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: textController,
                            focusNode: focusNode,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'いまどうしてる？',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (selectedImages.isNotEmpty) ...[
                            _buildSelectedImagesGrid(selectedImages, (file) {
                              setState(() => selectedImages.remove(file));
                            }),
                          ],

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            if (resbaAttachment != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                          'レスバ: ${resbaAttachment!.theme}',
                          style: AppTextStyles.bold(fontSize: 12.5, color: const Color(0xFF7856FF)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => resbaAttachment = null),
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: Colors.lightBlue),
                    onPressed: selectedImages.length >= 4 ? null : () async {
                      final picker = ref.read(imageUploadProvider);
                      final images = await picker.pickMultiImage(maxImages: 4 - selectedImages.length);
                      if (images.isNotEmpty) {
                        setState(() {
                          selectedImages.addAll(images);
                        });
                      }
                    },
                  ),
                  // ⚔️ レスバを付ける（写真を付けるのと同じ操作感）
                  IconButton(
                    icon: const Text('⚔️', style: TextStyle(fontSize: 22, color: Color(0xFF7856FF))),
                    onPressed: isUploading ? null : () async {
                      final attachment = await showResbaAttachSheet(
                        context,
                        presetTheme: textController.text.trim(),
                      );
                      if (attachment != null) {
                        setState(() => resbaAttachment = attachment);
                      }
                    },
                  ),
                  const Spacer(),
                  if (selectedImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text('${selectedImages.length}/4枚', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  const Icon(Icons.add_circle, color: Colors.lightBlue),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSelectedImagesGrid(List<File> images, Function(File) onRemove) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: images.length == 1 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: images.length == 1 ? 1.5 : 1.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final file = images[index];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(file, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: GestureDetector(
                onTap: () => onRemove(file),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
