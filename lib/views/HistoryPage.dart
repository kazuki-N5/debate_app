import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/history_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HistoryPage extends HookConsumerWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchRecordsAsync = ref.watch(matchRecordsProvider);
    final currentUserId = ref.read(currentUserIdProvider);

    final isLoadingRetry = useState(false);

    useEffect(() {
      // プロバイダがローディング中でなく (つまりデータ取得完了またはエラー発生後)、
      // かつローカルのリトライローディング状態がtrueの場合、リセットする
      if (!matchRecordsAsync.isLoading && isLoadingRetry.value) {
        isLoadingRetry.value = false;
      }
      return null; // クリーンアップ関数は不要
    }, [matchRecordsAsync, isLoadingRetry]);

    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: const Text('履歴',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          matchRecordsAsync.when(data: (records) {
            if (isLoadingRetry.value) isLoadingRetry.value = false;
            if (currentUserId == null) {
              return const Center(
                  child: Text('ログインしてください。',
                      style: TextStyle(color: Colors.white)));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(
                  left: 10.0, right: 10.0, top: 10.0, bottom: 80.0),
              itemCount: records.length,
              itemBuilder: (context, index) {
                return _MatchHistoryItem(
                  record: records[index],
                );
              },
            );
          }, loading: () {
            // プロバイダがローディング状態の時もローカルローディング状態をfalseにする
            // (プロバイダ自身のローディング状態が優先されるため)
            if (isLoadingRetry.value) isLoadingRetry.value = false;
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }, error: (error, stack) {
            print('Error in HistoryPage UI: $error');
            print(stack);
            // --- MODIFIED: Error UI with Refresh Button ---
            if (isLoadingRetry.value) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '履歴の読み込みに失敗しました。',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    iconSize: 40.0,
                    color: Colors.white,
                    tooltip: '再取得',
                    onPressed: () {
                      isLoadingRetry.value = true;
                      ref.invalidate(matchRecordsProvider);
                    },
                  ),
                ],
              ),
            );
            // --- END MODIFIED ---
          }),
          Positioned(
            left: 10,
            bottom: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              iconSize: 28.0,
              color: Colors.black,
              tooltip: '戻る',
              onPressed: () => context.pop(),
              padding: const EdgeInsets.all(12.0),
              splashRadius: 24.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHistoryItem extends HookWidget {
  final MatchRecordDisplay record;

  const _MatchHistoryItem({
    Key? key,
    required this.record,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isReasonExpanded = useState(false);

    final String resultStatus = record.resultString;
    final int trophyChange = record.trophyChange;
    final String opponentName = record.opponentName;
    final String? opponentAvatarUrl =
        record.opponentAvatarUrl; // <-- GET AVATAR URL
    final String theme = record.theme;
    final String userChoice = record.userChoice;
    final String reason = record.reason;

    final Color cardBackgroundColor = Colors.grey[200] ?? Colors.grey;
    final Color resultColor =
        resultStatus == '勝利' ? Colors.red[700]! : Colors.grey[700]!;
    final String trophyChangeString =
        (trophyChange > 0 ? '+' : '') + trophyChange.toString();
    const double collapsedGrayBoxHeight = 90.0;
    final BorderRadius grayBoxBorderRadius = BorderRadius.circular(8.0);
    const double avatarRadius = 18.0; // Define avatar size

    // --- Helper Widget for Avatar ---
    Widget _buildOpponentAvatar() {
      if (opponentAvatarUrl != null && opponentAvatarUrl.isNotEmpty) {
        // Display network image if URL exists
        return CircleAvatar(
          radius: avatarRadius,
          backgroundColor: Colors.grey[400], // Background while loading/error
          backgroundImage: NetworkImage(opponentAvatarUrl),
        );
      } else {
        // Display default icon if URL is null or empty
        return CircleAvatar(
          radius: avatarRadius,
          backgroundColor: Colors.blueGrey[300], // Placeholder background
          child: Icon(
            Icons.person,
            size: avatarRadius * 1.2, // Adjust icon size relative to radius
            color: Colors.white,
          ),
        );
      }
    }
    // --- End Helper Widget ---

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Material(
          color: cardBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 7.0, 10.0, 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Upper row: Result, Trophy, Opponent, Chat Button
                Row(
                  children: [
                    // Result Status
                    Text(
                      resultStatus,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Trophy Change
                    Text(
                      trophyChangeString,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                    const SizedBox(width: 12), // Space before avatar
                    // --- MODIFIED: Opponent Avatar and Name ---
                    _buildOpponentAvatar(), // Display the avatar
                    const SizedBox(width: 6), // Space between avatar and name
                    Expanded(
                      child: Text(
                        opponentName, // Display only the name here
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1, // Ensure name doesn't wrap excessively
                      ),
                    ),
                    // --- END MODIFIED ---
                    const SizedBox(width: 8), // Space before chat button
                    // Chat Button
                    InkWell(
                      onTap: () {
                        context.push('/chistory', extra: record);
                      },
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: Colors.transparent,
                      child: const Text(
                        'チャットを見る',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                // Expandable Gray Box Area
                InkWell(
                  onTap: () {
                    isReasonExpanded.value = !isReasonExpanded.value;
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[350],
                      borderRadius: grayBoxBorderRadius,
                    ),
                    constraints: isReasonExpanded.value
                        ? null
                        : BoxConstraints(maxHeight: collapsedGrayBoxHeight),
                    clipBehavior: Clip.hardEdge,
                    child: ClipRRect(
                      borderRadius: grayBoxBorderRadius,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: SingleChildScrollView(
                          physics: isReasonExpanded.value
                              ? null
                              : const NeverScrollableScrollPhysics(),
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(8.0, 5.0, 12.0, 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'テーマ:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  theme,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'あなたの選択:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userChoice,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '理由:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reason,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
