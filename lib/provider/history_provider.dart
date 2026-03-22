// lib/provider/history_provider.dart (またはプロバイダが定義されているファイル)

import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- ▼ 1. SharedPreferencesをインポートします ---
import 'package:shared_preferences/shared_preferences.dart';

final matchRecordsProvider =
    FutureProvider<List<MatchRecordDisplay>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  if (currentUserId == null) {
    print("User not logged in, cannot fetch match history.");
    return [];
  }

  try {
    // --- ▼ 2. SharedPreferencesからブロック済みのルームIDリストを取得 ---
    final prefs = await SharedPreferences.getInstance();
    final blockedRoomIds = prefs.getStringList('blocked_room_ids') ?? [];
    // 高速な検索のためにSetに変換
    final blockedRoomIdsSet = blockedRoomIds.toSet();
    // --- ▲ 修正ここまで ---

    final List<Map<String, dynamic>>? data = await supabase
        .from('match_record')
        .select(
            '*, player1:player1_id(name, avatar_url), player2:player2_id(name, avatar_url)')
        .or('player1_id.eq.$currentUserId,player2_id.eq.$currentUserId')
        .order('created_at', ascending: false)
        .limit(30)
        .then((data) => List<Map<String, dynamic>>.from(data));

    if (data == null) {
      return [];
    }

    return data.expand<MatchRecordDisplay>((record) {
      final roomid = record['roomid'] as String;

      // --- ▼ 3. 最初にブロック済みIDかどうかをチェック ---
      // もしこのルームIDがブロックリストに含まれていたら、このレコードは処理せずスキップ
      if (blockedRoomIdsSet.contains(roomid)) {
        return []; // expand なので空リストを返すと、この要素は結果から除外される
      }
      // --- ▲ 修正ここまで ---

      // --- これ以降は元のロジックのまま ---
      final winnerId = record['winner'] as String?;
      final player1Id = record['player1_id'] as String?;
      final player2Id = record['player2_id'] as String?;
      final theme = record['theme'] as String? ?? '';
      final player1Choice = record['player1_choice'] as String? ?? '';
      final player2Choice = record['player2_choice'] as String? ?? '';
      final cancel = record['cancel'] as bool? ?? false;

      String opponentName = 'Unknown Opponent';
      String? opponentAvatarUrl;
      String myname = 'Unknown Player';
      String? opponentid;

      if (currentUserId == player1Id) {
        opponentid = player2Id;
        if (record['player1'] is Map<String, dynamic>) {
          myname = (record['player1'] as Map<String, dynamic>)['name'] as String? ?? 'Unknown Player';
        }
        if (record['player2'] is Map<String, dynamic>) {
          final player2Data = record['player2'] as Map<String, dynamic>;
          opponentName = player2Data['name'] as String? ?? 'Unknown Opponent';
          opponentAvatarUrl = player2Data['avatar_url'] as String?;
        }
      } else if (currentUserId == player2Id) {
        opponentid = player1Id;
        if (record['player2'] is Map<String, dynamic>) {
           myname = (record['player2'] as Map<String, dynamic>)['name'] as String? ?? 'Unknown Player';
        }
        if (record['player1'] is Map<String, dynamic>) {
          final player1Data = record['player1'] as Map<String, dynamic>;
          opponentName = player1Data['name'] as String? ?? 'Unknown Opponent';
          opponentAvatarUrl = player1Data['avatar_url'] as String?;
        }
      }
      
      final userChoice = (currentUserId == player1Id)
          ? player1Choice
          : (currentUserId == player2Id ? player2Choice : 'N/A');
      
      if (cancel) {
        if (currentUserId == winnerId) {
          return [];
        } else {
          return [
            MatchRecordDisplay(
              roomid: roomid,
              resultString: '敗北',
              trophyChange: -3,
              opponentName: opponentName,
              opponentAvatarUrl: opponentAvatarUrl,
              opponentid: opponentid,
              theme: theme,
              userChoice: userChoice,
              reason: 'キャンセルした',
              cancel: true,
            )
          ];
        }
      } else {
        // 新しい個別カラムを取得
        final p1Move = record['player1_move_trophy'] as int?;
        final p2Move = record['player2_move_trophy'] as int?;
        final isUnderdog = record['is_underdog'] as bool? ?? false;
        final moveTrophyLegacy = record['move_trophy'] as int? ?? 0;

        final isWinner = winnerId != null && currentUserId == winnerId;
        final resultString = isWinner ? '勝利' : '敗北';

        // 自分のプレイヤーIDに応じて、正しい増減値を採用する
        int trophyChange;
        if (currentUserId == player1Id) {
          trophyChange = p1Move ?? (isWinner ? moveTrophyLegacy : -moveTrophyLegacy);
        } else {
          trophyChange = p2Move ?? (isWinner ? moveTrophyLegacy : -moveTrophyLegacy);
        }

        final resultReason = record['result'] as String? ?? '';
        String formattedReason = resultReason;
        String formatName(String name) => "'$name'";
        if (formattedReason.isNotEmpty) {
          formattedReason = formattedReason.trim();
          if (currentUserId == player1Id) {
            formattedReason = formattedReason.replaceAll('A', formatName(myname));
            formattedReason = formattedReason.replaceAll('B', formatName(opponentName));
          } else {
            formattedReason = formattedReason.replaceAll('A', formatName(opponentName));
            formattedReason = formattedReason.replaceAll('B', formatName(myname));
          }
        }
        return [
          MatchRecordDisplay(
            roomid: roomid,
            resultString: resultString,
            trophyChange: trophyChange,
            opponentName: opponentName,
            opponentAvatarUrl: opponentAvatarUrl,
            opponentid: opponentid,
            theme: theme,
            userChoice: userChoice,
            reason: formattedReason.isEmpty ? '理由がありませんでした。' : formattedReason,
            cancel: false,
            isUnderdog: isUnderdog,
            player1MoveTrophy: p1Move,
            player2MoveTrophy: p2Move,
          )
        ];
      }
    }).toList();
  } catch (e) {
    print('Error fetching match records: $e');
    throw Exception('Failed to load match history: $e');
  }
});