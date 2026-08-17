// ignore_for_file: file_names, avoid_print
import 'package:debate_project/modes/notification_settings.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// プッシュ通知のカテゴリ別設定を管理するProvider
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier,
        AsyncValue<NotificationSettingsModel>>((ref) {
  return NotificationSettingsNotifier(ref);
});

class NotificationSettingsNotifier
    extends StateNotifier<AsyncValue<NotificationSettingsModel>> {
  final Ref _ref;
  NotificationSettingsNotifier(this._ref)
      : super(const AsyncValue.loading());

  String? get _userId => _ref.read(currentUserIdProvider);
  SupabaseClient get _supabase => _ref.read(supabaseProvider);

  /// 設定を読み込む (行がなければ全ONで作成して保存)
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
        // 行がない場合 (新規ユーザー対策) は全ONで作成
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

  /// カテゴリのON/OFFを更新 (楽観的更新 + DB upsert)
  Future<void> setCategory(String column, bool value) async {
    final userId = _userId;
    if (userId == null) return;
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = _apply(column, value, current);
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
      default:
        return m;
    }
  }
}
