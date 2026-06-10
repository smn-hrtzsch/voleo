import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(matchesProvider);
    final tips = ref.watch(tipsProvider);
    final leagueTips = ref.watch(leagueTipsProvider);
    final standings = ref.watch(standingsProvider);

    final isSyncing = matches.isRefreshing ||
        matches.isLoading ||
        tips.isRefreshing ||
        tips.isLoading ||
        leagueTips.isRefreshing ||
        leagueTips.isLoading ||
        standings.isRefreshing ||
        standings.isLoading;

    final canPopNavigator = Navigator.of(context, rootNavigator: true).canPop();
    return PopScope(
      canPop: canPopNavigator || widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0, initialLocation: false);
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            if (isSyncing)
              const SizedBox(
                height: 2.0,
                child: LinearProgressIndicator(),
              )
            else
              const SizedBox(height: 2.0),
            Expanded(
              child: SafeArea(child: widget.navigationShell),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) {
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_soccer_outlined),
              selectedIcon: Icon(Icons.sports_soccer),
              label: 'Spiele',
            ),
            NavigationDestination(
              icon: Icon(Icons.table_chart_outlined),
              selectedIcon: Icon(Icons.table_chart),
              label: 'Tabelle',
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard),
              label: 'Liga',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
