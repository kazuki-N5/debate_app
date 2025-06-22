import 'dart:async';
import 'dart:math';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
//import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';

class ChosePage extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomnotifier = ref.watch(matchingRoomProvider.notifier);
    final supabase = ref.read(supabaseProvider);
    final user = ref.read(currentUserIdProvider);
    final room = ref.watch(matchingRoomProvider);
    final selectedChoice = useState<bool?>(null);
    final next = useState(false);
    final showerror = useState(false);
    final isfirst = useState(false);
    final secondsLeft = useState<int?>(null);

    useEffect(() {
      //roomnotifier.pushonline(room, user!);
      return null;
    }, []);

    useEffect(() {
      if (room.result != null) {
        Future.microtask(() {
          router.go('/finish');
        });
      }
      return null;
    }, [room.result]);

// タイマー状態

    final isTimerActive = useState<bool>(true);
    Timer? timer;
    final choice = useState<bool?>(null);

    Future<DateTime> getServerTime() async {
      final response = await supabase.rpc('get_server_time');
      return DateTime.parse(response);
    }

    String formatTime(int seconds) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes.toString()}:${remainingSeconds.toString().padLeft(2, '0')}';
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

    void resetTimer() async {
      timer?.cancel();
      DateTime deadline;

      final DateTime serverTime = await getServerTimeWithRetry();

      final clientTime = DateTime.now();
      final timeOffset = serverTime.difference(clientTime);
      isTimerActive.value = true;
      selectedChoice.value = null;
      deadline = room.updatedAt!.add(const Duration(seconds: 8));
      print('また始まってる');
      bool hasChoiceBeenUpdated = false;

      timer = Timer.periodic(Duration(seconds: 1), (timer) async {
        final estimatedServerTime = DateTime.now().add(timeOffset);
        final diff = deadline.difference(estimatedServerTime).inSeconds;
        if (diff >= 0) {
          secondsLeft.value = diff;
        }

        if (diff < 0) {
          isTimerActive.value = false;
          
          if (!hasChoiceBeenUpdated) {
            
          hasChoiceBeenUpdated = true;
            if (selectedChoice.value == null) {
              print(selectedChoice.value);
              choice.value = Random().nextBool();
              await roomnotifier.updateChoice(
                  room.roomId!, user!, choice.value!, 3);
            } else {
              await roomnotifier.updateChoice(
                  room.roomId!, user!, selectedChoice.value!, 3);
            }
          }
        }
        if (diff < -9) {
          timer.cancel();
          router.go('/home');
        }
      });
    }

    String getChoiceText() {
      if (selectedChoice.value == null) return '未選択';
      return selectedChoice.value == true ? room.choice1! : room.choice2!;
    }

    useEffect(() {
      return () {
        timer?.cancel();
      };
    }, []);

    useEffect(() {
      if (room.player1Choice != null && room.player2Choice != null) {
        if (room.player1Choice != room.player2Choice) {
          print(room);
          next.value = true;
        }
      }
      return null;
    }, [room.player1Choice, room.player2Choice]);

    useEffect(() {
      if (room.player1Choice != null && room.player2Choice != null) {
      } else {
        print('こんにちわ');
        resetTimer();
        if (isfirst.value == false) {
          isfirst.value = true;
          return null;
        }
        showerror.value = true;
        // 1秒後に非表示
        Future.delayed(Duration(seconds: 1), () {
          showerror.value = false;
        });
      }
      return null;
    }, [room.change]);

    // アニメーション表示中の場合
    if (next.value) {
      return Scaffold(
        backgroundColor: Colors.blue, // または任意の背景色
        body: BattleTransitionScreen(),
      );
    }

// 自分がどちらのプレイヤーでもない場合（エラー）

    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        title: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer,
                    size: 20,
                    color: secondsLeft.value != null && secondsLeft.value! <= 3
                        ? Colors.red
                        : Colors.grey[800]),
                SizedBox(width: 5),
                Text(
                  secondsLeft.value != null
                      ? formatTime(secondsLeft.value!)
                      : '-',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          secondsLeft.value != null && secondsLeft.value! <= 3
                              ? Colors.red
                              : Colors.grey[800]),
                )
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(room.theme!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 3.0,
                            color: Colors.black26,
                          ),
                        ],
                      )),
                ),
                const SizedBox(height: 50),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildChoiceButton(
                      text: room.choice1!,
                      isSelected: selectedChoice.value == true,
                      onPressed: isTimerActive.value
                          ? () => selectedChoice.value = true
                          : null,
                      activeColor: Colors.green,
                    ),
                    const SizedBox(width: 40),
                    _buildChoiceButton(
                      text: room.choice2!,
                      isSelected: selectedChoice.value == false,
                      onPressed: isTimerActive.value
                          ? () => selectedChoice.value = false
                          : null,
                      activeColor: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text('現在の選択: ${getChoiceText()}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2.0,
                          color: Colors.black26,
                        ),
                      ],
                    )),
                const SizedBox(height: 30),
                AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: showerror.value ? 1.0 : 0.0,
                  child: Text(
                    '選択が被りました',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2.0,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildChoiceButton({
  required String text,
  required bool isSelected,
  required VoidCallback? onPressed,
  required Color activeColor,
}) {
  return Container(
    height: 200,
    width: 120,
    child: GestureDetector(
      onTapDown: (_) => onPressed?.call(),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: isSelected ? activeColor.withOpacity(0.3) : Colors.black26,
              blurRadius: isSelected ? 15 : 8,
              offset: isSelected ? Offset(0, 8) : Offset(0, 4),
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 3,
          ),
        ),
        transform: Matrix4.identity()
          ..translate(0.0, isSelected ? 4.0 : 0.0, 0.0),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isSelected ? activeColor : Colors.black87,
            ),
          ),
        ),
      ),
    ),
  );
}

