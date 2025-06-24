import 'dart:async';

import 'package:debate_project/modes/chat.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, List<Chat>>((ref) {
  return ChatNotifier(ref);
});

class ChatNotifier extends StateNotifier<List<Chat>> {
  ChatNotifier(this._ref) : super([]);
  final Ref _ref;
  SupabaseClient get supabase => _ref.read(supabaseProvider);
  StreamSubscription? _messagesSubscription;

  Future<void> sendMesage(String roomId, String content) async {
    final userId = _ref.read(currentUserIdProvider);
    try {
      print(userId);
      await supabase.from('messages').insert({
        'room_id': roomId,
        'sender_id': userId,
        'content': content,
      });
    } catch (e) {
      print('インターネットに接続しましょう');
    }
  }

  void subscribeToMessages(String roomId) {
    // 既に購読している場合は、一旦キャンセルしてから新しい購読を開始します。
    // これにより、複数の購読が同時に走るのを防ぎます。
    _messagesSubscription?.cancel();

    // ストリームを購読し、StreamSubscriptionを保持します
    _messagesSubscription = supabase
        .from('messages')
        .stream(primaryKey: ['id']) // テーブルの主キーを指定
        .eq('room_id', roomId)
        .order('created_at') // 必要に応じてソート順を指定
        .listen(
          (data) {
            // 新しいデータが来たらStateを更新
            state = data.map((e) => Chat.fromMap(e)).toList();
            // print('メッセージデータを受信しました: ${state.length}件'); // デバッグ用
          },
        );
  }

  void unsubscribeFromMessages() {
    // StreamSubscriptionが存在すればキャンセルします
    _messagesSubscription?.cancel();
    // Subscription変数をnullに戻し、アクティブな購読がない状態にします
    // デバッグ用
  }

  // StateNotifierが破棄されるときに呼ばれるメソッド
  // Providerが不要になった場合にリソースを解放するために重要です
  @override
  void dispose() {
    // StateNotifierが破棄される際に必ず購読を停止します
    unsubscribeFromMessages();
    print('ChatNotifier disposed.'); // デバッグ用
    super.dispose(); // 親クラスのdisposeを忘れずに呼び出す
  }
}
