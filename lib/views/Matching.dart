// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

import 'package:debate_project/modes/users.dart';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/match_error_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Profile_model.dart';
// import 'package:debate_project/router/router.dart'; // context.goを使うため不要になることが多い

import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart'; // flutter_hooksをインポート
import 'package:hooks_riverpod/hooks_riverpod.dart'; // hooks_riverpodをインポート
import 'package:go_router/go_router.dart';
import 'package:debate_project/adsence/ad_banner_provider.dart';
import 'package:debate_project/adsence/ad_provider.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:developer';

// gochoseProvider と splashProvider は削除し、matchingRoomProvider の状態を直接 listen します。

// ConsumerStatefulWidgetからHookConsumerWidgetに変更
class MatchingPage extends HookConsumerWidget {
  // HookConsumerWidgetではconstコンストラクタを推奨
  const MatchingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // UI更新のために状態をwatch
    final room = ref.watch(matchingRoomProvider);
    // ボタン押下などで使うnotifierはreadで十分
    final roomNotifier = ref.read(matchingRoomProvider.notifier);
    final bannerAd = ref.watch(matchingBannerAdProvider);
    final isSubscribe = ref.watch(inAppPurchaseManagerProvider).isSubscribed;

    // final go = ref.watch(goProvider);

    // マッチング成功時の画面遷移をuseEffectで管理
    // マッチング成功時の画面遷移
    final shouldShowTransition = room.player2Id != null;

