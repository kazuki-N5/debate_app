import 'dart:async';
import 'dart:developer';
import 'package:debate_project/adsence/ad_mbanner_provider.dart';
import 'package:debate_project/adsence/ad_provider.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/message_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:debate_project/view_model/prohibited_view_model.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamePage extends HookConsumerWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdown = useState<int?>(null);
    final finish = useState(false);
    final textControler = useTextEditingController();
    final textFieldFocusNode = useFocusNode();

    // 点滅アニメーションのためのAnimationController
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 800), // 点滅の速度
    );

    final scrollController = useScrollController();
    final room = ref.watch(matchingRoomProvider);
    final chats = ref.watch(chatProvider);
    final chatsnotifier = ref.read(chatProvider.notifier);

    final supabase = ref.read(supabaseProvider);
    final user = ref.read(currentUserIdProvider);
    final cantap = useState(false);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);
    final isSubscribed = ref.watch(inAppPurchaseManagerProvider).isSubscribed;
    final offlineCountdown = ref.watch(opponentOfflineStatusProvider);
    DateTime deadline;
    final Users otherUserState = ref.watch(otherUserProvider);

    String formatTime(int seconds) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes.toString()}:${remainingSeconds.toString().padLeft(2, '0')}';
    }

    Future<DateTime> getServerTime() async {
      final response = await supabase.rpc('get_server_time');
      return DateTime.parse(response);
    }

    Future<DateTime> getServerTimeWithRetry() async {
      try {
        print('サーバー時刻の取得を試みます...-------------');
        final now = await getServerTime();
        print('サーバー時刻の取得に成功しました。');
        return now; // 成功したら時刻を返して関数を抜ける
      } catch (e) {
        print('サーバー時刻の取得に失敗しました: $e。');
        rethrow;
      }
    }

    final myAvatarUrl = ref.watch(userProvider).avatar_url;
    // 非表示にするメッセージIDのリストを状態として管理
    final hiddenMessageIds = useState<Set<String>>({});
    // SharedPreferencesからデータを読み込み中かどうかのフラグ
    final isLoadingPrefs = useState<bool>(true);

    // SharedPreferencesから非表示IDを読み込む非同期関数
    Future<void> loadHiddenMessageIds() async {
      final prefs = await SharedPreferences.getInstance();
      // ChathistoryPageと同じキー 'hidden_message_ids' を使用
      final ids = prefs.getStringList('hidden_message_ids') ?? [];
      if (context.mounted) {
        // ウィジェットがまだ存在するか確認
        hiddenMessageIds.value = ids.toSet();
        isLoadingPrefs.value = false; // 読み込み完了
      }
    }

    // 非表示にするメッセージIDを保存し、状態を更新する関数
    Future<void> hideMessage(String messageId) async {
      final newHiddenIds = {...hiddenMessageIds.value, messageId};
      hiddenMessageIds.value = newHiddenIds; // UIを即時更新

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_message_ids', newHiddenIds.toList());
    }

    // ウィジェットの初回ビルド時に一度だけ実行される
    useEffect(() {
      loadHiddenMessageIds();
      return null; // クリーンアップは不要
    }, const []);

    bool win = false;

    final gametimer = useState<Timer?>(null);
    final finishtimer = useState<Timer?>(null);

    Future<void> countTime() async {
      //これはフォント確認用にわざと止めているのでエターになってるだけです無視してくださいこのエラーはビルドに関係ないです
      deadline = room.updatedAt!.add(const Duration(seconds: 182));

      final DateTime serverTime = await getServerTimeWithRetry();

      final clientTime = DateTime.now();
      final timeOffset = serverTime.difference(clientTime);

      gametimer.value = Timer.periodic(Duration(seconds: 1), (timer) async {
        final estimatedServerTime = DateTime.now().add(timeOffset);
        final diff = deadline.difference(estimatedServerTime).inSeconds;

        if (diff < 165) {
          if (cantap.value == false) {
            cantap.value = true;
          }
        }
        if (diff >= 0) {
          countdown.value = diff;
        }
        if (diff <= 0) {
          finish.value = true;
          textFieldFocusNode.unfocus();
        }

        if (diff < -14) {
          if (!win) {
            win = true;
            roomnotifier.win(room, user!);
          }
        }
        if (diff < -20) {
          gametimer.value?.cancel();
          router.go('/home');
        }
      });
    }

    bool wina = false;

    Future<void> finishgeme() async {
      if (room.player1_finish == true && room.player2_finish == true) {
        gametimer.value?.cancel();
        print('判定結果を出す');
        textFieldFocusNode.unfocus();
        finish.value = true;

        deadline = room.updatedAt!;

        final DateTime serverTime = await getServerTimeWithRetry();

        final clientTime = DateTime.now();
        final timeOffset = serverTime.difference(clientTime);

        finishtimer.value = Timer.periodic(Duration(seconds: 1), (timer) async {
          final estimatedServerTime = DateTime.now().add(timeOffset);
          final fiinishcount =
              deadline.difference(estimatedServerTime).inSeconds.abs();


          if (fiinishcount >= 15) {
            if (!wina) {
              wina = true;
              log('勝利を確定します');
              roomnotifier.win(room, user!);
            }
          }

          if (fiinishcount >= 21) {
            finishtimer.value?.cancel();
            router.go('/home');
          }
        });
      }
    }


    // finish.valueの状態を監視し、アニメーションを制御するuseEffect
    useEffect(() {
      if (finish.value) {
        animationController.repeat(reverse: true); // trueになったらアニメーション開始
      } else {
        animationController.stop(); // falseになったら停止
      }
      return null;
    }, [finish.value]);

    useEffect(() {
      // ゲーム終了時 (room.winner != null) の広告表示ロジック
      if (room.winner != null) {
        Future.microtask(() async {
          // 非同期処理を行うためasync/awaitを使用

          // 広告を表示しない場合、直接次の画面へ遷移
          router.go('/finish');
        });
      }
      return null; // Clean-up は不要
    }, [room.winner]);

    useEffect(() {
      finishgeme();
      return () {
        finishtimer.value?.cancel();
      };
    }, [room.player1_finish, room.player2_finish]);

    useEffect(() {
      print('useEffect: Widget mounted.');

      // Future.microtask を使って、現在のイベントループの最後に処理をスケジュールします。
      // これにより、ウィジェットのビルドと描画が完了してから少し遅れて実行されます。
      Future.microtask(() {
        print('Future.microtask: Triggering ad loads...');

        // ref.read() を使って Notifier のインスタンスを取得し、メソッドを呼び出します。
        // read() は状態変化を監視しないため、useEffect や Future コールバック内でも安全です。
        if (isSubscribed == false) {
          ref.read(adNotifierProvider.notifier).loadAd();
          ref.read(mediumRectangleAdProvider.notifier).loadAd();
        }

        print('Future.microtask: Ad loads triggered.');
      });

      // クリーンアップ関数は不要なので null を返します。
      // もし何か購読などを設定した場合は、ここで購読解除処理などを記述します。
      return null;
    }, const []);

    useEffect(() {
      chatsnotifier.subscribeToMessages(room.roomId!);
      countTime(); // タイマーを再稼働

      return () {
        gametimer.value?.cancel();
      };
    }, []);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.blue,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.blue,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  // 左に配置する選択テキスト
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: Text(
                        '選択: ${user == room.player1Id ? (room.player1Choice! ? room.choice1 : room.choice2) : (room.player2Choice! ? room.choice1 : room.choice2)}',
                        style: AppTextStyles.notoSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // 中央に配置するタイマー
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer, // 時計のアイコン
                              size: 20,
                              color: countdown.value != null &&
                                      countdown.value! <= 3
                                  ? Colors.red
                                  : Colors.grey[800],
                            ),
                            SizedBox(width: 5), // アイコンとテキストの間隔
                            Text(
                              countdown.value != null
                                  ? formatTime(countdown.value!)
                                  : '-',
                              style: AppTextStyles.notoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: countdown.value != null &&
                                        countdown.value! <= 3
                                    ? Colors.red
                                    : Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 右に配置するボタン
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 17),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: cantap.value ? 1.0 : 0.5,
                            child: IconButton(
                              icon: const Icon(Icons.door_back_door,
                                  color: Colors.white),
                              iconSize: 29,
                              onPressed: cantap.value
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                          if (room.player1_finish == true ||
                              room.player2_finish == true)
                            Positioned(
                              top: 3,
                              child: IconButton(
                                onPressed: cantap.value
                                    ? () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(),
                                        );
                                      }
                                    : null,
                                icon: FaIcon(
                                  FontAwesomeIcons.check,
                                  size: 19,
                                  color: Colors.red[900],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            body: Column(
              children: [
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      room.theme!,
                      style: AppTextStyles.notoSans(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: () {
                            // SharedPreferencesの読み込み中はインジケータを表示
                            if (isLoadingPrefs.value) {
                              return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white));
                            }

                            // 非表示IDに含まれないメッセージのみをフィルタリング
                            final visibleMessages = chats
                                .where((chat) =>
                                    !hiddenMessageIds.value.contains(chat.id))
                                .toList();

                            return ListView.builder(
                              controller: scrollController,
                              reverse: true,
                              itemCount: visibleMessages.length,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              itemBuilder: (context, index) {
                                final chat = visibleMessages[index];
                                final isUserMessage = chat.senderId == user;

                                // アバター表示ロジック：相手の発言かつ、一つ前（古い方）の送信者と異なる場合に表示
                                bool showAvatar = !isUserMessage &&
                                    (index == visibleMessages.length - 1 ||
                                        visibleMessages[index + 1].senderId !=
                                            chat.senderId);

                                // 汎用的なMessageBubbleウィジェットを使用
                                return MessageBubble(
                                  chat: chat,
                                  isUserMessage: isUserMessage,
                                  opponentAvatarUrl: otherUserState.avatar_url,
                                  myAvatarUrl: myAvatarUrl,
                                  showAvatar: showAvatar,
                                  roomId: room.roomId,
                                  // 非表示処理をコールバックとして渡す
                                  onHide: () => hideMessage(chat.id),
                                );
                              },
                            );
                          }(),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(25),
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: TextField(
                                    focusNode: textFieldFocusNode,
                                    controller: textControler,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: AppTextStyles.notoSans(
                                        color: Colors.black, fontSize: 14),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: 'レスバしよう',
                                      hintStyle:
                                          AppTextStyles.notoSans(color: Colors.grey[400]),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  if (textControler.text.trim().isNotEmpty) {
                                    ref.read(chatProvider.notifier).sendMesage(
                                        room.roomId!,
                                        textControler.text.trim());
                                    textControler.clear();
                                    scrollController.animateTo(
                                      0,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send,
                                    color: Colors.blue, size: 24),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // finish.valueがtrueの場合にオーバーレイを表示
          if (finish.value)
            Positioned.fill(
              // 背景を薄白くし、下のウィジェットへのタップ操作をブロックする
              child: Container(
                color: Colors.white.withOpacity(0.4),
                child: Center(
                  // FadeTransitionを使って画像を点滅させる
                  child: FadeTransition(
                    opacity: animationController,
                    child: Image.asset(
                      // TODO: こちらにお持ちの画像ファイルのパスを
                      // 例: 'assets/images/loading.png'
                      'assets/images/robot.png',
                      width: 140,
                      height: 140,
                    ),
                  ),
                ),
              ),
            ),



          if (offlineCountdown != null)
            Positioned(
              top: 120, // テーマ表示エリアの下あたり
              left: 30,
              right: 30,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '相手がオフラインです (${offlineCountdown}s)',
                        style: AppTextStyles.bold(color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }
}

class Dialog extends ConsumerWidget {
  const Dialog({Key? key}) : super(key: key); // コンストラクタを追加

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(matchingRoomProvider);
    final roomnotifier = ref.watch(matchingRoomProvider.notifier);
    final user = ref.read(currentUserIdProvider);
    final isUserFinished = user == room.player1Id
        ? room.player1_finish
        : (user == room.player2Id ? room.player2_finish : false);

    return AlertDialog(
      // Dialog → AlertDialogに変更
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(30, 35, 30, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 50),
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                roomnotifier.finish(room.roomId!, user!);
              },
              child: Text('降参する',
                  style: AppTextStyles.bold(
                      fontSize: 17,
                      color: Colors.white)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 50),
                backgroundColor: isUserFinished! ? Colors.white : Colors.blue,
                side: isUserFinished
                    ? BorderSide(color: Colors.black, width: 1)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed:
                  (room.player1_finish == true && room.player2_finish == true)
                      ? null
                      : () {
                          if (isUserFinished) {
                            // キャンセル処理
                            roomnotifier.notsuggestfinish(room.roomId!, user!);
                          } else {
                            // 判定申し込み処理
                            roomnotifier.suggestfinish(room.roomId!, user!);
                          }
                        },
              child: Text(
                isUserFinished ? 'キャンセル' : '判定に進む',
                style: AppTextStyles.bold(
                  fontSize: 17,
                  color: isUserFinished ? Colors.black : Colors.white,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              '${(room.player1_finish == true ? 1 : 0) + (room.player2_finish == true ? 1 : 0)}/2',
              style: AppTextStyles.bold(
                fontSize: 16,
                color:
                    (room.player1_finish == true || room.player2_finish == true)
                        ? Colors.red
                        : Colors.grey,
              ),
            )
          ],
        ),
      ),
    );
  }
}
