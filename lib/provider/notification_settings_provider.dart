// ignore_for_file: file_names, avoid_print
import 'package:debate_project/modes/notification_settings.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// プッシュ通知の設定 (マスター + カテゴリ別) を管理するProvider
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier,
        AsyncValue<NotificationSettingsModel>>((ref) {
  return NotificationSettingsNotifier(ref);
});

class NotificationSettingsNotifier
    extends StateNotifier<AsyncValue<NotificationSettingsModel>> {
  final Ref _ref;
  NotificationSettingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  String? get _userId => _ref.read(currentUserIdProvider);
  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  Future<void> _init() async {
    final userId = _userId;
    if (userId == null) {
      state = const AsyncValue.data(NotificationSettingsModel());
      return;
    }
    await load();
  }

  /// 設定を読み込む (行がなければ既定値で作成して保存)
  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final res = await _supabase
          .from('notification_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      final model = res != null
          ? NotificationSettingsModel.fromMap(res)
          : const NotificationSettingsModel();
      if (res == null) {
        // 行がない場合 (新規ユーザー対策) は既定値で作成
        await _supabase.from('notification_settings').upsert({
          'user_id': userId,
          ...model.toMap(),
        });
      }
      state = AsyncValue.data(model);
    } catch (e) {
      print('notification_settings load error: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// マスター (プッシュ全体) のON/OFFを更新 (楽観的更新 + DB upsert)
  Future<void> setMaster(bool value) async {
    await _update('is_notification_enabled', value,
        (m) => m.copyWith(isNotificationEnabled: value));
  }

  /// カテゴリのON/OFFを更新 (楽観的更新 + DB upsert)
  Future<void> setCategory(String column, bool value) async {
    await _update(column, value, (m) => _apply(column, value, m));
  }

  Future<void> _update(
      String column, bool value, NotificationSettingsModel Function(NotificationSettingsModel) apply) async {
    final userId = _userId;
    if (userId == null) return;
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = apply(current);
    state = AsyncValue.data(updated);

    try {
      await _supabase.from('notification_settings').upsert({
        'user_id': userId,
        column: value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print('notification_settings update error: $e');
      state = AsyncValue.data(current); // 失敗時はロールバック
    }
  }

  NotificationSettingsModel _apply(
      String column, bool value, NotificationSettingsModel m) {
    switch (column) {
      case 'like_enabled':
        return m.copyWith(likeEnabled: value);
      case 'comment_enabled':
        return m.copyWith(commentEnabled: value);
      case 'follow_enabled':
        return m.copyWith(followEnabled: value);
      case 'dm_enabled':
        return m.copyWith(dmEnabled: value);
      case 'open_chat_enabled':
        return m.copyWith(openChatEnabled: value);
      case 'match_waiting_enabled':
        return m.copyWith(matchWaitingEnabled: value);
      case 'resba_apply_enabled':
        return m.copyWith(resbaApplyEnabled: value);
      default:
        return m;
    }
  }
}
