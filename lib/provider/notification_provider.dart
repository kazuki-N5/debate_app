// ignore_for_file: file_names, avoid_print
import 'package:debate_project/modes/app_notification.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アプリ内通知一覧(Realtime購読・既読管理・ページネーション)を管理するプロバイダー
final notificationProvider = StateNotifierProvider<NotificationNotifier,
    AsyncValue<List<AppNotification>>>((ref) {
  return NotificationNotifier(ref);
});

class NotificationNotifier
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final Ref _ref;
  RealtimeChannel? _channel;

  /// 追加取得できる通知が残っているか
  bool hasMore = true;

  /// 1回の取得件数 (カーソル方式)
  static const int _pageSize = 50;

  NotificationNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final supabase = _ref.read(supabaseProvider);
    final myId = _ref.read(currentUserIdProvider);
    if (myId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    // 新着通知のRealtime購読 (user_id が自分宛ての insert のみ)
    _channel = supabase
        .channel('notifications-user-$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: myId,
          ),
          callback: (payload) {
            fetchNotifications();
          },
        )
        .subscribe();

    await fetchNotifications();
  }

  String _selectQuery() {
    return '*, actor:users!notifications_actor_id_fkey(*), '
        'post:bbs_posts!notifications_post_id_fkey(*), '
        'comment:bbs_comments!notifications_comment_id_fkey(*)';
  }

  AppNotification _fromMap(Map<String, dynamic> e) =>
      AppNotification.fromMap(e);

  /// 通知一覧を先頭から再取得 (初回・Realtime受信・pull-to-refresh用)
  Future<void> fetchNotifications() async {
    final supabase = _ref.read(supabaseProvider);
    final myId = _ref.read(currentUserIdProvider);
    if (myId == null) return;

    try {
      final response = await supabase
          .from('notifications')
          .select(_selectQuery())
          .eq('user_id', myId)
          .order('created_at', ascending: false)
          .limit(_pageSize);

      final notifications = (response as List<dynamic>)
          .map((e) => _fromMap(e as Map<String, dynamic>))
          .toList();

      hasMore = notifications.length >= _pageSize;
      state = AsyncValue.data(notifications);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 古い通知を追加取得 (カーソル方式: 現在の最古より前を取得)
  Future<void> loadMore() async {
    if (!hasMore || state is! AsyncData) return;

    final current = state.value!;
    if (current.isEmpty) {
      hasMore = false;
      return;
    }

    final supabase = _ref.read(supabaseProvider);
    final myId = _ref.read(currentUserIdProvider);
    if (myId == null) return;

    final oldest = current.last.createdAt;
    try {
      final response = await supabase
          .from('notifications')
          .select(_selectQuery())
          .eq('user_id', myId)
          .lt('created_at', oldest.toIso8601String())
          .order('created_at', ascending: false)
          .limit(_pageSize);

      final more = (response as List<dynamic>)
          .map((e) => _fromMap(e as Map<String, dynamic>))
          .toList();

      if (more.length < _pageSize) {
        hasMore = false;
      }
      // 既存 + 追加 (重複排除)
      final existingIds = current.map((n) => n.id).toSet();
      final newItems = more.where((n) => !existingIds.contains(n.id)).toList();
      state = AsyncValue.data([...current, ...newItems]);
    } catch (e) {
      print('notification loadMore error: $e');
    }
  }

  /// 未読件数
  int get unreadCount {
    final list = state.valueOrNull;
    if (list == null) return 0;
    return list.where((n) => !n.isRead).length;
  }

  /// 1件を既読にする (UI反映はローカルで即時、DBは update)
  Future<void> markRead(String notificationId) async {
    final supabase = _ref.read(supabaseProvider);
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      print('markRead error: $e');
    }
    // ローカルで即時反映 (update失敗でもUI上は既読扱い)
    if (state is AsyncData) {
      state = AsyncValue.data(state.value!.map((n) {
        return n.id == notificationId ? n.copyWith(isRead: true) : n;
      }).toList());
    }
  }

  /// すべて既読にする
  Future<void> markAllRead() async {
    final supabase = _ref.read(supabaseProvider);
    final myId = _ref.read(currentUserIdProvider);
    if (myId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', myId)
          .eq('is_read', false);
    } catch (e) {
      print('markAllRead error: $e');
    }
    if (state is AsyncData) {
      state = AsyncValue.data(
        state.value!.map((n) => n.copyWith(isRead: true)).toList(),
      );
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
