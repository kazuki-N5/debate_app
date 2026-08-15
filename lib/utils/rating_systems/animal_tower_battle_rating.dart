// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:math' as math;

/// どうぶつタワーバトルのレーティング（イロレーティング）システム
/// 1500から始まり、相手との実力差を数学的に計算してレーティングを増減させます。
class AnimalTowerBattleRating {
  /// 定数K（一試合の最大の変動幅）。通常32程度が使われます。
  static const double kValue = 32.0;

  /// 新しいレーティングを計算します。
  /// [currentRating] 自分の現在のレーティング
  /// [opponentRating] 相手の現在のレーティング
  /// [outcome] 結果 (1.0 = 勝利, 0.5 = 引き分け, 0.0 = 敗北)
  static int calculateNewRating(int currentRating, int opponentRating, double outcome) {
    // 期待勝率の計算: E = 1 / (1 + 10^((R_opponent - R_self) / 400))
    double expectedOutcome = 1.0 / (1.0 + math.pow(10, (opponentRating - currentRating) / 400.0));
    
    // レーティング更新: R_new = R_old + K * (Outcome - ExpectedOutcome)
    double newRating = currentRating + kValue * (outcome - expectedOutcome);
    
    return newRating.round();
  }

  /// 変動量のみを取得します。
  static int calculateChange(int currentRating, int opponentRating, double outcome) {
    int next = calculateNewRating(currentRating, opponentRating, outcome);
    return next - currentRating;
  }
}
