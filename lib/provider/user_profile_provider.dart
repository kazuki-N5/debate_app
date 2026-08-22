import 'package:debate_project/modes/bbs_comment.dart';
import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 返信タブ用アイテム（ユーザーの返信と、返信先の元ポスト・親コメントを保持）
class UserReplyItem {
  final BbsComment reply;
  final BbsPost? parentPost;
  final BbsComment? parentComment;

  UserReplyItem({
    required this.reply,
    this.parentPost,
    this.parentComment,
  });

  UserReplyItem copyWith({
    BbsComment? reply,
    BbsPost? parentPost,
    BbsComment? parentComment,
  }) {
    return UserReplyItem(
      reply: reply ?? this.reply,
      parentPost: parentPost ?? this.parentPost,
      parentComment: parentComment ?? this.parentComment,
    );
  }
}

// メディアタブ用アイテム（画像を含むポストまたは返信を保持）
enum UserMediaType { post, reply }

class UserMediaItem {
  final UserMediaType type;
  final BbsPost? post;
  final UserReplyItem? replyItem;
  final DateTime createdAt;

  UserMediaItem.post(BbsPost p)
      : type = UserMediaType.post,
        post = p,
        replyItem = null,
        createdAt = p.createdAt;

  UserMediaItem.reply(UserReplyItem r)
      : type = UserMediaType.reply,
        post = null,
        replyItem = r,
        createdAt = r.reply.createdAt;
}

// UserProfileStateは、特定のユーザーの情報、投稿一覧、返信一覧、メディア一覧、フォロー数・フォロワー数を保持します
class UserProfileState {
  final Users? user;
  final List<BbsPost> posts;
  final List<UserReplyItem> replies;
  final List<UserMediaItem> mediaItems;
  final int followingCount;
  final int followerCount;
  final bool isLoading;
  final String? errorMessage;

