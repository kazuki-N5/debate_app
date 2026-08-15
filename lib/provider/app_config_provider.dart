// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:developer';
import 'package:debate_project/provider/app_config_service.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:version/version.dart';

enum AppStatus {
  normal,
  forceUpdate,
  optionalUpdate,
  maintenance,
  loading,
  error,
}

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppStatus>((ref) {
  // AppStateNotifier のインスタンスを作成し、Ref を渡す
  return AppStateNotifier(ref);
});

// SupabaseクライアントのProvider (main.dartなどで初期化済みであること)

// AppConfigを管理するStateNotifier
class AppStateNotifier extends StateNotifier<AppStatus> {
  final Ref _ref;

  // コンストラクタでRefを受け取り、初期状態と初期化処理の呼び出し
  AppStateNotifier(this._ref) : super(AppStatus.loading);

  SupabaseClient get supabase => _ref.read(supabaseProvider);
  Future<String> chackAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      print('AppConfigの取得に失敗しました: $e');
      rethrow;
    }
  }

  Future<void> saveVersion(String version) async {
    // version の型を明示
    try {
      // SharedPreferences のインスタンスを取得
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('thisappversionkey', version);
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getVersion() async {
    try {
      // SharedPreferences のインスタンスを取得
      final prefs = await SharedPreferences.getInstance();
      final String? version = prefs.getString('thisappversionkey');
      return version;
    } catch (e) {
      // エラーが発生した場合は、呼び出し元にエラーをスロー
      rethrow;
    }
  }

  Future<AppStatus> loadVersion() async {
    final appConfigNotifier = _ref.read(appConfigProvider.notifier);

    try {
      final appConfig = await appConfigNotifier.fetchAppConfig();
      if (appConfig == null) {
        log('AppConfigがnullのためエラーを返します');
        return AppStatus.error;
      }

      final thisVersion = Version.parse(await chackAppVersion());
      log('現在のアプリバージョン: $thisVersion');

      // 1. maxversionが今のバージョンと完全一致だったらノーマル（開発用などでバイパスするため）
      if (appConfig.maxVersion != null && appConfig.maxVersion!.isNotEmpty) {
        final maxVersion = Version.parse(appConfig.maxVersion!);
        if (thisVersion == maxVersion) {
          log('maxVersion一致により開発用バイパス(normal)として判定されました');
          return AppStatus.normal;
        }
      }

      // 2. メンテナンス
      if (appConfig.isMaintenanceMode == true) {
        log('メンテナンスモードとして判定されました');
        return AppStatus.maintenance;
      }

      // 3. 矯正アップデート (現在のバージョンが最小サポートバージョン未満)
      if (appConfig.minVersion != null && appConfig.minVersion!.isNotEmpty) {
        final minVersion = Version.parse(appConfig.minVersion!);
        if (thisVersion < minVersion) {
          log('最小サポートバージョン（$minVersion）未満のため、強制アップデートが必要です');
          return AppStatus.forceUpdate;
        }
      }

      // 4. オプショナルアップデート (現在のバージョンが最新バージョン未満)
      if (appConfig.latestVersion != null &&
          appConfig.latestVersion!.isNotEmpty) {
        final latestVersion = Version.parse(appConfig.latestVersion!);
        if (thisVersion < latestVersion) {
          log('最新バージョン（$latestVersion）が利用可能なため、オプショナルアップデートを推奨します');
          return AppStatus.optionalUpdate;
        }
      }

      // 5. ノーマル
      log('正常（最新バージョン）として判定されました');
      return AppStatus.normal;
    } catch (e) {
      log('バージョンチェック中にエラーが発生しました: $e');
      return AppStatus.error;
    }
  }
}
