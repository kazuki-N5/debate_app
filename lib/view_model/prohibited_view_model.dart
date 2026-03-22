import 'package:debate_project/modes/chat.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

class MessageBubble extends HookConsumerWidget {
  // ConsumerWidgetに変更
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
  Widget build(BuildContext context, WidgetRef ref) {
    // 各メッセージごとに固有のアンカー用キーを生成
    final anchorKey = useMemoized(() => GlobalKey(), [chat.id]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: isUserMessage
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!isUserMessage) ...[
                  SizedBox(
                    height: double.infinity,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: showAvatar
                          ? _buildAvatar()
                          : const SizedBox(width: 32),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isUserMessage) _buildStatus(),
                const SizedBox(width: 4),
                _buildMessageBubble(context, ref, anchorKey),
                const SizedBox(width: 4),
                if (!isUserMessage) _buildStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[300],
      backgroundImage:
          opponentAvatarUrl != null && opponentAvatarUrl!.isNotEmpty
              ? NetworkImage(opponentAvatarUrl!)
              : null,
      child: (opponentAvatarUrl == null || opponentAvatarUrl!.isEmpty)
          ? const Icon(Icons.person, color: Colors.white, size: 20)
          : null,
    );
  }

  Widget _buildStatus() {
    if (!isUserMessage) return const SizedBox.shrink();

    String? statusText;
    Color statusColor = Colors.black54;

    if (chat.id.startsWith('temp_')) {
      // 送信中 → 何も表示しない
      statusText = null;
    } else if (chat.id.startsWith('error_')) {
      // 送信失敗
      statusText = '✕';
      statusColor = Colors.black54;
    } else {
      // sent_ または 正規UUID → 送信完了
      statusText = '送信';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (statusText != null)
          Text(
            statusText,
            style: AppTextStyles.notoSans(fontSize: 9, color: statusColor),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildMessageBubble(BuildContext context, WidgetRef ref, GlobalKey anchorKey) {
    return Flexible(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onLongPress: () {
              // バブル本体のコンテキストではなく、内側に配置したアンカーのコンテキストを使用
              final anchorContext = anchorKey.currentContext;
              if (anchorContext == null) return;
              
              showCustomPopover(
                context: anchorContext,
                height: 90,
                arrowDxOffset: 0, // アンカー位置で調整するためオフセットは0
                children: [
                  PopoverButton(
                    text: '通報',
                    onTap: () async {
                      final prohibitedService =
                          ref.read(prohibitedServiceProvider);
                      await prohibitedService.sendProhibited(
                        context: context,
                        opponentId: chat.senderId,
                        roomId: roomId,
                        chatId: chat.id,
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 4),
                  PopoverButton(
                    text: '非表示',
                    onTap: () {
                      onHide();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              decoration: BoxDecoration(
                color: isUserMessage ? const Color(0xff95eb7c) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                chat.content,
                style: AppTextStyles.notoSans(
                  color: Colors.black,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          // ポップオーバーを表示するための透明なアンカーポイント
          // 端から28pxの位置に配置することで、メニューが画面端に張り付くのを防ぎ「ゆとり」を持たせる
          Positioned(
            bottom: 0,
            left: isUserMessage ? null : 50,
            right: isUserMessage ? 50 : null,
            child: SizedBox(key: anchorKey, width: 1, height: 1),
          ),
          Positioned(
            top: 6,
            left: isUserMessage ? null : -6,
            right: isUserMessage ? -6 : null,
            child: CustomPaint(
              painter: _BubbleTailPainter(
                isUserMessage ? const Color(0xff95eb7c) : Colors.white,
                isUserMessage,
              ),
              size: const Size(10, 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isUserMessage;

  _BubbleTailPainter(this.color, this.isUserMessage);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isUserMessage) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height * 0.8);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(size.width, size.height * 0.8);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void showCustomPopover({
  required BuildContext context,
  required List<Widget> children,
  required double height,
  double arrowDxOffset = 0,
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
    width: 80,
    height: height,
    arrowHeight: 0,
    arrowWidth: 0,
    arrowDxOffset: arrowDxOffset,
    shadow: const [], // 影をなくす
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
              style: AppTextStyles.notoSans(
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
