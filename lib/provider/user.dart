// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:io';

import 'package:debate_project/modes/transfer_model.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/provider/fcm_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:debate_project/view_model/start_error_dialog.dart';
import 'package:debate_project/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final userProvider = StateNotifierProvider<UserNotifier, Users>((ref) {
  return UserNotifier(ref);
});

class UserNotifier extends StateNotifier<Users> {
  UserNotifier(this._ref)
      : super(const Users(
            id: '', name: '', trophy: 0, win: 0, lose: 0, avatar_url: null));
  final Ref _ref;
  SupabaseClient get supabase => _ref.read(supabaseProvider);
  Future<void> signinandname() async {
    print('signinandname: 処理開始');
    final user = _ref.read(currentUserIdProvider);
    try {
      if (user != null) {
        print('signinandname: ユーザーID検出 ($user). fetchUserを開始します');
        await fetchUser(user);
        print('signinandname: fetchUser完了. ステータス: ${state.status}, 名前: ${state.name}');
        
        // --- FCMトークンをデータベースに保存する（MVVM的呼び出し） ---
        _ref.read(fcmServiceProvider).saveTokenToDatabase(user);
        // -----------------------------------------------------------------

        if (state.status == true) {
          final bool nameIsNullOrWhitespace;

          if (state.name == 'null') {
            nameIsNullOrWhitespace = true;
          } else {
            // nullでなければトリムして空文字列かチェック
            nameIsNullOrWhitespace = state.name!.trim().isEmpty;
          }

          if (nameIsNullOrWhitespace) {
            print('signinandname: 名前が空または文字列表記の"null"のため /name へ遷移します');
            FlutterNativeSplash.remove();
            router.go('/name');
            return;
          } else {
            print('signinandname: 名前が設定済みのため /home へ遷移します');
            FlutterNativeSplash.remove();
            router.go('/home');
            return;
          }
        } else {
          print('signinandname: state.status が true ではないため遷移をスキップしました (status: ${state.status})');
        }
      } else {
        print('signinandname: ユーザーが存在しません (新規ログイン). signInAnonymouslyを実行します');
        await supabase.auth.signInAnonymously();
        print('signinandname: 匿名サインイン完了. /name へ遷移します');
        FlutterNativeSplash.remove();
        router.go('/name');
      }
    } catch (e) {
      print('signinandname でエラーが発生しました: $e');
      // ローカルDBがリセットされてユーザーが存在しない場合などのためのフォールバック
      print('セッションをクリアして再試行を促します...');
      await supabase.auth.signOut();
      rethrow;
    }
  }

  Future<Users> fetchUser(String id) async {
    try {
      print(id);
      final response =
          await supabase.from('users').select().eq('id', id).single();

      if (response.isNotEmpty) {
        print(response);
        state = Users.fromMap(response);
        if (state.status == false) {
          print('fetchUser: ユーザーステータスがfalseです。引き継ぎ待機ページに遷移します。');
          
            FlutterNativeSplash.remove();
          router.go('/waittransfer'); // '/waittransfer' はWaittransferPageへのパス
          return state; // 遷移後はこの関数の処理を終了
        } else {
          // ユーザーステータスがtrueまたはnull (アクティブとみなす)
          print('fetchUser: ユーザーステータスがtrueまたはnullです。');
          final prefs = await SharedPreferences.getInstance();
          final storedTransferId = prefs.getString(SharedPrefKeys.transferId);
          final storedTransferPassword =
              prefs.getString(SharedPrefKeys.transferPassword);

          if (storedTransferId != null || storedTransferPassword != null) {
            print('fetchUser: SharedPreferencesに古い引き継ぎ情報が存在するため削除します。');
            await prefs.remove(SharedPrefKeys.transferId);
            await prefs.remove(SharedPrefKeys.transferPassword);
            print('fetchUser: 古い引き継ぎ情報を削除しました。');
          }

          return state;
        }
      }
      throw Exception('User not found');
    } catch (e) {
      print('エラー: $e');
      rethrow;
    }
  }

  final picker = ImagePicker();
  final uuid = const Uuid();

