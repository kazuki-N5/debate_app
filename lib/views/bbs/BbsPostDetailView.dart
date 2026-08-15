import 'package:debate_project/modes/bbs_comment.dart';
import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/provider/bbs_comment_provider.dart';
import 'package:debate_project/provider/bbs_timeline_provider.dart';
import 'package:debate_project/views/bbs/BbsTimelineView.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class BbsPostDetailView extends HookConsumerWidget {
  final BbsPost post;

  const BbsPostDetailView({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(bbsCommentProvider(post.id));
    final commentController = useTextEditingController();
    
    // 返信先のコメントIDを保持するステート
    final replyingToCommentId = useState<String?>(null);
    final replyingToUserName = useState<String?>(null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('投稿', style: AppTextStyles.bold(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
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
                  BbsPostWidget(post: post),
                  Container(height: 8, color: Colors.grey[200]),
                  // コメント欄のヘッダー
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('コメント', style: AppTextStyles.bold(fontSize: 16)),
                        Text('注目 | 新着', style: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey)),
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
                          return _buildCommentThread(context, ref, comments[index], replyingToCommentId, replyingToUserName);
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Text('返信先: ${replyingToUserName.value}', style: AppTextStyles.notoSans(color: Colors.blueAccent, fontSize: 13)),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              replyingToCommentId.value = null;
                              replyingToUserName.value = null;
                            },
                            child: const Icon(Icons.close, size: 16, color: Colors.grey),
                          )
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: commentController,
                            decoration: const InputDecoration(
                              hintText: 'すてきなコメントを残そう！',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final text = commentController.text;
                          if (text.trim().isEmpty) return;
                          
                          try {
                            await ref.read(bbsCommentProvider(post.id).notifier).addComment(text, parentCommentId: replyingToCommentId.value);
                            commentController.clear();
                            replyingToCommentId.value = null;
                            replyingToUserName.value = null;
                            FocusScope.of(context).unfocus(); // キーボードを閉じる
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('送信失敗: $e')));
                          }
                        },
                        child: Text('送る', style: AppTextStyles.bold(color: Colors.blueAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentThread(BuildContext context, WidgetRef ref, BbsComment comment, ValueNotifier<String?> replyingToCommentId, ValueNotifier<String?> replyingToUserName) {
    final user = comment.user;
    final userName = user?.name ?? '名無し';
    final userAvatar = user?.avatar_url;
    final dateStr = '${comment.createdAt.month.toString().padLeft(2, '0')}/${comment.createdAt.day.toString().padLeft(2, '0')}';
    
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
              CircleAvatar(
                backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                child: userAvatar == null || userAvatar.isEmpty ? const Icon(Icons.person) : null,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(userName, style: AppTextStyles.bold(fontSize: 14, color: Colors.black87)),
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
                    Text(comment.content, style: AppTextStyles.notoSans(fontSize: 14)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(dateStr, style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () {
                            replyingToCommentId.value = comment.id;
                            replyingToUserName.value = userName;
                          },
                          child: Text('返信', style: AppTextStyles.bold(fontSize: 12, color: Colors.grey)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  ref.read(bbsCommentProvider(post.id).notifier).toggleLike(comment);
                },
                child: Row(
                  children: [
                    Text('${comment.likesCount > 0 ? comment.likesCount : ""}', style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13)),
                    const SizedBox(width: 4),
                    Icon(
                      comment.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                      color: comment.isLikedByMe ? Colors.pink : Colors.grey,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 返信の表示
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, top: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comment.replies.map((reply) {
                  final rUser = reply.user;
                  final rUserName = rUser?.name ?? '名無し';
                  final rUserAvatar = rUser?.avatar_url;
                  final rDateStr = '${reply.createdAt.month.toString().padLeft(2, '0')}/${reply.createdAt.day.toString().padLeft(2, '0')}';
                  final rIsOwner = reply.userId == post.userId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundImage: rUserAvatar != null && rUserAvatar.isNotEmpty ? NetworkImage(rUserAvatar) : null,
                          child: rUserAvatar == null || rUserAvatar.isEmpty ? const Icon(Icons.person, size: 14) : null,
                          radius: 12,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(rUserName, style: AppTextStyles.bold(fontSize: 13, color: Colors.black87)),
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
                              Text(reply.content, style: AppTextStyles.notoSans(fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(rDateStr, style: AppTextStyles.notoSans(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            ref.read(bbsCommentProvider(post.id).notifier).toggleLike(reply);
                          },
                          child: Row(
                            children: [
                              Text('${reply.likesCount > 0 ? reply.likesCount : ""}', style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13)),
                              const SizedBox(width: 4),
                              Icon(
                                reply.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                                color: reply.isLikedByMe ? Colors.pink : Colors.grey,
                                size: 14,
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
