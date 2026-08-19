import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

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

      // 投稿一覧を取得 (新しい順、いいねフラグ付き)
      final response = await supabase.rpc('get_bbs_posts_with_status', params: {
        'p_user_id': currentUserId,
      });

      List<BbsPost> posts = [];
      for (var item in response) {
        final userData = item['users'];
        final user = userData != null ? Users.fromMap(userData) : null;
        final isLiked = item['is_liked_by_me'] ?? false;
        posts.add(BbsPost.fromMap(item, user: user, isLikedByMe: isLiked));
      }

      state = AsyncValue.data(posts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ポストを追加し、新しいポストのIDを返す（レスバ添付時に使用）
  Future<String?> addPost(String content, {List<String>? imageUrls}) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null || content.trim().isEmpty) return null;

    try {
      final supabase = _ref.read(supabaseProvider);
      final response = await supabase.from('bbs_posts').insert({
        'user_id': currentUserId,
        'content': content.trim(),
        if (imageUrls != null && imageUrls.isNotEmpty) 'image_urls': imageUrls,
      }).select('id').single();
      // 投稿後、リストを再取得
      await fetchPosts();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('addPost error: $e');
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
        // トリガーで自動カウント更新されるためRPC呼び出しは削除
      } else {
        await supabase
            .from('bbs_likes')
            .insert({'post_id': post.id, 'user_id': currentUserId});
        // トリガーで自動カウント更新されるためRPC呼び出しは削除
      }
    } catch (e) {
      debugPrint('toggleLike error: $e');
      // エラー時は再取得して同期
      await fetchPosts();
    }
  }

  /// ポストにレスバが付いたことをローカル反映する（再取得なしで「レスバ付き」バッジを即時表示）
  void markPostHasResba(String postId) {
    if (state is AsyncData) {
      final posts = state.value!;
      final newPosts = posts.map((p) {
        if (p.id == postId) {
          return p.copyWith(hasResba: true);
        }
        return p;
      }).toList();
      state = AsyncValue.data(newPosts);
    }
  }

  void incrementReplyCountLocally(String postId) {
    if (state is AsyncData) {
      final posts = state.value!;
      final newPosts = posts.map((p) {
        if (p.id == postId) {
          return p.copyWith(repliesCount: p.repliesCount + 1);
        }
        return p;
      }).toList();
      state = AsyncValue.data(newPosts);
    }
  }
}
