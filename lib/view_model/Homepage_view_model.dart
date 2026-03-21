import 'package:debate_project/modes/userranking_model.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/sfx_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/vibration_provider.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

final friendmatchProvider = StateProvider<bool>((ref) => false);

class FriendMatchDialog extends HookConsumerWidget {
  const FriendMatchDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMatching = useState<bool>(false);
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
    final friendmatch = ref.watch(friendmatchProvider);
    final friendmatchnotifier =
        ref.watch(friendmatchProvider.notifier);

    void toggleBoolean() {
      // 現在の isEnabled.value の値を反転させて、再代入します。
      // これによりWidgetが再ビルドされ、UIが更新されます。
      isMatching.value = !isMatching.value;
    }

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

    final buttonTextStyle = AppTextStyles.bold(
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
            height: 380, // 高さは必要に応じて調整
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
                      child: Text(
                        'キャンセル',
                        style: AppTextStyles.notoSans(color: Colors.white70),
                      ),
                    ),
                    // --- ここからボタンの条件分岐 ---
                    if (currentPage.value == 0) // ページ1 (参加) の場合
                      ElevatedButton(
                        onPressed: (!isPage1Valid || isMatching.value || friendmatch)
                            ? null // ページ1が無効ならnull
                            : () async {
                                toggleBoolean();
                                friendmatchnotifier.state = true; 
                                ref
                                    .read(soundServiceProvider)
                                    .playSfx(SfxAssets.go);

                                vibration.vibrateShort();
                                final secretWord = secretWordController.text;
                                print('合言葉で参加開始: $secretWord');

                                // ページ1の合言葉は secretWordController.text を使う
                                await ref
                                    .read(matchingRoomProvider.notifier)
                                    .findMatch(
                                        secretWordController.text, '', '', '');
                                toggleBoolean();
                                friendmatchnotifier.state = false; 
                                Navigator.of(context).pop();
                              },
                        style: buttonStyle,
                        child: Text('参加する', style: buttonTextStyle),
                      )
                    else if (currentPage.value == 1) // ページ2 (作成) の場合
                      ElevatedButton(
                        onPressed: !isPage2Valid || isMatching.value || friendmatch
                            ? null // ページ2が無効ならnull
                            : () async {
                                toggleBoolean();
                                friendmatchnotifier.state = true; 
                                ref
                                    .read(soundServiceProvider)
                                    .playSfx(SfxAssets.go);
                                final theme = themeController.text;
                                final choice1 = choice1Controller.text;
                                final choice2 = choice2Controller.text;
                                // ページ2の合言葉は passwordController.text を使う
                                final password = passwordController.text;
                                print(
                                    '部屋を作成して開始: テーマ=$theme, 選択肢=$choice1 vs $choice2, 合言葉=$password');
                                vibration.vibrateShort();
                                // ページ2の引数でメソッドを呼び出す
                                await ref
                                    .read(matchingRoomProvider.notifier)
                                    .findMatch(
                                        password, theme, choice1, choice2);
                                toggleBoolean();
                                friendmatchnotifier.state = false;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          Text(
            'ルームに参加', // タイトル変更
            style: AppTextStyles.bold(
              fontSize: 18,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'フレンドが作成したルームに参加', // サブタイトル
            style: AppTextStyles.notoSans(color: Colors.white70, fontSize: 14),
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
          Text(
            '合言葉だけ揃えれば通常のレスバができます！',
            style: AppTextStyles.notoSans(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

// --- ページ2 (部屋作成) のUI ---
  // [修正点] SingleChildScrollView を削除し、Paddingでレイアウトを維持します
  Widget _buildThemePage(
    TextEditingController themeController,
    TextEditingController choice1Controller,
    TextEditingController choice2Controller,
    TextEditingController passwordController,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            '部屋を作成',
            style: AppTextStyles.bold(
              fontSize: 18,
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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                child: Text('VS',
                    style: AppTextStyles.bold(
                        color: Colors.white,
                        fontSize: 16),),
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
          Text(
            'テーマと選択肢、参加用の合言葉を設定します',
            style: AppTextStyles.notoSans(color: Colors.white70, fontSize: 14),
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
      style: AppTextStyles.notoSans(color: Colors.black87, fontSize: 16),
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
          hintStyle: AppTextStyles.notoSans(color: Colors.grey[500], fontSize: 14)),
    );
  }
}

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
            Text(
              'ランキング',
              style: AppTextStyles.bold(
                color: appBarTextColor,
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
                      child: Text('上位',
                          style: AppTextStyles.bold(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (currentUserId == null) {
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
                      child: Text('付近',
                          style: AppTextStyles.bold(fontSize: 15)),
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
                    return Center(
                      child: Text(
                        '付近のランキングを表示するには\nログインが必要です。',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.notoSans(color: appBarTextColor, fontSize: 16),
                      ),
                    );
                  }
                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        'ランキングデータがありません。',
                        style: AppTextStyles.notoSans(color: appBarTextColor, fontSize: 16),
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
                                style: AppTextStyles.bold(
                                  color: rankTextColor,
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
                                    style: AppTextStyles.bold(
                                      fontSize: 15,
                                      color: playerNameColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '勝利数: ${user.win ?? 0}',
                                    style: AppTextStyles.notoSans(
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
                              style: AppTextStyles.bold(
                                fontSize: 15,
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
                        style: AppTextStyles.notoSans(
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

class SubmitThemeDialog extends HookConsumerWidget {
  const SubmitThemeDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // soundServiceProvider や vibrationServiceProvider はご自身のプロジェクトに合わせてください
    // final soundService = ref.read(soundServiceProvider);
    // final vibration = ref.read(vibrationServiceProvider);

    // --- State管理のためのHooks ---
    final themeController = useTextEditingController();
    final choice1Controller = useTextEditingController();
    final choice2Controller = useTextEditingController();

    final isThemeEmpty = useState(themeController.text.isEmpty);
    final isChoice1Empty = useState(choice1Controller.text.isEmpty);
    final isChoice2Empty = useState(choice2Controller.text.isEmpty);

    // --- 派生State (ボタンの有効/無効) ---
    final isFormValid =
        !isThemeEmpty.value && !isChoice1Empty.value && !isChoice2Empty.value;

    // --- テキスト変更を監視するためのEffect Hook ---
    useEffect(() {
      void updateState() {
        isThemeEmpty.value = themeController.text.isEmpty;
        isChoice1Empty.value = choice1Controller.text.isEmpty;
        isChoice2Empty.value = choice2Controller.text.isEmpty;
      }

      themeController.addListener(updateState);
      choice1Controller.addListener(updateState);
      choice2Controller.addListener(updateState);

      // 初期状態を反映
      updateState();

      return () {
        themeController.removeListener(updateState);
        choice1Controller.removeListener(updateState);
        choice2Controller.removeListener(updateState);
      };
    }, [themeController, choice1Controller, choice2Controller]);

    // --- ボタンのスタイル定義 ---
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

    final buttonTextStyle = AppTextStyles.bold(
      fontSize: 16,
    );

    Future<void> submitTheme() async {
      try {
        // Supabaseクライアントを取得
        final supabase = ref.read(supabaseProvider);

        // テーブルにデータを挿入
        // sender_id と created_at は自動で入るので指定不要
        await supabase.from('debate_themes_request').insert({
          'theme': themeController.text,
          'choice1': choice1Controller.text,
          'choice2': choice2Controller.text,
          'sender_id': ref.read(currentUserIdProvider),
        });

        // 成功時のフィードバック
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('テーマを送信しました！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } catch (e) {}
    }

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // コンテンツの高さに合わせる
              children: [
                Text(
                  'テーマを送信',
                  style: AppTextStyles.bold(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                _buildTextField(themeController, 'ディベートのテーマ (30文字以内)',
                    maxLength: 30),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                          choice1Controller, '選択肢 A (10文字以内)',
                          maxLength: 10),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Text(
                        'VS',
                        style: AppTextStyles.bold(
                            color: Colors.white,
                            fontSize: 16),
                      ),
                    ),
                    Expanded(
                      child: _buildTextField(
                          choice2Controller, '選択肢 B (10文字以内)',
                          maxLength: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '追加したいテーマを入力して送信してください',
                  style: AppTextStyles.notoSans(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                // --- ボタン ---
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: !isFormValid
                        ? null
                        : () async {
                            await submitTheme();
                          },
                    style: buttonStyle,
                    child: Text('送信', style: buttonTextStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // テキストフィールドのUIを生成するヘルパーウィジェット
  Widget _buildTextField(TextEditingController controller, String hintText,
      {int? maxLength}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      style: AppTextStyles.notoSans(
        color: const Color(0xFF0D47A1),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.notoSans(
          color: Colors.grey[500],
        ),
        filled: true,
        fillColor: Colors.white,
        counterText: '', // デフォルトの文字数カウンターを非表示に
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2.5),
        ),
      ),
    );
  }
}
