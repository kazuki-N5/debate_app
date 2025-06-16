
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
  AppStateNotifier(this._ref) : super(AppStatus.loading) {}
  
 
  SupabaseClient get supabase => _ref.read(supabaseProvider);
  Future<String> chackAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('AppConfigの取得に失敗しました: $e');
      throw e;
    }
  }

  Future<void> saveVersion(String version) async {
    // version の型を明示
    try {
      // SharedPreferences のインスタンスを取得
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('thisappversionkey', version);
    } catch (e) {
      throw e;
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
    throw e;
  }
}


  Future<AppStatus> loadVersion() async {
    final appconfignotifier = _ref.read(appConfigProvider.notifier);

    try {
      final app_config = await appconfignotifier.fetchAppConfig();
      final thisversion = Version.parse(await chackAppVersion());
      print('今のスマホのバージョン: $thisversion');
      final isMaintenance = app_config!.isMaintenanceMode;
      Version? latestversion;
      Version? minversion;

      latestversion = Version.parse(app_config.latestVersion!);
      minversion = Version.parse(app_config.minVersion!);

      if (thisversion <= minversion) {
        return AppStatus.forceUpdate;
      } else if (isMaintenance == true) {
        return AppStatus.maintenance;
      } else if (minversion < thisversion && thisversion < latestversion) {
        return AppStatus.optionalUpdate;
      } else if (latestversion == thisversion) {
        return AppStatus.normal;
      } else {
        return AppStatus.error;
      }
    } catch (e) {
      return AppStatus.error;
    }
  }
}
