import 'package:debate_project/provider/matching_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MatchingPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final go = ref.watch(goProvider);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);
    final room = ref.watch(matchingRoomProvider);
    if (go == true) {
      // 遅延実行しないとビルド中の遷移エラーが発生する可能性があります
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/chose');
      });
    }

    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: Stack(
          children: [
            if (go == false) // マッチング待機中の表示
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'マッチング中...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          BlinkingMatchingIndicator(),
                        ],
                      ),
                    ),
                    SizedBox(height: 60),
                    ElevatedButton(
                      onPressed: () {
                        roomnotifier.cancelMatching(room.roomId!);
                        
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        'キャンセル',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BlinkingMatchingIndicator extends StatefulWidget {
  @override
  _BlinkingMatchingIndicatorState createState() =>
      _BlinkingMatchingIndicatorState();
}

class _BlinkingMatchingIndicatorState extends State<BlinkingMatchingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Icon(
        Icons.search,
        size: 80,
        color: Colors.white,
      ),
    );
  }
}
