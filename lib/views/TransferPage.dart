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
            backgroundColor: Colors.blue, // 少し濃いめの青
            appBar: AppBar(
              title:
                  Text('引き継ぎ',
            style: AppTextStyles.bold(color: Colors.white)),
              backgroundColor: Colors.blue,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              automaticallyImplyLeading: false,
            ),
            body: Stack(
              children: [
                Center(
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
                          description: '''
 IdとPasswordを発行します。
 引き継ぎする機種で下の入力ボタンを押して実行してください。
 引き継ぎが完了するとこのデータは初期化されます。
 引き継ぎ中はゲームをプレイできません
 ''',
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
                                return; // finallyブロックが実行されるので isLoading.value = false は不要
                              }

                              final transferDetails =
                                  await usernotifier.initiateTransfer(userid);

                              if (transferDetails != null &&
                                  transferDetails['transfer_id'] != null &&
                                  transferDetails['transfer_password'] !=
                                      null) {
                                await usernotifier.saveTransferCredentials(
                                  transferDetails['transfer_id']!,
                                  transferDetails['transfer_password']!,
                                );
                                if (context.mounted) {
                                  router.go('/waittransfer');
                                }
                              } else {
                                // initiateTransfer が null を返した場合 (成功も失敗もせず、単にnullを返した場合)
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            '引き継ぎ情報の生成に失敗しました。再度お試しください。')),
                                  );
                                }
                              }
                            } catch (e) {
                              // エラーハンドリング
                              if (context.mounted) {
                               
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('データ送信に失敗しました。')),
                                );
                              }
                              print(
                                  'Error during data transfer initiation: $e');
                            } finally {
                              // 成功時、失敗時（catch）、早期リターン（userid == null）のいずれの場合も実行
                              isLoading.value = false;
                            }
                          },
                          showInputFields: false,
                          isButtonEnabled: true, // 送信ボタンは常に有効
                        ),
                        const SizedBox(height: 30),

                        // 下のデータ取得セクション
                        _buildTransferSection(
                          context: context,
                          title: 'データ取得',
                          description: '''
 発行されたidとpasswordを入力してください。
 現在のデータではプレイできなくなり、引き継ぎされた側の機種は初期化されます。
 ''',
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
                              final result =
                                  await usernotifier.completeTransfer(
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
                                  const SnackBar(
                                      content:
                                          Text('エラーが発生しました')),
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
                          isButtonEnabled: isDataAcquisitionButtonEnabled
                              .value, // 計算された有効状態を渡す
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  left: 10,
                  bottom: 20,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    iconSize: 28.0,
                    color: Colors.black,
                    tooltip: '戻る',
                    onPressed: () => router.pop(),
                    padding: const EdgeInsets.all(12.0),
                    splashRadius: 24.0,
                  ),
                ),
                // ★ ローディング表示をbodyのStackから削除
              ],
            ),
          ),
        ),
        // ★ ローディング表示 (Scaffold全体を覆うようにStackの最前面に配置)
        if (isLoading.value)
          Container(
            // ★ 薄い白で画面全体を覆う
            color: Colors.white.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(), // くるくるマーク
            ),
          ),
      ],
    );
  }

  // 各引き継ぎセクションの共通UIを生成するヘルパーメソッド
  Widget _buildTransferSection({
    required BuildContext context,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onButtonPressed,
    required bool showInputFields,
    TextEditingController? idTextController,
    TextEditingController? passwordTextController,
    bool isButtonEnabled = true, // ボタンの有効/無効状態を制御するフラグ
  }) {
    return Container(
      padding: const EdgeInsets.all(25.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.bold(
              fontSize: 20.0,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            description,
            style: AppTextStyles.notoSans(
              fontSize: 14.0,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          if (showInputFields) ...[
            TextField(
              controller: idTextController,
              decoration: InputDecoration(
                hintText: 'Id',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15.0, vertical: 18.0),
                counterText: '',
              ),
              keyboardType: TextInputType.text,
              maxLength: 6,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordTextController,
              decoration: InputDecoration(
                hintText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15.0,
                  vertical: 18.0,
                ),
                counterText: '',
              ),
              keyboardType: TextInputType.visiblePassword,
              maxLength: 6,
            ),
            const SizedBox(height: 25),
          ],
          Center(
            child: ElevatedButton(
              onPressed: isButtonEnabled
                  ? onButtonPressed
                  : null, // 有効状態に基づいてonPressedを設定
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 50.0, vertical: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                elevation: 5,
                disabledForegroundColor:
                    Colors.white.withValues(alpha: 0.7), // 無効時のテキスト色
                disabledBackgroundColor:
                    Colors.blueAccent.withValues(alpha: 0.5), // 無効時の背景色
              ),
              child: Text(
                buttonText,
                style: AppTextStyles.bold(
                    fontSize: 17.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
