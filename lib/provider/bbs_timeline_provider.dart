import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bbsTimelineProvider = StateNotifierProvider<BbsTimelineNotifier, AsyncValue<List<BbsPost>>>((ref) {
  return BbsTimelineNotifier(ref);
});

class BbsTimelineNotifier extends StateNotifier<AsyncValue<List<BbsPost>>> {
  final Ref _ref;

  BbsTimelineNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      state = const AsyncValue.loading();
      final supabase = _ref.read(supabaseProvider);
      final currentUserId = _ref.read(currentUserIdProvider);

      // 投稿一覧を取得 (新しい順)
      final response = await supabase
          .from('bbs_posts')
          .select('*, users(*)')
          .order('created_at', ascending: false)
          .limit(50); // 一旦50件まで

      List<BbsPost> posts = [];
      for (var item in response) {
        final userData = item['users'];
        final user = userData != null ? Users.fromMap(userData) : null;
        
        bool isLiked = false;
        if (currentUserId != null) {
          // いいね状態を取得
          final likeRes = await supabase
              .from('bbs_likes')
              .select('id')
              .eq('post_id', item['id'])
              .eq('user_id', currentUserId)
              .maybeSingle();
          isLiked = likeRes != null;
        }

        posts.add(BbsPost.fromMap(item, user: user, isLikedByMe: isLiked));
      }

      state = AsyncValue.data(posts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addPost(String content) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null || content.trim().isEmpty) return;

    try {
      final supabase = _ref.read(supabaseProvider);
      await supabase.from('bbs_posts').insert({
        'user_id': currentUserId,
        'content': content.trim(),
      });
      // 投稿後、リストを再取得
      await fetchPosts();
    } catch (e) {
      print('addPost error: $e');
      rethrow;
    }
  }

  Future<void> toggleLike(BbsPost post) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final supabase = _ref.read(supabaseProvider);
    final isLiked = post.isLikedByMe;
    final newLikesCount = isLiked ? post.likesCount - 1 : post.likesCount + 1;

    // 楽観的UI更新
    if (state is AsyncData) {
      final posts = state.value!;
      final newPosts = posts.map((p) {
        if (p.id == post.id) {
          return p.copyWith(
            isLikedByMe: !isLiked,
            likesCount: newLikesCount >= 0 ? newLikesCount : 0,
          );
        }
        return p;
      }).toList();
      state = AsyncValue.data(newPosts);
    }

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
      print('toggleLike error: $e');
      // エラー時は再取得して同期
      await fetchPosts();
    }
  }
}
