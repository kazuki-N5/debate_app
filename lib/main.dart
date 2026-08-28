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


import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/provider/notification_service.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/widgets/resba_applying_banner.dart';
import 'package:debate_project/adsence/ad_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final scaffoldMessengerKeyProvider = Provider((ref) => GlobalKey<ScaffoldMessengerState>());


void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: '.env');

  // Firebaseの初期化
  await Firebase.initializeApp();
  // AdMobのIDFA説明メッセージ / UMP同意取得と初期化
  await AdConsentService.requestConsentAndInitializeAds();


  await Supabase.initialize(
    url: dotenv.get('P_VAR_URL'), // .envのURLを取得.
    anonKey: dotenv.get('P_VAR_ANONKEY'), // .envのanonキーを取得.
  );

  // ★診断用: どのバックエンドに接続しているか確認する(実機/エミュレータの差異調査)
  log('🔌 Supabase URL: ${dotenv.get('P_VAR_URL')}');

  // 通知プロバイダーのコンテナを作成 (ProviderScopeなしの状態でもアクセス可能にするため。またはProviderScope内でrefを利用)
  final container = ProviderContainer();
  await container.read(notificationServiceProvider).initialize();

  // ローカルカウンター: アプリ起動回数を数え、Finishページ表示回数と合算して
  // 合計4回になったらレビューお願いダイアログを表示する
  // （表示自体はHomePage側でisreviewフラグにより一度だけ行う）
  try {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(reviewTriggerCountPrefKey) ?? 0) + 1;
    await prefs.setInt(reviewTriggerCountPrefKey, count);
    if (count == 4) {
      container.read(reviewProvider.notifier).state = true;
    }
  } catch (e) {
    // カウント失敗時は表示判定をスキップ（アプリ起動は継続する）
    log('レビューカウンターの更新に失敗: $e');
  }

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
