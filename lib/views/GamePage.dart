import 'dart:async';
import 'package:debate_project/main.dart';
import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/provider/ai_supabase.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/message_provider.dart';
import 'package:debate_project/router/router.dart';
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
    final scrollController = useScrollController();
    final room = ref.watch(matchingRoomProvider);
    final chats = ref.watch(chatProvider);
    final chatsnotifier = ref.read(chatProvider.notifier);
    final chat_with_ai chatwithai = chat_with_ai();
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser?.id;

    Timer? timer;
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

    useEffect(() {
      if (room.result != null) {
        Future.microtask(() {
          router.go('/finish');
        });
      }
      return null;
    }, [room.result]);

    useEffect(() {
      if (room.player1_finish == true && room.player2_finish == true) {
        if (room.player1Id == user!) {
          timer?.cancel();
          print('判定結果を出す');
          finish.value = true;
          chatwithai.gemini(room.player1Id!, room.roomId!, room.theme!,
              room.player1Choice!);
        }
      }
      return;
    }, [room.player1_finish, room.player2_finish]);

    useEffect(() {
      deadline = room.updatedAt!.add(const Duration(seconds: 90));
      chatsnotifier.subscribeToMessages(room.roomId!);

      timer = Timer.periodic(Duration(seconds: 1), (timer) async {
        final now = await getServerTime();
        final diff = deadline.difference(now).inSeconds;
        if (diff >= 0) {
          countdown.value = diff;
        } else {
          finish.value = true;
          timer.cancel();

          if (room.player1Id == supabase.auth.currentUser?.id) {
            await chatwithai.gemini(room.player1Id!, room.roomId!,
                room.theme!, room.player1Choice!);
          }
        }
      });

      return () {
        timer?.cancel();
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
                              IconButton(
                                icon: Icon(Icons.door_back_door,
                                    color: Colors.white),
                                iconSize: 29,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(),
                                  );
                                },
                              ),
                              // チェックアイコンをドアアイコンの真ん中に重ねて表示
                              if (room.player1_finish == true ||
                                  room.player2_finish == true)
                                Positioned(
                                  top: 3,
                                  child: IconButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(),
                                      );
                                    },
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
                              return _buildMessageBubble(chat, room);
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
          if (finish.value)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white.withOpacity(0.4),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '審査中',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    AnimatedDotsWidget(), // アニメーションする「...」部分
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Chat chat, MatchingRoom matchingRoomState) {
    final user = supabase.auth.currentUser?.id;
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
    final user = supabase.auth.currentUser?.id;
    final isUserFinished = user == room.player1Id
        ? room.player1_finish
        : (user == room.player2Id ? room.player2_finish : false);

    return AlertDialog(
      // Dialog → AlertDialogに変更
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      content: Container(
        // childをcontentに変更
        height: 200,
        width: 300,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              onPressed: () {
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

class AnimatedDotsWidget extends StatefulWidget {
  @override
  _AnimatedDotsWidgetState createState() => _AnimatedDotsWidgetState();
}

class _AnimatedDotsWidgetState extends State<AnimatedDotsWidget> {
  int _dotsCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _dotsCount = (_dotsCount + 1) % 4; // 0,1,2,3 の循環
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '.' * _dotsCount,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 40,
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.none,
      ),
    );
  }
}
