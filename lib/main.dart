import 'package:debate_project/router/router.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
//import 'package:google_mobile_ads/google_mobile_ads.dart';


import 'package:debate_project/widgets/app_text_styles.dart';

final scaffoldMessengerKeyProvider = Provider((ref) => GlobalKey<ScaffoldMessengerState>());


void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: '.env');

  // Firebaseの初期化
  await Firebase.initializeApp();
  //await MobileAds.instance.initialize();


  await Supabase.initialize(
    url: dotenv.get('P_VAR_URL'), // .envのURLを取得.
    anonKey: dotenv.get('P_VAR_ANONKEY'), // .envのanonキーを取得.
  );

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
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
    );
  }
}
