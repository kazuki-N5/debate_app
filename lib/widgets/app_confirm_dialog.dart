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
  String? cancelText = 'いいえ',
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
              // ボタン列
              if (cancelText != null)
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
                )
              else
                SizedBox(
                  width: double.infinity,
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
            ],
          ),
        ),
      );
    },
  );
}

/// メンバー退出確認ダイアログ（再参加禁止チェックボックス付き / アイコンなし・共通スタイル）
/// 
/// 戻り値:
/// - null: キャンセル
/// - false: 通常の退出（再参加可能）
/// - true: 強制退会（再参加禁止）
Future<bool?> showKickMemberConfirmDialog({
  required BuildContext context,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      bool isBanChecked = false;

      return StatefulBuilder(
        builder: (context, setState) {
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
                  // タイトル（アイコンなし）
                  Text(
                    'メンバーの削除',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bold(
                      color: const Color(0xFF0F172A),
                      fontSize: 17.5,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  // 説明文
                  Text(
                    'このメンバーをクラブから退出させますか？',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.notoSans(
                      color: const Color(0xFF64748B),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  // 再参加禁止チェックボックス
                  InkWell(
                    onTap: () {
                      setState(() {
                        isBanChecked = !isBanChecked;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isBanChecked ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBanChecked ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: isBanChecked,
                              activeColor: const Color(0xFFEF4444),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  isBanChecked = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '再参加を禁止する (強制退会)',
                                  style: AppTextStyles.bold(
                                    fontSize: 13,
                                    color: isBanChecked ? const Color(0xFFDC2626) : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '今後のクラブへの再参加をブロックします',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isBanChecked ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  // ボタン列
                  Row(
                    children: [
                      // キャンセルボタン
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF334155),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(null),
                            child: Text(
                              'キャンセル',
                              style: AppTextStyles.bold(
                                fontSize: 14,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 削除・退出実行ボタン
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(isBanChecked),
                            child: Text(
                              isBanChecked ? '強制退会' : '削除する',
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
    },
  );
}
