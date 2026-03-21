import 'dart:async';
import 'dart:developer';
import 'package:debate_project/modes/mathing.dart';
import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/history_provider.dart';
import 'package:debate_project/provider/message_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/view_model/Homepage_view_model.dart';
// import 'package:debate_project/views/Matching.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: implementation_imports
import 'package:realtime_client/src/types.dart' show ChannelFilter;

final matchingRoomProvider =
    StateNotifierProvider<MatchingRoomNotifier, MatchingRoom>((ref) {
  return MatchingRoomNotifier(ref);
});

// final goProvider = StateProvider<bool>((ref) => false);

class MatchingRoomNotifier extends StateNotifier<MatchingRoom>
    with WidgetsBindingObserver {
  final Ref ref;
  MatchingRoomNotifier(this.ref) : super(MatchingRoom());

  SupabaseClient get supabase => ref.read(supabaseProvider);

  bool hasNavigatedToChose = false;
  bool hasgotomatching = false;
  bool hasgotochose = false;
  bool hassplash = false;
  bool isdisposed = false;
  RealtimeChannel? _subscription;
  RealtimeChannel? _presenceChannel;
  Timer? _offlineTimer;
  int _countdownSeconds = 20; // 追加

  // 相手のIDを特定するヘルパー
  String? get _opponentId {
    final myId = ref.read(currentUserIdProvider);
    if (state.player1Id == myId) return state.player2Id;
    if (state.player2Id == myId) return state.player1Id;
    return null;
  }

//アプリのライフサイクルでホームに戻ったときと戻ったときの丁稚　キャンセルマッチを実装
  Future<void> fetchmatchupdate() async {
    try {
      final roomdata = await supabase
          .from('rooms')
          .select()
          .eq('id', state.roomId!)
          .single();

      if (!isdisposed) {
        state = MatchingRoom.fromMap(roomdata);
      }

      // gomatchstate();
    } catch (e) {
      log(e.toString());
    }
  }

  // gomatchstateはUI側のref.listenで代用するため削除します
  // void gomatchstate() async { ... }

  void setupPresenceChannel(String roomId) {
    // 既存のチャンネルがあればクリーンアップ
    if (_presenceChannel != null) {
      supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }


    // チャンネルの作成 (両ユーザーで共通のroomIdをKeyとして指定)
    _presenceChannel = supabase.channel(
      roomId,
      opts: RealtimeChannelConfig(
        key: roomId,
      ),
    );
    // 【GitHub Issue #43561 回避策：Dart版実装】
    // 高レイヤーのonPresenceSync/Join/Leaveが本番環境で発火しない不具合があるため、
    // 内部的な Phoenix イベントである 'presence_state' と 'presence_diff' を直接リスニングします。
    _presenceChannel!
        // ignore: invalid_use_of_internal_member
        .onEvents(
          'presence_state',
          ChannelFilter(),
          (payload, [ref]) {
            log('★★★ MANUAL Presence State (RAW): $payload');
            final currentPresences = _presenceChannel!.presenceState();
            log('--- Current Presences Total: ${currentPresences.length}');
            
            // 初期状態チェック: 相手がいなければタイマー開始
            final opponentId = _opponentId;
            if (opponentId != null) {
              final isOpponentOnline = currentPresences.any((p) {
                return p.presences.any((meta) => meta.payload['user_id'] == opponentId);
              });
              if (!isOpponentOnline) {
                _startOfflineTimer();
              } else {
                _offlineTimer?.cancel();
              }
            }
          },
        )
        // ignore: invalid_use_of_internal_member
        .onEvents(
          'presence_diff',
          ChannelFilter(),
          (payload, [ref]) {
            log('★★★ MANUAL Presence Diff (RAW): $payload');
            final Map<String, dynamic> joins = payload['joins'] ?? {};
            final Map<String, dynamic> leaves = payload['leaves'] ?? {};
            final opponentId = _opponentId;

            if (opponentId != null) {
              // 相手が戻ってきたかチェック
              bool opponentJoined = joins.values.any((user) => 
                (user['metas'] as List).any((m) => m['user_id'] == opponentId));
              
              if (opponentJoined) {
                log('✅ 相手（$opponentId）が復帰しました。タイマーを停止します。');
                _offlineTimer?.cancel();
              }

              // 相手が離脱したかチェック
              bool opponentLeft = leaves.values.any((user) => 
                (user['metas'] as List).any((m) => m['user_id'] == opponentId));

              if (opponentLeft) {
                 _startOfflineTimer();
              }
            }
          },
        )
        .onBroadcast(
          event: 'test_hello',
          callback: (payload) {
            log('★★★ RECEIVED HELLO BROADCAST: $payload');
          },
        )
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            log('--- Subscribed to Realtime ---');
            // 自分の状態をトラック開始
            final myUserId = ref.read(currentUserIdProvider);
            await _presenceChannel!.track({
              'user_id': myUserId,
              'online_at': DateTime.now().toIso8601String(),
            });

            // 3秒後にテスト用のBroadcastを送る
            Future.delayed(const Duration(seconds: 3), () async {
              log('--- Sending test broadcast HELLO... ---');
              await _presenceChannel!.sendBroadcastMessage(
                event: 'test_hello',
                payload: {'from': myUserId, 'text': 'HELLO!'},
              );
            });
          }
        }); 
  }

  Future delete() async {
    hasNavigatedToChose = false;
    hasgotomatching = false;
    hasgotochose = false;
    // Future.microtask(() {
    //   ref.read(gochoseProvider.notifier).state = false;
    //   ref.read(splashProvider.notifier).state = false;
    //   ref.read(goProvider.notifier).state = false;
    // });
    isdisposed = false;
    hassplash = false;
    _offlineTimer?.cancel(); // タイマーの解除

    ref.read(chatProvider.notifier).unsubscribeFromMessages();
    if (_subscription != null) {
      try {
        // removeChannelを呼ぶと、untrackとunsubscribeが内部的に実行されます。
        await supabase.removeChannel(_subscription!);
        log('Subscription channel cleaned up.');
      } catch (e) {
        log('Error during subscription channel cleanup: $e');
      }
      _subscription = null;
    }

    if (_presenceChannel != null) {
      try {
        supabase.removeChannel(_presenceChannel!);
        log('Presence channel cleaned up.');
      } catch (e) {
        log('Error during presence channel cleanup: $e');
      }
      _presenceChannel = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _offlineTimer?.cancel(); // 追加
    log('All notifier resources cleaned up.');
  }

  void _startOfflineTimer() {
    if (_offlineTimer?.isActive ?? false) return;
    _countdownSeconds = 20; // カウントダウンのリセット
    log('⚠️ 相手がオフラインです。カウントダウンを開始します（20秒）');
    
    _offlineTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _countdownSeconds--;
      log('⏳ 相手の復帰待ち... 残り $_countdownSeconds 秒');

      if (_countdownSeconds <= 0) {
        timer.cancel();
        log('⌛ タイムアップ。相手が戻らなかったため勝利判定を処理します。');
        await win(state, ref.read(currentUserIdProvider)!);
      }
    });
  }

  Future<void> findMatch(
      String password, String theme, String choice1, String choice2) async {
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) {
      log('エラー: ユーザーが認証されていません。マッチングを開始できません。');
      ref.read(friendmatchProvider.notifier).state = false;
      return;
    }

    state = MatchingRoom();
    log('${state}');
    final appstate = await ref.read(appStateProvider.notifier).loadVersion();
    if (appstate == AppStatus.error) {
      log('エラーが発生しました');
      Future.microtask(
          () => ref.read(friendmatchProvider.notifier).state = false);
      return;
    } else if (appstate == AppStatus.forceUpdate) {
      Future.microtask(() {
        ref.read(forceboolProvider.notifier).state = true;
        ref.read(friendmatchProvider.notifier).state = false;
      });
      return;
    } else if (appstate == AppStatus.maintenance) {
      log('メンテナンス中');
      Future.microtask(() {
        ref.read(maintenanceboolProvider.notifier).state = true;
        ref.read(friendmatchProvider.notifier).state = false;
      });
      return;
    } else if (appstate == AppStatus.optionalUpdate) {
    } else if (appstate == AppStatus.normal) {
    } else {
      Future.microtask(
          () => ref.read(friendmatchProvider.notifier).state = false);
      return;
    }

    await delete();
    log(userId);
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
        log('マッチングエラー: ${result['error']}');
        ref.read(friendmatchProvider.notifier).state = false;
      }
    } catch (e) {
      log('インターネットに接続しましょう');
      ref.read(friendmatchProvider.notifier).state = false;
    }
  }

  Future<void> waitForMatch(String roomId) async {
    Future.microtask(() => ref.invalidate(matchRecordsProvider));
    if (isdisposed) return;
    try {
      _subscription = await supabase
          .channel('room-updates:$roomId')
          .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'rooms',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: roomId,
              ),
              callback: (payload) async {
                final newData = payload.newRecord;
                if (!isdisposed) {
                  state = MatchingRoom.fromMap(newData);
                  // gomatchstate();
                }
              })
          .subscribe((status, [error]) async {
        log('Subscription status: $status');
        if (status == RealtimeSubscribeStatus.subscribed) {
          log('Successfully subscribed. Fetching initial state.');
          // サブスクライブ成功時に初期データを取得することで、
          // 監視開始前に入っていた変更も確実に拾い、かつ冗長なループを回避します
          await fetchmatchupdate();
        } else if (status == RealtimeSubscribeStatus.channelError) {
          log('Subscription failed with error: ${error.toString()}');
        }
      });
      log('Subscription process initiated.');
    } catch (e) {
      log('Error during subscription setup: $e');
      cancelMatching(roomId);
      ref.read(friendmatchProvider.notifier).state = false;
      router.go('/home');
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
      router.go('/home');
    }
  }

  Future<void> updategochose(String roomId, String player) async {
    final which = player == state.player1Id ? 'player1_go' : 'player2_go';
    try {
      await supabase.from('rooms').update({
        which: true,
      }).eq('id', roomId);
      log('次に進むように変更が完了しました');
    } catch (e) {
      log(e.toString());
    }
  }

  Future<void> updateChoice(
      String roomId, String player, bool choice, int maxRetries) async {
    final which =
        player == state.player1Id ? 'player1_choice' : 'player2_choice';
    try {
      await supabase.from('rooms').update({
        which: choice,
      }).eq('id', roomId);
    } catch (e) {
      log('updateChoice failed: $e');
      rethrow;
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
      log('error');
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
      log('error');
    }
  }

  Future<void> finish(String roomId, String player) async {
    final which = player == state.player1Id ? 'B' : 'A';
    log(which);
    log(roomId);

    try {
      await supabase.from('rooms').update({
        'winner': which,
        'reason': '降参した',
      }).eq('id', roomId);
    } catch (e) {
      log('error');
    }
  }

  Future<void> win(MatchingRoom room, String player) async {
    final which = player == state.player1Id ? 'A' : 'B';
    if (room.winner == null) {
      try {
        await supabase.from('rooms').update({
          'winner': which,
          'reason': 'オフラインになりました',
        }).eq('id', room.roomId!);
        return;
      } catch (e) {}
    }
  }

  @override
  void dispose() {
    log('MatchingRoomNotifier disposed. Performing cleanup.');
    // クリーンアップ処理を行う delete() メソッドを呼び出します。
    delete();
    // 親クラスの dispose も必ず呼び出します。
    super.dispose();
  }
}
