import 'dart:io';
import 'package:debate_project/modes/bbs_comment.dart';
import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/provider/bbs_comment_provider.dart';
import 'package:debate_project/provider/bbs_timeline_provider.dart';
import 'package:debate_project/provider/image_upload_provider.dart';
import 'package:debate_project/views/bbs/BbsTimelineView.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:debate_project/views/UserProfilePage.dart';
import 'package:debate_project/utils/mention_text_editing_controller.dart';
import 'package:debate_project/widgets/mention_text.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BbsPostDetailView extends HookConsumerWidget {
  final BbsPost post;

  const BbsPostDetailView({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(bbsTimelineProvider);
    final currentPost = postsAsync.maybeWhen(
      data: (posts) => posts.firstWhere((p) => p.id == post.id, orElse: () => post),
      orElse: () => post,
    );
    final commentsAsync = ref.watch(bbsCommentProvider(post.id));
    
    final commentController = useMemoized(() => MentionTextEditingController());
    useEffect(() {
      return () => commentController.dispose();
    }, const []);
    
    final focusNode = useFocusNode();
    
    // 返信先のコメントIDを保持するステート
    final replyingToCommentId = useState<String?>(null);
    final replyingToUserName = useState<String?>(null);
    
    // 画像選択用のステート
    final selectedImage = useState<File?>(null);
    final isUploading = useState(false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('投稿', style: AppTextStyles.bold(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(bbsTimelineProvider.notifier).fetchPosts();
                await ref.read(bbsCommentProvider(post.id).notifier).fetchComments();
              },
              child: ListView(
                children: [
                  // 親の投稿
                  BbsPostWidget(post: currentPost),
                  const Divider(height: 1),
                  // コメント欄のヘッダー
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('コメント', style: AppTextStyles.bold(fontSize: 16)),
                        Text('新着', style: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // コメント一覧
                  commentsAsync.when(
                    data: (comments) {
                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text('まだコメントがありません', style: AppTextStyles.notoSans(color: Colors.grey)),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildCommentThread(
                            context, 
                            ref, 
                            comments[index], 
                            replyingToCommentId, 
                            replyingToUserName,
                            (String commentId, String userName, bool useMention) {
                              replyingToCommentId.value = commentId;
                              replyingToUserName.value = userName;
                              if (useMention) {
                                final mention = '@$userName ';
                                commentController.text = mention;
                                commentController.selection = TextSelection.fromPosition(TextPosition(offset: commentController.text.length));
                              } else {
                                commentController.clear();
                              }
                              focusNode.requestFocus();
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, st) => Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(child: Text('エラー: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 入力フォーム
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyingToUserName.value != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                      child: Row(
                        children: [
                          Text('返信先: ${replyingToUserName.value}', style: AppTextStyles.notoSans(color: Colors.blueAccent, fontSize: 13)),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              replyingToCommentId.value = null;
                              replyingToUserName.value = null;
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(Icons.close, size: 16, color: Colors.grey),
                            ),
                          )
                        ],
                      ),
                    ),
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
                            focusNode: focusNode,
                            controller: commentController,
                            maxLength: 200,
                            textAlignVertical: TextAlignVertical.center,
                            style: AppTextStyles.notoSans(color: Colors.black, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'すてきなコメントを残そう！',
                              counterText: '',
                              hintStyle: AppTextStyles.notoSans(color: Colors.grey[400]),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          valueListenable: commentController,
                          builder: (context, value, child) {
                            final remaining = 200 - value.text.length;
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
                          final text = commentController.text;
                          if (text.trim().isEmpty && selectedImage.value == null) return;
                          
                          isUploading.value = true;
                          try {
                            String? uploadedUrl;
                            if (selectedImage.value != null) {
                              final uploader = ref.read(imageUploadProvider);
                              uploadedUrl = await uploader.uploadImage(
                                file: selectedImage.value!,
                                bucketName: 'bbs_images',
                                folderName: 'comments',
                              );
                            }

                            await ref.read(bbsCommentProvider(post.id).notifier).addComment(text, parentCommentId: replyingToCommentId.value, imageUrl: uploadedUrl);
                            commentController.clear();
                            replyingToCommentId.value = null;
                            replyingToUserName.value = null;
                            selectedImage.value = null;
                            if (!context.mounted) return;
                            focusNode.unfocus(); // キーボードを閉じる
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('送信失敗: $e')));
                          } finally {
                            isUploading.value = false;
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
          ),
        ],
      ),
    );
  }

  Widget _buildCommentThread(
    BuildContext context, 
    WidgetRef ref, 
    BbsComment comment, 
    ValueNotifier<String?> replyingToCommentId, 
    ValueNotifier<String?> replyingToUserName,
    Function(String, String, bool) onReplyTap,
  ) {
    return _CommentThreadWidget(
      post: post,
      comment: comment,
      replyingToCommentId: replyingToCommentId,
      replyingToUserName: replyingToUserName,
      onReplyTap: onReplyTap,
    );
  }
}

class _CommentThreadWidget extends HookConsumerWidget {
  final BbsPost post;
  final BbsComment comment;
  final ValueNotifier<String?> replyingToCommentId;
  final ValueNotifier<String?> replyingToUserName;
  final Function(String, String, bool) onReplyTap;

  const _CommentThreadWidget({
    required this.post,
    required this.comment,
    required this.replyingToCommentId,
    required this.replyingToUserName,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = useState(false);
    final user = comment.user;
    final userName = user?.name ?? '名無し';
    final userAvatar = user?.avatar_url;
    final dateStr = DateFormatter.formatBbsDate(comment.createdAt);
    
    // 投稿主かどうか
    final isOwner = comment.userId == post.userId;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfilePage(userId: comment.userId),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                      // 表示サイズ(radius18=36px)に縮小デコードしてカクつきを抑える
                      ? ResizeImage(NetworkImage(userAvatar), width: 108)
                      : null,
                  child: userAvatar == null || userAvatar.isEmpty ? const Icon(Icons.person) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(userName, style: AppTextStyles.bold(fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        Text('・ $dateStr', style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey)),
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('投稿主', style: AppTextStyles.notoSans(fontSize: 10, color: Colors.deepOrange)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (comment.content.isNotEmpty)
                      MentionText(text: comment.content, style: AppTextStyles.notoSans(fontSize: 14, color: Colors.black87)),
                    if (comment.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      _ReplyImageToggle(imageUrl: comment.imageUrl!),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            ref.read(bbsCommentProvider(post.id).notifier).toggleLike(comment);
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, 1),
                                child: comment.isLikedByMe
                                    ? const Icon(CupertinoIcons.heart_fill, color: Colors.pink, size: 14)
                                    : SvgPicture.asset(
                                        'assets/images/icons/tweeticon/heart.svg',
                                        width: 14,
                                        height: 14,
                                        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                                      ),
                              ),
                              const SizedBox(width: 4),
                              Text('${comment.likesCount}', style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13, height: 1.1)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            onReplyTap(comment.id, userName, false);
                          },
                          child: Text('返信', style: AppTextStyles.bold(fontSize: 12, color: Colors.grey, height: 1.1)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 返信の表示トグルボタン
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, top: 8.0),
              child: InkWell(
                onTap: () {
                  isExpanded.value = !isExpanded.value;
                },
                child: Row(
                  children: [
                    Icon(
                      isExpanded.value ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.replies.length}件の返信を表示',
                      style: AppTextStyles.bold(fontSize: 13, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            ),
          // 返信の表示（リスト展開時のみ）
          if (comment.replies.isNotEmpty && isExpanded.value)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, top: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comment.replies.map((reply) {
                  final rUser = reply.user;
                  final rUserName = rUser?.name ?? '名無し';
                  final rUserAvatar = rUser?.avatar_url;
                  final rDateStr = DateFormatter.formatBbsDate(reply.createdAt);
                  final rIsOwner = reply.userId == post.userId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfilePage(userId: reply.userId),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 12,
                            backgroundImage: rUserAvatar != null && rUserAvatar.isNotEmpty
                                // 表示サイズ(radius12=24px)に縮小デコードしてカクつきを抑える
                                ? ResizeImage(NetworkImage(rUserAvatar), width: 72)
                                : null,
                            child: rUserAvatar == null || rUserAvatar.isEmpty ? const Icon(Icons.person, size: 14) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(rUserName, style: AppTextStyles.bold(fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('・ $rDateStr', style: AppTextStyles.notoSans(fontSize: 11, color: Colors.grey)),
                                  if (rIsOwner) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('投稿主', style: AppTextStyles.notoSans(fontSize: 9, color: Colors.deepOrange)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (reply.content.isNotEmpty)
                                MentionText(text: reply.content, style: AppTextStyles.notoSans(fontSize: 13, color: Colors.black87)),
                              if (reply.imageUrl != null) ...[
                                const SizedBox(height: 8),
                                _ReplyImageToggle(imageUrl: reply.imageUrl!),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      ref.read(bbsCommentProvider(post.id).notifier).toggleLike(reply);
                                    },
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Transform.translate(
                                          offset: const Offset(0, 1),
                                          child: reply.isLikedByMe
                                              ? const Icon(CupertinoIcons.heart_fill, color: Colors.pink, size: 14)
                                              : SvgPicture.asset(
                                                  'assets/images/icons/tweeticon/heart.svg',
                                                  width: 14,
                                                  height: 14,
                                                  colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                                                ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text('${reply.likesCount}', style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13, height: 1.1)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  InkWell(
                                    onTap: () {
                                      onReplyTap(reply.id, rUserName, true);
                                    },
                                    child: Text('返信', style: AppTextStyles.bold(fontSize: 12, color: Colors.grey, height: 1.0)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyImageToggle extends StatefulWidget {
  final String imageUrl;

  const _ReplyImageToggle({required this.imageUrl});

  @override
  State<_ReplyImageToggle> createState() => _ReplyImageToggleState();
}

class _ReplyImageToggleState extends State<_ReplyImageToggle> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
        onTap: () {
          setState(() {
            _isVisible = !_isVisible;
          });
        },
        child: Text(
          _isVisible ? '写真を閉じる' : '写真を見る',
          style: AppTextStyles.notoSans(
            fontSize: 12,
            color: Colors.blueAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
        ),
        if (_isVisible) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 800, // 表示サイズでデコードしてカクつきを抑える
              fadeInDuration: Duration.zero, // ふわ〜っと出るフェードを無効化してパッと表示
              fadeOutDuration: Duration.zero,
              placeholder: (context, url) => Container(
                height: 100,
                color: Colors.grey[300],
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ],
      ],
    );
  }
}
