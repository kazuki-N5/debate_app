import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// アプリ全体の共通テキストスタイルを提供するクラス
class AppTextStyles {
  /// 基本的な Noto Sans JP スタイルを返す
  ///
  /// [fontSize] 文字サイズ
  /// [fontWeight] 文字の太さ (デフォルトは normal)
  /// [color] 文字の色 (デフォルトは black)
  /// [height] 行間 (デフォルトは 1.0)
  /// [decoration] 打ち消し線や下線
  static TextStyle notoSans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return GoogleFonts.notoSansJp(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 太字の Noto Sans JP スタイルを返す
  static TextStyle bold({
    double? fontSize,
    Color? color,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return notoSans(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// ThemeData の fontFamily 用の文字列を返す
  static String get fontFamily => GoogleFonts.notoSansJp().fontFamily!;

  /// ThemeData の textTheme 用の Noto Sans JP TextTheme を返す
  static TextTheme notoSansTextTheme([TextTheme? base]) {
    return GoogleFonts.notoSansJpTextTheme(base);
  }
}
