// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/modes/transfer_model.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/router/router.dart';

class WaittransferPage extends HookConsumerWidget {
  const WaittransferPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferId = useState<String?>(null);
    final transferPassword = useState<String?>(null);
    final canceltransferId = useState<String?>(null);
    final canseltransferPassword = useState<String?>(null);
    final id = ref.read(currentUserIdProvider);

    useEffect(() {
      Future<void> loadCredentials() async {
        final prefs = await SharedPreferences.getInstance();
        transferId.value = prefs.getString(SharedPrefKeys.transferId);
        transferPassword.value =
            prefs.getString(SharedPrefKeys.transferPassword);
      }

      loadCredentials();
      return null;
    }, []);

    void copyToClipboard(String text, String label) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$labelをコピーしました'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    void copyBoth() {
      final tId = transferId.value ?? '';
      final tPw = transferPassword.value ?? '';
      final text = '引き継ぎID: $tId\nパスワード: $tPw';
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IDとパスワードをまとめてコピーしました'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    Future<void> cancelTransfer() async {
      final userNotifier = ref.read(userProvider.notifier);

      if (id == null) {
        print('Error: User ID is null. Cannot proceed with cancellation.');
        return;
      }

      try {
        await userNotifier.cancelTransfer(id);
        print('Supabase cancelTransfer successful.');

        await userNotifier.clearTransferCredentials();

        final prefs = await SharedPreferences.getInstance();
        canceltransferId.value = prefs.getString(SharedPrefKeys.transferId);
        canseltransferPassword.value =
            prefs.getString(SharedPrefKeys.transferPassword);

        if (canceltransferId.value == null &&
            canseltransferPassword.value == null) {
          router.go('/');
        }
      } catch (e) {
        print('Error during cancelTransfer RPC call: $e');
        return;
      }
    }

    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: Text('引き継ぎ情報',
            style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.blue,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '以下のIDとパスワードを\n新しい端末で入力してください。',
                textAlign: TextAlign.center,
                style: AppTextStyles.notoSans(
                    fontSize: 16, color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: 24),
              // 白いフラットカード
              Container(
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 引き継ぎID行
                    Text(
                      '引き継ぎID:',
                      style: AppTextStyles.notoSans(
                          fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              transferId.value ?? '--------',
                              style: AppTextStyles.bold(
                                fontSize: 22,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (transferId.value != null)
                            InkWell(
                              onTap: () => copyToClipboard(
                                  transferId.value!, '引き継ぎID'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy,
                                        size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      'コピー',
                                      style: AppTextStyles.bold(
                                          fontSize: 12, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // パスワード行
                    Text(
                      'パスワード:',
                      style: AppTextStyles.notoSans(
                          fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              transferPassword.value ?? '--------',
                              style: AppTextStyles.bold(
                                fontSize: 22,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (transferPassword.value != null)
                            InkWell(
                              onTap: () => copyToClipboard(
                                  transferPassword.value!, 'パスワード'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy,
                                        size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      'コピー',
                                      style: AppTextStyles.bold(
                                          fontSize: 12, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // IDとパスワードを両方コピーボタン
                    if (transferId.value != null &&
                        transferPassword.value != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: copyBoth,
                          icon: const Icon(Icons.copy_all, size: 16),
                          label: const Text('IDとパスワードを両方コピー'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            textStyle: AppTextStyles.bold(fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '注意: この情報は一度きり有効です。新しい端末で引き継ぎを完了すると、このIDとパスワードは無効になります。',
                textAlign: TextAlign.center,
                style: AppTextStyles.notoSans(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.85), height: 1.5),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: cancelTransfer,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Text('キャンセルして戻る',
                style: AppTextStyles.bold(fontSize: 16, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
