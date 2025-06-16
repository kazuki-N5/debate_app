import 'dart:io';

class AdHelper {

  // テスト用バナー広告ユニットID
  // AdMobのテストIDはAndroid/iOS共通です
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // Android向けテストID
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      // iOS向けテストID (Androidと同じ)
      return 'ca-app-pub-3940256099942544/6300978111';
    } else {
      throw new UnsupportedError('Unsupported platform');
    }
  }

  // テスト用インタースティシャル広告ユニットID
  // AdMobのテストIDはAndroid/iOS共通です
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      // Android向けテストID
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      // iOS向けテストID (Androidと同じ)
      return 'ca-app-pub-3940256099942544/1033173712';
    } else {
      throw new UnsupportedError("Unsupported platform");
    }
  }

  // テスト用バナー広告ユニットID (mbannerも標準バナーテストIDを使用)
  // AdMobのテストIDはAndroid/iOS共通です
  static String get mbannerAdUnitId {
    if (Platform.isAndroid) {
      // Android向けテストID (標準バナーテストID)
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      // iOS向けテストID (標準バナーテストID, Androidと同じ)
      return 'ca-app-pub-3940256099942544/6300978111';
    } else {
      throw new UnsupportedError('Unsupported platform');
    }
  }
}

/*class AdHelper {

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    } else {
      throw new UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    } else {
      throw new UnsupportedError("Unsupported platform");
    }
  }
  static String get mbannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    } else {
      throw new UnsupportedError('Unsupported platform');
    }
  }
}*/