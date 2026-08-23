// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:developer';
import 'package:debate_project/router/router.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/provider/notification_service.dart';
import 'package:debate_project/widgets/resba_applying_banner.dart';

final scaffoldMessengerKeyProvider = Provider((ref) => GlobalKey<ScaffoldMessengerState>());


void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: '.env');

  // Firebaseの初期化
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();


  await Supabase.initialize(
    url: dotenv.get('P_VAR_URL'), // .envのURLを取得.
    anonKey: dotenv.get('P_VAR_ANONKEY'), // .envのanonキーを取得.
  );

  // ★診断用: どのバックエンドに接続しているか確認する(実機/エミュレータの差異調査)
  log('🔌 Supabase URL: ${dotenv.get('P_VAR_URL')}');

  // 通知プロバイダーのコンテナを作成 (ProviderScopeなしの状態でもアクセス可能にするため。またはProviderScope内でrefを利用)
  final container = ProviderContainer();
  await container.read(notificationServiceProvider).initialize();

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
        ),
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (BuildContext context) => const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      locale: const Locale('ja', 'JP'),
      // アプリ全体の最前面にレスバの応募中バナーを重ねる
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const ResbaApplyingBanner(),
          ],
        );
      },
    );
  }
}
