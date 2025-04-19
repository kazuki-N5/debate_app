import 'dart:math';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinishPage extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = Supabase.instance.client;
    final ischange = useState<bool>(true);
    final save = useState<String>('');
    final room = ref.watch(matchingRoomProvider);
    final myuser = ref.watch(userProvider);
    final otheruser = ref.watch(otherUserProvider);
    final user = supabase.auth.currentUser!.id;
    final usernotifier = ref.watch(userProvider.notifier);
    final roomnotifier = ref.read(matchingRoomProvider.notifier);

    useEffect(() {
      roomnotifier.delete();
      roomnotifier.finishstream();
      return () {
        roomnotifier.delete();
      };
    }, const []);

    String getResultText(MatchingRoom room, String userId) {
      // room.resultの最初の文字を取得
      String firstChar = room.result![0];
      bool isPlayer1 = room.player1Id == userId;

      if (isPlayer1) {
        return firstChar == 'A' ? '勝利' : '敗北';
      } else {
        return firstChar == 'A' ? '敗北' : '勝利';
      }
    }

    String formatResult(MatchingRoom room, Users myuser, Users otheruser) {
      String result = room.result!.substring(1); // 最初の1文字を削除

      // 先頭の空白を削除
      result = result.trimLeft(); // 最初の1文字を削除

      if (room.player1Id == myuser.id) {
        result =
            result.replaceAll('A', myuser.name).replaceAll('B', otheruser.name);
      } else {
        // player1がotheruserの場合
        result =
            result.replaceAll('A', otheruser.name).replaceAll('B', myuser.name);
      }

      return result;
    }

    int clamp(int point, int min, int max) {
      if (point < min) {
        return min;
      } else if (max < point) {
        return max;
      } else {
        return point;
      }
    }

    String calculatePoint(int winnerRate, int loserRate) {
      const int K = 32;

      double calculation = K / (pow(10, (winnerRate - loserRate) / 400) + 1);
      int point = calculation.round();
      point = clamp(point, 2, 32);
      return "$point";
    }

    String displayPoint(
        MatchingRoom room, Users myuser, Users otheruser, String userId) {
      String firstChar = room.result![0];
      if (ischange.value) {
        ischange.value = false;
        if (firstChar == 'A') {
          if (room.player1Id == userId) {
            save.value = '+${calculatePoint(myuser.trophy, otheruser.trophy)}';
            return save.value;
          } else {
            save.value = '-${calculatePoint(otheruser.trophy, myuser.trophy)}';
            return save.value;
          }
        } else if (firstChar == 'B') {
          if (room.player1Id == userId) {
            save.value = '-${calculatePoint(otheruser.trophy, myuser.trophy)}';
            return save.value;
          } else {
            save.value = '+${calculatePoint(myuser.trophy, otheruser.trophy)}';
            return save.value;
          }
        } else {
          return '0';
        }
      }
      return save.value;
    }

    final result = getResultText(room, user);

    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header with centered title (settings button removed)
                      Text(
                        '結果発表',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 200, // Stackに十分な幅を確保
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 勝利/敗北を中央に配置
                              Text(
                                getResultText(room, user),
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: result == ('勝利')
                                      ? Colors.red
                                      : Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              // 数字を右側に配置
                              Positioned(
                                right: 20,
                                top: 25,
                                child: Text(
                                  displayPoint(room, myuser, otheruser, user),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: result == ('勝利')
                                        ? Colors.red
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        width: double.infinity, // 親の幅いっぱいに広げる
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '勝敗の理由:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            // 固定高さのコンテナ内にSingleChildScrollViewを配置
                            Container(
                              width: double.infinity, // 親の幅いっぱいに広げる
                              height: 155, // 固定高さ
                              child: SingleChildScrollView(
                                child: Text(
                                  formatResult(room, myuser, otheruser),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        height: 200,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          'Advertisement Area',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          // Restart debate logic using ref if needed
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'もう一度ディベート',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          await usernotifier.fetchUser(user);
                          router.go('/home');
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blue),
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'ホームに戻る',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                color: Colors.grey[200],
                child: Text(
                  'Advertisement Area',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
