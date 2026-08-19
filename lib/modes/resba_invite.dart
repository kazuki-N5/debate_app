// ignore_for_file: file_names
/// ポスト型レスバへの応募者（先頭1件・ホストのみ）
class ResbaApplication {
  final String id;
  final String applicantId;
  final String? applicantName;
  final String? applicantAvatar;
  final int? applicantTrophy;

  const ResbaApplication({
    required this.id,
    required this.applicantId,
    this.applicantName,
    this.applicantAvatar,
    this.applicantTrophy,
  });

  factory ResbaApplication.fromJson(Map<String, dynamic> json) {
    return ResbaApplication(
      id: json['id'] as String,
      applicantId: json['applicant_id'] as String,
      applicantName: json['applicant_name'] as String?,
      applicantAvatar: json['applicant_avatar'] as String?,
      applicantTrophy: json['applicant_trophy'] as int?,
    );
  }
}

/// ホスト側の「保留中の応募」1件（応募キュー表示用）
class HostApplication {
  final String applicationId;
  final String inviteId;
  final String theme;
  final String? choice1;
  final String? choice2;
  final String attachType; // post / comment
  final String attachId;
  final String applicantId;
  final String? applicantName;
  final String? applicantAvatar;
  final int? applicantTrophy;
  final DateTime createdAt;

  const HostApplication({
    required this.applicationId,
    required this.inviteId,
    required this.theme,
    this.choice1,
    this.choice2,
    required this.attachType,
    required this.attachId,
    required this.applicantId,
    this.applicantName,
    this.applicantAvatar,
    this.applicantTrophy,
    required this.createdAt,
  });

  factory HostApplication.fromJson(Map<String, dynamic> json) {
    return HostApplication(
      applicationId: json['application_id'] as String,
      inviteId: json['invite_id'] as String,
      theme: json['theme'] as String? ?? 'レスバ対戦',
      choice1: json['choice1'] as String?,
      choice2: json['choice2'] as String?,
      attachType: json['attach_type'] as String? ?? 'post',
      attachId: json['attach_id'] as String,
      applicantId: json['applicant_id'] as String,
      applicantName: json['applicant_name'] as String?,
      applicantAvatar: json['applicant_avatar'] as String?,
      applicantTrophy: (json['applicant_trophy'] as num?)?.toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }
}

/// コンテンツ融合型レスバ（対戦招待）のモデル
class ResbaInvite {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final int? senderTrophy;
  final String attachType; // post / comment / dm
  final String attachId;
  final String? targetUserId;
  final String theme;
  final String? choice1;
  final String? choice2;
  final String status; // pending / accepted / declined / cancelled / finished
  final String? responderId;
  final String? battleRoomId;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final bool isSender;
  final bool isTarget;
  final String? myApplication; // pending / accepted / rejected / cancelled
  final ResbaApplication? firstApplication; // ポスト型・ホストのみ
  final int applicationCount; // 応募数（pending）

  const ResbaInvite({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.senderTrophy,
    required this.attachType,
    required this.attachId,
    this.targetUserId,
    required this.theme,
    this.choice1,
    this.choice2,
    required this.status,
    this.responderId,
    this.battleRoomId,
    required this.createdAt,
    this.respondedAt,
    this.isSender = false,
    this.isTarget = false,
    this.myApplication,
    this.firstApplication,
    this.applicationCount = 0,
  });

  factory ResbaInvite.fromJson(Map<String, dynamic> json) {
    return ResbaInvite(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
      senderTrophy: json['sender_trophy'] as int?,
      attachType: json['attach_type'] as String,
      attachId: json['attach_id'] as String,
      targetUserId: json['target_user_id'] as String?,
      theme: json['theme'] as String? ?? 'レスバ対戦',
      choice1: json['choice1'] as String?,
      choice2: json['choice2'] as String?,
      status: json['status'] as String? ?? 'pending',
      responderId: json['responder_id'] as String?,
      battleRoomId: json['battle_room_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String).toLocal()
          : null,
      isSender: json['is_sender'] as bool? ?? false,
      isTarget: json['is_target'] as bool? ?? false,
      myApplication: json['my_application'] as String?,
      firstApplication: json['first_application'] != null
          ? ResbaApplication.fromJson(
              json['first_application'] as Map<String, dynamic>)
          : null,
      applicationCount: (json['application_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// 募集中（相手待ち / 応募受付中）
  bool get isPending => status == 'pending';

  /// 対戦成立済み
  bool get isAccepted => status == 'accepted';

  /// 自分が既に応募中（ポスト型）
  bool get hasPendingApplication => myApplication == 'pending';

  bool get isFinished =>
      status == 'finished' || status == 'declined' || status == 'cancelled';
}
