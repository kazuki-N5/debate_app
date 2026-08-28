// ignore_for_file: file_names

import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/provider/bbs_bookmark_provider.dart';
import 'package:debate_project/provider/bbs_timeline_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';

import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/widgets/full_screen_image_viewer.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:debate_project/widgets/community_ad.dart';
import 'package:debate_project/adsence/ad_community_provider.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';

class BbsTimelineView extends HookConsumerWidget {
  const BbsTimelineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(bbsTimelineProvider);
    ref.watch(currentUserIdProvider);

    // --- コミュニティ(掲示板タブ)用の Medium Rectangle 広告 ---
    // スロット index -> 個別の BannerAd(スロットごとに別インスタンス)
    final bbsAds = ref.watch(communityBbsAdProvider);
    final isSubscribed = ref.watch(inAppPurchaseManagerProvider).isSubscribed;

        return Scaffold(
      backgroundColor: Colors.white,
      body: timelineAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            // 0件のときは広告のみ表示(課金で広告なしなら従来の空メッセージ)
            if (!isSubscribed) {
              ref.read(communityBbsAdProvider.notifier).prepare({0});
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 60),
                  Padding(
                    padding: EdgeInsets.only(bottom: homeBottomAdClearance()),
                    child: bbsAds[0] != null
                        ? communityAdWidget(bbsAds[0]!)
                        : communityAdPlaceholder(),
                  ),
                ],
              );
            }
            return Center(
              child: Text(
                'まだ投稿がありません',
                style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 16),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              if (!isSubscribed) {
                ref.read(communityBbsAdProvider.notifier).refresh();
              }
              await ref.read(bbsTimelineProvider.notifier).fetchPosts();
            },
            child: Builder(builder: (context) {
              // 掲示板は長いフィードなので「6件ごとに1個」広告を挟む(開始位置はランダム)
              final adSlots = !isSubscribed
                  ? communityAdSlotIndexes(
                      posts.length,
                      6,
                      startContentIndex: ref
                          .read(communityBbsAdProvider.notifier)
                          .resolveFirstAdOffset(posts.length, 2),
                    )
                  : <int>{};
              final totalItems = posts.length + adSlots.length;

              // 各広告スロットに個別の広告をロード(多重ロードはProvider側で防止)
              if (adSlots.isNotEmpty) {
                ref.read(communityBbsAdProvider.notifier).prepare(adSlots);
              }

              return ListView.separated(
                padding: EdgeInsets.only(
                  top: 4,
                  // 非課金時は下部の常時表示バナーに被らないよう余白を広げる
                  bottom: isSubscribed
                      ? MediaQuery.of(context).padding.bottom + 80
                      : homeBottomAdClearance(),
                ),
                itemCount: totalItems,
                separatorBuilder: (context, index) =>
                    // 広告の隣では区切り線を出さない(広告スロットは独立表示)
                    adSlots.contains(index) || adSlots.contains(index + 1)
                        ? const SizedBox.shrink()
                        : Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey[200],
                          ),
                itemBuilder: (context, index) {
                  if (adSlots.contains(index)) {
                    final slotAd = bbsAds[index];
                    return slotAd != null
                        ? communityAdWidget(slotAd)
                        : communityAdPlaceholder();
                  }
                  final post =
                      posts[communityContentIndex(index, adSlots)];
                  return BbsPostWidget(post: post);
                },
              );
            }),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('エラーが発生しました')),
      ),
    );
  }
}


class BbsPostWidget extends ConsumerWidget {
  final BbsPost post;

  /// true のとき本文・名前・画像を隠して「ブロックしたユーザーの投稿」を表示する
  /// (タイムラインではブロック投稿は除外済みのため、主に投稿詳細画面の深堀り遷移用)
  final bool isBlockedPlaceholder;

  /// true のときカード本体のタップで投稿詳細へ遷移する
  /// (詳細画面内で使うときは false にして二重遷移を防ぐ)
  final bool enableTapToDetail;

  /// いいねボタンの処理を差し替える(省略時はタイムラインの toggleLike で楽観更新)
  final void Function(BbsPost post)? onLikeTap;

  const BbsPostWidget({
    super.key,
    required this.post,
    this.isBlockedPlaceholder = false,
    this.enableTapToDetail = true,
    this.onLikeTap,
  });

  static bool _isNavigating = false;

