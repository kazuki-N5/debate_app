
import 'package:debate_project/views/ChosePage.dart';
import 'package:debate_project/views/FinishPage.dart';
import 'package:debate_project/views/GamePage.dart';
import 'package:debate_project/views/HistoryPage.dart';
import 'package:debate_project/views/HomePage.dart';
import 'package:debate_project/views/LoginPage.dart';
import 'package:debate_project/views/Matching.dart';
import 'package:debate_project/views/NamePage.dart';
import 'package:debate_project/views/SettingPage.dart';
import 'package:go_router/go_router.dart';// Import HistoryRoom model
import 'package:flutter/material.dart'; // Import Scaffold for error case


final GoRouter router = GoRouter(
  // Optional: Add error builder for better debugging
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text("Routing Error")),
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => LoginPage(),
    ),
    GoRoute(
      path: '/wait',
      builder: (context, state) => MatchingPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomePage(),
    ),
    GoRoute(
      path: '/game',
      // Potentially, GamePage might need parameters later (e.g., game ID)
      builder: (context, state) => GamePage(),
    ),
    GoRoute(
      path: '/chose',
      // Potentially, ChosePage might need parameters later (e.g., theme ID)
      builder: (context, state) => ChosePage(),
    ),
    GoRoute(
      path: '/finish',
      // Potentially, FinishPage might need parameters later (e.g., results)
      builder: (context, state) => FinishPage(),
    ),
    GoRoute(
      path: '/name',
      builder: (context, state) => NamePage(),
    ),
    
    GoRoute(
      path: '/setting', // Conventionally, paths are lowercase: /history
      builder: (context, state) => SettingPage(),
    ),
    GoRoute(
      path: '/history', // Conventionally, paths are lowercase: /history
      builder: (context, state) => HistoryPage(),
    ),
  ],
);