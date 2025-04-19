
import 'package:debate_project/modes/chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, List<Chat>>((ref) {
  return ChatNotifier();
});

class ChatNotifier extends StateNotifier<List<Chat>> {
  ChatNotifier() : super([]);
  final supabase = Supabase.instance.client;

  Future<void> sendMesage(String roomId, String content) async {
    try {
      final userId = supabase.auth.currentUser?.id;
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
    supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .listen((data) {
          state = data.map((e) => Chat.fromMap(e)).toList();
        });
  }

  


}
