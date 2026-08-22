// ignore_for_file: file_names
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';

/// アプリ共通の確認ダイアログ
/// 
/// - [title]: ダイアログの見出しタイトル（例: 「応募を取り消しますか？」）
/// - [message]: 説明文や確認メッセージ
/// - [cancelText]: キャンセルボタンのテキスト（デフォルト: 'いいえ'）
/// - [confirmText]: 確定ボタンのテキスト（デフォルト: 'OK'）
/// - [isDestructive]: 削除やブロックなど不可逆・危険な操作の場合は true (赤色ボタン)
/// - [barrierDismissible]: ダイアログ外タップで閉じるか（デフォルト: true）
Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = 'いいえ',
  String confirmText = 'OK',
  bool isDestructive = false,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final confirmColor = isDestructive ? const Color(0xFFEF4444) : Colors.blue;

      return Dialog(
        backgroundColor: Colors.white,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22.0, 24.0, 22.0, 20.0),
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
              // ボタン列 (2列横並び)
              Row(
                children: [
                  // キャンセルボタン (いいえ)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9), // slate-100
                          foregroundColor: const Color(0xFF334155), // slate-700
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(
                          cancelText,
                          style: AppTextStyles.bold(
                            fontSize: 14,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 確定ボタン (はい / 削除 / ブロック等)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: confirmColor.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(
                          confirmText,
                          style: AppTextStyles.bold(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
