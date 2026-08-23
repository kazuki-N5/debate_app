import 'dart:io';
import 'package:debate_project/modes/bbs_comment.dart';
import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/modes/users.dart';
import 'package:debate_project/provider/bbs_comment_provider.dart';
import 'package:debate_project/provider/bbs_timeline_provider.dart';
import 'package:debate_project/provider/image_upload_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/views/bbs/BbsTimelineView.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/moderation.dart';
import 'package:debate_project/widgets/resba_attach_sheet.dart';
import 'package:debate_project/widgets/resba_card.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:debate_project/views/UserProfilePage.dart';
import 'package:debate_project/utils/mention_text_editing_controller.dart';
import 'package:debate_project/widgets/mention_text.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BbsPostDetailView extends HookConsumerWidget {
  final BbsPost post;

  const BbsPostDetailView({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fetchedPost = useState<BbsPost?>(null);
    final isDeleted = useState(false);
    final postsAsync = ref.watch(bbsTimelineProvider);
    final BbsPost currentPost = fetchedPost.value ??
        postsAsync.maybeWhen<BbsPost>(
          data: (posts) =>
              posts.firstWhere((p) => p.id == post.id, orElse: () => post),
          orElse: () => post,
        );
    final commentsAsync = ref.watch(bbsCommentProvider(post.id));

    // 画面表示時に最新の投稿データ、コメント、レスバを自動再取得
    useEffect(() {
      Future<void> loadLatest() async {
        try {
          final supabase = ref.read(supabaseProvider);
          final currentUserId = ref.read(currentUserIdProvider);

          final response = await supabase
              .from('bbs_posts')
              .select('*, users!bbs_posts_user_id_fkey(*)')
              .eq('id', post.id)
              .maybeSingle();

          if (response != null) {
            bool isLiked = false;
            if (currentUserId != null) {
              final likeRes = await supabase
                  .from('bbs_likes')
                  .select('id')
                  .eq('post_id', post.id)
                  .eq('user_id', currentUserId)
                  .maybeSingle();
              isLiked = likeRes != null;
            }
            final userMap = response['users'] as Map<String, dynamic>?;
            final postUser = userMap != null ? Users.fromMap(userMap) : null;
            final latest =
                BbsPost.fromMap(response, user: postUser, isLikedByMe: isLiked)
                    .copyWith(hasResba: currentPost.hasResba);
            fetchedPost.value = latest;
            debugPrint('[RESBA_LOG] BbsPostDetailView.loadLatest loaded post: ${latest.id}, hasResba: ${latest.hasResba}');
          } else {
            // 投稿が削除されている場合
            isDeleted.value = true;
          }
        } catch (e) {
          debugPrint('[RESBA_LOG] BbsPostDetailView loadLatest error: $e');
        }

        // コメントとレスバも最新化
        ref.read(bbsCommentProvider(post.id).notifier).fetchComments();
        try {
          await ref.read(postResbaProvider(post.id).notifier).fetch();
        } catch (e) {
          debugPrint('[RESBA_LOG] BbsPostDetailView postResbaProvider.fetch error: $e');
        }
      }

      loadLatest();
      return null;
    }, [post.id]);
    
    final commentController = useMemoized(() => MentionTextEditingController());
    useEffect(() {
      return () => commentController.dispose();
    }, const []);
    
    final focusNode = useFocusNode();
    
    // 返信先のコメントIDを保持するステート
    final replyingToCommentId = useState<String?>(null);
    final replyingToUserName = useState<String?>(null);
    
    // 画像選択用のステート
    final selectedImage = useState<File?>(null);
    final isUploading = useState(false);

    // レスバ添付用のステート（写真を添付する感覚）
    final resbaAttachment = useState<ResbaAttachment?>(null);

    // このポスト（+コメント）に付いたレスバ
    final resbasAsync = ref.watch(postResbaProvider(post.id));
    final resbas = resbasAsync.valueOrNull ?? const <ResbaInvite>[];

    debugPrint('[RESBA_LOG] BbsPostDetailView build: postId=${post.id}, currentPost.hasResba=${currentPost.hasResba}, resbasAsync.status=${resbasAsync.isLoading ? "loading" : resbasAsync.hasError ? "error" : "data"}, resbasCount=${resbas.length}');

    void refreshResba() {
      debugPrint('[RESBA_LOG] refreshResba called for postId: ${post.id}');
      ref.read(postResbaProvider(post.id).notifier).fetch();
    }

    if (isDeleted.value) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('投稿', style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
          backgroundColor: Colors.blue,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 54, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'この投稿は削除されました',
                style: AppTextStyles.bold(color: Colors.black87, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '投稿者によって削除されたか、存在しません。',
                style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('投稿', style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(bbsTimelineProvider.notifier).fetchPosts();
                await ref.read(bbsCommentProvider(post.id).notifier).fetchComments();
                // ポストに付いたレスバ（⚔️）も再読み込みする
                try {
                  await ref.read(postResbaProvider(post.id).notifier).fetch();
                } catch (_) {
                  // 取得失敗時は表示を更新せずに継続（リフレッシュを妨げない）
                }
              },
              child: ListView(
                children: [
                  // 親の投稿
                  BbsPostWidget(post: currentPost),
                  // ポストに付いたレスバ
                  _PostResbaSection(
                    post: currentPost,
                    resbas: resbas.where((r) => r.attachType == 'post' && r.attachId == currentPost.id).toList(),
                    onChanged: refreshResba,
                  ),
                  const Divider(height: 1),
                  // コメント欄のヘッダー
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('コメント', style: AppTextStyles.bold(fontSize: 16)),
                        Text('新着', style: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // コメント一覧
                  commentsAsync.when(
                    data: (comments) {
                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text('まだコメントがありません', style: AppTextStyles.notoSans(color: Colors.grey)),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildCommentThread(
                            context, 
                            ref, 
                            comments[index], 
                            replyingToCommentId, 
                            replyingToUserName,
                            resbas,
                            refreshResba,
                            (String commentId, String userName, bool useMention) {
                              replyingToCommentId.value = commentId;
                              replyingToUserName.value = userName;
                              if (useMention) {
                                final mention = '@$userName ';
                                commentController.text = mention;
                                commentController.selection = TextSelection.fromPosition(TextPosition(offset: commentController.text.length));
                              } else {
                                commentController.clear();
                              }
                              focusNode.requestFocus();
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, st) => Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(child: Text('エラー: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 入力フォーム
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyingToUserName.value != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                      child: Row(
                        children: [
                          Text('返信先: ${replyingToUserName.value}', style: AppTextStyles.notoSans(color: Colors.blueAccent, fontSize: 13)),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              replyingToCommentId.value = null;
                              replyingToUserName.value = null;
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(Icons.close, size: 16, color: Colors.grey),
                            ),
                          )
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.grey),
                        onPressed: isUploading.value ? null : () async {
                          final picker = ref.read(imageUploadProvider);
                          final image = await picker.pickImage();
                          if (image != null) {
                            selectedImage.value = image;
                          }
                        },
                      ),
                      // ⚔️ レスバを添付（写真を付けるのと同じ操作感）
                      IconButton(
                        icon: const Text('⚔️', style: TextStyle(fontSize: 20, color: Color(0xFF7856FF))),
                        onPressed: isUploading.value ? null : () async {
                          final attachment = await showResbaAttachSheet(
                            context,
                            presetTheme: commentController.text.trim(),
                          );
                          if (attachment != null) {
                            resbaAttachment.value = attachment;
                          }
                        },
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            focusNode: focusNode,
                            controller: commentController,
                            maxLength: 200,
                            textAlignVertical: TextAlignVertical.center,
                            style: AppTextStyles.notoSans(color: Colors.black, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'コメントする',
                              counterText: '',
                              hintStyle: AppTextStyles.notoSans(color: Colors.grey[400]),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.translate(
                        offset: const Offset(4, 0),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: commentController,
                          builder: (context, value, child) {
                            final remaining = 200 - value.text.length;
                            return Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                '$remaining',
                                style: AppTextStyles.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: remaining <= 0 ? Colors.red : Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        onPressed: isUploading.value ? null : () async {
                          final text = commentController.text;
                          if (text.trim().isEmpty && selectedImage.value == null && resbaAttachment.value == null) return;
                          
                          isUploading.value = true;
                          try {
                            String? uploadedUrl;
                            if (selectedImage.value != null) {
                              final uploader = ref.read(imageUploadProvider);
                              uploadedUrl = await uploader.uploadImage(
                                file: selectedImage.value!,
                                bucketName: 'bbs_images',
                                folderName: 'comments',
                              );
                            }

                            final commentId = await ref.read(bbsCommentProvider(post.id).notifier).addComment(text, parentCommentId: replyingToCommentId.value, imageUrl: uploadedUrl, allowEmpty: resbaAttachment.value != null);

                            // レスバ添付: 返信先の相手にレスバが届く
                            final attachment = resbaAttachment.value;
                            if (attachment != null && commentId != null) {
                              final result = await ref.read(resbaActionsProvider).attachToComment(
                                commentId: commentId,
                                theme: attachment.theme,
                                choice1: attachment.choice1,
                                choice2: attachment.choice2,
                              );
                              if (result.error != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
                              }
                            }

                            commentController.clear();
                            replyingToCommentId.value = null;
                            replyingToUserName.value = null;
                            selectedImage.value = null;
                            resbaAttachment.value = null;
                            if (attachment != null) {
                              ref.read(postResbaProvider(post.id).notifier).fetch();
                            }
                            if (!context.mounted) return;
                            focusNode.unfocus(); // キーボードを閉じる
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('送信失敗: $e')));
                          } finally {
                            isUploading.value = false;
                          }
                        },
                        icon: isUploading.value 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.blue, size: 24),
                      ),
                    ],
                  ),
                  if (selectedImage.value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 48.0, bottom: 8.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              selectedImage.value!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: -8,
                            top: -8,
                            child: GestureDetector(
                              onTap: () {
                                selectedImage.value = null;
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (resbaAttachment.value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 48.0, bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF8FF),
                          border: Border.all(color: const Color(0xFF7856FF)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Text('⚔️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'レスバ: ${resbaAttachment.value!.theme}',
                                style: AppTextStyles.bold(fontSize: 12.5, color: const Color(0xFF7856FF)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                resbaAttachment.value = null;
                              },
                              child: const Icon(Icons.close, size: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCommentThread(
    BuildContext context, 
    WidgetRef ref, 
    BbsComment comment, 
    ValueNotifier<String?> replyingToCommentId, 
    ValueNotifier<String?> replyingToUserName,
    List<ResbaInvite> resbas,
    VoidCallback onResbaChanged,
    Function(String, String, bool) onReplyTap,
  ) {
    return _CommentThreadWidget(
      post: post,
      comment: comment,
      replyingToCommentId: replyingToCommentId,
      replyingToUserName: replyingToUserName,
      resbas: resbas,
      onResbaChanged: onResbaChanged,
      onReplyTap: onReplyTap,
    );
  }
}

/// ポストに付いたレスバ（投稿者のみ作成可・見た人は応じられる）
class _PostResbaSection extends HookConsumerWidget {
  final BbsPost post;
  final List<ResbaInvite> resbas;
  final VoidCallback onChanged;

  const _PostResbaSection({
    required this.post,
    required this.resbas,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.read(currentUserIdProvider);
    // pending（募集中） / accepted（対戦中） / finished（対戦終了・観戦ログ閲覧用）を表示
    final activeResbas = resbas
        .where((r) => r.isPending || r.isAccepted || r.status == 'finished')
        .toList();
    final hasPendingByMe = activeResbas.any((r) => r.isSender && r.isPending);

    debugPrint('[RESBA_LOG] _PostResbaSection build: postId=${post.id}, totalResbas=${resbas.length}, activeResbas=${activeResbas.length}, myId=$myId, postOwnerId=${post.userId}, hasPendingByMe=$hasPendingByMe');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final invite in activeResbas)
            ResbaCard(invite: invite, onChanged: onChanged),
          // 投稿者にのみ「レスバを付ける」ボタン
          if (myId == post.userId && !hasPendingByMe)
            InkWell(
              onTap: () async {
                final attachment = await showResbaAttachSheet(
                  context,
                  presetTheme: post.content.length > 60
                      ? post.content.substring(0, 60)
                      : post.content,
                );
                if (attachment == null || !context.mounted) return;
                final result = await ref
                    .read(resbaActionsProvider)
                    .createPostResba(
                      postId: post.id,
                      theme: attachment.theme,
                      choice1: attachment.choice1,
                      choice2: attachment.choice2,
                    );
                if (result.error != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(result.error!)));
                } else {
                  // タイムラインに戻ったときに「レスバ付き」バッジが付くようローカル反映
                  ref.read(bbsTimelineProvider.notifier).markPostHasResba(post.id);
                }
                onChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF7856FF).withValues(alpha: 0.08),
                  border: Border.all(color: const Color(0xFF7856FF).withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⚔️ このポストにレスバを付ける',
                  style: AppTextStyles.bold(fontSize: 13, color: const Color(0xFF7856FF)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentThreadWidget extends HookConsumerWidget {
  final BbsPost post;
  final BbsComment comment;
  final ValueNotifier<String?> replyingToCommentId;
  final ValueNotifier<String?> replyingToUserName;
  final List<ResbaInvite> resbas;
  final VoidCallback onResbaChanged;
  final Function(String, String, bool) onReplyTap;

  const _CommentThreadWidget({
    required this.post,
    required this.comment,
    required this.replyingToCommentId,
    required this.replyingToUserName,
    required this.resbas,
    required this.onResbaChanged,
    required this.onReplyTap,
  });

  /// コメントに付いたアクティブなレスバカード
  /// （対戦中・終了後の観戦ログ閲覧カードも含む）
  List<Widget> _resbaCardsFor(String attachId) {
    final matches = resbas
        .where((r) =>
            r.attachType == 'comment' &&
            r.attachId == attachId &&
            (r.isPending || r.isAccepted || r.status == 'finished'))
        .toList();
    if (matches.isNotEmpty) {
      debugPrint('[RESBA_UI_LOG] [CommentThread] Rendering ${matches.length} ResbaCards for comment: $attachId');
    }
    return matches
        .map((r) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ResbaCard(invite: r, onChanged: onResbaChanged),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = useState(false);
    final user = comment.user;
    final userName = user?.name ?? '名無し';
    final userAvatar = user?.avatar_url;
    final dateStr = DateFormatter.formatBbsDate(comment.createdAt);
    
    // 投稿主かどうか
    final isOwner = comment.userId == post.userId;
    if (comment.hasResba) {
      debugPrint('[RESBA_UI_LOG] [CommentThread] comment.hasResba is TRUE for comment: ${comment.id}, content: ${comment.content}');
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, _, __) => UserProfilePage(userId: comment.userId),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                      // 表示サイズ(radius18=36px)に縮小デコードしてカクつきを抑える
                      ? ResizeImage(NetworkImage(userAvatar), width: 108)
                      : null,
                  child: userAvatar == null || userAvatar.isEmpty ? Icon(Icons.person, color: Colors.grey[600]) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(userName, style: AppTextStyles.bold(fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        Text('・ $dateStr', style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey)),
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('投稿主', style: AppTextStyles.notoSans(fontSize: 10, color: Colors.deepOrange)),
                          ),
                        ],
                        const Spacer(),
                        // コメントメニュー(通報 / 非表示 / ブロック / 削除)
                        GestureDetector(
                          onTap: () {
                            final myId = ref.read(currentUserIdProvider);
                            final isOwnComment = comment.userId == myId;
                            showContentMenuSheet(
                              context: context,
                              ref: ref,
                              authorUserId: isOwnComment ? null : comment.userId,
                              authorName: userName,
                              contentType: 'bbs_comment',
                              contentId: comment.id,
                              contentSnapshot: comment.content,
                              isOwnContent: isOwnComment,
                              onHide: () => ref
                                  .read(bbsCommentProvider(post.id).notifier)
                                  .hideComment(comment.id),
                              onDelete: isOwnComment
                                  ? () async {
                                      final ok = await ref
                                          .read(bbsCommentProvider(post.id).notifier)
                                          .deleteComment(comment.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok ? 'コメントを削除しました' : '削除に失敗しました'),
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              onBlocked: () => ref
                                  .read(bbsCommentProvider(post.id).notifier)
                                  .fetchComments(),
                            );
                          },
                          child: const Icon(CupertinoIcons.ellipsis, color: Color(0xFF536471), size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (comment.content.isNotEmpty)
                      MentionText(text: comment.content, style: AppTextStyles.notoSans(fontSize: 14, color: Colors.black87)),
                    if (comment.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      _ReplyImageToggle(imageUrl: comment.imageUrl!),
                    ],
                    if (comment.hasResba) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ResbaBadge(text: 'レスバ付き'),
                      ),
                    ],
                    ..._resbaCardsFor(comment.id),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            ref.read(bbsCommentProvider(post.id).notifier).toggleLike(comment);
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, 1),
                                child: comment.isLikedByMe
                                    ? const Icon(CupertinoIcons.heart_fill, color: Colors.pink, size: 14)
                                    : SvgPicture.asset(
                                        'assets/images/icons/tweeticon/heart.svg',
                                        width: 14,
                                        height: 14,
                                        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                                      ),
                              ),
                              const SizedBox(width: 4),
                              Text('${comment.likesCount}', style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13, height: 1.1)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            onReplyTap(comment.id, userName, false);
                          },
                          child: Text('返信', style: AppTextStyles.bold(fontSize: 12, color: Colors.grey, height: 1.1)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 返信の表示トグルボタン
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, top: 8.0),
              child: InkWell(
                onTap: () {
                  isExpanded.value = !isExpanded.value;
                },
                child: Row(
                  children: [
                    Icon(
                      isExpanded.value ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.replies.length}件の返信を表示',
                      style: AppTextStyles.bold(fontSize: 13, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            ),
          // 返信の表示（リスト展開時のみ）
          if (comment.replies.isNotEmpty && isExpanded.value)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, top: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comment.replies.map((reply) {
                  final rUser = reply.user;
                  final rUserName = rUser?.name ?? '名無し';
                  final rUserAvatar = rUser?.avatar_url;
                  final rDateStr = DateFormatter.formatBbsDate(reply.createdAt);
                  final rIsOwner = reply.userId == post.userId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, _, __) => UserProfilePage(userId: reply.userId),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: rUserAvatar != null && rUserAvatar.isNotEmpty
                                // 表示サイズ(radius12=24px)に縮小デコードしてカクつきを抑える
                                ? ResizeImage(NetworkImage(rUserAvatar), width: 72)
                                : null,
                            child: rUserAvatar == null || rUserAvatar.isEmpty ? Icon(Icons.person, size: 14, color: Colors.grey[600]) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(rUserName, style: AppTextStyles.bold(fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('・ $rDateStr', style: AppTextStyles.notoSans(fontSize: 11, color: Colors.grey)),
                                  if (rIsOwner) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('投稿主', style: AppTextStyles.notoSans(fontSize: 9, color: Colors.deepOrange)),
                                    ),
                                  ],
                                  const Spacer(),
                                  // 返信メニュー(通報 / 非表示 / ブロック / 削除)
                                  GestureDetector(
                                    onTap: () {
                                      final myId = ref.read(currentUserIdProvider);
                                      final isOwnReply = reply.userId == myId;
                                      showContentMenuSheet(
                                        context: context,
                                        ref: ref,
                                        authorUserId: isOwnReply ? null : reply.userId,
                                        authorName: rUserName,
                                        contentType: 'bbs_comment',
                                        contentId: reply.id,
                                        contentSnapshot: reply.content,
                                        isOwnContent: isOwnReply,
                                        onHide: () => ref
                                            .read(bbsCommentProvider(post.id).notifier)
                                            .hideComment(reply.id),
                                        onDelete: isOwnReply
                                            ? () async {
                                                final ok = await ref
                                                    .read(bbsCommentProvider(post.id).notifier)
                                                    .deleteComment(reply.id);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(ok ? 'コメントを削除しました' : '削除に失敗しました'),
                                                    ),
                                                  );
                                                }
                                              }
                                            : null,
                                        onBlocked: () => ref
                                            .read(bbsCommentProvider(post.id).notifier)
                                            .fetchComments(),
                                      );
                                    },
                                    child: const Icon(CupertinoIcons.ellipsis, color: Color(0xFF536471), size: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (reply.content.isNotEmpty)
                                MentionText(text: reply.content, style: AppTextStyles.notoSans(fontSize: 13, color: Colors.black87)),
                              if (reply.imageUrl != null) ...[
                                const SizedBox(height: 8),
                                _ReplyImageToggle(imageUrl: reply.imageUrl!),
                              ],
                              if (reply.hasResba) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ResbaBadge(text: 'レスバ付き'),
                                ),
                              ],
                              ..._resbaCardsFor(reply.id),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      ref.read(bbsCommentProvider(post.id).notifier).toggleLike(reply);
                                    },
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Transform.translate(
                                          offset: const Offset(0, 1),
                                          child: reply.isLikedByMe
                                              ? const Icon(CupertinoIcons.heart_fill, color: Colors.pink, size: 14)
                                              : SvgPicture.asset(
                                                  'assets/images/icons/tweeticon/heart.svg',
                                                  width: 14,
                                                  height: 14,
                                                  colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                                                ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text('${reply.likesCount}', style: AppTextStyles.notoSans(color: Colors.grey, fontSize: 13, height: 1.1)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  InkWell(
                                    onTap: () {
                                      onReplyTap(reply.id, rUserName, true);
                                    },
                                    child: Text('返信', style: AppTextStyles.bold(fontSize: 12, color: Colors.grey, height: 1.0)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyImageToggle extends StatefulWidget {
  final String imageUrl;

  const _ReplyImageToggle({required this.imageUrl});

  @override
  State<_ReplyImageToggle> createState() => _ReplyImageToggleState();
}

class _ReplyImageToggleState extends State<_ReplyImageToggle> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
        onTap: () {
          setState(() {
            _isVisible = !_isVisible;
          });
        },
        child: Text(
          _isVisible ? '写真を閉じる' : '写真を見る',
          style: AppTextStyles.notoSans(
            fontSize: 12,
            color: Colors.blueAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
        ),
        if (_isVisible) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 800, // 表示サイズでデコードしてカクつきを抑える
              fadeInDuration: Duration.zero, // ふわ〜っと出るフェードを無効化してパッと表示
              fadeOutDuration: Duration.zero,
              placeholder: (context, url) => Container(
                height: 100,
                color: Colors.grey[300],
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ],
      ],
    );
  }
}
