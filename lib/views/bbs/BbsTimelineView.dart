import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/provider/bbs_timeline_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/views/bbs/BbsPostDetailView.dart';

class BbsTimelineView extends HookConsumerWidget {
  const BbsTimelineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(bbsTimelineProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: timelineAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'まだ投稿がありません',
                style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 16),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(bbsTimelineProvider.notifier).fetchPosts(),
            child: ListView.separated(
              itemCount: posts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final post = posts[index];
                return BbsPostWidget(post: post);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラーが発生しました: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreatePostDialog(context, ref);
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('新規投稿', style: AppTextStyles.bold(fontSize: 18)),
          content: TextField(
            controller: textController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'いまどうしてる？',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                final content = textController.text;
                if (content.trim().isEmpty) return;
                Navigator.pop(context);
                try {
                  await ref.read(bbsTimelineProvider.notifier).addPost(content);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('投稿に失敗しました: $e')));
                  }
                }
              },
              child: const Text('投稿する', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class BbsPostWidget extends ConsumerWidget {
  final BbsPost post;
  
  const BbsPostWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = post.user;
    final userName = user?.name ?? '名無し';
    final userAvatar = user?.avatar_url;

    // mm/dd hh:mm の形式にする簡易フォーマット
    final dateStr = '${post.createdAt.month.toString().padLeft(2, '0')}/${post.createdAt.day.toString().padLeft(2, '0')} ${post.createdAt.hour.toString().padLeft(2, '0')}:${post.createdAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () {
        // 詳細画面へ遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BbsPostDetailView(post: post),
          ),
        );
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: アイコン、名前、日時
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                  child: userAvatar == null || userAvatar.isEmpty ? const Icon(Icons.person) : null,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: AppTextStyles.bold(fontSize: 16)),
                      Text(dateStr, style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 本文
            Text(
              post.content,
              style: AppTextStyles.notoSans(fontSize: 15),
            ),
            const SizedBox(height: 16),
            // アクションボタン群 (ブックマーク、コメント、いいね、シェア)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark_border, color: Colors.grey, size: 20),
                    const SizedBox(width: 4),
                    Text('0', style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
                    const SizedBox(width: 4),
                    Text('${post.repliesCount}', style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                InkWell(
                  onTap: () {
                    ref.read(bbsTimelineProvider.notifier).toggleLike(post);
                  },
                  child: Row(
                    children: [
                      Icon(
                        post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                        color: post.isLikedByMe ? Colors.pink : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.likesCount}', style: AppTextStyles.notoSans(color: post.isLikedByMe ? Colors.pink : Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.share, color: Colors.grey, size: 20),
              ],
            )
          ],
        ),
      ),
    );
  }
}
