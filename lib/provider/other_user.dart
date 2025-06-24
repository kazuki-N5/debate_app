import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


final otherUserProvider =
    StateNotifierProvider<OtherUserNotifier, Users>((ref) {
  return OtherUserNotifier(ref);
});

class OtherUserNotifier extends StateNotifier<Users> {
  OtherUserNotifier(this._ref) : super(Users(id: '', name: '', trophy: 0));
  final Ref _ref;
  SupabaseClient get supabase => _ref.read(supabaseProvider);
  Future<void> fetchOtherUser(String id) async {
    try {
      final response =
          await supabase.from('users').select().eq('id', id).single();

      if (response.isNotEmpty) {
        state = Users.fromMap(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchOtherUserWithRetry(String id, {int maxRetries = 3}) async {
    int retryCount = 0;
    try {
      while (retryCount < maxRetries) {
        try {
          await fetchOtherUser(id);
          return; // 成功したら関数を抜ける
        } catch (e) {
          retryCount++;
          print('リトライ回数: $retryCount');
          if (retryCount == maxRetries) {
            print('リトライ回数が上限に達しました。');
            throw e; // 例外を再スロー
          }
          // 少し待ってからリトライ (例: 1秒待つ)
          await Future.delayed(Duration(seconds: 1));
        }
      }
    } catch (e) {
      // ここでエラーをキャッチ
      print('リトライがすべて失敗しました: $e');
      // ignore: use_build_context_synchronously
      router.go('/home');
    }
  }
}
