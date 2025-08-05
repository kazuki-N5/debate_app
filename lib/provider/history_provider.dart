// lib/provider/supabase_provider.dart など、このプロバイダが定義されているファイル

import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final matchRecordsProvider =
    FutureProvider<List<MatchRecordDisplay>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  if (currentUserId == null) {
    print("User not logged in, cannot fetch match history.");
    return [];
  }

  try {
    // クエリは元のままでも良いですが、将来のためにidも取得しておくとより安全です。
    // .select('*, player1:player1_id(id, name, avatar_url), player2:player2_id(id, name, avatar_url)')
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

    // expand を使用して、条件に応じてレコードをフィルタリングまたは変換する
    return data.expand<MatchRecordDisplay>((record) {
      // --- 共通の変数を先に宣言 ---
      final roomid = record['roomid'] as String;
      final winnerId = record['winner'] as String?;
      final player1Id = record['player1_id'] as String?;
      final player2Id = record['player2_id'] as String?;
      final theme = record['theme'] as String? ?? '';
      final player1Choice = record['player1_choice'] as String? ?? '';
      final player2Choice = record['player2_choice'] as String? ?? '';
      final cancel = record['cancel'] as bool? ?? false;

      // --- 相手と自分の情報を特定 ---
      String opponentName = 'Unknown Opponent';
      String? opponentAvatarUrl;
      String myname = 'Unknown Player';
      
      // --- 修正箇所 ---
      // ネストされたMapからIDを取得するのではなく、レコードに直接含まれるIDを使用します。
      // これが最も確実な方法です。
      String? opponentid; 

      if (currentUserId == player1Id) {
        // 自分はplayer1なので、相手はplayer2
        opponentid = player2Id; // ★★★ これが重要な修正点 ★★★

        if (record['player1'] is Map<String, dynamic>) {
          myname = (record['player1'] as Map<String, dynamic>)['name'] as String? ?? 'Unknown Player';
        }
        if (record['player2'] is Map<String, dynamic>) {
          final player2Data = record['player2'] as Map<String, dynamic>;
          opponentName = player2Data['name'] as String? ?? 'Unknown Opponent';
          opponentAvatarUrl = player2Data['avatar_url'] as String?;
        }

      } else if (currentUserId == player2Id) {
        // 自分はplayer2なので、相手はplayer1
        opponentid = player1Id; // ★★★ これが重要な修正点 ★★★

        if (record['player2'] is Map<String, dynamic>) {
           myname = (record['player2'] as Map<String, dynamic>)['name'] as String? ?? 'Unknown Player';
        }
        if (record['player1'] is Map<String, dynamic>) {
          final player1Data = record['player1'] as Map<String, dynamic>;
          opponentName = player1Data['name'] as String? ?? 'Unknown Opponent';
          opponentAvatarUrl = player1Data['avatar_url'] as String?;
        }
      }
      // --- 修正ここまで ---

      // --- 自分の選択を特定 ---
      final userChoice = (currentUserId == player1Id)
          ? player1Choice
          : (currentUserId == player2Id ? player2Choice : 'N/A');

      // --- 条件分岐 ---
      if (cancel) {
        if (currentUserId == winnerId) {
          // キャンセル勝ちした側は、この履歴を表示しない
          return []; // expand なので空リストを返すと、この要素は結果から除外される
        } else {
          // キャンセル負けした側の表示
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
              cancel: true, // cancel フラグを true に設定
            )
          ];
        }
      } else {
        // --- 通常の対戦結果の処理 ---
        final moveTrophy = record['move_trophy'] as int? ?? 0;
        final resultReason = record['result'] as String? ?? '';

        final isWinner = winnerId != null && currentUserId == winnerId;
        final resultString = isWinner ? '勝利' : '敗北';
        final trophyChange = isWinner ? moveTrophy : -moveTrophy;

        // --- 理由のフォーマット ---
        String formattedReason = resultReason;
        String formatName(String name) => "'$name'";

        if (formattedReason.isNotEmpty) {
          formattedReason = formattedReason.substring(1).trim();
          if (currentUserId == player1Id) {
            formattedReason =
                formattedReason.replaceAll('A', formatName(myname));
            formattedReason =
                formattedReason.replaceAll('B', formatName(opponentName));
          } else {
            formattedReason =
                formattedReason.replaceAll('A', formatName(opponentName));
            formattedReason =
                formattedReason.replaceAll('B', formatName(myname));
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
            cancel: false, // 通常の対戦なので cancel は false
          )
        ];
      }
    }).toList();
  } catch (e) {
    print('Error fetching match records: $e');
    throw Exception('Failed to load match history: $e');
  }
});