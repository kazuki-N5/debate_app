import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:debate_project/modes/history.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:debate_project/widgets/radar_chart_view.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:debate_project/adsence/ad_mbanner_provider.dart';
import 'package:debate_project/view_model/Paypage_view_model.dart';

class HistoryDetailPage extends HookConsumerWidget {
  final MatchRecordDisplay record;

  const HistoryDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BannerAd? mediumRectangleAd = ref.watch(mediumRectangleAdProvider);
    final isSubscribe = ref.watch(inAppPurchaseManagerProvider).isSubscribed;

    final resultText = record.resultString;
    final resultColor = resultText == '勝利' ? Colors.red : Colors.grey[700];

    final hasTrophyChange = record.trophyChange != 0;
    final basePointTextVal = (record.trophyChange > 0 ? '+' : '') + record.trophyChange.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('詳細・分析', style: AppTextStyles.bold(color: Colors.white, fontSize: 20)),
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        color: Colors.blue,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  '結果発表',
                  style: AppTextStyles.bold(color: Colors.black, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasTrophyChange)
                            Opacity(
                              opacity: 0,
                              child: Row(
                                children: [
                                  const Image(image: AssetImage('assets/images/trofie.png'), width: 24, height: 24),
                                  const SizedBox(width: 1),
                                  Text(basePointTextVal, style: AppTextStyles.notoSans(fontSize: 24, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          Text(
                            resultText,
                            style: AppTextStyles.notoSans(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: resultColor,
                            ),
                          ),
                          if (hasTrophyChange)
                            Row(
                              children: [
                                const SizedBox(width: 4),
                                Transform.translate(
                                  offset: const Offset(0, 6),
                                  child: Row(
                                    children: [
                                      const Image(image: AssetImage('assets/images/trofie.png'), width: 24, height: 24),
                                      const SizedBox(width: 1),
                                      Text(
                                        basePointTextVal,
                                        style: AppTextStyles.notoSans(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: record.trophyChange > 0 ? Colors.red : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (record.isUnderdog && hasTrophyChange) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber[400]!, Colors.amber[700]!, Colors.orange[800]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('格差ボーナス ', style: AppTextStyles.bold(color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        if (record.myScore != null) ...[
                          RadarChartView(
                            myScore: record.myScore!,
                            opponentScore: record.opponentScore ?? record.myScore!,
                            myName: record.myName ?? 'あなた',
                            opponentName: record.opponentName,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (record.reason.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '勝敗の理由:',
                                  style: AppTextStyles.bold(fontSize: 16, color: Colors.blue[800]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  record.reason,
                                  style: AppTextStyles.notoSans(fontSize: 14, color: Colors.black87, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (isSubscribe == false && mediumRectangleAd != null)
                          Container(
                            alignment: Alignment.center,
                            width: mediumRectangleAd.size.width.toDouble(),
                            height: mediumRectangleAd.size.height.toDouble(),
                            child: AdWidget(ad: mediumRectangleAd),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/chistory', extra: record);
                      },
                      icon: const Icon(Icons.forum_outlined, size: 20),
                      label: Text(
                        'レスバを見る',
                        style: AppTextStyles.notoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
