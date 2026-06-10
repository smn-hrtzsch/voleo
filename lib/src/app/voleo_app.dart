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
import '../features/table/table_screen.dart';
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
  ref.listen(sessionTransitionProvider, (_, __) {
    Future.microtask(() => trigger.trigger());
  });
  ref.listen(forceOnboardingProvider, (_, __) {
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
      final userValue = ref.read(userProvider);
      final leagueValue = ref.read(leagueProvider);
      final sessionTransitioning = ref.read(sessionTransitionProvider);
      final forceOnboarding = ref.read(forceOnboardingProvider);
      final isLoadingAuth = userValue.isLoading || userValue.isRefreshing;
      final user = userValue.value;
      final league = leagueValue.value;
      final loggedIn = user != null;
      final isLoadingLeague =
          loggedIn && (leagueValue.isLoading || leagueValue.isRefreshing);
      final hasLeague = league != null;
      final isLoadingRoute = state.matchedLocation == '/loading';
      final isRootRoute = state.matchedLocation == '/';

      if (sessionTransitioning) {
        return isLoadingRoute ? null : '/loading';
      }
      if (forceOnboarding) {
        return isRootRoute ? null : '/';
      }
      if (isLoadingRoute && (isLoadingAuth || isLoadingLeague)) {
        return null;
      }
      if ((isLoadingAuth || isLoadingLeague) && isRootRoute) {
        return '/loading';
      }
      if (isLoadingRoute) {
        return loggedIn && hasLeague ? '/home' : '/';
      }

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
        path: '/loading',
        builder: (context, state) => const _AppLoadingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final user = ref.watch(userProvider).value;
          return OnboardingScreen(
            key: ValueKey(user?.uid ?? 'signed-out'),
          );
        },
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
              path: '/table',
              builder: (context, state) => const TableScreen(),
              routes: [
                GoRoute(
                  path: 'tip/:matchId',
                  builder: (context, state) {
                    return TipEntryScreen(
                      matchId: state.pathParameters['matchId']!,
                      returnPath: '/table',
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
              routes: [
                GoRoute(
                  path: 'tip/:matchId',
                  builder: (context, state) {
                    return TipEntryScreen(
                      matchId: state.pathParameters['matchId']!,
                      returnPath: '/league',
                    );
                  },
                ),
              ],
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

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 180,
            child: LinearProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
