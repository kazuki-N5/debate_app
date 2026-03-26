// lib/providers/app_config_state_notifier.dart
import 'dart:io' show Platform; // Platform判定のためにインポート// モデルのパスを確認してください
import 'package:debate_project/modes/app_config_model.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // SupabaseClientのためにインポート

final appConfigProvider =
    StateNotifierProvider<AppConfigStateNotifier, AppConfig?>((ref) {
  return AppConfigStateNotifier(ref);
});

// AppConfigを管理するStateNotifier
class AppConfigStateNotifier extends StateNotifier<AppConfig?> {
  // コンストラクタでSupabaseClientを受け取り、初期データをフェッチ
  AppConfigStateNotifier(this._ref) : super(null) {
    // 初期値をnullに変更
    fetchAppConfig(); // 初期化時にデータをフェッチ
  }
  final Ref _ref;
  SupabaseClient get supabase => _ref.read(supabaseProvider);

  Future<AppConfig?> fetchAppConfig({int retryCount = 0}) async {
    try {
      final responseMap = await supabase.from('app_config').select().single();

      String? minVersion;
      String? latestVersion;
      String? maxVersion;

      if (Platform.isAndroid) {
        minVersion = responseMap['min_supported_version_android']?.toString();
        latestVersion = responseMap['latest_version_android']?.toString();
        maxVersion = responseMap['max_version_android']?.toString();
      } else if (Platform.isIOS) {
        minVersion = responseMap['min_supported_version_ios']?.toString();
        latestVersion = responseMap['latest_version_ios']?.toString();
        maxVersion = responseMap['max_version_ios']?.toString();
      }

      state = AppConfig(
        minVersion: minVersion,
        latestVersion: latestVersion,
        maxVersion: maxVersion,
        changelog: responseMap['changelog']?.toString(),
        isMaintenanceMode: responseMap['is_maintenance'] as bool?,
        maintenanceMessage: responseMap['maintenance_message']?.toString(),
      );
      return state;
    } on PostgrestException catch (error) {
      // PGRST301(期限切れ) または PGRST303(Unauthorized) の場合、1回だけリフレッシュを試みる
      if ((error.code == 'PGRST301' || error.code == 'PGRST303') &&
          retryCount < 1) {
        print('JWT expired or unauthorized. Refreshing session...');
        try {
          await supabase.auth.refreshSession();
          return await fetchAppConfig(retryCount: retryCount + 1);
        } catch (refreshError) {
          print('Session refresh failed: $refreshError');
        }
      }
      print('セッション以外のエラーAppConfigの取得に失敗しました: $error');
      rethrow; // 上位のAppStatus.error処理に任せる
    } catch (e) {
      print('AppConfigの取得中に予期せぬエラーが発生しました: $e');
      rethrow;
    }
  }
}

// AppConfigStateNotifierを提供するStateNotifierProvider
