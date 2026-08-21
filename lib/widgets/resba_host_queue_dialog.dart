// ignore_for_file: file_names, use_build_context_synchronously
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ホストの「応募キュー」ダイアログ
///  - 保留中の応募を古い順に一覧表示し、1件ずつ「承認 / 拒否」を選べる
///  - 新しい応募は同じダイアログに溜まる（Realtime / ポーリングで自動更新）
///  - キューが空になったら自動で閉じる
Future<void> showHostApplicationQueueDialog(Ref ref) async {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  await showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    builder: (dialogContext) => const _HostApplicationQueueDialog(),
  );
}

class _HostApplicationQueueDialog extends ConsumerStatefulWidget {
  const _HostApplicationQueueDialog();

  @override
  ConsumerState<_HostApplicationQueueDialog> createState() =>
      _HostApplicationQueueDialogState();
}

class _HostApplicationQueueDialogState
    extends ConsumerState<_HostApplicationQueueDialog> {
  bool _autoClosed = false;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(pendingHostApplicationsProvider).valueOrNull ??
        const <HostApplication>[];

    // すべて処理されたら自動で閉じる
    if (queue.isEmpty && !_autoClosed) {
      _autoClosed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _autoClosed) Navigator.of(context).pop();
      });
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    final width = MediaQuery.of(context).size.width * 0.88;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                  child: Row(
                    children: [
                      const Text('⚔️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '申し込み（${queue.length}件）',
                          style: AppTextStyles.bold(
                              fontSize: 15, color: Colors.black87),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close,
                            size: 20, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: queue.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'すべて処理しました',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: queue.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final application = queue[index];
                            return _ApplicationTile(
                              application: application,
                              onApprove: () => _handle(application, true),
                              onReject: () => _handle(application, false),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 承認 / 拒否を実行し、キューを再取得する
  Future<void> _handle(HostApplication application, bool approve) async {
    final result = await ref.read(resbaActionsProvider).approveApplication(
          application.inviteId,
          application.applicationId,
          approve,
        );
    // キューを再取得（承認なら同じレスバの残り応募は自動却下され消える）
    await ref.read(pendingHostApplicationsProvider.notifier).fetch();

    if (result.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.error!)));
      }
      return;
    }
    if (approve && result.roomId != null) {
      // 対戦開始: ダイアログを閉じてバトル画面へ
      if (mounted) {
        _autoClosed = true; // 自動クローズとの二重ポップを防ぐ
        Navigator.of(context).pop();
      }
      await ref.read(matchingRoomProvider.notifier).joinBbsRoom(result.roomId!);
      router.go('/wait');
    }
  }
}

class _ApplicationTile extends StatelessWidget {
  final HostApplication application;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApplicationTile({
    required this.application,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = application.applicantName ?? '名無し';
    final avatar = application.applicantAvatar;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: avatar != null && avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? Icon(Icons.person, size: 16, color: Colors.grey[600])
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name さん',
                        style: AppTextStyles.bold(
                            fontSize: 13, color: Colors.black87)),
                    Text(
                      '🏆 ${application.applicantTrophy ?? '-'} ・ ${application.theme}',
                      style: AppTextStyles.notoSans(
                          fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QueueButton(
                  label: '✅ 承認',
                  color: const Color(0xFF00BA7C),
                  onTap: onApprove,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QueueButton(
                  label: '拒否',
                  color: Colors.grey,
                  onTap: onReject,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueueButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QueueButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTextStyles.bold(fontSize: 12, color: Colors.white),
        ),
      ),
    );
  }
}
