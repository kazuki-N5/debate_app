// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:debate_project/widgets/app_text_styles.dart';

class TrophyCountAnimation extends HookWidget {
  final int targetTrophy;
  final int? startTrophy; // 開始時の数値を外部から指定可能にする
  final Duration baseDurationPerUnit;
  final Color textColor;

  const TrophyCountAnimation({
    super.key,
    required this.targetTrophy,
    this.startTrophy,
    this.baseDurationPerUnit = const Duration(milliseconds: 150),
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // 前回の値を保持
    // startTrophy が指定されている場合はそれを使用し、そうでなければ現在の targetTrophy を初期値にする
    final previousValue = useRef<int>(startTrophy ?? targetTrophy);
    final currentValue = useRef<int>(startTrophy ?? targetTrophy);
    final diff = useRef<int>(0);

    final animationController = useAnimationController(
        duration: const Duration(milliseconds: 600));

    // 数値の変化を監視してアニメーションを開始
    void startAnimation(int from, int to) {
      diff.value = (to - from).abs();
      if (diff.value == 0) return;
      
      previousValue.value = from;
      currentValue.value = to;
      animationController.duration = baseDurationPerUnit * diff.value;
      animationController.forward(from: 0);
    }

    // 初回ビルド時に startTrophy と targetTrophy が異なる場合に実行
    useEffect(() {
      if (startTrophy != null && startTrophy != targetTrophy) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          startAnimation(startTrophy!, targetTrophy);
        });
      }
      return null;
    }, []);

    // targetTrophy の変更を監視
    useEffect(() {
      if (currentValue.value != targetTrophy) {
        startAnimation(currentValue.value, targetTrophy);
      }
      return null;
    }, [targetTrophy]);

    useAnimation(animationController);

    final t = animationController.value;
    final totalDiff = diff.value;
    final double exactValue = previousValue.value + (currentValue.value - previousValue.value) * t;
    final int displayValue = exactValue.toInt();

    double pulseProgress = 0.0;
    if (totalDiff > 0 && t < 1.0) {
      pulseProgress = (t * totalDiff) % 1.0;
    } else {
      pulseProgress = 0.0;
    }

    final pulseScale = 1.0 + (math.sin(pulseProgress * math.pi) * 0.15);
    final glowPower = math.sin(pulseProgress * math.pi);

    return Stack(
      alignment: Alignment.center,
      children: [
        if (glowPower > 0.01)
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8 * glowPower),
                  blurRadius: 8 * glowPower,
                  spreadRadius: 1 * glowPower,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.4 * glowPower),
                  blurRadius: 15 * glowPower,
                ),
              ],
            ),
          ),
        Transform.scale(
          scale: pulseScale,
          child: Text(
            displayValue.toString(),
            style: AppTextStyles.bold(
              color: textColor,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
