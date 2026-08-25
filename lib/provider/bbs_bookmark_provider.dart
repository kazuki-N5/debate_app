import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';

const String _bookmarkKey = 'bookmarked_bbs_post_ids';

/// ブックマークされたポストIDのSetを管理するNotifier
class BbsBookmarkNotifier extends StateNotifier<Set<String>> {
  BbsBookmarkNotifier() : super({}) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_bookmarkKey) ?? [];
    state = list.toSet();
  }

  /// ブックマークの追加/削除を切り替える（追加時はtrue、解除時はfalseを返す）
  Future<bool> toggleBookmark(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final newSet = Set<String>.from(state);
    bool added = false;
    if (newSet.contains(postId)) {
      newSet.remove(postId);
      added = false;
    } else {
      newSet.add(postId);
      added = true;
    }
    state = newSet;
    await prefs.setStringList(_bookmarkKey, newSet.toList());
    return added;
  }

  bool isBookmarked(String postId) {
    return state.contains(postId);
  }
}

/// ブックマークID一覧のProvider
final bbsBookmarkIdsProvider =
    StateNotifierProvider<BbsBookmarkNotifier, Set<String>>((ref) {
  return BbsBookmarkNotifier();
});

/// ブックマークされたポスト一覧を取得するFutureProvider
final bookmarkedPostsProvider =
    FutureProvider.autoDispose<List<BbsPost>>((ref) async {
  final bookmarkIds = ref.watch(bbsBookmarkIdsProvider);
  if (bookmarkIds.isEmpty) {
    return [];
  }

  final supabase = ref.read(supabaseProvider);
  final currentUserId = ref.read(currentUserIdProvider);

  try {
    // 1. SupabaseからブックマークされたIDのポストを一括取得
    final response = await supabase
        .from('bbs_posts')
        .select('*, users!bbs_posts_user_id_fkey(*)')
        .filter('id', 'in', bookmarkIds.toList())
        .order('created_at', ascending: false);

    final List<dynamic> dataList = response as List<dynamic>;
    if (dataList.isEmpty) {
      return [];
    }

    // 2. 自分がいいねしているかを確認
    final postIds = dataList.map((item) => item['id'] as String).toList();
    Set<String> likedPostIds = {};
    if (currentUserId != null && postIds.isNotEmpty) {
      final likesResponse = await supabase
          .from('bbs_likes')
          .select('post_id')
          .eq('user_id', currentUserId)
          .filter('post_id', 'in', postIds);

      final likesList = likesResponse as List<dynamic>;
      likedPostIds = likesList.map((l) => l['post_id'] as String).toSet();
    }

    // 3. BbsPostモデルにマッピング
    final posts = dataList.map<BbsPost>((map) {
      final userMap = map['users'] as Map<String, dynamic>?;
      final user = userMap != null ? Users.fromMap(userMap) : null;
      final postId = map['id'] as String;
      return BbsPost.fromMap(
        map as Map<String, dynamic>,
        user: user,
        isLikedByMe: likedPostIds.contains(postId),
      );
    }).toList();

    // 4. ブロックしたユーザーのポストは表示しない
    final blocked = ref.read(blockedUserIdsProvider).toSet();
    return posts.where((p) => !blocked.contains(p.userId)).toList();
  } catch (e) {
    return [];
  }
});