class UserProfileCard extends StatelessWidget {
  final Users userData; // 型を Users に変更
  final CrossAxisAlignment? textAlignment;

  const UserProfileCard({
    Key? key,
    required this.userData,
    this.textAlignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: textAlignment ?? CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[300],
          child:
              (userData.avatar_url != null && userData.avatar_url!.isNotEmpty)
                  ? ClipOval(
                      child: FadeInImage.memoryNetwork(
                        placeholder: kTransparentImage, // 透明なプレースホルダーを使用
                        image: userData.avatar_url!, // プロパティ名を avatar_url に修正
                        fit: BoxFit.cover,
                        width: 100, // radius * 2
                        height: 100, // radius * 2
                        imageErrorBuilder: (context, error, stackTrace) {
                          // 画像の読み込みエラー時はアイコンを表示
                          return const Center(
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    )
                  : const Center(
                      // userData.avatar_urlがnullまたは空の場合もアイコンを表示
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
        ),
        const SizedBox(height: 12),
        Text(
          // userData.nameがnullの場合、空文字を表示 (または適切なフォールバックテキスト)
          // Users.fromMap で name: map['name'].toString() となっているので、
          // map['name']がnullだと "null" という文字列になる可能性があります。
          // もしそうなっていて、"null" と表示したくない場合は、
          // (userData.name == "null" ? "ゲスト" : userData.name ?? '不明なユーザー') のような処理も検討できます。
          // ここでは、UsersクラスのnameがString?で、適切にnullが渡される前提で userData.name ?? '' とします。
          userData.name ?? 'プレイヤー', // nameがnullの場合のフォールバック
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: textAlignment == CrossAxisAlignment.start
              ? TextAlign.left
              : textAlignment == CrossAxisAlignment.end
                  ? TextAlign.right
                  : TextAlign.center,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[600], size: 24),
            const SizedBox(width: 6),
            Text(
              userData.trophy.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BattleTransitionScreen extends ConsumerStatefulWidget {
  const BattleTransitionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BattleTransitionScreen> createState() =>
      _BattleTransitionScreenState();
}

class _BattleTransitionScreenState extends ConsumerState<BattleTransitionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _userSlideAnimation;
  late Animation<Offset> _otherUserSlideAnimation;
  late Animation<double> _vsFadeAnimation;
  late Animation<double> _vsScaleAnimation;

  @override
  void initState() {
    super.initState(); // 仮ルーターにコンテキストをセット

    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000), // アニメーション全体の時間
      vsync: this,
    );

    // 自分: 左から中央少し手前へ
    _userSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // 画面外左
      end: const Offset(-0.1, 0.0), // 画面中央より少し左
    ).animate(CurvedAnimation(
      parent: _controller,
      curve:
          const Interval(0.0, 0.6, curve: Curves.easeInOutCubic), // 全体の0%～60%
    ));

    // 相手: 右から中央少し手前へ
    _otherUserSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // 画面外右
      end: const Offset(0.1, 0.0), // 画面中央より少し右
    ).animate(CurvedAnimation(
      parent: _controller,
      curve:
          const Interval(0.0, 0.6, curve: Curves.easeInOutCubic), // 全体の0%～60%
    ));

    // VS: フェードイン
    _vsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.7, curve: Curves.easeIn), // 全体の50%～80%で表示
      ),
    );

    // VS: スケールアップ
    _vsScaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.elasticOut), // 伸縮する感じ
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            // 実際のプロジェクトのrouterインスタンスを使用してください
            // 例: GoRouter.of(context).go('/game');
            // 例: ref.read(routerProvider).go('/game');
            router.go('/game');
          }
        });
      }
    });

    // initStateの最後に呼び出すことで、ビルド後にアニメーションが開始される
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Users userState = ref.watch(userProvider);
    final Users otherUserState = ref.watch(otherUserProvider);

    return Scaffold(
      backgroundColor: Colors.blue, // 背景色
      body: Stack(
        children: [
          // 自分のプロフィール (左から)
          Align(
            alignment: Alignment.centerLeft,
            child: SlideTransition(
              position: _userSlideAnimation,
              child: Padding(
                padding: const EdgeInsets.only(left: 30.0), // 画面端からのパディング
                child: UserProfileCard(
                    userData: userState,
                    textAlignment: CrossAxisAlignment.start),
              ),
            ),
          ),

          // 相手のプロフィール (右から)
          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: _otherUserSlideAnimation,
              child: Padding(
                padding: const EdgeInsets.only(right: 30.0), // 画面端からのパディング
                child: UserProfileCard(
                    userData: otherUserState,
                    textAlignment: CrossAxisAlignment.end),
              ),
            ),
          ),

          // VS テキスト
          Center(
            child: FadeTransition(
              opacity: _vsFadeAnimation,
              child: ScaleTransition(
                scale: _vsScaleAnimation,
                child: Text(
                  "VS",
                  style: TextStyle(
                    fontSize: 90,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 15, 3, 3),
                    fontFamily: 'Impact', // かっこいいフォント (システムにあれば)
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(5.0, 5.0),
                      ),
                      const Shadow(
                        // 縁取りっぽく
                        blurRadius: 0.0,
                        color: Colors.white,
                        offset: Offset(1.0, 1.0),
                      ),
                      const Shadow(
                        blurRadius: 0.0,
                        color: Colors.white,
                        offset: Offset(-1.0, -1.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
