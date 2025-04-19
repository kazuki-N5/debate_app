import 'dart:async';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/provider/match_history_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userId = supabase.auth.currentUser?.id;
final matchingRoomProvider =
    StateNotifierProvider<MatchingRoomNotifier, MatchingRoom>((ref) {
  return MatchingRoomNotifier(ref);
});

final goProvider = StateProvider<bool>((ref) => false);

class MatchingRoomNotifier extends StateNotifier<MatchingRoom> {
  final Ref ref;
  MatchingRoomNotifier(this.ref) : super(MatchingRoom());

  final supabase = Supabase.instance.client;
  bool hasNavigatedToChose = false;
  DateTime lastReceivedTime = DateTime.now();
  Timer? heartbeat;
  Timer? onlineTimer;
  StreamSubscription? _subscription;
  RealtimeChannel? channel;

  Future<DateTime> getServerTime() async {
    final response = await supabase.rpc('get_server_time');
    return DateTime.parse(response);
  }

  void updateMyTime(String user) async {
    final server = await getServerTime();
    final serverTime = server.toIso8601String();
    print('自分の時間$serverTime');
    final which = user == state.player1Id ? 'player1_time' : 'player2_time';
    print(which);
    try {
      await supabase.from('rooms').update({
        which: serverTime,
      }).eq('id', state.roomId!);
    } catch (e) {
      print('error');
    }
  }

