import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/league/league_screen.dart';
import '../features/matches/matches_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/tips/tip_entry_screen.dart';
import 'voleo_theme.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
        path: '/matches', builder: (context, state) => const MatchesScreen()),
    GoRoute(path: '/league', builder: (context, state) => const LeagueScreen()),
    GoRoute(
        path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(
      path: '/tip/:matchId',
      builder: (context, state) {
        return TipEntryScreen(matchId: state.pathParameters['matchId']!);
      },
    ),
  ],
);

class VoleoApp extends StatelessWidget {
  const VoleoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Voleo',
      debugShowCheckedModeBanner: false,
      theme: buildVoleoTheme(),
      routerConfig: _router,
    );
  }
}
