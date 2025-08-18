import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/user.dart';
import 'package:debate_project/view_model/prohibited_view_model.dart';
import 'package:flutter/material.dart';
// --- ▼▼▼ ここから変更 ▼▼▼ ---
import 'package:flutter_hooks/flutter_hooks.dart'; // flutter_hooksをインポート
import 'package:hooks_riverpod/hooks_riverpod.dart'; // hooks_riverpodをインポート
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferencesをインポート
// --- ▲▲▲ ここまで変更 ▲▲▲ ---
import 'package:go_router/go_router.dart';

import '../provider/supabase_provider.dart';

// --- ▼▼▼ HookConsumerWidgetに変更 ▼▼▼ ---
class ChatHistoryPage extends HookConsumerWidget {
  final MatchRecordDisplay record;

  const ChatHistoryPage({Key? key, required this.record}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(currentUserIdProvider);
    final myurl = ref.read(userProvider).avatar_url;

    Future<List<Chat>> _fetchMessages(String roomId) async {
      final supabase = ref.read(supabaseProvider);
      try {
        final List<Map<String, dynamic>> data = await supabase
            .from('messages')
            .select('*')
            .eq('room_id', roomId)
            .order('created_at', ascending: true);
        return data.map((map) => Chat.fromMap(map)).toList();
      } catch (e) {
        print('メッセージ取得エラー: $e');
        throw Exception('メッセージの読み込みに失敗しました');
      }
    }

    // --- ▼▼▼ ここから変更 ▼▼▼ ---
    // 非表示にするメッセージIDのリストを状態として管理
    final hiddenMessageIds = useState<Set<String>>({});
    // SharedPreferencesからデータを読み込み中かどうかのフラグ

    // useMemoized を使ってFutureをキャッシュし、不要な再取得を防ぐ
    final messagesFuture = useMemoized(
      () => _fetchMessages(record.roomid),
      [record.roomid], // record.roomid が変わらない限り、このFutureは再生成されない
    );
    // useFuture を使ってFutureの状態を監視する
    final messagesSnapshot = useFuture(messagesFuture);
    // --- ▲▲▲ ここまで変更 ▲▲▲ ---

    // SharedPreferencesから非表示IDを読み込む非同期関数
    Future<void> loadHiddenMessageIds() async {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('hidden_message_ids') ?? [];
      hiddenMessageIds.value = ids.toSet();
    }

    // 非表示にするメッセージIDを保存し、状態を更新する関数
    Future<void> hideMessage(String messageId) async {
      final newHiddenIds = {...hiddenMessageIds.value, messageId};
      hiddenMessageIds.value = newHiddenIds; // UIを即時更新

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hidden_message_ids', newHiddenIds.toList());
    }

    // ウィジェットの初回ビルド時に一度だけ実行される
    useEffect(() {
      loadHiddenMessageIds();
      return null;
    }, const []);

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('チャット履歴')),
        body: const Center(child: Text('ユーザー情報が取得できません。')),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.blue,
            title: Text(
              '${record.opponentName} とのレスバ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w300,
                fontSize: 20.0,
              ),
            ),
            automaticallyImplyLeading: false,
          ),
          backgroundColor: Colors.blue,
          body: Column(
            children: [
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.theme,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  // --- ▼▼▼ ここから変更 (FutureBuilderをuseFutureの結果で置き換え) ▼▼▼ ---
                  child: () {
                    // SharedPreferencesとメッセージ取得の両方の読み込みを待つ
                    if (messagesSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return Container(); // 何も表示しない
                    }
                    if (messagesSnapshot.hasError) {
                      return Container(); // 何も表示しない
                    }
                    if (!messagesSnapshot.hasData) {
                      return Container(); // 何も表示しない
                    }

                    final allMessages = messagesSnapshot.data!;
                    // 非表示IDに含まれないメッセージのみをフィルタリング
                    final visibleMessages = allMessages
                        .where(
                            (chat) => !hiddenMessageIds.value.contains(chat.id))
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 16),
                      itemCount: visibleMessages.length,
                      itemBuilder: (context, index) {
                        final chat = visibleMessages[index];
                        final isUserMessage = chat.senderId == currentUserId;

                        final bool showAvatar = index == 0 ||
                            visibleMessages[index - 1].senderId !=
                                chat.senderId;

                        return MessageBubble(
                          chat: chat,
                          isUserMessage: isUserMessage,
                          opponentAvatarUrl: record.opponentAvatarUrl,
                          myAvatarUrl: myurl,
                          showAvatar: showAvatar,
                          onHide: () => hideMessage(chat.id),
                        );
                      },
                    );
                  }(),
                  // --- ▲▲▲ ここまで変更 ▲▲▲ ---
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 10,
          bottom: 20,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            iconSize: 28.0,
            color: Colors.black,
            tooltip: '戻る',
            onPressed: () => context.pop(),
            padding: const EdgeInsets.all(12.0),
            splashRadius: 24.0,
          ),
        ),
      ],
    );
  }
}

/// 汎用的なポップオーバーを表示するヘルパー関数
