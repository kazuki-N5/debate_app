import 'dart:ui';

import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/app_config_service.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_redirect/store_redirect.dart';

class start_errornotifier extends StateNotifier {
  start_errornotifier(this.ref) : super(const ());

  final Ref ref;

  Future<void> launchStoreUrl() async {
    StoreRedirect.redirect();
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
                            visualDensity: VisualDensity.compact, // 少しコンパクトにする
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

// StateNotifierProviderの定義
final startProvider = StateNotifierProvider(
  (ref) => start_errornotifier(ref),
);