  /// 投稿カードのタップで詳細画面へ遷移する（二重遷移ガード付き）
  void _openPostDetail(BuildContext context) {
    if (_isNavigating) {
      debugPrint('RESBA_DEBUG: skip (isNavigating=true)');
      return;
    }
    _isNavigating = true;
    debugPrint('RESBA_DEBUG: onTap, pushing /bbsPostDetail');
    try {
      context
          .push(
            '/bbsPostDetail',
            extra: post,
          )
          .whenComplete(() {
            debugPrint('RESBA_DEBUG: push completed');
            _isNavigating = false;
          });
    } catch (e) {
      debugPrint('RESBA_DEBUG: push error: $e');
      _isNavigating = false;
    }
    // 保険: push が完了しなくても3秒でフラグを戻す
    Future.delayed(const Duration(seconds: 3), () {
      _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ▼ ここを一箇所変えれば、すべてのアイコンのサイズがまとめて変わります ▼
    const double iconSize = 15.0;

    // ブロックしたユーザーの投稿: 内容は一切見せない
    if (isBlockedPlaceholder) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
              child: Icon(Icons.block, color: Colors.grey[400], size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ブロックしたユーザーの投稿です',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final user = post.user;
    final userName = user?.name ?? '名無し';
    final userAvatar = user?.avatar_url;

    final dateStr = DateFormatter.formatBbsDate(post.createdAt);
    final isBookmarked = ref.watch(bbsBookmarkIdsProvider).contains(post.id);

    // 論理削除された投稿: アイコン・名前・時間はそのまま表示し、
    // 本文・画像・アクションの代わりに「このポストは削除されました」を表示する
    // (コメントの削除表示と同じ方針。カードはタップで詳細(コメント)を開ける)
    if (post.isDeleted) {
      return InkWell(
        onTap: enableTapToDetail ? () => _openPostDetail(context) : null,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー: アイコン(通常と同じ)
              GestureDetector(
                onTap: () {
                  context.push('/userProfile', extra: post.userId);
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      userAvatar != null && userAvatar.isNotEmpty
                          // 表示サイズ(radius20=40px)に縮小デコードしてカクつきを抑える
                          ? ResizeImage(NetworkImage(userAvatar), width: 120)
                          : null,
                  child: userAvatar == null || userAvatar.isEmpty
                      ? Icon(Icons.person, color: Colors.grey[600])
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // コンテンツ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名前・時間(通常と同じ)
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
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('・ $dateStr',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF536471),
                                    height: 1.2,
                                  )),
                            ],
                          ),
                        ),
                        // メニュー(…)は削除済みのため非表示(コメントと同じ)
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 削除プレースホルダー(本文・画像・アクションの代わり)
                    const Text(
                      'このポストは削除されました',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
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

    return InkWell(
      onTap: enableTapToDetail ? () => _openPostDetail(context) : null,
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
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    userAvatar != null && userAvatar.isNotEmpty
                        // 表示サイズ(radius20=40px)に縮小デコードしてカクつきを抑える
                        ? ResizeImage(NetworkImage(userAvatar), width: 120)
                        : null,
                child: userAvatar == null || userAvatar.isEmpty
                    ? Icon(Icons.person, color: Colors.grey[600])
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
                        onTap: () {
                          final myId = ref.read(currentUserIdProvider);
                          final isOwn = post.userId == myId;
                          showContentMenuSheet(
                            context: context,
                            ref: ref,
                            authorUserId: isOwn ? null : post.userId,
                            authorName: userName,
                            contentType: 'bbs_post',
                            contentId: post.id,
                            contentSnapshot: post.content,
                            isOwnContent: isOwn,
                            onHide: () =>
                                ref.read(bbsTimelineProvider.notifier).hidePost(post.id),
                            onDelete: isOwn
                                ? () async {
                                    final ok = await ref
                                        .read(bbsTimelineProvider.notifier)
                                        .deletePost(post.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? '投稿を削除しました' : '削除に失敗しました'),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            onBlocked: () =>
                                ref.read(bbsTimelineProvider.notifier).fetchPosts(),
                          );
                        },
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
                  if (post.hasResba) ...[
                    const SizedBox(height: 6),
                    Builder(builder: (context) {
                      debugPrint('[RESBA_UI_LOG] [Timeline] Rendering ResbaBadge for post: ${post.id}, title: ${post.content}');
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: ResbaBadge(text: 'レスバ付き'),
                      );
                    }),
                  ],
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
                              if (onLikeTap != null) {
                                onLikeTap!(post);
                              } else {
                                ref
                                    .read(bbsTimelineProvider.notifier)
                                    .toggleLike(post);
                              }
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
                      // 右側のボタン（ブックマーク）
                      GestureDetector(
                        onTap: () async {
                          final added = await ref
                              .read(bbsBookmarkIdsProvider.notifier)
                              .toggleBookmark(post.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added
                                      ? 'ブックマークに追加しました'
                                      : 'ブックマークから削除しました',
                                  style: AppTextStyles.notoSans(
                                      color: Colors.white, fontSize: 13),
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: Icon(
                            isBookmarked
                                ? CupertinoIcons.bookmark_fill
                                : CupertinoIcons.bookmark,
                            color: isBookmarked
                                ? const Color(0xFF1D9BF0)
                                : const Color(0xFF536471),
                            size: 16,
                          ),
                        ),
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
    FullScreenImageViewer.show(
      context,
      imageUrls: imageUrls,
      initialIndex: index,
    );
  }
}


