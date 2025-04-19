import 'dart:async';
import 'dart:math';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
//import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChosePage extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomnotifier = ref.watch(matchingRoomProvider.notifier);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser?.id;
    final room = ref.watch(matchingRoomProvider);
    final selectedChoice = useState<bool?>(null);
    final next = useState(false);
    final userState = ref.read(userProvider);
    final otherUserState = ref.read(otherUserProvider);
    final showerror = useState(false);
    final isfirst = useState(false);
    final secondsLeft = useState<int?>(null);

    useEffect(() {
      roomnotifier.pushonline(room, user!);
      return null;
    }, [room.result]);

    useEffect(() {
      if (room.result != null) {
        print(room.roomId);
        print(room.result);
        print('結果が来たよ');
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

    void resetTimer() async {
      DateTime deadline;

      isTimerActive.value = true;
      selectedChoice.value = null;
      deadline = room.updatedAt!.add(const Duration(seconds: 10));
      print('また始まってる');

      timer = Timer.periodic(Duration(seconds: 1), (timer) async {
        final now = await getServerTime();
        final diff = deadline.difference(now).inSeconds;
        if (diff < 0) {
          timer.cancel();
          isTimerActive.value = false;
          if (selectedChoice.value == null) {
            print(selectedChoice.value);
            choice.value = Random().nextBool();
            await roomnotifier.updateChoice(room.roomId!, user!, choice.value!);
          } else {
            await roomnotifier.updateChoice(
                room.roomId!, user!, selectedChoice.value!);
          }
        } else {
          secondsLeft.value = diff;
        }
      });
    }

    String getChoiceText() {
      if (selectedChoice.value == null) return '未選択';
      return selectedChoice.value == true ? room.choice1! : room.choice2!;
    }

    useEffect(() {
      resetTimer();

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
        body: MatchingAnimation(
          user: userState,
          otherUser: otherUserState,
          onAnimationComplete: () {
            // アニメーション完了後の画面遷移
            context.go('/game');
          },
        ),
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

class MatchingAnimation extends StatefulWidget {
  final Users user;
  final Users otherUser;
  final VoidCallback onAnimationComplete;

  MatchingAnimation({
    required this.user,
    required this.otherUser,
    required this.onAnimationComplete,
  });

  @override
  _MatchingAnimationState createState() => _MatchingAnimationState();
}

class _MatchingAnimationState extends State<MatchingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _leftSlideAnimation;
  late Animation<double> _rightSlideAnimation;
  late Animation<double> _vsScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _leftSlideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _rightSlideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _vsScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.5, 0.8, curve: Curves.elasticOut),
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(Duration(seconds: 1), widget.onAnimationComplete);
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // 左側のプロフィール
            Positioned(
              left:
                  MediaQuery.of(context).size.width * _leftSlideAnimation.value,
              top: MediaQuery.of(context).size.height * 0.3,
              child: PlayerProfile(
                name: widget.user.name,
                trophy: widget.user.trophy,
                isLeft: true,
              ),
            ),
            // 右側のプロフィール
            Positioned(
              right: MediaQuery.of(context).size.width *
                  _rightSlideAnimation.value,
              top: MediaQuery.of(context).size.height * 0.3,
              child: PlayerProfile(
                name: widget.otherUser.name,
                trophy: widget.otherUser.trophy,
                isLeft: false,
              ),
            ),
            // VS表示
            Center(
              child: ScaleTransition(
                scale: _vsScaleAnimation,
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(5, 5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlayerProfile extends StatelessWidget {
  final String name;
  final int trophy;
  final bool isLeft;

  PlayerProfile({
    required this.name,
    required this.trophy,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, size: 50),
          ),
          SizedBox(height: 10),
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber),
              SizedBox(width: 5),
              Text(
                trophy.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
