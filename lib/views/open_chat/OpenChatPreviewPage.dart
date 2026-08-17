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
        title: Text('オープンチャット', style: AppTextStyles.bold(fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
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
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 250,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 250,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.forum, size: 80, color: Colors.grey),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // タイトル
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      room.name,
                      style: AppTextStyles.bold(fontSize: 22, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // メンバー数
                  Text(
                    'メンバー ${room.memberCount ?? 0}',
                    style: AppTextStyles.notoSans(fontSize: 14, color: Colors.black54),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 説明文
                  if (room.description != null && room.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        room.description!,
                        style: AppTextStyles.notoSans(fontSize: 14, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                  const SizedBox(height: 40),

                  // パスワード入力欄 (パスワード設定がある場合)
                  if (hasPassword) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '合言葉を入力してください',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
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
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading.value ? null : handleJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // 緑ではなく青色にする
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: isLoading.value
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        '参加',
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
