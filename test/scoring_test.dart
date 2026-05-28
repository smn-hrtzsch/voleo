import 'package:flutter_test/flutter_test.dart';
import 'package:voleo/src/domain/scoring.dart';
import 'package:voleo/src/domain/voleo_models.dart';

void main() {
  group('scoreTip', () {
    test('awards 4 points for exact result', () {
      final result = scoreTip(
        predictedHome: 2,
        predictedAway: 1,
        actualHome: 2,
        actualAway: 1,
      );

      expect(result.points, 4);
      expect(result.isExact, isTrue);
      expect(result.isTendency, isTrue);
    });

    test('awards 3 points for correct goal difference', () {
      final result = scoreTip(
        predictedHome: 3,
        predictedAway: 1,
        actualHome: 2,
        actualAway: 0,
      );

      expect(result.points, 3);
      expect(result.isExact, isFalse);
      expect(result.isTendency, isTrue);
    });

    test('awards 2 points for correct tendency', () {
      final result = scoreTip(
        predictedHome: 1,
        predictedAway: 0,
        actualHome: 3,
        actualAway: 1,
      );

      expect(result.points, 2);
      expect(result.isExact, isFalse);
      expect(result.isTendency, isTrue);
    });

    test('awards 0 points for wrong tendency', () {
      final result = scoreTip(
        predictedHome: 1,
        predictedAway: 0,
        actualHome: 0,
        actualAway: 2,
      );

      expect(result.points, 0);
      expect(result.isExact, isFalse);
      expect(result.isTendency, isFalse);
    });
  });

  test('locks tips at kickoff', () {
    final match = CupMatch(
      id: 'm1',
      homeTeam: 'A',
      awayTeam: 'B',
      kickoff: DateTime(2026, 6, 11, 21),
      stage: 'Gruppenphase',
      status: MatchStatus.scheduled,
    );

    expect(canEditTip(match, DateTime(2026, 6, 11, 20, 59)), isTrue);
    expect(canEditTip(match, DateTime(2026, 6, 11, 21)), isFalse);
  });

  test('ranks by points, exact count, then display name', () {
    final ranked = rankStandings([
      const Standing(
        uid: 'b',
        displayName: 'Bela',
        totalPoints: 4,
        exactCount: 0,
        tendencyCount: 2,
        rank: 0,
      ),
      const Standing(
        uid: 'a',
        displayName: 'Ana',
        totalPoints: 4,
        exactCount: 1,
        tendencyCount: 1,
        rank: 0,
      ),
      const Standing(
        uid: 'c',
        displayName: 'Chris',
        totalPoints: 2,
        exactCount: 0,
        tendencyCount: 1,
        rank: 0,
      ),
    ]);

    expect(ranked.map((standing) => standing.uid), ['a', 'b', 'c']);
    expect(ranked.map((standing) => standing.rank), [1, 2, 3]);
  });
}
