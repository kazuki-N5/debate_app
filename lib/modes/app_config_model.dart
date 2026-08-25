// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
// lib/models/app_config_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_config_model.freezed.dart';

@freezed
abstract class AppConfig with _$AppConfig {
  const factory AppConfig({
    String? minVersion, // 変更: 汎用的な最小サポートバージョン
    String? latestVersion, // 変更: 汎用的な最新バージョン
    String? maxVersion, // 追加: 開発用の最大バージョン
    String? changelog, // 共通の変更ログ
    bool? isMaintenanceMode,
    String? maintenanceMessage,
  }) = _AppConfig;

  // fromMap ファクトリメソッドは StateNotifier 側でロジックを実装するため削除、
  // またはプラットフォームに応じた値の選択ロジックを StateNotifier に委譲します。
  // ここでは、StateNotifier内で直接AppConfigインスタンスを生成するアプローチを取ります。
}
