import 'dart:math' hide log;

import 'package:debate_project/adsence/ad_banner_provider.dart';
import 'package:debate_project/adsence/ad_mbanner_provider.dart';
import 'package:debate_project/adsence/ad_provider.dart'; // adNotifierProvider がここにあると仮定
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/message_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/sfx_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/provider/vibration_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

class FinishPage extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibration = ref.read(vibrationServiceProvider);
    final isMatching = useState<bool>(false);
    final ischange = useState<bool>(true);
    final save = useState<String>('');
    final roomState = useState(ref.read(matchingRoomProvider));
    final room = roomState.value;
    final myuser = ref.watch(userProvider);
    final otheruser = ref.watch(otherUserProvider);
    final user = ref.read(currentUserIdProvider);
    final usernotifier = ref.watch(userProvider.notifier);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);
    final chatsnotifier = ref.read(chatProvider.notifier);
    final BannerAd? mediumRectangleAd = ref.watch(mediumRectangleAdProvider);
    // isAdBlockingInteraction の状態を監視
    final isAdBlockingInteraction = ref.watch(adNotifierProvider);
    final isSubscribe = ref.watch(inAppPurchaseManagerProvider).isSubscribed;
    ;

    void toggleBoolean() {
      // 現在の isEnabled.value の値を反転させて、再代入します。
      // これによりWidgetが再ビルドされ、UIが更新されます。
      isMatching.value = !isMatching.value;
    }

    if (room.roomId == null || room.result == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('結果の読み込みに失敗しました。'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => router.go('/home'),
                child: const Text('ホームに戻る'),
              ),
            ],
          ),
        ),
      );
    }

    void _showErrorDialog(BuildContext context) {
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
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    final result = await usernotifier.fetchUser(user!);
                    if (result.win! >= 5) {
                      ref.read(reviewProvider.notifier).state = true;
                    }
                    router.go('/home');
                  } catch (e) {
                    _showErrorDialog(context);
                  }
                  // 再試行コールバックを実行
                },
              ),
            ],
          );
        },
      ).then((_) {
        // ダイアログが閉じた後に実行される (オプション)
      });
    }

    useEffect(() {
      // 広告表示を通知 (例: 全画面広告など)
      if (isSubscribe == false) {
        
      ref.read(adNotifierProvider.notifier).showAd();
      }

      Future.microtask(() {
        if (isSubscribe == false) {
          // 広告をロード
          ref.read(bannerAdProvider.notifier).loadAd();
        }
        // ロード済みの広告を表示 (Medium Rectangle Ad はビルド内で watch しているのでここで特別な処理は不要)
      });

      // 部屋の情報をクリア
      roomnotifier.delete();
      // 部屋の状態ストリームの購読を終了
      // メッセージストリームの購読を終了
      chatsnotifier.unsubscribeFromMessages();

      return () {};
    }, const []);

    String getResultText(MatchingRoom room, String userId) {
      // room.resultの最初の文字を取得
      String firstChar = room.result![0];
      bool isPlayer1 = room.player1Id == userId;

      if (isPlayer1) {
        return firstChar == 'A' ? '勝利' : '敗北';
      } else {
        return firstChar == 'A' ? '敗北' : '勝利';
      }
    }

    String formatName(String name) {
      return "'$name'";
    }

    String formatResult(MatchingRoom room, Users myuser, Users otheruser) {
      String result = room.result!.substring(1); // 最初の1文字を削除

      // 先頭の空白を削除
      result = result.trimLeft();

      if (room.player1Id == myuser.id) {
        result = result
            .replaceAll('A', formatName(myuser.name!))
            .replaceAll('B', formatName(otheruser.name!));
      } else {
        // player1がotheruserの場合
        result = result
            .replaceAll('A', formatName(otheruser.name!))
            .replaceAll('B', formatName(myuser.name!));
      }

      return result;
    }

    int clamp(int point, int min, int max) {
      if (point < min) {
        return min;
      } else if (max < point) {
        return max;
      } else {
        return point;
      }
    }

    String calculatePoint(int winnerRate, int loserRate) {
      const int K = 32;

      double calculation = K / (pow(10, (winnerRate - loserRate) / 400) + 1);
      int point = calculation.round();
      point = clamp(point, 2, 32);
      return "$point";
    }

    String displayPoint(
        MatchingRoom room, Users myuser, Users otheruser, String userId) {
      String firstChar = room.result![0];
      if (ischange.value) {
        ischange.value = false;
        if (firstChar == 'A') {
          if (room.player1Id == userId) {
            save.value = '+${calculatePoint(myuser.trophy, otheruser.trophy)}';
            return save.value;
          } else {
            save.value = '-${calculatePoint(otheruser.trophy, myuser.trophy)}';
            return save.value;
          }
        } else if (firstChar == 'B') {
          if (room.player1Id == userId) {
            save.value = '-${calculatePoint(otheruser.trophy, myuser.trophy)}';
            return save.value;
          } else {
            save.value = '+${calculatePoint(myuser.trophy, otheruser.trophy)}';
            return save.value;
          }
        } else {
          // 引き分けなどのケースがあればここに追記
          return '0';
        }
      }
      return save.value;
    }

    final pointText = displayPoint(room, myuser, otheruser, user!);
    final reasonText = formatResult(room, myuser, otheruser);
    final resultText = getResultText(room, user);

    void showSharePreviewDialog() {
      final GlobalKey globalKey = GlobalKey();

      // 画像をキャプチャして共有する非同期関数（ダイアログ内で定義）
      Future<void> captureAndShare(BuildContext buttonContext) async {
        try {
          final box = buttonContext.findRenderObject() as RenderBox?;
          final rect =
              box != null ? box.localToGlobal(Offset.zero) & box.size : null;
          final boundary = globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 3.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) return;
          final pngBytes = byteData.buffer.asUint8List();

          final tempDir = await getTemporaryDirectory();
          final file = await File('${tempDir.path}/debate_result.png').create();
          await file.writeAsBytes(pngBytes);
          // ダイアログを閉じる

          final shareText = 'ディベートで「$resultText」しました！\nみんなも遊んでみよう！\n#ディベートアプリ';

          await Share.shareXFiles(
            [XFile(file.path)],
            text: '$shareText\njjfjfj',
            subject: 'ディベート結果',
            sharePositionOrigin: rect,
          );

          Navigator.of(context).pop();
        } catch (e) {
          Navigator.of(context).pop(); // エラー時もダイアログを閉じる
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('画像のシェアに失敗しました。')),
          );
        }
      }

      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- ここからが画像化されるウィジェット ---
                RepaintBoundary(
                  key: globalKey,
                  child: _ShareableResultCard(
                    result: resultText,
                    points: room.password == null ? pointText : null,
                    reason: reasonText,
                  ),
                ),
                // --- ここまで ---
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Builder(
                      // ★★★ Builderでラップ ★★★
                      builder: (buttonContext) {
                        return SizedBox(
                          height: 48.0, // 高さを指定
                          width: 48.0,
                          child: FloatingActionButton(
                            shape: const CircleBorder(),
                            backgroundColor: Colors.white,
                            // ★★★ 取得したContextを渡して関数を呼び出す ★★★
                            onPressed: () => captureAndShare(buttonContext),
                            // 共有でよく見るアイコン（Icons.share）を指定します。
                            // iOS風にしたい場合は `Icon(CupertinoIcons.share)` なども利用できます。
                            child: const Icon(
                              CupertinoIcons.share,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                )
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // --- START: FIXED TOP AREA (スクロールしない上部エリア) ---
                const SizedBox(height: 24),
                // Header with centered title
                const Text(
                  '結果発表',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 200, // Stackに十分な幅を確保
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 勝利/敗北を中央に配置
                        Text(
                          resultText,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: resultText == ('勝利')
                                ? Colors.red
                                : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // 数字を右側に配置
                        if (room.password == null)
                          Positioned(
                            right: 20,
                            top: 25,
                            child: Text(
                              displayPoint(room, myuser, otheruser, user),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: resultText == ('勝利')
                                    ? Colors.red
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // --- END: FIXED TOP AREA ---

                // --- START: SCROLLABLE CONTENT AREA (スクロールする中央エリア) ---
                Expanded(
                  child: SingleChildScrollView(
                    // 左右のパディングをこちらに移動
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        // 勝敗の理由
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '勝敗の理由:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatResult(room, myuser, otheruser),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // --- Medium Rectangle Ad 表示エリア ---
                        if (mediumRectangleAd != null)
                          Container(
                            alignment: Alignment.center,
                            width: mediumRectangleAd.size.width.toDouble(),
                            height: mediumRectangleAd.size.height.toDouble(),
                            child: AdWidget(ad: mediumRectangleAd),
                          )
                        else
                          Container(
                          ),
                        const SizedBox(
                            height: 24), // Add padding at the end of scroll
                      ],
                    ),
                  ),
                ),
                // --- START: FIXED BUTTONS AREA (スクロールしない下部エリア) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IgnorePointer(
                        ignoring: isAdBlockingInteraction,
                        child: ElevatedButton(
                          onPressed: isMatching.value || isAdBlockingInteraction
                              ? null
                              : () async {
                                  toggleBoolean();
                                  ref
                                      .read(soundServiceProvider)
                                      .playSfx(SfxAssets.go);
                                  vibration.vibrateShort();
                                  // findMatchの呼び出しは変更なし
                                  await ref
                                      .read(matchingRoomProvider.notifier)
                                      .findMatch('', '', '', '');
                                  toggleBoolean();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            disabledBackgroundColor: Colors.blue,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'もう一度ディベート',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // 左側の「ホームに戻る」ボタン
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isAdBlockingInteraction
                                  ? null
                                  : () async {
                                      try {
                                        final result =
                                            await usernotifier.fetchUser(user);
                                        if (result.win! >= 5) {
                                          ref
                                              .read(reviewProvider.notifier)
                                              .state = true;
                                        }
                                        router.go('/home');
                                      } catch (e) {
                                        _showErrorDialog(context);
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.blue),
                                minimumSize: const Size(0, 50), // 高さを50に設定
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'ホームに戻る',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12), // ボタン間のスペース
                          // 右側のシェアボタン（正方形）
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: OutlinedButton(
                              // TODO: シェア機能のロジックをここに実装します
                              onPressed: isAdBlockingInteraction
                                  ? null
                                  : () async {
                                      showSharePreviewDialog();
                                    },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.blue),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.zero, // アイコンを中央に配置
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined, // カメラアイコン
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // --- END: FIXED BUTTONS AREA ---
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareableResultCard extends StatelessWidget {
  const _ShareableResultCard({
    Key? key,
    required this.result,
    this.points,
    required this.reason,
  }) : super(key: key);

  final String result;
  final String? points;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '結果発表',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 0),
          Center(
            child: SizedBox(
              width: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    result,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: result == ('勝利') ? Colors.red : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '勝敗の理由:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
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
