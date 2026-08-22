// ignore_for_file: file_names, use_build_context_synchronously
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/view_model/prohibited_view_model.dart';
import 'package:debate_project/widgets/app_confirm_dialog.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通報理由の選択肢
const List<String> kReportReasons = [
  'スパム・宣伝',
  '暴言・誹謗中傷',
  '不適切な内容',
  '個人情報の掲載',
  'なりすまし',
  'その他',
];

/// 通報ダイアログ(理由選択 → 通報テーブルに登録)
Future<void> showReportDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String? opponentId,
  String? roomId,
  String? contentId,
  String? contentType,
  String? contentSnapshot,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '通報する理由を選択',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          ...kReportReasons.map(
            (r) => ListTile(
              title: Text(r, style: AppTextStyles.notoSans(fontSize: 14)),
              onTap: () => Navigator.pop(context, r),
            ),
          ),
        ],
      ),
    ),
  );

  if (reason == null || !context.mounted) return;

  final service = ref.read(prohibitedServiceProvider);
  await service.sendProhibited(
    context: context,
    opponentId: opponentId,
    roomId: roomId,
    contentId: contentId,
    contentType: contentType,
    reason: reason,
    contentSnapshot: contentSnapshot,
  );
}

/// ユーザーをブロックする確認ダイアログ
/// 成功時は [onBlocked] を呼ぶ(表示フィルタの再適用などに使用)
Future<void> showBlockUserDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String targetUserId,
  required String targetName,
  VoidCallback? onBlocked,
}) async {
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'ユーザーをブロック',
    message: '$targetNameさんをブロックしますか？\n'
        'ブロックすると、このユーザーの投稿・メッセージが表示されなくなり、'
        'DM・対戦申し込みもできなくなります。\n'
        '※ランダムマッチングでは引き続き対戦することがあります。',
    cancelText: 'キャンセル',
    confirmText: 'ブロック',
    isDestructive: true,
  );
  if (confirmed != true || !context.mounted) return;

  final ok = await ref.read(blockedUserIdsProvider.notifier).block(targetUserId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? '$targetNameさんをブロックしました' : 'ブロックに失敗しました'),
      duration: const Duration(seconds: 2),
    ),
  );
  if (ok) onBlocked?.call();
}

/// ユーザーのブロックを解除する確認ダイアログ
Future<void> showUnblockUserDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String targetUserId,
  required String targetName,
  VoidCallback? onUnblocked,
}) async {
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'ブロックを解除',
    message: '$targetNameさんのブロックを解除しますか？',
    cancelText: 'キャンセル',
    confirmText: '解除する',
    isDestructive: false,
  );
  if (confirmed != true || !context.mounted) return;

  final ok = await ref
      .read(blockedUserIdsProvider.notifier)
      .unblock(targetUserId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'ブロックを解除しました' : 'ブロック解除に失敗しました'),
      duration: const Duration(seconds: 2),
    ),
  );
  if (ok) onUnblocked?.call();
}

/// コンテンツ共通メニュー(通報 / 非表示 / ブロック / 自分の投稿なら削除)
/// - [authorUserId]: コンテンツ作者(ブロック対象)。自分のコンテンツなら null
/// - [isOwnContent]: 自分のコンテンツなら削除メニューを表示
Future<void> showContentMenuSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String? authorUserId,
  required String authorName,
  required String contentType,
  String? contentId,
  String? contentSnapshot,
  String? roomId,
  bool isOwnContent = false,
  VoidCallback? onHide,
  VoidCallback? onDelete,
  VoidCallback? onBlocked,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isOwnContent && authorUserId != null) ...[
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text(
                '$authorNameさんをブロック',
                style: AppTextStyles.notoSans(fontSize: 14),
              ),
              onTap: () => Navigator.pop(sheetContext, 'block'),
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.red),
              title: Text(
                '通報',
                style: AppTextStyles.notoSans(fontSize: 14),
              ),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
          ],
          if (onHide != null)
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.black54),
              title: Text(
                '非表示',
                style: AppTextStyles.notoSans(fontSize: 14),
              ),
              onTap: () => Navigator.pop(sheetContext, 'hide'),
            ),
          if (isOwnContent && onDelete != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                '削除',
                style: AppTextStyles.notoSans(fontSize: 14),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ListTile(
            title: Text(
              'キャンセル',
              style: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey),
            ),
            onTap: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case 'report':
      await showReportDialog(
        context: context,
        ref: ref,
        opponentId: authorUserId,
        roomId: roomId,
        contentId: contentId,
        contentType: contentType,
        contentSnapshot: contentSnapshot,
      );
      break;
    case 'hide':
      onHide?.call();
      break;
    case 'block':
      if (authorUserId != null) {
        await showBlockUserDialog(
          context: context,
          ref: ref,
          targetUserId: authorUserId,
          targetName: authorName,
          onBlocked: onBlocked,
        );
      }
      break;
    case 'delete':
      onDelete?.call();
      break;
  }
}
