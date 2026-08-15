// ignore_for_file: file_names, avoid_print, use_build_context_synchronously


import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabaseクライアントのインスタンスを提供するProvider
// これにより、アプリ全体で同じクライアントインスタンスを共有できます。
final supabaseProvider = Provider<SupabaseClient>((ref) {
  log('🔵 supabaseProvider が生成されました。', name: 'Riverpod');
  return Supabase.instance.client;
});

// 認証状態の変化を監視するStreamProvider
// ログイン、ログアウトなど、認証状態が変わると新しい値がストリームに流れます。
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  log('🔵 authStateChangesProvider が生成されました。', name: 'Riverpod');
  final supabaseClient = ref.watch(supabaseProvider);
  return supabaseClient.auth.onAuthStateChange;
});

// 現在ログインしているユーザー(Userオブジェクト)を提供するProvider
// 認証状態が変わると、このProviderも自動的に更新されます。
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateChangesProvider);

  return ref.watch(supabaseProvider).auth.currentUser?.id;
});
