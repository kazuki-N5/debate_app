import 'dart:io';

import 'package:debate_project/adsence/ad_banner_provider.dart';
import 'package:debate_project/modes/userranking_model.dart';
import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/app_config_service.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/message_provider.dart';
import 'package:debate_project/provider/sfx_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/provider/vibration_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart'; // Hooksを継続して使用
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'; // hooks_riverpodを継続して使用
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// 広告関連のインポートを追加
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);
    final vibration = ref.read(vibrationServiceProvider);
    final chatsnotifier = ref.read(chatProvider.notifier);
    final optionalupdate = ref.read(optionalboolProvider);
    final update = ref.read(appConfigProvider);
    final updatenotifier = ref.read(appStateProvider.notifier);
    final review = ref.watch(reviewProvider);
    const String androidStoreUrl =
        'https://play.google.com/store/apps/details?id=YOUR_ANDROID_PACKAGE_NAME';
    const String iosStoreUrl = 'https://apps.apple.com/app/idYOUR_IOS_APP_ID';
    final forceupdate = ref.watch(forceboolProvider);
    final maintenance = ref.watch(maintenanceboolProvider);
    Future<void> launchStoreUrl() async {
      final url = Platform.isIOS ? iosStoreUrl : androidStoreUrl;
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch $url');
      }
    }

    void _showUpdateDialog(BuildContext context, VoidCallback onUpdate) {
      const Color dialogBackgroundColor = Color(0xFF42A5F5);
      const Color textColor = Colors.white;
      const Color buttonTextColor = Color(0xFF1565C0);
      const Color buttonBackgroundColor = Colors.white;

      // チェックボックスの初期状態
      bool doNotShowAgain = false;

      showDialog<bool>(
        // showDialog の型引数を bool にして、チェックボックスの状態を返すようにする
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          // StatefulBuilder を使ってダイアログ内のチェックボックスの状態を管理
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                backgroundColor: dialogBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
                contentPadding: const EdgeInsets.fromLTRB(
                    24.0, 12.0, 24.0, 12.0), // チェックボックスのために少し調整
                title: const Text(
                  'アップデートができます',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20.0,
                  ),
                ),
                content: Column(
                  mainAxisSize:
                      MainAxisSize.min, // Column が AlertDialog の高さを不必要に広げないように
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      update!.changelog!.replaceAll(r'\n', '\n'),
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 16.0,
                      ),
                    ),
                    const SizedBox(height: 20.0), // テキストとチェックボックスの間のスペース
                    GestureDetector(
                      // 行全体をタップ可能にする
                      onTap: () {
                        setState(() {
                          doNotShowAgain = !doNotShowAgain;
                        });
                      },
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            // チェックボックスのタップ領域を広げるためと、見た目の調整
                            width: 24, // チェックボックスのデフォルトサイズに近い値
                            height: 24,
                            child: Checkbox(
                              value: doNotShowAgain,
                              onChanged: (bool? value) {
                                setState(() {
                                  doNotShowAgain = value ?? false;
                                });
                              },
                              checkColor: buttonTextColor, // チェックマークの色
                              activeColor:
                                  buttonBackgroundColor, // チェックボックスの背景色 (アクティブ時)
                              side: MaterialStateBorderSide.resolveWith(
                                (states) => const BorderSide(
                                    color: textColor, width: 2), // ボーダーの色と太さ
                              ),
                              visualDensity:
                                  VisualDensity.compact, // 少しコンパクトにする
                            ),
                          ),
                          const SizedBox(width: 8.0), // チェックボックスとテキストの間のスペース
                          const Expanded(
                            // テキストが長い場合にも対応
                            child: Text(
                              '次回のアップデートまで表示しない',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.center,
                actionsPadding: const EdgeInsets.only(
                    bottom: 24.0,
                    left: 24.0,
                    right: 24.0,
                    top: 16.0), // content とボタンの間に少しパディング(top)
                actions: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: buttonBackgroundColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            minimumSize: const Size(100, 44),
                          ),
                          child: const Text(
                            'しない',
                            style: TextStyle(
                              color: buttonTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(doNotShowAgain);
                          },
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: buttonBackgroundColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            minimumSize: const Size(100, 44),
                          ),
                          child: const Text(
                            'する',
                            style: TextStyle(
                              color: buttonTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                          ),
                          onPressed: () {
                            onUpdate(); // 元のアップデート処理を実行

                            Navigator.of(dialogContext).pop(doNotShowAgain);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ).then((bool? checkboxResult) async {
        ref.read(optionalboolProvider.notifier).state = false;
        if (checkboxResult == true) {
          print('saveされました');
          await updatenotifier.saveVersion(update!.latestVersion!);
        }
      });
    }

    void _showMaintenanceDialog(
        BuildContext context, VoidCallback onRetry, String message) {
      const Color dialogBackgroundColor = Color(0xFF42A5F5);
      const Color textColor = Colors.white;
      const Color buttonTextColor =
          Color(0xFF1565C0); // ホーム画面のボタン内テキストに近い青 (例: Colors.blue[800])
      const Color buttonBackgroundColor = Colors.white;

      showDialog(
        context: context,
        barrierDismissible: false, // メンテナンス中は基本的に閉じさせない方が良い場合も
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: dialogBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0), // 角丸を少し大きめに
            ),
            titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
            contentPadding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
            title: const Text(
              'メンテナンス中です', // タイトル変更
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
            ),
            content: Text(
              message, // コンテンツメッセージ変更
              textAlign: TextAlign.center,
              style: TextStyle(
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
                icon: Icon(Icons.refresh, color: buttonTextColor, size: 22.0),
                label: Text(
                  '再試行', // ボタンラベルは「再試行」とする (元の「やり直す」でも可)
                  style: TextStyle(
                    color: buttonTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
                onPressed: () {
                  onRetry();
                  Navigator.of(dialogContext).pop(); // 再試行コールバックを実行
                },
              ),
            ],
          );
        },
      ).then((_) {
        ref.read(maintenanceboolProvider.notifier).state = false;
      });
    }

    void _showforceUpdateDialog(
        BuildContext context, VoidCallback launchStoreUrl) {
      const Color dialogBackgroundColor = Color(0xFF42A5F5); // 元の青
      const Color textColor = Colors.white;
      const Color buttonTextColor = Color(0xFF1565C0); // 元のボタン内テキストの青
      const Color buttonBackgroundColor = Colors.white;

      showDialog(
        context: context,
        barrierDismissible: false, // アップデートは必須なので閉じさせない
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: dialogBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
            contentPadding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
            title: const Text(
              'アップデートが必要です', // タイトル変更
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
            ),
            content: const Text(
              '最新バージョンが利用可能です。\nストアでアプリを更新してください。', // 内容変更
              textAlign: TextAlign.center,
              style: TextStyle(
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
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                icon: Icon(Icons.arrow_forward, // 右矢印アイコンに変更
                    color: buttonTextColor,
                    size: 22.0),
                label: Text(
                  'ストアを開く', // ボタンテキスト変更
                  style: TextStyle(
                    color: buttonTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
                onPressed: () {
                  // ダイアログを閉じる必要があれば閉じる。
                  // 強制アップデートの場合、ストアに飛ぶまで閉じない方が良いかもしれないが、
                  // ストア遷移後に戻ってきた時のために閉じておくのが一般的。
                  launchStoreUrl(); // ストアURLを開く関数を実行
                },
              ),
            ],
          );
        },
      ).then((_) {
        // ダイアログが閉じた後に実行される (オプション)
      });
    }

    void showAppReviewDialog(BuildContext context) async {
      // final InAppReview inAppReview = InAppReview.instance; // レビュー機能を使う場合

      return showDialog<void>(
        context: context,
        barrierDismissible: true, // ダイアログ外タップで閉じることを許可
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
                      style: TextStyle(
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
                            style: TextStyle(
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star,
                                  color: Colors.white, size: 18), // 星アイコン
                              SizedBox(width: 8),
                              Text(
                                '応援する',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          onPressed: () async {
                            Navigator.of(dialogContext).pop(); // 先にダイアログを閉じる
                            // --- レビュー依頼の処理 ---
                            // 例: in_app_review パッケージを使用する場合
                            // if (await inAppReview.isAvailable()) {
                            //   inAppReview.requestReview();
                            // } else {
                            //   // App StoreやGoogle PlayのURLに直接遷移するなどのフォールバック処理
                            //   // inAppReview.openStoreListing(appStoreId: 'YOUR_APP_STORE_ID', microsoftStoreId: '...');
                            //   print('レビュー機能が利用できません。ストアに直接誘導します。');
                            // }
                            print('「応援する」ボタンが押されました。レビューページへ誘導します。');
                            // TODO: 実際のレビュー誘導処理をここに記述してください
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
        roomnotifier.delete();
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
                _showUpdateDialog(context, () {
                  launchStoreUrl();
                });
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
              _showforceUpdateDialog(context, () {
                launchStoreUrl();
              });
            }
          });
        } else if (maintenance) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              _showMaintenanceDialog(context, () {
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
    // --- メインのbuildメソッド ---
    return Scaffold(
      resizeToAvoidBottomInset: false,
            body: Container(
        color: const Color(0xFF2196F3),
        child: SafeArea(
          child: Column(
            children: [
              // トップセクション (プロフィール、名前、トロフィー、アイコン)
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
                        InkWell(
                          onTap: () {
                            ref.read(userProvider.notifier).updateAvatar();
                          },
                          borderRadius: BorderRadius.circular(25),
                          enableFeedback: false,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[300], // アイコンの背景色
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
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
                                Text(
                                  user.trophy.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
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
                                  shape: BeveledRectangleBorder(
                                    // 角を四角に
                                    borderRadius: BorderRadius.zero,
                                    side: const BorderSide(
                                        // constを追加
                                        color: Colors.white,
                                        width: 2), // 白い縁取り
                                  ),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.all(20), // constを追加
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start, // 左寄せ
                                      children: [
                                        Text(
                                          '<ルール>',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        Text(
                                          "論破する\n20秒以上アプリを離れると負けになります。",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        Text(
                                          '<判定基準>',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        Text(
                                          '見る人がどっちに納得するかAIで判定',
                                          style: TextStyle(
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
                              barrierDismissible: true, // ダイアログ外タップで閉じるか
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
                        )
                      ],
                    ),
                  ],
                ),
              ),

              // 中央の拡張スペース
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Image(
                          image: AssetImage('assets/images/debateimage.png'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 下部のボタン (垂直に配置)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // フレンドと対戦ボタン
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton(
                        onPressed: () {
                          // 新しいカスタムダイアログを表示
                          showDialog(
                            context: context,
                            // ダイアログ外タップで閉じないようにする (任意)
                            barrierDismissible: true, // キーボード外タップで閉じたいのでtrueのまま
                            builder: (BuildContext context) {
                              // FriendMatchDialogが必要とするプロバイダーがあればここで渡すこともできるが、
                              // 通常はFriendMatchDialog自身のビルドコンテキストからref経由で取得する
                              return const FriendMatchDialog();
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enableFeedback: false,
                        ),
                        child: const Text(
                          'フレンドと対戦 / 部屋作成', // ボタンテキスト変更
                          style: TextStyle(
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
                        onPressed: () async {
                          ref.read(soundServiceProvider).playSfx(SfxAssets.go);
                          vibration.vibrateShort();
                          ref
                              .read(matchingRoomProvider.notifier)
                              .findMatch('', '', '', '');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enableFeedback: false,
                        ),
                        child: const Text(
                          'ランダムマッチ', // ボタンテキストを修正 ('a' -> 'ランダムマッチ'など)
                          style: TextStyle(
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
              // adがロードされている場合のみ表示
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
                  height: AdSize.banner.height.toDouble(), // 広告の高さ分のスペースを確保
                  color: Colors.blue, // プレースホルダーの背景色
                ),
              // --- バナー広告表示エリア 終了 ---
            ],
          ),
        ),
      ),
    );
  }
}

// --- FriendMatchDialog (この部分はそのまま) ---
class FriendMatchDialog extends HookConsumerWidget {
  const FriendMatchDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibration = ref.read(vibrationServiceProvider);
    // --- State管理のためのHooks ---
    final pageController = usePageController();
    final currentPage = useState(0);

    // --- ページ1 (合言葉で参加) のState ---
    final secretWordController = useTextEditingController();
    final isSecretWordEmpty = useState(secretWordController.text.isEmpty);

    // --- ページ2 (部屋作成) のState ---
    final themeController = useTextEditingController();
    final choice1Controller = useTextEditingController();
    final choice2Controller = useTextEditingController();
    final passwordController = useTextEditingController(); // 合言葉用

    final isThemeEmpty = useState(themeController.text.isEmpty);
    final isChoice1Empty = useState(choice1Controller.text.isEmpty);
    final isChoice2Empty = useState(choice2Controller.text.isEmpty);
    final isPasswordEmpty =
        useState(passwordController.text.isEmpty); // 合言葉の空状態

    // --- 派生State (ボタンの有効/無効) ---
    final isPage1Valid = !isSecretWordEmpty.value;
    final isPage2Valid = !isThemeEmpty.value &&
        !isChoice1Empty.value &&
        !isChoice2Empty.value &&
        !isPasswordEmpty.value;
    // isCurrentPageValid は不要になるので削除

    // --- テキスト変更を監視するためのEffect Hook ---
    useEffect(() {
      void secretWordListener() =>
          isSecretWordEmpty.value = secretWordController.text.isEmpty;
      void themeListener() => isThemeEmpty.value = themeController.text.isEmpty;
      void choice1Listener() =>
          isChoice1Empty.value = choice1Controller.text.isEmpty;
      void choice2Listener() =>
          isChoice2Empty.value = choice2Controller.text.isEmpty;
      void passwordListener() =>
          isPasswordEmpty.value = passwordController.text.isEmpty;

      secretWordController.addListener(secretWordListener);
      themeController.addListener(themeListener);
      choice1Controller.addListener(choice1Listener);
      choice2Controller.addListener(choice2Listener);
      passwordController.addListener(passwordListener);

      // 初期状態を反映
      secretWordListener();
      themeListener();
      choice1Listener();
      choice2Listener();
      passwordListener();

      // Effectが再実行されるかウィジェットが破棄されるときにリスナーをクリーンアップ
      return () {
        secretWordController.removeListener(secretWordListener);
        themeController.removeListener(themeListener);
        choice1Controller.removeListener(choice1Listener);
        choice2Controller.removeListener(choice2Listener);
        passwordController.removeListener(passwordListener);
      };
    }, [
      secretWordController,
      themeController,
      choice1Controller,
      choice2Controller,
      passwordController
    ]);

    // --- ボタンのスタイル定義 (共通化) ---
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue,
      disabledBackgroundColor: Colors.grey[300],
      disabledForegroundColor: Colors.grey[500],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      enableFeedback: false,
    );

    final buttonTextStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    // --- UI定義 ---
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: SizedBox(
            height: 350, // 高さは必要に応じて調整
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: pageController,
                    onPageChanged: (index) {
                      currentPage.value = index;
                      FocusScope.of(context).unfocus();
                    },
                    children: [
                      _buildSecretWordPage(secretWordController),
                      _buildThemePage(
                        themeController,
                        choice1Controller,
                        choice2Controller,
                        passwordController,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                SmoothPageIndicator(
                  controller: pageController,
                  count: 2,
                  effect: const WormEffect(
                    dotHeight: 10,
                    dotWidth: 10,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white54,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        ref
                            .read(soundServiceProvider)
                            .playSfx(SfxAssets.normal);
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        enableFeedback: false, // <-- ボタンの触覚・聴覚フィードバックを無効化
                      ),
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    // --- ここからボタンの条件分岐 ---
                    if (currentPage.value == 0) // ページ1 (参加) の場合
                      ElevatedButton(
                        onPressed: !isPage1Valid
                            ? null // ページ1が無効ならnull
                            : () {
                                ref
                                    .read(soundServiceProvider)
                                    .playSfx(SfxAssets.go);

                                vibration.vibrateShort();
                                final secretWord = secretWordController.text;
                                print('合言葉で参加開始: $secretWord');

                                // ページ1の合言葉は secretWordController.text を使う
                                ref
                                    .read(matchingRoomProvider.notifier)
                                    .findMatch(
                                        secretWordController.text, '', '', '');
                                Navigator.of(context).pop();
                              },
                        style: buttonStyle,
                        child: Text('参加する', style: buttonTextStyle),
                      )
                    else if (currentPage.value == 1) // ページ2 (作成) の場合
                      ElevatedButton(
                        onPressed: !isPage2Valid
                            ? null // ページ2が無効ならnull
                            : () {
                                ref
                                    .read(soundServiceProvider)
                                    .playSfx(SfxAssets.go);
                                final notifier =
                                    ref.read(matchingRoomProvider.notifier);
                                final theme = themeController.text;
                                final choice1 = choice1Controller.text;
                                final choice2 = choice2Controller.text;
                                // ページ2の合言葉は passwordController.text を使う
                                final password = passwordController.text;
                                print(
                                    '部屋を作成して開始: テーマ=$theme, 選択肢=$choice1 vs $choice2, 合言葉=$password');
                                vibration.vibrateShort();
                                // ページ2の引数でメソッドを呼び出す
                                notifier.findMatch(
                                    password, theme, choice1, choice2);
                                Navigator.of(context).pop();
                              },
                        style: buttonStyle,
                        child: Text('作成して開始', style: buttonTextStyle),
                      ),
                    // --- ボタンの条件分岐 ここまで ---
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ページ1 (合言葉で参加) のUI ---
  Widget _buildSecretWordPage(TextEditingController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          const Text(
            'ルームに参加', // タイトル変更
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'フレンドが作成したルームに参加', // サブタイトル
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller,
            '合言葉 (10文字以内)',
            maxLength: 10,
            centerAlign: true,
          ),
          const SizedBox(height: 10),
          const Text(
            '合言葉だけ揃えれば通常のレスバができます！',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

// --- ページ2 (部屋作成) のUI ---
  Widget _buildThemePage(
    TextEditingController themeController,
    TextEditingController choice1Controller,
    TextEditingController choice2Controller,
    TextEditingController passwordController,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10,0,10,10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const Text(
            '部屋を作成',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildTextField(themeController, 'ディベートのテーマ (30文字以内)', maxLength: 30),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildTextField(choice1Controller, '選択肢 A (10文字以内)',
                      maxLength: 10)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                child: Text('VS',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              Expanded(
                  child: _buildTextField(choice2Controller, '選択肢 B (10文字以内)',
                      maxLength: 10)),
            ],
          ),
          const SizedBox(height: 15),
          _buildTextField(
            passwordController,
            '合言葉を設定 (10文字以内)',
            maxLength: 10,
          ),
          const SizedBox(height: 10),
          const Text(
            'テーマと選択肢、参加用の合言葉を設定します',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

// --- 共通TextFieldヘルパー ---
  Widget _buildTextField(TextEditingController controller, String hintText,
      {int maxLength = 30, bool centerAlign = false}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      textAlign: centerAlign ? TextAlign.center : TextAlign.start,
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: Colors.white,
          counterText: "",
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Colors.lightBlueAccent, width: 2),
          ),
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14)),
    );
  }
}

// import 'package:debate_project/main.dart'; // 既に user_ranking.dart でインポート済み
// import 'package:hooks_riverpod/hooks_riverpod.dart'; // 既に user_ranking.dart でインポート済み
// import 'user_ranking.dart'; // UserRankingクラスとProviderをインポート

// import 'package:debate_project/main.dart'; // supabase は user_ranking.dart から参照
// import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'user_ranking.dart'; // UserRankingクラスとProviderをインポート

class RankingDialog extends ConsumerWidget {
  const RankingDialog({Key? key}) : super(key: key);

  // Color palette
  static const Color dialogBackground = Colors.blue;
  static const Color appBarTextColor = Colors.white;
  // static const Color closeButtonColor = Color(0xFFE53935); // 元のコードにあったが未使用？

  static const Color listItemBackground = Color(0xFFDDE3F3);
  static const Color myRankItemBackground =
      Color(0xFFC5CAE9); // 通常の背景より少し暗く、または区別できる色
  static const Color rankBoxBackground = Color(0xFFB0BEC5);
  static const Color rankTextColor = Colors.white;

  static const Color playerNameColor = Color(0xFF1A237E);
  static const Color clanNameColor = Color(0xFF546E7A);
  static const Color trophyCountColor = Color(0xFF1A237E);

  static const Color defaultBadgeBackgroundColor = Color(0xFFCFD8DC);
  static const Color defaultBadgeIconColor = Color(0xFF78909C);

  static const Color loadingIndicatorColor = Colors.white;
  static const Color errorTextColor = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedRankingTabProvider);
    final currentUserId = ref.read(currentUserIdProvider);

    final AsyncValue<List<UserRanking>> rankingAsyncValue;
    if (selectedTab == RankingTab.top) {
      rankingAsyncValue = ref.watch(topRankingProvider);
    } else {
      if (currentUserId == null) {
        rankingAsyncValue = const AsyncValue.data([]);
      } else {
        rankingAsyncValue = ref.watch(nearbyRankingProvider);
      }
    }
 // 現在のユーザーIDを取得

    return AlertDialog(
      backgroundColor: dialogBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      titlePadding: const EdgeInsets.all(0),
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Container(
        // ... (タイトル部分は変更なし)
        padding: const EdgeInsets.only(
            left: 20.0, top: 12.0, right: 20.0, bottom: 3.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 24.0), // アイコンの幅と合わせるか、適切に調整
            const Text(
              'ランキング',
              style: TextStyle(
                color: appBarTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            InkWell(
              onTap: () {
                print('Close button tapped');
                Navigator.of(context).pop();
                ref.invalidate(topRankingProvider);
                ref.invalidate(nearbyRankingProvider);
              },
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 214, 132, 131),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              // ... (タブボタン部分は変更なし)
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(selectedRankingTabProvider.notifier).state =
                            RankingTab.top;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTab == RankingTab.top
                            ? const Color(0xFFFFC107)
                            : const Color(0xFF4A75D3),
                        foregroundColor: selectedTab == RankingTab.top
                            ? Colors.black
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('上位',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (currentUserId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("付近のランキングを表示するにはログインが必要です。")),
                          );
                          return;
                        }
                        ref.read(selectedRankingTabProvider.notifier).state =
                            RankingTab.nearby;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTab == RankingTab.nearby
                            ? const Color(0xFFFFC107)
                            : const Color(0xFF4A75D3),
                        foregroundColor: selectedTab == RankingTab.nearby
                            ? Colors.black
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('付近',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rankingAsyncValue.when(
                data: (users) {
                  if (selectedTab == RankingTab.nearby &&
                      currentUserId == null) {
                    return const Center(
                      child: Text(
                        '付近のランキングを表示するには\nログインが必要です。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: appBarTextColor, fontSize: 16),
                      ),
                    );
                  }
                  if (users.isEmpty) {
                    return const Center(
                      child: Text(
                        'ランキングデータがありません。',
                        style: TextStyle(color: appBarTextColor, fontSize: 16),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final rank = user.overallRank!;
                      final bool isCurrentUser =
                          user.id == currentUserId && currentUserId != null;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 10.0),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? myRankItemBackground
                              : listItemBackground, // ★ 自分の項目か否かで色を変更
                          borderRadius: BorderRadius.circular(8.0),
                          // オプション: 自分の項目に枠線を追加してさらに目立たせる
                          border: isCurrentUser
                              ? Border.all(
                                  color: Colors.indigo.shade300, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          // ... (Rowのコンテンツは変更なし)
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: rankBoxBackground,
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Text(
                                '$rank',
                                style: const TextStyle(
                                  color: rankTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 42,
                              height: 42,
                              child: user.avatarUrl != null &&
                                      user.avatarUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6.0),
                                      child: Image.network(
                                        user.avatarUrl!,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  defaultBadgeBackgroundColor,
                                              borderRadius:
                                                  BorderRadius.circular(6.0),
                                            ),
                                            child: const Icon(
                                                Icons.shield_outlined,
                                                size: 28,
                                                color: defaultBadgeIconColor),
                                          );
                                        },
                                        loadingBuilder: (BuildContext context,
                                            Widget child,
                                            ImageChunkEvent? loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.0,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.blue[700]!),
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: defaultBadgeBackgroundColor,
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: const Icon(Icons.help_outline,
                                          size: 28,
                                          color: defaultBadgeIconColor),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    user.name ?? 'プレイヤー',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: playerNameColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '勝利数: ${user.win ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: clanNameColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Image.asset(
                              'assets/images/trofie.png',
                              width: 26,
                              height: 26,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.emoji_events,
                                    size: 26, color: Color(0xFF7E57C2));
                              },
                            ),
                            const SizedBox(width: 5),
                            Text(
                              user.trophy.toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: trophyCountColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: loadingIndicatorColor)),
                error: (error, stackTrace) {
                  print("Ranking display error: $error");
                  print("Stack trace: $stackTrace");
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'ランキングの表示に失敗しました。\nエラー: ${error.toString()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: errorTextColor, fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: null,
    );
  }
}
