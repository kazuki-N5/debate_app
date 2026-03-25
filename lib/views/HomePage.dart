import 'dart:developer';

import 'package:debate_project/adsence/ad_banner_provider.dart';
import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/app_config_service.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/message_provider.dart';
import 'package:debate_project/provider/sfx_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/provider/vibration_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Homepage_view_model.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:debate_project/view_model/start_error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // CupertinoSwitchのために追加
import 'package:flutter_hooks/flutter_hooks.dart'; // Hooksを継続して使用
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'; // hooks_riverpodを継続して使用
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 広告関連のインポートを追加
import 'package:debate_project/widgets/trophy_count_animation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:showcaseview/showcaseview.dart';

// 前回のトロフィー数を保持してアニメーションの起点にするためのプロバイダー
final lastTrophyCountProvider = StateProvider<int?>((ref) => null);

class HomePage extends HookConsumerWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMatching = useState<bool>(false);
    // 元の notificationEnabled (useState) は削除し、userProvider の値を直接使用するように変更

    // トロフィーアニメーションの起点となる値を管理
    final lastTrophy = ref.watch(lastTrophyCountProvider);
    final user = ref.watch(userProvider);

    // 設定画面から戻ったときなどに通知状態を同期する
    useOnAppLifecycleStateChange((previous, current) {
      if (current == AppLifecycleState.resumed) {
        ref.read(userProvider.notifier).syncNotificationStatusWithSystem();
      }
    });

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

    final matchingRoomnotifier = ref.watch(matchingRoomProvider.notifier);
    final vibration = ref.read(vibrationServiceProvider);
    final chatsnotifier = ref.read(chatProvider.notifier);
    final optionalupdate = ref.read(optionalboolProvider);
    final update = ref.read(appConfigProvider);
    final updatenotifier = ref.read(appStateProvider.notifier);
    final review = ref.watch(reviewProvider);
    final startnotifier = ref.read(startProvider.notifier);

    final forceupdate = ref.watch(forceboolProvider);
    final maintenance = ref.watch(maintenanceboolProvider);

    final friendmatch = ref.watch(friendmatchProvider);
    final friendmatchnotifier = ref.watch(friendmatchProvider.notifier);

    void toggleBoolean() {
      // 現在の isEnabled.value の値を反転させて、再代入します。
      // これによりWidgetが再ビルドされ、UIが更新されます。
      isMatching.value = !isMatching.value;
    }

    // HomePageクラスの外に追加

    void showAppReviewDialog(BuildContext context) async {
      // final InAppReview inAppReview = InAppReview.instance; // レビュー機能を使う場合

      return showDialog<void>(
        context: context, // ダイアログ外タップで閉じることを許可
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0), // ダイアログの角を丸くする
            ),
            elevation: 5,
            backgroundColor: Colors.transparent, // Dialog自体の背景は透明に
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white, // コンテナの背景色（優しい白）
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                // コンテンツが溢れた場合にスクロール可能に
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 内容に合わせて高さを調整
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '応援をよろしくお願いします！',
                      style: AppTextStyles.bold(
                        fontSize: 22,
                        color: Colors.orangeAccent[700], // 暖色系のアクセント
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Image.asset(
                        'assets/images/stars.png',
                        height: 150, // 画像の高さを適宜調整
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'いつもご利用いただきありがとうございます。\nより良いコンテンツをお届けられるように日々改善を続けております。\nぜひレビューしていただけると嬉しいです！',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.notoSans(
                        fontSize: 15,
                        color: Colors.grey[800], // 落ち着いたテキスト色
                        height: 1.6, // 行間を少し広めに
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              side: BorderSide(
                                  color: Colors.grey[300]!), // 控えめな枠線
                            ),
                          ),
                          child: Text(
                            'また今度',
                            style: AppTextStyles.notoSans(
                              color: Colors.grey[700],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            final SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setBool('isreview', true);
                          },
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[600], // 星の色に合わせた暖色
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 4, // 少し影をつける
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.white, size: 18), // 星アイコン
                              const SizedBox(width: 8),
                              Text(
                                '応援する',
                                style: AppTextStyles.bold(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();

                            final InAppReview inAppReview =
                                InAppReview.instance;

                            if (await inAppReview.isAvailable()) {
                              inAppReview.requestReview();
                            }

                            final SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setBool('isreview', true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    final bannerAd = ref.watch(
        bannerAdProvider); // 空の依存配列 [] は、このエフェクトがウィジェットがマウントされたとき一度だけ実行されることを意味します (initState と同様)

    // --- 既存の useEffect (ルーム/チャットのクリーンアップ用) ---
    useEffect(() {
      // マウント時に実行したい処理をまとめた非同期関数
      Future<void> initializePage() async {
        // 以前の状態をクリアする、または初期化として実行したい処理
        // これらがもし非同期処理なら await を付けてください
        matchingRoomnotifier.delete();
        chatsnotifier.unsubscribeFromMessages();

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

    final _profileIconKey = useMemoized(() => GlobalKey());

    useEffect(() {
      // ウィジェットのビルドが完了した後に実行
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final prefs = await SharedPreferences.getInstance();
        final bool hasSeenTutorial =
            prefs.getBool('hasSeenProfileIconTutorial') ?? false;

        // チュートリアルをまだ見ておらず、キーに紐づくコンテキストが利用可能な場合
        // _profileIconKey.currentContext が null でないことを確認するのが重要です
        if (!hasSeenTutorial && _profileIconKey.currentContext != null) {
          // Showcaseを開始
          ShowCaseWidget.of(_profileIconKey.currentContext!)
              .startShowCase([_profileIconKey]);
        }
      });
      return null; // クリーンアップは不要
    }, const []);

    double a = 25;
    double bigicon = 290;

    // --- メインのbuildメソッド ---
    return ShowCaseWidget(onFinish: () async {
      final prefs = await SharedPreferences.getInstance();
      // チュートリアルが完了したことを保存し、次回以降は表示しないようにする
      await prefs.setBool('hasSeenProfileIconTutorial', true);
    }, builder: (context) {
      // ← このように関数を直接指定する
      return Scaffold(
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
                      padding: const EdgeInsets.fromLTRB(21, 25, 21, 21),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // プロフィール画像とユーザー情報
                          Row(
                            children: [
                              // プロフィール画像
                              Showcase(
                                key: _profileIconKey,
                                description: 'アイコンが変更できます',
                                tooltipBackgroundColor: Colors.blueAccent,
                                textColor: Colors.white,
                                targetBorderRadius: BorderRadius.circular(50),
                                overlayOpacity: 0.5,
                                child: InkWell(
                                  onTap: isMatching.value
                                      ? () {}
                                      : () async {
                                          toggleBoolean();
                                          await ref
                                              .read(userProvider.notifier)
                                              .updateAvatar();
                                          toggleBoolean();
                                        },
                                  borderRadius: BorderRadius.circular(25),
                                  enableFeedback: false,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300], // アイコンの背景色
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: ClipOval(
                                      child: user.avatar_url != null &&
                                              user.avatar_url!.isNotEmpty
                                          ? Image.network(
                                              user.avatar_url!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                print('画像読み込みエラー: $error');
                                                return Icon(
                                                  Icons.person, // 人物を表すアイコン
                                                  color: Colors.grey[600],
                                                  size: 30,
                                                );
                                              },
                                            )
                                          : Icon(
                                              Icons.person, // アバターがない場合の初期アイコン
                                              color: Colors.grey[600],
                                              size: 30,
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),
                              // 名前とトロフィー数
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        image: AssetImage(
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
                                    barrierColor: Colors.transparent, // 背景を透明に
                                    builder: (BuildContext context) {
                                      return Dialog(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          side: const BorderSide(
                                              color: Colors.white,
                                              width: 2), // 白い縁取り
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start, // 左寄せ
                                            children: [
                                              Text(
                                                '<ルール>',
                                                style: AppTextStyles.bold(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              Text(
                                                "論破する\n20秒以上アプリを離れると負けになります。",
                                                style: AppTextStyles.notoSans(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              Text(
                                                '<判定基準>',
                                                style: AppTextStyles.bold(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              Text(
                                                '見る人がどっちに納得するかAIで判定',
                                                style: AppTextStyles.notoSans(
                                                  color: Colors.white,
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
                                  height: 7), // 他のボタンとの間隔に合わせる (必要に応じて調整してください)
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    barrierColor:
                                        Colors.transparent, // 背景を暗くしない
                                    builder: (BuildContext dialogContext) {
                                      // dialogContext を使うことで、元の context と区別する
                                      return const RankingDialog();
                                    },
                                  );
                                },
                                child: Image.asset(
                                  'assets/images/trofie.png', // ここに新しい画像のアセットパスを指定してください
                                  // 例として 'assets/images/rule.png' を再利用する場合はそのように変更
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 7),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Color.fromRGBO(255, 255, 255, 0.702),
                                  size: 40,
                                ),
                                onPressed: () {
                                  // 効果音の再生処理はそのまま残します
                                  ref
                                      .read(soundServiceProvider)
                                      .playSfx(SfxAssets.normal);

                                  // 画面遷移の代わりにダイアログを表示します
                                  showDialog(
                                    context: context,
                                    barrierColor:
                                        Colors.transparent, // 背景を暗くしない
                                    // barrierDismissibleをfalseにすると、ダイアログの外側をタップしても閉じなくなります（任意）
                                    // barrierDismissible: false,
                                    builder: (BuildContext dialogContext) {
                                      // 先ほど作成したダイアログウィジェットを返します
                                      return const SubmitThemeDialog();
                                    },
                                  );
                                },
                                enableFeedback: false, // 触覚フィードバックの無効化もそのまま
                              ),
                              const SizedBox(height: 7),

                              GestureDetector(
                                onTap: () {
                                  // dialogContext を使うことで、元の context と区別する
                                  router.push('/pay');
                                },
                                child: Image.asset(
                                  'assets/images/adbrock.png', // ここに新しい画像のアセットパスを指定してください
                                  // 例として 'assets/images/rule.png' を再利用する場合はそのように変更
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
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
                              // 通知設定セクション（UIのみ）
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        barrierColor:
                                            Colors.transparent, // 背景を暗くしない
                                        builder: (context) {
                                          return Dialog(
                                            backgroundColor: Colors.blue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              side: const BorderSide(
                                                  color: Colors.white,
                                                  width: 2),
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '通知について',
                                                    style: AppTextStyles.bold(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 15),
                                                  Text(
                                                    '誰かがマッチングを開始したときに通知を受け取ることができます。\n\n※対戦者が非常に多い時間帯などは、通知が停止する場合があります。',
                                                    style:
                                                        AppTextStyles.notoSans(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(
                                          right: 2,
                                          left: 10,
                                          top: 10,
                                          bottom: 10),
                                      child: Icon(
                                        Icons.info_outline,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.notifications,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 4),
                                  CupertinoSwitch(
                                    value: user.is_notification_enabled ?? false,
                                    onChanged: (value) {
                                      // プロバイダーを通じてDBを更新
                                      ref
                                          .read(userProvider.notifier)
                                          .updateNotificationStatus(
                                              context, value);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // フレンドと対戦ボタン
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ElevatedButton(
                                  onPressed: () {
                                    // 新しいカスタムダイアログを表示
                                    showDialog(
                                      context: context,
                                      barrierColor:
                                          Colors.transparent, // 背景を暗くしない
                                      // ダイアログ外タップで閉じないようにする (任意)
                                      barrierDismissible:
                                          true, // キーボード外タップで閉じたいのでtrueのまま
                                      builder: (BuildContext context) {
                                        // FriendMatchDialogが必要とするプロバイダーがあればここで渡すこともできるが、
                                        // 通常はFriendMatchDialog自身のビルドコンテキストからref経由で取得する
                                        return const FriendMatchDialog();
                                      },
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
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
                                  onPressed: isMatching.value || friendmatch
                                      ? () {
                                          log("isMatching.value: ${isMatching.value.toString()}");
                                          log("friendmatch: ${friendmatch.toString()}");
                                          ref
                                              .read(soundServiceProvider)
                                              .playSfx(SfxAssets.go);
                                          vibration.vibrateShort();
                                        }
                                      : () async {
                                          toggleBoolean();
                                          friendmatchnotifier.state = true;
                                          ref
                                              .read(soundServiceProvider)
                                              .playSfx(SfxAssets.go);
                                          vibration.vibrateShort();
                                          // findMatchの呼び出しは変更なし
                                          await ref
                                              .read(
                                                  matchingRoomProvider.notifier)
                                              .findMatch('', '', '', '');
                                          toggleBoolean();
                                          friendmatchnotifier.state = false;
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
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

                        // --- バナー広告表示エリア ---
                        if (ref
                                .watch(inAppPurchaseManagerProvider)
                                .isSubscribed ==
                            false)
                          if (bannerAd != null)
                            Container(
                              alignment: Alignment.center, // 広告を水平方向に中央揃え
                              width: bannerAd.size.width.toDouble(),
                              height: bannerAd.size.height.toDouble(),
                              child: AdWidget(ad: bannerAd), // ロードされた広告ウィジェット
                            )
                          else
                            // オプション: ロード中や失敗時にプレースホルダーを表示
                            Container(
                              height: AdSize.banner.height
                                  .toDouble(), // 広告の高さ分のスペースを確保
                              color: Colors.blue, // プレースホルダーの背景色
                            ),
                        // --- バナー広告表示エリア 終了 ---
                      ],
                    ),
                  ],
                ),
              ),

              // 前景レイヤー：画面の中央に画像を配置
              Center(
                child: SizedBox(
                  width: bigicon,
                  height: bigicon,
                  child: const Image(
                    image: AssetImage('assets/images/debateimage.png'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// --- FriendMatchDialog (この部分はそのまま) ---
