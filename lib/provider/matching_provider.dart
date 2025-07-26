import 'dart:async';
import 'dart:developer';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/history_provider.dart';
import 'package:debate_project/provider/message_provider.dart';
import 'package:debate_project/provider/other_user.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Homepage_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final matchingRoomProvider =
    StateNotifierProvider<MatchingRoomNotifier, MatchingRoom>((ref) {
  return MatchingRoomNotifier(ref);
});

final goProvider = StateProvider<bool>((ref) => false);

class MatchingRoomNotifier extends StateNotifier<MatchingRoom>
    with WidgetsBindingObserver {
  final Ref ref;
  MatchingRoomNotifier(this.ref) : super(MatchingRoom());

  SupabaseClient get supabase => ref.read(supabaseProvider);

  bool hasNavigatedToChose = false;
  bool isdisposed = false;
  RealtimeChannel? _subscription;
  RealtimeChannel? _presenceChannel;
  Timer? _offlineTimer;

//アプリのライフサイクルでホームに戻ったときと戻ったときの丁稚　キャンセルマッチを実装
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState appState) async {
    super.didChangeAppLifecycleState(appState);
    log(appState.toString());

    if (appState == AppLifecycleState.inactive) {
      log('inactive');

      log(state.player2Id.toString());

      if (state.player2Id == null) {
        log('Cancelling matching for roomIddue to app pause.');
        cancelMatching(state.roomId!);
      } else {
        log('roomId is null on app pause. No matching to cancel.');
      }
    }

    if (appState == AppLifecycleState.resumed) {
      log('App resumed. Checking for room updates.');
      if (state.roomId != null) {
        try {
          final roomdata = await supabase
              .from('rooms')
              .select()
              .eq('id', state.roomId!)
              .single();

          if (!isdisposed) {
            state = MatchingRoom.fromMap(roomdata);
          }
        } catch (e) {
          log(e.toString());
        }
      }
    }
  }

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
              log('----------${countdown}--------');
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
    if (_subscription != null) {
      try {
        // removeChannelを呼ぶと、untrackとunsubscribeが内部的に実行されます。
        supabase.removeChannel(_subscription!);
        print('Presence channel cleaned up.');
      } catch (e) {
        print('Error during presence channel cleanup: $e');
      }
      _subscription = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    print('All notifier resources cleaned up.');
  }

  void pdelete() {
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
    if (_subscription != null) {
      try {
        // removeChannelを呼ぶと、untrackとunsubscribeが内部的に実行されます。
        supabase.removeChannel(_subscription!);
        print('Presence channel cleaned up.');
      } catch (e) {
        print('Error during presence channel cleanup: $e');
      }
      _subscription = null;
    }
    print('All notifier resources cleaned up.');
  }

  Future<void> findMatch(
      String password, String theme, String choice1, String choice2) async {
    final userId = ref.read(currentUserIdProvider);
    hasNavigatedToChose = false;
    isdisposed = false;
    ref.read(goProvider.notifier).state = false;

    if (userId == null) {
      print('エラー: ユーザーが認証されていません。マッチングを開始できません。');
      ref.read(friendmatchProvider.notifier).state = false;
      return;
    }

    state = MatchingRoom();
    log('${state}');
    final appstate = await ref.read(appStateProvider.notifier).loadVersion();
    if (appstate == AppStatus.error) {
      print('エラーが発生しました');
      ref.read(friendmatchProvider.notifier).state = false;
      return;
    } else if (appstate == AppStatus.forceUpdate) {
      ref.read(forceboolProvider.notifier).state = true;
      ref.read(friendmatchProvider.notifier).state = false;
      return;
    } else if (appstate == AppStatus.maintenance) {
      print('メンテナンス中');
      ref.read(maintenanceboolProvider.notifier).state = true;
      ref.read(friendmatchProvider.notifier).state = false;
      return;
    } else if (appstate == AppStatus.optionalUpdate) {
    } else if (appstate == AppStatus.normal) {
    } else {
      ref.read(friendmatchProvider.notifier).state = false;
      return;
    }

    delete();
    ref.read(chatProvider.notifier).unsubscribeFromMessages();
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
        final roomData = result['room'];
        final roomId = roomData['id'];

        state = MatchingRoom.fromMap(roomData);

        router.go('/wait');
        WidgetsBinding.instance.addObserver(this);

        ref.read(friendmatchProvider.notifier).state = false;

        await waitForMatch(roomId);
      } else {
        print('マッチングエラー: ${result['error']}');
        ref.read(friendmatchProvider.notifier).state = false;
      }
    } catch (e) {
      log('インターネットに接続しましょう');
      ref.read(friendmatchProvider.notifier).state = false;
      print(e);
    }
  }

  Future<void> waitForMatch(String roomId) async {
    final userId = ref.read(currentUserIdProvider);
    ref.invalidate(matchRecordsProvider);
    log('サブスク前のgoprovider ${ref.read(goProvider)}');
    log('${isdisposed}-------');
    if (isdisposed) return;
    try {
      _subscription = await supabase
          .channel('room-updates:$roomId')
          .onPostgresChanges(
              event: PostgresChangeEvent
                  .all, // or .update if you only care about updates
              schema: 'public',
              table: 'rooms',
              // filterでidがroomIdと一致する行のみを対象にする
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: roomId,
              ),
              callback: (payload) async {
                final newData = payload.newRecord;
                state = MatchingRoom.fromMap(newData);
                log('サブスク完了${state.player2Id}');

                if (state.player2Id != null && !hasNavigatedToChose) {
                  log('対戦相手発見');
                  hasNavigatedToChose = true;
                  final otherUserId = state.player1Id == userId
                      ? state.player2Id
                      : state.player1Id;
                  await ref
                      .read(otherUserProvider.notifier)
                      .fetchOtherUserWithRetry(otherUserId!);
                  ref.read(goProvider.notifier).state = true;
                }
              })
          .subscribe();
      log('サブスクは完了しました！');
    } catch (e) {
      cancelMatching(roomId);
      ref.read(friendmatchProvider.notifier).state = false;
      router.go('/home');
    }

    if (state.player2Id != null && !hasNavigatedToChose) {
      log('対戦相手発見');
      hasNavigatedToChose = true;
      final otherUserId =
          state.player1Id == userId ? state.player2Id : state.player1Id;
      await ref
          .read(otherUserProvider.notifier)
          .fetchOtherUserWithRetry(otherUserId!);
      ref.read(goProvider.notifier).state = true;
    }

    await Future.delayed(const Duration(seconds: 2));
    log('${state.player2Id}');
    log('一旦サブスク後のgoprovider ${ref.read(goProvider)}');

    if (!hasNavigatedToChose) {
      if (isdisposed) return;
      try {
        log('Performing initial fetch for room: $roomId');
        log('フェッチ前で２秒後goprovider ${ref.read(goProvider)}');
        final initialData = await supabase.rpc(
          'get_room_data',
          params: {
            'p_room_id': roomId,
          },
        );
        // single()は結果が1行でないとエラーを投げるので堅牢
        state = MatchingRoom.fromMap(initialData);
        log('${initialData['player2_id']}');
        if (isdisposed) return;
        // すでにplayer2がいる場合（レースコンディションでstreamが見逃したケース）
        if (initialData['player2_id'] != null && !hasNavigatedToChose) {
          hasNavigatedToChose = true;
          final otherUserId =
              state.player1Id == userId ? state.player2Id : state.player1Id;
          await ref
              .read(otherUserProvider.notifier)
              .fetchOtherUserWithRetry(otherUserId!);
          ref.read(goProvider.notifier).state = true;
          log('フェッチ後goprovider ${ref.read(goProvider)}');
        }
      } catch (e) {
        log('初期フェッチ中にエラーが発生: $e');
      }
    }
  }

  Future<void> cancelMatching(String roomId) async {
    final userId = ref.read(currentUserIdProvider);
    final response = await supabase.rpc('deleteroom', params: {
      'p_room_id': roomId,
      'p_user_id': userId,
    });
    if (response['success'] == true) {
      isdisposed = true;
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
      router.go('/home');
    }
  }

  Future<void> updateChoice(
      String roomId, String player, bool choice, int maxRetries) async {
    final which =
        player == state.player1Id ? 'player1_choice' : 'player2_choice';
    for (int i = 0; i < maxRetries; i++) {
      try {
        await supabase.from('rooms').update({
          which: choice,
        }).eq('id', roomId);
        return;
      } catch (e) {
        if (i < maxRetries - 1) {
          // 最後の試行でなければ、少し待ってからリトライ
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } // すべての試行が失敗した場合
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
    for (int i = 0; i < 3; i++) {
      if (room.result == null) {
        try {
          await supabase.from('rooms').update({
            'result': '$which オフラインになりました',
          }).eq('id', room.roomId!);
          return;
        } catch (e) {
          if (i < 2) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
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
