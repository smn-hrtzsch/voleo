import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleo/src/domain/clock.dart';
import 'package:voleo/src/domain/voleo_models.dart';
import 'package:voleo/src/features/matches/matches_screen.dart';
import 'package:voleo/src/providers.dart';

class _DelayedSwipeModeController extends DateModeController {
  @override
  bool build() {
    scheduleMicrotask(() => state = true);
    return false;
  }

  @override
  Future<void> setSwipeByDay(bool value) async => state = value;
}

void main() {
  testWidgets('opens the current match day after restoring swipe mode',
      (tester) async {
    final now = VoleoClock.now;
    final today = DateTime(now.year, now.month, now.day);
    final previousDay = today.subtract(const Duration(days: 2));
    final matches = [
      CupMatch(
        id: 'previous',
        homeTeam: 'Südafrika',
        awayTeam: 'Kanada',
        kickoff: previousDay.add(const Duration(hours: 19)),
        stage: 'Sechzehntelfinale',
        group: '',
        status: MatchStatus.finalResult,
        homeScore: 0,
        awayScore: 1,
      ),
      CupMatch(
        id: 'today',
        homeTeam: 'Niederlande',
        awayTeam: 'Marokko',
        kickoff: today.add(const Duration(hours: 19)),
        stage: 'Sechzehntelfinale',
        group: '',
        status: MatchStatus.scheduled,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dateModeProvider.overrideWith(_DelayedSwipeModeController.new),
          matchesProvider.overrideWith((ref) => Stream.value(matches)),
          tipsProvider.overrideWith((ref) => Stream.value(const <Tip>[])),
          userProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: MatchesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 1);
    expect(find.text('Niederlande'), findsOneWidget);
  });
}
