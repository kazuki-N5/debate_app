import 'package:flutter/material.dart';

/// 1桁時はまんまる（正円）、2桁以上はカプセル型、999以降は「999+」を表示するバッジウィジェット
class CountBadge extends StatelessWidget {
  final int count;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final double minSize;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  const CountBadge({
    super.key,
    required this.count,
    this.backgroundColor = const Color(0xFF4FAFF5),
    this.textColor = Colors.white,
    this.fontSize = 11.5,
    this.minSize = 21,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final text = count > 999 ? '999+' : '$count';
    final isSingleDigit = count < 10;

    final textStyle = TextStyle(
      color: textColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
    );

    final strutStyle = StrutStyle(
      fontSize: fontSize,
      height: 1.0,
      forceStrutHeight: true,
      leadingDistribution: TextLeadingDistribution.even,
    );

    if (isSingleDigit) {
      return Container(
        width: minSize,
        height: minSize,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: textStyle,
            strutStyle: strutStyle,
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: border,
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: textStyle,
          strutStyle: strutStyle,
        ),
      ),
    );
  }
}
