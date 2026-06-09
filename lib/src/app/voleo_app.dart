import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/league/join_league_screen.dart';
import '../features/home/home_screen.dart';
import '../features/league/league_screen.dart';
import '../features/matches/matches_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shared/app_shell.dart';
import '../features/tips/tip_entry_screen.dart';
import '../providers.dart';
import 'voleo_theme.dart';

GoRouter _createRouter() => GoRouter(
      initialLocation: _hasCachedUser() ? '/home' : '/',
      redirect: (context, state) {
        final loggedIn = _hasCachedUser();
        if (loggedIn && state.matchedLocation == '/') return '/home';
        return null;
      },
      routes: [
        GoRoute(
            path: '/', builder: (context, state) => const OnboardingScreen()),
        GoRoute(
          path: '/join/:inviteCode',
          builder: (context, state) => JoinLeagueScreen(
            inviteCode: state.pathParameters['inviteCode']!,
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'tip/:matchId',
                    builder: (context, state) {
                      return TipEntryScreen(
                        matchId: state.pathParameters['matchId']!,
                        returnPath: '/home',
                      );
                    },
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/matches',
                builder: (context, state) => const MatchesScreen(),
                routes: [
                  GoRoute(
                    path: 'tip/:matchId',
                    builder: (context, state) {
                      return TipEntryScreen(
                        matchId: state.pathParameters['matchId']!,
                        returnPath: '/matches',
                      );
                    },
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/league',
                builder: (context, state) => const LeagueScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ]),
          ],
        ),
      ],
    );

bool _hasCachedUser() {
  if (firebase_core.Firebase.apps.isEmpty) return false;
  return auth.FirebaseAuth.instance.currentUser != null;
}

class VoleoApp extends StatefulWidget {
  const VoleoApp({super.key});

  @override
  State<VoleoApp> createState() => _VoleoAppState();
}

class _VoleoAppState extends State<VoleoApp> {
  late final GoRouter _router = _createRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final themeMode = ref.watch(themeModeProvider);
        return MaterialApp.router(
          title: 'Voleo',
          debugShowCheckedModeBanner: false,
          theme: buildVoleoTheme(),
          darkTheme: buildVoleoTheme(brightness: Brightness.dark),
          themeMode: themeMode,
          routerConfig: _router,
        );
      },
    );
  }
}
