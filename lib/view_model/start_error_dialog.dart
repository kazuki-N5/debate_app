// ignore_for_file: file_names, avoid_print, use_build_context_synchronously, camel_case_types

import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/app_config_service.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_redirect/store_redirect.dart';
import 'package:permission_handler/permission_handler.dart';

class start_errornotifier extends StateNotifier {
  start_errornotifier(this.ref) : super(const ());

  final Ref ref;

  Future<void> launchStoreUrl() async {
    StoreRedirect.redirect(iOSAppId: "6747020633");
  }

  void showUpdateDialog(BuildContext context) {
    final update = ref.read(appConfigProvider);
    final updatenotifier = ref.read(appStateProvider.notifier);
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
              title: Text(
                'アップデートができます',
                textAlign: TextAlign.center,
                style: AppTextStyles.bold(
                  color: textColor,
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
                    style: AppTextStyles.notoSans(
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
                            side: WidgetStateBorderSide.resolveWith(
                              (states) => const BorderSide(
                                  color: textColor, width: 2), // ボーダーの色と太さ
                            ),
                            visualDensity: VisualDensity.compact, // 少しコンパクトにする
                          ),
                        ),
                        const SizedBox(width: 8.0), // チェックボックスとテキストの間のスペース
                        Expanded(
                          // テキストが長い場合にも対応
                          child: Text(
                            '次回のアップデートまで表示しない',
                            style: AppTextStyles.notoSans(
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
                        child: Text(
                          'しない',
                          style: AppTextStyles.bold(
                            color: buttonTextColor,
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
                        child: Text(
                          'する',
                          style: AppTextStyles.bold(
                            color: buttonTextColor,
                            fontSize: 16.0,
                          ),
                        ),
                        onPressed: () async {
                          await launchStoreUrl();
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

  void showErrorDialog(BuildContext context, VoidCallback onRetry) {
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

  void showMaintenanceDialog(
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
          title: Text(
            'メンテナンス中です',
            textAlign: TextAlign.center,
            style: AppTextStyles.bold(
              color: textColor,
              fontSize: 20.0,
            ),
          ),
          content: Text(
            message,
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
                '再試行',
                style: AppTextStyles.bold(
                  color: buttonTextColor,
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
      ref.read(maintenanceboolProvider.notifier).state = false;
    });
  }

  void showforceUpdateDialog(BuildContext context) {
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
          title: Text(
            'アップデートが必要です',
            textAlign: TextAlign.center,
            style: AppTextStyles.bold(
              color: textColor,
              fontSize: 20.0,
            ),
          ),
          content: Text(
            '最新バージョンが利用可能です。\nストアでアプリを更新してください。',
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
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, // 右矢印アイコンに変更
                  color: buttonTextColor,
                  size: 22.0),
              label: Text(
                'ストアを開く',
                style: AppTextStyles.bold(
                  color: buttonTextColor,
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
    );
  }

  void showPermissionDeniedDialog(BuildContext context) {
    const Color dialogBackgroundColor = Color(0xFF42A5F5);
    const Color textColor = Colors.white;
    const Color buttonTextColor = Color(0xFF1565C0);
    const Color buttonBackgroundColor = Colors.white;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
          title: Text(
            '通知がオフになっています',
            textAlign: TextAlign.center,
            style: AppTextStyles.bold(
              color: textColor,
              fontSize: 20.0,
            ),
          ),
          content: Text(
            '通知を受け取るには、設定画面から通知を「許可」にしてください。',
            textAlign: TextAlign.center,
            style: AppTextStyles.notoSans(
              color: textColor,
              fontSize: 16.0,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: buttonBackgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: Text(
                '設定を開く',
                style: AppTextStyles.bold(
                  color: buttonTextColor,
                  fontSize: 16.0,
                ),
              ),
              onPressed: () {
                openAppSettings();
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('閉じる', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// StateNotifierProviderの定義
final startProvider = StateNotifierProvider(
  (ref) => start_errornotifier(ref),
);
