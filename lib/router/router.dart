import 'package:debate_project/modes/history.dart';
import 'package:debate_project/views/ChathistoryPage.dart';
import 'package:debate_project/views/ChosePage.dart';
import 'package:debate_project/views/FinishPage.dart';
import 'package:debate_project/views/GamePage.dart';
import 'package:debate_project/views/HistoryPage.dart';
import 'package:debate_project/views/HomePage.dart';
import 'package:debate_project/views/LoginPage.dart';
import 'package:debate_project/views/Matching.dart';
import 'package:debate_project/views/NamePage.dart';
import 'package:debate_project/views/NamePage_change.dart';
import 'package:debate_project/views/SettingPage.dart';
import 'package:debate_project/views/TransferPage.dart';
import 'package:debate_project/views/WaittransferPage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text("Routing Error")),
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(child: LoginPage(), key: state.pageKey),
    ),

    // ★ MatchingPageのみアニメーションあり（builder をそのまま使う）
    GoRoute(
      path: '/wait',
      builder: (context, state) => MatchingPage(),
    ),

    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => NoTransitionPage(child: HomePage(), key: state.pageKey),
    ),
    GoRoute(
      path: '/game',
      pageBuilder: (context, state) => NoTransitionPage(child: GamePage(), key: state.pageKey),
    ),
    GoRoute(
      path: '/chose',
      pageBuilder: (context, state) => NoTransitionPage(child: ChosePage(), key: state.pageKey),
    ),
    GoRoute(
      path: '/finish',
      pageBuilder: (context, state) => NoTransitionPage(child: FinishPage(), key: state.pageKey),
    ),
    GoRoute(
      path: '/name',
      pageBuilder: (context, state) => NoTransitionPage(child: NamePage(), key: state.pageKey),
    ),
    GoRoute(
      path: '/setting',
      pageBuilder: (context, state) => NoTransitionPage(child: SettingPage(), key: state.pageKey),
    ),
    GoRoute(
      path: '/history',
      pageBuilder: (context, state) => NoTransitionPage(child: HistoryPage(), key: state.pageKey),
    ),
    GoRoute(
      path: '/name2',
      pageBuilder: (context, state) => NoTransitionPage(child: NamePageChange(), key: state.pageKey),
    ),
    GoRoute(
      path: '/chistory',
      pageBuilder: (context, state) {
        final record = state.extra as MatchRecordDisplay;
        return NoTransitionPage(
          child: ChatHistoryPage(record: record),
          key: state.pageKey,
        );
      },
    ),
    GoRoute(
      path: '/transfer',
      pageBuilder: (context, state) => NoTransitionPage(child: TransferPage(), key: state.pageKey),
    ),
    GoRoute(
      path: '/waittransfer',
      pageBuilder: (context, state) => NoTransitionPage(child: const WaittransferPage(), key: state.pageKey),
    ),
  ],
);