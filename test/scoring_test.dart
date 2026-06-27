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

  test('keeps team picks when ranking standings', () {
    final ranked = rankStandings([
      const Standing(
        uid: 'a',
        displayName: 'Ana',
        totalPoints: 4,
        exactCount: 1,
        differenceCount: 0,
        tendencyCount: 1,
        rank: 0,
        favoriteTeam: 'Deutschland',
        predictedChampion: 'Frankreich',
      ),
    ]);

    expect(ranked.single.favoriteTeam, 'Deutschland');
    expect(ranked.single.predictedChampion, 'Frankreich');
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

  group('risk progression', () {
    test('penalizes group-stage exit pick once knockouts are reached', () {
      final points = calculateExtraPoints(
        const VoleoUser(
          uid: 'olaf',
          nickname: 'Olaf',
          isAnonymous: false,
          riskTeam: 'Belgien',
          riskStage: 'Gruppenphase',
        ),
        [
          CupMatch(
            id: 'ko1',
            homeTeam: 'Belgien',
            awayTeam: 'Bester 3. Gruppe A/E/H/I/J',
            kickoff: DateTime(2026, 7, 3),
            stage: 'Sechzehntelfinale',
            group: '',
            status: MatchStatus.scheduled,
          ),
        ],
      );

      expect(points, -40);
    });

    test('exposes current negative risk points for detail views', () {
      final points = calculateCurrentRiskPoints(
        'Belgien',
        'Gruppenphase',
        [
          CupMatch(
            id: 'ko1',
            homeTeam: 'Belgien',
            awayTeam: 'Bester 3. Gruppe A/E/H/I/J',
            kickoff: DateTime(2026, 7, 1),
            stage: 'Sechzehntelfinale',
            group: '',
            status: MatchStatus.scheduled,
          ),
        ],
      );

      expect(points, -40);
    });

    test('does not award points before actual elimination', () {
      final points = calculateExtraPoints(
        const VoleoUser(
          uid: 'olaf',
          nickname: 'Olaf',
          isAnonymous: false,
          riskTeam: 'Belgien',
          riskStage: 'Sechzehntelfinale',
        ),
        [
          CupMatch(
            id: 'ko1',
            homeTeam: 'Belgien',
            awayTeam: 'Bester 3. Gruppe A/E/H/I/J',
            kickoff: DateTime(2026, 7, 3),
            stage: 'Sechzehntelfinale',
            group: '',
            status: MatchStatus.scheduled,
          ),
        ],
      );

      expect(points, 0);
    });

    test('penalizes exit pick immediately after team wins that round', () {
      final points = calculateExtraPoints(
        const VoleoUser(
          uid: 'olaf',
          nickname: 'Olaf',
          isAnonymous: false,
          riskTeam: 'Belgien',
          riskStage: 'Sechzehntelfinale',
        ),
        [
          CupMatch(
            id: 'ko1',
            homeTeam: 'Belgien',
            awayTeam: 'Kanada',
            kickoff: DateTime(2026, 7, 3),
            stage: 'Sechzehntelfinale',
            group: '',
            status: MatchStatus.finalResult,
            homeScore: 2,
            awayScore: 0,
          ),
        ],
      );

      expect(points, -30);
    });
  });

  group('isSameTeam', () {
    test('correctly maps various aliases and languages', () {
      expect(isSameTeam('Germany', 'Deutschland'), isTrue);
      expect(isSameTeam('Argentina', 'Argentinien'), isTrue);
      expect(isSameTeam('Côte d\'Ivoire', 'Elfenbeinküste'), isTrue);
      expect(
          isSameTeam('bosnia and herzegovina', 'Bosnien-Herzegowina'), isTrue);
      expect(isSameTeam('USA', 'United States'), isTrue);
      expect(isSameTeam('katar', 'Qatar'), isTrue);
    });
  });
}
