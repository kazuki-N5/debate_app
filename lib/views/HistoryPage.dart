// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/history_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/view_model/prohibited_view_model.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:debate_project/views/UserProfilePage.dart';

class HistoryPage extends HookConsumerWidget {
  const HistoryPage({super.key});

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
        title: Text('履歴',
            style: AppTextStyles.bold(color: Colors.white)),
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
              return Center(
                  child: Text('ログインしてください。',
                      style: AppTextStyles.notoSans(color: Colors.white)));
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
              return Center(child: Container());
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '履歴の読み込みに失敗しました。',
                    style: AppTextStyles.notoSans(color: Colors.white, fontSize: 16),
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

// (HistoryPageクラスは変更なしのため省略)

class _MatchHistoryItem extends HookConsumerWidget {
// --- 変更箇所 END ---
  final MatchRecordDisplay record;

  const _MatchHistoryItem({
    required this.record,
  });

  @override
  // --- 変更箇所 START ---
  // 3. buildメソッドに `WidgetRef ref` を追加します
  Widget build(BuildContext context, WidgetRef ref) {
    // --- 変更箇所 END ---
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
    final supabase = ref.read(supabaseProvider);
    // --- 変更箇所 START ---
    // 4. `supabase` の直接インスタンス化は不要になるので削除します
    // final supabase = Supabase.instance.client;
    // --- 変更箇所 END ---

    // --- UI Constants ---
    final Color cardBackgroundColor = Colors.grey[200] ?? Colors.grey;
    final Color resultColor = resultStatus == '勝利'
        ? Colors.red[700]!
        : Colors.grey[700]!;
    final String trophyChangeString =
        (trophyChange > 0 ? '+' : '') + trophyChange.toString();
    const double collapsedGrayBoxHeight = 90.0;
    final BorderRadius grayBoxBorderRadius = BorderRadius.circular(8.0);
    const double avatarRadius = 18.0;

    // --- 変更箇所 START ---
    // 5. 古い `_buildReportButton` メソッドはViewModelの機能で代替されるため、完全に削除します
    // Widget _buildReportButton(BuildContext popoverContext) { ... }
    // --- 変更箇所 END ---

    Widget buildAvatarImage() {
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
          child: const Icon(
            Icons.person,
            size: avatarRadius * 1.2,
            color: Colors.white,
          ),
        );
      }
    }

    Widget buildOpponentAvatar() {
      return Builder(
        builder: (avatarContext) {
          return InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              if (opponentid != null) {
                Navigator.push(
                  avatarContext,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(userId: opponentid),
                  ),
                );
              }
            },
            onLongPress: () {
              final navigator = Navigator.of(avatarContext);

              showCustomPopover(
                context: avatarContext,
                height: 100,
                children: [
                  PopoverButton(
                    text: '通報',
                    onTap: () async {
                      final prohibitedService =
                          ref.read(prohibitedServiceProvider);

                      await prohibitedService.sendProhibited(
                        context: avatarContext,
                        opponentId: opponentid,
                        roomId: roomid,
                      );
                      navigator.pop();
                    },
                  ),
                  const SizedBox(height: 4),
                  PopoverButton(
                    text: 'ブロック',
                    onTap: () {
                      navigator.pop();
                      showDialog(
                        context: avatarContext,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27.0),
                            ),
                            title: Text(
                              'ユーザーをブロック',
                              style: AppTextStyles.bold(
                                color: Colors.black,
                                fontSize: 20,
                              ),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${record.opponentName}さんをブロックしますか？\nブロックすると、このユーザーの投稿・メッセージが表示されなくなり、DM・対戦申し込みもできなくなります。\n※ランダムマッチングでは引き続き対戦することがあります。', // 説明を修正
                                    style: AppTextStyles.notoSans(
                                      color: Colors.black.withValues(alpha: 0.8),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actionsPadding:
                                const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            actionsAlignment: MainAxisAlignment.end,
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                    side: const BorderSide(
                                        color: Colors.black, width: 1.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0, vertical: 10.0),
                                  textStyle: AppTextStyles.bold(
                                      fontSize: 15),
                                ),
                                child: const Text('キャンセル'),
                              ),
                              const SizedBox(width: 1),
                              ElevatedButton(
                                // --- ▼ 2. ブロックボタンの処理を修正 ---
                                onPressed: () async {
                                  final dialogNavigator = Navigator.of(dialogContext);
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                                  try {
                                    // ① Supabaseにブロック情報を挿入
                                    await supabase.from('brock_user').insert({
                                      'user_id': ref.read(currentUserIdProvider),
                                      'block_user_id': opponentid,
                                    });

                                    // ② ブロック一覧プロバイダを更新(全画面に反映)
                                    await ref.read(blockedUserIdsProvider.notifier).refresh();

                                    // ③ SharedPreferencesにブロックしたroomidを保存
                                    final prefs = await SharedPreferences.getInstance();
                                    const key = 'blocked_room_ids'; // 保存キー
                                    
                                    // 既存のリストを取得
                                    final List<String> blockedRoomIds = prefs.getStringList(key) ?? [];
                                    
                                    // 新しいIDを追加（重複を避ける）
                                    if (!blockedRoomIds.contains(roomid)) {
                                      blockedRoomIds.add(roomid);
                                      await prefs.setStringList(key, blockedRoomIds);
                                    }

                                    // ④ プロバイダを無効化し、履歴リストを再読み込み・再フィルタリングさせる
                                    ref.invalidate(matchRecordsProvider);

                                    // ④ ダイアログを閉じる
                                    dialogNavigator.pop();

                                    // ④ ユーザーに完了を通知
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text('${record.opponentName}さんをブロックしました。'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );

                                  } catch (error) {
                                    print('ブロック処理に失敗しました: $error');
                                    // エラー時もダイアログを閉じる
                                    dialogNavigator.pop();
                                    // ユーザーにエラーを通知
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('ブロック処理に失敗しました。'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                // --- ▲ 修正ここまで ---
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0, vertical: 12.0),
                                  elevation: 2,
                                  textStyle: AppTextStyles.bold(
                                      fontSize: 15),
                                ),
                                child: const Text('はい'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
            child: buildAvatarImage(),
          );
        },
      );
    }

    // (これ以降のUI部分に変更はありません)
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
                Row(
                  children: [
                    Text(
                      resultStatus,
                      style: AppTextStyles.bold(
                        fontSize: 20,
                        color: resultColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trophyChangeString,
                      style: AppTextStyles.bold(
                        fontSize: 18,
                        color: resultColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 自分が「格差ボーナス」対象だった場合のみバッジを表示
                    if (record.isUnderdog)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '格差ボーナス',
                          style: AppTextStyles.bold(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    buildOpponentAvatar(),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        opponentName,
                        style: AppTextStyles.notoSans(
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
                          style: AppTextStyles.bold(
                              fontSize: 14,
                              color: const Color.fromARGB(255, 114, 114, 114)),
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
                                  Text(
                                    'テーマ:',
                                    style: AppTextStyles.bold(
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    theme,
                                    style:
                                        AppTextStyles.notoSans(color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'あなたの選択:',
                                    style: AppTextStyles.bold(
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userChoice,
                                    style:
                                        AppTextStyles.notoSans(color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  '理由:',
                                  style: AppTextStyles.bold(
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reason,
                                  style: AppTextStyles.notoSans(color: Colors.black87),
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
