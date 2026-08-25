// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/adsence/ad_banner_provider.dart';
import 'package:debate_project/adsence/ad_mbanner_provider.dart';
import 'package:debate_project/adsence/ad_provider.dart'; // adNotifierProvider がここにあると仮定
import 'package:debate_project/modes/debate_scores.dart';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/sfx_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/provider/vibration_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/utils/rating_systems/brawl_stars_rating.dart';
import 'package:debate_project/view_model/Homepage_view_model.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:debate_project/widgets/radar_chart_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

class FinishPage extends HookConsumerWidget {
  const FinishPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibration = ref.read(vibrationServiceProvider);
    final isMatching = useState<bool>(false);
    final roomState = useState(ref.read(matchingRoomProvider));
    final room = roomState.value;
    final myuser = ref.watch(userProvider);
    final otheruserState = useState(ref.read(otherUserProvider));
    final otheruser = otheruserState.value;
    final user = ref.read(currentUserIdProvider);
    final usernotifier = ref.watch(userProvider.notifier);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);
    final BannerAd? mediumRectangleAd = ref.watch(mediumRectangleAdProvider);
    // isAdBlockingInteraction の状態を監視
    final isAdBlockingInteraction = ref.watch(adNotifierProvider);
    final isSubscribe = ref.watch(inAppPurchaseManagerProvider).isSubscribed;

    void toggleBoolean() {
      // 現在の isEnabled.value の値を反転させて、再代入します。
      // これによりWidgetが再ビルドされ、UIが更新されます。
      isMatching.value = !isMatching.value;
    }

    if (room.roomId == null || room.winner == null) {
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
                    await usernotifier.fetchUser(user!);
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
      ).then((_) {
        // ダイアログが閉じた後に実行される (オプション)
      });
    }

    useEffect(() {
      // 広告表示を通知 (例: 全画面広告など)
      if (isSubscribe == false) {
        ref.read(adNotifierProvider.notifier).showAd();
      }

      // マッチングフラグを確実にリセット
      ref.read(friendmatchProvider.notifier).state = false;

      Future.microtask(() {
        if (isSubscribe == false) {
          // 広告をロード
          ref.read(bannerAdProvider.notifier).loadAd();
          ref.read(matchingBannerAdProvider.notifier).loadAd();
        }
        // ロード済みの広告を表示 (Medium Rectangle Ad はビルド内で watch しているのでここで特別な処理は不要)
      });

      // 部屋の情報をクリア（チャット購読解除・プレゼンス破棄を含む）
      roomnotifier.delete();

      // ローカルカウンター: Finishページ表示回数を数え、アプリ起動回数と合算して
      // 合計4回になったらレビューお願いダイアログを表示する
      // （表示はHomePage側でisreviewフラグにより一度だけ）
      () async {
        final prefs = await SharedPreferences.getInstance();
        final count = (prefs.getInt(reviewTriggerCountPrefKey) ?? 0) + 1;
        await prefs.setInt(reviewTriggerCountPrefKey, count);
        if (count == 4) {
          ref.read(reviewProvider.notifier).state = true;
        }
      }();

      return () {};
    }, const []);

    String getResultText(MatchingRoom room, String userId) {
      String? winnerLabel = room.winner;
      if (winnerLabel == 'C') return '引き分け';
      if (winnerLabel == null || (winnerLabel != 'A' && winnerLabel != 'B')) {
        return '終了';
      }
      bool isPlayer1 = room.player1Id == userId;

      if (isPlayer1) {
        return winnerLabel == 'A' ? '勝利' : '敗北';
      } else {
        return winnerLabel == 'A' ? '敗北' : '勝利';
      }
    }

    String formatName(String name) {
      return "'$name'";
    }

    String formatResult(MatchingRoom room, Users myuser, Users otheruser) {
      String result = room.reason ?? ""; // 理由を直接取得（パース不要）

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

    // 決定した勝敗理由と結果テキスト
    final reasonText = formatResult(room, myuser, otheruser);
    final resultText = getResultText(room, user!);

    // スコア情報の取得
    final isPlayer1 = room.player1Id == user;
    final scores = room.scores;
    final myScore = scores?.getMyScore(isPlayer1) ?? const PlayerScore();
    final opponentScore = scores?.getOpponentScore(isPlayer1);

    String getChoiceText(bool? choice) {
      if (choice == null) return '';
      return choice ? (room.choice1 ?? '') : (room.choice2 ?? '');
    }

    final myChoice = getChoiceText(isPlayer1 ? room.player1Choice : room.player2Choice);
    final opponentChoice = getChoiceText(isPlayer1 ? room.player2Choice : room.player1Choice);

    // ポイント計算ロジックを useMemoized で管理（データ変更時に自動再計算）
    final ratingDetail = useMemoized(() {
      final winner = room.winner;
      if (winner == 'C') {
        return BrawlStarsRating.calculatePlayerChangeDetail(
          myuser.trophy,
          myuser.trophy,
          true,
        );
      }
      if (winner == null || (winner != 'A' && winner != 'B')) return null;
      final isWin = (winner == 'A' && room.player1Id == user) ||
          (winner == 'B' && room.player2Id == user);

      return BrawlStarsRating.calculatePlayerChangeDetail(
        myuser.trophy,
        otheruser.trophy,
        isWin,
      );
    }, [room.winner, myuser.trophy, otheruser.trophy, user]);

    final isUnderdogVal = ratingDetail?.isUnderdog ?? false;
    final basePointTextVal = ratingDetail == null
        ? ''
        : (ratingDetail.baseChange > 0 ? '+' : '') +
            ratingDetail.baseChange.toString();
    final bonusPointTextVal = ratingDetail == null
        ? ''
        : (ratingDetail.bonus > 0 ? '+' : '') + ratingDetail.bonus.toString();

    final hasTrophyChange = room.password == null && room.isBbs != true;

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
          const appStoreUrl =
              'https://link-my.app/resubato';
          // ダイアログを閉じる

          final shareText =
              'ディベートで「$resultText」しました！\nみんなも遊んでみよう！\n#ディベートアプリ\n$appStoreUrl';

          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path)],
              text: shareText,
              subject: 'ディベート結果',
              sharePositionOrigin: rect,
            ),
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
                // --- ここからが画像化されるウィジェット（スクロール領域） ---
                Flexible(
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: globalKey,
                      child: _ShareableResultCard(
                        result: resultText,
                        points: hasTrophyChange ? basePointTextVal : null,
                        bonus: hasTrophyChange && isUnderdogVal
                            ? bonusPointTextVal
                            : null,
                        reason: reasonText,
                        isUnderdog: isUnderdogVal,
                        myScore: myScore,
                        opponentScore: opponentScore,
                        myName: myuser.name ?? 'あなた',
                        opponentName: otheruser.name ?? '対戦相手',
                        myAvatarUrl: myuser.avatar_url,
                        opponentAvatarUrl: otheruser.avatar_url,
                        myChoice: myChoice,
                        opponentChoice: opponentChoice,
                      ),
                    ),
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
                            heroTag: null, // Heroアニメーションを無効化
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
                  color: Colors.black.withValues(alpha: 0.1),
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
                Text(
                  '結果発表',
                  style: AppTextStyles.bold(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 左側のダミー（表示されないがスペースを確保して「勝利/敗北」を中央に保つ）
                          if (hasTrophyChange)
                            Opacity(
                              opacity: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, 6),
                                    child: Row(
                                      children: [
                                        const Image(
                                          image: AssetImage(
                                              'assets/images/trofie.png'),
                                          width: 24,
                                          height: 24,
                                        ),
                                        const SizedBox(width: 1),
                                        Text(
                                          basePointTextVal,
                                          style: AppTextStyles.notoSans(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                          // 勝利/敗北
                          Text(
                            resultText,
                            style: AppTextStyles.notoSans(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: resultText == '勝利'
                                  ? Colors.red
                                  : Colors.grey[700],
                            ),
                          ),
                          if (hasTrophyChange)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 4),
                                Transform.translate(
                                  offset: const Offset(0, 6),
                                  child: Row(
                                    children: [
                                      const Image(
                                        image: AssetImage(
                                            'assets/images/trofie.png'),
                                        width: 24,
                                        height: 24,
                                      ),
                                      const SizedBox(width: 1),
                                      // 数字（-6等）
                                      Text(
                                        basePointTextVal,
                                        style: AppTextStyles.notoSans(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              (ratingDetail?.baseChange ?? 0) >
                                                      0
                                                  ? Colors.red
                                                  : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (isUnderdogVal && hasTrophyChange) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber[400]!,
                                Colors.amber[700]!,
                                Colors.orange[800]!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '格差ボーナス ',
                                style: AppTextStyles.bold(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const Image(
                                image: AssetImage(
                                    'assets/images/trofie.png'),
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 1),
                              Text(
                                bonusPointTextVal,
                                style: AppTextStyles.bold(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
                        // --- 両者の選択肢 VS対峙カード ---
                        if (myChoice.isNotEmpty || opponentChoice.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF8FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 自分（左側・青）
                                    Expanded(
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.blue[100],
                                            backgroundImage: myuser.avatar_url != null &&
                                                    myuser.avatar_url!.isNotEmpty
                                                ? ResizeImage(
                                                    NetworkImage(myuser.avatar_url!),
                                                    width: 72)
                                                : null,
                                            child: myuser.avatar_url == null ||
                                                    myuser.avatar_url!.isEmpty
                                                ? Icon(Icons.person,
                                                    size: 20, color: Colors.blue[700])
                                                : null,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            myuser.name ?? 'あなた',
                                            style: AppTextStyles.bold(
                                                fontSize: 11, color: Colors.grey[800]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              myChoice.isNotEmpty ? myChoice : '未選択',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.bold(
                                                  fontSize: 11, color: Colors.white),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 36), // VSバッジ用の隙間
                                    // 相手（右側・赤）
                                    Expanded(
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.red[100],
                                            backgroundImage: otheruser.avatar_url != null &&
                                                    otheruser.avatar_url!.isNotEmpty
                                                ? ResizeImage(
                                                    NetworkImage(otheruser.avatar_url!),
                                                    width: 72)
                                                : null,
                                            child: otheruser.avatar_url == null ||
                                                    otheruser.avatar_url!.isEmpty
                                                ? Icon(Icons.person,
                                                    size: 20, color: Colors.red[700])
                                                : null,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            otheruser.name ?? '対戦相手',
                                            style: AppTextStyles.bold(
                                                fontSize: 11, color: Colors.grey[800]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              opponentChoice.isNotEmpty
                                                  ? opponentChoice
                                                  : '未選択',
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.bold(
                                                  fontSize: 11, color: Colors.white),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // 中央VSバッジ
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[850],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'VS',
                                      style: AppTextStyles.bold(
                                          fontSize: 9, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // レーダーチャート＆論理能力%表示
                        RadarChartView(
                          myScore: myScore,
                          opponentScore: opponentScore,
                          myName: myuser.name ?? 'あなた',
                          opponentName: otheruser.name ?? '対戦相手',
                        ),
                        const SizedBox(height: 16),
                        // 勝敗の理由
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '勝敗の理由:',
                                style: AppTextStyles.bold(
                                  fontSize: 16,
                                  color: Colors.blue[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatResult(room, myuser, otheruser),
                                style: AppTextStyles.notoSans(
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
                        if (isSubscribe == false)
                          if (mediumRectangleAd != null)
                            Container(
                              alignment: Alignment.center,
                              width: mediumRectangleAd.size.width.toDouble(),
                              height: mediumRectangleAd.size.height.toDouble(),
                              child: AdWidget(ad: mediumRectangleAd),
                            )
                          else
                            Container()
                        else
                          Container(),
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
                      if (hasTrophyChange) ...[
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
                            child: Text(
                              'もう一度ディベート',
                              style: AppTextStyles.notoSans(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          // 左側の「ホームに戻る」ボタン
                          Expanded(
                            child: hasTrophyChange
                                ? OutlinedButton(
                                    onPressed: isAdBlockingInteraction
                                        ? null
                                        : () async {
                                            try {
                                              await usernotifier.fetchUser(
                                                  user);
                                              router.go('/home');
                                            } catch (e) {
                                              showErrorDialog(context);
                                            }
                                          },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.blue),
                                      minimumSize: const Size(0, 50), // 高さを50に設定
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'ホームに戻る',
                                      style: AppTextStyles.notoSans(
                                        color: Colors.blue,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: isAdBlockingInteraction
                                        ? null
                                        : () async {
                                            try {
                                              await usernotifier.fetchUser(
                                                  user);
                                              router.go('/home');
                                            } catch (e) {
                                              showErrorDialog(context);
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      minimumSize: const Size(0, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'ホームに戻る',
                                      style: AppTextStyles.notoSans(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
    required this.result,
    this.points,
    this.bonus,
    required this.reason,
    this.isUnderdog = false,
    required this.myScore,
    this.opponentScore,
    this.myName = 'あなた',
    this.opponentName,
    this.myAvatarUrl,
    this.opponentAvatarUrl,
    this.myChoice,
    this.opponentChoice,
  });

  final String result;
  final String? points;
  final String? bonus;
  final String reason;
  final bool isUnderdog;
  final PlayerScore myScore;
  final PlayerScore? opponentScore;
  final String myName;
  final String? opponentName;
  final String? myAvatarUrl;
  final String? opponentAvatarUrl;
  final String? myChoice;
  final String? opponentChoice;

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
          Text(
            '結果発表',
            style: AppTextStyles.bold(
              color: Colors.black,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 0),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (points != null)
                      Opacity(
                        opacity: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, 4),
                              child: Row(
                                children: [
                                  const Image(
                                    image: AssetImage(
                                        'assets/images/trofie.png'),
                                    width: 18,
                                    height: 18,
                                  ),
                                  const SizedBox(width: 1),
                                  Text(
                                    points!,
                                    style: AppTextStyles.bold(
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    Text(
                      result,
                      style: AppTextStyles.bold(
                        fontSize: 32,
                        color: result == '勝利' ? Colors.red : Colors.grey[700],
                      ),
                    ),
                    if (points != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 4),
                          Transform.translate(
                            offset: const Offset(0, 4),
                            child: Row(
                              children: [
                                const Image(
                                  image: AssetImage(
                                      'assets/images/trofie.png'),
                                  width: 18,
                                  height: 18,
                                ),
                                const SizedBox(width: 1),
                                Text(
                                  points!,
                                  style: AppTextStyles.notoSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: points!.startsWith('+')
                                        ? Colors.red
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (isUnderdog && bonus != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber[400]!,
                          Colors.amber[700]!,
                          Colors.orange[800]!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '格差ボーナス ',
                          style: AppTextStyles.bold(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const Image(
                          image: AssetImage('assets/images/trofie.png'),
                          width: 14,
                          height: 14,
                        ),
                        const SizedBox(width: 1),
                        Text(
                          bonus.toString(),
                          style: AppTextStyles.bold(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // --- 両者の選択肢 VS対峙カード ---
          if ((myChoice != null && myChoice!.isNotEmpty) ||
              (opponentChoice != null && opponentChoice!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 自分（左側・青）
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue[100],
                              backgroundImage: myAvatarUrl != null && myAvatarUrl!.isNotEmpty
                                  ? ResizeImage(NetworkImage(myAvatarUrl!), width: 64)
                                  : null,
                              child: myAvatarUrl == null || myAvatarUrl!.isEmpty
                                  ? Icon(Icons.person, size: 18, color: Colors.blue[700])
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              myName,
                              style: AppTextStyles.bold(fontSize: 10, color: Colors.grey[800]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                myChoice != null && myChoice!.isNotEmpty ? myChoice! : '未選択',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bold(fontSize: 10, color: Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32), // VSバッジ用の隙間
                      // 相手（右側・赤）
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.red[100],
                              backgroundImage: opponentAvatarUrl != null && opponentAvatarUrl!.isNotEmpty
                                  ? ResizeImage(NetworkImage(opponentAvatarUrl!), width: 64)
                                  : null,
                              child: opponentAvatarUrl == null || opponentAvatarUrl!.isEmpty
                                  ? Icon(Icons.person, size: 18, color: Colors.red[700])
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opponentName ?? '対戦相手',
                              style: AppTextStyles.bold(fontSize: 10, color: Colors.grey[800]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                opponentChoice != null && opponentChoice!.isNotEmpty
                                    ? opponentChoice!
                                    : '未選択',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bold(fontSize: 10, color: Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 中央VSバッジ
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'VS',
                        style: AppTextStyles.bold(fontSize: 8, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // レーダーチャート (静止画キャプチャ用)
          RadarChartView(
            myScore: myScore,
            opponentScore: opponentScore,
            myName: myName,
            opponentName: opponentName,
            isStatic: true,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '勝敗の理由:',
                  style: AppTextStyles.bold(
                    fontSize: 16,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: AppTextStyles.notoSans(
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
