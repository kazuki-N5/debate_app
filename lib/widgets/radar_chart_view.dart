import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:debate_project/modes/debate_scores.dart';
import 'package:debate_project/widgets/app_text_styles.dart';

/// レーダーチャートおよび論理能力%表示ウィジェット
class RadarChartView extends StatefulWidget {
  final PlayerScore myScore;
  final PlayerScore? opponentScore;
  final String myName;
  final String? opponentName;
  final bool isStatic; // 静止画キャプチャ用（アニメーションなし）

  const RadarChartView({
    Key? key,
    required this.myScore,
    this.opponentScore,
    this.myName = 'あなた',
    this.opponentName,
    this.isStatic = false,
  }) : super(key: key);

  @override
  State<RadarChartView> createState() => _RadarChartViewState();
}

class _RadarChartViewState extends State<RadarChartView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.isStatic
          ? Duration.zero
          : const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (widget.isStatic) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['論理性', '説得力', '反論力', '構成力', 'マナー'];
    final myValues = [
      widget.myScore.logic,
      widget.myScore.persuasion,
      widget.myScore.rebuttal,
      widget.myScore.structure,
      widget.myScore.manner,
    ];
    final opponentValues = widget.opponentScore != null
        ? [
            widget.opponentScore!.logic,
            widget.opponentScore!.persuasion,
            widget.opponentScore!.rebuttal,
            widget.opponentScore!.structure,
            widget.opponentScore!.manner,
          ]
        : null;

    final myPercentage = widget.myScore.totalPercentage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.18),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- 論理能力 % 表示バッジ ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[600]!,
                  Colors.blue[800]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '今回の論理能力: ',
                  style: AppTextStyles.bold(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$myPercentage%',
                  style: AppTextStyles.bold(
                    color: Colors.amberAccent,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // --- 凡例（Legend） ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: Colors.blue[600]!,
                label: '${widget.myName} ($myPercentage%)',
              ),
              if (widget.opponentScore != null) ...[
                const SizedBox(width: 16),
                _buildLegendItem(
                  color: Colors.deepOrange[400]!,
                  label:
                      '${widget.opponentName ?? "対戦相手"} (${widget.opponentScore!.totalPercentage}%)',
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // --- レーダーチャート本体 ---
          SizedBox(
            height: 240,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final progress = widget.isStatic ? 1.0 : _animation.value;
                return CustomPaint(
                  painter: _RadarChartPainter(
                    categories: categories,
                    myValues: myValues,
                    opponentValues: opponentValues,
                    progress: progress,
                  ),
                  size: const Size(double.infinity, 240),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.bold(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// レーダーチャートのカスタムペインター
class _RadarChartPainter extends CustomPainter {
  final List<String> categories;
  final List<int> myValues;
  final List<int>? opponentValues;
  final double progress; // アニメーション進捗 (0.0 ~ 1.0)

  _RadarChartPainter({
    required this.categories,
    required this.myValues,
    this.opponentValues,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // ラベルを描画する余白を残して半径を設定
    final radius = math.min(size.width, size.height) / 2 - 38;
    final count = categories.length;
    if (count < 3) return;

    final angleStep = (2 * math.pi) / count;
    // 1つ目の頂点を真上（-pi/2）にするためのオフセット
    const startAngle = -math.pi / 2;

    // --- 1. グリッド背景の同心多角形 (20%, 40%, 60%, 80%, 100%) ---
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final gridFillPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // 外枠背景の塗りつぶし
    final outerPath = Path();
    for (int i = 0; i < count; i++) {
      final angle = startAngle + i * angleStep;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        outerPath.moveTo(x, y);
      } else {
        outerPath.lineTo(x, y);
      }
    }
    outerPath.close();
    canvas.drawPath(outerPath, gridFillPaint);

    // 同心目盛り線
    const levels = [0.2, 0.4, 0.6, 0.8, 1.0];
    for (final level in levels) {
      final levelRadius = radius * level;
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = startAngle + i * angleStep;
        final x = center.dx + levelRadius * math.cos(angle);
        final y = center.dy + levelRadius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // --- 2. 軸線（中心から各頂点への直線） ---
    final axisPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.0;

    for (int i = 0; i < count; i++) {
      final angle = startAngle + i * angleStep;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // --- 3. 対戦相手のポリゴン描画 ---
    if (opponentValues != null && opponentValues!.length == count) {
      _drawPolygon(
        canvas: canvas,
        center: center,
        radius: radius,
        values: opponentValues!,
        angleStep: angleStep,
        startAngle: startAngle,
        fillColor: Colors.deepOrange.withOpacity(0.2 * progress),
        strokeColor: Colors.deepOrange.withOpacity(0.85),
        pointColor: Colors.deepOrange[600]!,
        isDashed: true,
      );
    }

    // --- 4. 自分のポリゴン描画 ---
    _drawPolygon(
      canvas: canvas,
      center: center,
      radius: radius,
      values: myValues,
      angleStep: angleStep,
      startAngle: startAngle,
      fillColor: Colors.blue.withOpacity(0.35 * progress),
      strokeColor: Colors.blue[700]!,
      pointColor: Colors.blue[800]!,
      isDashed: false,
    );

    // --- 5. ラベルとスコアの描画 ---
    for (int i = 0; i < count; i++) {
      final angle = startAngle + i * angleStep;
      final labelRadius = radius + 22; // 少し外側に配置
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      final category = categories[i];
      final myVal = (myValues[i] * progress).round();

      final textSpan = TextSpan(
        children: [
          TextSpan(
            text: '$category\n',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: '$myVal',
            style: TextStyle(
              color: Colors.blue[800],
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final textOffset = Offset(
        x - textPainter.width / 2,
        y - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawPolygon({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required List<int> values,
    required double angleStep,
    required double startAngle,
    required Color fillColor,
    required Color strokeColor,
    required Color pointColor,
    required bool isDashed,
  }) {
    final count = values.length;
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < count; i++) {
      final angle = startAngle + i * angleStep;
      final normalizedValue = (values[i] / 100.0).clamp(0.0, 1.0) * progress;
      final r = radius * normalizedValue;
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      points.add(pt);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    // 塗りつぶし
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 境界線
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // 頂点ドット
    final pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;
    for (final pt in points) {
      canvas.drawCircle(pt, 3.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.myValues != myValues ||
        oldDelegate.opponentValues != opponentValues;
  }
}
