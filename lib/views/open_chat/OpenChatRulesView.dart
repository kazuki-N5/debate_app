import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// クラブのルール閲覧・編集画面
class OpenChatRulesView extends HookConsumerWidget {
  final OpenChatRoom room;

  const OpenChatRulesView({
    super.key,
    required this.room,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(supabaseProvider).auth.currentUser?.id;
    final isOwner = currentUserId == room.ownerId;

    // 最新のルーム情報を取得（ルール更新の反映用）
    final roomDetailAsync = ref.watch(openChatRoomDetailProvider(room.id));
    final currentRoom = roomDetailAsync.valueOrNull ?? room;
    final rulesText = currentRoom.rules ?? '';

    final isEditing = useState(false);
    final rulesController = useTextEditingController(text: rulesText);
    final isSaving = useState(false);

    useEffect(() {
      if (!isEditing.value) {
        rulesController.text = rulesText;
      }
      return null;
    }, [rulesText]);

    // ルール保存処理
    Future<void> handleSaveRules() async {
      isSaving.value = true;
      try {
        final error = await ref
            .read(openChatActionProvider.notifier)
            .updateRules(room.id, rulesController.text.trim());

        if (context.mounted) {
          if (error == null) {
            isEditing.value = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ルールを更新しました')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('エラー: $error')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('予期せぬエラー: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'クラブのルール',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: isEditing.value
                  ? TextButton(
                      onPressed: isSaving.value ? null : handleSaveRules,
                      child: isSaving.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              '保存',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    )
                  : TextButton(
                      onPressed: () {
                        rulesController.text = rulesText;
                        isEditing.value = true;
                      },
                      child: const Text(
                        '編集',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ルール表示 または 編集フォーム
                if (isEditing.value) ...[
                  TextField(
                    controller: rulesController,
                    maxLines: 15,
                    style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: '例:\n1. 誹謗中傷・人格攻撃の禁止\n2. 根拠のある議論を心がける\n3. 連続投稿は控える',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          isEditing.value = false;
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('キャンセル'),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${currentRoom.name} のルール',
                          style: AppTextStyles.bold(color: Colors.black87, fontSize: 15),
                        ),
                        const Divider(height: 24, thickness: 1),
                        if (rulesText.isNotEmpty)
                          Text(
                            rulesText,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          )
                        else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Text(
                                'まだルールは設定されていません。',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
