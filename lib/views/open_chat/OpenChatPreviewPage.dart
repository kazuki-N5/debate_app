import 'package:debate_project/modes/open_chat.dart';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OpenChatPreviewPage extends HookConsumerWidget {
  final OpenChatRoom room;

  const OpenChatPreviewPage({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState(false);
    final passwordController = useTextEditingController();
    
    // パスワードが設定されているかどうかの判定 (空文字でない場合)
    final bool hasPassword = room.password != null && room.password!.isNotEmpty;

    // タグ一覧（room.tags または説明文から抽出）
    final tags = (room.tags != null && room.tags!.isNotEmpty)
        ? room.tags!
        : (room.description != null ? extractTagsFromDescription(room.description!) : <String>[]);

    Future<void> handleJoin() async {
      // 合言葉のチェック
      if (hasPassword && passwordController.text != room.password) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('合言葉が間違っています')),
        );
        return;
      }

      isLoading.value = true;
      try {
        final error = await ref.read(openChatActionProvider.notifier).joinRoom(room.id);
        
        if (context.mounted) {
          if (error == null || error == 'ALREADY_JOINED') {
            // 参加成功 -> ルーム一覧を更新してチャットルームへ遷移
            ref.invalidate(openChatRoomsProvider);
            context.pushReplacement('/openChatRoom', extra: room);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('参加エラー: $error')),
            );
          }
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('クラブ', style: AppTextStyles.bold(fontSize: 20, color: Colors.white)),
        backgroundColor: Colors.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 背景画像
                  if (room.backgroundUrl != null && room.backgroundUrl!.isNotEmpty)
                    Image.network(
                      room.backgroundUrl!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 220,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE3F2FD), Color(0xFFEDE7F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.forum_rounded, size: 70, color: Colors.blueAccent),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // ルーム名
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      room.name,
                      style: AppTextStyles.bold(fontSize: 20, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // メンバー数 & 合言葉バッジ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'メンバー ${room.memberCount ?? 0}',
                        style: AppTextStyles.notoSans(fontSize: 13, color: Colors.grey[600]),
                      ),
                      if (hasPassword) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 12, color: Color(0xFFD97706)),
                              SizedBox(width: 3),
                              Text(
                                '合言葉あり',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // ハッシュタグチップ一覧
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  
                  // 説明文
                  if (room.description != null && room.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          room.description!,
                          style: AppTextStyles.notoSans(fontSize: 13, color: Colors.black87, height: 1.5),
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ),
                    
                  const SizedBox(height: 24),

                  // パスワード入力欄 (パスワード設定がある場合)
                  if (hasPassword) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '合言葉を入力してください',
                          prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFFD97706)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
          
          // 参加ボタン (画面下部固定)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading.value ? null : handleJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: isLoading.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        '参加する',
                        style: AppTextStyles.bold(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom), // セーフエリア対応
        ],
      ),
    );
  }
}
