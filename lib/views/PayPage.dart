import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// このページで利用するProviderの例です。
// 今後、実際の購入処理などを実装する際に利用できます。
final subscriptionViewModelProvider = Provider((ref) {
  // ここに購入処理のロジックなどを記述します。
  return SubscriptionViewModel();
});

class SubscriptionViewModel {
  // 購入ボタンが押されたときの処理
  Future<void> subscribe() async {
    // TODO: ここに 'in_app_purchase' パッケージなどを使用した
    // App Store/Google Play Store の実際の購入処理を実装します。
    print('購入処理を開始します...');
    // 例:
    // final success = await InAppPurchase.instance.buyNonConsumable(...);
    // if (success) { ... }
  }

  // URLを起動する共通の関数
  Future<void> launchURL(Uri url) async {
    if (!await launchUrl(url)) {
      // エラーハンドリング: URLが開けない場合
      print('Could not launch $url');
    }
  }
}

class PayPage extends ConsumerWidget {
  const PayPage({super.key});

  // --- ここにあなたのURLを貼り付けてください ---
  // 利用規約のURL
  static final Uri _termsOfServiceUrl =
      Uri.parse('https://humorous-abacus-317.notion.site/22c969f0105080c8997dd39de4574d51?pvs=143'); // <- あなたの利用規約URL

  // プライバシーポリシーのURL
  static final Uri _privacyPolicyUrl =
      Uri.parse('https://humorous-abacus-317.notion.site/22c969f01050804097efe13b39f04faa?pvs=143'); // <- あなたのプライバシーポリシーURL
  // -----------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(subscriptionViewModelProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('広告をオフにする',
            style: TextStyle(
                color: Color.fromARGB(255, 240, 237, 229),
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        elevation: 0,
        // --- 変更点 1: 左上の戻るボタンを非表示にする ---
        automaticallyImplyLeading: false,
      ),
      // --- 変更点 2: Stackを使用してUIを重ねる ---
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 上部のコンテンツ
                  Column(
                    children: [
                      const SizedBox(height: 30),
                      const Icon(
                        Icons.workspace_premium, // プレミアム感のあるアイコン
                        color: Colors.white,
                        size: 100,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'プレミアムプラン',
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '月額プランに登録して、\nアプリ内のすべての広告を非表示にし、\nもっと快適にレスバを楽しもう！',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white, fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '月額 500円',
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 下部のコンテンツ
                  Column(
                    children: [
                      // 購入ボタン
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          // viewModelの購入処理を呼び出す
                          viewModel.subscribe();
                        },
                        child: const Text('登録して広告を非表示にする'),
                      ),
                      const SizedBox(height: 20),

                      // 注意書きとリンク
                      Text(
                        'お支払いは、購入確認時にAppleアカウントに請求されます。サブスクリプションは、現在の期間が終了する24時間前までにキャンセルされない限り、自動的に更新されます。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () =>
                                viewModel.launchURL(_termsOfServiceUrl),
                            child: const Text(
                              '利用規約',
                              style: TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white),
                            ),
                          ),
                          const Text('|', style: TextStyle(color: Colors.white)),
                          TextButton(
                            onPressed: () =>
                                viewModel.launchURL(_privacyPolicyUrl),
                            child: const Text(
                              'プライバシーポリシー',
                              style: TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // --- 変更点 3: 左下に戻るボタンを配置 ---
          Positioned(
            left: 10,
            bottom: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              iconSize: 28.0,
              // 背景色に合わせて白に変更
              color: Colors.white,
              tooltip: '戻る',
              // 画面を閉じる処理
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.all(12.0),
              splashRadius: 24.0,
            ),
          ),
        ],
      ),
    );
  }
}