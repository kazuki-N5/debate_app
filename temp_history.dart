// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/history_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/view_model/prohibited_view_model.dart';
import 'package:debate_project/widgets/radar_chart_view.dart';
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
    final scrollController = useScrollController();

    useEffect(() {
      void onScroll() {
        if (!scrollController.hasClients) return;
        final maxScroll = scrollController.position.maxScrollExtent;
        final currentScroll = scrollController.position.pixels;
        // 末尾200px手前に達したら自動で追加ロード
        if (maxScroll - currentScroll <= 200) {
          ref.read(matchRecordsProvider.notifier).loadMore();
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: matchRecordsAsync.when(data: (records) {
        if (isLoadingRetry.value) isLoadingRetry.value = false;
        if (currentUserId == null) {
          return Center(
              child: Text('ログインしてください。',
                  style: AppTextStyles.notoSans(color: Colors.white)));
        }
        if (records.isEmpty) {
          return Center(
            child: Text(
              '対戦履歴がありません。',
              style: AppTextStyles.notoSans(color: Colors.white, fontSize: 16),
            ),
          );
        }
        return RefreshIndicator(
          color: Colors.blue,
          backgroundColor: Colors.white,
          onRefresh: () =>
              ref.read(matchRecordsProvider.notifier).fetchInitial(),
          child: ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
                left: 12.0, right: 12.0, top: 8.0, bottom: 24.0),
            itemCount: records.length,
            itemBuilder: (context, index) {
              return _MatchHistoryItem(
                record: records[index],
              );
            },
          ),
        );
      }, loading: () {
        // プロバイダがローディング状態の時もローカルローディング状態をfalseにする
        // (プロバイダ自身のローディング状態が優先されるため)
        if (isLoadingRetry.value) isLoadingRetry.value = false;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
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
                  ref.read(matchRecordsProvider.notifier).fetchInitial();
                },
              ),
            ],
          ),
        );
        // --- END MODIFIED ---
      }),
    );
  }
}

class _MatchHistoryItem extends HookConsumerWidget {
  final MatchRecordDisplay record;

  const _MatchHistoryItem({
    required this.record,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- Record Data ---
    final String resultStatus = record.resultString;
    final int trophyChange = record.trophyChange;
    final String opponentName = record.opponentName;
    final String? opponentAvatarUrl = record.opponentAvatarUrl;
    final String theme = record.theme;
    final bool isCancelled = record.cancel ?? false;
    final String? opponentid = record.opponentid;
    final String roomid = record.roomid;
    final supabase = ref.read(supabaseProvider);

    // --- UI Constants ---
    final Color cardBackgroundColor = Colors.grey[200] ?? Colors.grey;
    final Color resultColor = resultStatus == '勝利'
        ? Colors.red[700]!
        : (resultStatus == '引き分け' ? Colors.blue[800]! : Colors.grey[700]!);
    final String trophyChangeString =
        (trophyChange > 0 ? '+' : '') + trophyChange.toString();
    const double avatarRadius = 18.0;

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
                                    '${record.opponentName}さんをブロックしますか？\nブロックすると、このユーザーの投稿・メッセージが表示されなくなり、DM・対戦申し込みもできなくなります。\n※ランダムマッチングでは引き続き対戦することがあります。',
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

    // 詳細ボトムシートを表示する関数
    void showDetailBottomSheet() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetContext) {
          final myScore = record.myScore;
          final opponentScore = record.opponentScore;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.0),
                topRight: Radius.circular(24.0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 上部ドラッグハンドル
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                // ヘッダー（タイトル＆閉じるボタン）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.analytics_outlined, color: Colors.blue, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '試合詳細・分析',
                            style: AppTextStyles.bold(
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // スクロール可能な詳細コンテンツ
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 勝敗＆対戦相手
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
                            const Spacer(),
                            Text(
                              'vs $opponentName',
                              style: AppTextStyles.bold(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // テーマ・選択情報コンテナ
                        if (!isCancelled)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'テーマ: $theme',
                                  style: AppTextStyles.bold(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.blue[200]!),
                                      ),
                                      child: Text(
                                        'あなた: ${record.userChoice}',
                                        style: AppTextStyles.notoSans(
                                          fontSize: 12,
                                          color: Colors.blue[900],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (record.opponentChoice != null &&
                                        record.opponentChoice != '未選択')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.red[200]!),
                                        ),
                                        child: Text(
                                          '相手: ${record.opponentChoice}',
                                          style: AppTextStyles.notoSans(
                                            fontSize: 12,
                                            color: Colors.red[900],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        // レーダーチャート表示
                        if (myScore != null) ...[
                          RadarChartView(
                            myScore: myScore,
                            opponentScore: opponentScore,
                            myName: record.myName ?? 'あなた',
                            opponentName: opponentName,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // AI判定理由
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.smart_toy_outlined,
                                      size: 18, color: Colors.blue[800]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AI判定の理由:',
                                    style: AppTextStyles.bold(
                                      fontSize: 15,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                record.reason,
                                style: AppTextStyles.notoSans(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 「レスバを見る」ボタン
                        if (!isCancelled)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                                context.push('/chistory', extra: record);
                              },
                              icon: const Icon(Icons.forum_outlined, size: 20),
                              label: Text(
                                'レスバ（チャット履歴）を見る',
                                style: AppTextStyles.bold(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final myScore = record.myScore;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Material(
          color: cardBackgroundColor,
          child: InkWell(
            onTap: showDetailBottomSheet,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1行目: 勝敗、トロフィー、格差バッジ、相手アバター、相手名、論理能力%バッジ
                  Row(
                    children: [
                      Text(
                        resultStatus,
                        style: AppTextStyles.bold(
                          fontSize: 19,
                          color: resultColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trophyChangeString,
                        style: AppTextStyles.bold(
                          fontSize: 17,
                          color: resultColor,
                        ),
                      ),
                      if (record.isUnderdog) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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
                      ],
                      const SizedBox(width: 8),
                      buildOpponentAvatar(),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          opponentName,
                          style: AppTextStyles.notoSans(
                            fontSize: 15,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      // スコアが存在する場合、論理能力%バッジを表示
                      if (myScore != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.psychology_outlined,
                                size: 14,
                                color: Colors.blue[800],
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${myScore.totalPercentage}%',
                                style: AppTextStyles.bold(
                                  fontSize: 12,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 2行目: テーマ表示ボックス
                  if (!isCancelled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        'テーマ: $theme',
                        style: AppTextStyles.notoSans(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  // 3行目: タップ誘導テキスト＆詳細矢印
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'タップして詳細・分析を見る',
                        style: AppTextStyles.notoSans(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '詳細',
                            style: AppTextStyles.bold(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                        ],
                      ),
                    ],
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

