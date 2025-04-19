import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final matchHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  if (supabase.auth.currentUser == null) return [];

  try {
    final response = await supabase.rpc('get_recent_match_history');
    return (response as List).cast<Map<String, dynamic>>();
  } catch (error) {
    throw Exception('Failed to load match history');
  }
});