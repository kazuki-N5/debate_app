// ignore_for_file: file_names, use_build_context_synchronously
import 'package:debate_project/modes/resba_invite.dart';
import 'package:debate_project/provider/matching_provider.dart';
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:debate_project/router/router.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _resbaColor = Color(0xFF7856FF);

/// 小さな ⚔️ バッジ（タイムライン・コメント本文用）
class ResbaBadge extends StatelessWidget {
  final String text;
  const ResbaBadge({super.key, this.text = 'レスバ'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _resbaColor.withValues(alpha: 0.1),
        border: Border.all(color: _resbaColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '⚔️ $text',
        style: AppTextStyles.bold(fontSize: 10, color: _resbaColor),
      ),
    );
  }
}

/// レスバカード本体（状態に応じた操作ボタンを表示）
class ResbaCard extends ConsumerWidget {
  final ResbaInvite invite;

  /// 状態変化後に親側で一覧を再取得するためのコールバック
  final VoidCallback? onChanged;

  const ResbaCard({super.key, required this.invite, this.onChanged});

  Future<void> _showError(BuildContext context, String? error) async {
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// バトル開始（成立時）
  Future<void> _startBattle(BuildContext context, WidgetRef ref, String roomId) async {
    try {
      await ref.read(matchingRoomProvider.notifier).joinBbsRoom(roomId);
      if (context.mounted) router.go('/wait');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('対戦を開始できませんでした')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(resbaActionsProvider);

    // ---- 状態に応じたアクションボタン ----
    List<Widget> actionButtons = [];

    if (invite.isPending && invite.isTarget) {
      // 指名型: 承諾 / 拒否
      actionButtons = [
        _ActionButton(
          label: '⚔️ 承諾して対戦',
          color: const Color(0xFF00BA7C),
          onTap: () async {
            final result = await actions.respond(invite.id, true);
            if (result.error != null) {
              await _showError(context, result.error);
            } else if (result.roomId != null) {
              onChanged?.call();
              await _startBattle(context, ref, result.roomId!);
            } else {
              onChanged?.call();
            }
          },
        ),
        _ActionButton(
          label: '拒否',
          color: Colors.grey,
          onTap: () async {
            final result = await actions.respond(invite.id, false);
            await _showError(context, result.error);
            onChanged?.call();
          },
        ),
      ];
    } else if (invite.isPending && !invite.isTarget && !invite.isSender) {
      // 募集型（ポスト / 返信 / DM / オプチャ / 対戦募集）: 応募者側
      if (invite.myApplication == null || invite.myApplication == 'cancelled') {
        // 未応募 or 自分でやめた → 応募できる（再応募可）
        actionButtons = [
          _ActionButton(
            label: '⚔️ 応じる',
            color: _resbaColor,
            onTap: () async {
              // 応募できるのは1試合のみ: 応募中なら入れ替え確認
              final applying = ref.read(applyingInfoProvider).valueOrNull;
              if (applying != null && applying.isPending) {
                final swap = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('⚔️ 応募できるのは1試合までです'),
                    content: const Text(
                        '今の応募を取り消して、この申し込みにしますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('いいえ'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('はい（入れ替え）'),
                      ),
                    ],
                  ),
                );
                if (swap != true) return;
                await actions.cancelMyPendingApplications();
              }
              final result = await actions.apply(invite.id);
              await _showError(context, result.error);
              onChanged?.call();
            },
          ),
        ];
      } else if (invite.myApplication == 'pending') {
        actionButtons = [
          _ActionButton(
            label: '応募を取り下げ',
            color: Colors.grey,
            onTap: () async {
              final result = await actions.cancelApplication(invite.id);
              await _showError(context, result.error);
              onChanged?.call();
            },
          ),
        ];
      } else {
        // rejected（拒否された）→ 押せない
        actionButtons = [];
      }
    } else if (invite.isPending && invite.isSender) {
      // 送信者側: 募集型は申込者を1件ずつ承認、指名型（旧DM）は相手待ち
      if (!invite.isTarget && invite.firstApplication != null) {
        return _buildPostHostCard(context, ref, invite.firstApplication!);
      }
      actionButtons = [
        _ActionButton(
          label: '取り下げる',
          color: Colors.grey,
          onTap: () async {
            final result = await actions.cancel(invite.id);
            await _showError(context, result.error);
            onChanged?.call();
          },
        ),
      ];
    } else if (invite.isAccepted) {
      // 対戦中: 参加者は「対戦へ戻る」、第三者（観戦者）は「👁 観戦する」
      if (invite.battleRoomId != null) {
        final myId = ref.read(currentUserIdProvider);
        final isParticipant = invite.senderId == myId ||
            invite.responderId == myId;
        // DM は当事者2名のみのため観戦導線なし（対戦へ戻るのみ）
        if (invite.attachType == 'dm' && !isParticipant) {
          actionButtons = [];
        } else {
          actionButtons = [
            _ActionButton(
              label: isParticipant ? '対戦へ戻る' : '👁 観戦する',
              color: const Color(0xFF7856FF),
              onTap: () {
                if (isParticipant) {
                  _startBattle(context, ref, invite.battleRoomId!);
                } else {
                  router.push('/resbaWatch', extra: invite);
                }
              },
            ),
          ];
        }
      }
    } else if (invite.status == 'finished' &&
        invite.battleRoomId != null &&
        invite.attachType != 'dm') {
      // 対戦終了: 観戦ログは消さずに残す（クリックで閲覧）
      actionButtons = [
        _ActionButton(
          label: '👁 観戦ログを見る',
          color: const Color(0xFF7856FF),
          onTap: () => router.push('/resbaWatch', extra: invite),
        ),
      ];
    }

