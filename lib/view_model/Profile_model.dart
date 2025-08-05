import 'package:debate_project/modes/users.dart';
import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';

class UserProfileCard extends StatelessWidget {
  final Users userData; // 型を Users に変更
  final CrossAxisAlignment? textAlignment;

  const UserProfileCard({
    Key? key,
    required this.userData,
    this.textAlignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: textAlignment ?? CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[300],
          child:
              (userData.avatar_url != null && userData.avatar_url!.isNotEmpty)
                  ? ClipOval(
                      child: FadeInImage.memoryNetwork(
                        placeholder: kTransparentImage, // 透明なプレースホルダーを使用
                        image: userData.avatar_url!, // プロパティ名を avatar_url に修正
                        fit: BoxFit.cover,
                        width: 100, // radius * 2
                        height: 100, // radius * 2
                        imageErrorBuilder: (context, error, stackTrace) {
                          // 画像の読み込みエラー時はアイコンを表示
                          return const Center(
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    )
                  : const Center(
                      // userData.avatar_urlがnullまたは空の場合もアイコンを表示
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
        ),
        const SizedBox(height: 12),
        Text(
          // userData.nameがnullの場合、空文字を表示 (または適切なフォールバックテキスト)
          // Users.fromMap で name: map['name'].toString() となっているので、
          // map['name']がnullだと "null" という文字列になる可能性があります。
          // もしそうなっていて、"null" と表示したくない場合は、
          // (userData.name == "null" ? "ゲスト" : userData.name ?? '不明なユーザー') のような処理も検討できます。
          // ここでは、UsersクラスのnameがString?で、適切にnullが渡される前提で userData.name ?? '' とします。
          userData.name ?? 'プレイヤー', // nameがnullの場合のフォールバック
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: textAlignment == CrossAxisAlignment.start
              ? TextAlign.left
              : textAlignment == CrossAxisAlignment.end
                  ? TextAlign.right
                  : TextAlign.center,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/trofie.png', // ← あなたの画像のパスに置き換えてください
              width: 24, // アイコンのサイズ（widthとheightで指定）
              height: 24,
              // もし画像がモノクロで、Iconsのcolorのように色を付けたい場合は、以下を追加します
              // color: Colors.amber[600],
              // colorBlendMode: BlendMode.srcIn, // 画像の透過部分に色を適用する場合など
            ),
            const SizedBox(width: 6),
            Text(
              userData.trophy.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
//トロフィーの数字がないバージョン
class UserProfileCard2 extends StatelessWidget {
  final Users userData; // 型を Users に変更
  final CrossAxisAlignment? textAlignment;

  const UserProfileCard2({
    Key? key,
    required this.userData,
    this.textAlignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: textAlignment ?? CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[300],
          child:
              (userData.avatar_url != null && userData.avatar_url!.isNotEmpty)
                  ? ClipOval(
                      child: FadeInImage.memoryNetwork(
                        placeholder: kTransparentImage, // 透明なプレースホルダーを使用
                        image: userData.avatar_url!, // プロパティ名を avatar_url に修正
                        fit: BoxFit.cover,
                        width: 100, // radius * 2
                        height: 100, // radius * 2
                        imageErrorBuilder: (context, error, stackTrace) {
                          // 画像の読み込みエラー時はアイコンを表示
                          return const Center(
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    )
                  : const Center(
                      // userData.avatar_urlがnullまたは空の場合もアイコンを表示
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
        ),
        const SizedBox(height: 12),
        Text(
          // userData.nameがnullの場合、空文字を表示 (または適切なフォールバックテキスト)
          // Users.fromMap で name: map['name'].toString() となっているので、
          // map['name']がnullだと "null" という文字列になる可能性があります。
          // もしそうなっていて、"null" と表示したくない場合は、
          // (userData.name == "null" ? "ゲスト" : userData.name ?? '不明なユーザー') のような処理も検討できます。
          // ここでは、UsersクラスのnameがString?で、適切にnullが渡される前提で userData.name ?? '' とします。
          userData.name ?? 'プレイヤー', // nameがnullの場合のフォールバック
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: textAlignment == CrossAxisAlignment.start
              ? TextAlign.left
              : textAlignment == CrossAxisAlignment.end
                  ? TextAlign.right
                  : TextAlign.center,
        ),
       
      ],
    );
  }
}