import 'package:debate_project/provider/bbs_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class BbsApplyingBanner extends HookConsumerWidget {
  const BbsApplyingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestState = ref.watch(bbsGuestProvider);

    if (guestState == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.orangeAccent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '現在応募中...',
            style: AppTextStyles.bold(color: Colors.white, fontSize: 16),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
            ),
            onPressed: () async {
              final error = await ref.read(bbsGuestProvider.notifier).cancelApplication();
              if (error != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                }
              }
            },
            child: Text('やっぱやめる', style: AppTextStyles.bold()),
          )
        ],
      ),
    );
  }
}