  Future<void> updateAvatar() async {
    final currentUser = state;
    // 現在のユーザーIDがない場合は処理しない
    if (currentUser.id.isEmpty) {
      print('ユーザーIDがありません。アバターを更新できません。');
      return;
    }

    final String? oldAvatarUrl = currentUser.avatar_url;

    try {
      // 1. ギャラリーから画像を選択
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        // imageQualityやmaxWidth/maxHeightはCropper/Compressで制御するため、ここでは不要な場合が多い
        // imageQuality: 90,
        // maxWidth: 1000,
        // maxHeight: 1000,
      );

      if (pickedFile == null) {
        print('画像選択がキャンセルされました。');
        return;
      }

      // 2. 画像をクロップ (円形)
      final cropper = ImageCropper(); // または ImageCropper() を使用
      final CroppedFile? croppedFile = await cropper.cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          // プラットフォームごとのUI設定
          AndroidUiSettings(
            toolbarTitle: '画像を切り抜く',
            toolbarColor: Colors.deepOrange, // 例: アプリのテーマカラー
            toolbarWidgetColor: Colors.white,
            cropStyle: CropStyle.circle,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            statusBarColor: Colors.deepOrange,
          ),
          IOSUiSettings(
            title: '画像を切り抜く',
            aspectRatioLockEnabled: true, // アスペクト比を固定
            aspectRatioPickerButtonHidden: true, // アスペクト比選択ボタンを隠す
            resetAspectRatioEnabled: false, // リセットボタンを無効化
            cropStyle: CropStyle.circle,
            doneButtonTitle: '完了',
            cancelButtonTitle: 'キャンセル',
          ),
          // Web用の設定も必要であれば追加: WebUiSettings(...)
        ],
      );

      if (croppedFile == null) {
        print('画像クロップがキャンセルされました。');
        return;
      }

      // 3. クロップした画像を圧縮
      final File imageFile = File(croppedFile.path); // CroppedFileをFileに変換
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 500, // 圧縮後の最小幅 (アスペクト比は維持される)
        minHeight: 500, // 圧縮後の最小高さ
        quality: 85, // 圧縮品質 (0-100, 高いほど高品質・高サイズ)
        // format: CompressFormat.jpeg, // 必要ならフォーマットを指定 (デフォルトは元画像依存 or JPEG)
      );

      if (compressedBytes == null || compressedBytes.isEmpty) {
        print('画像圧縮に失敗しました。');
        throw Exception('画像の圧縮に失敗しました。');
      }

      // 4. Supabase Storageにアップロード
      // ファイル拡張子を取得 (圧縮後のフォーマットに合わせるか、元画像に合わせるか検討)
      // ここでは元画像の拡張子を使用する例 (圧縮でJPEGに統一する場合は 'jpg' 固定でも良い)
      final fileExtension = pickedFile.path.split('.').last.toLowerCase();
      // または final fileExtension = p.extension(pickedFile.path).substring(1).toLowerCase(); (pathパッケージ使用時)
      // 圧縮でJPEGに統一した場合: final fileExtension = 'jpg';

      final path = 'avatars/${currentUser.id}/${uuid.v4()}.$fileExtension';

      // Stateのローディング表示はUI側で行うことを推奨

      await supabase.storage.from('avatars').uploadBinary(
            path, // ストレージ内のパス
            compressedBytes, // 圧縮後のバイトデータを使用
            fileOptions: const FileOptions(
              // contentType: 'image/jpeg', // 圧縮でJPEGに統一した場合など、MIMEタイプを指定可能
              upsert: false, // 同じパスが存在する場合、上書きしない (ユニークなパスなので通常不要)
            ),
          );

      // 5. 公開URLを取得
      final publicUrlResponse =
          supabase.storage.from('avatars').getPublicUrl(path);

      // getPublicUrlは文字列を直接返す (v2以降)
      final imageUrl = publicUrlResponse;

      if (imageUrl.isEmpty) {
        throw Exception('Failed to get public URL');
      }

      // 6. ユーザーテーブルを更新
      await supabase
          .from('users')
          .update({'avatar_url': imageUrl}).eq('id', currentUser.id);

      if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
        try {
          // URLからStorageのパスを抽出する (より堅牢な実装が必要な場合あり)
          // 例: https://<project-ref>.supabase.co/storage/v1/object/public/avatars/<user-id>/<filename.ext>
          final Uri? oldUri = Uri.tryParse(oldAvatarUrl);
          // URLの構造が期待通りか基本的なチェック
          if (oldUri != null && oldUri.pathSegments.length > 4) {
            // ['storage', 'v1', 'object', 'public', 'avatars', 'user-id', 'filename.ext']
            final bucketNameIndex = oldUri.pathSegments.indexOf('avatars');
            if (bucketNameIndex != -1 &&
                bucketNameIndex < oldUri.pathSegments.length - 1) {
              // 'avatars/' より後の部分をパスとして結合
              final oldPath =
                  oldUri.pathSegments.sublist(bucketNameIndex + 1).join('/');

              if (oldPath.isNotEmpty) {
                print('古いアバターを削除します: $oldPath');
                // Storageから古いファイルを削除 (removeはリストを受け取る)
                await supabase.storage
                    .from('avatars')
                    .remove([oldPath]); // パスをリストで渡す
                print('古いアバターを削除しました。');
              } else {
                print('古いアバターURLから有効なパスを抽出できませんでした: $oldAvatarUrl');
              }
            } else {
              print(
                  '古いアバターURLの形式が予期したものと異なります (avatarsセグメントが見つからないか、パスがありません): $oldAvatarUrl');
            }
          } else {
            print('古いアバターURLを解析できませんでした: $oldAvatarUrl');
          }
        } catch (e) {
          // 古いファイルの削除失敗はログに残すが、エラーとはしない
          print('古いアバターの削除に失敗しました: $e');
          // ここでエラーを再スローしない
        }
      }

      // 7. Stateを更新 (再フェッチ)
      await fetchUser(currentUser.id); // 更新後のデータでStateを更新

      // 必要であれば、成功メッセージ表示などのUIフィードバック
    } on PostgrestException catch (e) {
      print('Supabaseエラー (Postgrest): ${e.message}');
      // エラーハンドリング (例: UIにエラーメッセージ表示)
      // state = AsyncValue.error(e, StackTrace.current); // AsyncValueの場合
    } on PlatformException catch (e) {
      // image_cropper や flutter_image_compress が出す可能性のあるエラー
      print('プラットフォームエラー (Crop/Compress): ${e.message}');
      // エラーハンドリング
    } catch (e, st) {
      print('アバター更新中の予期せぬエラー: $e\n$st');
      // エラーハンドリング
      // state = AsyncValue.error(e, st); // AsyncValueの場合
    } finally {
      // ローディング解除処理 (UI側で行うか、AsyncValueならここで state = AsyncValue.data(state) など)
    }
  }

  Future<void> updateName(Users user, String name) async {
    // user パラメータはここでは直接使用されていないようですが、
    // 他の箇所で使用するために残している場合はそのままにしてください。
    // この関数内で不要であれば削除しても構いません。

    final myuser = _ref.read(currentUserIdProvider);

    // ユーザーがログインしているか確認 (currentUser?.id が null の場合は処理しない)
    if (myuser == null) {
      print('エラー: ユーザーがログインしていません。');
      // 必要に応じて、ログインページへのリダイレクトやユーザーへのエラーメッセージ表示
      // 例: ScaffoldMessenger.of(context).showSnackBar(...); // BuildContext が必要
      // 例: router.go('/login');
      return; // 処理を終了
    }

    // 入力された name をトリム（前後の空白削除）し、空文字列であれば 'NoName' を使用する
    // 空白文字のみの場合も trim() すると空文字列になるため、このチェックで対応できる
    final String nameToUpdate =
        name.trim().isEmpty ? 'NoName' : name.trim(); // 更新する値はトリムされたものを使用

    try {
      // 1. データベースの更新を実行
      // update 呼び出しが成功した場合（エラーが発生しなかった場合）は、
      // 更新が正常に行われたとみなします。
      await supabase
          .from('users')
          .update({'name': nameToUpdate}).eq('id', myuser);

      print('ユーザー名の更新に成功しました'); // 成功ログ（オプション）

      // 2. データベース更新が成功したら、ユーザー情報を再取得
      // fetchUser は上記で修正した通り、エラー時に例外を投げます
      await fetchUser(myuser);

      print('ユーザー情報の再取得に成功しました'); // 成功ログ（オプション）

      router.go('/home');
    } catch (e) {
      print('処理中にエラーが発生しました: $e');
    }
  }

  Future<void> saveTransferCredentials(String id, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefKeys.transferId, id);
    await prefs.setString(SharedPrefKeys.transferPassword, password);
    print('Transfer credentials saved to SharedPreferences.');
  }

  Future<void> clearTransferCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefKeys.transferId);
    await prefs.remove(SharedPrefKeys.transferPassword);
    print('Transfer credentials cleared from SharedPreferences.');
  }

  Future<Map<String, String>?> initiateTransfer(String senderId) async {
    try {
      final List<dynamic> result = await supabase.rpc(
        'initiate_data_transfer',
        params: {'p_sender_id': senderId},
      );
      if (result.isNotEmpty && result.first is Map) {
        final data = result.first as Map<String, dynamic>;
        //  [ { transfer_id: 'xxxxxx', transfer_password: 'yyyyyy' } ] のような形式で返ってくる
        return {
          'transfer_id': data['transfer_id'] as String,
          'transfer_password': data['transfer_password'] as String,
        };
      }
      return null;
    } catch (e) {
      print('Error initiating transfer: $e');
      // エラー内容をユーザーに表示するなどの処理
      // 例: (e as PostgrestException).message
      rethrow; // 必要に応じて再スロー
    }
  }

  Future<String?> completeTransfer({
    required String transferId,
    required String password,
    required String receiverId,
  }) async {
    try {
      final String result = await supabase.rpc(
        'complete_data_transfer_v2',
        params: {
          'p_transfer_id': transferId,
          'p_password': password,
          'p_receiver_id': receiverId,
        },
      );
      return result; // "Data transfer completed successfully."
    } catch (e) {
      print('Error completing transfer: $e');
      // エラーメッセージを解析してユーザーに表示
      // if (e is PostgrestException) { return e.message; }
      rethrow;
    }
  }

  Future<String?> cancelTransfer(String senderId) async {
    try {
      // cancel_data_transfer または cancel_data_transfer_robust を選択
      final String result = await supabase.rpc(
        'cancel_data_transfer_robust', // もしくは 'cancel_data_transfer'
        params: {'p_sender_id': senderId},
      );
      return result; // "Data transfer canceled successfully." など
    } catch (e) {
      print('Error canceling transfer: $e');
      rethrow;
    }
  }

  // --- テスト用: トロフィーを即座に変更する ---
  void incrementTrophyDebug(int amount) {
    state = state.copyWith(trophy: state.trophy + amount);
  }

  // 通知のオン・オフを更新する
  Future<void> updateNotificationStatus(BuildContext? context, bool isEnabled,
      {bool isSilent = false}) async {
    final userId = state.id;
    if (userId.isEmpty) return;

    // 現在の状態を保存（エラー時のロールバック用）
    final previousState = state;

    // 1. 先にローカルの状態（UI）を更新する（楽観的更新）
    state = state.copyWith(is_notification_enabled: isEnabled);

    if (isEnabled && !isSilent) {
      // 権限をリクエストする
      final settings =
          await _ref.read(fcmServiceProvider).requestNotificationPermission();

      // もし許可されなかった場合は、状態を元に戻して案内を出す
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        print('通知権限が許可されませんでした。ステータス: ${settings.authorizationStatus}');

        // 状態を元に戻す
        state = previousState;

        if (context != null && context.mounted) {
          _ref.read(startProvider.notifier).showPermissionDeniedDialog(context);
        }
        return;
      }
    }

    try {
      // 2. データベースをバックグラウンドで更新
      await supabase
          .from('users')
          .update({'is_notification_enabled': isEnabled}).eq('id', userId);

      // 有効にした場合は、ついでにFCMトークンを再保存して確実にする
      if (isEnabled) {
        await _ref.read(fcmServiceProvider).saveTokenToDatabase(userId);
      }
      print('通知設定の更新に成功しました: $isEnabled');
    } catch (e) {
      print('通知設定の更新に失敗しました。元の状態に戻します: $e');
      // 失敗した場合は元の状態にロールバック
      state = previousState;
      rethrow;
    }
  }

  /// OSの設定状態を確認し、もし許可されているのにアプリ内がオフなら同期する（設定画面から戻った時などに使用）
  Future<void> syncNotificationStatusWithSystem() async {
    final userId = state.id;
    if (userId.isEmpty) return;

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    // OS側が許可されているのに、DB側がオフになっている場合のみ同期（オンにする）
    if (isAuthorized && (state.is_notification_enabled == false)) {
      print('OS側の通知許可を検知したため、アプリ内の設定もオンに同期します');
      await updateNotificationStatus(null, true, isSilent: true);
    }
  }
}
