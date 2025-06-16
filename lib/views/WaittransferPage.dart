// debate_project/pages/wait_transfer_page.dart
import 'package:debate_project/modes/transfer_model.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:debate_project/provider/user.dart'; // userProvider と SharedPrefKeys をインポート
import 'package:debate_project/router/router.dart';// router をインポート

class WaittransferPage extends HookConsumerWidget {
  const WaittransferPage({Key? key}) : super(key: key);

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
      return null; // クリーンアップは不要
    }, []); // 初回ビルド時のみ実行

    Future<void> cancelTransfer() async {
  // final userNotifier = ref.read(userProvider.notifier); // Riverpodの場合
  // ダミーのuserNotifierインスタンス (実際のプロジェクトでは上記のように取得)
   final userNotifier = ref.read(userProvider.notifier);

  if (id == null) {
    print('Error: User ID is null. Cannot proceed with cancellation.');
    // 必要であればユーザーにエラーを通知
    return;
  }

  try {
    // Supabase RPC呼び出し (userNotifier.cancelTransferが内部で最初のDart関数を呼ぶ想定)
    await userNotifier.cancelTransfer(id);
    print('Supabase cancelTransfer successful.');

    // Supabase呼び出しが成功した場合のみ、以下の処理を実行
    await userNotifier.clearTransferCredentials(); // SharedPreferences から削除

    // SharedPreferencesから読み直して確認（clearTransferCredentialsが正しく動作したか）
    final prefs = await SharedPreferences.getInstance();
    canceltransferId.value = prefs.getString(SharedPrefKeys.transferId);
    canseltransferPassword.value = prefs.getString(SharedPrefKeys.transferPassword); // タイプミス修正: cansel -> cancel

    if (canceltransferId.value == null && canseltransferPassword.value == null) {
      
       router.go('/');
    } else {
      print('Warning: Credentials were not fully cleared from SharedPreferences.');
      // このケースは通常発生しないはずだが、念のためログを出す
    }
  } catch (e) {
    print('Error during cancelTransfer RPC call: $e');;
    return;
  }
}

    return Scaffold(
      backgroundColor: Colors.blue.shade700, // 背景を青色に
      appBar: AppBar(
        title: const Text('引き継ぎ情報', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        automaticallyImplyLeading: false, // AppBarの戻るボタンは非表示
      ),
      body: Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      '以下のIDとパスワードを\n新しい端末で入力してください。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18, color: Colors.white, height: 1.5),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '引き継ぎID:',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            transferId.value ?? 'エラー: IDなし',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 2.0, // IDを見やすくするため文字間隔を調整
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 25),
                          const Text(
                            'パスワード:',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            transferPassword.value ?? 'エラー: パスワードなし',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 2.0, // パスワードを見やすくするため文字間隔を調整
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      '注意: この情報は一度きり有効です。新しい端末で引き継ぎを完了すると、このIDとパスワードは無効になります。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: ElevatedButton(
          onPressed: cancelTransfer,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          child: const Text('キャンセルして戻る', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
