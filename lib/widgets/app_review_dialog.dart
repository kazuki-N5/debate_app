// ignore_for_file: file_names
import 'package:debate_project/widgets/app_dialog_shell.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ共通のレビューお願いダイアログ
///
/// 共通ダイアログ骨格（[AppDialogShell]）を使い、ほかの確認ダイアログ
/// （[showAppConfirmDialog]）と同じ見た目で表示する。
/// - タイトル: 「応援をよろしくお願いします！」
/// - 画像: assets/images/stars.png
/// - ボタン: 「また今度」 / 「応援する」(OSのレビュー画面を開く)
///
/// 「また今度」「応援する」どちらを押しても SharedPreferences の
/// `isreview` フラグを true に設定する（一度だけ表示するための
/// 判定は呼び出し側で行う）。
Future<void> showAppReviewDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AppDialogShell(
        title: '応援をよろしくお願いします！',
        image: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Image.asset(
            'assets/images/stars.png',
            height: 150, // 画像の高さを適宜調整
            fit: BoxFit.contain,
          ),
        ),
        message:
            'いつもご利用いただきありがとうございます。\nより良いコンテンツをお届けられるように日々改善を続けております。\nぜひレビューしていただけると嬉しいです！',
        buttons: [
          AppDialogButton(
            label: 'また今度',
            variant: AppDialogButtonVariant.cancel,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.setBool('isreview', true);
            },
          ),
          AppDialogButton(
            label: '応援する',
            variant: AppDialogButtonVariant.confirm,
            icon: const Icon(Icons.star, color: Colors.white, size: 18),
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              final InAppReview inAppReview = InAppReview.instance;

              if (await inAppReview.isAvailable()) {
                inAppReview.requestReview();
              }

              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.setBool('isreview', true);
            },
          ),
        ],
      );
    },
  );
}
