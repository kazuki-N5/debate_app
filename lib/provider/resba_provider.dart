// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/match_error_provider.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/widgets/resba_host_queue_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ポスト（+そのコメント）に付いたレスバ一覧
final postResbaProvider =
    StateNotifierProvider.autoDispose.family<PostResbaNotifier, AsyncValue<List<ResbaInvite>>, String>(
        (ref, postId) => PostResbaNotifier(ref, postId));

class PostResbaNotifier extends StateNotifier<AsyncValue<List<ResbaInvite>>> {
  final Ref ref;
  final String postId;
  PostResbaNotifier(this.ref, this.postId) : super(const AsyncValue.loading()) {
    fetch();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  Future<void> fetch() async {
    try {
      final myId = ref.read(currentUserIdProvider);
      debugPrint('[RESBA_LOG] PostResbaNotifier.fetch started for postId: $postId, myId: $myId');
      final response = await supabase.rpc('get_post_resbas', params: {
        'p_post_id': postId,
        'p_user_id': myId,
      });
      debugPrint('[RESBA_LOG] PostResbaNotifier.fetch response: $response (type: ${response.runtimeType})');

      List<dynamic> rawList = [];
      if (response is List) {
        rawList = response;
      } else if (response is String) {
        // JSON文字列の場合
        rawList = (response.isNotEmpty) ? (jsonDecode(response) as List) : [];
      }

      final list = rawList
          .map((e) => ResbaInvite.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[RESBA_LOG] PostResbaNotifier.fetch parsed ${list.length} invites.');
      for (final inv in list) {
        debugPrint('[RESBA_LOG]  - invite id: ${inv.id}, attachType: ${inv.attachType}, attachId: ${inv.attachId}, status: ${inv.status}, isSender: ${inv.isSender}, myApp: ${inv.myApplication}');
      }
      state = AsyncValue.data(list);
    } catch (e, st) {
      debugPrint('[RESBA_LOG] PostResbaNotifier.fetch ERROR: $e\n$st');
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// DMルームに付いたレスバ一覧
final dmResbaProvider =
    StateNotifierProvider.autoDispose.family<DmResbaNotifier, AsyncValue<List<ResbaInvite>>, String>(
        (ref, roomId) => DmResbaNotifier(ref, roomId));

class DmResbaNotifier extends StateNotifier<AsyncValue<List<ResbaInvite>>> {
  final Ref ref;
  final String roomId;
  RealtimeChannel? _channel;
  bool _isDisposed = false;
  bool _isReconnecting = false;

  DmResbaNotifier(this.ref, this.roomId) : super(const AsyncValue.loading()) {
    _init();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  void _init({String reason = '初回接続'}) async {
    if (_channel != null) {
      final old = _channel!;
      _channel = null;
      try {
        await supabase.removeChannel(old);
      } catch (_) {}
    }
    if (_isDisposed || !mounted) return;

    log('🔌 [DMレスバ一覧] 接続開始 (理由: $reason, roomId: $roomId)');
    final channel = supabase.channel('dm-resba-$roomId');
    _channel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'attach_type',
            value: 'dm',
          ),
          callback: (_) => fetch(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_invite_applications',
          callback: (_) => fetch(),
        )
        .subscribe((status, [error]) async {
          if (_isDisposed || !mounted || _channel != channel) return;

          if (status == RealtimeSubscribeStatus.subscribed) {
            log('✅ [DMレスバ一覧] 接続成功 (理由: $reason, roomId: $roomId)');
            _isReconnecting = false;
            await fetch();
          } else if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            if (_isReconnecting) return;
            _isReconnecting = true;
            log('⚠️ [DMレスバ一覧] 切断/エラー/タイムアウト検知 (status: $status, error: $error) ➔ 3秒後に再接続');
            await Future.delayed(const Duration(seconds: 3));
            if (!mounted || _isDisposed || _channel != channel) {
              _isReconnecting = false;
              return;
            }
            _isReconnecting = false;
            _init(reason: '再接続 ($status)');
          }
        });
  }

  Future<void> fetch() async {
    try {
      final response = await supabase.rpc('get_dm_resbas', params: {
        'p_room_id': roomId,
        'p_user_id': ref.read(currentUserIdProvider),
      });
      final list = (response as List)
          .map((e) => ResbaInvite.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_channel != null) {
      try {
        supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
    super.dispose();
  }
}

/// レスバ1件を取得（通知タップ時などの詳細表示用）
final resbaInviteProvider =
    StateNotifierProvider.autoDispose.family<ResbaInviteNotifier,
        AsyncValue<ResbaInvite?>, String>((ref, inviteId) {
  return ResbaInviteNotifier(ref, inviteId);
});

class ResbaInviteNotifier extends StateNotifier<AsyncValue<ResbaInvite?>> {
  final Ref ref;
  final String inviteId;
  ResbaInviteNotifier(this.ref, this.inviteId)
      : super(const AsyncValue.loading()) {
    fetch();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  Future<void> fetch() async {
    try {
      final r = await supabase.rpc('get_resba_invite', params: {
        'p_invite_id': inviteId,
        'p_user_id': ref.read(currentUserIdProvider),
      });
      if (r == null) {
        state = const AsyncValue.data(null);
      } else {
        state =
            AsyncValue.data(ResbaInvite.fromJson(r as Map<String, dynamic>));
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// レスバのアクション（クエリ非依存）。返り値: (エラー文言 or null, 成立時のroomId)
typedef ResbaResult = ({String? error, String? roomId});

/// 自分の対戦状態（get_my_resba_status の結果）
class ResbaStatus {
  final String state; // free / proposing / applying / invited / battle
  final int pendingApplicationCount;
  final int pendingSenderCount;
  final int pendingTargetCount;

  const ResbaStatus({
    this.state = 'free',
    this.pendingApplicationCount = 0,
    this.pendingSenderCount = 0,
    this.pendingTargetCount = 0,
  });

  /// 応募中（ポスト型の応募 pending）かどうか
  bool get isApplying => pendingApplicationCount > 0;
}

final resbaActionsProvider = Provider<ResbaActions>((ref) => ResbaActions(ref));

class ResbaActions {
  final Ref ref;
  ResbaActions(this.ref);

  SupabaseClient get supabase => ref.read(supabaseProvider);

  String? get _userId => ref.read(currentUserIdProvider);

  /// 返信コメントにレスバを添付
  Future<ResbaResult> attachToComment({
    required String commentId,
    required String theme,
    String? choice1,
    String? choice2,
  }) =>
      _invoke('attach_resba_to_comment', {
        'p_sender_id': _userId,
        'p_comment_id': commentId,
        'p_theme': theme,
        'p_choice1': choice1 ?? '',
        'p_choice2': choice2 ?? '',
      });

  /// ポストにレスバを付ける
  Future<ResbaResult> createPostResba({
    required String postId,
    required String theme,
    String? choice1,
    String? choice2,
  }) =>
      _invoke('create_post_resba', {
        'p_sender_id': _userId,
        'p_post_id': postId,
        'p_theme': theme,
        'p_choice1': choice1 ?? '',
        'p_choice2': choice2 ?? '',
      });

  /// DMメッセージにレスバを添付(募集型: 誰でも応募可)
  Future<ResbaResult> sendDmResba({
    required String messageId,
    required String theme,
    String? choice1,
    String? choice2,
  }) =>
      _invoke('send_dm_resba', {
        'p_sender_id': _userId,
        'p_message_id': messageId,
        'p_theme': theme,
        'p_choice1': choice1 ?? '',
        'p_choice2': choice2 ?? '',
      });

  /// オープンチャットメッセージにレスバを添付(募集型)
  Future<ResbaResult> createOpenChatResba({
    required String messageId,
    required String theme,
    String? choice1,
    String? choice2,
  }) =>
      _invoke('create_open_chat_resba', {
        'p_sender_id': _userId,
        'p_message_id': messageId,
        'p_theme': theme,
        'p_choice1': choice1 ?? '',
        'p_choice2': choice2 ?? '',
      });

  /// 対戦募集(添付なしの募集型レスバ)を作成
  Future<ResbaResult> createRecruitResba({
    required String theme,
    String? choice1,
    String? choice2,
  }) =>
      _invoke('create_recruit_resba', {
        'p_sender_id': _userId,
        'p_theme': theme,
        'p_choice1': choice1 ?? '',
        'p_choice2': choice2 ?? '',
      });

  /// ポスト型レスバへの応募（⚔️ 応じる）
  Future<ResbaResult> apply(String inviteId) async {
    try {
      final response = await supabase.rpc('apply_post_resba', params: {
        'p_invite_id': inviteId,
        'p_user_id': _userId,
      });
      if (response['success'] == true) {
        if (response['application'] != null) {
          final info = ApplyingInfo.fromJson(
              response['application'] as Map<String, dynamic>);
          ref.read(applyingInfoProvider.notifier).setApplication(info);
        } else {
          ref.read(applyingInfoProvider.notifier).fetch();
        }
        return (error: null, roomId: null);
      }
      return (error: _errorMessage(response['error']), roomId: null);
    } catch (e) {
      log('resba apply_post_resba error: $e');
      return (error: _errorMessage('UNKNOWN'), roomId: null);
    }
  }

  /// ポスト型レスバの承認・拒否（投稿者・1件ずつ処理）。承認時は roomId を返す
  Future<ResbaResult> approveApplication(
      String inviteId, String applicationId, bool approve) async {
    try {
      final response = await supabase.rpc('approve_post_resba', params: {
        'p_invite_id': inviteId,
        'p_application_id': applicationId,
        'p_host_id': _userId,
        'p_approve': approve,
      });
      if (response['success'] == true) {
        return (error: null, roomId: response['room_id'] as String?);
      }
      return (error: _errorMessage(response['error']), roomId: null);
    } catch (e) {
      log('approve_post_resba error: $e');
      return (error: _errorMessage('UNKNOWN'), roomId: null);
    }
  }

  /// 送信者がレスバを取り下げ
  Future<ResbaResult> cancel(String inviteId) => _invoke('cancel_resba', {
        'p_invite_id': inviteId,
        'p_sender_id': _userId,
      });

  /// 応募者（ポスト型）が応募を取り下げ
  Future<ResbaResult> cancelApplication(String inviteId) =>
      _invoke('cancel_post_resba_application', {
        'p_invite_id': inviteId,
        'p_user_id': _userId,
      });

  /// 自分の応募中（pending）の応募をすべて取り消す（ランダムマッチ開始前など）
  Future<ResbaResult> cancelMyPendingApplications() =>
      _invoke('cancel_my_pending_applications', {
        'p_user_id': _userId,
      });

  /// 自分がホストの「保留中の応募」全件（古い順・応募キュー表示用）
  Future<List<HostApplication>> getMyPendingHostApplications() async {
    try {
      debugPrint('[RESBA_LOG] getMyPendingHostApplications started for userId: $_userId');
      final response = await supabase.rpc(
          'get_my_pending_host_applications', params: {
        'p_user_id': _userId,
      });
      debugPrint('[RESBA_LOG] getMyPendingHostApplications response: $response (type: ${response.runtimeType})');

      List<dynamic> rawList = [];
      if (response is List) {
        rawList = response;
      } else if (response is String) {
        rawList = response.isNotEmpty ? (jsonDecode(response) as List) : [];
      }

      final list = rawList
          .map((e) => HostApplication.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[RESBA_LOG] getMyPendingHostApplications parsed ${list.length} applications.');
      return list;
    } catch (e, st) {
      debugPrint('[RESBA_LOG] getMyPendingHostApplications ERROR: $e\n$st');
      return [];
    }
  }

  /// 自分が送信したレスバ一覧（マイレスバ）
  Future<List<ResbaInvite>> getMySentResbas() async {
    try {
      final response = await supabase.rpc('get_my_sent_resbas', params: {
        'p_user_id': _userId,
      });
      return (response as List)
          .map((e) => ResbaInvite.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('get_my_sent_resbas error: $e');
      return [];
    }
  }

  /// レスバを完全削除（自分が送信・対戦中以外のみ）
  Future<ResbaResult> deleteResba(String inviteId) =>
      _invoke('delete_resba', {
        'p_invite_id': inviteId,
        'p_sender_id': _userId,
      });

  /// 自分の放置ルーム（15分以上更新なし）を即終了（アプリ起動時などに呼ぶ）
  Future<void> finalizeUserStaleRoom() async {
    final myId = _userId;
    if (myId == null) return;
    try {
      await supabase.rpc('finalize_user_stale_room', params: {
        'p_user_id': myId,
      });
    } catch (e) {
      log('finalize_user_stale_room error: $e');
    }
  }

  /// 前の試合（進行中ルーム）をすべて「負け（相手勝ち）」にして解除（ランダムマッチ前など）
  /// ※ is_user_in_battle は解決型: 進行中ルームを負けにして false を返す副作用を持つ
  Future<void> resolveMyBattle() async {
    final myId = _userId;
    if (myId == null) return;
    try {
      await supabase.rpc('is_user_in_battle', params: {
        'p_user_id': myId,
      });
    } catch (e) {
      log('resolveMyBattle error: $e');
    }
  }

  /// 自分の対戦状態を取得（ランダムマッチ開始前の応募中チェック用）
  Future<ResbaStatus> getMyResbaStatus() async {
    try {
      final r = await supabase.rpc('get_my_resba_status', params: {
        'p_user_id': _userId,
      });
      return ResbaStatus(
        state: r['state'] as String? ?? 'free',
        pendingApplicationCount:
            (r['pending_application_count'] as num?)?.toInt() ?? 0,
        pendingSenderCount: (r['pending_sender_count'] as num?)?.toInt() ?? 0,
        pendingTargetCount: (r['pending_target_count'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      log('get_my_resba_status error: $e');
      return const ResbaStatus();
    }
  }

  Future<ResbaResult> _invoke(String fn, Map<String, dynamic> params) async {
    try {
      final response = await supabase.rpc(fn, params: params);
      if (response['success'] == true) {
        return (error: null, roomId: null);
      }
      return (error: _errorMessage(response['error']), roomId: null);
    } catch (e) {
      log('resba $fn error: $e');
      return (error: _errorMessage('UNKNOWN'), roomId: null);
    }
  }

  String _errorMessage(dynamic code) {
    const errorCodeMap = {
      'INVITE_NOT_FOUND': '8101',
      'INVITE_CLOSED': '8102',
      'APPLICATION_NOT_FOUND': '8103',
      'APPLICATION_CLOSED': '8104',
      'SENDER_IN_BATTLE': '8105',
      'APPLICANT_IN_BATTLE': '8105',
      'IN_BATTLE': '8106',
      'NOT_TARGET': '8107',
      'NOT_HOST': '8107',
      'NOT_POST_OWNER': '8107',
      'NOT_COMMENT_OWNER': '8107',
      'NOT_MESSAGE_OWNER': '8107',
      'BLOCKED': '8108',
      'ROOM_JOIN_FAILED': '8109',
      'RECRUITMENT_LIMIT_EXCEEDED': '8110',
      'ALREADY_APPLYING': '8111',
      'ALREADY_APPLIED': '8112',
      'SELF_INVITE': '8113',
      'SELF_APPLY': '8113',
      'POST_NOT_FOUND': '8114',
      'COMMENT_NOT_FOUND': '8114',
      'MESSAGE_NOT_FOUND': '8114',
    };
    final numericCode = errorCodeMap[code?.toString()] ?? '8999';
    return 'エラーが発生しました（エラーコード: $numericCode）';
  }
}

/// レスバの「対戦成立」をリアルタイムで検知し、バトル画面（/wait）へ遷移するリスナー
///  - 送信者側: 自分の battle_invites が accepted になったら
///  - 応募者側: 自分の battle_invite_applications が accepted になったら
///  - ホスト側: 自分のレスバへの応募を検知 → 応募キューを更新 → キュー表示ダイアログ
/// ※ autoDispose にしない: アプリ全体で購読を維持するため
final resbaMatchListenerProvider =
    StateNotifierProvider<ResbaMatchListener, bool>((ref) {
  return ResbaMatchListener(ref);
});

/// ホスト側の「保留中の応募キュー」（古い順・アプリ全体で保持）
///  - Realtime / ポーリング / アプリ復帰 / 承認・拒否のたびに fetch() される
final pendingHostApplicationsProvider = StateNotifierProvider<
    PendingHostApplicationsNotifier, AsyncValue<List<HostApplication>>>((ref) {
  return PendingHostApplicationsNotifier(ref);
});

class PendingHostApplicationsNotifier
    extends StateNotifier<AsyncValue<List<HostApplication>>> {
  final Ref ref;
  PendingHostApplicationsNotifier(this.ref)
      : super(const AsyncValue.data(<HostApplication>[]));

  Future<void> fetch() async {
    final list =
        await ref.read(resbaActionsProvider).getMyPendingHostApplications();
    state = AsyncValue.data(list);
  }
}

class ResbaMatchListener extends StateNotifier<bool> {
  final Ref ref;
  ResbaMatchListener(this.ref) : super(false) {
    // 対戦中のバトルが終了したら（winner確定・ルーム破棄など）保留中の応募を再確認
    ref.listen(matchingRoomProvider, (previous, next) {
      final prevWinner = previous?.winner;
      final nextWinner = next.winner;
      if ((prevWinner == null && nextWinner != null) ||
          (previous?.roomId != null && next.roomId == null)) {
        _refreshHostQueue();
      }
    });
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;
  final Set<String> _handledRoomIds = {};
  bool _dialogOpen = false;

  String? get _userId => ref.read(currentUserIdProvider);

  /// 現在進行中のバトル（rooms_v2 で winner 未確定）に参加しているか
  bool _isReconnecting = false;

  bool get _inBattle {
    final room = ref.read(matchingRoomProvider);
    return room.roomId != null && room.winner == null;
  }

  Future<void> _scheduleReconnect(RealtimeChannel channel, [String reason = '切断']) async {
    if (_isReconnecting || _channel != channel) return;
    _isReconnecting = true;
    log('⚠️ [レスバ対戦検知リスナー] 切断/エラー/タイムアウト検知 (理由: $reason) ➔ 3秒後に再接続');
    await Future.delayed(const Duration(seconds: 3));
    if (_channel != channel) {
      _isReconnecting = false;
      return;
    }
    _cleanupChannel();
    _isReconnecting = false;
    start(reason: '再接続 ($reason)');
  }

  void _cleanupChannel() {
    state = false;
    if (_channel != null) {
      final old = _channel!;
      _channel = null;
      try {
        supabase.removeChannel(old);
      } catch (_) {}
    }
  }

  Future<void> start({String reason = '初回接続'}) async {
    final myId = _userId;
    if (myId == null) {
      // 認証セッション復元前: サインイン後に再実行する
      _ensureAuthRetry();
      return;
    }
    if (state && _channel != null) return;

    _cleanupChannel();
    state = true;

    log('🔌 [レスバ対戦検知リスナー] 接続開始 (理由: $reason, userId: $myId)');

    // 1つのチャンネルに2つのリスナー（レンズ）を取り付ける
    final channel = supabase.channel('resba-listener-$myId');
    _channel = channel;

    channel
        // ① 送信者側レンズ: 自分のレスバが承諾されたら
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'battle_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: myId,
          ),
          callback: (payload) async {
            final newData = payload.newRecord;
            log('realtime[resba-sender] event: status=${newData['status']}');
            if (newData['status'] == 'accepted') {
              final roomId = newData['battle_room_id']?.toString();
              if (roomId != null) await navigateToBattle(roomId);
            } else if (newData['status'] == 'declined') {
              ref.read(matchErrorServiceProvider).showMatchEndMessage('拒否されました', 0.68);
            }
          },
        )
        // ② ホスト側レンズ: 自分のレスバへの応募 INSERT → 応募キューを更新
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_invite_applications',
          callback: (payload) async {
            log('realtime[resba-host] application change event');
            await _refreshHostQueue();
          },
        )
        .subscribe((status, [error]) {
          if (_channel != channel) return;
          log('realtime[resba-listener] state=$status${error != null ? ' error=$error' : ''}');
          // 購読確立（初回・再接続時）に現在の応募キューを再取得する
          if (status == RealtimeSubscribeStatus.subscribed) {
            log('✅ [レスバ対戦検知リスナー] 接続成功 (理由: $reason, userId: $myId)');
            _isReconnecting = false;
            _refreshHostQueue();
          } else if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            _scheduleReconnect(channel, '$status${error != null ? ' ($error)' : ''}');
          }
        });

    // 開始時の未対応応募をキューに反映（あればダイアログ表示）
    await _refreshHostQueue();
  }

  /// 認証セッションが復元されたら start() を再実行する
  void _ensureAuthRetry() {
    _authSub ??= supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _authSub?.cancel();
        _authSub = null;
        start();
      }
    });
  }

  /// 応募キューを再取得し、未対応があればダイアログを開く（外部からの呼び出し用）
  Future<void> checkAndShowPendingDialog() async {
    await _refreshHostQueue();
  }

  /// 応募キューを再取得し、未対応があればダイアログを開く
  Future<void> _refreshHostQueue() async {
    debugPrint('[RESBA_LOG] _refreshHostQueue triggered. dialogOpen=$_dialogOpen, inBattle=$_inBattle');
    await ref.read(pendingHostApplicationsProvider.notifier).fetch();
    if (!_dialogOpen) await _maybeOpenQueueDialog();
  }

  /// 応募が溜まっていたら「応募キュー」ダイアログを開く（同時に1つだけ）
  Future<void> _maybeOpenQueueDialog() async {
    if (_dialogOpen) {
      debugPrint('[RESBA_LOG] _maybeOpenQueueDialog skipped: dialog already open');
      return;
    }
    // 対戦フロー中（待機・選択・試合・リザルト）はダイアログを表示しない
    if (_inBattle) {
      debugPrint('[RESBA_LOG] _maybeOpenQueueDialog skipped: user is in battle');
      return;
    }
    try {
      final currentPath =
          router.routerDelegate.currentConfiguration.uri.path;
      const battlePaths = {'/wait', '/chose', '/game', '/finish'};
      if (battlePaths.contains(currentPath)) {
        debugPrint('[RESBA_LOG] _maybeOpenQueueDialog skipped: currentPath=$currentPath is battlePath');
        return;
      }
    } catch (_) {}

    final items = ref
            .read(pendingHostApplicationsProvider)
            .valueOrNull ??
        const <HostApplication>[];
    debugPrint('[RESBA_LOG] _maybeOpenQueueDialog items count: ${items.length}');
    if (items.isEmpty) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint('[RESBA_LOG] _maybeOpenQueueDialog skipped: navigatorKey.currentContext is null');
      return;
    }
    _dialogOpen = true;
    try {
      debugPrint('[RESBA_LOG] Showing showHostApplicationQueueDialog with ${items.length} items!');
      await showHostApplicationQueueDialog(ref);
    } finally {
      _dialogOpen = false;
      debugPrint('[RESBA_LOG] showHostApplicationQueueDialog closed.');
    }
  }

  Future<void> navigateToBattle(String roomId) async {
    if (_handledRoomIds.contains(roomId)) return;
    _handledRoomIds.add(roomId);

    final room = ref.read(matchingRoomProvider);
    // 既に同一ルームで対戦中なら重複遷移をスキップ
    if (room.roomId == roomId && room.winner == null) {
      log('⚔️ resba navigate skipped: 同一ルームで既に対戦中 (roomId=$roomId)');
      return;
    }

    try {
      await ref.read(matchingRoomProvider.notifier).joinBbsRoom(roomId);
      router.go('/wait');
    } catch (e) {
      log('resba navigate error: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cleanupChannel();
    super.dispose();
  }
}

/// 自分が応募中のレスバ情報（応募中バナー・入れ替え確認用）
class ApplyingInfo {
  final String applicationId;
  final String inviteId;
  final String theme;
  final String? choice1;
  final String? choice2;
  final String? hostName;
  final String? hostAvatar;
  final String attachType;
  final String attachId;
  final String status; // pending / rejected / cancelled
  final DateTime createdAt;

  const ApplyingInfo({
    required this.applicationId,
    required this.inviteId,
    required this.theme,
    this.choice1,
    this.choice2,
    this.hostName,
    this.hostAvatar,
    required this.attachType,
    required this.attachId,
    required this.status,
    required this.createdAt,
  });

  factory ApplyingInfo.fromJson(Map<String, dynamic> json) {
    return ApplyingInfo(
      applicationId: json['application_id'] as String,
      inviteId: json['invite_id'] as String,
      theme: json['theme'] as String? ?? '',
      choice1: json['choice1'] as String?,
      choice2: json['choice2'] as String?,
      hostName: json['host_name'] as String?,
      hostAvatar: json['host_avatar'] as String?,
      attachType: json['attach_type'] as String? ?? '',
      attachId: json['attach_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';
}

/// 応募中バナー用プロバイダ（アプリ全体で購読・タブ切替と無関係に常駐）
final applyingInfoProvider =
    StateNotifierProvider<ApplyingInfoNotifier, AsyncValue<ApplyingInfo?>>(
        (ref) {
  return ApplyingInfoNotifier(ref);
});

class ApplyingInfoNotifier extends StateNotifier<AsyncValue<ApplyingInfo?>> {
  final Ref ref;
  RealtimeChannel? _channel;
  bool _isDisposed = false;
  bool _isReconnecting = false;
  bool _isManualCancelling = false;

  ApplyingInfoNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  Future<void> _init({String reason = '初回接続'}) async {
    final myId = ref.read(currentUserIdProvider);
    if (myId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    if (_channel != null) {
      final old = _channel!;
      _channel = null;
      try {
        await supabase.removeChannel(old);
      } catch (_) {}
    }
    if (_isDisposed || !mounted) return;

    log('🔌 [レスバ応募中バナー] 接続開始 (理由: $reason, userId: $myId)');
    await fetch();
    // 自分の応募の INSERT / UPDATE（承認・拒否・取消）を購読して即時反映
    final channel = supabase.channel('resba-applying-$myId');
    _channel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_invite_applications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'applicant_id',
            value: myId,
          ),
          callback: (payload) async {
            final newData = payload.newRecord;
            log('realtime[resba-applying] event: status=${newData['status']}');
            final status = newData['status'] as String?;
            if (status == 'rejected') {
              // ホストに拒否された: 「拒否されました」を白いテキストで表示する
              ref.read(matchErrorServiceProvider).showMatchEndMessage('拒否されました', 0.68);
              state = const AsyncValue.data(null);
            } else if (status == 'cancelled') {
              // ホストによる取り下げ、または24時間期限切れ/システム削除時
              if (!_isManualCancelling) {
                ref.read(matchErrorServiceProvider).showMatchEndMessage('削除されました', 0.68);
              }
              _isManualCancelling = false;
              state = const AsyncValue.data(null);
            } else if (status == 'accepted') {
              // 承認されて対戦が成立した場合、画面遷移を行う（元のresba-applicantの機能）
              final inviteId = newData['invite_id']?.toString();
              if (inviteId != null) {
                try {
                  final invite = await supabase
                      .from('battle_invites')
                      .select('battle_room_id')
                      .eq('id', inviteId)
                      .maybeSingle();
                  final roomId = invite?['battle_room_id']?.toString();
                  if (roomId != null) {
                    await ref.read(resbaMatchListenerProvider.notifier).navigateToBattle(roomId);
                  }
                } catch (e) {
                  log('failed to navigate to battle on accepted: $e');
                }
              }
              fetch(); // 成立後はバナーを消すためにfetch
            } else {
              fetch();
            }
          },
        )
        .subscribe((status, [error]) async {
          if (_isDisposed || !mounted || _channel != channel) return;
          log('realtime[resba-applying] state=$status${error != null ? ' error=$error' : ''}');
          if (status == RealtimeSubscribeStatus.subscribed) {
            log('✅ [レスバ応募中バナー] 接続成功 (理由: $reason, userId: $myId)');
            _isReconnecting = false;
            // 購読完了時（初回・再接続時）に取りこぼしがないよう再フェッチ
            await fetch();
          } else if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            if (_isReconnecting) return;
            _isReconnecting = true;
            log('⚠️ [レスバ応募中バナー] 切断/エラー/タイムアウト検知 (status: $status, error: $error) ➔ 3秒後に再接続');
            // 切断・エラー・タイムアウト時は数秒待ってから再接続を試みる
            await Future.delayed(const Duration(seconds: 3));
            if (!mounted || _isDisposed || _channel != channel) {
              _isReconnecting = false;
              return;
            }
            _isReconnecting = false;
            _init(reason: '再接続 ($status)'); // チャンネルを作り直す
          }
        });
  }

  Future<void> fetch() async {
    try {
      final r = await supabase.rpc('get_my_pending_application', params: {
        'p_user_id': ref.read(currentUserIdProvider),
      });
      if (r == null) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.data(ApplyingInfo.fromJson(r));
      }
    } catch (e) {
      log('get_my_pending_application error: $e');
      state = const AsyncValue.data(null);
    }
  }

  /// 応募成功時の即時反映（RPC返答から直接セット）
  void setApplication(ApplyingInfo info) {
    state = AsyncValue.data(info);
  }

  /// 応募を取り消す（バナーから）
  Future<void> cancelApplication() async {
    _isManualCancelling = true;
    await ref.read(resbaActionsProvider).cancelMyPendingApplications();
    await fetch();
  }

  /// 拒否・取消の表示をすぐに消す（バナーを非表示にする）
  void clear() {
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_channel != null) {
      try {
        supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
    super.dispose();
  }
}

// ============================================================
// 対戦募集(recruit型)・オープンチャット(open_chat型)レスバの一覧
// ============================================================

/// 募集中の対戦募集(recruit型レスバ)一覧
final recruitResbasProvider = StateNotifierProvider<RecruitResbasNotifier,
    AsyncValue<List<ResbaInvite>>>((ref) {
  return RecruitResbasNotifier(ref);
});

class RecruitResbasNotifier
    extends StateNotifier<AsyncValue<List<ResbaInvite>>> {
  final Ref ref;

  RecruitResbasNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  Future<void> fetch() async {
    try {
      final r = await supabase.rpc('get_recruit_resbas', params: {
        'p_user_id': ref.read(currentUserIdProvider),
      });
      // ブロック済みユーザーの募集は表示しない
      final blocked = ref.read(blockedUserIdsProvider).toSet();
      final list = (r as List<dynamic>)
          .map((e) => ResbaInvite.fromJson(e as Map<String, dynamic>))
          .where((invite) => !blocked.contains(invite.senderId))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      log('get_recruit_resbas error: $e');
      state = AsyncValue.error(e, st);
    }
  }
}

/// オープンチャットルームのレスバ一覧(メッセージに添付された募集型)
final openChatResbasProvider =
    StateNotifierProvider.autoDispose.family<OpenChatResbasNotifier, AsyncValue<List<ResbaInvite>>, String>(
        (ref, roomId) => OpenChatResbasNotifier(ref, roomId));

class OpenChatResbasNotifier extends StateNotifier<AsyncValue<List<ResbaInvite>>> {
  final Ref ref;
  final String roomId;
  RealtimeChannel? _channel;
  bool _isDisposed = false;
  bool _isReconnecting = false;

  OpenChatResbasNotifier(this.ref, this.roomId) : super(const AsyncValue.loading()) {
    _init();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  void _init({String reason = '初回接続'}) async {
    if (_channel != null) {
      final old = _channel!;
      _channel = null;
      try {
        await supabase.removeChannel(old);
      } catch (_) {}
    }
    if (_isDisposed || !mounted) return;

    log('🔌 [オプチャレスバ一覧] 接続開始 (理由: $reason, roomId: $roomId)');
    final channel = supabase.channel('open-chat-resba-$roomId');
    _channel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'attach_type',
            value: 'open_chat',
          ),
          callback: (_) => fetch(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_invite_applications',
          callback: (_) => fetch(),
        )
        .subscribe((status, [error]) async {
          if (_isDisposed || !mounted || _channel != channel) return;

          if (status == RealtimeSubscribeStatus.subscribed) {
            log('✅ [オプチャレスバ一覧] 接続成功 (理由: $reason, roomId: $roomId)');
            _isReconnecting = false;
            await fetch();
          } else if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            if (_isReconnecting) return;
            _isReconnecting = true;
            log('⚠️ [オプチャレスバ一覧] 切断/エラー/タイムアウト検知 (status: $status, error: $error) ➔ 3秒後に再接続');
            await Future.delayed(const Duration(seconds: 3));
            if (!mounted || _isDisposed || _channel != channel) {
              _isReconnecting = false;
              return;
            }
            _isReconnecting = false;
            _init(reason: '再接続 ($status)');
          }
        });
  }

  Future<void> fetch() async {
    try {
      final r = await supabase.rpc('get_open_chat_resbas', params: {
        'p_room_id': roomId,
        'p_user_id': ref.read(currentUserIdProvider),
      });
      // オプチャ内ではブロックに関わらず全レスバを表示
      final list = (r as List<dynamic>)
          .map((e) => ResbaInvite.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      log('get_open_chat_resbas error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_channel != null) {
      try {
        supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
    super.dispose();
  }
}

// ホスト側の応募ダイアログは widgets/resba_host_queue_dialog.dart の
// showHostApplicationQueueDialog()（応募キュー・古い順・溜まる表示）に移行済み
