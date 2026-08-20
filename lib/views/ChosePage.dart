// ignore_for_file: file_names, avoid_print, use_build_context_synchronously, deprecated_member_use
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer';

import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/match_error_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Homepage_view_model.dart';
import 'package:debate_project/view_model/Profile_model.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
//import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChosePage extends HookConsumerWidget {
  const ChosePage({super.key});

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
    final timerRef = useRef<Timer?>(null);
    final matchErrorService = ref.read(matchErrorServiceProvider);

    useEffect(() {
      if (room.winner != null) {
        Future.microtask(() {
          router.go('/finish');
        });
      }
      return null;
    }, [room.winner]);

    final isTimerActive = useState<bool>(true);

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

    void resetTimer() async {
      timerRef.value?.cancel();
      DateTime deadline;

      log('【DEBUG】ChosePage: resetTimer initiated');
      final DateTime serverTime = await getServerTimeWithRetry();

      final clientTime = DateTime.now();
      final timeOffset = serverTime.difference(clientTime);
      isTimerActive.value = true;
      selectedChoice.value = null;
      if (room.isBbs == true) {
        deadline = room.updatedAt!.add(const Duration(seconds: 16));
      } else {
        deadline = room.updatedAt!.add(const Duration(seconds: 9));
      }
      print('また始まってる');
      bool hasChoiceBeenUpdated = false;
      log('【DEBUG】ChosePage: Timer start. deadline: $deadline');
      timerRef.value = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final estimatedServerTime = DateTime.now().add(timeOffset);
        final diff = deadline.difference(estimatedServerTime).inSeconds;
        if (diff >= 0) {
          secondsLeft.value = diff;
          log('【DEBUG】ChosePage: Timer tick, secondsLeft: ${secondsLeft.value}, diff: $diff');
        }

        if (diff < 0) {
          isTimerActive.value = false;

          if (!hasChoiceBeenUpdated) {
            hasChoiceBeenUpdated = true;
            if (selectedChoice.value != null) {
              await roomnotifier.updateChoice(
                  room.roomId!, user!, selectedChoice.value!, 3);
            }
          }
        }
        if (diff < -5) {
          timer.cancel();
          timerRef.value = null;

          if (context.mounted) {
            final latestRoom = ref.read(matchingRoomProvider);
            final isPlayer1 = latestRoom.player1Id == user;
            final myChoice =
                isPlayer1 ? latestRoom.player1Choice : latestRoom.player2Choice;
            final opponentChoice =
                isPlayer1 ? latestRoom.player2Choice : latestRoom.player1Choice;

            String message = '通信エラーが発生しました';
            if (myChoice == null) {
              message = 'あなたが選択しませんでした';
              // 自分が選択しなかった → 相手の勝ち（勝敗を確定して「対戦中」が残るのを防ぐ）
              final opponentId =
                  isPlayer1 ? latestRoom.player2Id : latestRoom.player1Id;
              if (opponentId != null) {
                await roomnotifier.win(latestRoom, opponentId);
              }
            } else if (opponentChoice == null) {
              message = '相手が選択しませんでした';
              // 相手が選択しなかった → 自分の勝ち（勝敗を確定）
              if (user != null) {
                await roomnotifier.win(latestRoom, user);
              }
            }

            if (context.mounted) {
              matchErrorService.showMatchEndMessage('マッチ終了：$message', 0.68);
            }
            ref.read(friendmatchProvider.notifier).state = false;
            await roomnotifier.delete();
            router.go('/home');
          }
        }
      });
    }

    String getChoiceText() {
      if (selectedChoice.value == null) return '未選択';
      return selectedChoice.value == true ? room.choice1! : room.choice2!;
    }

    useEffect(() {
      return () {
        log('【DEBUG】ChosePage: unmounted. Cancelling timer.');
        ref.read(friendmatchProvider.notifier).state = false;
        timerRef.value?.cancel();
        if (timerRef.value == null) {
          log('【DEBUG】ChosePage: timerRef.value was null at unmount!');
        }
      };
    }, []);

    useEffect(() {
      if (room.player1Choice != null && room.player2Choice != null) {
        if (room.player1Choice != room.player2Choice) {
          log(room.toString());
          next.value = true;
          timerRef.value?.cancel();
        }
      }
      return null;
    }, [room.player1Choice, room.player2Choice]);

    useEffect(() {
      if (room.player1Choice != null && room.player2Choice != null) {
      } else {
        resetTimer();
        if (isfirst.value == false) {
          isfirst.value = true;
          return null;
        }
        showerror.value = true;
        // 2秒後に非表示
        Future.delayed(const Duration(seconds: 2), () {
          showerror.value = false;
        });
      }
      return null;
    }, [room.change]);

    // アニメーション表示中の場合
    if (next.value) {
      return const Scaffold(
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
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
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
                const SizedBox(width: 5),
                Text(
                  secondsLeft.value != null
                      ? formatTime(secondsLeft.value!)
                      : '-',
                  style: AppTextStyles.bold(
                      fontSize: 16,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(room.theme!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bold(
                        fontSize: 32,
                        color: Colors.white,
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
                    style: AppTextStyles.bold(
                      fontSize: 20,
                      color: Colors.white,
                    )),
                const SizedBox(height: 30),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: showerror.value ? 1.0 : 0.0,
                  child: Text(
                    '選択が被りました',
                    style: AppTextStyles.bold(
                      fontSize: 20,
                      color: Colors.red,
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
  return SizedBox(
    height: 200,
    width: 120,
    child: GestureDetector(
      onTapDown: (_) => onPressed?.call(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: isSelected ? activeColor.withValues(alpha: 0.3) : Colors.black26,
              blurRadius: isSelected ? 15 : 8,
              offset: isSelected ? const Offset(0, 8) : const Offset(0, 4),
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
            style: AppTextStyles.bold(
              fontSize: 24,
              color: isSelected ? activeColor : Colors.black87,
            ),
          ),
        ),
      ),
    ),
  );
}

class BattleTransitionScreen extends HookConsumerWidget {
  const BattleTransitionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 4000),
    );

    final userSlideAnimation = useMemoized(() {
      return Tween<Offset>(
        begin: const Offset(-1.0, 0.0),
        end: const Offset(-0.1, 0.0),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
      ));
    }, [controller]);

    final otherUserSlideAnimation = useMemoized(() {
      return Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: const Offset(0.1, 0.0),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
      ));
    }, [controller]);

    final vsFadeAnimation = useMemoized(() {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.5, 0.7, curve: Curves.easeIn),
        ),
      );
    }, [controller]);

    final vsScaleAnimation = useMemoized(() {
      return Tween<double>(begin: 0.5, end: 1.2).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.5, 0.9, curve: Curves.elasticOut),
        ),
      );
    }, [controller]);

    useEffect(() {
      final room = ref.read(matchingRoomProvider);
      if (room.roomId != null) {
        ref
            .read(matchingRoomProvider.notifier)
            .setupPresenceChannel(room.roomId!);
      }

      void statusListener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) {
              router.go('/game');
            }
          });
        }
      }

      controller.addStatusListener(statusListener);
      controller.forward();

      return () => controller.removeStatusListener(statusListener);
    }, [controller]);

    final Users userState = ref.watch(userProvider);
    final Users otherUserState = ref.watch(otherUserProvider);
    final userId = ref.watch(currentUserIdProvider);

    useEffect(() {
      final room = ref.read(matchingRoomProvider);
      final otherUserId =
          room.player1Id == userId ? room.player2Id : room.player1Id;
      if (otherUserId != null &&
          ref.read(otherUserProvider).id != otherUserId) {
        log('ChosePage: 対戦相手情報取得開始: $otherUserId');
        ref
            .read(otherUserProvider.notifier)
            .fetchOtherUserWithRetry(otherUserId);
      }
      return null;
    }, [
      ref.watch(matchingRoomProvider).player1Id,
      ref.watch(matchingRoomProvider).player2Id,
      userId
    ]);

    return Scaffold(
      backgroundColor: Colors.blue,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SlideTransition(
              position: userSlideAnimation,
              child: Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: UserProfileCard(
                    userData: userState,
                    textAlignment: CrossAxisAlignment.start),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: otherUserSlideAnimation,
              child: Padding(
                padding: const EdgeInsets.only(right: 30.0),
                child: UserProfileCard(
                    userData: otherUserState,
                    textAlignment: CrossAxisAlignment.end),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: vsFadeAnimation,
              child: ScaleTransition(
                scale: vsScaleAnimation,
                child: Text(
                  "VS",
                  style: GoogleFonts.lilitaOne(
                    fontSize: 50,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
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
