import 'dart:async';
import 'dart:developer';
import 'package:debate_project/adsence/ad_mbanner_provider.dart';
import 'package:debate_project/adsence/ad_provider.dart';
import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/provider/ai_supabase.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/message_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GamePage extends HookConsumerWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdown = useState<int?>(null);
    final finish = useState(false);
    final textControler = useTextEditingController();
    final textFieldFocusNode = useFocusNode();
    // --- ▼ここから追加▼ ---
    // 点滅アニメーションのためのAnimationController
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 800), // 点滅の速度
    );
    // --- ▲ここまで追加▲ ---
    final scrollController = useScrollController();
    final room = ref.watch(matchingRoomProvider);
    final chats = ref.watch(chatProvider);
    final chatsnotifier = ref.read(chatProvider.notifier);
    final chatwithai = ref.read(chatWithAiProvider);
    final supabase = ref.read(supabaseProvider);
    final user = ref.read(currentUserIdProvider);
    final cantap = useState(false);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);
    final isSubscribed = ref.watch(inAppPurchaseManagerProvider).isSubscribed;
    DateTime deadline;

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
      while (true) {
        try {
          print('サーバー時刻の取得を試みます...-------------');
          final now = await getServerTime();
          print('サーバー時刻の取得に成功しました。');
          return now; // 成功したら時刻を返して関数を抜ける
        } catch (e) {
          print('サーバー時刻の取得に失敗しました: $e。3秒後に再試行します。');
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }

    bool gemini = false;
    bool gemini2 = false;
    bool win = false;

    final gametimer = useState<Timer?>(null);
    final finishtimer = useState<Timer?>(null);

    Future<void> countTime() async {
      deadline = room.updatedAt!.add(const Duration(seconds: 182));

      final DateTime serverTime = await getServerTimeWithRetry();

      final clientTime = DateTime.now();
      final timeOffset = serverTime.difference(clientTime);

      gametimer.value = Timer.periodic(Duration(seconds: 1), (timer) async {
        final estimatedServerTime = DateTime.now().add(timeOffset);
        final diff = deadline.difference(estimatedServerTime).inSeconds;
        log(diff.toString());

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
          if (!gemini) {
            gemini = true;
            log('gemiiniを呼び出します');
            if (room.player1Id == user) {
              await chatwithai.gemini(
                  room.player1Id!,
                  room.roomId!,
                  room.theme!,
                  room.choice1!,
                  room.choice2!,
                  room.player1Choice!);
            }
          }
        }
        if (diff < -7) {
          if (!gemini2) {
            if (room.result == null) {
              gemini2 = true;
              log('gemiini2を呼び出します');
              if (room.player2Id == user) {
                await chatwithai.gemini(
                    room.player1Id!,
                    room.roomId!,
                    room.theme!,
                    room.choice1!,
                    room.choice2!,
                    room.player1Choice!);
              }
            }
          }
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

    bool geminia = false;
    bool gemini2a = false;
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
          log(fiinishcount.toString());
          if (fiinishcount >= 1) {
            if (room.player1Id == user) {
              () async {
                if (!geminia) {
                  
              log('geminiを呼び出します試合中断');
                  geminia = true;
                  await chatwithai.gemini(
                      room.player1Id!,
                      room.roomId!,
                      room.theme!,
                      room.choice1!,
                      room.choice2!,
                      room.player1Choice!);
                }
              }();
            }
          }

          if (fiinishcount >= 8) {
            if (room.player2Id == user) {
              if (!gemini2a) {
                gemini2a = true;
                log('gemini2を呼び出します試合中断');
                // player2のAIにメッセージを送信
                await chatwithai.gemini(
                    room.player1Id!,
                    room.roomId!,
                    room.theme!,
                    room.choice1!,
                    room.choice2!,
                    room.player1Choice!);
              }
            }
          }

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

    // --- ▼ここから追加▼ ---
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
      // ゲーム終了時 (room.result != null) の広告表示ロジック
      if (room.result != null) {
        Future.microtask(() async {
          // 非同期処理を行うためasync/awaitを使用

          // 広告を表示しない場合、直接次の画面へ遷移
          router.go('/finish');
        });
      }
      return null; // Clean-up は不要
    }, [room.result]);

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
      countTime();

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
                        style: const TextStyle(
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
                              style: TextStyle(
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
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 17),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                // cantap.value が true の場合は完全に不透明 (1.0)
                                // cantap.value が false の場合は半透明 (例: 0.5)
                                opacity:
                                    cantap.value ? 1.0 : 0.5, // ここで透明度を調整できます
                                child: IconButton(
                                  icon: Icon(Icons.door_back_door,
                                      color: Colors.white), // アイコンの色はそのまま
                                  iconSize: 29,
                                  onPressed: cantap
                                          .value // onPressed が null のときにタッチ操作が無効になる
                                      ? () {
                                          showDialog(
                                            context: context,
                                            builder: (context) =>
                                                Dialog(), // 表示したいダイアログウィジェット
                                          );
                                        }
                                      : null, // cantap.value が false の時は null にしてボタンを無効化
                                ),
                              ),
                              // チェックアイコンをドアアイコンの真ん中に重ねて表示
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
                      ],
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
                      style: const TextStyle(
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
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            reverse: true,
                            itemCount: chats.length,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 16),
                            itemBuilder: (context, index) {
                              final chat = chats[index];
                              return _buildMessageBubble(
                                  chat, room, supabase, user!);
                            },
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                offset: Offset(0, -1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: TextField(
                                    focusNode: textFieldFocusNode,
                                    controller: textControler,
                                    style: const TextStyle(color: Colors.black),
                                    decoration: InputDecoration(
                                      hintText: '論破しよう',
                                      hintStyle:
                                          TextStyle(color: Colors.grey[600]),
                                      border: InputBorder.none,
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
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    if (textControler.text.trim().isNotEmpty) {
                                      ref
                                          .read(chatProvider.notifier)
                                          .sendMesage(room.roomId!,
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
                                      color: Colors.white, size: 20),
                                ),
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
          // --- ▼ここから追加▼ ---
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
          // --- ▲ここまで追加▲ ---
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Chat chat, MatchingRoom matchingRoomState,
      SupabaseClient supabase, String user) {
    final isCurrentUser = chat.senderId == user;

    return Padding(
      padding: EdgeInsets.only(
        left: isCurrentUser ? 64 : 8,
        right: isCurrentUser ? 8 : 64,
        top: 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.green : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              chat.content,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
                fontSize: 16,
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
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
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
              onPressed:(room.player1_finish == true && room.player2_finish == true)?
              null: () {
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
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isUserFinished ? Colors.black : Colors.white,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              '${(room.player1_finish == true ? 1 : 0) + (room.player2_finish == true ? 1 : 0)}/2',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
