import 'dart:io';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class OpenChatCreateRoomPage extends HookConsumerWidget {
  const OpenChatCreateRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final descController = useTextEditingController();
    final passwordController = useTextEditingController();

    final iconImage = useState<File?>(null);
    final backgroundImage = useState<File?>(null);
    final isLoading = useState(false);

    final picker = useMemoized(() => ImagePicker());

    Future<void> pickImage(ValueNotifier<File?> imageState) async {
      try {
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1024,
        );
        if (pickedFile != null) {
          imageState.value = File(pickedFile.path);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('画像の選択に失敗しました: $e')),
          );
        }
      }
    }

    Future<void> createRoom() async {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ルーム名を入力してください')),
        );
        return;
      }

      isLoading.value = true;
      FocusManager.instance.primaryFocus?.unfocus();

      try {
        final notifier = ref.read(openChatActionProvider.notifier);
        
        String? iconUrl;
        String? backgroundUrl;

        if (iconImage.value != null) {
          iconUrl = await notifier.uploadImage(iconImage.value!.path, 'icons');
        }
        
        if (backgroundImage.value != null) {
          backgroundUrl = await notifier.uploadImage(backgroundImage.value!.path, 'backgrounds');
        }

        final password = passwordController.text.trim().isEmpty ? null : passwordController.text.trim();

        final error = await notifier.createRoom(
          name,
          descController.text.trim(),
          iconUrl,
          backgroundUrl: backgroundUrl,
          password: password,
        );

        if (context.mounted) {
          if (error == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('オープンチャットを作成しました')),
            );
            context.pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('予期せぬエラーが発生しました: $e')),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('オープンチャット作成', style: AppTextStyles.bold(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 背景画像とアイコン画像のヘッダーエリア
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 背景画像
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 160,
                      child: GestureDetector(
                        onTap: () => pickImage(backgroundImage),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            image: backgroundImage.value != null
                                ? DecorationImage(
                                    image: FileImage(backgroundImage.value!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: backgroundImage.value == null
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('背景画像を追加', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : const Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.edit, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // アイコン画像
                    Positioned(
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => pickImage(iconImage),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: iconImage.value != null
                                ? Image.file(
                                    iconImage.value!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(Icons.camera_alt, color: Colors.grey),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'ルーム名 (必須)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: '説明文 (任意)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: '合言葉 (任意)',
                        helperText: '合言葉を設定するとプライベートルームになります',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading.value ? null : createRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: isLoading.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text('オープンチャットを作成', style: AppTextStyles.bold(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
