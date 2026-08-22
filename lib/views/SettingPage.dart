// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:io';
import 'package:debate_project/provider/setting_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart'; 
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
// SoundServiceとSfxAssetsを使う場合はインポート
// import 'package:debate_project/services/sound_service.dart';

class SettingPage extends HookConsumerWidget {
  const SettingPage({super.key});

  // --- 既存のヘルパー関数 (_launchURL, _requestReview など) は変更なし ---
  static const String _xProfileUrl = 'https://x.com/resubadebate';

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
    router.push('/pay');
  }

 
  // --- ヘルパー関数の終わり ---

  void _reportBug(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // ダイアログの内容は別のStatefulWidgetに委譲
        return const BugReportDialogContent();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final isSubscribed = ref.watch(inAppPurchaseManagerProvider).isSubscribed;
    final inappNotifier = ref.read(inAppPurchaseManagerProvider.notifier);
    // 効果音スライダーがアクティブかどうか (isSfxOn に基づく)
    final isSfxSliderActive = settings.isSfxOn;

    Future<void> handleDataTransfer(BuildContext context) async {
      router.push('/transfer');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('設定',
            style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.blue,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 30.0),
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

          // --- 通知セクション ---
          _buildSectionTitle('通知'),
          _buildListTile(
            icon: Icons.notifications,
            title: '通知設定',
            onTap: () => router.push('/notification_settings'),
          ),
          const SizedBox(height: 10), // セクション間のスペース

          // --- 「サポート＆その他」セクション (変更なし) ---
          _buildSectionTitle('サポート＆その他'),
          _buildListTile(
            icon: FontAwesomeIcons.xTwitter.data,
            title: '公式X',
            onTap: () => _launchURL(context, _xProfileUrl),
            iconSize: 20,
          ),
          _buildListTile(
            icon: Icons.rate_review,
            title: '評価する',
            onTap: () => _requestReview(context),
          ),
          _buildListTile(
            icon: Icons.bug_report,
            title: 'バグ報告&機能提案',
            onTap: () => _reportBug(context),
          ),
          _buildListTile(
            icon: Icons.sync_alt,
            title: 'データ引き継ぎ',
            onTap: () => handleDataTransfer(context),
          ),
          _buildListTile(
            icon: Icons.block,
            title: 'ブロック管理',
            onTap: () => router.push('/blocked_users'),
          ),
          const SizedBox(height: 10), // セクション間のスペース

          // --- 「プレミアム機能」セクション (変更なし) ---
          _buildSectionTitle('プレミアム機能'),
          if (isSubscribed == false)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.star),
                label: const Text('広告を消す'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  textStyle: AppTextStyles.notoSans(fontSize: 16),
                ),
                onPressed: () => _handleSubscription(context, ref),
              ),
            ),
          if (isSubscribed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'プレミアム機能をご利用中です！',
                  style: AppTextStyles.bold(
                      color: Colors.white,
                      fontSize: 16),
                ),
              ),
            ),
          _buildListTile(
            icon: Icons.restore,
            title: '購入情報を復元',
            onTap: () async => await inappNotifier.restorePurchases(),
          ),
          const SizedBox(height: 30), // 下部のスペース確保
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
        style: AppTextStyles.bold(
          fontSize: 18,
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
              child: Text(title, style: AppTextStyles.notoSans(fontSize: 16)),
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
              activeThumbColor: Colors.blue.shade700,
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
        title: Text(title, style: AppTextStyles.notoSans(fontSize: 16)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.blue.shade700,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    double? iconSize, // ▼▼▼【変更点 1/2】オプショナルなiconSize引数を追加 ▼▼▼
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        // Iconウィジェットにsizeプロパティを渡す
        leading: Icon(icon, color: Colors.blue.shade800, size: iconSize),
        title: Text(title, style: AppTextStyles.notoSans(fontSize: 16)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade600),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      ),
    );
  }
}

  

class BugReportDialogContent extends HookConsumerWidget {
  const BugReportDialogContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugController = useTextEditingController();
    final isSending = useState(false);
    final isFeatureRequest = useState(false); // false: バグ報告 / true: 機能提案
    final textLength = useState(0);

