import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// UserProfileStateは、特定のユーザーの情報と、そのユーザーの投稿一覧を保持します
class UserProfileState {
  final Users? user;
  final List<BbsPost> posts;
  final bool isLoading;
  final String? errorMessage;

  UserProfileState({
    this.user,
    this.posts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  UserProfileState copyWith({
    Users? user,
    List<BbsPost>? posts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UserProfileState(
      user: user ?? this.user,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ユーザーIDをパラメータとして受け取るProvider
final userProfileProvider = StateNotifierProvider.family<UserProfileNotifier, UserProfileState, String>((ref, userId) {
  return UserProfileNotifier(ref, userId);
});

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final Ref _ref;
  final String _userId;

  UserProfileNotifier(this._ref, this._userId) : super(UserProfileState(isLoading: true)) {
    _fetchProfileAndPosts();
  }

  Future<void> _fetchProfileAndPosts() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final supabase = _ref.read(supabaseProvider);
      final currentUserId = _ref.read(currentUserIdProvider);

      // 1. ユーザー情報の取得
      final userResponse = await supabase
          .from('users')
          .select()
          .eq('id', _userId)
          .maybeSingle();

      Users? user;
      if (userResponse != null) {
        user = Users.fromMap(userResponse);
      }

      // 2. ユーザーのBBS投稿一覧を取得 (新しい順)
      final postsResponse = await supabase
          .from('bbs_posts')
          .select('*, users(*)')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(50); // 一旦50件まで

      List<BbsPost> posts = [];
      Set<String> likedPostIds = {};

      if (currentUserId != null && postsResponse.isNotEmpty) {
        final postIds = postsResponse.map((p) => p['id'] as String).toList();
        final likesRes = await supabase
            .from('bbs_likes')
            .select('post_id')
            .eq('user_id', currentUserId)
            .inFilter('post_id', postIds);
        
        for (var row in likesRes) {
          likedPostIds.add(row['post_id'] as String);
        }
      }

      for (var item in postsResponse) {
        final userData = item['users'];
        final postUser = userData != null ? Users.fromMap(userData) : null;
        final isLiked = likedPostIds.contains(item['id']);

        posts.add(BbsPost.fromMap(item, user: postUser, isLikedByMe: isLiked));
      }

      state = state.copyWith(
        user: user,
        posts: posts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> toggleLike(BbsPost post) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final supabase = _ref.read(supabaseProvider);
    final isLiked = post.isLikedByMe;
    final newLikesCount = isLiked ? post.likesCount - 1 : post.likesCount + 1;

    // 楽観的UI更新
    final newPosts = state.posts.map((p) {
      if (p.id == post.id) {
        return p.copyWith(
          isLikedByMe: !isLiked,
          likesCount: newLikesCount >= 0 ? newLikesCount : 0,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(posts: newPosts);

    try {
      if (isLiked) {
        await supabase
            .from('bbs_likes')
            .delete()
            .match({'post_id': post.id, 'user_id': currentUserId});
        await supabase.rpc('decrement_likes_count', params: {'post_id': post.id});
      } else {
        await supabase
            .from('bbs_likes')
            .insert({'post_id': post.id, 'user_id': currentUserId});
        await supabase.rpc('increment_likes_count', params: {'post_id': post.id});
      }
    } catch (e) {
      log('toggleLike error: $e');
      // エラー時は再取得して同期
      await _fetchProfileAndPosts();
    }
  }
}
