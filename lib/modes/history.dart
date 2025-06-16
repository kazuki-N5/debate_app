class MatchRecordDisplay {
  final String roomid;
  final String resultString; // "勝利" or "敗北"
  final int trophyChange; // +value or -value
  final String opponentName;
  final String? opponentAvatarUrl; // <-- ADDED: Make it nullable
  final String theme;
  final String userChoice;
  final String reason;

  MatchRecordDisplay({
    required this.roomid,
    required this.resultString,
    required this.trophyChange,
    required this.opponentName,
    this.opponentAvatarUrl, // <-- ADDED: Update constructor
    required this.theme,
    required this.userChoice,
    required this.reason,
  });
}