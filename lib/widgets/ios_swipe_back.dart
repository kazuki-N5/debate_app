import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// iOS端末において画面左端からのスワイプ（スワイプバック）を可能にするラッパーウィジェット。
/// 画面を開くときはアニメーションを行わず即時表示（ぱっと遷移）し、戻るときのみスワイプ操作を提供します。
class IosSwipeBack extends StatefulWidget {
  final Widget child;
  final bool enabled;

  /// スワイプ開始を許可する画面左端からの幅 (px)
  final double edgeWidth;

  const IosSwipeBack({
    super.key,
    required this.child,
    this.enabled = true,
    this.edgeWidth = 35.0,
  });

  @override
  State<IosSwipeBack> createState() => _IosSwipeBackState();
}

class _IosSwipeBackState extends State<IosSwipeBack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _controller.addListener(() {
      setState(() {
        _dragOffset = _controller.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!widget.enabled || !_isIos) return;
    if (details.globalPosition.dx <= widget.edgeWidth) {
      _isDragging = true;
      _controller.stop();
      setState(() {
        _dragOffset = 0.0;
      });
      FocusScope.of(context).unfocus();
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, screenWidth);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = screenWidth > 0 ? _dragOffset / screenWidth : 0.0;
    final velocity = details.primaryVelocity ?? 0.0;

    // 画面の25%以上スワイプ、または右方向へ一定以上のフリック速度がある場合は戻る
    if (progress > 0.25 || velocity > 250) {
      _controller.value = _dragOffset;
      _controller
          .animateTo(
            screenWidth,
            duration: Duration(
              milliseconds: ((1.0 - progress) * 200).clamp(50, 200).toInt(),
            ),
            curve: Curves.easeOut,
          )
          .then((_) {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    } else {
      // スワイプが足りない場合は元の位置に戻す
      _controller.value = _dragOffset;
      _controller.animateTo(
        0.0,
        duration: Duration(
          milliseconds: (progress * 200).clamp(50, 200).toInt(),
        ),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_isIos) {
      return widget.child;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final progress =
        screenWidth > 0 ? (_dragOffset / screenWidth).clamp(0.0, 1.0) : 0.0;

    return Stack(
      children: [
        // スワイプ中に背景を少し暗くするオーバーレイ
        if (_dragOffset > 0)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.15 * (1.0 - progress)),
            ),
          ),
        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: Container(
            decoration: _dragOffset > 0
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(-4, 0),
                      ),
                    ],
                  )
                : null,
            child: widget.child,
          ),
        ),
        // 左端のスワイプ検知領域（ドラッグ中は画面全体で追従）
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: _isDragging ? screenWidth : widget.edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
          ),
        ),
      ],
    );
  }
}

/// 遷移時は即時表示（アニメーションなし）で開き、iPhoneではスワイプバックを可能にするGoRouter用カスタムページ
class InstantSwipePage<T> extends CustomTransitionPage<T> {
  InstantSwipePage({
    required Widget child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
          child: IosSwipeBack(child: child),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}
