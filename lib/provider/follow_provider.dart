// ignore_for_file: file_names, avoid_print
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 指定ユーザーをフォローしているかどうか
final isFollowingProvider =
    FutureProvider.family.autoDispose<bool, String>((ref, userId) async {
  final myId = ref.read(currentUserIdProvider);
  if (myId == null || myId == userId) return false;

  final supabase = ref.read(supabaseProvider);
  final res = await supabase
      .from('user_follows')
      .select('follower_id')
      .eq('follower_id', myId)
      .eq('followed_id', userId)
      .maybeSingle();
  return res != null;
});

/// フォロー / フォロー解除アクション
final followActionProvider = Provider<FollowActionNotifier>((ref) {
  return FollowActionNotifier(ref);
});

class FollowActionNotifier {
  final Ref _ref;
  FollowActionNotifier(this._ref);

  /// フォロー状態をトグルする
  Future<void> toggle(String userId) async {
    final myId = _ref.read(currentUserIdProvider);
    if (myId == null || myId == userId) return;

    final supabase = _ref.read(supabaseProvider);
    try {
      final existing = await supabase
          .from('user_follows')
          .select('follower_id')
          .eq('follower_id', myId)
          .eq('followed_id', userId)
          .maybeSingle();

      if (existing != null) {
        await supabase
            .from('user_follows')
            .delete()
            .eq('follower_id', myId)
            .eq('followed_id', userId);
      } else {
        await supabase
            .from('user_follows')
            .insert({'follower_id': myId, 'followed_id': userId});
      }

      // 状態を再取得
      _ref.invalidate(isFollowingProvider(userId));
    } catch (e) {
      print('follow toggle error: $e');
    }
  }
}