    // ---- 状態ラベル ----
    String? statusLabel;
    if (!invite.isSender &&
        !invite.isTarget &&
        invite.myApplication == 'rejected') {
      // 他の人が承認されたため自動却下された応募者には「拒否されました」を表示
      statusLabel = '拒否されました';
    } else if (invite.isAccepted) {
      statusLabel = '対戦中';
    } else if (invite.status == 'declined') {
      statusLabel = '拒否されました';
    } else if (invite.status == 'cancelled') {
      statusLabel = '取り下げられました';
    } else if (invite.status == 'finished') {
      statusLabel = '対戦終了';
    } else if (invite.isTarget) {
      statusLabel = '相手待ち';
    } else if (invite.isSender && !invite.isTarget) {
      statusLabel = '申込待ち';
    } else if (invite.isSender) {
      statusLabel = '相手待ち';
    } else if (!invite.isTarget) {
      // 拒否された場合は「募集中」と表示しない
      statusLabel = invite.myApplication == 'rejected' ? '拒否されました' : '募集中';
    }

    final showStatusOnly = actionButtons.isEmpty && statusLabel != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        border: Border.all(color: _resbaColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              if (invite.senderAvatar != null && invite.senderAvatar!.isNotEmpty)
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(invite.senderAvatar!),
                )
              else
                const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invite.isTarget
                      ? '⚔️ ${invite.senderName ?? '名無し'}さんからレスバが届きました'
                      : '⚔️ レスバ',
                  style: AppTextStyles.bold(fontSize: 12.5),
                ),
              ),
              if (statusLabel != null && showStatusOnly)
                Text(
                  statusLabel,
                  style: AppTextStyles.notoSans(
                      fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            invite.theme,
            style: AppTextStyles.bold(fontSize: 14, color: Colors.black87),
          ),
          if (invite.choice1 != null && invite.choice2 != null) ...[
            const SizedBox(height: 2),
            Text(
              '選択肢：${invite.choice1} vs ${invite.choice2}',
              style: AppTextStyles.notoSans(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (invite.isAccepted && invite.battleRoomId != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (invite.attachType != 'dm') ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    invite.attachType == 'dm'
                        ? '⚔️ 対戦が始まっています'
                        : '🔴 ⚔️ 対戦中・ライブ観戦できます',
                    style: AppTextStyles.bold(fontSize: 12, color: _resbaColor),
                  ),
                ),
              ],
            ),
          ],
          if (invite.status == 'finished') ...[
            const SizedBox(height: 6),
            Text(
              '⚔️ 対戦が終了しました・観戦ログを見る',
              style: AppTextStyles.bold(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (actionButtons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final btn in actionButtons) ...[
                  if (btn != actionButtons.first) const SizedBox(width: 8),
                  Expanded(child: btn),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// ポスト型・ホスト側の「応募者を1件ずつ承認/拒否」カード
  Widget _buildPostHostCard(BuildContext context, WidgetRef ref, ResbaApplication app) {
    final actions = ref.read(resbaActionsProvider);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        border: Border.all(color: _resbaColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (app.applicantAvatar != null && app.applicantAvatar!.isNotEmpty)
                CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage(app.applicantAvatar!),
                )
              else
                const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${app.applicantName ?? '名無し'} が応じました',
                        style: AppTextStyles.bold(fontSize: 12.5)),
                    if (app.applicantTrophy != null)
                      Text('🏆 ${app.applicantTrophy}',
                          style: AppTextStyles.notoSans(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('⚔️ ${invite.theme}', style: AppTextStyles.bold(fontSize: 13.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: '承認して対戦',
                  color: const Color(0xFF00BA7C),
                  onTap: () async {
                    final result = await actions.approveApplication(
                        invite.id, app.id, true);
                    if (result.error != null) {
                      await _showError(context, result.error);
                    } else if (result.roomId != null) {
                      onChanged?.call();
                      await _startBattle(context, ref, result.roomId!);
                    } else {
                      onChanged?.call();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: '拒否',
                  color: Colors.grey,
                  onTap: () async {
                    final result = await actions.approveApplication(
                        invite.id, app.id, false);
                    await _showError(context, result.error);
                    onChanged?.call();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
