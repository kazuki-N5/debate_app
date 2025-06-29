import 'dart:io';

import 'package:debate_project/adsence/ad_banner_provider.dart';
import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/app_config_service.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/setting_provider.dart';
import 'package:debate_project/provider/user.dart'; // あなたのプロジェクトに合わせてください
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart'; // flutter_hooksをインポート
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart'; // GoRouterをインポート



class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showErrorDialogFlag = useState<bool>(false);
    final showMainatenanceDialogFlag = useState<bool>(false);
    final showforceupdateDialogFlag = useState<bool>(false);
    const String androidStoreUrl =
        'https://play.google.com/store/apps/details?id=YOUR_ANDROID_PACKAGE_NAME';
    const String iosStoreUrl = 'https://apps.apple.com/app/idYOUR_IOS_APP_ID';

    Future<void> launchStoreUrl() async {
      final url = Platform.isIOS ? iosStoreUrl : androidStoreUrl;
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch $url');
      }
    }

    Future<void> attemptInit() async {
      ref.read(bannerAdProvider.notifier).loadAd();
      await ref.read(settingsProvider.notifier).loadSettings();
      final usernotifier = ref.read(userProvider.notifier);
      try {
        final appstate =
            await ref.read(appStateProvider.notifier).loadVersion();
        print(appstate);
        if (appstate == AppStatus.error) {
          FlutterNativeSplash.remove();
          showErrorDialogFlag.value = true;
          return;
        } else if (appstate == AppStatus.forceUpdate) {
          FlutterNativeSplash.remove();
          showforceupdateDialogFlag.value = true;
          return;
        } else if (appstate == AppStatus.maintenance) {
          FlutterNativeSplash.remove();
          showMainatenanceDialogFlag.value = true;
          return;
        } else if (appstate == AppStatus.optionalUpdate) {
          ref.read(optionalboolProvider.notifier).state = true;
        } else if (appstate == AppStatus.normal) {
        } else {
          FlutterNativeSplash.remove();
          showErrorDialogFlag.value = true;
          return;
        }

        await usernotifier.signinandname();
      } catch (e) {
        FlutterNativeSplash.remove();
        if (context.mounted) {
          showErrorDialogFlag.value = true;
        }
      }
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          attemptInit();
        }
      });
      return null;
    }, const []);

    useEffect(() {
      if (showMainatenanceDialogFlag.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && showMainatenanceDialogFlag.value) {
            _showMaintenanceDialog(context, () {
              showMainatenanceDialogFlag.value = false;              
              attemptInit();
            },
            ref.read(appConfigProvider)?.maintenanceMessage ?? 'メンテナンス中です'
             );
          }
        });
      }
      return null;
    }, [showMainatenanceDialogFlag.value]);

    useEffect(() {
      if (showErrorDialogFlag.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && showErrorDialogFlag.value) {
            _showErrorDialog(context, () {
              showErrorDialogFlag.value = false;
              attemptInit();
            });
          }
        });
      }
      return null;
    }, [showErrorDialogFlag.value]);

    useEffect(() {
      if (showforceupdateDialogFlag.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && showforceupdateDialogFlag.value) {
            _showforceUpdateDialog(context, () {
              showforceupdateDialogFlag.value = false;
              launchStoreUrl();
            });
          }
        });
      }
      return null;
    }, [showforceupdateDialogFlag.value]);

    return const Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: SizedBox(
          width: 230,
          height: 230,
          child: Image(
            image: AssetImage('assets/images/debateimage.png'),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, VoidCallback onRetry) {
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
          title: const Text(
            'ネットワークエラー',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
          content: const Text(
            'データの取得に失敗しました。\nもう一度お試しください。',
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
                'やり直す',
                style: TextStyle(
                  color: buttonTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // ダイアログを閉じる
                onRetry(); // 再試行コールバックを実行
              },
            ),
          ],
        );
      },
    ).then((_) {
      // ダイアログが閉じた後に実行される (オプション)
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
                Navigator.of(dialogContext).pop(); // ダイアログを閉じる
                onRetry(); // 再試行コールバックを実行
              },
            ),
          ],
        );
      },
    ).then((_) {
      // ダイアログが閉じた後に実行される (オプション)
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
}
