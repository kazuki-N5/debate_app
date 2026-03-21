import 'package:debate_project/router/router.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:debate_project/widgets/app_text_styles.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: '.env');

  // Firebaseの初期化
  await Firebase.initializeApp();

  // プッシュ通知の権限リクエスト
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // FCMトークンの取得テスト（確認用）
  try {
    final token = await messaging.getToken();
    print("🔥 FCM Token: $token");
    // TODO: ここでトークンをSupabase(ユーザー情報)に保存する。MVVM構造に則ってProvider等で実装する。
  } catch (e) {
    print("🔥 FCM Token Error: $e");
  }

  await Supabase.initialize(
    url: dotenv.get('VAR_URL'), // .envのURLを取得.
    anonKey: dotenv.get('VAR_ANONKEY'), // .envのanonキーを取得.
  );

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Debate App',
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      theme: ThemeData(
        fontFamily: AppTextStyles.fontFamily,
        textTheme: AppTextStyles.notoSansTextTheme(
          Theme.of(context).textTheme,
        ),
        primarySwatch: Colors.blue,
      ),
    );
  }
}
