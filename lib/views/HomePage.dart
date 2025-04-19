import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:flutter/material.dart';
// flutter/widgets.dart は flutter/material.dart に含まれるため不要な場合が多い
// import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
// flutter_riverpod/flutter_riverpod.dart は hooks_riverpod/hooks_riverpod.dart に含まれる
// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);

    useEffect(() {
      // Call the function when the screen is opened
      roomnotifier.finishstream();
      roomnotifier.delete();

      // Optional: Return a dispose function if you need cleanup
      return null; // or return a dispose function
    }, []);

    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: SafeArea(
          child: Column(
            children: [
              // Top section with profile, name, trophy count, and icons
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 25, 21, 21),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile image and user info
                    Row(
                      children: [
                        // Profile image
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/debateimage.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Name and trophy count
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  // constを追加
                                  Icons.emoji_events,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 4), // constを追加
                                Text(
                                  user.trophy.toString(),
                                  style: const TextStyle(
                                    // constを追加
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Settings and history icons
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.white70,
                            size: 40,
                          ),
                          onPressed: (){
                            context.push('/setting');
                          },
                        ),
                        const SizedBox(height: 7),
                        IconButton(
                          icon: const Icon(
                            Icons.history,
                            color: Colors.white70,
                            size: 40,
                          ),
                          onPressed: () {
                            // 履歴画面への遷移などの処理を追加
                            context.push('/History');
                          },
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
                                          '論破する',
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
                        )
                      ],
                    ),
                  ],
                ),
              ),

              // Expanding space
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 31,
                      ),
                      SizedBox(
                        width: 250,
                        height: 250,
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
              ),

              // Bottom buttons arranged vertically
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Play with friends button
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

                    // Game start button
                    SizedBox(
                      // ContainerをSizedBoxに変更 (子にElevatedButtonしかないため)
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // watchではなくreadを使う (ボタン押下時のアクションのため)
                          ref.read(matchingRoomProvider.notifier).findMatch('', '', '', '');
                        },  
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

              // Bottom advertisement area
              Container(
                height: 60,
                width: double.infinity,
                color: Colors.black12,
                child: const Center(
                  child: Text(
                    'Advertisement Area',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendMatchDialog extends HookConsumerWidget {
  const FriendMatchDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final isPasswordEmpty = useState(passwordController.text.isEmpty); // 合言葉の空状態

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
            height: 400, // 高さは必要に応じて調整
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('キャンセル',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    // --- ここからボタンの条件分岐 ---
                    if (currentPage.value == 0) // ページ1 (参加) の場合
                      ElevatedButton(
                        onPressed: !isPage1Valid
                            ? null // ページ1が無効ならnull
                            : () {
                                final notifier =
                                    ref.read(matchingRoomProvider.notifier);
                                final secretWord = secretWordController.text;
                                print('合言葉で参加開始: $secretWord');
                                // ページ1の合言葉は secretWordController.text を使う
                                notifier.findMatch(secretWordController.text, '', '', '');
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
                                final notifier =
                                    ref.read(matchingRoomProvider.notifier);
                                final theme = themeController.text;
                                final choice1 = choice1Controller.text;
                                final choice2 = choice2Controller.text;
                                // ページ2の合言葉は passwordController.text を使う
                                final password = passwordController.text;
                                print(
                                    '部屋を作成して開始: テーマ=$theme, 選択肢=$choice1 vs $choice2, 合言葉=$password');
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
          const SizedBox(height: 90),
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
            'またはランダムでフレンドと対戦', // サブタイトル
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
            'フレンドが作成した部屋の合言葉を入力',
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
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
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
                  child: _buildTextField(choice1Controller, '選択肢 A (30文字以内)', maxLength: 30)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                child: Text('VS',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              Expanded(
                  child: _buildTextField(choice2Controller, '選択肢 B (30文字以内)', maxLength: 30)),
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