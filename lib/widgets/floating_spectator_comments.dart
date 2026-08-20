import 'dart:math';
import 'package:flutter/material.dart';

/// 観戦コメント（ヤジ）のデータモデル
class FloatingSpectatorCommentItem {
  final String id;
  final String text;
  final double topRatio; // 画面の縦位置の割合 (0.15 ~ 0.65)
  final Color backgroundColor;

  FloatingSpectatorCommentItem({
    required this.id,
    required this.text,
    required this.topRatio,
    this.backgroundColor = const Color(0xCC1A1A1A),
  });
}

/// 観戦コメントが画面横からふわっと流れて消えるオーバーレイウィジェット
class FloatingSpectatorCommentsOverlay extends StatefulWidget {
  final Widget child;
  final bool isMuted;

  const FloatingSpectatorCommentsOverlay({
    super.key,
    required this.child,
    this.isMuted = false,
  });

  @override
  State<FloatingSpectatorCommentsOverlay> createState() =>
      FloatingSpectatorCommentsOverlayState();
}

class FloatingSpectatorCommentsOverlayState
    extends State<FloatingSpectatorCommentsOverlay> {
  final List<FloatingSpectatorCommentItem> _activeComments = [];
  final Random _random = Random();
  double _lastTopRatio = 0.25;

  /// コメントを追加（最大15文字）
  void addComment(String text) {
    if (widget.isMuted) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final displayText = trimmed.length > 15 ? trimmed.substring(0, 15) : trimmed;

    // 前回の位置と重なりにくいように適度に散らす
    double nextTopRatio = _lastTopRatio + 0.12 + (_random.nextDouble() * 0.08);
    if (nextTopRatio > 0.60) {
      nextTopRatio = 0.15 + (_random.nextDouble() * 0.08);
    }
    _lastTopRatio = nextTopRatio;

    final item = FloatingSpectatorCommentItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}',
      text: displayText,
      topRatio: nextTopRatio,
    );

    if (mounted) {
      setState(() {
        _activeComments.add(item);
      });
    }
  }

  void _removeComment(String id) {
    if (!mounted) return;
    setState(() {
      _activeComments.removeWhere((c) => c.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!widget.isMuted)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: _activeComments.map((item) {
                      return _SingleFloatingComment(
                        key: ValueKey(item.id),
                        item: item,
                        parentHeight: constraints.maxHeight,
                        parentWidth: constraints.maxWidth,
                        onComplete: () => _removeComment(item.id),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _SingleFloatingComment extends StatefulWidget {
  final FloatingSpectatorCommentItem item;
  final double parentHeight;
  final double parentWidth;
  final VoidCallback onComplete;

  const _SingleFloatingComment({
    super.key,
    required this.item,
    required this.parentHeight,
    required this.parentWidth,
    required this.onComplete,
  });

  @override
  State<_SingleFloatingComment> createState() => _SingleFloatingCommentState();
}

class _SingleFloatingCommentState extends State<_SingleFloatingComment>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // 右から左へふわっと移動（画面右外から左へ移動）
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: -0.4,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
      ),
    );

    // フェードイン（最初15%）→ 維持 → フェードアウト（最後の25%）
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    // 登場時に少しポコッと大きくなる
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPos = widget.parentHeight * widget.item.topRatio;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final leftPos = widget.parentWidth * _slideAnimation.value;

        return Positioned(
          top: topPos,
          left: leftPos,
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: widget.item.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.campaign,
                      size: 16,
                      color: Color(0xFFFFD54F),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.item.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
