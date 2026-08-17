// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:go_router/go_router.dart';

class OpenChatRoomsView extends HookConsumerWidget {
  const OpenChatRoomsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(openChatRoomsProvider);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: Column(
        children: [
          // 検索バー (LINE風)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'オープンチャット',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Colors.black87, size: 22),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) {
                  ref.read(openChatSearchQueryProvider.notifier).state = value;
                },
              ),
            ),
          ),
          // リスト表示
          Expanded(
            child: roomsAsync.when(
              data: (originalRooms) {
                final rooms = originalRooms;
                if (rooms.isEmpty) {
                  return Center(
                    child: Text(
                      'オープンチャットが見つかりません',
                      style: AppTextStyles.notoSans(
                          color: Colors.grey, fontSize: 16),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(openChatRoomsProvider),
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: MediaQuery.of(context).padding.bottom + 80,
                    ),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            if (room.isJoined == true) {
                              context.push(
                                '/openChatRoom',
                                extra: room,
                              );
                            } else {
                              context.push('/open_chat_preview', extra: room);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // アイコンとバッジ
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.blueAccent
                                            .withValues(alpha: 0.1),
                                        backgroundImage: room.iconUrl != null &&
                                                room.iconUrl!.isNotEmpty
                                            // 表示サイズ(44px)に縮小デコードしてカクつきを抑える
                                            ? ResizeImage(NetworkImage(room.iconUrl!), width: 132)
                                            : null,
                                        child: room.iconUrl == null ||
                                                room.iconUrl!.isEmpty
                                            ? const Icon(Icons.forum,
                                                color: Colors.blueAccent,
                                                size: 24)
                                            : null,
                                      ),

                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // テキスト情報
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        room.name,
                                        style: AppTextStyles.notoSans(
                                            fontSize: 14,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        room.description ?? '説明なし',
                                        style: AppTextStyles.notoSans(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            'メンバー ${room.memberCount ?? 0}',
                                            style: AppTextStyles.notoSans(
                                                fontSize: 11,
                                                color: Colors.grey[500]),
                                          ),
                                          if (room.isJoined == true) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text('参加中',
                                                  style: AppTextStyles.notoSans(
                                                      color: Colors.grey[700],
                                                      fontSize: 10)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('エラー: $error')),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
