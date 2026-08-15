// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:math' as math;

/// クラッシュ・ロワイヤルのトロフィー計算システム
/// ELOシステムに基づき、対戦相手とのトロフィー差によって増減が変動します。
class ClashRoyaleRating {
  /// トロフィー変動を計算します。
  /// [playerTrophies] 自分のトロフィー
  /// [opponentTrophies] 相手のトロフィー
  /// [isWin] 勝利したかどうか
  /// [arenaGate] 到達済みのアリーナゲート（これ以下には下がらない）
  static int calculateChange(int playerTrophies, int opponentTrophies, bool isWin, {int arenaGate = 0}) {
    // 基準となる増減値
    const int baseChange = 30;
    
    // トロフィー差による補正 (10〜12の差で1トロフィー変動)
    double diff = (opponentTrophies - playerTrophies).toDouble();
    int adjustment = (diff / 10).round();
    
    int result;
    if (isWin) {
      // 格上に勝てば多く貰え、格下に勝てば少ない。
      result = math.max(10, math.min(50, baseChange + adjustment));
    } else {
      // 格上に負ければ減りは少なく、格下に負ければ大幅に減る。
      result = -math.max(10, math.min(50, baseChange - adjustment));
    }

    // アリーナゲート（トロフィー保護）の考慮
    if (!isWin && (playerTrophies + result < arenaGate)) {
      return arenaGate - playerTrophies;
    }

    return result;
  }
}
