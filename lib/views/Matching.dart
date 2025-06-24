import 'package:debate_project/provider/matching_provider.dart'; // 適切なパスに修正してください
import 'package:debate_project/router/router.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:developer'; // デバッグ用のログ出力に利用

// ConsumerWidgetからConsumerStatefulWidgetに変更
class MatchingPage extends ConsumerStatefulWidget {
  @override
  _MatchingPageState createState() => _MatchingPageState();
}

// 対応するStateクラスを作成し、WidgetsBindingObserverをmixin
class _MatchingPageState extends ConsumerState<MatchingPage> with WidgetsBindingObserver {

  // initStateでオブザーバーを登録
  @override
  void initState() {
    super.initState();
    log('MatchingPage initState called.');
    // アプリのライフサイクル変更を監視するためのオブザーバーを追加
    WidgetsBinding.instance.addObserver(this);
  }

  // didChangeAppLifecycleStateメソッドを実装
  // アプリのライフサイクル状態が変更されたときに呼ばれる
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log('AppLifecycleState changed: $state');

    // アプリがバックグラウンドになったとき (タスクキルなどの可能性)
    if (state == AppLifecycleState.paused) {
      log('App paused detected. Attempting to cancel matching.');

      // Riverpodのreadを使用して現在の状態とnotifierを取得
      // 注意: didChangeAppLifecycleState内ではbuildコンテキストがないため、ref.readを使用
      final roomNotifier = ref.read(matchingRoomProvider.notifier);
      final currentRoomState = ref.read(matchingRoomProvider);

      // roomIdが存在する場合にキャンセル処理を実行
      // この処理は、MatchingPageが表示されている最中にアプリがバックグラウンドに行った場合に発火します。
      if (currentRoomState.roomId != null) {
         log('Cancelling matching for roomId: ${currentRoomState.roomId} due to app pause.');
        roomNotifier.cancelMatching(currentRoomState.roomId!);
      } else {
         log('roomId is null on app pause. No matching to cancel.');
      }
    }
    // 他のライフサイクル状態 (resumed, inactive, detached) も必要なら処理を追加
  }


  // disposeでオブザーバーの登録を解除
  // このdisposeは、MatchingPageから他のページに遷移したときに呼ばれます。
  @override
  void dispose() {
    log('MatchingPage dispose called.');

    // アプリのライフサイクル監視を停止
    WidgetsBinding.instance.removeObserver(this);

    // 注意: ここでは MatchingPage から離れること自体でキャンセル処理は行いません。
    // アプリ全体のライフサイクル変更（pausedなど）でキャンセルするようにしました。

    // アニメーションコントローラーなどのリソースを解放
    // _controller.dispose(); // BlinkingMatchingIndicator にdisposeが移動したので不要

    super.dispose(); // 必ず最後に呼び出す
  }

  @override
  Widget build(BuildContext context) {
    // ConsumerStatefulWidgetのbuildメソッドはwidgetではなく、thisからrefを取得
    final go = ref.watch(goProvider);
    // ボタン押下などで使うnotifierはreadで十分
    final roomnotifier = ref.read(matchingRoomProvider.notifier);
    // UI更新のために状態をwatch
    final room = ref.watch(matchingRoomProvider);

    // マッチング成功時の画面遷移
    if (go == true) {
      // 遅延実行しないとビルド中の遷移エラーが発生する可能性があります
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // `mounted`をチェックして、ウィジェットがまだツリーにあるか確認するのが安全
        if (mounted) {
           log('Navigating to /chose because go is true.');
           context.go('/chose');
        } else {
           log('Navigation skipped because widget is not mounted.');
        }
      });
    }

    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: Stack(
          children: [
            // go == false の場合のみマッチング待機UIを表示
            if (go == false)
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
                          BlinkingMatchingIndicator(), // StatefulWidgetのまま
                        ],
                      ),
                    ),
                    SizedBox(height: 60),
                    ElevatedButton(
                      onPressed: () {
                        // ボタン押下時のキャンセル処理
                        if (room.roomId != null) {
                           log('User pressed Cancel button for roomId: ${room.roomId}');
                          roomnotifier.cancelMatching(room.roomId!);
                        } else {
                          router.go('/home');
                        }
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
             // go == true の場合はマッチング待機UIを非表示にするだけ
          ],
        ),
      ),
    );
  }
}

// BlinkingMatchingIndicator は StatefulWidget のままでOKです
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
    // ここでアニメーションコントローラーを破棄します
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