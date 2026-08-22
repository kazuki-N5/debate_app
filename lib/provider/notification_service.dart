// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:debate_project/router/router.dart';

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
        print('Notification tapped: ${details.payload}');
        if (details.payload != null && details.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(details.payload!) as Map<String, dynamic>;
            final type = data['type'];
            final inviteId = data['invite_id'];
            if (type == 'resba_invite' && inviteId != null && inviteId.toString().isNotEmpty) {
              router.push(
                '/resbaRequest',
                extra: (inviteId: inviteId.toString(), notification: null),
              );
            }
          } catch (e) {
            print('Error handling notification tap payload: $e');
          }
        }
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
      final type = message.data['type'];
      print('Foreground message received: type=$type, title=${message.notification?.title}');

      // DMからのレスバ招待（resba_invite）のみ、フォアグラウンド（操作中）でも通知バナーを表示
      if (type == 'resba_invite') {
        final title = message.notification?.title ?? 'レスバの対戦申し込みが届きました！';
        final body = message.notification?.body ?? 'レスバの対戦申し込みが届きました';

        final androidDetails = AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          showWhen: true,
        );

        const darwinDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
        );

        _localNotifications.show(
          id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF,
          title: title,
          body: body,
          notificationDetails: notificationDetails,
          payload: jsonEncode(message.data),
        );
      }
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
