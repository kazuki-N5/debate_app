// ignore_for_file: file_names, use_build_context_synchronously
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/utils/date_formatter.dart';
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
  List<ResbaInvite> _invites = [];
  bool _loading = true;
  int _tabIndex = 0; // 0: 募集中 / 1: 応募されてる中 / 2: 履歴

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final list = await ref.read(resbaActionsProvider).getMySentResbas();
    if (mounted) {
      setState(() {
        _invites = list;
        _loading = false;
      });
    }
  }

  List<ResbaInvite> get _current {
    switch (_tabIndex) {
      case 0: // 募集中（応募ゼロ）
        return _invites
            .where((i) => i.isPending && i.applicationCount == 0)
            .toList();
      case 1: // 応募されてる中（応募あり）
        return _invites
            .where((i) => i.isPending && i.applicationCount > 0)
            .toList();
      default: // 履歴
        return _invites.where((i) => !i.isPending).toList();
    }
  }

  /// 応募の承認 / 拒否（応募されてる中タブから直接操作）
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

  Future<void> _withdraw(ResbaInvite invite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚔️ 取り下げますか？'),
        content: Text('「${invite.theme}」の募集を取り下げます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('いいえ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('取り下げる'),
          ),
        ],
      ),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚔️ 削除しますか？'),
        content: Text('「${invite.theme}」を一覧から完全に削除します（元に戻せません）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('いいえ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除する'),
          ),
        ],
      ),
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
    final current = _current;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('⚔️ マイレスバ', style: AppTextStyles.bold(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: Column(
        children: [
          // セグメント
          Row(
            children: [
              _segButton('募集中', 0),
              _segButton('応募されてる中', 1),
              _segButton('履歴', 2),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : current.isEmpty
                    ? Center(
                        child: Text(
                          _tabIndex == 0
                              ? '募集中のレスバはありません'
                              : _tabIndex == 1
                                  ? '応募が来ているレスバはありません'
                                  : '履歴はありません',
                          style: AppTextStyles.notoSans(
                              color: Colors.grey, fontSize: 15),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: current.length,
                          itemBuilder: (context, index) =>
                              _buildCard(current[index]),
                        ),
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
        onTap: () => setState(() => _tabIndex = index),
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
              fontSize: 14,
              color: selected ? Colors.blue : Colors.grey,
            ),
          ),
        ),
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
                    backgroundImage:
                        firstApp.applicantAvatar != null &&
                                firstApp.applicantAvatar!.isNotEmpty
                            ? NetworkImage(firstApp.applicantAvatar!)
                            : null,
                    child: firstApp.applicantAvatar == null ||
                            firstApp.applicantAvatar!.isEmpty
                        ? const Icon(Icons.person, size: 14)
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
