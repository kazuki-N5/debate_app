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

  /// コメントを追加（最大20文字）
  void addComment(String text) {
    if (widget.isMuted) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final displayText = trimmed.length > 20 ? trimmed.substring(0, 20) : trimmed;

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    // 右から左へ等速で移動（画面右外から左外へ完全に抜け切るまで）
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: -1.2,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

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
          child: Stack(
            children: [
              // 弾幕風：黒フチ取り（ストローク）
              Text(
                widget.item.text,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3.5
                    ..color = Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
              // 弾幕風：内側の白太文字 ＋ ドロップシャドウ
              Text(
                widget.item.text,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  decoration: TextDecoration.none,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
