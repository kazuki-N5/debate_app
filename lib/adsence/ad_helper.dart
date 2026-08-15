// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  // バナー広告ユニットID
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    } else {
      return Platform.isAndroid
          ? 'ca-app-pub-3492733955068641/6834401429'
          : 'ca-app-pub-3492733955068641/1773646436';
    }
  }

  // インタースティシャル広告ユニットID
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    } else {
      return Platform.isAndroid
          ? 'ca-app-pub-3492733955068641/2175895717'
          : 'ca-app-pub-3492733955068641/2950996731';
    }
  }

  // mbannerのバナー広告ユニットID
  static String get mbannerAdUnitId {
    if (kDebugMode) {
      // mbannerも標準バナーのテストIDを使用
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    } else {
      return Platform.isAndroid
          ? 'ca-app-pub-3492733955068641/9560691015'
          : 'ca-app-pub-3492733955068641/2415879927';
    }
  }
}