  UserProfileState({
    this.user,
    this.posts = const [],
    this.replies = const [],
    this.mediaItems = const [],
    this.followingCount = 0,
    this.followerCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  UserProfileState copyWith({
    Users? user,
    List<BbsPost>? posts,
    List<UserReplyItem>? replies,
    List<UserMediaItem>? mediaItems,
    int? followingCount,
    int? followerCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UserProfileState(
      user: user ?? this.user,
      posts: posts ?? this.posts,
      replies: replies ?? this.replies,
      mediaItems: mediaItems ?? this.mediaItems,
      followingCount: followingCount ?? this.followingCount,
      followerCount: followerCount ?? this.followerCount,
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

  Future<void> refreshProfile() async {
    await _fetchProfileAndPosts();
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

      // 2. フォロー数・フォロワー数の取得
      int followingCount = 0;
      int followerCount = 0;
      try {
        followingCount = await supabase
            .from('user_follows')
            .count(CountOption.exact)
            .eq('follower_id', _userId);

        followerCount = await supabase
            .from('user_follows')
            .count(CountOption.exact)
            .eq('followed_id', _userId);
      } catch (e) {
        log('fetch follow counts error: $e');
      }

      // 3. ユーザーのBBS投稿一覧を取得 (新しい順)
      final postsResponse = await supabase
          .from('bbs_posts')
          .select('*, users(*)')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(50);

      List<BbsPost> posts = [];
      Set<String> likedPostIds = {};

      if (currentUserId != null && postsResponse.isNotEmpty) {
        final postIds = postsResponse.map((p) => p['id'] as String).toList();
        try {
          final likesRes = await supabase
              .from('bbs_likes')
              .select('post_id')
              .eq('user_id', currentUserId)
              .inFilter('post_id', postIds);
          
          for (var row in likesRes) {
            likedPostIds.add(row['post_id'] as String);
          }
        } catch (e) {
          log('fetch post likes error: $e');
        }
      }

      for (var item in postsResponse) {
        final userData = item['users'];
        final postUser = userData != null ? Users.fromMap(userData) : null;
        final isLiked = likedPostIds.contains(item['id']);

        posts.add(BbsPost.fromMap(item, user: postUser, isLikedByMe: isLiked));
      }

      // 4. ユーザーの返信（リプライ）一覧を取得 (新しい順)
      final commentsResponse = await supabase
          .from('bbs_comments')
          .select('*, users(*)')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(50);

      List<UserReplyItem> replies = [];
      if (commentsResponse.isNotEmpty) {
        // 返信先の post_id のユニークリストを取得
        final postIds = commentsResponse
            .map((c) => c['post_id'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toSet()
            .toList();

        // 親ポストを一括取得
        Map<String, BbsPost> parentPostMap = {};
        if (postIds.isNotEmpty) {
          try {
            final parentPostsRes = await supabase
                .from('bbs_posts')
                .select('*, users(*)')
                .inFilter('id', postIds);

            // 親ポストのいいね状態も取得
            Set<String> parentLikedPostIds = {};
            if (currentUserId != null) {
              try {
                final pLikesRes = await supabase
                    .from('bbs_likes')
                    .select('post_id')
                    .eq('user_id', currentUserId)
                    .inFilter('post_id', postIds);
                for (var r in pLikesRes) {
                  parentLikedPostIds.add(r['post_id'] as String);
                }
              } catch (_) {}
            }

            for (var pItem in parentPostsRes) {
              final pUserData = pItem['users'];
              final pUser = pUserData != null ? Users.fromMap(pUserData) : null;
              final pIsLiked = parentLikedPostIds.contains(pItem['id']);
              parentPostMap[pItem['id'] as String] =
                  BbsPost.fromMap(pItem, user: pUser, isLikedByMe: pIsLiked);
            }
          } catch (e) {
            log('fetch parent posts error: $e');
          }
        }

        // 自分の返信へのいいね状態を取得
        Set<String> likedCommentIds = {};
        if (currentUserId != null) {
          try {
            final commentIds = commentsResponse.map((c) => c['id'] as String).toList();
            final cLikesRes = await supabase
                .from('bbs_comment_likes')
                .select('comment_id')
                .eq('user_id', currentUserId)
                .inFilter('comment_id', commentIds);
            for (var r in cLikesRes) {
              likedCommentIds.add(r['comment_id'] as String);
            }
          } catch (e) {
            log('fetch comment likes error: $e');
          }
        }

        for (var cItem in commentsResponse) {
          final cUserData = cItem['users'];
          final cUser = cUserData != null ? Users.fromMap(cUserData) : user;
          final cIsLiked = likedCommentIds.contains(cItem['id']);
          final comment = BbsComment.fromMap(cItem, user: cUser, isLikedByMe: cIsLiked);
          final parentPost = parentPostMap[comment.postId];

          replies.add(UserReplyItem(
            reply: comment,
            parentPost: parentPost,
          ));
        }
      }

      // 5. メディアアイテム（画像付きポスト ＋ 画像付き返信）を構築
      List<UserMediaItem> mediaItems = [];
      for (var p in posts) {
        if (p.imageUrls != null && p.imageUrls!.isNotEmpty) {
          mediaItems.add(UserMediaItem.post(p));
        }
      }
      for (var r in replies) {
        if (r.reply.imageUrl != null && r.reply.imageUrl!.isNotEmpty) {
          mediaItems.add(UserMediaItem.reply(r));
        }
      }
      // 日時が新しい順にソート
      mediaItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        user: user,
        posts: posts,
        replies: replies,
        mediaItems: mediaItems,
        followingCount: followingCount,
        followerCount: followerCount,
        isLoading: false,
      );
    } catch (e) {
      log('fetchProfileAndPosts error: $e');
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

    // 楽観的UI更新 (posts & mediaItems & repliesのparentPost)
    final newPosts = state.posts.map((p) {
      if (p.id == post.id) {
        return p.copyWith(
          isLikedByMe: !isLiked,
          likesCount: newLikesCount >= 0 ? newLikesCount : 0,
        );
      }
      return p;
    }).toList();

    final newMedia = state.mediaItems.map((m) {
      if (m.type == UserMediaType.post && m.post?.id == post.id) {
        return UserMediaItem.post(m.post!.copyWith(
          isLikedByMe: !isLiked,
          likesCount: newLikesCount >= 0 ? newLikesCount : 0,
        ));
      }
      return m;
    }).toList();

    final newReplies = state.replies.map((r) {
      if (r.parentPost?.id == post.id) {
        return r.copyWith(
          parentPost: r.parentPost!.copyWith(
            isLikedByMe: !isLiked,
            likesCount: newLikesCount >= 0 ? newLikesCount : 0,
          ),
        );
      }
      return r;
    }).toList();

    state = state.copyWith(
      posts: newPosts,
      mediaItems: newMedia,
      replies: newReplies,
    );

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
      await _fetchProfileAndPosts();
    }
  }

  Future<void> toggleReplyLike(BbsComment comment) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final supabase = _ref.read(supabaseProvider);
    final isLiked = comment.isLikedByMe;
    final newLikesCount = isLiked ? comment.likesCount - 1 : comment.likesCount + 1;

    // 楽観的UI更新
    final newReplies = state.replies.map((r) {
      if (r.reply.id == comment.id) {
        return r.copyWith(
          reply: r.reply.copyWith(
            isLikedByMe: !isLiked,
            likesCount: newLikesCount >= 0 ? newLikesCount : 0,
          ),
        );
      }
      return r;
    }).toList();

    final newMedia = state.mediaItems.map((m) {
      if (m.type == UserMediaType.reply && m.replyItem?.reply.id == comment.id) {
        return UserMediaItem.reply(m.replyItem!.copyWith(
          reply: m.replyItem!.reply.copyWith(
            isLikedByMe: !isLiked,
            likesCount: newLikesCount >= 0 ? newLikesCount : 0,
          ),
        ));
      }
      return m;
    }).toList();

    state = state.copyWith(
      replies: newReplies,
      mediaItems: newMedia,
    );

    try {
      if (isLiked) {
        await supabase
            .from('bbs_comment_likes')
            .delete()
            .match({'comment_id': comment.id, 'user_id': currentUserId});
      } else {
        await supabase
            .from('bbs_comment_likes')
            .insert({'comment_id': comment.id, 'user_id': currentUserId});
      }
    } catch (e) {
      log('toggleReplyLike error: $e');
      await _fetchProfileAndPosts();
    }
  }
}