    final supabase = ref.read(supabaseProvider);
    final userId = ref.read(currentUserIdProvider);

    useEffect(() {
      void listener() {
        textLength.value = bugController.text.length;
      }
      bugController.addListener(listener);
      return () => bugController.removeListener(listener);
    }, [bugController]);

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

    Future<void> sendBugReport() async {
      final text = bugController.text.trim();
      if (text.isEmpty) return;

      isSending.value = true;
      final typePrefix = isFeatureRequest.value ? '【機能提案】' : '【バグ報告】';
      final bugDescription = '$typePrefix $text';
      final deviceInfo = await getDeviceInfo();

      try {
        await supabase.from('bugs').insert({
          'user_id': userId,
          'device_info': deviceInfo,
          'bug_description': bugDescription,
        });

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFeatureRequest.value
                ? '機能提案を送信しました！ご協力ありがとうございます！'
                : 'バグ報告を送信しました。ご協力ありがとうございます！'),
          ),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('送信に失敗しました。時間をおいてお試しください。')),
        );
      } finally {
        if (context.mounted) {
          isSending.value = false;
        }
      }
    }

    final hasInput = textLength.value > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 18.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 上部セグメントタブ（バグ報告 / 機能提案）
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // slate-100
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Row(
                    children: [
                      // バグ報告タブ
                      Expanded(
                        child: GestureDetector(
                          onTap: () => isFeatureRequest.value = false,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !isFeatureRequest.value
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.0),
                              boxShadow: !isFeatureRequest.value
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bug_report,
                                  size: 16,
                                  color: !isFeatureRequest.value
                                      ? Colors.red
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'バグ報告',
                                  style: AppTextStyles.bold(
                                    fontSize: 13,
                                    color: !isFeatureRequest.value
                                        ? Colors.red
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 機能提案タブ
                      Expanded(
                        child: GestureDetector(
                          onTap: () => isFeatureRequest.value = true,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isFeatureRequest.value
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.0),
                              boxShadow: isFeatureRequest.value
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 16,
                                  color: isFeatureRequest.value
                                      ? const Color(0xFFD97706) // amber-600
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '機能提案',
                                  style: AppTextStyles.bold(
                                    fontSize: 13,
                                    color: isFeatureRequest.value
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 説明文
                Text(
                  isFeatureRequest.value
                      ? '「こんな機能があったらもっと面白い」というアイデアを教えてください！'
                      : '発生した不具合の状況や再現手順を詳しく教えてください。',
                  style: AppTextStyles.notoSans(
                    color: const Color(0xFF64748B), // slate-500
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                // テキスト入力エリア
                Stack(
                  children: [
                    TextField(
                      controller: bugController,
                      maxLines: 5,
                      maxLength: 150,
                      enabled: !isSending.value,
                      style: AppTextStyles.notoSans(
                        color: const Color(0xFF0F172A),
                        fontSize: 13.5,
                      ),
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) =>
                          null, // デフォルトの文字数カウントを非表示にしてカスタム配置
                      decoration: InputDecoration(
                        hintText: isFeatureRequest.value
                            ? '例: 観戦中に拍手を送れるスタンプ機能が欲しいです...'
                            : '例: ○○画面でボタンを押すとアプリが強制終了する...',
                        hintStyle: AppTextStyles.notoSans(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC), // slate-50
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0), // slate-200
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(
                            14.0, 12.0, 14.0, 26.0),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 12,
                      child: Text(
                        '${textLength.value} / 150',
                        style: AppTextStyles.notoSans(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // アクションボタン列
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFF1F5F9), // slate-100
                            foregroundColor:
                                const Color(0xFF334155), // slate-700
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: isSending.value
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(
                            'キャンセル',
                            style: AppTextStyles.bold(
                              fontSize: 13.5,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            elevation: hasInput && !isSending.value ? 2 : 0,
                            shadowColor:
                                Colors.blue.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed:
                              hasInput && !isSending.value ? sendBugReport : null,
                          child: isSending.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  '送信する',
                                  style: AppTextStyles.bold(
                                    fontSize: 13.5,
                                    color: hasInput && !isSending.value
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
