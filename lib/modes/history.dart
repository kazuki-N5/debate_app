// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
class MatchRecordDisplay {
  final String roomid;
  final String resultString; // "勝利" or "敗北"
  final int trophyChange; // 自分の増減 (+value or -value)
  final String opponentName;
  final String? opponentAvatarUrl;
  final String theme;
  final String userChoice;
  final String reason;
  final bool? cancel;
  final String? opponentid;
  final bool isUnderdog; // この試合が格差ボーナス対象だったか

  // DBの個別移動値を保存するカラムに対応
  final int? player1MoveTrophy;
  final int? player2MoveTrophy;

  MatchRecordDisplay({
    required this.roomid,
    required this.resultString,
    required this.trophyChange,
    required this.opponentName,
    this.opponentAvatarUrl,
    required this.theme,
    required this.userChoice,
    required this.reason,
    this.cancel,
    this.opponentid,
    this.isUnderdog = false,
    this.player1MoveTrophy,
    this.player2MoveTrophy,
  });
}
