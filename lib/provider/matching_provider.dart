import 'dart:async';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/history_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final matchingRoomProvider =
    StateNotifierProvider<MatchingRoomNotifier, MatchingRoom>((ref) {
  return MatchingRoomNotifier(ref);
});

final goProvider = StateProvider<bool>((ref) => false);

class MatchingRoomNotifier extends StateNotifier<MatchingRoom> {
  final Ref ref;
  MatchingRoomNotifier(this.ref) : super(MatchingRoom());

  SupabaseClient get supabase => ref.read(supabaseProvider);

  bool hasNavigatedToChose = false;
  StreamSubscription? _subscription;
  RealtimeChannel? _presenceChannel;
  Timer? _offlineTimer;

  void setupPresenceChannel(String roomId) {
    final myUserId = ref.read(currentUserIdProvider);
    if (myUserId == null) return;

    if (_presenceChannel != null) return; // 既に接続済みの場合は何もしない

    final channelName = 'presence-room-$roomId';
    _presenceChannel = supabase.channel(channelName);

    final otherUserId =
        (state.player1Id == myUserId) ? state.player2Id! : state.player1Id!;

    _presenceChannel!.onPresenceJoin((payload) {
      for (final presence in payload.newPresences) {
        // trackで送信したペイロードからuser_idを取得
        if (presence.payload['user_id'] == otherUserId) {
          print('✅ Opponent ($otherUserId) joined/reconnected.');
          // 相手が再接続したので、オフラインタイマーをキャンセル
          if (_offlineTimer?.isActive ?? false) {
            print('Cancelling offline timer.');
            _offlineTimer!.cancel();
            _offlineTimer = null;
          }
        }
      }
    }).onPresenceLeave((payload) {
      for (final presence in payload.leftPresences) {
        if (presence.payload['user_id'] == otherUserId) {
          // 既にタイマーが動いている場合や試合が終了している場合は何もしない
          if ((_offlineTimer?.isActive ?? false) || state.result != null) {
            return;
          }

          // 相手が切断したので、10秒の猶予タイマーを開始
          print('Starting 10-second offline grace period timer.');
          int countdown = 20; // カウントダウンの秒数
          _offlineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (countdown > 0) {
              print('----------${countdown}--------');
              countdown--;
            } else {
              // カウントダウンが0になったのでタイマーを停止し、勝利処理を実行
              print('⏰ 10 seconds passed. Opponent did not reconnect.');
              timer.cancel(); // periodic timerを必ずキャンセルする

              if (state.result == null) {
                win(state, myUserId);
              }
              _offlineTimer = null;
            }
          });
        }
      }
    }).subscribe((status, [error]) async {
      // 購読に成功したら、自分のプレゼンス情報を送信
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('Successfully subscribed to presence channel: $channelName');
        await _presenceChannel!.track({'user_id': myUserId});
      } else {
        print(
            'Failed to subscribe to presence channel: $status, Error: $error');
      }
    });
  }

  void delete() {
    _subscription?.cancel();
    _offlineTimer?.cancel();
    _offlineTimer = null;

    if (_presenceChannel != null) {
      try {
        // removeChannelを呼ぶと、untrackとunsubscribeが内部的に実行されます。
        supabase.removeChannel(_presenceChannel!);
        print('Presence channel cleaned up.');
      } catch (e) {
        print('Error during presence channel cleanup: $e');
      }
      _presenceChannel = null;
    }
    print('All notifier resources cleaned up.');
  }

  Future<void> findMatch(
      String password, String theme, String choice1, String choice2) async {
    final userId = ref.read(currentUserIdProvider);
    hasNavigatedToChose = false;
    ref.read(goProvider.notifier).state = false;

    if (userId == null) {
      print('エラー: ユーザーが認証されていません。マッチングを開始できません。');
      // ここでユーザーにエラーを通知するなどの処理を追加できます
      return;
    }

    state = MatchingRoom();
    final appstate = await ref.read(appStateProvider.notifier).loadVersion();
    if (appstate == AppStatus.error) {
      print('エラーが発生しました');
      return;
    } else if (appstate == AppStatus.forceUpdate) {
      ref.read(forceboolProvider.notifier).state = true;
      return;
    } else if (appstate == AppStatus.maintenance) {
      print('メンテナンス中');
      ref.read(maintenanceboolProvider.notifier).state = true;
      return;
    } else if (appstate == AppStatus.optionalUpdate) {
    } else if (appstate == AppStatus.normal) {
    } else {
      return;
    }

    _subscription?.cancel();
    delete();
    print(userId);
    try {
      // データベース関数を呼び出してトランザクション処理を行う
      final result = await supabase.rpc('join_room', params: {
        'p_user_id': userId, // パラメータ名を SQL 関数に合わせる
        'p_room_password': password.isNotEmpty ? password : null,
        'p_room_theme': theme.isNotEmpty ? theme : null,
        'p_room_choice1': choice1.isNotEmpty ? choice1 : null,
        'p_room_choice2': choice2.isNotEmpty ? choice2 : null,
      });

      if (result['success']) {
        router.go('/wait');
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
    final userId = ref.read(currentUserIdProvider);
    print('待機中');
    print('5');
    ref.invalidate(matchRecordsProvider);

    _subscription = supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .listen((List<Map<String, dynamic>> data) async {
          state = MatchingRoom.fromMap(data[0]);

          if (data[0]['player2_id'] != null && !hasNavigatedToChose) {
            hasNavigatedToChose = true;
            final otherUserId =
                state.player1Id == userId ? state.player2Id : state.player1Id;
            await ref
                .read(otherUserProvider.notifier)
                .fetchOtherUserWithRetry(otherUserId!);
            ref.read(goProvider.notifier).state = true;
          }
        });
  }

  Future<void> cancelMatching(String roomId) async {
    final userId = ref.read(currentUserIdProvider);
    final response = await supabase.rpc('deleteroom', params: {
      'p_room_id': roomId,
      'p_user_id': userId,
    });
    if (response['success'] == true) {
      _subscription?.cancel();
      router.go('/home');
    }
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

  @override
  void dispose() {
    print('MatchingRoomNotifier disposed. Performing cleanup.');
    // クリーンアップ処理を行う delete() メソッドを呼び出します。
    delete();
    // 親クラスの dispose も必ず呼び出します。
    super.dispose();
  }
}
