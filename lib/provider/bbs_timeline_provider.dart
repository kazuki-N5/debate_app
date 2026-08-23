import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final bbsTimelineProvider = StateNotifierProvider<BbsTimelineNotifier, AsyncValue<List<BbsPost>>>((ref) {
  return BbsTimelineNotifier(ref);
});

class BbsTimelineNotifier extends StateNotifier<AsyncValue<List<BbsPost>>> {
  final Ref _ref;
  // 端末内で非表示にした投稿ID(「非表示」機能)
  Set<String> _hiddenPostIds = {};

  BbsTimelineNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadHiddenIds();
    fetchPosts();
  }

  Future<void> _loadHiddenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hiddenPostIds = (prefs.getStringList('hidden_bbs_post_ids') ?? const []).toSet();
    } catch (_) {}
  }

  /// 投稿を「非表示」にする(端末内のみ。ブロックとは独立)
  Future<void> hidePost(String postId) async {
    _hiddenPostIds.add(postId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_bbs_post_ids', _hiddenPostIds.toList());
    } catch (_) {}
    if (state is AsyncData) {
      state = AsyncValue.data(state.value!.where((p) => p.id != postId).toList());
    }
  }

  /// 自分の投稿を削除する（論理削除: 「削除されました」表示になる）
  Future<bool> deletePost(String postId) async {
    try {
      final supabase = _ref.read(supabaseProvider);
      final result = await supabase.rpc('delete_bbs_post', params: {
        'p_post_id': postId,
      });
      final ok = (result is Map && result['success'] == true) || result == true;
      if (ok) {
        // 論理削除された行をリスト上で即座に反映（再取得でプレースホルダーが出る）
        await fetchPosts();
      }
      return ok;
    } catch (e) {
      debugPrint('deletePost error: $e');
      // 失敗時は再同期
      await fetchPosts();
      return false;
    }
  }

  Future<void> fetchPosts() async {
    try {
      state = const AsyncValue.loading();
      final supabase = _ref.read(supabaseProvider);
      final currentUserId = _ref.read(currentUserIdProvider);
      // ブロック済みユーザーの投稿は表示しない
      final blocked = _ref.read(blockedUserIdsProvider).toSet();

      // 投稿一覧を取得 (新しい順、いいねフラグ付き)
      final response = await supabase.rpc('get_bbs_posts_with_status', params: {
        'p_user_id': currentUserId,
      });

      debugPrint('[RESBA_LOG] bbsTimelineProvider.fetchPosts response length: ${(response as List).length}');
      List<BbsPost> posts = [];
      for (var item in response) {
        final userData = item['users'];
        final user = userData != null ? Users.fromMap(userData) : null;
        final isLiked = item['is_liked_by_me'] ?? false;
        final post = BbsPost.fromMap(item, user: user, isLikedByMe: isLiked);
        if (post.hasResba) {
          debugPrint('[RESBA_LOG] Found post WITH resba: id=${post.id}, content=${post.content}');
        }
        posts.add(post);
      }

      // ブロック済みユーザー・非表示投稿を除外
      posts = posts
          .where((p) => !blocked.contains(p.userId))
          .where((p) => !_hiddenPostIds.contains(p.id))
          .toList();

      state = AsyncValue.data(posts);
    } catch (e, st) {
      debugPrint('[RESBA_LOG] bbsTimelineProvider.fetchPosts ERROR: $e\n$st');
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
