import 'dart:io';
import 'package:debate_project/provider/open_chat_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class OpenChatCreateRoomPage extends HookConsumerWidget {
  const OpenChatCreateRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final descController = useTextEditingController();
    final passwordController = useTextEditingController();
    final customTagController = useTextEditingController();

    final iconImage = useState<File?>(null);
    final backgroundImage = useState<File?>(null);
    final isPrivate = useState(false);
    final isLoading = useState(false);

    // デフォルトのハッシュタグ候補一覧
    final defaultTags = useMemoized(() => [
      'ディベート',
      '初心者歓迎',
      '雑談',
      '時事問題',
      '質問・相談',
      '勉強・作業',
      '哲学・思想',
      '趣味',
      'ゲーム',
      'アニメ・漫画',
      '働き方・仕事',
      '情報交換',
    ]);

    // 全タグ候補（ユーザー追加分を含む）
    final allTags = useState<List<String>>([...defaultTags]);
    // 選択中のタグ（初期状態は未選択）
    final selectedTags = useState<Set<String>>({});

    final picker = useMemoized(() => ImagePicker());
    final cropper = useMemoized(() => ImageCropper());

    // 画像選択 ＆ クロップ（アイコン: 1:1円形 / 背景: 9:16縦長）
    Future<void> pickAndCropImage({
      required ValueNotifier<File?> imageState,
      required bool isIcon,
    }) async {
      try {
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (pickedFile == null) return;

        final croppedFile = await cropper.cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: isIcon
              ? const CropAspectRatio(ratioX: 1, ratioY: 1)
              : const CropAspectRatio(ratioX: 9, ratioY: 16),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: isIcon ? 'アイコンを切り抜く' : '背景画像を切り抜く (9:16)',
              toolbarColor: const Color(0xFF007AFF),
              toolbarWidgetColor: Colors.white,
              cropStyle: isIcon ? CropStyle.circle : CropStyle.rectangle,
              initAspectRatio: isIcon
                  ? CropAspectRatioPreset.square
                  : CropAspectRatioPreset.original,
              lockAspectRatio: true,
              statusBarColor: const Color(0xFF007AFF),
            ),
            IOSUiSettings(
              title: isIcon ? 'アイコンを切り抜く' : '背景画像を切り抜く (9:16)',
              aspectRatioLockEnabled: true,
              aspectRatioPickerButtonHidden: true,
              resetAspectRatioEnabled: false,
              cropStyle: isIcon ? CropStyle.circle : CropStyle.rectangle,
              doneButtonTitle: '完了',
              cancelButtonTitle: 'キャンセル',
            ),
          ],
        );

        if (croppedFile != null) {
          imageState.value = File(croppedFile.path);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('画像の処理に失敗しました: $e')),
          );
        }
      }
    }

    // タグの選択切り替え
    void toggleTag(String tag) {
      final updated = Set<String>.from(selectedTags.value);
      if (updated.contains(tag)) {
        updated.remove(tag);
      } else {
        updated.add(tag);
      }
      selectedTags.value = updated;
    }

    // オリジナルタグの追加
    void addCustomTag() {
      var text = customTagController.text.trim();
      if (text.isEmpty) return;
      if (text.startsWith('#')) {
        text = text.substring(1).trim();
      }
      if (text.isEmpty) return;

      if (!allTags.value.contains(text)) {
        allTags.value = [...allTags.value, text];
      }
      final updated = Set<String>.from(selectedTags.value)..add(text);
      selectedTags.value = updated;
      customTagController.clear();
    }

    // ルーム作成処理
    Future<void> createRoom() async {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('オープンチャット名を入力してください')),
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

        final password = (isPrivate.value && passwordController.text.trim().isNotEmpty)
            ? passwordController.text.trim()
            : null;

        // 選択されたタグ ＋ 説明文内に手打ちされたタグを統合
        final descTags = extractTagsFromDescription(descController.text);
        final finalTags = {...selectedTags.value, ...descTags}.toList();

        final error = await notifier.createRoom(
          name,
          descController.text.trim(),
          iconUrl,
          backgroundUrl: backgroundUrl,
          password: password,
          tags: finalTags,
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
        backgroundColor: const Color(0xFF007AFF),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'オープンチャットを作成',
          style: AppTextStyles.bold(color: Colors.white, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: isLoading.value ? null : createRoom,
              child: isLoading.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      '作成',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 背景画像バナー ＆ アイコン設定
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // 背景画像（上部にテキストをオーバーレイ表示）
                    GestureDetector(
                      onTap: () => pickAndCropImage(imageState: backgroundImage, isIcon: false),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          image: backgroundImage.value != null
                              ? DecorationImage(
                                  image: FileImage(backgroundImage.value!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 背景画像の上側にオーバーレイ表示する注記テキスト
                              const Text(
                                'この画像はオープンチャットのプロフィールおよびトークルームの背景に適用されます。',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1.3,
                                  shadows: [
                                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                              ),

                              // 右下のカメラ変更ボタン
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    color: Color(0xFF1C1C1E),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // アイコン画像（バナー中央下部に配置）
                    Positioned(
                      bottom: -28,
                      child: GestureDetector(
                        onTap: () => pickAndCropImage(imageState: iconImage, isIcon: true),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
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
                                        color: const Color(0xFFE5E5EA),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Color(0xFF8E8E93),
                                          size: 36,
                                        ),
                                      ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 38),

              // 2. オープンチャット名を入力（もとの枠スタイル）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'オープンチャット名を入力',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '*',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF3B30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      maxLength: 50,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
                      decoration: InputDecoration(
                        hintText: 'オープンチャット名を入力',
                        hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: nameController,
                        builder: (context, value, _) {
                          return Text(
                            '${value.text.length}/50',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. 説明（もとの枠スタイル）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '説明',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      maxLength: 1000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E), height: 1.4),
                      decoration: InputDecoration(
                        hintText: '説明を入力\n\n「#」から始まるハッシュタグを入力',
                        hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13, height: 1.4),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: descController,
                        builder: (context, value, _) {
                          return Text(
                            '${value.text.length}/1000',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 4. ハッシュタグ（カテゴリー風チップ一覧 ＋ もとの枠の追加入力欄）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ハッシュタグ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ハッシュタグを設定すると、ユーザーが検索した時にこのオープンチャットが見つかりやすくなります。',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93), height: 1.4),
                    ),
                    const SizedBox(height: 12),

                    // タグチップ一覧（角丸レクタングル、選択中は青色背景）
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allTags.value.map((tag) {
                        final isSelected = selectedTags.value.contains(tag);
                        return GestureDetector(
                          onTap: () => toggleTag(tag),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF007AFF) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x33007AFF),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF333333),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // オリジナルタグ追加入力欄（枠付き ＋ 背景なしテキストボタン「追加」）
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '#',
                            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: customTagController,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E)),
                              onSubmitted: (_) => addCustomTag(),
                              decoration: const InputDecoration(
                                hintText: 'オリジナルのハッシュタグを追加',
                                hintStyle: TextStyle(color: Color(0xFFC7C7CC), fontSize: 12),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: addCustomTag,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: Text(
                                '追加',
                                style: TextStyle(
                                  color: Color(0xFF007AFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. 合言葉（パスワード）設定
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '合言葉で参加制限',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '合言葉を知っている人のみ参加できます',
                              style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                            ),
                          ],
                        ),
                        CupertinoSwitch(
                          value: isPrivate.value,
                          activeTrackColor: const Color(0xFF007AFF),
                          onChanged: (value) {
                            isPrivate.value = value;
                            if (!value) {
                              passwordController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    if (isPrivate.value) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)),
                        decoration: InputDecoration(
                          hintText: '参加用の合言葉を入力',
                          hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
