import 'package:debate_project/modes/chat.dart';
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:popover/popover.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:debate_project/widgets/chat/chat_message_bubble.dart';
import 'package:debate_project/utils/date_formatter.dart';

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
    String? contentId,
    String? contentType,
    String? reason,
    String? contentSnapshot,
  }) async {
    try {
      await _supabase.from('prohibited').insert({
        'user_id': opponentId, // 引数名を修正
        'room_id': roomId,
        'chat_id': chatId, // 引数名を修正
        'reporter_id': _supabase.auth.currentUser?.id,
        'content_id': contentId,
        'content_type': contentType,
        'reason': reason,
        'content_snapshot': contentSnapshot,
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
  final Chat chat;
  final bool isUserMessage;
  final String? opponentAvatarUrl;
  final String? opponentName;
  final String? myAvatarUrl;
  final String? myName;
  final bool showAvatar;
  final String? roomId;
  final VoidCallback onHide;
  final VoidCallback? onBlock;
  final VoidCallback? onReply;
  final VoidCallback? onTapReplyQuote;
  final bool isHighlighted;

  const MessageBubble({
    super.key,
    required this.chat,
    required this.isUserMessage,
    required this.opponentAvatarUrl,
    this.opponentName,
    this.myAvatarUrl,
    this.myName,
    required this.showAvatar,
    this.roomId,
    required this.onHide,
    this.onBlock,
    this.onReply,
    this.onTapReplyQuote,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChatMessageBubble(
      id: chat.id,
      content: chat.content,
      imageUrl: chat.imageUrl,
      isUserMessage: isUserMessage,
      senderId: chat.senderId,
      senderName: isUserMessage ? myName : opponentName,
      senderAvatarUrl: isUserMessage ? myAvatarUrl : opponentAvatarUrl,
      showAvatar: showAvatar,
      showSenderName:
          !isUserMessage && (opponentName != null && opponentName!.isNotEmpty),
      replyToId: chat.replyToId,
      replyToContent: chat.replyToContent,
      replyToUserName: chat.replyToUserName,
      onReply: onReply,
      onTapReplyQuote: onTapReplyQuote,
      isHighlighted: isHighlighted,
      statusWidget: _buildStatus(),
      timeLabel: DateFormatter.formatChatTime(chat.createdAt),
      onHide: onHide,
      onReport: () async {
        final prohibitedService = ref.read(prohibitedServiceProvider);
        await prohibitedService.sendProhibited(
          context: context,
          opponentId: chat.senderId,
          roomId: roomId,
          chatId: chat.id,
          contentId: chat.id,
          contentType: 'message',
          contentSnapshot: chat.content,
        );
      },
    );
  }

  Widget? _buildStatus() {
    if (!isUserMessage) return null;

    String statusText;
    Color statusColor = Colors.black54;

    if (chat.id.startsWith('temp_')) {
      statusText = '送信中';
    } else if (chat.id.startsWith('error_')) {
      statusText = '✕';
    } else {
      statusText = '送信';
    }

    return Text(
      statusText,
      style: AppTextStyles.notoSans(fontSize: 9, color: statusColor),
    );
  }
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

  const PopoverButton({super.key, required this.text, required this.onTap});

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
