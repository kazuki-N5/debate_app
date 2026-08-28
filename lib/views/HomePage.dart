// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:developer';
import 'dart:math' hide log; // dart:math の log は dart:developer の log と衝突するため除外

import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:debate_project/adsence/ad_banner_provider.dart';
import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/app_config_service.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/chat_inbox_provider.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/notification_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/provider/sfx_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/provider/vibration_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Homepage_view_model.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:debate_project/view_model/start_error_dialog.dart';
import 'package:debate_project/widgets/app_confirm_dialog.dart';
import 'package:debate_project/widgets/app_review_dialog.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart'; // Hooksを継続して使用
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'; // hooks_riverpodを継続して使用
import 'package:shared_preferences/shared_preferences.dart';

import 'package:debate_project/views/CommunityPage.dart';
import 'package:debate_project/views/MessagePage.dart';

import 'package:debate_project/widgets/keep_alive_page.dart';
import 'package:debate_project/widgets/trophy_count_animation.dart';
import 'package:debate_project/widgets/count_badge.dart';
import 'package:debate_project/adsence/ad_consent_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// 前回のトロフィー数を保持してアニメーションの起点にするためのプロバイダー
final lastTrophyCountProvider = StateProvider<int?>((ref) => null);

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = useState<int>(1); // 初期値をホーム(1)に変更
    // メッセージタブの未読数 (通知 + DM/オプチャの合算)
    final unreadNotifications = ref
            .watch(notificationProvider)
            .valueOrNull
            ?.where((n) => !n.isRead)
            .length ??
        0;
    final unreadMessages = ref
            .watch(chatInboxProvider)
            .valueOrNull
            ?.fold<int>(0, (sum, item) => sum + item.unreadCount) ??
        0;
    final totalUnreadCount = unreadNotifications + unreadMessages;
    // 一度訪れたタブだけをビルドして保持する(遅延マウントで起動時・切替時の負荷を軽減)
    final visitedTabs = useState<Set<int>>({1}); // ホーム(1)は最初から表示
    final isMatching = useState<bool>(false);
    // 元の notificationEnabled (useState) は削除し、userProvider の値を直接使用するように変更

    // トロフィーアニメーションの起点となる値を管理
    final lastTrophy = ref.watch(lastTrophyCountProvider);
    final user = ref.watch(userProvider);


    // 設定画面から戻ったときなどに通知状態を同期する
    useOnAppLifecycleStateChange((previous, current) {
      if (current == AppLifecycleState.resumed) {
        ref.read(userProvider.notifier).syncNotificationStatusWithSystem();
        ref.read(notificationProvider.notifier).fetchNotifications();
      }
    });

    // レスバ（対戦招待）の成立をリアルタイム検知し、バトル画面へ遷移するリスナー
    // watch してプロバイダを生存させ、購読が破棄されないようにする
    ref.watch(resbaMatchListenerProvider);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // ホーム画面表示時にマッチング状態を確実にリセット（対戦中フラグを解除）
        isMatching.value = false;
        ref.read(friendmatchProvider.notifier).state = false;
        await ref.read(matchingRoomProvider.notifier).delete();
        ref.read(resbaMatchListenerProvider.notifier).start();
        // 試合中に保留されていた応募があればダイアログを表示
        ref.read(resbaMatchListenerProvider.notifier).checkAndShowPendingDialog();
      });
      return null;
    }, []);

    // 初回起動時: 通知許可ダイアログを先に表示し、完了後にAdMob IDFA/ATT同意ダイアログを表示
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref
            .read(userProvider.notifier)
            .requestFirstLaunchNotificationPermission();
        // 通知ダイアログ完了後、AdMobのIDFA説明メッセージ / ATTダイアログを表示して広告を初期化
        await AdConsentService.requestConsentAndInitializeAds();
        // 初期化完了後、バナー広告をロード
        if (ref.read(inAppPurchaseManagerProvider).isSubscribed == false) {
          ref.read(bannerAdProvider.notifier).loadAd();
          ref.read(matchingBannerAdProvider.notifier).loadAd();
        }
      });
      return null;
    }, []);

    // 現在のトロフィー数を保存して、次回の「前回値」として使う
    useEffect(() {
      if (user.trophy != lastTrophy) {
        // 表示が終わるのを待たずに更新して良いが、
        // 次回のビルドでアニメーションの起点が変わってしまわないよう
        // 微調整が必要な場合はFuture.microtask等を使う
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(lastTrophyCountProvider.notifier).state = user.trophy;
        });
      }
      return null;
    }, [user.trophy]);

    final vibration = ref.read(vibrationServiceProvider);
    final optionalupdate = ref.read(optionalboolProvider);
    final update = ref.read(appConfigProvider);
    final updatenotifier = ref.read(appStateProvider.notifier);
    final review = ref.watch(reviewProvider);
    final startnotifier = ref.read(startProvider.notifier);

    final forceupdate = ref.watch(forceboolProvider);
    final maintenance = ref.watch(maintenanceboolProvider);

    final friendmatch = ref.watch(friendmatchProvider);
    final friendmatchnotifier = ref.watch(friendmatchProvider.notifier);

    final bannerAd = ref.watch(
        bannerAdProvider); // 空の依存配列 [] は、このエフェクトがウィジェットがマウントされたとき一度だけ実行されることを意味します (initState と同様)

    // --- 既存の useEffect (バージョン確認用) ---
    useEffect(() {
      Future<void> initializePage() async {
        // バージョン情報を取得
        final saveversion = await updatenotifier.getVersion();
        print('今の保存されてるバージョン　$saveversion');
        print('今のスマホのバージョン　${update?.latestVersion}');

        if (optionalupdate) {
          if (saveversion == update?.latestVersion) {
            return;
          }
          if (context.mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // コールバックが呼ばれる時点でも再度ウィジェットの存在を確認 (安全のため)
              if (context.mounted) {
                startnotifier.showUpdateDialog(
                  context,
                );
              }
            });
          }
        }
      }

      initializePage();
      return null;
    }, []);

    useEffect(() {
      // 即時実行の非同期関数 (async IIFE) を定義して実行
      (() async {
        if (forceupdate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              startnotifier.showforceUpdateDialog(context);
            }
          });
        } else if (maintenance) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (context.mounted) {
              startnotifier.showMaintenanceDialog(context, () {
                router.go('/');
              },
                  ref.read(appConfigProvider)?.maintenanceMessage ??
                      'メンテナンス中です');
            }
          });
        } else if (review) {
          // SharedPreferences.getInstance() は Future を返すため await を使用
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool shouldShowReviewDialog = prefs.getBool('isreview') ?? false;
          if (shouldShowReviewDialog == false) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                showAppReviewDialog(context);
              }
            });
          } else {
            // 元のコードの `return;` はこの async IIFE のスコープ内で何もしないことに相当します。
            // 明示的に `return;` と書くこともできますが、なくても動作は同じです。
            // 「他のコードは一切変えないで」という指示に厳密に従う場合、
            // この else ブロックは元のままとします。
            return;
          }
        }
      })(); // async IIFE を実行

      return null; // useEffect のクリーンアップ関数 (この場合はなし)
    }, [forceupdate, maintenance, review]);

    double a = 25;
    double bigicon = 290;

    // --- ボトムバーの円と広告の重なり対策 ---
    // ボトムバーの高さは既存レイアウトで確保されているため、
    // 広告には中央円の張り出し分だけ下余白を設ける。
    const double circleNavWidth = 60.0; // CircleNavBar の circleWidth 指定値
    const double circleNavR = circleNavWidth / 2 * 1.2; // getR: 60/2*1.2 = 36
    const double circleNavMiniRadius = circleNavR * 0.3; // getMiniRadius: 36*0.3 = 10.8
    const double adBottomPadding =
        circleNavWidth * 0.5 - circleNavMiniRadius; // 30 - 10.8 = 19.2
    // CircleNavBar 自体の高さ(バナーをナビバーの上に浮かせるために使用)
    const double circleNavBarHeight = 60.0;
    // ボタン(フレンド対戦⇄ランダムマッチ)同士の間隔。
    // ランダムマッチ⇄バナー広告の間隔もこの値に揃える。
    const double buttonGap = 16.0;
    // 下部ボタンブロックの下パディング。EdgeInsets.all(20.0) の bottom と揃える。
    const double footerButtonBlockPadding = 20.0;

    // --- メインのbuildメソッド ---
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex.value,
            children: [
              // 初回タップ時までビルドしない(遅延マウント)
              visitedTabs.value.contains(0)
                  ? const KeepAlivePage(child: CommunityPage())
                  : const SizedBox.shrink(), // 0: コミュニティ
              Scaffold(
                resizeToAvoidBottomInset: false,
                body: Container(
                  color: Colors.blue,
                  child: Stack(
                    children: [
                      // 背景レイヤー：ヘッダーとフッターのみをSafeAreaで囲みます
                      SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // トップセクション (ヘッダー)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(21, 25, 21, 21),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // 左側セクション (プロフィール情報 + 左列アイコン群)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // プロフィール画像とユーザー情報
                                      Row(
                                        children: [
                                          // プロフィール画像
                                          InkWell(
                                            onTap: () {
                                              ref
                                                  .read(soundServiceProvider)
                                                  .playSfx(SfxAssets.normal);
                                              context.push('/userProfile',
                                                  extra: user.id);
                                            },
                                            borderRadius:
                                                BorderRadius.circular(25),
                                            enableFeedback: false,
                                            child: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: Colors
                                                    .grey[300], // アイコンの背景色
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2),
                                              ),
                                              child: ClipOval(
                                                child: user.avatar_url !=
                                                            null &&
                                                        user.avatar_url!
                                                            .isNotEmpty
                                                    ? Image.network(
                                                        user.avatar_url!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (context, error,
                                                                stackTrace) {
                                                          print(
                                                              '画像読み込みエラー: $error');
                                                          return Icon(
                                                            Icons
                                                                .person, // 人物を表すアイコン
                                                            color: Colors
                                                                .grey[600],
                                                            size: 30,
                                                          );
                                                        },
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .person, // アバターがない場合の初期アイコン
                                                        color:
                                                            Colors.grey[600],
                                                        size: 30,
                                                      ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 10),
                                              // 名前とトロフィー数
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () {
                                                      context.push('/name2');
                                                    },
                                                    child: Text(
                                                      user.name!,
                                                      style: AppTextStyles.bold(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Image(
                                                        image: const AssetImage(
                                                            'assets/images/trofie.png'), // 画像パスを指定
                                                        width: a, // サイズ調整
                                                        height: a,
                                                      ),
                                                      const SizedBox(width: 1),
                                                      TrophyCountAnimation(
                                                        targetTrophy: user.trophy,
                                                        startTrophy:
                                                            lastTrophy, // nullなら現在の値が使われる
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 7),
                                          // 左側のアイコン列（マイレスバ等）
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              IconButton(
                                                icon: const Text(
                                                  '⚔️',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 34,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  ref
                                                      .read(soundServiceProvider)
                                                      .playSfx(SfxAssets.normal);
                                                  context.push('/myResbas');
                                                },
                                                enableFeedback: false,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      // 設定アイコンと履歴アイコン
                                      Column(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.settings,
                                              color: Colors.white70,
                                              size: 40,
                                            ),
                                            onPressed: () {
                                              ref
                                                  .read(soundServiceProvider)
                                                  .playSfx(SfxAssets.normal);
                                              context.push('/setting');
                                            },
                                            enableFeedback: false,
                                          ),
                                          const SizedBox(height: 7),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.history,
                                              color: Colors.white70,
                                              size: 40,
                                            ),
                                            onPressed: () {
                                              ref
                                                  .read(soundServiceProvider)
                                                  .playSfx(SfxAssets.normal);
                                              router.push('/history');
                                            },
                                            enableFeedback: false,
                                          ),
                                          const SizedBox(height: 0),
                                          GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                barrierDismissible: true,
                                                barrierColor: Colors
                                                    .transparent, // 背景を透明に
                                                builder:
                                                    (BuildContext context) {
                                                  return Dialog(
                                                    backgroundColor:
                                                        Colors.blue,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              15),
                                                      side: const BorderSide(
                                                          color: Colors.white,
                                                          width: 2), // 白い縁取り
                                                    ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              20),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start, // 左寄せ
                                                        children: [
                                                          Text(
                                                            '<ルール>',
                                                            style: AppTextStyles
                                                                .bold(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 18,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 15),
                                                          Text(
                                                            "論破する\n20秒以上アプリを離れると負けになります。",
                                                            style: AppTextStyles
                                                                .notoSans(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 15),
                                                          Text(
                                                            '<判定基準>',
                                                            style: AppTextStyles
                                                                .bold(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 18,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 15),
                                                          Text(
                                                            '見る人がどっちに納得するかAIで判定',
                                                            style: AppTextStyles
                                                                .notoSans(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                            child: Image.asset(
                                              'assets/images/rule.png',
                                              width: 70,
                                              height: 70,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(
                                              height: 0), // パディングを追加したため間隔を調整
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                barrierDismissible: true,
                                                barrierColor: Colors
                                                    .transparent, // 背景を暗くしない
                                                builder: (BuildContext
                                                    dialogContext) {
                                                  // dialogContext を使うことで、元の context と区別する
                                                  return const RankingDialog();
                                                },
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              child: Image.asset(
                                                'assets/images/trofie.png', // ここに新しい画像のアセットパスを指定してください
                                                // 例として 'assets/images/rule.png' を再利用する場合はそのように変更
                                                width: 45,
                                                height: 45,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                              height: 0), // パディングを追加したため間隔を調整
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              // 効果音の再生処理はそのまま残します
                                              ref
                                                  .read(soundServiceProvider)
                                                  .playSfx(SfxAssets.normal);

                                              // 画面遷移の代わりにダイアログを表示します
                                              showDialog(
                                                context: context,
                                                barrierColor: Colors
                                                    .transparent, // 背景を暗くしない
                                                // barrierDismissibleをfalseにすると、ダイアログの外側をタップしても閉じなくなります（任意）
                                                // barrierDismissible: false,
                                                builder: (BuildContext
                                                    dialogContext) {
                                                  // 先ほど作成したダイアログウィジェットを返します
                                                  return const SubmitThemeDialog();
                                                },
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              child: const Icon(
                                                Icons.add_circle_outline,
                                                color: Color.fromRGBO(
                                                    255, 255, 255, 0.702),
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                              height: 0), // パディングを追加したため間隔を調整

                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              // dialogContext を使うことで、元の context と区別する
                                              router.push('/pay');
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              child: Image.asset(
                                                'assets/images/adbrock.png', // ここに新しい画像のアセットパスを指定してください
                                                // 例として 'assets/images/rule.png' を再利用する場合はそのように変更
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // フッター（ボタンと広告）
                                Column(
                                  children: [
                                    // 下部のボタン
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        children: [
                                          // フレンドと対戦ボタン
                                          Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                                bottom: buttonGap),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                // 新しいカスタムダイアログを表示
                                                showDialog(
                                                  context: context,
                                                  barrierColor: Colors
                                                      .transparent, // 背景を暗くしない
                                                  // ダイアログ外タップで閉じないようにする (任意)
                                                  barrierDismissible:
                                                      true, // キーボード外タップで閉じたいのでtrueのまま
                                                  builder:
                                                      (BuildContext context) {
                                                    // FriendMatchDialogが必要とするプロバイダーがあればここで渡すこともできるが、
                                                    // 通常はFriendMatchDialog自身のビルドコンテキストからref経由で取得する
                                                    return const FriendMatchDialog();
                                                  },
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                enableFeedback: false,
                                              ),
                                              child: Text(
                                                'フレンドと対戦 / 部屋作成', // ボタンテキスト変更
                                                style: AppTextStyles.notoSans(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // ゲーム開始ボタン
                                          SizedBox(
                                            // ContainerをSizedBoxに変更 (子にElevatedButtonしかないため)
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: isMatching.value ||
                                                      friendmatch
                                                  ? () {
                                                      log("isMatching.value: ${isMatching.value.toString()}");
                                                      log("friendmatch: ${friendmatch.toString()}");
                                                      ref
                                                          .read(
                                                              soundServiceProvider)
                                                          .playSfx(
                                                              SfxAssets.go);
                                                      vibration.vibrateShort();
                                                    }
                                                   : () async {
                                                       try {
                                                         isMatching.value = true;
                                                         // 前の試合（進行中ルーム）があれば「負け（相手勝ち）」にして解除
                                                         // 待ち時間なしで新しい試合に参加できるようにする
                                                         await ref
                                                             .read(
                                                                 resbaActionsProvider)
                                                             .resolveMyBattle();
                                                         // 応募中チェック: 応募中のレスバがあれば確認ダイアログ
                                                         final status = await ref
                                                             .read(
                                                                 resbaActionsProvider)
                                                             .getMyResbaStatus();
                                                         if (status.isApplying) {
                                                           final proceed =
                                                              await showAppConfirmDialog(
                                                            context: context,
                                                            title: '応募中のレスバがあります',
                                                            message:
                                                                '応募を取り消してランダムマッチに参加しますか？',
                                                            cancelText: 'いいえ',
                                                            confirmText: '取り消して参加',
                                                            isDestructive: false,
                                                          );
                                                          if (proceed != true) {
                                                            return;
                                                          }
                                                          await ref
                                                              .read(
                                                                  resbaActionsProvider)
                                                              .cancelMyPendingApplications();
                                                         }
                                                         friendmatchnotifier
                                                             .state = true;
                                                         ref
                                                             .read(
                                                                 soundServiceProvider)
                                                             .playSfx(
                                                                 SfxAssets.go);
                                                         vibration
                                                             .vibrateShort();
                                                         // findMatchの呼び出し
                                                         await ref
                                                             .read(
                                                                 matchingRoomProvider
                                                                     .notifier)
                                                             .findMatch(
                                                                 '', '', '', '');
                                                       } finally {
                                                         if (context.mounted) {
                                                           isMatching.value =
                                                               false;
                                                         }
                                                         friendmatchnotifier
                                                             .state = false;
                                                       }
                                                     },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                disabledBackgroundColor:
                                                    Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                enableFeedback: false,
                                              ),
                                              child: Text(
                                                'ランダムマッチ', // ボタンテキストを修正 ('a' -> 'ランダムマッチ'など)
                                                style: AppTextStyles.notoSans(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // --- 広告表示時(非課金)はボタンを上に詰める ---
                                    // 常時表示バナー(ナビバーの上＝広告下部が起点)とボタンが
                                    // 重ならないよう余白を確保する。間隔は「ボタン同士の間隔」
                                    // (=buttonGap)と同じにする。
                                    // SafeArea の下パディングは extendBody:true により
                                    // max(システム下インセット, circleNavBarHeight) になるが、
                                    // この build の context は外側の Scaffold より上なので
                                    // MediaQuery.of(context).padding.bottom はシステムインセット
                                    // しか返さない。そのため max() で SafeArea と同じ値を引く。
                                    if (!ref.watch(inAppPurchaseManagerProvider)
                                        .isSubscribed)
                                      SizedBox(
                                        height: max(
                                          0,
                                          circleNavBarHeight +
                                              adBottomPadding +
                                              (bannerAd?.size.height ??
                                                  AdSize.banner.height) +
                                              buttonGap -
                                              footerButtonBlockPadding -
                                              max(
                                                MediaQuery.of(context)
                                                    .padding
                                                    .bottom,
                                                circleNavBarHeight,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 前景レイヤー：画面の中央に画像を配置
                          IgnorePointer(
                            child: Center(
                              child: Transform.translate(
                                offset: const Offset(0, -50), // さらに上に配置をずらす
                                child: SizedBox(
                                  width: bigicon,
                                  height: bigicon,
                                  child: const Image(
                                    image: AssetImage(
                                        'assets/images/debateimage_v2.png'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              // 初回タップ時までビルドしない(遅延マウント)
              visitedTabs.value.contains(2)
                  ? const KeepAlivePage(child: MessagePage())
                  : const SizedBox.shrink(), // 2: メッセージ
            ],
          ),

          // --- 常時表示のバナー広告(全タブ共通でボトムバーの上に浮かせる) ---
          if (!ref.watch(inAppPurchaseManagerProvider).isSubscribed)
            Positioned(
              left: 0,
              right: 0,
              bottom: circleNavBarHeight + adBottomPadding,
              child: bannerAd != null
                  ? Container(
                      alignment: Alignment.center, // 水平中央揃え
                      width: bannerAd.size.width.toDouble(),
                      height: bannerAd.size.height.toDouble(),
                      child: AdWidget(ad: bannerAd),
                    )
                  : Container(
                      height: AdSize.banner.height.toDouble(),
                      color: Colors.transparent,
                    ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent, // 隙間を透明にする
        // RepaintBoundary: ナビバーの毎フレーム描画(影のblur)を他UIから分離してカクつきを防ぐ
        child: RepaintBoundary(
          child: CircleNavBar(
            activeIcons: const [
              Icon(Icons.people, color: Colors.blue),
              Center(
                child: Text(
                  '⚔️',
                  style: TextStyle(fontSize: 24),
                ),
              ),
              Icon(Icons.message, color: Colors.blue),
            ],
            inactiveIcons: [
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people,
                      color:
                          currentIndex.value == 0 ? Colors.blue : Colors.grey),
                  Text("コミュニティ",
                      style: TextStyle(
                          color: currentIndex.value == 0
                              ? Colors.blue
                              : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '⚔️',
                    style: TextStyle(fontSize: 20),
                  ),
                  Text("ホーム",
                      style: TextStyle(
                          color: currentIndex.value == 1
                              ? Colors.blue
                              : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMessageIcon(
                    currentIndex.value == 2 ? 0 : totalUnreadCount,
                    active: false,
                  ),
                  Text("メッセージ",
                      style: TextStyle(
                          color: currentIndex.value == 2
                              ? Colors.blue
                              : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            color: const Color(0xFFF3F3F3), // 背景を少しだけグレーに(アプリ全体の背景色と統一)
            circleColor: const Color(0xFFF3F3F3),
            height: 60,
            circleWidth: 60,
            activeIndex: currentIndex.value,
            onTap: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              // メッセージタブ(2)から他のタブに移動した場合、溜まっていた通知を既読にする
              if (currentIndex.value == 2 && index != 2) {
                ref.read(notificationProvider.notifier).markAllRead();
              }
              visitedTabs.value = {
                ...visitedTabs.value,
                index
              }; // 訪れたタブを保持対象にする
              currentIndex.value = index;
            },
            tabCurve: Curves.easeInOut, // 丸が移動するアニメーション
            // 影は不要(カクつきの原因にもなる)ので消す: elevation 0 で影の描画自体がスキップされる
            shadowColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
    );
  }

  /// メッセージアイコン + 未読通知数バッジ
  Widget _buildMessageIcon(int unreadCount, {required bool active}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.message,
          color: active ? Colors.blue : Colors.grey,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -10,
            top: -7,
            child: CountBadge(
              count: unreadCount,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
      ],
    );
  }
}

// --- FriendMatchDialog (この部分はそのまま) ---
