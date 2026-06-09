import 'dart:async';
import 'package:flutter/material.dart';
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

class RouterTrigger extends ChangeNotifier {
  void trigger() => notifyListeners();
}

final routerRefreshListenableProvider = Provider<Listenable>((ref) {
  final trigger = RouterTrigger();
  ref.listen(userProvider, (_, __) {
    Future.microtask(() => trigger.trigger());
  });
  ref.listen(leagueProvider, (_, __) {
    Future.microtask(() => trigger.trigger());
  });
  return trigger;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final user = ref.read(userProvider).value;
      final league = ref.read(leagueProvider).value;
      final loggedIn = user != null;
      final hasLeague = league != null;

      if (loggedIn && hasLeague && state.matchedLocation == '/') {
        return '/home';
      }
      if ((!loggedIn || !hasLeague) &&
          state.matchedLocation != '/' &&
          !state.matchedLocation.startsWith('/join/')) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OnboardingScreen(),
      ),
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
});

class VoleoApp extends ConsumerWidget {
  const VoleoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Voleo',
      debugShowCheckedModeBanner: false,
      theme: buildVoleoTheme(),
      darkTheme: buildVoleoTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
