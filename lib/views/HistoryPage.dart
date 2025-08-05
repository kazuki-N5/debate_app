import 'dart:developer';

import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/history_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:popover/popover.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            return Center(child: Container());
          }, error: (error, stack) {
            print('Error in HistoryPage UI: $error');
            print(stack);
            // --- MODIFIED: Error UI with Refresh Button ---
            if (isLoadingRetry.value) {
              return Center(
                  child: Container());
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

    // --- Record Data ---
    final String resultStatus = record.resultString;
    final int trophyChange = record.trophyChange;
    final String opponentName = record.opponentName;
    final String? opponentAvatarUrl = record.opponentAvatarUrl;
    final String theme = record.theme;
    final String userChoice = record.userChoice;
    final String reason = record.reason;
    final bool isCancelled = record.cancel!;
    final String? opponentid = record.opponentid;
    final String roomid = record.roomid;
    final supabase = Supabase.instance.client;

    // --- UI Constants ---
    final Color cardBackgroundColor = Colors.grey[200] ?? Colors.grey;
    final Color resultColor =
        resultStatus == '勝利' ? Colors.red[700]! : Colors.grey[700]!;
    final String trophyChangeString =
        (trophyChange > 0 ? '+' : '') + trophyChange.toString();
    const double collapsedGrayBoxHeight = 90.0;
    final BorderRadius grayBoxBorderRadius = BorderRadius.circular(8.0);
    const double avatarRadius = 18.0;
    Widget _buildReportButton(BuildContext popoverContext) {
      return GestureDetector(
        onTap: () async {
          Navigator.of(popoverContext).pop();
          log(opponentid.toString());
          log(roomid.toString());

          try {
            // 2. Supabaseのprohibitedテーブルにデータを挿入
            await supabase.from('prohibited').insert({
              'user_id': opponentid,
              'room_id': roomid,
            });

            // 成功した場合の処理
            // 非同期処理をまたぐため、contextがまだ有効かチェックするのが安全です
            if (!context.mounted) return;

            // ポップオーバーを閉じる

            // 成功したことを知らせるスナックバーを表示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ユーザーを報告しました。'),// 成功を分かりやすくするために色付け
                duration: Duration(seconds: 2),
              ),
            );
          } catch (e) {
            // 3. 失敗した場合の処理
            if (!context.mounted) return;


            // エラーが発生したことを知らせるスナックバーを表示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('報告に失敗しました。'),// エラーを分かりやすくするために色付け
                duration: Duration(seconds: 2),
              ),
            );

            // デバッグ用にエラー内容をコンソールに出力
            debugPrint('Supabaseへの挿入エラー: $e');
          }
        },
        child: Container(
          margin: const EdgeInsets.all(8.0), // 吹き出しの内側の余白
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              '報告',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    Widget _buildAvatarImage() {
      if (opponentAvatarUrl != null && opponentAvatarUrl.isNotEmpty) {
        return CircleAvatar(
          radius: avatarRadius,
          backgroundColor: Colors.grey[400],
          backgroundImage: NetworkImage(opponentAvatarUrl),
        );
      } else {
        return CircleAvatar(
          radius: avatarRadius,
          backgroundColor: Colors.blueGrey[300],
          child: Icon(
            Icons.person,
            size: avatarRadius * 1.2,
            color: Colors.white,
          ),
        );
      }
    }

    // 報告ボタンのウィジェット

    // --- Helper Widget for Avatar ---
    Widget _buildOpponentAvatar() {
      // InkWellでラップするために、BuildContextを渡せるようにBuilderでラップ
      return Builder(
        builder: (avatarContext) {
          return InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              // --- POPOVER表示処理 ---
              showPopover(
                context: avatarContext, // タップされたアイコンのcontextを使用
                bodyBuilder: (popoverContext) =>
                    _buildReportButton(popoverContext),
                direction: PopoverDirection.bottom, // アイコンの上側に表示
                backgroundColor: Colors.white,
                barrierColor: Colors.transparent,
                width: 100, // 吹き出しの幅
                height: 50, // 吹き出しの高さ
                arrowHeight: 10, // 吹き出しの矢印の高さ
                arrowWidth: 20, // 吹き出しの矢印の幅
                transitionDuration: const Duration(milliseconds: 100),
              );
              // --- END POPOVER ---
            },
            child: _buildAvatarImage(),
          );
        },
      );
    }

    // アバターの画像部分を分離

    return Padding(
      // (以下、変更なし)
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
                Row(
                  children: [
                    Text(
                      resultStatus,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trophyChangeString,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // --- MODIFIED: Tappable Avatar with Popover ---
                    _buildOpponentAvatar(),
                    // --- END MODIFIED ---
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        opponentName,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isCancelled)
                      InkWell(
                        onTap: () {
                          context.push('/chistory', extra: record);
                        },
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                        child: Text(
                          'レスバを見る',
                          style: TextStyle(
                              fontSize: 14,
                              color: const Color.fromARGB(255, 114, 114, 114),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
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
                    constraints: isReasonExpanded.value || isCancelled
                        ? null
                        : const BoxConstraints(
                            maxHeight: collapsedGrayBoxHeight),
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
                                if (!isCancelled) ...[
                                  const Text(
                                    'テーマ:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    theme,
                                    style:
                                        const TextStyle(color: Colors.black87),
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
                                    style:
                                        const TextStyle(color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                ],
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
