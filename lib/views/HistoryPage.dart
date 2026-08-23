// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/history_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/view_model/prohibited_view_model.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:debate_project/widgets/chat_message_action_menu.dart';
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
            style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
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
          backgroundColor: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: avatarRadius * 1.2,
            color: Colors.grey[600],
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
                  PageRouteBuilder(
                    pageBuilder: (context, _, __) => UserProfilePage(userId: opponentid),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            },
            onLongPress: () {
              showChatMessageActionMenu(
                context: avatarContext,
                customItems: [
                  ChatMessageActionItem(
                    icon: Icons.warning_amber_rounded,
                    label: '通報',
                    iconColor: const Color(0xFFFBBF24),
                    textColor: const Color(0xFFFDE68A),
                    onTap: () async {
                      final prohibitedService =
                          ref.read(prohibitedServiceProvider);

                      await prohibitedService.sendProhibited(
                        context: avatarContext,
                        opponentId: opponentid,
                        roomId: roomid,
                      );
                    },
                  ),
                  ChatMessageActionItem(
                    icon: Icons.block_rounded,
                    label: 'ブロック',
                    iconColor: const Color(0xFFFB7185),
                    textColor: const Color(0xFFFDA4AF),
                    isDestructive: true,
                    onTap: () {
                      if (opponentid == null) return;
                      showBlockUserDialog(
                        context: context,
                        ref: ref,
                        targetUserId: opponentid,
                        targetName: record.opponentName,
                        onBlocked: () async {
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            const key = 'blocked_room_ids';
                            final List<String> blockedRoomIds =
                                prefs.getStringList(key) ?? [];
                            if (!blockedRoomIds.contains(roomid)) {
                              blockedRoomIds.add(roomid);
                              await prefs.setStringList(key, blockedRoomIds);
                            }
                            ref.invalidate(matchRecordsProvider);
                          } catch (e) {
                            print('History blocked_room_ids save error: $e');
                          }
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

    final myScore = record.myScore;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Material(
          color: cardBackgroundColor,
          child: InkWell(
            onTap: () => context.push('/history_detail', extra: record),
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

