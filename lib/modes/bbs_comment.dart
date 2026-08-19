import 'package:debate_project/modes/users.dart';

class BbsComment {
  final String id;
  final String postId;
  final String userId;
  final String? parentCommentId;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final String? imageUrl;
  
  // JOIN用
  final Users? user;
  final bool isLikedByMe;
  final List<BbsComment> replies;
  final bool hasResba;

  BbsComment({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentCommentId,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.imageUrl,
    this.user,
    this.isLikedByMe = false,
    this.replies = const [],
    this.hasResba = false,
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
      imageUrl: map['image_url'] as String?,
      user: user,
      isLikedByMe: isLikedByMe,
      replies: replies,
      hasResba: map['has_resba'] as bool? ?? false,
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
    String? imageUrl,
    Users? user,
    bool? isLikedByMe,
    List<BbsComment>? replies,
    bool? hasResba,
  }) {
    return BbsComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      imageUrl: imageUrl ?? this.imageUrl,
      user: user ?? this.user,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      replies: replies ?? this.replies,
      hasResba: hasResba ?? this.hasResba,
    );
  }
}
