import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:debate_project/provider/supabase_provider.dart';

final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService(ref);
});

class FCMService {
  final Ref _ref;
  FCMService(this._ref);

  /// ログインしているユーザーIDを受け取り、FCMトークンを取得してSupabaseのusersテーブルに保存する
  Future<void> saveTokenToDatabase(String userId) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // 今の端末のFCMトークンを取得する
      String? token = await messaging.getToken();
      if (token != null) {
        print('📱 FCM Token retrieved for saving: $token');
        await _updateTokenInSupabase(userId, token);
      }

      // FCMトークンがOS側でリフレッシュ(新しく作り直し)された場合にも、自動でSupabaseを更新するようにリスナーを登録
      messaging.onTokenRefresh.listen((newToken) async {
        print('🔄 FCM Token refreshed: $newToken');
        await _updateTokenInSupabase(userId, newToken);
      });
      
    } catch (e) {
      print('🔥 Error saving FCM token: $e');
    }
  }

  /// 通知の権限をリクエストし、ユーザーの選択（許可・拒否）を確認する。
  Future<NotificationSettings> requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    return await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Supabaseのusersテーブルの fcm_token カラムを更新する実際の処理
  Future<void> _updateTokenInSupabase(String userId, String token) async {
    try {
      final supabase = _ref.read(supabaseProvider);
      await supabase.from('users').update({
        'fcm_token': token
      }).eq('id', userId);
      print('🎉 FCM Token saved successfully to Supabase for user: $userId');
    } catch (e) {
      print('🔥 Failed to save token to database: $e');
    }
  }
}
