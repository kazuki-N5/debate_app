import 'package:debate_project/modes/bbs_comment.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 投稿ごとのコメントを取得するためのプロバイダ
final bbsCommentProvider = StateNotifierProvider.family<BbsCommentNotifier, AsyncValue<List<BbsComment>>, String>((ref, postId) {
  return BbsCommentNotifier(ref, postId);
});

class BbsCommentNotifier extends StateNotifier<AsyncValue<List<BbsComment>>> {
  final Ref _ref;
  final String postId;

  BbsCommentNotifier(this._ref, this.postId) : super(const AsyncValue.loading()) {
    fetchComments();
  }

  Future<void> fetchComments() async {
    try {
      final supabase = _ref.read(supabaseProvider);
      final currentUserId = _ref.read(currentUserIdProvider);

      // コメント一覧を取得 (古い順)
      final response = await supabase
          .from('bbs_comments')
          .select('*, users(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      List<BbsComment> allComments = [];
      for (var item in response) {
        final userData = item['users'];
        final user = userData != null ? Users.fromMap(userData) : null;
        
        bool isLiked = false;
        if (currentUserId != null) {
          final likeRes = await supabase
              .from('bbs_comment_likes')
              .select('id')
              .eq('comment_id', item['id'])
              .eq('user_id', currentUserId)
              .maybeSingle();
          isLiked = likeRes != null;
        }

        allComments.add(BbsComment.fromMap(item, user: user, isLikedByMe: isLiked));
      }

      // parentCommentId が null のものをルートコメントとし、null でないものを replies に詰める
      List<BbsComment> rootComments = allComments.where((c) => c.parentCommentId == null).toList();
      List<BbsComment> childComments = allComments.where((c) => c.parentCommentId != null).toList();

      for (int i = 0; i < rootComments.length; i++) {
        final replies = childComments.where((c) => c.parentCommentId == rootComments[i].id).toList();
        rootComments[i] = rootComments[i].copyWith(replies: replies);
      }

      state = AsyncValue.data(rootComments);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addComment(String content, {String? parentCommentId}) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null || content.trim().isEmpty) return;

    try {
      final supabase = _ref.read(supabaseProvider);
      await supabase.from('bbs_comments').insert({
        'post_id': postId,
        'user_id': currentUserId,
        'parent_comment_id': parentCommentId,
        'content': content.trim(),
      });
      // 投稿後、コメント数を増やす
      await supabase.rpc('increment_replies_count', params: {'p_post_id': postId});
      
      await fetchComments();
    } catch (e) {
      print('addComment error: $e');
      rethrow;
    }
  }

  Future<void> toggleLike(BbsComment comment) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final supabase = _ref.read(supabaseProvider);
    final isLiked = comment.isLikedByMe;

    try {
      if (isLiked) {
        await supabase
            .from('bbs_comment_likes')
            .delete()
            .match({'comment_id': comment.id, 'user_id': currentUserId});
        await supabase.rpc('decrement_comment_likes_count', params: {'p_comment_id': comment.id});
      } else {
        await supabase
            .from('bbs_comment_likes')
            .insert({'comment_id': comment.id, 'user_id': currentUserId});
        await supabase.rpc('increment_comment_likes_count', params: {'p_comment_id': comment.id});
      }
      await fetchComments();
    } catch (e) {
      print('toggleLike error: $e');
    }
  }
}
