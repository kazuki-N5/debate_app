import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:debate_project/provider/supabase_provider.dart';

final imageUploadProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService(ref);
});

class ImageUploadService {
  final Ref _ref;
  final ImagePicker _picker = ImagePicker();

  ImageUploadService(this._ref);

  Future<File?> pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      print('pickImage error: $e');
    }
    return null;
  }

  Future<List<File>> pickMultiImage({int maxImages = 4}) async {
    try {
      final pickedFiles = await _picker.pickMultiImage(imageQuality: 70);
      if (pickedFiles.isNotEmpty) {
        return pickedFiles.take(maxImages).map((xFile) => File(xFile.path)).toList();
      }
    } catch (e) {
      print('pickMultiImage error: $e');
    }
    return [];
  }

  Future<String?> uploadImage({
    required File file,
    required String bucketName,
    required String folderName,
  }) async {
    final supabase = _ref.read(supabaseProvider);
    try {
      final fileExtension = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final path = '$folderName/$fileName';

      await supabase.storage.from(bucketName).upload(path, file);
      final publicUrl = supabase.storage.from(bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('uploadImage error: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultiImages({
    required List<File> files,
    required String bucketName,
    required String folderName,
  }) async {
    List<String> uploadedUrls = [];
    for (var file in files) {
      final url = await uploadImage(file: file, bucketName: bucketName, folderName: folderName);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    return uploadedUrls;
  }
}
