// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
/// ブロスタ風のトロフィー計算システム（格差ボーナス対応）
class BrawlStarsRating {
  static const int underdogThreshold = 200; // 格差ボーナスと判定するレート差
  static const int underdogBonus = 4;    // 格差ボーナス分

  /// 対戦結果から、両プレイヤーそれぞれのトロフィー増減量を計算して返します。
  /// [player1Trophy] Player1 の現在のトロフィー
  /// [player2Trophy] Player2 の現在のトロフィー
  /// [winner] 勝利した側 ('A' = Player1, 'B' = Player2, その他 = 引き分け/エラー等)
  static Map<String, int> calculateMatchResult({
    required int player1Trophy,
    required int player2Trophy,
    required String winner,
  }) {
    int p1Change = 0;
    int p2Change = 0;

    if (winner == 'A') {
      // Player 1 勝ち / Player 2 負け
      p1Change = calculatePlayerChange(player1Trophy, player2Trophy, true);
      p2Change = calculatePlayerChange(player2Trophy, player1Trophy, false);
    } else if (winner == 'B') {
      // Player 2 勝ち / Player 1 負け
      p2Change = calculatePlayerChange(player2Trophy, player1Trophy, true);
      p1Change = calculatePlayerChange(player1Trophy, player2Trophy, false);
    } else {
      // 引き分けなどの救済措置
      p1Change = 0;
      p2Change = 0;
    }

    return {
      'player1': p1Change,
      'player2': p2Change,
    };
  }

  /// 個別のプレイヤーの増減量、ベースの変動、ボーナス、格差ボーナス判定を計算して返します。
  static ({int change, int baseChange, int bonus, bool isUnderdog}) calculatePlayerChangeDetail(
    int myTrophy,
    int opponentTrophy,
    bool isWin,
  ) {
    final bool isUnderdog = (opponentTrophy - myTrophy) >= underdogThreshold;
    final int baseChange = isWin ? _getWinGain(myTrophy) : _getLossPenalty(myTrophy);
    int bonus = 0;

    if (isUnderdog) {
      if (isWin) {
        bonus = underdogBonus;
      } else {
        // 敗北時。本来の減少量(負の値)を打ち消す方向に加算
        // ただし、減少量を超えて「増える」ことはない（上限：本来引かれる分まで）
        final int maxBonus = baseChange.abs();
        bonus = underdogBonus > maxBonus ? maxBonus : underdogBonus;
      }
    }

    final int change = baseChange + bonus;

    return (
      change: change,
      baseChange: baseChange,
      bonus: bonus,
      isUnderdog: isUnderdog,
    );
  }

  /// 個別のプレイヤーの増減量を計算（後方互換用）
  static int calculatePlayerChange(int myTrophy, int opponentTrophy, bool isWin) {
    return calculatePlayerChangeDetail(myTrophy, opponentTrophy, isWin).change;
  }

  /// 勝利時の増加量テーブル
  static int _getWinGain(int trophy) {
    if (trophy < 500) return 8;
    if (trophy < 600) return 7;
    if (trophy < 700) return 6;
    if (trophy < 800) return 5;
    if (trophy < 900) return 4;
    return 3;
  }

  /// 敗北時の減少量テーブル
  static int _getLossPenalty(int trophy) {
    if (trophy < 50) return 0;
    if (trophy < 100) return -1;
    if (trophy < 200) return -2;
    if (trophy < 300) return -3;
    if (trophy < 400) return -4;
    if (trophy < 500) return -5;
    if (trophy < 600) return -6;
    if (trophy < 700) return -7;
    if (trophy < 800) return -8;
    if (trophy < 900) return -9;
    if (trophy < 1000) return -10;
    if (trophy < 1100) return -11;
    return -12;
  }
}
