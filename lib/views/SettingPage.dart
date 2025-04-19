import 'package:debate_project/provider/setting_provider.dart'; // あなたのプロジェクトに合わせてパスを調整してください
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';

class SettingPage extends HookConsumerWidget {
  const SettingPage({super.key});

  // XアカウントのURL (自分のものに置き換えてください)
  static const String _xProfileUrl =
      'https://twitter.com/YOUR_X_USERNAME'; // ★★★ 自分のXアカウントに変更 ★★★

  // URLを開くヘルパー関数
  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) return; // BuildContextが有効かチェック
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('URLを開けませんでした: $urlString')),
      );
    }
  }

  // アプリ内レビューを表示する関数
  Future<void> _requestReview(BuildContext context) async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        // ignore: use_build_context_synchronously
        if (!context.mounted) return; // BuildContextが有効かチェック
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このデバイスではレビューを利用できません。')),
        );
        // ストアに直接誘導するなどの代替案
        // inAppReview.openStoreListing(appStoreId: 'YOUR_APP_STORE_ID', microsoftStoreId: '...');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) return; // BuildContextが有効かチェック
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('レビュー表示中にエラーが発生しました: $e')),
      );
    }
  }

  // バグ報告 (仮の動作)
  void _reportBug(BuildContext context) {
    // ここにバグ報告のロジックを実装
    // 例: メールアプリを開く、フォームを表示するなど
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('バグ報告機能は準備中です。')),
    );
    // メールを開く例:
    // final Uri emailLaunchUri = Uri(
    //   scheme: 'mailto',
    //   path: 'your_support_email@example.com',
    //   query: 'subject=Bug Report: [Your App Name]&body=Please describe the bug:\n\n',
    // );
    // _launchURL(context, emailLaunchUri.toString());
  }

  // データ引き継ぎ (仮の動作)
  void _handleDataTransfer(BuildContext context) {
    // ここにデータ引き継ぎのロジックを実装
    // 例: 別の画面に遷移、ダイアログ表示など
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('データ引き継ぎ機能は準備中です。')),
    );
    // Navigator.push(context, MaterialPageRoute(builder: (_) => DataTransferScreen()));
  }

  // 課金申し込み (仮の動作)
  void _handleSubscription(BuildContext context, WidgetRef ref) {
    // ここに課金処理のロジックを実装
    // 例: in_app_purchase パッケージを使用
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('課金機能は準備中です。購入処理を開始します...')),
    );
    // 仮に成功したとして状態を更新（テスト用）
    // 注意: 実際の課金処理が成功した場合のみ呼び出すこと
    // ref.read(settingsProvider.notifier).setPremiumStatus(true);
  }

  // 課金復元 (仮の動作)
  void _restorePurchases(BuildContext context, WidgetRef ref) {
    // ここに購入済みアイテムの復元ロジックを実装
    // 例: in_app_purchase パッケージを使用
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('購入情報の復元を試みます...')),
    );
    // 仮に復元に成功したとして状態を更新（テスト用）
    // 注意: 実際の復元処理が成功した場合のみ呼び出すこと
    // ref.read(settingsProvider.notifier).setPremiumStatus(true);
  }

  @override
