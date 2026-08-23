// ignore_for_file: file_names, use_build_context_synchronously
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:debate_project/widgets/app_confirm_dialog.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// マイレスバ（自分が送信したレスバの一覧・管理）
class MyResbaListPage extends ConsumerStatefulWidget {
  const MyResbaListPage({super.key});

  @override
  ConsumerState<MyResbaListPage> createState() => _MyResbaListPageState();
}

class _MyResbaListPageState extends ConsumerState<MyResbaListPage> {
  late final PageController _pageController;
  List<ResbaInvite> _invites = [];
  bool _loading = true;
  int _tabIndex = 0; // 0: 募集中 / 1: 届いた応募 / 2: 応募中 / 3: 履歴

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex);
    _fetch(isInitial: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool isInitial = false}) async {
    if (isInitial) {
      setState(() => _loading = true);
    }
    final list = await ref.read(resbaActionsProvider).getMySentResbas();
    await ref.read(applyingInfoProvider.notifier).fetch();
    if (mounted) {
      setState(() {
        _invites = list;
        _loading = false;
      });
    }
  }

  /// 応募の承認 / 拒否（届いた応募タブから直接操作）
  Future<void> _approveApplication(ResbaInvite invite, bool approve) async {
    final app = invite.firstApplication;
    if (app == null) return;
    final result = await ref
        .read(resbaActionsProvider)
        .approveApplication(invite.id, app.id, approve);
    if (result.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.error!)));
      }
      return;
    }
    if (approve && result.roomId != null) {
      // 承認 → 試合へ
      await ref.read(matchingRoomProvider.notifier).joinBbsRoom(result.roomId!);
      if (mounted) router.go('/wait');
      return;
    }
    await _fetch();
  }

  /// 自分の応募を取り消す
  Future<void> _cancelMyApplication(ApplyingInfo info) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: '応募を取り消しますか？',
      message: '「${info.theme}」への応募を取り消します。',
      cancelText: 'いいえ',
      confirmText: '取り消す',
      isDestructive: false,
    );
    if (ok != true) return;
    final result =
        await ref.read(resbaActionsProvider).cancelMyPendingApplications();
    if (result.error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error!)));
    }
    await _fetch();
  }

  Future<void> _withdraw(ResbaInvite invite) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: '募集を取り下げますか？',
      message: '「${invite.theme}」の募集を取り下げます。',
      cancelText: 'いいえ',
      confirmText: '取り下げる',
      isDestructive: false,
    );
    if (ok != true) return;
    final result = await ref.read(resbaActionsProvider).cancel(invite.id);
    if (result.error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error!)));
    }
    await _fetch();
  }

  Future<void> _delete(ResbaInvite invite) async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: '募集を完全に削除しますか？',
      message: '「${invite.theme}」を一覧から完全に削除します（元に戻せません）。',
      cancelText: 'いいえ',
      confirmText: '削除する',
      isDestructive: true,
    );
    if (ok != true) return;
    final result = await ref.read(resbaActionsProvider).deleteResba(invite.id);
    if (result.error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error!)));
    }
    await _fetch();
  }

  Future<void> _resumeBattle(ResbaInvite invite) async {
    final roomId = invite.battleRoomId;
    if (roomId == null) return;
    await ref.read(matchingRoomProvider.notifier).joinBbsRoom(roomId);
    router.go('/wait');
  }

  void _watchBattleLog(ResbaInvite invite) {
    router.push('/resbaWatch', extra: invite);
  }

  @override
  Widget build(BuildContext context) {
    final recruitingList =
        _invites.where((i) => i.isPending && i.applicationCount == 0).toList();
    final receivedList =
        _invites.where((i) => i.isPending && i.applicationCount > 0).toList();
    final historyList = _invites.where((i) => !i.isPending).toList();
    final applyingInfo = ref.watch(applyingInfoProvider).valueOrNull;
    final isApplying = applyingInfo != null && applyingInfo.isPending;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('⚔️ マイレスバ',
            style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: Column(
        children: [
          // セグメント
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE6E6E6)),
              ),
            ),
            child: Row(
              children: [
                _segButton('募集中', 0),
                _segButton('届いた応募', 1),
                _segButton('応募中', 2),
                _segButton('履歴', 3),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _tabIndex = index);
                    },
                    children: [
                      _buildInviteListTab(
                        list: recruitingList,
                        emptyMessage: '募集中のレスバはありません',
                      ),
                      _buildInviteListTab(
                        list: receivedList,
                        emptyMessage: '届いた応募はありません',
                      ),
                      _buildApplyingTab(
                        applyingInfo: applyingInfo,
                        isApplying: isApplying,
                      ),
                      _buildInviteListTab(
                        list: historyList,
                        emptyMessage: '履歴はありません',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _segButton(String label, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_tabIndex != index) {
            setState(() => _tabIndex = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bold(
              fontSize: 13,
              color: selected ? Colors.blue : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteListTab({
    required List<ResbaInvite> list,
    required String emptyMessage,
  }) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 160),
                Center(
                  child: Text(
                    emptyMessage,
                    style: AppTextStyles.notoSans(
                        color: Colors.grey, fontSize: 15),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, index) => _buildCard(list[index]),
            ),
    );
  }

  Widget _buildApplyingTab({
    required ApplyingInfo? applyingInfo,
    required bool isApplying,
  }) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: !isApplying || applyingInfo == null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 160),
                Center(
                  child: Text(
                    '現在応募中のレスバはありません',
                    style: AppTextStyles.notoSans(
                        color: Colors.grey, fontSize: 15),
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                _buildApplyingCard(applyingInfo),
              ],
            ),
    );
  }

  Widget _buildCard(ResbaInvite invite) {
    final isPending = invite.isPending;
    final isAccepted = invite.isAccepted;

    final String placeLabel;
    final String placeIcon;
    switch (invite.attachType) {
      case 'post':
        placeLabel = 'ポスト';
        placeIcon = '📝';
        break;
      case 'comment':
        placeLabel = '返信';
        placeIcon = '💬';
        break;
      default:
        placeLabel = 'DM';
        placeIcon = '✉️';
    }

    final String statusLabel;
    final Color statusColor;
    if (isPending && invite.applicationCount > 0) {
      // 応募されてる中: 応募件数を強調表示
      statusLabel = '応募${invite.applicationCount}件';
      statusColor = const Color(0xFF7856FF);
    } else if (isPending) {
      statusLabel = invite.attachType == 'post' ? '募集中' : '相手待ち';
      statusColor = const Color(0xFFC77800);
    } else if (isAccepted) {
      statusLabel = '対戦中';
      statusColor = const Color(0xFF7856FF);
    } else if (invite.status == 'declined') {
      statusLabel = '拒否';
      statusColor = Colors.grey;
    } else if (invite.status == 'finished') {
      statusLabel = '終了';
      statusColor = Colors.grey;
    } else {
      statusLabel = '取り下げ';
      statusColor = Colors.grey;
    }

    // 先頭の応募者（承認/拒否対象）
    final firstApp = invite.firstApplication;

    return Card(
      color: const Color(0xFFF3F3F3),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$placeIcon $placeLabel',
                    style: AppTextStyles.notoSans(
                        fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTextStyles.bold(
                        fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              invite.theme,
              style: AppTextStyles.bold(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              '${DateFormatter.formatBbsDate(invite.createdAt)}'
              '${invite.attachType == 'post' && isPending ? ' ・ 応募${invite.applicationCount}件' : ''}',
              style:
                  AppTextStyles.notoSans(fontSize: 11, color: Colors.grey),
            ),
            // 応募されてる中: 先頭の応募者を表示
            if (isPending && firstApp != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        firstApp.applicantAvatar != null &&
                                firstApp.applicantAvatar!.isNotEmpty
                            ? NetworkImage(firstApp.applicantAvatar!)
                            : null,
                    child: firstApp.applicantAvatar == null ||
                            firstApp.applicantAvatar!.isEmpty
                        ? Icon(Icons.person, size: 14, color: Colors.grey[600])
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${firstApp.applicantName ?? '名無し'} さん',
                    style:
                        AppTextStyles.bold(fontSize: 12, color: Colors.black87),
                  ),
                  if (firstApp.applicantTrophy != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '🏆 ${firstApp.applicantTrophy}',
                      style: AppTextStyles.notoSans(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (isPending && firstApp != null) ...[
                  // 応募されてる中: 承認 / 拒否
                  Expanded(
                    child: _actionButton(
                      label: '✅ 承認して対戦',
                      color: const Color(0xFF00BA7C),
                      onTap: () => _approveApplication(invite, true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: '拒否',
                      color: Colors.grey,
                      onTap: () => _approveApplication(invite, false),
                    ),
                  ),
                ] else if (isPending)
                  Expanded(
                    child: _actionButton(
                      label: '取り下げる',
                      color: Colors.grey,
                      onTap: () => _withdraw(invite),
                    ),
                  )
                else if (isAccepted)
                  Expanded(
                    child: _actionButton(
                      label: '対戦へ戻る',
                      color: const Color(0xFF7856FF),
                      onTap: () => _resumeBattle(invite),
                    ),
                  )
                else if (invite.status == 'finished' &&
                    invite.battleRoomId != null &&
                    invite.attachType != 'dm') ...[
                  // 対戦終了: 観戦ログは消さずに残す（クリックで閲覧）+ 削除
                  Expanded(
                    child: _actionButton(
                      label: '👁 観戦ログを見る',
                      color: const Color(0xFF7856FF),
                      onTap: () => _watchBattleLog(invite),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      label: '削除',
                      color: Colors.red,
                      onTap: () => _delete(invite),
                    ),
                  ),
                ]
                else
                  Expanded(
                    child: _actionButton(
                      label: '削除',
                      color: Colors.red,
                      onTap: () => _delete(invite),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyingCard(ApplyingInfo info) {
    final String placeLabel;
    final String placeIcon;
    switch (info.attachType) {
      case 'post':
        placeLabel = 'ポスト';
        placeIcon = '📝';
        break;
      case 'comment':
        placeLabel = '返信';
        placeIcon = '💬';
        break;
      default:
        placeLabel = 'DM';
        placeIcon = '✉️';
    }

    const statusLabel = '承認待ち';
    const statusColor = Color(0xFF7856FF);

    return Card(
      color: const Color(0xFFF3F3F3),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$placeIcon $placeLabel',
                    style: AppTextStyles.notoSans(
                        fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTextStyles.bold(
                        fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              info.theme,
              style: AppTextStyles.bold(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.formatBbsDate(info.createdAt),
              style: AppTextStyles.notoSans(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      info.hostAvatar != null && info.hostAvatar!.isNotEmpty
                          ? NetworkImage(info.hostAvatar!)
                          : null,
                  child: info.hostAvatar == null || info.hostAvatar!.isEmpty
                      ? Icon(Icons.person, size: 14, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  '${info.hostName ?? '名無し'} さんのレスバに応募中',
                  style:
                      AppTextStyles.bold(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    label: '応募を取り消す',
                    color: Colors.grey,
                    onTap: () => _cancelMyApplication(info),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: AppTextStyles.bold(fontSize: 12, color: Colors.white),
        ),
      ),
    );
  }
}
