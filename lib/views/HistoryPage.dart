import 'package:debate_project/provider/match_history_provider.dart'; // Assuming this is your provider file
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:debate_project/features/chat/presentation/chat_page.dart'; // Import your ChatPage if needed

class HistoryPage extends HookConsumerWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchHistoryAsync = ref.watch(matchHistoryProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.blue, // Set background color for the page
      appBar: AppBar(
        title: const Text('履歴', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue, // Match background
        elevation: 0, // No shadow
        // --- ★変更点: デフォルトの戻るボタンを非表示にする ---
        automaticallyImplyLeading: false,
        // --- 変更点ここまで ---
        iconTheme: const IconThemeData(color: Colors.white), // Make other icons white if needed
      ),
      // --- ★変更点: body を Stack でラップして Positioned を使えるようにする ---
      body: Stack(
        children: [
          // --- 元々の body の内容 (ListView や Loading/Error 表示) ---
          matchHistoryAsync.when(
            data: (history) {
              if (currentUserId == null) {
                return const Center(child: Text('ログインしてください。', style: TextStyle(color: Colors.white)));
              }
              if (history.isEmpty) {
                return const Center(child: Text('対戦履歴がありません。', style: TextStyle(color: Colors.white)));
              }
              // --- ★変更点: ListView の Padding を調整してボタンと被らないようにする ---
              //    (必要に応じて bottom padding を追加)
              return ListView.builder(
                // EdgeInsets.only を使用して、下部にボタン分のスペースを確保
                padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0, bottom: 80.0), // bottom を増やしてボタンと被らないように
                itemCount: history.length,
                itemBuilder: (context, index) {
                  return _MatchHistoryItem(
                    matchData: history[index],
                    currentUserId: currentUserId,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (error, stack) {
              print('Error in HistoryPage UI: $error'); // Log error for debugging
              print(stack);
              return Center(child: Text('履歴の読み込みに失敗しました: $error', style: const TextStyle(color: Colors.white)));
            }
          ),
          // --- ★変更点: ここに Positioned でカスタム戻るボタンを追加 ---
          Positioned(
            left: 10, // 少し左に寄せる
            bottom: 20, // 下からの位置 (広告バーなどを考慮)
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              iconSize: 28.0,
              // ボタンの色を背景に合わせて調整 (白など)
              color: Colors.black, // 白に変更して視認性を上げる
              tooltip: '戻る',
              onPressed: () => Navigator.of(context).pop(),
              // 背景色や形状を追加して目立たせることも可能
              // style: IconButton.styleFrom(
              //   backgroundColor: Colors.black.withOpacity(0.3),
              //   padding: const EdgeInsets.all(12.0),
              // ),
              padding: const EdgeInsets.all(12.0), // デフォルトのpaddingでもOK
              splashRadius: 24.0,
            ),
          ),
          // --- 変更点ここまで ---
        ],
      ),
    );
  }
}

// Extracted widget for a single history item (変更なし)
class _MatchHistoryItem extends HookWidget {
  final Map<String, dynamic> matchData;
  final String currentUserId; // Pass current user ID

  const _MatchHistoryItem({
    Key? key,
    required this.matchData,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false); // Hook for managing expansion state

    // Extract data safely with null checks and default values
    final winnerId = matchData['winner'] as String?;
    final moveTrophy = matchData['move_trophy'] as int? ?? 0;
    final originalResultDetail = matchData['result'] as String? ?? '結果情報なし'; // Get original text
    final roomId = matchData['roomid'] as String?;

    // --- resultDetail の加工 (変更なし) ---
    String processedResultDetail = originalResultDetail;
    if (processedResultDetail.length > 1) {
      processedResultDetail = processedResultDetail.substring(1);
    } else if (processedResultDetail.length == 1) {
        processedResultDetail = ''; // 1文字しかない場合は空にする
    }
    processedResultDetail = processedResultDetail.replaceAll(RegExp(r'\s+'), '');
    // --- 加工ここまで ---


    // Determine if the current user won or lost based on requirements
    final bool isWin = (winnerId == currentUserId) || (winnerId == null); // Consider null winner as win? Adjust logic if needed.
    final String resultStatus = isWin ? '勝利' : '敗北';
    final String trophyChange = '${isWin ? '+' : '-'}${moveTrophy.abs()}';

    final Color cardBackgroundColor = Colors.grey[200] ?? Colors.grey;
    final Color reasonBackgroundColor = Colors.grey[400] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(15.0),
          child: Material(
              color: cardBackgroundColor,
              child: InkWell(
                onTap: () {
                  if (roomId != null) {
                    print('Navigating to ChatPage for room: $roomId');
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(roomId: roomId))); // チャットページへの遷移 (コメントアウト)
                  } else {
                    print('Error: roomId is null, cannot navigate to chat.');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('チャット情報の取得に失敗しました。')),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Top Row ---
                      Row(
                        children: [
                          Text(
                            resultStatus,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trophyChange,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isWin ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'チャットを見る',
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                          // ▼ アイコンは不要であればコメントアウトまたは削除
                          // const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- Bottom Section: Reason (Expandable) ---
                       Container(
                        width: double.infinity,
                         child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: Material(
                               color: reasonBackgroundColor,
                               child: InkWell(
                                  onTap: () {
                                      isExpanded.value = !isExpanded.value;
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '理由：',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 4),
                                        // --- Result Text (Handles expansion) ---
                                        Text( // 直接Textを配置
                                          processedResultDetail, // 加工済みのテキストを使用
                                          style: const TextStyle(color: Colors.black87),
                                          maxLines: isExpanded.value ? null : 2,
                                          overflow: TextOverflow.fade,
                                        ),
                                      ],
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
      ),
    );
  }
}