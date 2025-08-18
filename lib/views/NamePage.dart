import 'package:debate_project/provider/user.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class NamePage extends HookConsumerWidget {
  const NamePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final isTextTooLong = useState(false);
    final isTextEmpty = useState(true);
    final myuser = ref.watch(userProvider);

    // 利用規約のテキスト
    const String termsOfServiceText = '''
第1条（適用

本規約は、当アプリ開発チーム（以下「当事業者」といいます。）が提供するスマートフォン向けアプリケーション「レスバディベートオンライン」（以下「本サービス」といいます。）の利用に関する条件を、本サービスを利用するお客様（以下「ユーザー」といいます。）と当事業者との間で定めるものです。

第2条（本サービスの内容）

本サービスは、ユーザーにディベートをテーマとしたゲーム機能を提供するものです。

第3条（知的財産権）

本サービスに関する著作権その他一切の知的財産権は、当事業者または当事業者にライセンスを許諾している第三者に帰属します。当事業者は、本規約に定める利用条件に従って本サービスを利用する権利をユーザーに許諾しますが、これは将来にわたって保証されるものではありません。

第4条（料金及び支払い）

1. 本サービスの利用は基本無料ですが、一部の機能は有料のサブスクリプション（月額課金等）に登録することで利用可能となります。
2. サブスクリプション料金の支払いは、Apple App StoreまたはGoogle Play Storeなど、利用するプラットフォームの決済手段を通じて行われます。
3. 支払われた利用料金について、当事業者は法令に定めがある場合を除き、いかなる理由があっても返金いたしません。サブスクリプションの解約は、各プラットフォームの定める手順に従ってユーザー自身が行う必要があります。
4. 本サービスには、第三者配信事業者による広告が表示されます。

第5条（禁止事項）

ユーザーは、本サービスの利用にあたり、以下の各号のいずれかに該当する行為または該当すると当事業者が判断する行為をしてはなりません。

1. 法令に違反する行為または犯罪行為に関連する行為
2. 公序良俗に反する行為
3. 当事業者、他のユーザーまたはその他の第三者に対する誹謗中傷行為
4. 当事業者、他のユーザーまたはその他の第三者の知的財産権、肖像権、プライバシーの権利、名誉、その他の権利または利益を侵害する行為
5. 本サービスのネットワークまたはシステム等に過度な負荷をかける行為
6. 本サービスの運営を妨害するおそれのある行為
7. 本サービスのソフトウェアの逆アセンブル、逆コンパイル、リバースエンジニアリング、その他本サービスのソースコードを解析する行為
8. その他、当事業者が不適切と判断する行為

第6条（利用停止等）

当事業者は、ユーザーが前条の禁止事項に違反したと判断した場合、事前の通知をすることなく、当該ユーザーの本サービスの全部または一部の利用を停止することができるものとします。当事業者は、本条に基づき当事業者が行った措置によりユーザーに生じた損害について一切の責任を負いません。

第7条（免責事項）

1. 当事業者は、サーバーダウン、通信回線の障害、天災、バグの発生、その他当事業者の責によらない事由により生じたユーザーの損害について、一切の責任を負わないものとします。
2. 本サービス内におけるユーザー間のトラブルについて、当事業者は一切関与せず、責任を負わないものとします。
3. 本サービスに表示される第三者配信の広告内容の正確性、適法性等について、当事業者は一切の保証をせず、責任を負わないものとします。
4. 当事業者は、本サービスが全ての端末において正常に動作することを保証するものではありません。

第8条（本サービスの変更・中断・終了）

当事業者は、事業者の都合により、本サービスの内容を変更し、または提供を中断・終了することができます。本サービスの提供を終了する場合、当事業者は事前にユーザーに通知するよう努めるものとしますが、緊急の場合はこの限りではありません。

第9条（本規約の変更）

当事業者は、必要と判断した場合には、ユーザーに通知することなくいつでも本規約を変更することができるものとします。変更後の利用規約は、本サービス内または当事業者が運営するウェブサイト内の適宜の場所に掲示された時点からその効力を生じるものとします。

第10条（準拠法及び管轄裁判所）

1. 本規約の準拠法は日本法とします。
2. 本規約または本サービスに起因し、または関連する一切の紛争については、【東京地方裁判所】を第一審の専属的合意管轄裁判所とします。

第11条（お問い合わせ）

本サービスに関するお問い合わせは、下記の連絡先までお願いいたします。

- 連絡先： kgg5app@gmail.com

附則

2025年7月10日 制定
''';

    // タップイベントを管理するためのGestureRecognizer
    final tapGestureRecognizer = useMemoized(() => TapGestureRecognizer()
      ..onTap = () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true, // 高さを画面の9割に指定
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext context) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8, // 初期表示の高さ
              maxChildSize: 0.9,       // 最大の高さ
              minChildSize: 0.3,       // 最小の高さ
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Container(
                  color: Colors.blue,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          // ListView自体にパディングを設定
                          padding: const EdgeInsets.all(20.0),
                          children: const [
                            // タイトル用のTextウィジェット
                            Text(
                              '利用規約',
                              style: TextStyle(
                                fontSize: 24, // フォントサイズを大きく
                                fontWeight: FontWeight.bold, // 太字に
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 24), // タイトルと本文の間のスペース
                            // 本文用のTextウィジェット
                            Text(
                              termsOfServiceText,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      });

    // メモリリークを防ぐために Hook のライフサイクルで recognizer を dispose する
    useEffect(() {
      return () => tapGestureRecognizer.dispose();
    }, [tapGestureRecognizer]);


    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: const Text(
          '',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '名前を入力してください',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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
                  decoration: InputDecoration(
                    hintText: '１０文字以内',
                    border: InputBorder.none,
                    counterText: '',
                    errorStyle: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: const TextStyle(fontSize: 18),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '決定',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // --- ここから追加 ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    children: [
                      const TextSpan(text: '決定ボタンを押すことで'),
                      TextSpan(
                        text: '利用規約',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: tapGestureRecognizer,
                      ),
                      const TextSpan(text: 'に同意したものとみなします。'),
                    ],
                  ),
                ),
              ),
              // --- ここまで追加 ---
            ],
          ),
        ),
      ),
    );
  }
}