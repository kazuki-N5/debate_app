// ignore_for_file: file_names
/// プッシュ通知の設定 (notification_settings テーブル対応)
class NotificationSettingsModel {
  final bool isNotificationEnabled; // マスター (プッシュ全体のON/OFF)
  final bool likeEnabled; // いいね (like_post / like_comment)
  final bool commentEnabled; // コメント・返信 (comment / reply_comment)
  final bool followEnabled; // フォロー
  final bool dmEnabled; // DM
  final bool openChatEnabled; // オプチャ
  final bool matchWaitingEnabled; // 対戦待ち

  const NotificationSettingsModel({
    this.isNotificationEnabled = false,
    this.likeEnabled = true,
    this.commentEnabled = true,
    this.followEnabled = true,
    this.dmEnabled = true,
    this.openChatEnabled = true,
    this.matchWaitingEnabled = true,
  });

  factory NotificationSettingsModel.fromMap(Map<String, dynamic> map) {
    return NotificationSettingsModel(
      isNotificationEnabled: map['is_notification_enabled'] as bool? ?? false,
      likeEnabled: map['like_enabled'] as bool? ?? true,
      commentEnabled: map['comment_enabled'] as bool? ?? true,
      followEnabled: map['follow_enabled'] as bool? ?? true,
      dmEnabled: map['dm_enabled'] as bool? ?? true,
      openChatEnabled: map['open_chat_enabled'] as bool? ?? true,
      matchWaitingEnabled: map['match_waiting_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'is_notification_enabled': isNotificationEnabled,
        'like_enabled': likeEnabled,
        'comment_enabled': commentEnabled,
        'follow_enabled': followEnabled,
        'dm_enabled': dmEnabled,
        'open_chat_enabled': openChatEnabled,
        'match_waiting_enabled': matchWaitingEnabled,
      };

  NotificationSettingsModel copyWith({
    bool? isNotificationEnabled,
    bool? likeEnabled,
    bool? commentEnabled,
    bool? followEnabled,
    bool? dmEnabled,
    bool? openChatEnabled,
    bool? matchWaitingEnabled,
  }) {
    return NotificationSettingsModel(
      isNotificationEnabled:
          isNotificationEnabled ?? this.isNotificationEnabled,
      likeEnabled: likeEnabled ?? this.likeEnabled,
      commentEnabled: commentEnabled ?? this.commentEnabled,
      followEnabled: followEnabled ?? this.followEnabled,
      dmEnabled: dmEnabled ?? this.dmEnabled,
      openChatEnabled: openChatEnabled ?? this.openChatEnabled,
      matchWaitingEnabled: matchWaitingEnabled ?? this.matchWaitingEnabled,
    );
  }
}
