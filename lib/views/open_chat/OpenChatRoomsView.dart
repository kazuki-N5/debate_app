// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/community_ad.dart';
import 'package:debate_project/adsence/ad_community_provider.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:go_router/go_router.dart';

class OpenChatRoomsView extends HookConsumerWidget {
  const OpenChatRoomsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(openChatRoomsProvider);
    final searchController = useTextEditingController();

    // --- コミュニティ(クラブタブ)用の Medium Rectangle 広告 ---
    // スロット index -> 個別の BannerAd(スロットごとに別インスタンス)
    final clubAds = ref.watch(communityClubAdProvider);
    final isSubscribed = ref.watch(inAppPurchaseManagerProvider).isSubscribed;

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
                  controller: searchController,
                  onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '検索する',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.black87, size: 20),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                            onPressed: () {
                              searchController.clear();
                              ref.read(openChatSearchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                    // 0件のときは広告のみ表示(課金で広告なしなら従来の空メッセージ)
                    if (!isSubscribed) {
                      ref.read(communityClubAdProvider.notifier).prepare({0});
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 60),
                          Padding(
                            padding: EdgeInsets.only(
                                bottom: homeBottomAdClearance()),
                            child: clubAds[0] != null
                                ? communityAdWidget(clubAds[0]!)
                                : communityAdPlaceholder(),
                          ),
                        ],
                      );
                    }
                    return Center(
                      child: Text(
                        'クラブが見つかりません',
                        style: AppTextStyles.notoSans(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(openChatRoomsProvider),
                    child: Builder(builder: (context) {
                      // クラブも長い一覧なので「6件ごとに1個」広告を挟む(開始位置はランダム)
                      final adSlots = !isSubscribed
                          ? communityAdSlotIndexes(
                              rooms.length,
                              6,
                              startContentIndex: ref
                                  .read(communityClubAdProvider.notifier)
                                  .resolveFirstAdOffset(rooms.length, 2),
                            )
                          : <int>{};
                      final totalItems = rooms.length + adSlots.length;

                      // 各広告スロットに個別の広告をロード(多重ロードはProvider側で防止)
                      if (adSlots.isNotEmpty) {
                        ref
                            .read(communityClubAdProvider.notifier)
                            .prepare(adSlots);
                      }

                      return ListView.builder(
                        padding: EdgeInsets.only(
                          top: 4,
                          // 非課金時は下部の常時表示バナーに被らないよう余白を広げる
                          bottom: isSubscribed
                              ? MediaQuery.of(context).padding.bottom + 80
                              : homeBottomAdClearance(),
                        ),
                        itemCount: totalItems,
                        itemBuilder: (context, index) {
                          if (adSlots.contains(index)) {
                            final slotAd = clubAds[index];
                            return slotAd != null
                                ? communityAdWidget(slotAd)
                                : communityAdPlaceholder();
                          }
                          final room =
                              rooms[communityContentIndex(index, adSlots)];
                          final tags =
                              (room.tags != null && room.tags!.isNotEmpty)
                                  ? room.tags!
                                  : (room.description != null
                                      ? extractTagsFromDescription(
                                          room.description!)
                                      : <String>[]);

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
                                  context.push('/open_chat_preview',
                                      extra: room);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 10.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // アイコンとバッジ
                                    SizedBox(
                                      width: 46,
                                      height: 46,
                                      child: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 23,
                                            backgroundColor: Colors.blueAccent
                                                .withValues(alpha: 0.1),
                                            backgroundImage: room.iconUrl !=
                                                    null &&
                                                room.iconUrl!.isNotEmpty
                                                ? ResizeImage(
                                                    NetworkImage(
                                                        room.iconUrl!),
                                                    width: 138)
                                                : null,
                                            child: room.iconUrl == null ||
                                                    room.iconUrl!.isEmpty
                                                ? const Icon(
                                                    Icons.forum,
                                                    color: Colors.blueAccent,
                                                    size: 24,
                                                  )
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
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  room.name,
                                                  style: AppTextStyles.notoSans(
                                                    fontSize: 14,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (room.password != null &&
                                                  room.password!
                                                      .isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                const Icon(Icons.lock,
                                                    size: 13,
                                                    color: Color(0xFFD97706)),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            room.description ?? '説明なし',
                                            style: AppTextStyles.notoSans(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          // タグチップ表示
                                          if (tags.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: tags.take(3).map((tag) {
                                                return InkWell(
                                                  onTap: () {
                                                    searchController.text =
                                                        '#$tag';
                                                    ref
                                                        .read(
                                                            openChatSearchQueryProvider
                                                                .notifier)
                                                        .state = tag;
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 6,
                                                          vertical: 1.5,
                                                        ),
                                                    decoration:
                                                        BoxDecoration(
                                                      color:
                                                          const Color(0xFFEFF6FF),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      '#$tag',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                'メンバー ${room.memberCount ?? 0}',
                                                style: AppTextStyles.notoSans(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                              if (room.isJoined == true) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    '参加中',
                                                    style: AppTextStyles.notoSans(
                                                      color: Colors.blue.shade700,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
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
                      );
                    }),
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
