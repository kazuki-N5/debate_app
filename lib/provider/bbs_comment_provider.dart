import 'package:debate_project/modes/bbs_comment.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:debate_project/provider/bbs_timeline_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 投稿ごとのコメントを取得するためのプロバイダ
final bbsCommentProvider = StateNotifierProvider.family<BbsCommentNotifier, AsyncValue<List<BbsComment>>, String>((ref, postId) {
  return BbsCommentNotifier(ref, postId);
});

class BbsCommentNotifier extends StateNotifier<AsyncValue<List<BbsComment>>> {
  final Ref _ref;
  final String postId;
  // 端末内で非表示にしたコメントID(「非表示」機能)
  Set<String> _hiddenCommentIds = {};

  BbsCommentNotifier(this._ref, this.postId) : super(const AsyncValue.loading()) {
    _loadHiddenIds();
    fetchComments();
  }

  Future<void> _loadHiddenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hiddenCommentIds = (prefs.getStringList('hidden_bbs_comment_ids') ?? const []).toSet();
    } catch (_) {}
  }

  /// コメントを「非表示」にする(端末内のみ)
  Future<void> hideComment(String commentId) async {
    _hiddenCommentIds.add(commentId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_bbs_comment_ids', _hiddenCommentIds.toList());
    } catch (_) {}
    await fetchComments();
  }

  /// 自分のコメントを削除する
  Future<bool> deleteComment(String commentId) async {
    try {
      final supabase = _ref.read(supabaseProvider);
      await supabase.from('bbs_comments').delete().eq('id', commentId);
      await fetchComments();
      return true;
    } catch (e) {
      debugPrint('deleteComment error: $e');
      return false;
    }
  }

  /// コメント1件(とその返信)がブロック済み・非表示か
  bool _shouldHide(BbsComment c) {
    return _hiddenCommentIds.contains(c.id);
  }

  Future<void> fetchComments() async {
    try {
      final supabase = _ref.read(supabaseProvider);
      final currentUserId = _ref.read(currentUserIdProvider);
      // ブロック済みユーザーのコメントは表示しない
      final blocked = _ref.read(blockedUserIdsProvider).toSet();

      // コメント一覧を取得 (古い順、いいねフラグ付き)
      final response = await supabase.rpc('get_bbs_comments_with_status', params: {
        'p_post_id': postId,
        'p_user_id': currentUserId,
      });

      List<BbsComment> allComments = [];

      for (var item in response) {
        final userData = item['users'];
        final user = userData != null ? Users.fromMap(userData) : null;
        final isLiked = item['is_liked_by_me'] ?? false;
        allComments.add(BbsComment.fromMap(item, user: user, isLikedByMe: isLiked));
      }

      // ブロック済みユーザーのコメントを除外
      allComments = allComments.where((c) => !blocked.contains(c.userId)).toList();

      // すべてのコメントをMapに保持しておく
      Map<String, BbsComment> commentMap = {};
      for (var c in allComments) {
        commentMap[c.id] = c;
      }

      // あるコメントの最も大元のルートコメント(parentCommentIdがnullのコメント)のIDを探す関数
      String? findRootId(String? parentId) {
        if (parentId == null) return null;
        var current = commentMap[parentId];
        while (current != null && current.parentCommentId != null) {
          current = commentMap[current.parentCommentId];
        }
        return current?.id ?? parentId;
      }

      // ルートコメントを抽出
      List<BbsComment> rootComments = allComments.where((c) => c.parentCommentId == null).toList();
      
      // ルートごとの子孫リストを集めるマップ
      Map<String, List<BbsComment>> repliesMap = {};
      for (var c in rootComments) {
        repliesMap[c.id] = [];
      }

      // 子孫コメントを対応するルートのリストに追加
      for (var c in allComments) {
        if (c.parentCommentId != null) {
          final rootId = findRootId(c.parentCommentId);
          if (rootId != null && repliesMap.containsKey(rootId)) {
            repliesMap[rootId]!.add(c);
          }
        }
      }

      for (int i = 0; i < rootComments.length; i++) {
        final replies = repliesMap[rootComments[i].id] ?? [];
        // 非表示にしたコメントは返信も含めて除外
        final visibleReplies = replies
            .where((r) => !_shouldHide(r))
            .toList();
        rootComments[i] = rootComments[i].copyWith(replies: visibleReplies);
      }

      // ルート自体が非表示なら除外
      rootComments = rootComments.where((c) => !_shouldHide(c)).toList();

      state = AsyncValue.data(rootComments);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// コメントを追加し、新しいコメントのIDを返す（レスバ添付時に使用）
  /// [allowEmpty] = true なら本文が空でも作成する（レスバだけの送信に対応）
  Future<String?> addComment(String content, {String? parentCommentId, String? imageUrl, bool allowEmpty = false}) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return null;
    if (content.trim().isEmpty && !allowEmpty) return null;

    try {
      final supabase = _ref.read(supabaseProvider);
      final response = await supabase.from('bbs_comments').insert({
        'post_id': postId,
        'user_id': currentUserId,
        'parent_comment_id': parentCommentId,
        'content': content.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
      }).select('id').single();
      // 投稿後、コメント数を増やす
      await supabase.rpc('increment_replies_count', params: {'p_post_id': postId});
      
      // Timeline側も更新する
      if (_ref.read(bbsTimelineProvider) is AsyncData) {
        _ref.read(bbsTimelineProvider.notifier).incrementReplyCountLocally(postId);
      }
      
      await fetchComments();
      return response['id'] as String?;
    } catch (e) {
      debugPrint('addComment error: $e');
      rethrow;
    }
  }

  Future<void> toggleLike(BbsComment comment) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final supabase = _ref.read(supabaseProvider);
    final isLiked = comment.isLikedByMe;
    final newLikesCount = isLiked ? comment.likesCount - 1 : comment.likesCount + 1;

    // 楽観的UI更新
    if (state is AsyncData) {
      final comments = state.value!;
      final newComments = comments.map((c) {
        if (c.id == comment.id) {
          return c.copyWith(
            isLikedByMe: !isLiked,
            likesCount: newLikesCount >= 0 ? newLikesCount : 0,
          );
        }
        
        if (c.replies.isNotEmpty) {
          final newReplies = c.replies.map((r) {
            if (r.id == comment.id) {
              return r.copyWith(
                isLikedByMe: !isLiked,
                likesCount: newLikesCount >= 0 ? newLikesCount : 0,
              );
            }
            return r;
          }).toList();
          return c.copyWith(replies: newReplies);
        }
        return c;
      }).toList();
      state = AsyncValue.data(newComments);
    }

    try {
      if (isLiked) {
        await supabase
            .from('bbs_comment_likes')
            .delete()
            .match({'comment_id': comment.id, 'user_id': currentUserId});
        // トリガーで自動カウント更新されるため削除
      } else {
        await supabase
            .from('bbs_comment_likes')
            .insert({'comment_id': comment.id, 'user_id': currentUserId});
        // トリガーで自動カウント更新されるため削除
      }
      await fetchComments();
    } catch (e) {
      debugPrint('toggleLike error: $e');
    }
  }
}
