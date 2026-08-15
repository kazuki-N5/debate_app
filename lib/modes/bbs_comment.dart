import 'package:debate_project/modes/users.dart';

class BbsComment {
  final String id;
  final String postId;
  final String userId;
  final String? parentCommentId;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  
  // JOIN用
  final Users? user;
  final bool isLikedByMe;
  final List<BbsComment> replies;

  BbsComment({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentCommentId,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.user,
    this.isLikedByMe = false,
    this.replies = const [],
  });

  factory BbsComment.fromMap(Map<String, dynamic> map, {Users? user, bool isLikedByMe = false, List<BbsComment> replies = const []}) {
    return BbsComment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      parentCommentId: map['parent_comment_id'] as String?,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      likesCount: map['likes_count'] as int? ?? 0,
      user: user,
      isLikedByMe: isLikedByMe,
      replies: replies,
    );
  }

  BbsComment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? parentCommentId,
    String? content,
    DateTime? createdAt,
    int? likesCount,
    Users? user,
    bool? isLikedByMe,
    List<BbsComment>? replies,
  }) {
    return BbsComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      user: user ?? this.user,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      replies: replies ?? this.replies,
    );
  }
}
