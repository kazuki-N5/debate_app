// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

/// 通知関連のサービスを管理するProvider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Android用の通知チャンネル設定 (ポップアップを有効にするための設定)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel_v4', // 新しいIDに変更して設定を強制更新
    'High Importance Notifications', // チャンネル名
    description: 'このチャンネルは対戦通知などの重要な通知に使用されます',
    importance: Importance.max, // ポップアップ（Heads-up）表示に必須
    playSound: true,
    showBadge: false, // バッジ（ドット）を表示しないよう修正
  );

  NotificationService(Ref ref); // RiverpodのRefを受け取るが現在は未使用

  /// 通知の初期化設定 (iOS/Android共通)
  Future<void> initialize() async {
    // Android固有の初期化設定
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS固有の初期化設定 (foregroundでの通知表示設定も含む)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // プラグインの初期化 (v20.x は名前付き引数 settings が必須)
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // 通知がタップされた時の処理をここに記述
        print('Notification tapped: ${details.payload}');
      },
    );

    // Android 8.0以上で必須のチャンネル作成
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_channel);
      }
    }

    // フォアグラウンドでのリスナー登録
    _listenToForegroundMessages();

    // 起動時にバッジ/通知をクリアする (数字が溜まらないようにする対策)
    await clearBadge();
  }

  /// フォアグラウンドで通知を受け取った時のリスナー
  void _listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received (notification suppressed): ${message.notification?.title}');
      
      // アプリ操作中（フォアグラウンド）は通知を出さない方針のため、
      // ここでの _localNotifications.show は行いません。
    });
  }

  /// バッジと全ての通知をクリアするメソッド
  Future<void> clearBadge() async {
    try {
      await _localNotifications.cancelAll();
      print('Notification badge and tray cleared.');
    } catch (e) {
      print('Error clearing badge: $e');
    }
  }

  /// 通知の権限リクエスト (Android 13+ および iOS)
  Future<void> requestPermissions() async {
    // Firebaseの既存リクエスト
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+ のためのローカル通知権限リクエスト
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }
}
