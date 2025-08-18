import 'package:debate_project/modes/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popover/popover.dart';
import 'package:riverpod/riverpod.dart'; // Riverpodのimportを追加
import 'package:supabase_flutter/supabase_flutter.dart'; // SupabaseClientの型のためにimportを追加

// プロジェクトのパスに合わせて調整してください
import 'package:debate_project/provider/supabase_provider.dart';

// 1. ProhibitedServiceのインスタンスを提供するRiverpod Providerを定義
//    ref.watchを使ってsupabaseProviderからSupabaseClientを取得し、
//    それをProhibitedServiceのコンストラクタに渡します。
final prohibitedServiceProvider = Provider((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ProhibitedService(supabase: supabase);
});

// 2. ProhibitedServiceクラスの定義 (クラス名をPascalCaseに変更)
class ProhibitedService {
  // SupabaseClientをプライベートなfinalフィールドとして保持
  final SupabaseClient _supabase;

  // コンストラクタでSupabaseClientを受け取る
  ProhibitedService({required SupabaseClient supabase}) : _supabase = supabase;

  // 3. ユーザーを報告するメソッド (メソッド名をcamelCaseに変更し、BuildContextを引数に追加)
  //    opponentIdとroomIdは必須とするため、required Stringに変更
  Future<void> sendProhibited({
    required BuildContext context, // UI操作のためにBuildContextを必須引数として追加
    String? opponentId,
    String? roomId,
    String? chatId,
  }) async {
    try {
      await _supabase.from('prohibited').insert({
        'user_id': opponentId, // 引数名を修正
        'room_id': roomId,
        'chat_id': chatId, // 引数名を修正
      });

      // 成功した場合の処理
      // 非同期処理をまたぐため、contextがまだ有効かチェックするのが安全です
      if (!context.mounted) return;

      // 元のコメントにあった「ポップオーバーを閉じる」処理は、
      // このサービス層ではなく、このメソッドを呼び出すUI層（ウィジェット）で実行すべきです。
      // 例: Navigator.of(context).pop();

      // 成功したことを知らせるスナックバーを表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('通報しました。'), // 成功を示す色
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // エラーが発生したことを知らせるスナックバーを表示
      // ここでもcontextが有効かチェック
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        // contextを正しく指定
        const SnackBar(
          content: Text('通報に失敗しました。'),
          duration: Duration(seconds: 2),
        ),
      );

      // デバッグ用にエラー内容をコンソールに出力
      debugPrint('Supabaseへの挿入エラー: $e');
    }
  }

  

  /// ポップオーバー内で使用する共通のボタンウィジェット
}

class MessageBubble extends ConsumerWidget { // ConsumerWidgetに変更
  final Chat chat;
  final bool isUserMessage;
  final String? opponentAvatarUrl;
  final String? myAvatarUrl;
  final bool showAvatar;
  final String? roomId; // ★★★ 追加: roomId を受け取るように変更 ★★★
  final VoidCallback onHide; // 親ウィジェットから非表示処理を受け取るコールバック


  const MessageBubble({
    Key? key,
    required this.chat,
    required this.isUserMessage,
    required this.opponentAvatarUrl,
    this.myAvatarUrl,
    required this.showAvatar,
    this.roomId, // ★★★ 追加: roomId をコンストラクタに追加 ★★★
    required this.onHide,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) { // ★★★ WidgetRef ref を追加 ★★★
    double size = 15;
    double avatarDiameter = size * 2;

    Widget avatarWidget;
    if (showAvatar) {
      if (isUserMessage) {
        avatarWidget = CircleAvatar(
          radius: size,
          backgroundImage: myAvatarUrl != null && myAvatarUrl!.isNotEmpty
              ? NetworkImage(myAvatarUrl!) as ImageProvider<Object>?
              : null,
          child: (myAvatarUrl == null || myAvatarUrl!.isEmpty)
              ? Icon(Icons.person, color: Colors.grey, size: size)
              : null,
          backgroundColor: Colors.grey[200],
        );
      } else {
        avatarWidget = CircleAvatar(
          radius: size,
          backgroundImage:
              opponentAvatarUrl != null && opponentAvatarUrl!.isNotEmpty
                  ? NetworkImage(opponentAvatarUrl!) as ImageProvider<Object>?
                  : null,
          child: (opponentAvatarUrl == null || opponentAvatarUrl!.isEmpty)
              ? Icon(Icons.person, color: Colors.grey, size: size)
              : null,
          backgroundColor: Colors.grey[200],
        );
      }
    } else {
      avatarWidget = SizedBox(width: avatarDiameter);
    }

    Widget messageContent = Flexible(
      child: Column(
        crossAxisAlignment:
            isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (BuildContext popoverContext) {
              return GestureDetector(
                onLongPress: () {
                  showCustomPopover(
                    context: popoverContext,
                    height: 90,
                    children: [
                      PopoverButton(
                        text: '通報',
                        onTap: () async { // ★★★ async を追加 ★★★
                          // Riverpodを通じてProhibitedServiceのインスタンスを取得
                          final prohibitedService = ref.read(prohibitedServiceProvider);

                          // sendProhibitedメソッドを呼び出す
                          // 報告対象はメッセージの送信者なので chat.senderId を渡す
                          // （自分が送ったメッセージを報告することはないという前提）
                          await prohibitedService.sendProhibited(
                            context: popoverContext, // ポップオーバーのコンテキストを使用
                            opponentId: chat.senderId, // このメッセージの送信者を報告
                            roomId: roomId,
                            chatId: chat.id,
                          );

                          // ポップオーバーを閉じる
                          Navigator.of(popoverContext).pop();
                          // ★★★ ここでのprintは不要になります。サービス内でSnackBarが表示されます。 ★★★
                        },
                      ),
                      const SizedBox(height: 4),
                      PopoverButton(
                        text: '非表示',
                        onTap: () {
                          // 親から渡されたonHideコールバックを呼び出す
                          onHide();
                          // ポップオーバーを閉じる
                          Navigator.of(popoverContext).pop();
                          print('「${chat.content}」が非表示にされました。');
                        },
                      ),
                    ],
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isUserMessage ? Colors.green : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    chat.content,
                    style: TextStyle(
                      color: isUserMessage ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: isUserMessage ? 64 : 8,
        right: isUserMessage ? 8 : 64,
        top: showAvatar ? 4 : 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isUserMessage
            ? [
                messageContent,
                const SizedBox(width: 8),
                Transform.translate(
                  offset: const Offset(0, 5),
                  child: avatarWidget,
                ),
              ]
            : [
                Transform.translate(
                  offset: const Offset(0, 5),
                  child: avatarWidget,
                ),
                const SizedBox(width: 8),
                messageContent,
              ],
      ),
    );
  }
}

void showCustomPopover({
  required BuildContext context,
  required List<Widget> children,
  required double height,
}) {
  showPopover(
    context: context,
    bodyBuilder: (context) => Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    ),
    direction: PopoverDirection.bottom,
    backgroundColor: Colors.white,
    barrierColor: Colors.transparent,
    width: 100,
    height: height,
    arrowHeight: 10,
    arrowWidth: 20,
    transitionDuration: const Duration(milliseconds: 150),
  );
}

class PopoverButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const PopoverButton({
    Key? key,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
