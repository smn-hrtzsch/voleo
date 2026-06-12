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
      group: 'A',
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
        differenceCount: 0,
        tendencyCount: 2,
        rank: 0,
      ),
      const Standing(
        uid: 'a',
        displayName: 'Ana',
        totalPoints: 4,
        exactCount: 1,
        differenceCount: 0,
        tendencyCount: 1,
        rank: 0,
      ),
      const Standing(
        uid: 'c',
        displayName: 'Chris',
        totalPoints: 2,
        exactCount: 0,
        differenceCount: 0,
        tendencyCount: 1,
        rank: 0,
      ),
    ]);

    expect(ranked.map((standing) => standing.uid), ['a', 'b', 'c']);
    expect(ranked.map((standing) => standing.rank), [1, 2, 3]);
  });

  group('calculateRiskPoints', () {
    test('awards points when team exits earlier than predicted', () {
      final points = calculateRiskPoints(
        'Brasilien',
        'Viertelfinale',
        'Achtelfinale',
      );

      expect(points, 30);
    });

    test('penalizes when team stays longer than predicted', () {
      final points = calculateRiskPoints(
        'Brasilien',
        'Achtelfinale',
        'Viertelfinale',
      );

      expect(points, -50);
    });

    test('supports sixteenth-final risk stage', () {
      final points = calculateRiskPoints(
        'Brasilien',
        'Sechzehntelfinale',
        'Sechzehntelfinale',
      );

      expect(points, 60);
    });
  });
}