Widget build(BuildContext context, WidgetRef ref) {
  final settings = ref.watch(settingsProvider);
  final settingsNotifier = ref.read(settingsProvider.notifier);

  final isSoundSliderActive = settings.isSoundOn;

  // 戻るボタンの高さとパディングを考慮したコンテンツエリアのボトムパディング
  // IconButtonのタップ領域を考慮して少し広めに取る
  const double bottomButtonAreaHeight =
      kMinInteractiveDimension * 1.5; // 48.0 * 1.5 = 72.0
  const double bottomPadding = 20.0;
  // 広告バー用の高さを追加
  const double adBannerHeight = 60.0;

  return Scaffold(
    appBar: AppBar(
      title: const Text('設定'),
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false, // デフォルトの戻るボタンを非表示にする
    ),
    backgroundColor: Colors.blue.shade700, // 背景色を AppBar と同じ濃い青に
    body: Stack(
      // Stack を使用して戻るボタンを重ねる
      children: [
        // コンテンツ部分 (スクロール無効化)
        ListView(
          // ListView を維持しつつスクロールを無効化
          physics: const NeverScrollableScrollPhysics(), // スクロールを無効にする
          // 戻るボタンと重ならないように下部にパディングを追加
          padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0,
              bottomButtonAreaHeight + bottomPadding + adBannerHeight), // 広告スペース追加
          children: [
            _buildSectionTitle('サウンド設定'), // セクションタイトル（白色）
            _buildVolumeControl(
              context: context,
              title: 'サウンド',
              volume: settings.soundVolume,
              isOn: settings.isSoundOn,
              // サウンドのオン/オフ状態に応じてスライダーの有効/無効を切り替え
              onVolumeChanged: isSoundSliderActive
                  ? (value) => settingsNotifier.setSoundVolume(value)
                  : null,
              onToggleChanged: (value) => settingsNotifier.toggleSound(value),
              isActive: isSoundSliderActive,
            ),
            _buildSwitchTile(
              title: '振動',
              value: settings.isVibrationOn,
              onChanged: (value) => settingsNotifier.toggleVibration(value),
            ),
            // --- サウンド設定とサポート＆その他の間のDividerを削除 ---
            // Divider(height: 30, color: Colors.white.withOpacity(0.5)), // 元の間隔を維持
            const SizedBox(height: 0), // セクション間のスペースを少し確保

            // --- 「サポート＆その他」セクション ---
            _buildSectionTitle('サポート＆その他'), // セクションタイトル（白色）
            _buildListTile(
              icon: Icons.share,
              title: 'Xでシェア / フォロー',
              onTap: () => _launchURL(context, _xProfileUrl),
            ),
            _buildListTile(
              icon: Icons.rate_review,
              title: '評価する',
              onTap: () => _requestReview(context),
            ),
            _buildListTile(
              icon: Icons.bug_report,
              title: 'バグ報告',
              onTap: () => _reportBug(context),
            ),
            _buildListTile(
              icon: Icons.sync_alt,
              title: 'データ引き継ぎ',
              onTap: () => _handleDataTransfer(context),
            ),
            // --- サポート＆その他とプレミアム機能の間のDividerとSizedBoxを削除 ---
            // const SizedBox(height: 5), // 白線との間隔を狭める
            // Divider(height: 20, color: Colors.white.withOpacity(0.5)), // 高さを減らした
            const SizedBox(height: 10), // セクション間のスペースを少し確保

            // --- 「プレミアム機能」セクション ---
            _buildSectionTitle('プレミアム機能'), // セクションタイトル（白色）
            if (!settings.isPremiumUser)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0), // 元の間隔を維持
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.star),
                  label: const Text('広告を消す + AIお助け'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () => _handleSubscription(context, ref),
                ),
              ),
            if (settings.isPremiumUser)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0), // 元の間隔を維持
                child: Center(
                  child: Text(
                    'プレミアム機能をご利用中です！',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            _buildListTile(
              icon: Icons.restore,
              title: '購入情報を復元',
              onTap: () => _restorePurchases(context, ref),
            ),
            // 画面下部のスペース確保用 (コンテンツが少ない場合でも戻るボタンとバナー広告の両方に適切なスペースを確保)
            const SizedBox(height: 30), // 広告バーのスペース確保
          ],
        ),
        // --- 左下に戻るボタン（< アイコン、背景透明）を配置 ---
        Positioned(
          left: bottomPadding / 2, // 少し左に寄せる
          bottom: bottomPadding +0, // 広告バー分のスペースを考慮
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            iconSize: 28.0,
            color: Colors.grey.shade800,
            tooltip: '戻る',
            onPressed: () => Navigator.of(context).pop(),
            padding: const EdgeInsets.all(12.0),
            splashRadius: 24.0,
          ),
        ),
      ],
    ),
  );
}
  

  // --- 以下のヘルパーメソッドは変更なし ---

  // セクションタイトル用Widget
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white, // 文字色を白に
        ),
      ),
    );
  }

  // 音量調整用Widget (Slider + Switch)
  Widget _buildVolumeControl({
    required BuildContext context,
    required String title,
    required double volume,
    required bool isOn,
    required ValueChanged<double>? onVolumeChanged,
    required ValueChanged<bool> onToggleChanged,
    required bool isActive,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(title, style: const TextStyle(fontSize: 16)),
            ),
            Expanded(
              flex: 5,
              child: Slider(
                value: volume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: (volume * 100).toStringAsFixed(0),
                onChanged: isActive && onVolumeChanged != null
                    ? onVolumeChanged
                    : null,
                activeColor: Colors.blue.shade700,
                inactiveColor:
                    isActive ? Colors.blue.shade200 : Colors.grey.shade400,
                thumbColor:
                    isActive ? Colors.blue.shade700 : Colors.grey.shade400,
              ),
            ),
            Switch(
              value: isOn,
              onChanged: onToggleChanged,
              activeColor: Colors.blue.shade700,
            ),
          ],
        ),
      ),
    );
  }

  // オン/オフ切り替え用Widget (SwitchListTile)
  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue.shade700,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      ),
    );
  }

  // 各種アクションボタン用Widget (ListTile)
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue.shade800),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade600),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      ),
    );
  }
}