// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/modes/debate_scores.dart';
import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- ▼ 1. SharedPreferencesをインポートします ---
import 'package:shared_preferences/shared_preferences.dart';

final matchRecordsProvider = StateNotifierProvider.autoDispose<
    MatchRecordsNotifier, AsyncValue<List<MatchRecordDisplay>>>((ref) {
  return MatchRecordsNotifier(ref);
});

class MatchRecordsNotifier
    extends StateNotifier<AsyncValue<List<MatchRecordDisplay>>> {
  final Ref ref;
  bool hasMore = true;
  bool _isLoadingMore = false;

  MatchRecordsNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchInitial();
  }

  Future<void> fetchInitial() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      state = const AsyncValue.loading();
      final records = await _fetchRecords(currentUserId: currentUserId, limit: 30);
      if (records.length < 30) {
        hasMore = false;
      }
      state = AsyncValue.data(records);
    } catch (e, st) {
      print('Error fetching match records: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || _isLoadingMore || state is! AsyncData) return;
    final currentList = state.value!;
    if (currentList.isEmpty) return;

    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    _isLoadingMore = true;
    try {
      // 最も古いレコードの作成日時を取得
      final oldestCreatedAt = currentList
          .map((r) => r.createdAt)
          .whereType<DateTime>()
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final olderRecords = await _fetchRecords(
        currentUserId: currentUserId,
        limit: 30,
        beforeDate: oldestCreatedAt,
      );

      if (olderRecords.length < 30) {
        hasMore = false;
      }

      // 重複チェックを行ってマージ
      final existingIds = currentList.map((r) => r.roomid).toSet();
      final newRecords = olderRecords.where((r) => !existingIds.contains(r.roomid)).toList();

      state = AsyncValue.data([...currentList, ...newRecords]);
    } catch (e) {
      print('Error loading more match records: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<List<MatchRecordDisplay>> _fetchRecords({
    required String currentUserId,
    required int limit,
    DateTime? beforeDate,
  }) async {
    final supabase = ref.read(supabaseProvider);

    // SharedPreferencesからブロック済みルームを取得
    final prefs = await SharedPreferences.getInstance();
    final blockedRoomIds = (prefs.getStringList('blocked_room_ids') ?? const []).toSet();

    var query = supabase
        .from('match_record')
        .select(
            '*, player1:player1_id(name, avatar_url), player2:player2_id(name, avatar_url)')
        .or('player1_id.eq.$currentUserId,player2_id.eq.$currentUserId');

    if (beforeDate != null) {
      query = query.lt('created_at', beforeDate.toIso8601String());
    }

    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);

    final rawList = List<Map<String, dynamic>>.from(data);

    return rawList.expand<MatchRecordDisplay>((record) {
      final roomid = record['roomid'] as String;
      if (blockedRoomIds.contains(roomid)) {
        return [];
      }

      final winnerId = record['winner'] as String?;
      final player1Id = record['player1_id'] as String?;
      final player2Id = record['player2_id'] as String?;
      final theme = record['theme'] as String? ?? '';
      final player1Choice = record['player1_choice'] as String? ?? '';
      final player2Choice = record['player2_choice'] as String? ?? '';
      final cancel = record['cancel'] as bool? ?? false;
      final isPlayer1 = currentUserId == player1Id;
      final createdAtStr = record['created_at'] as String?;
      final recordCreatedAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

      String opponentName = 'Unknown Opponent';
      String? opponentAvatarUrl;
      String myname = 'Unknown Player';
      String? opponentid;

      if (isPlayer1) {
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

      final String choiceInDb = isPlayer1
          ? player1Choice
          : (currentUserId == player2Id ? player2Choice : 'N/A');
      final userChoice = choiceInDb.isEmpty ? '未選択' : choiceInDb;

      final String oppChoiceInDb = isPlayer1
          ? player2Choice
          : (currentUserId == player2Id ? player1Choice : 'N/A');
      final opponentChoice = oppChoiceInDb.isEmpty ? '未選択' : oppChoiceInDb;

      // スコアパース
      MatchScores? scores;
      if (record['scores'] != null) {
        if (record['scores'] is Map<String, dynamic>) {
          scores = MatchScores.fromMap(record['scores'] as Map<String, dynamic>);
        } else if (record['scores'] is String) {
          scores = MatchScores.fromJsonString(record['scores'] as String);
        }
      }

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
              scores: scores,
              myName: myname,
              opponentChoice: opponentChoice,
              isPlayer1: isPlayer1,
              createdAt: recordCreatedAt,
            )
          ];
        }
      } else {
        final p1Move = record['player1_move_trophy'] as int?;
        final p2Move = record['player2_move_trophy'] as int?;
        final isUnderdog = record['is_underdog'] as bool? ?? false;
        final moveTrophyLegacy = record['move_trophy'] as int? ?? 0;

        final isWinner = winnerId != null && currentUserId == winnerId;
        final bool isDraw = winnerId == null;
        final resultString = isDraw ? '引き分け' : (isWinner ? '勝利' : '敗北');

        int trophyChange;
        if (isPlayer1) {
          trophyChange = p1Move ?? (isWinner ? moveTrophyLegacy : -moveTrophyLegacy);
        } else {
          trophyChange = p2Move ?? (isWinner ? moveTrophyLegacy : -moveTrophyLegacy);
        }

        final resultReason = record['result'] as String? ?? '';
        String formattedReason = resultReason;
        String formatName(String name) => "'$name'";
        if (formattedReason.isNotEmpty) {
          formattedReason = formattedReason.trim();
          if (isPlayer1) {
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
            scores: scores,
            myName: myname,
            opponentChoice: opponentChoice,
            isPlayer1: isPlayer1,
            createdAt: recordCreatedAt,
          )
        ];
      }
    }).toList();
  }
}
