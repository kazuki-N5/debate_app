// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:io';
import 'package:debate_project/adsence/ad_banner_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // logInを使わないので不要になるかも

// FirebaseAuthのインスタンスはどこか他で定義されていると仮定
// final auth = FirebaseAuth.instance;

final inAppPurchaseManagerProvider = // Providerの名前を変更
    ChangeNotifierProvider((ref) => InAppPurchaseManager(ref));

class InAppPurchaseManager with ChangeNotifier {
  final Ref _ref;
  InAppPurchaseManager(this._ref);
  bool isSubscribed = false;
  Offerings? offerings; // 初期値はnullの可能性があるので?をつける

  bool _isConfigured = false;

  // ★変更点1: init処理を最新版向けにリファクタリング
  Future<void> initInAppPurchase() async {
    if (_isConfigured) return; // 二重初期化を防ぐ

    try {
      // 開発時は詳細なログを出すように設定
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      await dotenv.load(fileName: '.env');
      
      // プラットフォームごとの設定
      final String apiKey = Platform.isAndroid 
          ? dotenv.get('REVENUECAT_GOOGLE') 
          : dotenv.get('REVENUECAT_APPLE');

      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = null // 匿名ユーザー（後で認証システムと紐付けも可能）
        ..purchasesAreCompletedBy = const PurchasesAreCompletedByRevenueCat();

      await Purchases.configure(configuration);
      _isConfigured = true;

      // Offeringsを取得
      offerings = await Purchases.getOfferings();

      // ★重要：logIn処理を削除する
      // final result = await Purchases.logIn(auth.currentUser!.uid); // この行を削除

      // ★変更点2: リスナーを設定して購入状態の変更を検知する
      // これにより、復元された時などにも自動でisSubscribedが更新される
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        // customerInfoが更新されるたびにチェック処理を呼び出す
        updatePurchaseStatus(customerInfo);
      });

      // ★変更点3: 初回の購入状態チェック
      // アプリ起動時に現在の状態を取得して反映させる
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePurchaseStatus(customerInfo);
      if (isSubscribed == false) {
        _ref.read(bannerAdProvider.notifier).loadAd();
        _ref.read(matchingBannerAdProvider.notifier).loadAd();
      }
    } catch (e) {
      print("initInAppPurchase error caught! ${e.toString()}");
    }
  }

  // ★変更点4: メソッド名を変更し、notifyListenersを呼ぶようにする
  Future<void> updatePurchaseStatus(CustomerInfo customerInfo) async {
    // ご自身のEntitlement名に書き換えてください
    const entitlementID = 'delete_ads'; // 例: 'ad_free' など

    // entitlements.allはMapなので、キーが存在するかどうかと、そのキーの値がisActiveかを見る
    final entitlement = customerInfo.entitlements.all[entitlementID];

    // シンプルな判定ロジック
    // entitlementが存在し、かつisActiveなら購読中
    final newStatus = entitlement != null && entitlement.isActive;

    // 状態が変わった場合のみ更新して通知する
    if (isSubscribed != newStatus) {
      isSubscribed = newStatus;
      notifyListeners(); // UIに変更を通知
      print("購読状態が更新されました: $isSubscribed");
    }
  }

  // ★任意: 購入処理と復元処理の例
  // UIからこれらのメソッドを呼び出す

  Future<void> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final customerInfo = result.customerInfo;
      // 購入が成功すると、上のリスナーが自動で呼ばれて状態が更新される
      print("購入成功: ${customerInfo.entitlements.all}");
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print("購入エラー: $e");
      }
    } catch (e) {
      print("購入エラー: $e");
    }
  }

  Future<void> restorePurchases() async {
    try {
      CustomerInfo restoredInfo = await Purchases.restorePurchases();
      // 復元が成功すると、リスナーが自動で呼ばれて状態が更新される
      print("復元成功: ${restoredInfo.entitlements.all}");
    } on PlatformException catch (e) {
      print("復元エラー: $e");
    }
  }
}
