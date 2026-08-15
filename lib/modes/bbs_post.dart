import 'package:debate_project/modes/users.dart';

class BbsPost {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final int repliesCount;
  
  // JOIN用
  final Users? user;
  final bool isLikedByMe;

  BbsPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.user,
    this.isLikedByMe = false,
  });

  factory BbsPost.fromMap(Map<String, dynamic> map, {Users? user, bool isLikedByMe = false}) {
    return BbsPost(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      likesCount: map['likes_count'] as int? ?? 0,
      repliesCount: map['replies_count'] as int? ?? 0,
      user: user,
      isLikedByMe: isLikedByMe,
    );
  }

  BbsPost copyWith({
    String? id,
    String? userId,
    String? content,
    DateTime? createdAt,
    int? likesCount,
    int? repliesCount,
    Users? user,
    bool? isLikedByMe,
  }) {
    return BbsPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      repliesCount: repliesCount ?? this.repliesCount,
      user: user ?? this.user,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}
