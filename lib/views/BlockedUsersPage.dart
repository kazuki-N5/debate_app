// ignore_for_file: file_names
import 'package:debate_project/provider/block_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ブロック中ユーザーの1件分
class BlockedUserEntry {
  final String userId;
  final String? name;
  final String? avatarUrl;

  const BlockedUserEntry({
    required this.userId,
    this.name,
    this.avatarUrl,
  });
}

/// ブロック中のユーザー一覧(ブロックID順にユーザー情報をJOINして取得)
final blockedUsersListProvider =
    FutureProvider.autoDispose<List<BlockedUserEntry>>((ref) async {
  final supabase = ref.read(supabaseProvider);
  final ids = ref.watch(blockedUserIdsProvider);
  if (ids.isEmpty) return [];

  final res = await supabase
      .from('users')
      .select('id, name, avatar_url')
      .inFilter('id', ids);

  final byId = <String, Map<String, dynamic>>{};
  for (final u in res as List) {
    final m = u as Map<String, dynamic>;
    byId[m['id'] as String] = m;
  }

  return ids.map((id) {
    final u = byId[id];
    return BlockedUserEntry(
      userId: id,
      name: u?['name']?.toString(),
      avatarUrl: u?['avatar_url']?.toString(),
    );
  }).toList();
});

/// 設定 → ブロック管理: ブロック中のユーザー一覧と解除
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(blockedUsersListProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('ブロック管理', style: AppTextStyles.bold(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                'ブロック中のユーザーはいません',
                style: AppTextStyles.notoSans(color: Colors.grey),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(blockedUsersListProvider);
              await ref.read(blockedUserIdsProvider.notifier).refresh();
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, thickness: 0.5),
              itemBuilder: (context, index) {
                final entry = users[index];
                final displayName = entry.name?.isNotEmpty == true
                    ? entry.name!
                    : '名無し';
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                            ? NetworkImage(entry.avatarUrl!)
                            : null,
                    child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    displayName,
                    style: AppTextStyles.bold(fontSize: 15),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      showUnblockUserDialog(
                        context: context,
                        ref: ref,
                        targetUserId: entry.userId,
                        targetName: displayName,
                        onUnblocked: () {
                          ref.invalidate(blockedUsersListProvider);
                        },
                      );
                    },
                    child: const Text(
                      '解除',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            '読み込みに失敗しました',
            style: AppTextStyles.notoSans(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
