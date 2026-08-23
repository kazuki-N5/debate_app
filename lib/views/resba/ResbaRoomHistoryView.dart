import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/widgets/ios_swipe_back.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// オプチャまたはDM内のレスバ履歴一覧画面
class ResbaRoomHistoryView extends HookConsumerWidget {
  final String roomId;
  final String title;
  final bool isDm;

  const ResbaRoomHistoryView({
    super.key,
    required this.roomId,
    required this.title,
    this.isDm = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resbasAsync = isDm
        ? ref.watch(dmResbaProvider(roomId))
        : ref.watch(openChatResbasProvider(roomId));

    void refresh() {
      if (isDm) {
        ref.invalidate(dmResbaProvider(roomId));
      } else {
        ref.invalidate(openChatResbasProvider(roomId));
      }
    }

    return IosSwipeBack(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.blue,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leadingWidth: 44,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '$title のレスバ履歴',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: false,
        ),
        body: resbasAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'レスバ履歴の取得に失敗しました',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: refresh,
                  child: const Text('再読み込み'),
                ),
              ],
            ),
          ),
          data: (resbas) {
            if (resbas.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        '⚔️',
                        style: TextStyle(fontSize: 36),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'レスバの履歴はありません',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'チャット内でレスバを申し込むと、\nここに履歴と進行状況が表示されます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: resbas.length,
                itemBuilder: (context, index) {
                  final invite = resbas[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ResbaCard(
                      invite: invite,
                      onChanged: refresh,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
