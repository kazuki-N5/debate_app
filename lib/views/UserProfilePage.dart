// ignore_for_file: file_names
import 'package:debate_project/provider/follow_provider.dart';
import 'package:debate_project/provider/user_profile_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/views/bbs/BbsTimelineView.dart';
import 'package:debate_project/views/DmRoomPage.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
        appBar: AppBar(title: const Text('プロフィール')),
        body: const Center(child: Text('ユーザーが見つかりません')),
      );
    }

    final isSelf = Supabase.instance.client.auth.currentUser?.id == user.id;
    final isFollowing = ref.watch(isFollowingProvider(user.id));
    final headerUrl = user.header_url;
    final avatarUrl = user.avatar_url;
    final bio = user.bio ?? '';
    final name = user.name ?? '名無し';
    final displayId = user.id.length > 15 ? user.id.substring(0, 15) : user.id;

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 150.0,
              pinned: true,
              backgroundColor: Colors.blueAccent,
              flexibleSpace: FlexibleSpaceBar(
                background: InkWell(
                  onTap: () async {
                    if (Supabase.instance.client.auth.currentUser?.id == user.id) {
                      await ref.read(userProvider.notifier).updateHeader();
                    }
                  },
                  child: headerUrl != null && headerUrl.isNotEmpty
                      ? Image.network(headerUrl, fit: BoxFit.cover)
                      : Container(color: Colors.blueAccent),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // アバター画像と右上のアクションボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? const Icon(Icons.person, size: 40, color: Colors.grey)
                              : null,
                        ),
                        Row(
                          children: [
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
                                  MaterialPageRoute(
                                    builder: (context) => DmRoomPage(
                                      otherUserId: user.id,
                                      otherUserName: name,
                                      otherUserAvatar: avatarUrl,
                                    ),
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
                                onPressed: () {
                                  ref.read(followActionProvider).toggle(user.id);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: AppTextStyles.bold(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$displayId',
                      style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    // 自己紹介文
                    if (bio.isNotEmpty) ...[
                      Text(
                        bio,
                        style: AppTextStyles.notoSans(fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
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
                    Tab(text: '投稿'),
                    Tab(text: 'リプライ'),
                    Tab(text: 'メディア'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            // 投稿タブ
            _buildPostsList(state),
            // リプライタブ
            const Center(child: Text('まだリプライがありません', style: TextStyle(color: Colors.grey))),
            // メディアタブ
            const Center(child: Text('まだメディアがありません', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(UserProfileState state) {
    if (state.posts.isEmpty) {
      return Center(
        child: Text(
          'まだ投稿がありません',
          style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: state.posts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = state.posts[index];
        // BbsPostWidgetは BbsTimelineView.dart で定義されているものを再利用
        return BbsPostWidget(post: post);
      },
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
