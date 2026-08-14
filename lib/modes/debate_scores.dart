import 'dart:convert';

/// ディベートの個別スコア項目
class PlayerScore {
  final int logic; // 論理性
  final int persuasion; // 説得力
  final int rebuttal; // 反論力
  final int structure; // 構成力
  final int manner; // マナー

  const PlayerScore({
    this.logic = 70,
    this.persuasion = 70,
    this.rebuttal = 70,
    this.structure = 70,
    this.manner = 70,
  });

  /// 総合論理能力（%）: 5項目の平均スコア
  int get totalPercentage {
    final sum = logic + persuasion + rebuttal + structure + manner;
    return (sum / 5).round().clamp(0, 100);
  }

  /// 項目名と値のマップ
  Map<String, int> toCategoryMap() {
    return {
      '論理性': logic,
      '説得力': persuasion,
      '反論力': rebuttal,
      '構成力': structure,
      'マナー': manner,
    };
  }

  factory PlayerScore.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlayerScore();

    int parseScore(dynamic value, int fallback) {
      if (value is int) return value.clamp(0, 100);
      if (value is double) return value.round().clamp(0, 100);
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed.clamp(0, 100);
      }
      return fallback;
    }

    return PlayerScore(
      logic: parseScore(map['logic'] ?? map['logic_score'], 70),
      persuasion: parseScore(map['persuasion'] ?? map['persuasion_score'], 70),
      rebuttal: parseScore(map['rebuttal'] ?? map['rebuttal_score'], 70),
      structure: parseScore(map['structure'] ?? map['structure_score'], 70),
      manner: parseScore(map['manner'] ?? map['manner_score'], 70),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logic': logic,
      'persuasion': persuasion,
      'rebuttal': rebuttal,
      'structure': structure,
      'manner': manner,
    };
  }
}

/// 試合全体のスコア（Player A, Player B）
class MatchScores {
  final PlayerScore playerA;
  final PlayerScore playerB;

  const MatchScores({
    this.playerA = const PlayerScore(),
    this.playerB = const PlayerScore(),
  });

  /// プレイヤー1（A）またはプレイヤー2（B）に応じた自分のスコアを取得
  PlayerScore getMyScore(bool isPlayer1) => isPlayer1 ? playerA : playerB;

  /// 相手のスコアを取得
  PlayerScore getOpponentScore(bool isPlayer1) => isPlayer1 ? playerB : playerA;

  factory MatchScores.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MatchScores();

    // { "player_a": { ... }, "player_b": { ... } } または { "scores": { ... } } などを安全にパース
    final scoresMap = map.containsKey('scores') && map['scores'] is Map<String, dynamic>
        ? map['scores'] as Map<String, dynamic>
        : map;

    final playerAMap = scoresMap['player_a'] ?? scoresMap['player1'] ?? scoresMap['A'];
    final playerBMap = scoresMap['player_b'] ?? scoresMap['player2'] ?? scoresMap['B'];

    return MatchScores(
      playerA: PlayerScore.fromMap(playerAMap is Map<String, dynamic> ? playerAMap : null),
      playerB: PlayerScore.fromMap(playerBMap is Map<String, dynamic> ? playerBMap : null),
    );
  }

  factory MatchScores.fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return const MatchScores();
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return MatchScores.fromMap(decoded);
      }
    } catch (_) {}
    return const MatchScores();
  }

  Map<String, dynamic> toMap() {
    return {
      'player_a': playerA.toMap(),
      'player_b': playerB.toMap(),
    };
  }
}
