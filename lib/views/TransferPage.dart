// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart'; // flutter_hooksをインポート
import 'package:hooks_riverpod/hooks_riverpod.dart';// hooks_riverpodをインポート

// HookConsumerWidgetに変更
class TransferPage extends HookConsumerWidget {
  const TransferPage({super.key});

  // ユーザーが後で実装するためのプレースホルダーメソッド

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // データ取得セクション用のTextEditingControllerをフックで作成
    final idController = useTextEditingController();
    final passwordController = useTextEditingController();

    // データ取得ボタンの有効状態を管理するState
    final isDataAcquisitionButtonEnabled = useState(false);

    // データ送信中のローディング状態を管理するState
    final isLoading = useState(false);
    final usernotifier = ref.read(userProvider.notifier);

    final userid = ref.read(currentUserIdProvider);

    // idControllerとpasswordControllerのテキスト変更を監視してボタンの有効状態を更新
    useEffect(() {
      void updateButtonState() {
        isDataAcquisitionButtonEnabled.value = idController.text.length == 6 &&
            passwordController.text.length == 6;
      }

      idController.addListener(updateButtonState);
      passwordController.addListener(updateButtonState);

      // 初期状態も評価
      updateButtonState();

      return () {
        idController.removeListener(updateButtonState);
        passwordController.removeListener(updateButtonState);
      };
    }, [idController, passwordController]); // 依存配列にコントローラーを含める

    // ★ Scaffold全体をStackでラップし、ローディング表示を最前面に
    return Stack(
      children: [
        GestureDetector(
          // キーボード以外の場所をタップしたときにフォーカスを外す（キーボードを閉じる）
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Scaffold(
            backgroundColor: Colors.blue,
            appBar: AppBar(
              title: Text(
                '引き継ぎ',
                style: AppTextStyles.bold(color: Colors.white, fontSize: 20),
              ),
              backgroundColor: Colors.blue,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => router.pop(),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 上のデータ送信セクション
                    _buildTransferSection(
                      context: context,
                      title: 'データ送信',
                      description:
                          'IdとPasswordを発行します。\n引き継ぎする機種で下の入力ボタンを押して実行してください。\n引き継ぎが完了するとこのデータは初期化されます。\n引き継ぎ中はゲームをプレイできません。',
                      buttonText: '実行',
                      onButtonPressed: () async {
                        isLoading.value = true;
                        try {
                          if (userid == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'ユーザーIDが取得できません。ログイン状態を確認してください。')),
                              );
                            }
                            return;
                          }

                          final transferDetails =
                              await usernotifier.initiateTransfer(userid);

                          if (transferDetails != null &&
                              transferDetails['transfer_id'] != null &&
                              transferDetails['transfer_password'] != null) {
                            await usernotifier.saveTransferCredentials(
                              transferDetails['transfer_id']!,
                              transferDetails['transfer_password']!,
                            );
                            if (context.mounted) {
                              router.go('/waittransfer');
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        '引き継ぎ情報の生成に失敗しました。再度お試しください。')),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('データ送信に失敗しました。')),
                            );
                          }
                          print('Error during data transfer initiation: $e');
                        } finally {
                          isLoading.value = false;
                        }
                      },
                      showInputFields: false,
                      isButtonEnabled: true,
                    ),
                    const SizedBox(height: 20),

                    // 下のデータ取得セクション
                    _buildTransferSection(
                      context: context,
                      title: 'データ取得',
                      description:
                          '発行されたidとpasswordを入力してください。\n現在のデータではプレイできなくなり、引き継ぎされた側の機種は初期化されます。',
                      buttonText: '入力',
                      onButtonPressed: () async {
                        final id = idController.text;
                        final password = passwordController.text;

                        isLoading.value = true;
                        if (userid == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'ユーザーIDが取得できません。ログイン状態を確認してください。')),
                          );
                          isLoading.value = false;
                          return;
                        }

                        try {
                          final result = await usernotifier.completeTransfer(
                              transferId: id,
                              password: password,
                              receiverId: userid);
                          if (result != null &&
                              result.startsWith(
                                  "Data transfer completed successfully.")) {
                            router.go('/');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('エラーが発生しました')),
                            );
                          }
                          isLoading.value = false;
                        } finally {
                          isLoading.value = false;
                        }
                      },
                      showInputFields: true,
                      idTextController: idController,
                      passwordTextController: passwordController,
                      isButtonEnabled: isDataAcquisitionButtonEnabled.value,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ローディング表示
        if (isLoading.value)
          Container(
            color: Colors.white.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  // 各引き継ぎセクションの共通UIを生成するヘルパーメソッド (フラット・影なし)
  Widget _buildTransferSection({
    required BuildContext context,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onButtonPressed,
    required bool showInputFields,
    TextEditingController? idTextController,
    TextEditingController? passwordTextController,
    bool isButtonEnabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.bold(
              fontSize: 18.0,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: AppTextStyles.notoSans(
              fontSize: 13.0,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (showInputFields) ...[
            TextField(
              controller: idTextController,
              decoration: InputDecoration(
                hintText: 'Id (6文字)',
                hintStyle: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                counterText: '',
              ),
              keyboardType: TextInputType.text,
              maxLength: 6,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordTextController,
              decoration: InputDecoration(
                hintText: 'Password (6文字)',
                hintStyle: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                counterText: '',
              ),
              keyboardType: TextInputType.visiblePassword,
              maxLength: 6,
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isButtonEnabled ? onButtonPressed : null,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                disabledBackgroundColor: Colors.blue.withValues(alpha: 0.4),
              ),
              child: Text(
                buttonText,
                style: AppTextStyles.bold(fontSize: 16.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
