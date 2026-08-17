// ignore_for_file: file_names
import 'package:debate_project/modes/bbs_comment.dart';
import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/modes/users.dart';

/// アプリ内通知(いいね/フォロー/返信)のモデル
class AppNotification {
  final String id;
  final String userId; // 通知を受け取るユーザー
  final String actorId; // 通知を発生させたユーザー
  final String type; // like_post / like_comment / follow / reply_comment
  final String? postId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;

  // JOIN で取得した情報
  final Users? actor;
  final BbsPost? post;
  final BbsComment? comment;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    this.postId,
    this.commentId,
    this.isRead = false,
    required this.createdAt,
    this.actor,
    this.post,
    this.comment,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    Users? actor;
    final actorData = map['actor'];
    if (actorData != null) {
      actor = Users.fromMap(actorData as Map<String, dynamic>);
    }

    BbsPost? post;
    final postData = map['post'];
    if (postData != null) {
      post = BbsPost.fromMap(postData as Map<String, dynamic>);
    }

    BbsComment? comment;
    final commentData = map['comment'];
    if (commentData != null) {
      comment = BbsComment.fromMap(commentData as Map<String, dynamic>);
    }

    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      actorId: map['actor_id'] as String,
      type: map['type'] as String,
      postId: map['post_id'] as String?,
      commentId: map['comment_id'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      actor: actor,
      post: post,
      comment: comment,
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? actorId,
    String? type,
    String? postId,
    String? commentId,
    bool? isRead,
    DateTime? createdAt,
    Users? actor,
    BbsPost? post,
    BbsComment? comment,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      actorId: actorId ?? this.actorId,
      type: type ?? this.type,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actor: actor ?? this.actor,
      post: post ?? this.post,
      comment: comment ?? this.comment,
    );
  }

  /// アクターの表示名
  String get actorName => actor?.name ?? '不明なユーザー';

  /// アクターのアバターURL
  String? get actorAvatarUrl => actor?.avatar_url;

  /// 通知の本文となる引用テキスト (コメント通知はコメント本文を優先表示)
  String get quoteText {
    if (comment != null && comment!.content.isNotEmpty) return comment!.content;
    if (post != null && post!.content.isNotEmpty) return post!.content;
    return '';
  }
}
