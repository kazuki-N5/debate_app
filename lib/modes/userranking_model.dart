// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
// RankingDialog内のColorsなどのため
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// UserRanking クラスの定義
class UserRanking {
  final String id;
  final String? name;
  final int trophy;
  final int? win;
  final String? avatarUrl;
  final int? overallRank; // 全体ランキングの順位

  UserRanking({
    required this.id,
    this.name,
    required this.trophy,
    this.win,
    this.avatarUrl,
    this.overallRank,
  });

  factory UserRanking.fromMap(Map<String, dynamic> map, {int? calculatedRank}) {
    return UserRanking(
      id: map['id'] as String,
      name: map['name'] as String?,
      trophy: map['trophy'] as int? ?? 0,
      win: map['win'] as int?, // winはnull default 0
      avatarUrl: map['avatar_url'] as String?,
      overallRank: map['overall_rank'] != null // RPCからの 'overall_rank' フィールド
          ? (map['overall_rank'] as num).toInt()
          : calculatedRank, // '上位'タブ用に計算されたランク
    );
  }
}

// タブ選択状態のProvider
enum RankingTab { top, nearby }

final selectedRankingTabProvider =
    StateProvider<RankingTab>((ref) => RankingTab.top);

// 上位ランキングのProvider (元の rankingProvider をリネームして修正)
final topRankingProvider = FutureProvider<List<UserRanking>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final response = await supabase
        .from('users')
        .select('id, name, trophy, win, avatar_url')
        .order('trophy', ascending: false)
        .order('win', ascending: false) // winがnullの場合、最後にソート
        .limit(100);

    // Supabaseクライアントのバージョンによって、responseが直接データリストであるか、
    // response.dataにデータが含まれるかが異なります。
    // 元のコードでは `response as List<dynamic>?` としていたため、それに合わせます。
    // モダンなSupabase Dart SDK (v2+)では、select()のawait結果は List<Map<String, dynamic>> です。
    final data = response as List<dynamic>?;

    if (data == null || data.isEmpty) {
      return [];
    }

    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value as Map<String, dynamic>;
      return UserRanking.fromMap(item, calculatedRank: index + 1);
    }).toList();
  } catch (e) {
    print('Error fetching top ranking: $e');
    rethrow;
  }
});

// 付近ランキングのProvider
final nearbyRankingProvider = FutureProvider<List<UserRanking>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final currentUser = ref.read(currentUserIdProvider);
  if (currentUser == null) {
    // ユーザーがログインしていない場合は空リストを返す
    // UI側で「ログインが必要です」などのメッセージを出すことを想定
    return [];
  }

  try {
    final response = await supabase.rpc(
      'get_nearby_ranking', // 次のセクションで定義するSQL関数名
      params: {'p_user_id': currentUser},
    );
    // RPCの返り値も、クライアントバージョンにより直接リストかresponse.dataか異なります。
    // ここでも元のコードのキャスト形式に合わせます。
    final data = response as List<dynamic>?;

    if (data == null || data.isEmpty) {
      return [];
    }
    return data.map((item) {
      final mapItem = item as Map<String, dynamic>;
      return UserRanking.fromMap(mapItem); // fromMapがRPC結果の'overall_rank'を処理
    }).toList();
  } catch (e) {
    print('Error fetching nearby ranking: $e');
    // エラーの詳細を確認したい場合:
    // if (e is PostgrestException) { print('PostgrestException: ${e.message}'); }
    rethrow;
  }
});
