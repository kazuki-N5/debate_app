// ignore_for_file: file_names
import 'package:cached_network_image/cached_network_image.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/follow_provider.dart';
import 'package:debate_project/provider/user_profile_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:debate_project/views/bbs/BbsPostDetailView.dart';
import 'package:debate_project/views/bbs/BbsTimelineView.dart';
import 'package:debate_project/views/DmRoomPage.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

class UserProfilePage extends HookConsumerWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider(userId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileState.errorMessage != null
              ? Center(child: Text('エラーが発生しました: ${profileState.errorMessage}'))
              : _buildProfileContent(context, ref, profileState),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, UserProfileState state) {
    final user = state.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('プロフィール', style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
          backgroundColor: Colors.blue,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('ユーザーが見つかりません')),
      );
    }

    final isSelf = Supabase.instance.client.auth.currentUser?.id == user.id;
    final isFollowing = ref.watch(isFollowingProvider(user.id));
    // ブロック状態(自分がブロック / 相手からブロック)
    final isBlocked = ref.watch(blockedUserIdsProvider).contains(user.id);
    final blockedByThem =
        ref.watch(isBlockedByProvider(user.id)).valueOrNull ?? false;
    final headerUrl = user.header_url;
    final avatarUrl = user.avatar_url;
    final bio = user.bio ?? '';
    final name = user.name ?? '名無し';
    final displayId = user.id.length > 15 ? user.id.substring(0, 15) : user.id;

    return Stack(
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            overscroll: false,
          ),
          child: RefreshIndicator(
            notificationPredicate: (notification) => true,
            onRefresh: () async {
              await ref.read(userProfileProvider(user.id).notifier).refreshProfile();
            },
            child: DefaultTabController(
              length: 3,
              child: NestedScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. ヘッダー画像と、最前面に重なるアバター
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // ヘッダー画像 (高さ150)
                              InkWell(
                                onTap: isSelf
                                    ? () async {
                                        await ref.read(userProvider.notifier).updateHeader();
                                        ref.invalidate(userProfileProvider(user.id));
                                      }
                                    : null,
                                child: Container(
                                  height: 150,
                                  width: double.infinity,
                                  color: Colors.blue,
                                  child: headerUrl != null && headerUrl.isNotEmpty
                                      ? Image.network(headerUrl, fit: BoxFit.cover)
                                      : null,
                                ),
                              ),
                              // ヘッダーカメラアイコン (isSelf時)
                              if (isSelf)
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              // ヘッダー下端に重なるアバター（最前面に表示）
                              Positioned(
                                left: 16,
                                bottom: -38,
                                child: InkWell(
                                  onTap: isSelf
                                      ? () async {
                                          await ref
                                              .read(userProvider.notifier)
                                              .updateAvatar();
                                          ref.invalidate(
                                              userProfileProvider(user.id));
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(44),
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 3.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.12),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 38,
                                          backgroundColor: Colors.grey[300],
                                          backgroundImage: avatarUrl != null &&
                                                  avatarUrl.isNotEmpty
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child: avatarUrl == null || avatarUrl.isEmpty
                                              ? Icon(Icons.person,
                                                  size: 38, color: Colors.grey[600])
                                              : null,
                                        ),
                                      ),
                                      if (isSelf)
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white, width: 2),
                                            ),
                                            child: const Icon(Icons.camera_alt,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // 2. ヘッダー直下のコンテンツ（右側に4つのアクションボタン、その下に名前等）
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // アバターの右側に並ぶ4つのアクションボタン（ヘッダー直下）
                                SizedBox(
                                  height: 44,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (!isSelf) ...[
                                        // ブロック / ブロック解除
                                        IconButton(
                                          icon: Icon(
                                            isBlocked ? Icons.person_off : Icons.block,
                                            color: isBlocked ? Colors.red : Colors.black54,
                                          ),
                                          tooltip: isBlocked ? 'ブロックを解除' : 'ブロック',
                                          onPressed: () {
                                            if (isBlocked) {
                                              showUnblockUserDialog(
                                                context: context,
                                                ref: ref,
                                                targetUserId: user.id,
                                                targetName: name,
                                              );
                                            } else {
                                              showBlockUserDialog(
                                                context: context,
                                                ref: ref,
                                                targetUserId: user.id,
                                                targetName: name,
                                                onBlocked: () =>
                                                    ref.invalidate(userProfileProvider(user.id)),
                                              );
                                            }
                                          },
                                        ),
                                        // 通報
                                        IconButton(
                                          icon: const Icon(Icons.flag_outlined,
                                              color: Colors.black54),
                                          tooltip: '通報',
                                          onPressed: () => showReportDialog(
                                            context: context,
                                            ref: ref,
                                            opponentId: user.id,
                                            contentType: 'user',
                                          ),
                                        ),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.mail_outline),
                                        onPressed: () {
                                          if (Supabase.instance.client.auth.currentUser?.id == user.id) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('自分自身にはDMを送れません')),
                                            );
                                            return;
                                          }
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (context, _, __) => DmRoomPage(
                                                otherUserId: user.id,
                                                otherUserName: name,
                                                otherUserAvatar: avatarUrl,
                                              ),
                                              transitionDuration: Duration.zero,
                                              reverseTransitionDuration: Duration.zero,
                                            ),
                                          );
                                        },
                                      ),
                                      if (!isSelf)
                                        IconButton(
                                          icon: Icon(
                                            isFollowing.valueOrNull == true
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: isFollowing.valueOrNull == true
                                                ? Colors.pink
                                                : Colors.black54,
                                          ),
                                          onPressed: () async {
                                            await ref.read(followActionProvider).toggle(user.id);
                                            ref.invalidate(userProfileProvider(user.id));
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // 名前・ID・情報表示
                                GestureDetector(
                                  onTap: isSelf
                                      ? () {
                                          context.push('/name2');
                                        }
                                      : null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: AppTextStyles.bold(fontSize: 20),
                                      ),
                                      if (isSelf) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.edit,
                                            size: 16, color: Colors.grey),
                                      ],
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 4),
                            Text(
                              '@$displayId',
                              style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            // フォロー数・フォロワー数
                            Row(
                              children: [
                                Text(
                                  '${state.followingCount}',
                                  style: AppTextStyles.bold(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'フォロー中',
                                  style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '${state.followerCount}',
                                  style: AppTextStyles.bold(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'フォロワー',
                                  style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 自己紹介文
                            if (bio.isNotEmpty) ...[
                              GestureDetector(
                                onTap: isSelf
                                    ? () => _showEditBioDialog(context, ref, user.id, bio)
                                    : null,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          bio,
                                          style: AppTextStyles.notoSans(fontSize: 15),
                                        ),
                                      ),
                                      if (isSelf) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ] else if (isSelf) ...[
                              GestureDetector(
                                onTap: () => _showEditBioDialog(context, ref, user.id, ''),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add, size: 16, color: Colors.blueAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        '自己紹介を追加',
                                        style: AppTextStyles.notoSans(fontSize: 13, color: Colors.blueAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // 相手からブロックされている場合の表示
                            if (blockedByThem) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Text(
                                  'このユーザーからブロックされています',
                                  style: AppTextStyles.notoSans(
                                    fontSize: 12,
                                    color: Colors.red[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    const TabBar(
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blueAccent,
                      tabs: [
                        Tab(text: 'ポスト'),
                        Tab(text: '返信'),
                        Tab(text: 'メディア'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                // ポストタブ
                _buildPostsList(state),
                // 返信タブ (X風スレッド表示)
                _buildRepliesList(context, ref, state),
                // メディアタブ (画像付きポスト＋画像付き返信のタイムライン表示)
                _buildMediaList(context, ref, state),
              ],
            ),
          ),
        ),
      ),
    ),
    // 常時表示される左上戻るボタン
    Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      child: CircleAvatar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        radius: 18,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    ),
  ],
);
  }

  void _showEditBioDialog(
      BuildContext context, WidgetRef ref, String userId, String currentBio) {
    final textController = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('自己紹介を編集', style: AppTextStyles.bold(fontSize: 18)),
          content: TextField(
            controller: textController,
            maxLines: 4,
            maxLength: 160,
            decoration: const InputDecoration(
              hintText: '自己紹介を入力してください (160文字以内)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newBio = textController.text;
                Navigator.pop(ctx);
                try {
                  await ref.read(userProvider.notifier).updateBio(newBio);
                  ref.invalidate(userProfileProvider(userId));
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('自己紹介の更新に失敗しました: $e')),
                    );
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // 1. ポストタブ
  Widget _buildPostsList(UserProfileState state) {
    if (state.posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'まだポストがありません',
              style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      itemCount: state.posts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = state.posts[index];
        return BbsPostWidget(post: post);
      },
    );
  }

  // 2. 返信タブ (X風スレッド表示)
  Widget _buildRepliesList(BuildContext context, WidgetRef ref, UserProfileState state) {
    if (state.replies.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'まだ返信がありません',
              style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      itemCount: state.replies.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.replies[index];
        return UserReplyThreadWidget(
          item: item,
          userId: state.user?.id ?? userId,
        );
      },
    );
  }

  // 3. メディアタブ (画像付きポスト＋画像付き返信のタイムライン表示)
  Widget _buildMediaList(BuildContext context, WidgetRef ref, UserProfileState state) {
    if (state.mediaItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'まだメディアがありません',
              style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      itemCount: state.mediaItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.mediaItems[index];
        if (item.type == UserMediaType.post && item.post != null) {
          return BbsPostWidget(post: item.post!);
        } else if (item.type == UserMediaType.reply && item.replyItem != null) {
          return UserReplyThreadWidget(
            item: item.replyItem!,
            userId: state.user?.id ?? userId,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// X（Twitter）風 スレッド表示ウィジェット（親ポスト ＋ 縦線 ＋ 自分の返信）
class UserReplyThreadWidget extends ConsumerWidget {
  final UserReplyItem item;
  final String userId;

  const UserReplyThreadWidget({
    super.key,
    required this.item,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reply = item.reply;
    final parentPost = item.parentPost;
    final replyUser = reply.user;
    final replyUserName = replyUser?.name ?? 'ユーザー';
    final replyAvatarUrl = replyUser?.avatar_url;

    return InkWell(
      onTap: parentPost != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BbsPostDetailView(post: parentPost),
                ),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上段: 親ポスト（返信先）
            if (parentPost != null) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 親アバターと縦のスレッドライン
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, _, __) => UserProfilePage(userId: parentPost.userId),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: parentPost.user?.avatar_url != null &&
                                    parentPost.user!.avatar_url!.isNotEmpty
                                ? CachedNetworkImageProvider(parentPost.user!.avatar_url!)
                                : null,
                            child: parentPost.user?.avatar_url == null ||
                                    parentPost.user!.avatar_url!.isEmpty
                                ? const Icon(Icons.person, size: 20, color: Colors.white)
                                : null,
                          ),
                        ),
                        // アバターから下へ伸びるスレッド連結線
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // 親ポストの本文
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    parentPost.user?.name ?? 'ユーザー',
                                    style: AppTextStyles.bold(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '· ${DateFormatter.formatBbsDate(parentPost.createdAt)}',
                                  style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              parentPost.content,
                              style: AppTextStyles.notoSans(fontSize: 14, color: Colors.black87),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // 親ポストの画像（もしあれば）
                            if (parentPost.imageUrls != null && parentPost.imageUrls!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: parentPost.imageUrls!.first,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 親ポストが見つからない場合
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '元の投稿は削除されたか表示できません',
                  style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],

            // 下段: ユーザー自身の返信（リプライ）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 返信者のアバター
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: replyAvatarUrl != null && replyAvatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(replyAvatarUrl)
                      : null,
                  child: replyAvatarUrl == null || replyAvatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 20, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                // 返信内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              replyUserName,
                              style: AppTextStyles.bold(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '· ${DateFormatter.formatBbsDate(reply.createdAt)}',
                            style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      // 返信先の表示
                      if (parentPost?.user?.name != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                          child: Text(
                            '返信先: @${parentPost!.user!.name} さん',
                            style: AppTextStyles.notoSans(color: Colors.blueAccent, fontSize: 12),
                          ),
                        ),
                      // 返信本文
                      if (reply.content.isNotEmpty)
                        Text(
                          reply.content,
                          style: AppTextStyles.notoSans(fontSize: 14),
                        ),
                      // 返信の添付画像（もしあれば）
                      if (reply.imageUrl != null && reply.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: reply.imageUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 180,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 180,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // アクションバー（コメント数・いいね）
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // コメントアイコン
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${reply.replies.length}',
                                style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          // いいねボタン
                          InkWell(
                            onTap: () {
                              ref.read(userProfileProvider(userId).notifier).toggleReplyLike(reply);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  reply.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                                  size: 16,
                                  color: reply.isLikedByMe ? Colors.pink : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${reply.likesCount}',
                                  style: AppTextStyles.notoSans(
                                    color: reply.isLikedByMe ? Colors.pink : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.bookmark_border, size: 16, color: Colors.grey),
                          const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
