// ignore_for_file: file_names
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';

/// レスバの添付内容（テーマ + 選択肢）
class ResbaAttachment {
  final String theme;
  final String? choice1;
  final String? choice2;
  const ResbaAttachment({required this.theme, this.choice1, this.choice2});
}

/// 写真を添付する感覚でレスバ（テーマ・選択肢）を設定するボトムシート
Future<ResbaAttachment?> showResbaAttachSheet(
  BuildContext context, {
  String? presetTheme,
}) {
  return showModalBottomSheet<ResbaAttachment>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ResbaAttachSheet(presetTheme: presetTheme),
  );
}

class _ResbaAttachSheet extends StatefulWidget {
  final String? presetTheme;
  const _ResbaAttachSheet({this.presetTheme});

  @override
  State<_ResbaAttachSheet> createState() => _ResbaAttachSheetState();
}

class _ResbaAttachSheetState extends State<_ResbaAttachSheet> {
  late final TextEditingController _themeController;
  final _choice1Controller = TextEditingController();
  final _choice2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _themeController = TextEditingController(text: widget.presetTheme ?? '');
  }

  @override
  void dispose() {
    _themeController.dispose();
    _choice1Controller.dispose();
    _choice2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('レスバを送る', style: AppTextStyles.bold(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '相手が承諾すると対戦が始まります',
              style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _label('テーマ（必須）'),
            TextField(
              controller: _themeController,
              maxLength: 60,
              style: const TextStyle(fontSize: 14),
              decoration: _decoration(hint: '例：AIは人間の仕事を奪うか？'),
            ),
            const SizedBox(height: 8),
            _label('選択肢1（任意）'),
            TextField(
              controller: _choice1Controller,
              maxLength: 30,
              style: const TextStyle(fontSize: 14),
              decoration: _decoration(hint: '例：賛成'),
            ),
            const SizedBox(height: 8),
            _label('選択肢2（任意）'),
            TextField(
              controller: _choice2Controller,
              maxLength: 30,
              style: const TextStyle(fontSize: 14),
              decoration: _decoration(hint: '例：反対'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('キャンセル'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final theme = _themeController.text.trim();
                      if (theme.isEmpty) return;
                      Navigator.pop(
                        context,
                        ResbaAttachment(
                          theme: theme,
                          choice1: _choice1Controller.text.trim().isEmpty
                              ? null
                              : _choice1Controller.text.trim(),
                          choice2: _choice2Controller.text.trim().isEmpty
                              ? null
                              : _choice2Controller.text.trim(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7856FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('⚔️ レスバを送る'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: AppTextStyles.bold(fontSize: 12, color: Colors.black87)),
      );

  InputDecoration _decoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      counterText: '',
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF3F3F3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