  Future<void> checkTimeDifference(MatchingRoom room, user) async {
    final serverTime = await getServerTime();
    final which = user == state.player1Id ? 'player2_time' : 'player1_time';
    final roomData = await supabase
        .from('rooms')
        .select(which)
        .eq('id', room.roomId!) // roomIdはこの関数のスコープ内で利用可能な変数と仮定
        .single();
    final opponentTime =
        roomData[which] != null ? DateTime.parse(roomData[which]) : null;

    if (opponentTime == null) {
      print('=============================================');
      await Future.delayed(Duration(seconds: 10));
      print('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      final currentOpponentTime =
          user == state.player1Id ? state.player2_time : state.player1_time;
      if (currentOpponentTime == null) {
        win(state, user);
        return;
      } else {
        final difference = serverTime.difference(currentOpponentTime);
        if (difference.inSeconds >= 10) {
          win(state, user);
        }
      }
    } else {
      final difference = serverTime.difference(opponentTime);
      print('difference: $difference');
      if (difference.inSeconds >= 10) {
        win(state, user);
      }
    }
  }

  void pushonline(MatchingRoom room, String user) {
    onlineTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      print('オンライン');
      updateMyTime(user);
      checkTimeDifference(room, user);
    });
  }

  void checkOnline(MatchingRoom room, String user) {
    final lastTime = lastReceivedTime;

    final now = DateTime.now();
    final difference = now.difference(lastTime);
    print(difference.inSeconds);

    if (difference.inSeconds >= 10) {
      print('10秒以上経過しました');
      win(room, user);
    }
  }

  void initPresence(MatchingRoom room) {
    print('ページ遷移した');

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser?.id;

    delete();

    lastReceivedTime = DateTime.now();

    channel = supabase.channel(
      room.roomId!,
      opts: const RealtimeChannelConfig(),
    );
    channel
        ?.onPresenceSync((_) {
          print('sync');
        })
        .onPresenceLeave((payload) {})
        .onBroadcast(
          event: 'heartbeat',
          callback: (payload) {
            lastReceivedTime = DateTime.now();
            print(lastReceivedTime);
          },
        )
        .subscribe();

    heartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
      checkOnline(room, user!);
      channel?.sendBroadcastMessage(
        event: 'heartbeat',
        payload: {'message': 'ping'},
      );
    });
  }

  void delete() {
    if (onlineTimer != null) {
      onlineTimer!.cancel();
      onlineTimer = null;
      print('Timer cancelled');
    }
    if (heartbeat != null) {
      heartbeat!.cancel();
      heartbeat = null;
      print('Timer cancelled');
    }
    if (channel != null) {
      try {
        // Presenceでトラッキングしている場合は明示的にleave
        channel!.untrack();
        print('Channel untracked');

        // チャンネルの購読解除
        channel!.unsubscribe();
        print('Channel unsubscribed');

        channel = null;
      } catch (e) {
        print('Error during channel cleanup: $e');
      }
    }
  }

  Future<void> findMatch(String password,String theme,String choice1,String choice2) async {
    hasNavigatedToChose = false;
    ref.read(goProvider.notifier).state = false;
    state = MatchingRoom();

    router.go('/wait');
    print(userId);
    try {
      // データベース関数を呼び出してトランザクション処理を行う
      final result = await supabase.rpc('join_room', params: {
        'p_user_id': userId, // パラメータ名を SQL 関数に合わせる
        'p_room_password':
    password.isNotEmpty ? password : null, 
'p_room_theme':
    theme.isNotEmpty ? theme : null,
'p_room_choice1':
    choice1.isNotEmpty ? choice1 : null,
'p_room_choice2':
    choice2.isNotEmpty ? choice2 : null,
      });

      if (result['success']) {
        final roomData = result['room'];
        final roomId = roomData['id'];

        state = MatchingRoom.fromMap(roomData);

        if (result['action'] == 'joined') {
          // 既存の部屋に参加した場合
          print('部屋に参加しました');
        } else {
          // 新しい部屋を作成した場合
          print('新しい部屋を作成しました');
        }

        await waitForMatch(roomId);
      } else {
        print('マッチングエラー: ${result['error']}');
      }
    } catch (e) {
      print('インターネットに接続しましょう');
      print(e);
    }
  }

  Future<void> waitForMatch(String roomId) async {
    print('待機中');
    print('5');
    ref.invalidate(matchHistoryProvider);

    _subscription = supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .listen((List<Map<String, dynamic>> data) async {
          print('更新');
          state = MatchingRoom.fromMap(data[0]);
          print('更新の$state');

          if (data[0]['player2_id'] != null && !hasNavigatedToChose) {
            hasNavigatedToChose = true;
            final otherUserId =
                state.player1Id == userId ? state.player2Id : state.player1Id;
            await ref
                .read(otherUserProvider.notifier)
                .fetchOtherUser(otherUserId!);
            print(state.change);
            ref.read(goProvider.notifier).state = true;
          }
        });
  }

  Future<void> cancelMatching(String roomId) async {
   final response = await supabase.rpc('deleteroom', params: {
    'p_room_id': roomId,
    'p_user_id': userId,

  });
  if(response['success'] == true){
    _subscription?.cancel();
    router.go('/home');
   }
  }

  void finishstream() {
    _subscription?.cancel();
  }

  Future<void> updateChoice(String roomId, String player, bool choice) async {
    final which =
        player == state.player1Id ? 'player1_choice' : 'player2_choice';
    try {
      await supabase.from('rooms').update({
        which: choice,
      }).eq('id', roomId);
    } catch (e) {
      print('チョイスの接続不良です');
    }
  }

  Future<void> suggestfinish(String roomId, String player) async {
    final which =
        player == state.player1Id ? 'player1_finish' : 'player2_finish';
    try {
      await supabase.from('rooms').update({
        which: true,
      }).eq('id', roomId);
    } catch (e) {
      print('error');
    }
  }

  Future<void> notsuggestfinish(String roomId, String player) async {
    final which =
        player == state.player1Id ? 'player1_finish' : 'player2_finish';
    try {
      await supabase.from('rooms').update({
        which: false,
      }).eq('id', roomId);
    } catch (e) {
      print('error');
    }
  }

  Future<void> finish(String roomId, String player) async {
    final which = player == state.player1Id ? 'B' : 'A';
    print(which);
    print(roomId);

    try {
      await supabase.from('rooms').update({
        'result': '$which 降参した',
      }).eq('id', roomId);
    } catch (e) {
      print('error');
    }
  }

  Future<void> win(MatchingRoom room, String player) async {
    final which = player == state.player1Id ? 'A' : 'B';

    if (room.result == null) {
      try {
        await supabase.from('rooms').update({
          'result': '$which オフラインになりました',
        }).eq('id', room.roomId!);
      } catch (e) {
        print('error');
      }
    }
  }
}
