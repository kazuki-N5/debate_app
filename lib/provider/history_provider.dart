import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final matchRecordsProvider =
    FutureProvider<List<MatchRecordDisplay>>((ref) async {
  final supabase = ref.watch(supabaseProvider); 
  final currentUserId = ref.watch(currentUserIdProvider); // Get current user ID

  if (currentUserId == null) {
    // User not logged in, return empty list or throw specific error
    print("User not logged in, cannot fetch match history.");
    return [];
  }

  try {
    // Fetch match records and embed player names
    final List<Map<String, dynamic>>? data = await supabase
        .from('match_record')
        .select(
            '*, player1:player1_id(name, avatar_url), player2:player2_id(name, avatar_url)') // Embedding player names
        .or('player1_id.eq.$currentUserId,player2_id.eq.$currentUserId')
        .order('created_at', ascending: false)
        .limit(30)
        .then((data) =>
            List<Map<String, dynamic>>.from(data)); // Ensure correct type

    if (data == null) {
      return []; // No data found
    }

    // Process data into display format
    return data.map((record) {
      final roomid = record['roomid'] as String;
      final winnerId = record['winner'] as String?;
      final moveTrophy =
          record['move_trophy'] as int? ?? 0; // Default to 0 if null
      final theme = record['theme'] as String? ?? 'N/A';
      final player1Id = record['player1_id'] as String?;
      final player2Id = record['player2_id'] as String?;
      final player1Choice = record['player1_choice'] as String? ?? 'N/A';
      final player2Choice = record['player2_choice'] as String? ?? 'N/A';
      final resultReason = record['result'] as String? ?? '理由なし';

      // Determine win/loss
      final isWinner = winnerId != null && currentUserId == winnerId;
      final resultString = isWinner ? '勝利' : '敗北';
      final trophyChange = isWinner ? moveTrophy : -moveTrophy;

      // Determine opponent name
      String opponentName = 'Unknown Opponent';
      String? opponentAvatarUrl;
      String? myname = 'Unknown Player';
      if (currentUserId == player1Id &&
          record['player2'] is Map<String, dynamic>) {
        final player2Data = record['player2'] as Map<String, dynamic>;
        final player1Data = record['player1'] as Map<String, dynamic>;
        myname = player1Data['name'] as String? ?? 'Unknown Opponent';
        opponentName = player2Data['name'] as String? ?? 'Unknown Opponent';
        opponentAvatarUrl =
            player2Data['avatar_url'] as String?; // Get avatar_url
      } else if (currentUserId == player2Id &&
          record['player1'] is Map<String, dynamic>) {
        final player1Data = record['player1'] as Map<String, dynamic>;
        final player2Data = record['player2'] as Map<String, dynamic>;
        myname = player2Data['name'] as String? ?? 'Unknown Opponent';
        opponentName = player1Data['name'] as String? ?? 'Unknown Opponent';
        opponentAvatarUrl =
            player1Data['avatar_url'] as String?; // Get avatar_url
      }

      // Determine user's choice
      final userChoice = (currentUserId == player1Id)
          ? player1Choice
          : (currentUserId == player2Id ? player2Choice : 'N/A');

      // Format reason text
      // Remove the first character and trim leading/trailing whitespace
      String formattedReason = resultReason;
      String formatName(String name) {
        return "'$name'";
      }

      if (formattedReason.isNotEmpty) {
        formattedReason = formattedReason.substring(1).trim();

        if (currentUserId == player1Id) {
          formattedReason = formattedReason.replaceAll('A', formatName(myname));
          formattedReason =
              formattedReason.replaceAll('B', formatName(opponentName));
        } else {
          formattedReason =
              formattedReason.replaceAll('A', formatName(opponentName));
          formattedReason = formattedReason.replaceAll('B', formatName(myname));
        }
      }

      return MatchRecordDisplay(
        roomid: roomid,
        resultString: resultString,
        trophyChange: trophyChange,
        opponentName: opponentName,
        opponentAvatarUrl: opponentAvatarUrl,
        theme: theme,
        userChoice: userChoice,
        reason: formattedReason,
      );
    }).toList();
  } catch (e) {
    // Handle errors during fetching
    print('Error fetching match records: $e');
    // Depending on requirements, you might return empty list or re-throw the error
    throw Exception('Failed to load match history: $e');
  }
});
