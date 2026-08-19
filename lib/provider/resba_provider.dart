// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:async';
import 'dart:developer';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/widgets/resba_host_queue_dialog.dart';
import 'package:flutter/material.dart';
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
    _subscribeRealtime();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  RealtimeChannel? _channel;

  /// このポストに付いたレスバの変化（成立 → 対戦中 / 終了）をリアルタイム反映
  void _subscribeRealtime() {
    try {
      _channel = supabase
          .channel('post-resba-$postId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'battle_invites',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'attach_id',
              value: postId,
            ),
            callback: (payload) => fetch(),
          )
          .subscribe();
    } catch (e) {
      log('post resba realtime subscribe error: $e');
    }
  }

  Future<void> fetch() async {
    try {
      final response = await supabase.rpc('get_post_resbas', params: {
        'p_post_id': postId,
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
    if (_channel != null) supabase.removeChannel(_channel!);
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
  DmResbaNotifier(this.ref, this.roomId) : super(const AsyncValue.loading()) {
    fetch();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

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

  /// DMメッセージにレスバを添付
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

  /// 指名型（comment / dm）の承諾・拒否。承諾時は roomId を返す
  Future<ResbaResult> respond(String inviteId, bool approve) async {
    try {
      final response = await supabase.rpc('respond_resba', params: {
        'p_invite_id': inviteId,
        'p_user_id': _userId,
        'p_approve': approve,
      });
      if (response['success'] == true) {
        return (error: null, roomId: response['room_id'] as String?);
      }
      return (error: _errorMessage(response['error']), roomId: null);
    } catch (e) {
      log('respond_resba error: $e');
      return (error: 'エラーが発生しました: $e', roomId: null);
    }
  }

  /// ポスト型レスバへの応募（⚔️ 応じる）
  Future<ResbaResult> apply(String inviteId) => _invoke('apply_post_resba', {
        'p_invite_id': inviteId,
        'p_user_id': _userId,
      });

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
      return (error: 'エラーが発生しました: $e', roomId: null);
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

  /// 自分がホストの pending レスバ一覧（保留応募の表示用）を取得
  Future<List<ResbaInvite>> getMyPendingHostInvites() async {
    try {
      final response = await supabase.rpc('get_my_pending_host_invites', params: {
        'p_user_id': _userId,
      });
      return (response as List)
          .map((e) => ResbaInvite.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('get_my_pending_host_invites error: $e');
      return [];
    }
  }

  /// 自分がホストの「保留中の応募」全件（古い順・応募キュー表示用）
  Future<List<HostApplication>> getMyPendingHostApplications() async {
    try {
      final response = await supabase.rpc(
          'get_my_pending_host_applications', params: {
        'p_user_id': _userId,
      });
      return (response as List)
          .map((e) => HostApplication.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('get_my_pending_host_applications error: $e');
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

  /// 自分の放置ルーム（3分以上更新なし）を即終了（アプリ起動時などに呼ぶ）
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
      return (error: 'エラーが発生しました', roomId: null);
    }
  }

  String? _errorMessage(dynamic code) {
    if (code == 'IN_BATTLE') return '対戦中のため送信できません';
    if (code == 'SENDER_IN_BATTLE') return '相手が対戦中のため、今は承諾できません';
    if (code == 'APPLICANT_IN_BATTLE') return '応募者が対戦中のため、今は承認できません';
    if (code == 'RECRUITMENT_LIMIT_EXCEEDED') return '募集中のレスバが上限（3件）に達しています';
    if (code == 'ALREADY_APPLYING') return '現在応募中のレスバがあります。先にキャンセルしてください';
    if (code == 'ALREADY_APPLIED') return 'このレスバには応募済みです';
    if (code == 'INVITE_CLOSED') return 'このレスバは受付終了しています';
    if (code == 'NOT_TARGET') return 'このレスバの相手ではないため操作できません';
    if (code == 'NOT_HOST') return 'このレスバの投稿者ではないため操作できません';
    if (code == 'NOT_POST_OWNER') return '自分のポストにのみレスバを付けられます';
    if (code == 'SELF_INVITE' || code == 'SELF_APPLY') return '自分自身には送信できません';
    return '失敗しました: $code';
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

class ResbaMatchListener extends StateNotifier<bool>
    with WidgetsBindingObserver {
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

  RealtimeChannel? _senderChannel;
  RealtimeChannel? _applicantChannel;
  RealtimeChannel? _hostChannel;
  StreamSubscription<AuthState>? _authSub;
  final Set<String> _handledRoomIds = {};
  bool _dialogOpen = false;

  String? get _userId => ref.read(currentUserIdProvider);

  /// 現在進行中のバトル（rooms_v2 で winner 未確定）に参加しているか
  bool get _inBattle {
    final room = ref.read(matchingRoomProvider);
    return room.roomId != null && room.winner == null;
  }

  Future<void> start() async {
    final myId = _userId;
    if (myId == null) {
      // 認証セッション復元前: サインイン後に再実行する
      _ensureAuthRetry();
      return;
    }
    if (state) return;
    state = true;

    WidgetsBinding.instance.addObserver(this);

    // 送信者側: 自分のレスバが承諾されたら
    _senderChannel = supabase
        .channel('resba-sender-$myId')
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
            if (newData['status'] == 'accepted') {
              final roomId = newData['battle_room_id']?.toString();
              if (roomId != null) await _navigateToBattle(roomId);
            }
          },
        )
        .subscribe();

    // 応募者側: 自分の応募が承認されたら
    _applicantChannel = supabase
        .channel('resba-applicant-$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'battle_invite_applications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'applicant_id',
            value: myId,
          ),
          callback: (payload) async {
            final newData = payload.newRecord;
            if (newData['status'] == 'accepted') {
              final inviteId = newData['invite_id']?.toString();
              if (inviteId == null) return;
              final invite = await supabase
                  .from('battle_invites')
                  .select('battle_room_id')
                  .eq('id', inviteId)
                  .maybeSingle();
              final roomId = invite?['battle_room_id']?.toString();
              if (roomId != null) await _navigateToBattle(roomId);
            }
          },
        )
        .subscribe();

    // ホスト側: 自分のレスバへの応募 INSERT → 応募キューを更新（ダイアログはキュー単位で1つ）
    _hostChannel = supabase
        .channel('resba-host-$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'battle_invite_applications',
          callback: (payload) async {
            final newData = payload.newRecord;
            final inviteId = newData['invite_id']?.toString();
            if (inviteId == null) return;
            final invite = await supabase
                .from('battle_invites')
                .select('sender_id')
                .eq('id', inviteId)
                .maybeSingle();
            if (invite == null || invite['sender_id']?.toString() != myId) {
              return;
            }
            await _refreshHostQueue();
          },
        )
        .subscribe();

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

  /// 応募キューを再取得し、未対応があればダイアログを開く
  Future<void> _refreshHostQueue() async {
    await ref.read(pendingHostApplicationsProvider.notifier).fetch();
    if (!_dialogOpen) await _maybeOpenQueueDialog();
  }

  /// 応募が溜まっていたら「応募キュー」ダイアログを開く（同時に1つだけ）
  Future<void> _maybeOpenQueueDialog() async {
    if (_dialogOpen) return;
    // 対戦中は表示しない（承認もサーバー側で IN_BATTLE によりブロックされるため）
    if (_inBattle) return;
    final items = ref
            .read(pendingHostApplicationsProvider)
            .valueOrNull ??
        const <HostApplication>[];
    if (items.isEmpty) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    _dialogOpen = true;
    try {
      await showHostApplicationQueueDialog(ref);
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // バックグラウンド中に来た応募も取りこぼさない
      _refreshHostQueue();
    }
  }

  Future<void> _navigateToBattle(String roomId) async {
    if (_handledRoomIds.contains(roomId)) return;
    _handledRoomIds.add(roomId);
    // 既に別の試合中ならバトル画面へ移動しない
    // （サーバー側でも is_user_in_battle により二重対戦はブロックされる）
    if (_inBattle) return;
    try {
      await ref.read(matchingRoomProvider.notifier).joinBbsRoom(roomId);
      router.go('/wait');
    } catch (e) {
      log('resba navigate error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    if (_senderChannel != null) supabase.removeChannel(_senderChannel!);
    if (_applicantChannel != null) supabase.removeChannel(_applicantChannel!);
    if (_hostChannel != null) supabase.removeChannel(_hostChannel!);
    super.dispose();
  }
}

/// 自分がホストの保留応募（pending レスバ + 先頭応募者）を表示するためのプロバイダ
final pendingHostInvitesProvider = StateNotifierProvider.autoDispose<
    PendingHostInvitesNotifier, AsyncValue<List<ResbaInvite>>>((ref) {
  return PendingHostInvitesNotifier(ref);
});

class PendingHostInvitesNotifier
    extends StateNotifier<AsyncValue<List<ResbaInvite>>> {
  final Ref ref;
  PendingHostInvitesNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    final invites = await ref.read(resbaActionsProvider).getMyPendingHostInvites();
    state = AsyncValue.data(invites);
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

  ApplyingInfoNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  Future<void> _init() async {
    final myId = ref.read(currentUserIdProvider);
    if (myId == null) {
      state = const AsyncValue.data(null);
      return;
    }
    await fetch();
    // 自分の応募の INSERT / UPDATE（承認・拒否・取消）を購読して即時反映
    _channel = supabase
        .channel('resba-applying-$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_invite_applications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'applicant_id',
            value: myId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            final status = newData['status'] as String?;
            if (status == 'rejected') {
              // ホストに拒否された: 「⚔️ 拒否されました」を一時表示する
              state = AsyncValue.data(ApplyingInfo(
                applicationId: newData['id'] as String,
                inviteId: newData['invite_id'] as String,
                theme: '',
                status: 'rejected',
                attachType: '',
                attachId: '',
                createdAt: DateTime.now(),
              ));
            } else {
              fetch();
            }
          },
        )
        .subscribe();
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

  /// 応募を取り消す（バナーから）
  Future<void> cancelApplication() async {
    await ref.read(resbaActionsProvider).cancelMyPendingApplications();
    await fetch();
  }

  /// 拒否・取消の表示をすぐに消す（バナーを非表示にする）
  void clear() {
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    if (_channel != null) supabase.removeChannel(_channel!);
    super.dispose();
  }
}

// ホスト側の応募ダイアログは widgets/resba_host_queue_dialog.dart の
// showHostApplicationQueueDialog()（応募キュー・古い順・溜まる表示）に移行済み
