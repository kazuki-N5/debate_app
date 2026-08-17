// ignore_for_file: file_names

import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/provider/bbs_timeline_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';

import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/widgets/full_screen_image_viewer.dart';

class BbsTimelineView extends HookConsumerWidget {
  const BbsTimelineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(bbsTimelineProvider);
    ref.watch(currentUserIdProvider);

        return Scaffold(
      backgroundColor: Colors.white,
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
            onRefresh: () =>
                ref.read(bbsTimelineProvider.notifier).fetchPosts(),
            child: ListView.separated(
              padding: EdgeInsets.only(
                top: 4,
                bottom: MediaQuery.of(context).padding.bottom + 80,
              ),
              itemCount: posts.length,
              separatorBuilder: (context, index) => Divider(height: 1, thickness: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final post = posts[index];
                return BbsPostWidget(post: post);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラーが発生しました')),
      ),
    );
  }
}


class BbsPostWidget extends ConsumerWidget {
  final BbsPost post;

  const BbsPostWidget({super.key, required this.post});

  static bool _isNavigating = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ▼ ここを一箇所変えれば、すべてのアイコンのサイズがまとめて変わります ▼
    const double iconSize = 15.0;

    final user = post.user;
    final userName = user?.name ?? '名無し';
    final userAvatar = user?.avatar_url;

    final dateStr = DateFormatter.formatBbsDate(post.createdAt);

    return InkWell(
      onTap: () {
        if (_isNavigating) return;
        _isNavigating = true;
        // 詳細画面へ遷移
        context.push(
          '/bbsPostDetail',
          extra: post,
        ).then((_) => _isNavigating = false);
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: アイコン
            GestureDetector(
              onTap: () {
                context.push(
                  '/userProfile',
                  extra: post.userId,
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage:
                    userAvatar != null && userAvatar.isNotEmpty
                        // 表示サイズ(radius20=40px)に縮小デコードしてカクつきを抑える
                        ? ResizeImage(NetworkImage(userAvatar), width: 120)
                        : null,
                child: userAvatar == null || userAvatar.isEmpty
                    ? const Icon(CupertinoIcons.person)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // コンテンツ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名前、時間
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.2, // 高さを抑えて上揃えを合わせる
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('・ $dateStr',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF536471), // アイコンと同じ少し濃いグレー
                                  height: 1.2,
                                )),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Icon(CupertinoIcons.ellipsis, color: Color(0xFF536471), size: iconSize),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 本文
                  if (post.content.isNotEmpty)
                    Text(
                      post.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  if (post.imageUrls != null && post.imageUrls!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildImageGrid(context, post.imageUrls!),
                  ],
                  const SizedBox(height: 8),
                  // アクションボタン群
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 左側のボタン群（リプライ、いいね）
                      Row(
                        children: [
                          // リプライ
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/images/icons/tweeticon/reply.svg',
                                width: iconSize,
                                height: iconSize,
                                colorFilter: const ColorFilter.mode(Color(0xFF536471), BlendMode.srcIn),
                              ),
                              const SizedBox(width: 4),
                              Text('${post.repliesCount}',
                                  style: const TextStyle(color: Color(0xFF536471), fontSize: 13)),
                            ],
                          ),
                          const SizedBox(width: 48), // アイコン間の間隔
                          // いいね
                          InkWell(
                            onTap: () {
                              ref.read(bbsTimelineProvider.notifier).toggleLike(post);
                            },
                            child: Row(
                              children: [
                                post.isLikedByMe
                                    ? const Icon(CupertinoIcons.heart_fill, color: Colors.pink, size: iconSize)
                                    : SvgPicture.asset(
                                        'assets/images/icons/tweeticon/heart.svg',
                                        width: iconSize,
                                        height: iconSize,
                                        colorFilter: const ColorFilter.mode(Color(0xFF536471), BlendMode.srcIn),
                                      ),
                                const SizedBox(width: 4),
                                Text('${post.likesCount}',
                                    style: TextStyle(
                                        color: post.isLikedByMe
                                            ? Colors.pink
                                            : const Color(0xFF536471),
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // 右側のボタン群（ブックマーク & シェア）
                      const Row(
                        children: [
                          Icon(CupertinoIcons.bookmark,
                              color: Color(0xFF536471), size: 16),
                          SizedBox(width: 16),
                          Icon(CupertinoIcons.share, color: Color(0xFF536471), size: 16),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context, List<String> imageUrls) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildGrid(context, imageUrls),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<String> imageUrls) {
    if (imageUrls.length == 1) {
      return GestureDetector(
        onTap: () => _showFullScreen(context, imageUrls, 0),
        child: CachedNetworkImage(
          imageUrl: imageUrls[0],
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
          memCacheWidth: 1000, // 表示サイズでデコードしてカクつきを抑える
          fadeInDuration: Duration.zero, // ふわ〜っと出るフェードを無効化してパッと表示
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) => Container(color: Colors.grey[300]),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      );
    } else if (imageUrls.length == 2) {
      return SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(child: _buildImage(imageUrls[0], onTap: () => _showFullScreen(context, imageUrls, 0))),
            const SizedBox(width: 2),
            Expanded(child: _buildImage(imageUrls[1], onTap: () => _showFullScreen(context, imageUrls, 1))),
          ],
        ),
      );
    } else if (imageUrls.length == 3) {
      return SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(child: _buildImage(imageUrls[0])),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildImage(imageUrls[1], onTap: () => _showFullScreen(context, imageUrls, 1))),
                  const SizedBox(height: 2),
                  Expanded(child: _buildImage(imageUrls[2], onTap: () => _showFullScreen(context, imageUrls, 2))),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 4枚
      return SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildImage(imageUrls[0], onTap: () => _showFullScreen(context, imageUrls, 0))),
                  const SizedBox(height: 2),
                  Expanded(child: _buildImage(imageUrls[2], onTap: () => _showFullScreen(context, imageUrls, 2))),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildImage(imageUrls[1], onTap: () => _showFullScreen(context, imageUrls, 1))),
                  const SizedBox(height: 2),
                  Expanded(child: _buildImage(imageUrls[3], onTap: () => _showFullScreen(context, imageUrls, 3))),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildImage(String url, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 600, // 表示サイズでデコードしてカクつきを抑える
        fadeInDuration: Duration.zero, // ふわ〜っと出るフェードを無効化してパッと表示
        fadeOutDuration: Duration.zero,
          placeholder: (context, url) => Container(color: Colors.grey[300]),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
    );
  }


  void _showFullScreen(BuildContext context, List<String> imageUrls, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: index,
        ),
      ),
    );
  }
}


