import 'dart:io';
import 'package:debate_project/provider/setting_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart'; 
import 'package:debate_project/router/router.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
// SoundServiceとSfxAssetsを使う場合はインポート
// import 'package:debate_project/services/sound_service.dart';

class SettingPage extends HookConsumerWidget {
  const SettingPage({super.key});

  // --- 既存のヘルパー関数 (_launchURL, _requestReview など) は変更なし ---
  static const String _xProfileUrl = 'https://twitter.com/YOUR_X_USERNAME';

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
    }
  }

  Future<void> _requestReview(BuildContext context) async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.openStoreListing(
          appStoreId: '6747020633',
        );
      } else {
        if (!context.mounted) return;
      }
    } catch (e) {
      throw Exception('レビューリクエストに失敗しました: $e');
    }
  }

  void _handleSubscription(BuildContext context, WidgetRef ref) {
    // 例: プレミアム状態をtrueにする（テスト用）
    // ref.read(settingsProvider.notifier).setPremiumStatus(true);
  }

  void _restorePurchases(BuildContext context, WidgetRef ref) {}
  // --- ヘルパー関数の終わり ---

  void _reportBug(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // ダイアログの内容は別のStatefulWidgetに委譲
        return BugReportDialogContent();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // 効果音スライダーがアクティブかどうか (isSfxOn に基づく)
    final isSfxSliderActive = settings.isSfxOn;

    const double bottomButtonAreaHeight = kMinInteractiveDimension * 1.5;
    const double bottomPadding = 20.0;
    const double adBannerHeight = 60.0;

    Future<void> _handleDataTransfer(BuildContext context) async {
      router.push('/transfer');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.blue,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0,
                bottomButtonAreaHeight + bottomPadding + adBannerHeight),
            children: [
              // --- 音量設定セクション ---
              _buildSectionTitle('音量設定'), // タイトルを変更
              // 効果音の音量調整コントロールを表示
              _buildVolumeControl(
                context: context,
                title: '効果音', // タイトルを「効果音」に
                volume: settings.sfxVolume, // sfxVolume を使用
                isOn: settings.isSfxOn, // isSfxOn を使用
                // 効果音のオン/オフ状態に応じてスライダーの有効/無効を切り替え
                onVolumeChanged: isSfxSliderActive
                    ? (value) => settingsNotifier
                        .setSfxVolume(value) // setSfxVolume を呼び出し
                    : null,
                onToggleChanged: (value) =>
                    settingsNotifier.toggleSfx(value), // toggleSfx を呼び出し
                isActive: isSfxSliderActive, // isSfxOn に基づく
              ),
              // --- サウンド設定は削除 ---
              _buildSwitchTile(
                title: '振動',
                value: settings.isVibrationOn,
                onChanged: (value) => settingsNotifier.toggleVibration(value),
              ),
              const SizedBox(height: 10), // セクション間のスペース

              // --- 「サポート＆その他」セクション (変更なし) ---
              _buildSectionTitle('サポート＆その他'),
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
              const SizedBox(height: 10), // セクション間のスペース

              // --- 「プレミアム機能」セクション (変更なし) ---
              _buildSectionTitle('プレミアム機能'),
              if (!settings.isPremiumUser)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                  padding: EdgeInsets.symmetric(vertical: 16.0),
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
              const SizedBox(height: 30), // 下部のスペース確保
            ],
          ),
          // --- 戻るボタン (変更なし) ---
          Positioned(
            left: 10,
            bottom: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              iconSize: 28.0,
              color: Colors.black,
              tooltip: '戻る',
              onPressed: () => context.pop(),
              padding: const EdgeInsets.all(12.0),
              splashRadius: 24.0,
            ),
          ),
        ],
      ),
    );
  }

  // --- 以下のヘルパーメソッドは変更なし ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

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
                onChanged:
                    isActive ? onVolumeChanged : null, // isActiveに基づいて有効/無効を制御
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

  

class BugReportDialogContent extends HookConsumerWidget {
  // HookConsumerWidgetではコンストラクタにKeyを渡すのが一般的です
  const BugReportDialogContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hooksを使ってStateとControllerを管理します
    // これによりinitStateやdisposeが不要になります
    final bugController = useTextEditingController();
    final isSending = useState(false);
    // 非同期処理後にウィジェットが破棄されていないか確認するためのフック
    final isMounted = useIsMounted();
    final supabase = ref.read(supabaseProvider);

    final userId = ref.read(currentUserIdProvider);

    // 端末情報を取得する非同期関数
    // buildメソッド内で定義するか、別のファイルに切り出します
    Future<String> getDeviceInfo() async {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceData = 'Unknown Device';

      try {
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceData =
              'Android ${androidInfo.version.sdkInt} (${androidInfo.model})';
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceData =
              'iOS ${iosInfo.systemVersion} (${iosInfo.utsname.machine})';
        }
      } catch (e) {
        deviceData = 'Failed to get device info: $e';
      }
      return deviceData;
    }

    // バグ報告をSupabaseに送信する非同期関数
    Future<void> sendBugReport() async {
      if (bugController.text.trim().isEmpty) {
        return;
      }

      // setStateの代わりに .value を使って状態を更新します
      isSending.value = true;

      final bugDescription = bugController.text.trim();
      final deviceInfo = await getDeviceInfo();

      try {
        await supabase.from('bugs').insert({
          'user_id': userId,
          'device_info': deviceInfo,
          'bug_description': bugDescription,
        });

        if (!isMounted()) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('バグ報告を送信しました。ご協力ありがとうございます！')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        // エラーが発生した場合も考慮します
        if (!isMounted()) return;
      } finally {
        // mountedチェックは useIsMounted フックで行います
        if (isMounted()) {
          isSending.value = false;
        }
      }
    }

    // --- UI部分はここから ---
    // 元のコードのUI実装をそのまま利用します
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: const Text(
          'バグを報告',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '発生したバグの内容と、再現手順を詳しく教えてください。',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.8),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bugController,
                maxLines: 6,
                maxLength: 150,
                // isSending.valueで状態を読み取ります
                enabled: !isSending.value,
                style: const TextStyle(color: Colors.black, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '例: ○○の画面で○○をするとアプリがクラッシュする...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                ),
              ),
            ],
          ),
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: isSending.value
                ? null
                : () {
                    Navigator.of(context).pop();
                  },
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: const BorderSide(
                    color: Colors.black, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20.0, vertical: 10.0),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            child: const Text('キャンセル'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isSending.value ? null : sendBugReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24.0, vertical: 12.0),
              elevation: 2,
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            child: isSending.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('送信'),
          ),
        ],
      ),
    );
  }
}