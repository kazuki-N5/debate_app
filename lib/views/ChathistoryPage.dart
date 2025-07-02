import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/modes/history.dart';
import 'package:debate_project/provider/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../provider/supabase_provider.dart';

class ChatHistoryPage extends ConsumerWidget {
  // GoRouterのextraとして渡される record を受け取る
  final MatchRecordDisplay record;

  const ChatHistoryPage({Key? key, required this.record}) : super(key: key);

  // Supabaseからメッセージを取得する非同期関数

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = ref.read(supabaseProvider);
    // 現在のユーザーIDを取得
    final currentUserId = ref.read(currentUserIdProvider);

    final myurl = ref.read(userProvider).avatar_url;

    Future<List<Chat>> _fetchMessages(String roomId) async {
      try {
        // Fetch messages ordered by creation time
        final List<Map<String, dynamic>> data = await supabase
            .from('messages')
            .select('*') // Select all columns
            .eq('room_id', roomId) // Filter by room_id
            .order('created_at',
                ascending: true); // Sort by created_at ascending

        // Convert list of maps to list of Chat objects
        return data.map((map) => Chat.fromMap(map)).toList();
      } catch (e) {
        print('メッセージ取得エラー: $e');
        // Provide a more user-friendly error message
        throw Exception('メッセージの読み込みに失敗しました');
      }
    }

    // ユーザーがログインしていない場合はエラーを表示
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('チャット履歴')),
        body: const Center(child: Text('ユーザー情報が取得できません。')),
      );
    }

    // Stackを使用してScaffoldの上にボタンを重ねて表示
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.blue,
            title: Text(
              // Textウィジェットのstyleプロパティとして指定
              '${record.opponentName} とのチャット',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w300,
                fontSize: 20.0,
              ),
            ),
            automaticallyImplyLeading: false, // AppBarのプロパティとして正しく配置
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
                    color: Colors.blue, // 背景色は元のものを維持
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: FutureBuilder<List<Chat>>(
                    future: _fetchMessages(record.roomid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('メッセージの読み込みに失敗しました。'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('メッセージがありません。'));
                      } else {
                        final messages = snapshot.data!;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final chat = messages[index];
                            final isUserMessage =
                                chat.senderId == currentUserId;

                            // --- ▼▼▼ 変更点 ▼▼▼ ---
                            // アバターを表示するかどうかを判定するロジック
                            // 最初のメッセージか、または直前のメッセージと送信者が違う場合にtrueになる
                            final bool showAvatar = index == 0 ||
                                messages[index - 1].senderId != chat.senderId;
                            // --- ▲▲▲ 変更点 ▲▲▲ ---

                            return _MessageBubble(
                              chat: chat,
                              isUserMessage: isUserMessage,
                              opponentAvatarUrl: record.opponentAvatarUrl,
                              myAvatarUrl: myurl, // 自分のアバターURLを渡す
                              // --- ▼▼▼ 変更点 ▼▼▼ ---
                              showAvatar: showAvatar, // 計算したフラグを渡す
                              // --- ▲▲▲ 変更点 ▲▲▲ ---
                            );
                          },
                        );
                      }
                    },
                  ),
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

// --- ▼▼▼ ここから _MessageBubble ウィジェットの変更 ▼▼▼ ---
class _MessageBubble extends StatelessWidget {
  final Chat chat;
  final bool isUserMessage;
  final String? opponentAvatarUrl;
  final String? myAvatarUrl;
  // --- ▼▼▼ 変更点 ▼▼▼ ---
  // アバターを表示するかどうかを受け取るプロパティを追加
  final bool showAvatar;
  // --- ▲▲▲ 変更点 ▲▲▲ ---

  const _MessageBubble({
    Key? key,
    required this.chat,
    required this.isUserMessage,
    required this.opponentAvatarUrl,
    this.myAvatarUrl,
    // --- ▼▼▼ 変更点 ▼▼▼ ---
    required this.showAvatar, // コンストラクタに追加
    // --- ▲▲▲ 変更点 ▲▲▲ ---
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double size = 15;
    // アバターの直径を計算
    double avatarDiameter = size * 2;

    // アバターウィジェットを生成
    Widget avatarWidget;

    // --- ▼▼▼ 変更点 ▼▼▼ ---
    // showAvatarがtrueの場合のみアバターを生成し、falseの場合は同じ幅のSizedBoxでスペースを確保する
    if (showAvatar) {
      if (isUserMessage) {
        avatarWidget = CircleAvatar(
          radius: size, // Avatar size
          backgroundImage: myAvatarUrl != null && myAvatarUrl!.isNotEmpty
              ? NetworkImage(myAvatarUrl!) as ImageProvider<Object>?
              : null,
          child: (myAvatarUrl == null || myAvatarUrl!.isEmpty)
              ? Icon(
                  Icons.person,
                  color: Colors.grey,
                  size: size,
                ) // Default icon
              : null,
          backgroundColor: Colors.grey[200], // Default background
        );
      } else {
        avatarWidget = CircleAvatar(
          radius: size, // Avatar size
          backgroundImage:
              opponentAvatarUrl != null && opponentAvatarUrl!.isNotEmpty
                  ? NetworkImage(opponentAvatarUrl!) as ImageProvider<Object>?
                  : null,
          child: (opponentAvatarUrl == null || opponentAvatarUrl!.isEmpty)
              ? Icon(
                  Icons.person,
                  color: Colors.grey,
                  size: size,
                ) // Default icon
              : null,
          backgroundColor: Colors.grey[200], // Default background
        );
      }
    } else {
      // アバターを表示しない場合、レイアウトを崩さないように同じ幅のSizedBoxを配置
      avatarWidget = SizedBox(width: avatarDiameter);
    }
    // --- ▲▲▲ 変更点 ▲▲▲ ---

    // メッセージコンテンツウィジェット
    Widget messageContent = Flexible(
      child: Column(
        crossAxisAlignment:
            isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isUserMessage ? Colors.green : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              chat.content,
              style: TextStyle(
                color: isUserMessage ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      // パディングを調整
      padding: EdgeInsets.only(
        left: isUserMessage ? 64 : 8,
        right: isUserMessage ? 8 : 64,
        // --- ▼▼▼ 変更点 ▼▼▼ ---
        // 連続するメッセージの場合、上の余白を少し詰めてグループに見せる
        top: showAvatar ? 4 : 2,
        // --- ▲▲▲ 変更点 ▲▲▲ ---
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start, // アバターとメッセージの上端を合わせる
        children: isUserMessage
            ? [
                // 自分のメッセージ: メッセージが先、アバターが後 (右側)
                messageContent,
                const SizedBox(width: 8),
                Transform.translate(
                  offset: const Offset(0, 5),
                  child: avatarWidget,
                ),
                // メッセージとアバターの間
                // showAvatarに応じてCircleAvatarかSizedBoxが表示される
              ]
            : [
                // 相手のメッセージ: アバターが先、メッセージが後 (左側)

                Transform.translate(
                  offset: const Offset(0, 5),
                  child: avatarWidget,
                ), // showAvatarに応じてCircleAvatarかSizedBoxが表示される
                const SizedBox(width: 8), // アバターとメッセージの間
                messageContent,
              ],
      ),
    );
  }
}
