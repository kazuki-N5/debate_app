// ignore_for_file: file_names
import 'package:debate_project/provider/notification_settings_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// プッシュ通知の設定画面（全体マスター + カテゴリ別）
class NotificationSettingsPage extends HookConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    useEffect(() {
      notifier.load();
      return null;
    }, []);

    final settings = settingsAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('通知設定', style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      backgroundColor: Colors.blue,
      body: settings == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 全体設定
                _buildSectionTitle('全体設定'),
                _buildSwitchTile(
                  icon: Icons.notifications_active,
                  title: 'プッシュ通知（全体）',
                  subtitle: 'アプリからのプッシュ通知を受け取る',
                  value: settings.isNotificationEnabled,
                  onChanged: (v) {
                    ref
                        .read(userProvider.notifier)
                        .updateNotificationStatus(context, v);
                  },
                ),
                const SizedBox(height: 16),
                // 説明文
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'ここではプッシュ通知（OSに届く通知）のON/OFFや種類ごとの設定ができます。\n'
                    '・アプリ内通知（通知タブ）には影響しません。\n'
                    '・「プッシュ通知（全体）」がOFFの場合は、カテゴリ別設定をONにしてもプッシュ通知は届きません。',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('カテゴリ別設定'),
                _buildSwitchTile(
                  icon: Icons.favorite,
                  title: 'いいね',
                  subtitle: 'ポスト・コメントへのいいね',
                  value: settings.likeEnabled,
                  onChanged: (v) =>
                      notifier.setCategory('like_enabled', v),
                ),
                _buildSwitchTile(
                  icon: Icons.chat_bubble,
                  title: 'コメント・返信',
                  subtitle: 'ポストへのコメント、コメントへの返信',
                  value: settings.commentEnabled,
                  onChanged: (v) =>
                      notifier.setCategory('comment_enabled', v),
                ),
                _buildSwitchTile(
                  icon: Icons.person_add,
                  title: 'フォロー',
                  subtitle: 'フォローされたとき',
                  value: settings.followEnabled,
                  onChanged: (v) =>
                      notifier.setCategory('follow_enabled', v),
                ),
                _buildSwitchTile(
                  icon: Icons.mail,
                  title: 'DM',
                  subtitle: 'ダイレクトメッセージの受信',
                  value: settings.dmEnabled,
                  onChanged: (v) => notifier.setCategory('dm_enabled', v),
                ),
                _buildSwitchTile(
                  icon: Icons.groups,
                  title: 'クラブ',
                  subtitle: '参加中クラブの新着',
                  value: settings.openChatEnabled,
                  onChanged: (v) =>
                      notifier.setCategory('open_chat_enabled', v),
                ),
                _buildSwitchTile(
                  icon: Icons.sports_esports,
                  title: '対戦待ち',
                  subtitle: '対戦相手を探している人がいるお知らせ',
                  value: settings.matchWaitingEnabled,
                  onChanged: (v) =>
                      notifier.setCategory('match_waiting_enabled', v),
                ),
                _buildSwitchTile(
                  icon: Icons.sports_kabaddi,
                  title: 'レスバ応募',
                  subtitle: 'あなたが作ったレスバに応募が来たとき',
                  value: settings.resbaApplyEnabled,
                  onChanged: (v) =>
                      notifier.setCategory('resba_apply_enabled', v),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: AppTextStyles.bold(fontSize: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.blue.shade800),
        title: Text(title, style: AppTextStyles.notoSans(fontSize: 16)),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey[600]),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.blue.shade700,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      ),
    );
  }
}
