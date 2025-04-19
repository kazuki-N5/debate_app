import 'package:debate_project/modes/users.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

final otherUserProvider = StateNotifierProvider<OtherUserNotifier, Users>((ref) {
  return OtherUserNotifier();
});

class OtherUserNotifier extends StateNotifier<Users> {
  OtherUserNotifier() : super(Users(id: '', name: '', trophy: 0));

  Future<void> fetchOtherUser(String id) async {
    try {
      final response = 
          await supabase.from('users').select().eq('id', id).single();

      if (response.isNotEmpty) {
        state = Users.fromMap(response);
      }
    } catch (e) {
      print('エラー: $e');
    }
  }
}