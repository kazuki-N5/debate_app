// ignore_for_file: file_names, use_build_context_synchronously
import 'package:debate_project/provider/resba_provider.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 応募中の常駐バナー（アプリ全体の上部に固定・タブ切替と無関係）
///  - 応募中: 「⚔️ 申し込み中（◯◯さんのレスバ）」+ 取り消す
///  - 拒否/取消: 「⚔️ 拒否されました」を表示してすぐ消える
///  - 右スワイプで右へ流して隠せる（戻るボタン等と被るとき用）。
///    次の申し込みが発生すると再表示される。
class ResbaApplyingBanner extends ConsumerStatefulWidget {
  const ResbaApplyingBanner({super.key});

  @override
  ConsumerState<ResbaApplyingBanner> createState() =>
      _ResbaApplyingBannerState();
}

class _ResbaApplyingBannerState extends ConsumerState<ResbaApplyingBanner> {
  /// 右スワイプで隠されたかどうか
  bool _dismissed = false;

  /// ドラッグ中の右方向の移動量(px)。左には動かさない。
  double _dx = 0;

  @override
  void initState() {
    super.initState();
    // ホスト応募検知 + 再起動時の再ダイアログをアプリ全体で開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resbaMatchListenerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(applyingInfoProvider);
    final info = infoAsync.valueOrNull;
    if (info == null || !info.isPending) {
      // 非表示の間はスワイプ状態をリセット → 次の申し込みでは再表示される
      // (この分岐では常に非表示ウィジェットを返すため setState 不要)
      _dismissed = false;
      _dx = 0;
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: AnimatedSlide(
                // 隠す時は右側の画面外へ流して消す（親の Stack がクリップする）
                offset: _dismissed ? const Offset(2, 0) : Offset.zero,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dx = (_dx + details.delta.dx)
                          .clamp(0.0, double.infinity)
                          .toDouble();
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (_dx > 90 || velocity > 600) {
                      // 右スワイプ(または右フリック): バナーを隠す
                      setState(() {
                        _dismissed = true;
                        _dx = 0;
                      });
                    } else {
                      // 途中までなら元の位置へ戻す
                      setState(() {
                        _dx = 0;
                      });
                    }
                  },
                  child: Transform.translate(
                    offset: Offset(_dx, 0),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Row(
                            children: [
                              const Text('⚔️', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '申し込み中（${info.hostName ?? ''}さんのレスバ）',
                                  style: AppTextStyles.bold(
                                    fontSize: 13,
                                    color: const Color(0xFF7856FF),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  await ref
                                      .read(applyingInfoProvider.notifier)
                                      .cancelApplication();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7856FF),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    '取り消す',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // スワイプで隠したとき、右端に残す再表示タブ
            Positioned(
              // 右上のアイコン(ハンバーガー等)と重ならないよう、左へアイコン1個分ずらす
              right: 12 + 40,
              top: 6,
              child: IgnorePointer(
                ignoring: !_dismissed,
                child: AnimatedOpacity(
                  opacity: _dismissed ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Semantics(
                    button: true,
                    label: '申し込み中バナーを再表示',
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _dismissed = false;
                          _dx = 0;
                        });
                      },
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.white,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('⚔️', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 1),
                              Icon(
                                Icons.chevron_left,
                                size: 18,
                                color: Color(0xFF7856FF),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
