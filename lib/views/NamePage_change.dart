// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:debate_project/provider/user.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart'; // go_routerパッケージをインポート

class NamePageChange extends HookConsumerWidget {
  const NamePageChange({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final isTextTooLong = useState(false);
    final isTextEmpty = useState(true);
    final myuser = ref.watch(userProvider);

    // roomnotifierなどのプロバイダーを使用する場合は以下のようにrefから取得
    // final roomNotifier = ref.watch(roomNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '',
          style: AppTextStyles.notoSans(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '名前を入力してください',
                    style: AppTextStyles.bold(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: TextField(
                      controller: controller,
                      maxLength: 10,
                      onChanged: (text) {
                        isTextTooLong.value = text.length > 10;
                        isTextEmpty.value = text.isEmpty;
                      },
                      decoration: const InputDecoration(
                        hintText: '１０文字以内',
                        border: InputBorder.none,
                        counterText: '',
                        errorStyle: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: AppTextStyles.notoSans(fontSize: 18),
                    ),
                  ),
                  if (isTextTooLong.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, left: 45),
                    ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: isTextEmpty.value || isTextTooLong.value
                        ? null
                        : () {
                            print(controller.text);
                            FocusScope.of(context).unfocus();
                            ref
                                .read(userProvider.notifier)
                                .updateName(myuser, controller.text);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '変更',
                      style: AppTextStyles.bold(
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }
}
