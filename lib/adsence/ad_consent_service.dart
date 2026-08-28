import 'dart:async';
import 'dart:developer';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentService {
  /// AdMobのIDFA説明メッセージ / UMP同意フォームを要求・表示し、広告を初期化する
  static Future<void> requestConsentAndInitializeAds() async {
    final completer = Completer<void>();

    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          final isAvailable = await ConsentInformation.instance.isConsentFormAvailable();
          if (isAvailable) {
            ConsentForm.loadConsentForm(
              (ConsentForm consentForm) async {
                final status = await ConsentInformation.instance.getConsentStatus();
                if (status == ConsentStatus.required) {
                  consentForm.show(
                    (FormError? formError) async {
                      if (formError != null) {
                        log('AdMob ConsentForm error: ${formError.errorCode} - ${formError.message}');
                      }
                      await _initializeMobileAds();
                      if (!completer.isCompleted) completer.complete();
                    },
                  );
                } else {
                  await _initializeMobileAds();
                  if (!completer.isCompleted) completer.complete();
                }
              },
              (FormError formError) async {
                log('AdMob ConsentForm load error: ${formError.errorCode} - ${formError.message}');
                await _initializeMobileAds();
                if (!completer.isCompleted) completer.complete();
              },
            );
          } else {
            await _initializeMobileAds();
            if (!completer.isCompleted) completer.complete();
          }
        } catch (e) {
          log('AdMob Consent processing error: $e');
          await _initializeMobileAds();
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError formError) async {
        log('AdMob ConsentInfoUpdate error: ${formError.errorCode} - ${formError.message}');
        // エラーが発生した場合でもアプリの起動が止まらないよう広告を初期化して続行
        await _initializeMobileAds();
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  static Future<void> _initializeMobileAds() async {
    try {
      await MobileAds.instance.initialize();
      log('AdMob MobileAds initialized successfully');
    } catch (e) {
      log('AdMob MobileAds initialization failed: $e');
    }
  }
}
