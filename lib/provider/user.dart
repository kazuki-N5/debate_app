import 'package:debate_project/modes/users.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

final userProvider = StateNotifierProvider<UserNotifier, Users>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<Users> {
  UserNotifier() : super(Users(id: '', name: '', trophy: 0)) {}

  final supabase = Supabase.instance.client;

  Future<void> signinandname() async {
    try {
      final user = supabase.auth.currentUser?.id;
      if (user != null) {
        await fetchUser(user);
        if (state.name == '') {
          print(state.name);
          print('namaekara');
          router.go('/name');
          return;
        } else {
          print('ユーザーが存在します');
          router.go('/home');
          return;
        }
      } else {
        print('ユーザーが存在しません');
        await supabase.auth.signInAnonymously();
        print('ユーザーが作成されました');

        router.go('/name');
      }
    } catch (e) {
      print('error');
    }
  }

  Future<void> fetchUser(String id) async {
    try {
      print(id);
      final response =
          await supabase.from('users').select().eq('id', id).single();

      if (response.isNotEmpty) {
        print(response);
        state = Users.fromMap(response);
      }
    } catch (e) {
      print('エラー: $e');
    }
  }

  Future<void> updateName(Users user, String name) async {
    final myuser = supabase.auth.currentUser?.id;
    try {
      await supabase.from('users').update({'name': name}).eq('id', myuser!);
    } catch (e) {
      print('エラー: $e');
    }
    await fetchUser(myuser!);
    if (state.name == name) {
      router.go('/home');
    } else {
      router.go('/name');
    }
  }
}
