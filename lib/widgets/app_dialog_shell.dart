// ignore_for_file: file_names
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';

/// アプリ共通のダイアログ骨格（スケルトン）
///
/// アプリ内のすべてのダイアログで共通の見た目（白背景・角丸24・
/// 共通タイトル/本文スタイル・共通ボタン列）を提供する。
/// 内容は [title] / [image] / [message] / [buttons] で差し替える。
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    super.key,
    required this.title,
    this.image,
    required this.message,
    required this.buttons,
  });

  /// ダイアログの見出し
  final String title;

  /// タイトルと本文の間に表示する任意のウィジェット（画像など）
  final Widget? image;

  /// 説明文
  final String message;

  /// ボタン列（[AppDialogButton] を推奨。1個なら全幅、2個以上なら横並び）
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22.0, 24.0, 22.0, 20.0),
        child: SingleChildScrollView(
          // コンテンツが溢れた場合にスクロール可能に（見た目は不変）
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // タイトル
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.bold(
                  color: const Color(0xFF0F172A), // slate-900
                  fontSize: 17.5,
                ),
              ),
              const SizedBox(height: 12.0),
              // 任意画像（タイトルと本文の間）
              if (image != null) ...[
                image!,
                const SizedBox(height: 12.0),
              ],
              // 説明文
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.notoSans(
                  color: const Color(0xFF64748B), // slate-500
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24.0),
              // ボタン列（1個なら全幅・2個以上なら横並び）
              if (buttons.length == 1)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: buttons.first,
                )
              else
                Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: buttons[i],
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 共通ダイアログのボタン種別
enum AppDialogButtonVariant {
  /// キャンセル用（グレー背景・濃グレー文字）
  cancel,

  /// 確定用（[AppDialogButton.confirmColor] 背景・白文字）
  confirm,
}

/// アプリ共通のダイアログボタン
///
/// [AppDialogShell.buttons] に渡して使う。高さ44・角丸12の
/// 共通スタイルを持つ。
class AppDialogButton extends StatelessWidget {
  const AppDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppDialogButtonVariant.cancel,
    this.confirmColor = Colors.blue,
  });

  /// ボタンに表示するテキスト
  final String label;

  /// タップ時のコールバック
  final VoidCallback onPressed;

  /// テキストの左に表示するアイコン（任意）
  final Widget? icon;

  /// ボタンの種別（キャンセル/確定）
  final AppDialogButtonVariant variant;

  /// 確定ボタンの背景色（削除など危険な操作は赤を指定）
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    final bool isCancel = variant == AppDialogButtonVariant.cancel;
    final Color backgroundColor =
        isCancel ? const Color(0xFFF1F5F9) : confirmColor; // slate-100
    final Color foregroundColor =
        isCancel ? const Color(0xFF334155) : Colors.white; // slate-700

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: isCancel ? 0 : 2,
        shadowColor:
            isCancel ? Colors.transparent : confirmColor.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: onPressed,
      child: icon == null
          ? Text(
              label,
              style: AppTextStyles.bold(fontSize: 14, color: foregroundColor),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon!,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.bold(
                    fontSize: 14,
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
    );
  }
}