    if (shouldShowTransition) {
      return const Scaffold(
        backgroundColor: Colors.blue,
        body: BattleTransitionScreen2(),
      );
    }

    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // go == false の場合のみマッチング待機UIを表示
                  Stack(
                    children: [
                      // アニメーション中の四角形を画面中央に配置
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // 最小限の高さに
                            children: [
                              Text(
                                'マッチング中...',
                                style: AppTextStyles.bold(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const BlinkingMatchingIndicator(),
                            ],
                          ),
                        ),
                      ),
                      // キャンセルボタンを画面下部に配置（中心より下へ）
                      Align(
                        alignment: const Alignment(0, 0.45), // 位置を少し上に調整
                        child: ElevatedButton(
                          onPressed: () {
                            // ボタン押下時のキャンセル処理
                            if (room.roomId != null) {
                              log('User pressed Cancel button for roomId: ${room.roomId}');
                              roomNotifier.cancelMatching(room.roomId!);
                            } else {
                              // go_routerの推奨プラクティスに従いcontext.goを使用
                              context.go('/home');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            'キャンセル',
                            style: AppTextStyles.bold(
                              color: Colors.blue[600],
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // バナー広告表示エリア
            // ホームと同じ位置に揃える: ホームは bottom: circleNavBarHeight + adBottomPadding = 60 + 19.2 = 79.2
            // で広告を底から約79px浮かせている。waitは下部に広い空間があるため、他UIは動かさず広告のみ嵩上げする。
            if (isSubscribe == false)
              if (bannerAd != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 79.2),
                  child: Container(
                    alignment: Alignment.center,
                    width: bannerAd.size.width.toDouble(),
                    height: bannerAd.size.height.toDouble(),
                    child: AdWidget(ad: bannerAd),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 79.2),
                  child: SizedBox(
                    height: AdSize.banner.height.toDouble(),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// StatefulWidgetからHookWidgetに変更
class BlinkingMatchingIndicator extends HookWidget {
  const BlinkingMatchingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // useAnimationControllerフックでAnimationControllerを生成・管理
    // これによりinitState, dispose, TickerProviderStateMixinが不要になる
    final controller = useAnimationController(
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // useMemoizedでAnimationを生成し、controllerが変わらない限り再生成しない
    final animation = useMemoized(
        () => Tween(begin: 0.5, end: 1.0).animate(controller), [controller]);

    return FadeTransition(
      opacity: animation,
      child: const Icon(
        Icons.search,
        size: 80,
        color: Colors.white,
      ),
    );
  }
}

class BattleTransitionScreen2 extends HookConsumerWidget {
  const BattleTransitionScreen2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerRef = useRef<Timer?>(null);
    final room = ref.watch(matchingRoomProvider);
    final userId = ref.watch(currentUserIdProvider);
    final secondsLeft = useState<int?>(null);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);
    final isButtonPressed = useState(false);
    final hasAutoGoCalled = useState(false); // 自動準備完了の連投防止フラグを追加
    final usernotifier = ref.read(userProvider.notifier);
    final matchErrorService = ref.read(matchErrorServiceProvider);
    // AnimationControllerをフックで初期化
    // SingleTickerProviderStateMixinの代わりにuseSingleTickerProviderフックを使用
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 4000),
    );

    void showErrorDialog(BuildContext context) {
      const Color dialogBackgroundColor = Color(0xFF42A5F5);
      const Color textColor = Colors.white;
      const Color buttonTextColor =
          Color(0xFF1565C0); // ホーム画面のボタン内テキストに近い青 (例: Colors.blue[800])
      const Color buttonBackgroundColor = Colors.white;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: dialogBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0), // 角丸を少し大きめに
            ),
            titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
            contentPadding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
            title: Text(
              'ネットワークエラー',
              textAlign: TextAlign.center,
              style: AppTextStyles.bold(
                color: textColor,
                fontSize: 20.0,
              ),
            ),
            content: Text(
              'データの取得に失敗しました。\nもう一度お試しください。',
              textAlign: TextAlign.center,
              style: AppTextStyles.notoSans(
                color: textColor,
                fontSize: 16.0,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.only(bottom: 20.0, top: 8.0),
            actions: <Widget>[
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: buttonBackgroundColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0), // ボタンも角丸に
                  ),
                ),
                icon: const Icon(Icons.refresh, color: buttonTextColor, size: 22.0),
                label: Text(
                  'やり直す',
                  style: AppTextStyles.bold(
                    color: buttonTextColor,
                    fontSize: 16.0,
                  ),
                ),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    await usernotifier.fetchUser(userId!);

                    router.go('/home');
                  } catch (e) {
                    showErrorDialog(context);
                  }
                  // 再試行コールバックを実行
                },
              ),
            ],
          );
        },
      ).then((_) {});
    }

    // 各アニメーションをフックで定義
    // useMemoizedを使用して、コントローラーが再生成されない限りアニメーションオブジェクトを再利用する
    // 自分: 左から中央少し手前へ
    final userSlideAnimation = useMemoized(() {
      return Tween<Offset>(
        begin: const Offset(-1.0, 0.0), // 画面外左
        end: const Offset(-0.1, 0.0), // 画面中央より少し左
      ).animate(CurvedAnimation(
        parent: controller,
        curve:
            const Interval(0.0, 0.6, curve: Curves.easeInOutCubic), // 全体の0%～60%
      ));
    }, [controller]);

    // 相手: 右から中央少し手前へ
    final otherUserSlideAnimation = useMemoized(() {
      return Tween<Offset>(
        begin: const Offset(1.0, 0.0), // 画面外右
        end: const Offset(0.1, 0.0), // 画面中央より少し右
      ).animate(CurvedAnimation(
        parent: controller,
        curve:
            const Interval(0.0, 0.6, curve: Curves.easeInOutCubic), // 全体の0%～60%
      ));
    }, [controller]);

    // VS: フェードイン
    final vsFadeAnimation = useMemoized(() {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve:
              const Interval(0.5, 0.7, curve: Curves.easeIn), // 全体の50%～70%で表示
        ),
      );
    }, [controller]);

    // VS: スケールアップ
    final vsScaleAnimation = useMemoized(() {
      return Tween<double>(begin: 0.5, end: 1.2).animate(
        CurvedAnimation(
          parent: controller,
          curve: const Interval(0.5, 0.9, curve: Curves.elasticOut), // 伸縮する感じ
        ),
      );
    }, [controller]);

    final buttonsFadeAnimation = useMemoized(() {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          // VSテキストが表示された後、少し遅れてフェードインを開始
          curve: const Interval(0.7, 0.95, curve: Curves.easeIn),
        ),
      );
    }, [controller]);

    // initStateやdisposeのロジックをuseEffectフックで管理
    useEffect(() {
      // アニメーションの状態を監視するリスナー
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 800), () {
            // HookConsumerWidgetでは `mounted` のチェックは通常不要ですが、
            // 非同期処理後にcontextに依存する処理を行う場合は念のため確認します。
            // `context.mounted` はFlutter 3.7以降で利用可能です。
            if (context.mounted) {
              // 実際のプロジェクトのrouterインスタンスを使用してください
              // 例: GoRouter.of(context).go('/game');
              // 例: ref.read(routerProvider).go('/game');
              print("アニメーション完了、画面遷移します。");
            }
          });
        }
      }

      controller.addStatusListener(listener);

      // ビルド後にアニメーションを開始
      // WidgetsBinding.instance.addPostFrameCallbackに相当する処理
      controller.forward();

      // クリーンアップ関数（dispose時に呼ばれる）
      // リスナーをここで削除する
      return () {
        controller.removeStatusListener(listener);
        // useAnimationControllerが自動でdisposeしてくれるので、
        // controller.dispose() を呼ぶ必要はありません。
      };
    }, [
      controller
    ]); // 第2引数に[controller]を渡すことで、controllerのインスタンスが変わらない限りこのeffectは再実行されない

    // matchingRoomProvider の変更を listen してナビゲーションを制御
    ref.listen<MatchingRoom>(matchingRoomProvider, (previous, next) async {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      // 1. 対戦相手が見つかった時の処理 (UserProfileの取得)
      if (next.player2Id != null &&
          (previous == null || previous.player2Id == null)) {
        log('対戦相手発見 (UI Listener)');
        final otherUserId =
            next.player1Id == userId ? next.player2Id : next.player1Id;
        if (otherUserId != null) {
          await ref
              .read(otherUserProvider.notifier)
              .fetchOtherUserWithRetry(otherUserId);
        }
      }

      // 2. 両者が「スタート」を押した時の処理 -> /chose へ遷移
      if (next.player1_go == true &&
          next.player2_go == true &&
          !(previous?.player1_go == true && previous?.player2_go == true)) {
        log('両者の準備完了 -> /choseに移動');
        // インタースティシャル広告をプリロード（未購読時）
        // 対戦開始より前にロード開始し、FinishPage表示時にロード済み広告を表示できるようにする。
        // 既にロード済み/ロード中の場合は loadAd 内のガードにより自動的にスキップされる。
        try {
          if (!ref.read(inAppPurchaseManagerProvider).isSubscribed) {
            ref.read(adNotifierProvider.notifier).loadAd();
          }
        } catch (e) {
          debugPrint('Interstitial Ad: Preload on match start failed: $e');
        }
        router.go('/chose');
      }

      // 3. どちらかがキャンセルした、または退出した時の処理 (Splash相当)
      if ((next.player1_go == false && previous?.player1_go != false) ||
          (next.player2_go == false && previous?.player2_go != false)) {
        log('プレイヤーの退出を検知');

        if ((next.player1Id == userId && next.player1_go == false) ||
            (next.player2Id == userId && next.player2_go == false)) {
          log('自分が退出したためホームへ');
          try {
            await ref.read(userProvider.notifier).fetchUser(userId);
            router.go('/home');
          } catch (e) {
            showErrorDialog(context);
          }
        } else {
          log('相手が退出したため');
          if (context.mounted) {
            matchErrorService.showMatchEndMessage('マッチ終了：相手がキャンセルをしました', 0.68);
          }
          final isFriend = next.password != null && next.password!.isNotEmpty;
          final isBbs = next.isBbs == true;
          if (isFriend || isBbs) {
            log('フレンドマッチまたはレスバのためホームへ戻ります');
            await ref.read(matchingRoomProvider.notifier).delete();
            router.go('/home');
          } else {
            log('ランダムマッチのため再マッチング');
            try {
              ref.read(matchingRoomProvider.notifier).findMatch('', '', '', '');
            } catch (e) {
              router.go('/home');
            }
          }
        }
      }
    });

    final supabase = ref.read(supabaseProvider);

    useEffect(() {
      final otherUserId =
          room.player1Id == userId ? room.player2Id : room.player1Id;
      
      final currentFetchedId = ref.read(otherUserProvider).id;
      log('【DEBUG】対戦相手情報取得の判定: currentFetchedId=$currentFetchedId, nextOpponentId=$otherUserId');
      
      if (otherUserId != null && currentFetchedId != otherUserId) {
        log('【DEBUG】対戦相手情報の取得を開始します: $otherUserId');
        ref
            .read(otherUserProvider.notifier)
            .fetchOtherUserWithRetry(otherUserId);
      }
      return null;
    }, [room.player1Id, room.player2Id, userId]);

    useEffect(() {
      // 内部で非同期関数を定義して実行する
      Future<void> startTimer() async {
        log('【DEBUG】Matching: startTimer initiated');
        // --- 既存のresetTimerのロジックをここに移動 ---
        Future<DateTime> getServerTime() async {
          final response = await supabase.rpc('get_server_time');
          return DateTime.parse(response);
        }

        Future<DateTime> getServerTimeWithRetry() async {
          try {
            print('サーバー時刻の取得を試みます...-------------');
            final now = await getServerTime();
            print('サーバー時刻の取得に成功しました。');
            return now;
          } catch (e) {
            print('サーバー時刻の取得に失敗しました: $e。');
            rethrow;
          }
        }

        timerRef.value?.cancel();

        // updatedAtがnullの場合はタイマーを開始しない
        if (room.updatedAt == null) {
          print("room.updatedAt is null. Timer cannot be started.");
          return;
        }

        final DateTime serverTime = await getServerTimeWithRetry();
        final clientTime = DateTime.now();
        final timeOffset = serverTime.difference(clientTime);
        final DateTime deadline =
            room.updatedAt!.add(const Duration(seconds: 7));

        log('タイマーを開始します。');

        log('【DEBUG】Matching: Timer periodic start. deadline: $deadline');
        timerRef.value =
            Timer.periodic(const Duration(seconds: 1), (timer) async {
          final estimatedServerTime = DateTime.now().add(timeOffset);
          final diff = deadline.difference(estimatedServerTime).inSeconds;

          log('【DEBUG】Matching: Timer tick, secondsLeft: ${secondsLeft.value}, diff: $diff');
          if (diff >= 0) {
            secondsLeft.value = diff;
          } else {
            isButtonPressed.value = true;
          }
          
          if (diff <= 0 && room.isBbs == true) {
            timer.cancel();
            timerRef.value = null;
            if (context.mounted) {
              roomnotifier.hasgotomatching = true;
              roomnotifier.hassplash = false;
              router.go('/chose');
            }
            return;
          }

          if (diff <= -5) {
            timer.cancel();
            timerRef.value = null;

            if (context.mounted) {
              final latestRoom = ref.read(matchingRoomProvider);
              final isPlayer1 = latestRoom.player1Id == userId;
              final myGo =
                  isPlayer1 ? latestRoom.player1_go : latestRoom.player2_go;
              final opponentGo =
                  isPlayer1 ? latestRoom.player2_go : latestRoom.player1_go;

              String message = '通信エラーが発生しました';
              if (myGo != true) {
                message = 'あなたが準備完了しませんでした';
              } else if (opponentGo != true) {
                message = '相手が準備完了しませんでした';
              }

              if (context.mounted) {
                matchErrorService.showMatchEndMessage('マッチ終了：$message', 0.68);
              }

              final isFriend = latestRoom.password != null &&
                  latestRoom.password!.isNotEmpty;
              final isBbs = latestRoom.isBbs == true;

              if (isFriend || isBbs || myGo != true) {
                await roomnotifier.delete();
                router.go('/home');
              } else {
                try {
                  roomnotifier.findMatch('', '', '', '');
                } catch (e) {
                  router.go('/home');
                }
              }
            }
          }
          if (diff <= -0.6 && !hasAutoGoCalled.value) { // 1回だけ送信するようにフラグをチェック
            hasAutoGoCalled.value = true; // 送信済みフラグを立てる
            try {
              // .rpc() を使ってデータベース関数を呼び出す
              await roomnotifier.updategochose(
                room.roomId!,
                userId!,
              );

              // 成功した場合の処理
              print('キャンセル処理が正常に完了しました。');
            } catch (error) {
              // エラー処理
              router.go('/home');
            }
          }
        });
      }

      // ウィジェットがビルドされたらタイマーを開始
      startTimer();

      // 2. クリーンアップ関数を返す
      //    このウィジェットが破棄されるときにタイマーをキャンセルする
      return () {
        log('【DEBUG】Matching: BattleTransitionScreen2 is unmounted. Cancelling timer.');
        timerRef.value?.cancel();
        if (timerRef.value == null) {
          log('【DEBUG】Matching: timerRef.value was null at unmount!');
        }
      };
    }, []);
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
              position: userSlideAnimation,
              child: Padding(
                padding: const EdgeInsets.only(left: 30.0), // 画面端からのパディング
                child: UserProfileCard2(
                    userData: userState,
                    textAlignment: CrossAxisAlignment.start),
              ),
            ),
          ),

          // 相手のプロフィール (右から)
          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: otherUserSlideAnimation,
              child: Padding(
                padding: const EdgeInsets.only(right: 30.0), // 画面端からのパディング
                child: UserProfileCard2(
                    userData: otherUserState,
                    textAlignment: CrossAxisAlignment.end),
              ),
            ),
          ),

          // VS テキスト (画面の厳密な中央)
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

          // ボタン群 (VSの下に配置)
          FadeTransition(
            opacity: buttonsFadeAnimation, // VSテキストと同じフェードアニメーションを適用
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                // VSテキストの下に来るように、上方向にパディングを設定して位置を調整
                padding: const EdgeInsets.only(top: 400.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (room.isBbs != true) ...[
                      // 開始ボタン
                      ElevatedButton(
                        onPressed: isButtonPressed.value
                            ? null // isButtonPressedがtrueなら、onPressedにnullを渡しボタンを無効化
                            : () async {
                                isButtonPressed.value = true;
                                await roomnotifier.updategochose(
                                  room.roomId!,
                                  userId!,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // ボタンの背景色
                          foregroundColor: Colors.blue, // テキストやアイコンの色
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0), // 角を丸くする
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 15), // ボタンの余白
                          elevation: 8, // 影をつけて立体感を出す
                        ),
                        child: Text(
                          'スタート',
                          style: AppTextStyles.bold(
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16), // ボタン間のスペース
                      // キャンセルボタン
                      SizedBox(
                        // 要素が増えたため、必要に応じて幅を調整してください。
                        // width: 160,
                        // TextButtonをRowに置き換えて、クリック範囲を限定しつつレイアウトを再構築
                        child: Row(
                          // 垂直方向の配置を中央に設定
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // --- 左側の要素（秒数） ---
                            // Expandedが利用可能なスペースを埋めることで、中央の要素が真ん中に来る
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.end, // 要素を右端（中央側）に寄せる
                                crossAxisAlignment:
                                    CrossAxisAlignment.center, // 垂直方向も中央揃え
                                children: [
                                  // 秒数 (nullでない場合のみ表示)
                                  if (secondsLeft.value != null)
                                    Text(
                                      secondsLeft.value.toString(),
                                      style: AppTextStyles.notoSans(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // --- 中央の要素（キャンセルボタン） ---
                            // 「キャンセル」テキストのみをTextButtonで囲み、クリック範囲を限定
                            TextButton(
                              onPressed: isButtonPressed.value
                                  ? null // isButtonPressedがtrueなら、onPressedにnullを渡しボタンを無効化
                                  : () async {
                                      isButtonPressed.value = true;
                                      try {
                                        // .rpc() を使ってデータベース関数を呼び出す
                                        await supabase.rpc(
                                          'handle_cancellation_v2', // 作成したSQL関数名
                                          params: {
                                            'p_user_id':
                                                userId, // SQL関数の引数名 'p_user_id' に値を渡す
                                            'p_room_id': room
                                                .roomId, // SQL関数の引数名 'p_room_id' に値を渡す
                                          },
                                        );

                                        // 成功した場合の処理
                                        print('キャンセル処理が正常に完了しました。');
                                      } catch (error) {
                                        // エラー処理
                                        log('予期せぬエラーが発生しました: $error');
                                      }
                                    },
                              // 元のPaddingウィジェットの代わりにstyleで余白を設定
                              style: TextButton.styleFrom(
                                splashFactory: NoSplash.splashFactory,
                                overlayColor: const Color.fromARGB(
                                    255, 10, 89, 153), // 波紋エフェクトの色
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0), // 左右に少し余白を持たせる
                              ),
                              child: Text(
                                'キャンセル',
                                style: AppTextStyles.notoSans(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            // --- 右側の要素（画像と-3） ---
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.start, // 要素を左端（中央側）に寄せる
                                crossAxisAlignment:
                                    CrossAxisAlignment.center, // 垂直方向も中央揃え
                                children: [
                                  // 画像
                                  Image.asset(
                                    'assets/images/trofie.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                  const SizedBox(width: 4), // 画像と数字の間のスペース

                                  // 「-3」という数字
                                  Text(
                                    '-3',
                                    style: AppTextStyles.notoSans(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // BBSの場合はタイマー秒数だけシンプルに表示
                      if (secondsLeft.value != null && secondsLeft.value! >= 0)
                        Text(
                          secondsLeft.value.toString(),
                          style: AppTextStyles.bold(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                    ],
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
