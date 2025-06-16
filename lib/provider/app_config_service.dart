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

  Future<AppConfig?> fetchAppConfig() async {
    Map<String, dynamic>? responseMap;
    try {
      try {
         responseMap = await supabase.from('app_config').select().single();
      } on PostgrestException catch (error) {
        if (error.code == 'PGRST301') {
          print('jwt expired');
          try {
            // セッションのリフレッシュを試みる
            await supabase.auth.refreshSession();
            print('セッションの更新に成功しました。');

            // リフレッシュ後、再度APIを呼び出す
             responseMap = await supabase.from('app_config').select().single();
          } catch (e) {
            print('セッションの更新に失敗しました: $e');
          }
        } else {
          print('セッション以外のエラーAppConfigの取得に失敗しました: $error');
        }
      }

      String? minVersion;
      String? latestVersion;

      if (Platform.isAndroid) {
        minVersion = responseMap!['min_supported_version_android']?.toString();
        latestVersion = responseMap['latest_version_android']?.toString();
      } else if (Platform.isIOS) {
        minVersion = responseMap!['min_supported_version_ios']?.toString();
        latestVersion = responseMap['latest_version_ios']?.toString();
      }
      // 他のプラットフォーム（Web, Desktopなど）をサポートする場合はここに追加の条件分岐を記述

      state = AppConfig(
        minVersion: minVersion,
        latestVersion: latestVersion,
        changelog: responseMap!['changelog']?.toString(),
        isMaintenanceMode: responseMap['is_maintenance'] as bool?,
        maintenanceMessage: responseMap['maintenance_message']?.toString(),
      );
      return state;
    } catch (e) {
      print('AppConfigの取得に失敗しました: $e');
      throw e;
    }
  }
}

// AppConfigStateNotifierを提供するStateNotifierProvider
