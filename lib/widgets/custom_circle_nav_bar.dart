import 'package:flutter/material.dart';

class CustomCircleNavBar extends StatelessWidget {
  final int activeIndex;
  final Function(int index) onTap;
  final double height;
  final double circleWidth;
  final Color color;
  final Color circleColor;
  final double elevation;
  final Color shadowColor;
  final List<Widget> items;
  final Widget centerIcon;

  const CustomCircleNavBar({
    Key? key,
    required this.activeIndex,
    required this.onTap,
    this.height = 60,
    this.circleWidth = 60,
    this.color = Colors.white,
    this.circleColor = Colors.white,
    this.elevation = 4,
    this.shadowColor = Colors.black12,
    required this.items,
    required this.centerIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            painter: _CircleBottomPainter(
              iconWidth: circleWidth,
              color: color,
              circleColor: circleColor,
              xOffsetPercent: 0.5, // 常に中央固定
              boxRadius: BorderRadius.zero,
              shadowColor: shadowColor,
              circleShadowColor: shadowColor,
              elevation: elevation,
            ),
            child: SizedBox(
              height: height,
              width: double.infinity,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => onTap(0),
                  child: Center(child: items[0]),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => onTap(1),
                  child: Container(), // 中央は空けておく
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => onTap(2),
                  child: Center(child: items[1]), // itemsの2番目
                ),
              ),
            ],
          ),
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - circleWidth / 2,
            top: -(circleWidth * 0.5) + _CircleBottomPainter.getMiniRadius(circleWidth),
            child: GestureDetector(
              onTap: () => onTap(1),
              child: Container(
                width: circleWidth,
                height: circleWidth,
                alignment: Alignment.center,
                child: centerIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBottomPainter extends CustomPainter {
  _CircleBottomPainter({
    required this.iconWidth,
    required this.color,
    required this.circleColor,
    required this.xOffsetPercent,
    required this.boxRadius,
    required this.shadowColor,
    required this.circleShadowColor,
    required this.elevation,
  });

  final Color color;
  final Color circleColor;
  final double iconWidth;
  final double xOffsetPercent;
  final BorderRadius boxRadius;
  final Color shadowColor;
  final Color circleShadowColor;
  final double elevation;

  static double getR(double circleWidth) {
    return circleWidth / 2 * 1.2;
  }

  static double getMiniRadius(double circleWidth) {
    return getR(circleWidth) * 0.3;
  }

  static double convertRadiusToSigma(double radius) {
    return radius * 0.57735 + 0.5;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Path path = Path();
    Paint paint = Paint()..color = color;
    Paint circlePaint = Paint()..color = circleColor;

    final w = size.width;
    final h = size.height;
    final r = getR(iconWidth);
    final miniRadius = getMiniRadius(iconWidth);
    final x = xOffsetPercent * w;
    final firstX = x - r;
    final secondX = x + r;

    path.moveTo(0, 0 + boxRadius.topLeft.y);
    path.quadraticBezierTo(0, 0, boxRadius.topLeft.x, 0);
    path.lineTo(firstX - miniRadius, 0);
    path.quadraticBezierTo(firstX, 0, firstX, miniRadius);

    path.arcToPoint(
      Offset(secondX, miniRadius),
      radius: Radius.circular(r),
      clockwise: false,
    );

    path.quadraticBezierTo(secondX, 0, secondX + miniRadius, 0);
    path.lineTo(w - boxRadius.topRight.x, 0);
    path.quadraticBezierTo(w, 0, w, boxRadius.topRight.y);
    path.lineTo(w, h - boxRadius.bottomRight.y);
    path.quadraticBezierTo(w, h, w - boxRadius.bottomRight.x, h);
    path.lineTo(boxRadius.bottomLeft.x, h);
    path.quadraticBezierTo(0, h, 0, h - boxRadius.bottomLeft.y);
    path.close();

    if (elevation > 0) {
      canvas.drawPath(
          path,
          Paint()
            ..color = shadowColor
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, convertRadiusToSigma(elevation)));
      canvas.drawCircle(
          Offset(x, miniRadius),
          iconWidth / 2,
          Paint()
            ..color = circleShadowColor
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, convertRadiusToSigma(elevation)));
    }

    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(x, miniRadius), iconWidth / 2, circlePaint);
  }

  @override
  bool shouldRepaint(_CircleBottomPainter oldDelegate) => oldDelegate != this;
}
