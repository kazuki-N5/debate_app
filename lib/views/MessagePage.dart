// ignore_for_file: file_names
import 'package:debate_project/modes/app_notification.dart';
import 'package:debate_project/modes/bbs_post.dart';
import 'package:debate_project/provider/chat_inbox_provider.dart';
import 'package:debate_project/provider/notification_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:debate_project/views/DmRoomPage.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/community_ad.dart';
import 'package:debate_project/widgets/notification/chat_inbox_list_tile.dart';
import 'package:debate_project/widgets/notification/notification_list_tile.dart';
import 'package:debate_project/widgets/count_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// メッセージタブ
/// 「通知」と「メッセージ(DM / オプチャ)」をセグメントで切り替える画面
class MessagePage extends HookConsumerWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController(initialPage: 0);
    final selectedSegment = useState<int>(0); // 0: 通知 / 1: メッセージ

    final notificationsAsync = ref.watch(notificationProvider);
    final unreadNotifications =
        notificationsAsync.valueOrNull?.where((n) => !n.isRead).length ?? 0;

    final inboxAsync = ref.watch(chatInboxProvider);
    final unreadMessages = inboxAsync.valueOrNull
            ?.fold<int>(0, (sum, item) => sum + item.unreadCount) ??
        0;

    // 下部の常時表示バナー(ホームシェル)にリスト最下部が被らないよう、
    // 非課金(広告表示)時のみ下パディングを確保する
    final isSubscribed = ref.watch(inAppPurchaseManagerProvider).isSubscribed;
    final bottomPadding =
        isSubscribed ? 0.0 : homeBottomAdClearance();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text('メッセージ', style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.blue,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: Column(
        children: [
          _SegmentTab(
            selected: selectedSegment.value,
            onChanged: (index) {
              selectedSegment.value = index;
              pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              );
            },
            tab1Label: '通知',
            tab1Count: unreadNotifications,
            tab2Label: 'メッセージ',
            tab2Count: unreadMessages,
          ),
          Expanded(
            child: PageView(
              controller: pageController,
              onPageChanged: (index) {
                selectedSegment.value = index;
              },
              children: [
                _NotificationList(
                  notificationsAsync: notificationsAsync,
                  onTapNotification: (n) =>
                      _openNotification(context, ref, n),
                  onRefresh: () => ref
                      .read(notificationProvider.notifier)
                      .fetchNotifications(),
                  onLoadMore: () =>
                      ref.read(notificationProvider.notifier).loadMore(),
                  bottomPadding: bottomPadding,
                ),
                _MessageList(
                  inboxAsync: inboxAsync,
                  onRefresh: () => ref.refresh(chatInboxProvider.future),
                  onTapItem: (item) => _openChat(context, ref, item),
                  bottomPadding: bottomPadding,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 通知タップ時の画面遷移
  Future<void> _openNotification(
      BuildContext context, WidgetRef ref, AppNotification n) async {
    // 開いた通知は既読化
    ref.read(notificationProvider.notifier).markRead(n.id);

    switch (n.type) {
      case 'follow':
        context.push('/userProfile', extra: n.actorId);
        break;
      case 'resba_invite':
      case 'resba_accepted':
      case 'resba_declined':
        if (n.inviteId != null) {
          context.push(
            '/resbaRequest',
            extra: (inviteId: n.inviteId, notification: n),
          );
          break;
        }
        // 旧データ（invite_id なし）: ポスト添付なら詳細へ、それ以外は開けない
        if (n.post != null) {
          context.push('/bbsPostDetail', extra: n.post);
        } else if (n.postId != null) {
          // JOINで投稿データが取れなかった場合、直接DBから取得
          try {
            final supabase = ref.read(supabaseProvider);
            final response = await supabase
                .from('bbs_posts')
                .select('*, users!bbs_posts_user_id_fkey(*)')
                .eq('id', n.postId!)
                .maybeSingle();
            if (response != null && context.mounted) {
              final post = BbsPost.fromMap(response);
              context.push('/bbsPostDetail', extra: post);
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('投稿が見つかりませんでした')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('投稿の取得に失敗しました')),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('このレスバは見つかりませんでした')),
          );
        }
        break;
      case 'like_post':
      case 'like_comment':
      case 'reply_comment':
      case 'comment':
        if (n.post != null) {
          context.push('/bbsPostDetail', extra: n.post);
        } else if (n.postId != null) {
          // JOINで投稿データが取れなかった場合、直接DBから取得
          try {
            final supabase = ref.read(supabaseProvider);
            final response = await supabase
                .from('bbs_posts')
                .select('*, users!bbs_posts_user_id_fkey(*)')
                .eq('id', n.postId!)
                .maybeSingle();
            if (response != null && context.mounted) {
              final post = BbsPost.fromMap(response);
              context.push('/bbsPostDetail', extra: post);
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('投稿が見つかりませんでした')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('投稿の取得に失敗しました')),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('投稿が見つかりませんでした')),
          );
        }
        break;
      default:
        break;
    }
  }

  /// メッセージタップ時の画面遷移
  void _openChat(BuildContext context, WidgetRef ref, ChatInboxItem item) async {
    if (item.isDm) {
      // ルームを開く前に既読化
      await ref.read(markDmReadProvider)(item.roomId);
      ref.invalidate(chatInboxProvider);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, __) => DmRoomPage(
            otherUserId: item.otherUserId ?? '',
            otherUserName: item.otherUserName ?? item.title,
            otherUserAvatar: item.avatarUrl,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      // 画面から戻ってきたときにも最新の既読状態に更新
      ref.invalidate(chatInboxProvider);
    } else if (item.openChatRoom != null) {
      // ルームを開く前に既読化
      await ref.read(markOpenChatReadProvider)(item.roomId);
      ref.invalidate(chatInboxProvider);
      if (!context.mounted) return;
      await context.push('/openChatRoom', extra: item.openChatRoom);
      // 画面から戻ってきたときにも最新の既読状態に更新
      ref.invalidate(chatInboxProvider);
    }
  }
}

/// セグメントタブ (通知 / メッセージ)
class _SegmentTab extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final String tab1Label;
  final int tab1Count;
  final String tab2Label;
  final int tab2Count;

  const _SegmentTab({
    required this.selected,
    required this.onChanged,
    required this.tab1Label,
    required this.tab1Count,
    required this.tab2Label,
    required this.tab2Count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE6E6E6)),
        ),
      ),
      child: Row(
        children: [
          _buildTab(context, 0, tab1Label, tab1Count),
          _buildTab(context, 1, tab2Label, tab2Count),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index, String label, int count) {
    final isActive = selected == index;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFF1D9BF0) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTextStyles.bold(
                  fontSize: 14,
                  color: isActive ? const Color(0xFF1D9BF0) : Colors.grey,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                CountBadge(
                  count: count,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 通知リスト (無限スクロール対応)
class _NotificationList extends StatefulWidget {
  final AsyncValue<List<AppNotification>> notificationsAsync;
  final void Function(AppNotification) onTapNotification;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final double bottomPadding;

  const _NotificationList({
    required this.notificationsAsync,
    required this.onTapNotification,
    required this.onRefresh,
    this.onLoadMore,
    this.bottomPadding = 0.0,
  });

  @override
  State<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<_NotificationList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 末尾付近までスクロールしたら追加読み込み
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.notificationsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return _EmptyMessage(
            icon: Icons.notifications_none,
            text: '通知はまだありません',
          );
        }
        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return NotificationListTile(
                notification: n,
                onTap: () => widget.onTapNotification(n),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _EmptyMessage(
        icon: Icons.error_outline,
        text: '通知の取得に失敗しました',
        onRetry: widget.onRefresh,
      ),
    );
  }
}

/// メッセージリスト (DM + オプチャ)
class _MessageList extends StatelessWidget {
  final AsyncValue<List<ChatInboxItem>> inboxAsync;
  final Future<void> Function() onRefresh;
  final void Function(ChatInboxItem) onTapItem;
  final double bottomPadding;

  const _MessageList({
    required this.inboxAsync,
    required this.onRefresh,
    required this.onTapItem,
    this.bottomPadding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return inboxAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyMessage(
            icon: Icons.chat_bubble_outline,
            text: 'メッセージはまだありません',
            subText: 'DMやクラブの\nやり取りがここに表示されます',
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPadding),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ChatInboxListTile(
                item: item,
                onTap: () => onTapItem(item),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _EmptyMessage(
        icon: Icons.error_outline,
        text: 'メッセージの取得に失敗しました',
        onRetry: onRefresh,
      ),
    );
  }
}


/// 空状態・エラー状態の共通表示
class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subText;
  final Future<void> Function()? onRetry;

  const _EmptyMessage({
    required this.icon,
    required this.text,
    this.subText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.notoSans(fontSize: 14, color: Colors.grey),
          ),
          if (subText != null) ...[
            const SizedBox(height: 4),
            Text(
              subText!,
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.notoSans(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('再読み込み'),
            ),
          ],
        ],
      ),
    );
  }
}
