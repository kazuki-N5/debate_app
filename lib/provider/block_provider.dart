// ignore_for_file: file_names, avoid_print
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 自分がブロックしたユーザーID一覧を一元管理するプロバイダ
/// (Supabase の brock_user テーブルから取得。ランダムマッチングには適用しない)
final blockedUserIdsProvider =
    StateNotifierProvider<BlockedUserIdsNotifier, List<String>>((ref) {
  return BlockedUserIdsNotifier(ref);
});

class BlockedUserIdsNotifier extends StateNotifier<List<String>> {
  final Ref _ref;

  BlockedUserIdsNotifier(this._ref) : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final supabase = _ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final res = await supabase
          .from('brock_user')
          .select('block_user_id')
          .eq('user_id', myId);
      state = (res as List)
          .map((e) => e['block_user_id'] as String)
          .toList();
    } catch (e) {
      print('ブロック一覧の取得に失敗: $e');
    }
  }

  /// 自分が [userId] をブロックしているか
  bool isBlocked(String userId) => state.contains(userId);

  /// [targetUserId] をブロックする
  Future<bool> block(String targetUserId) async {
    final supabase = _ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null || myId == targetUserId) return false;
    try {
      await supabase.from('brock_user').insert({
        'user_id': myId,
        'block_user_id': targetUserId,
      });
      if (!state.contains(targetUserId)) {
        state = [...state, targetUserId];
      }
      return true;
    } catch (e) {
      print('ブロック登録に失敗: $e');
      return false;
    }
  }

  /// [targetUserId] のブロックを解除する
  Future<bool> unblock(String targetUserId) async {
    final supabase = _ref.read(supabaseProvider);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return false;
    try {
      await supabase
          .from('brock_user')
          .delete()
          .match({'user_id': myId, 'block_user_id': targetUserId});
      state = state.where((id) => id != targetUserId).toList();
      return true;
    } catch (e) {
      print('ブロック解除に失敗: $e');
      return false;
    }
  }

  /// サーバーから再取得(機種変更・他端末での変更反映用)
  Future<void> refresh() => _load();
}

/// 相手([userId])が自分をブロックしているか
/// (プロフィールの「ブロックされています」表示や送信ガードに使用)
final isBlockedByProvider =
    FutureProvider.family.autoDispose<bool, String>((ref, userId) async {
  final supabase = ref.read(supabaseProvider);
  final myId = supabase.auth.currentUser?.id;
  if (myId == null || userId == myId) return false;
  try {
    final res = await supabase
        .from('brock_user')
        .select('id')
        .eq('user_id', userId)
        .eq('block_user_id', myId)
        .maybeSingle();
    return res != null;
  } catch (e) {
    print('ブロック済み判定に失敗: $e');
    return false;
  }
});
