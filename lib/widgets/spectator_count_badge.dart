import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';

/// 観戦者数バッジ（👁 + 人数）
///
/// 観戦者が0人の場合は非表示にするため、呼び出し側で
/// `count > 0` のときだけ組み込むこと。
class SpectatorCountBadge extends StatelessWidget {
  const SpectatorCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: AppTextStyles.bold(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}