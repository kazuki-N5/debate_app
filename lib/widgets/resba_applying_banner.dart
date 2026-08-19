// ignore_for_file: file_names, use_build_context_synchronously
import 'dart:async';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 応募中の常駐バナー（アプリ全体の上部に固定・タブ切替と無関係）
///  - 応募中: 「⚔️ 申し込み中（◯◯さんのレスバ）」+ 取り消す
///  - 拒否/取消: 「⚔️ 拒否されました」を表示してすぐ消える
class ResbaApplyingBanner extends ConsumerStatefulWidget {
  const ResbaApplyingBanner({super.key});

  @override
  ConsumerState<ResbaApplyingBanner> createState() =>
      _ResbaApplyingBannerState();
}

class _ResbaApplyingBannerState extends ConsumerState<ResbaApplyingBanner> {
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    // ホスト応募検知 + 再起動時の再ダイアログをアプリ全体で開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resbaMatchListenerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(applyingInfoProvider);
    final info = infoAsync.valueOrNull;
    if (info == null) return const SizedBox.shrink();

    if (!info.isPending) {
      // 拒否・取消: 「⚔️ 拒否されました」を白テキストで表示し、すぐ消える
      _clearTimer ??= Timer(const Duration(milliseconds: 800), () {
        if (mounted) ref.read(applyingInfoProvider.notifier).clear();
      });
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⚔️', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Text(
                    '拒否されました',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Row(
                  children: [
                    const Text('⚔️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '申し込み中（${info.hostName ?? ''}さんのレスバ）',
                        style: AppTextStyles.bold(
                          fontSize: 13,
                          color: const Color(0xFF7856FF),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        await ref
                            .read(applyingInfoProvider.notifier)
                            .cancelApplication();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7856FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          '取り消す',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
