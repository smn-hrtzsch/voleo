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

  group('scoreTipForMatch knockout scoring', () {
    test('awards 5, 4 and 3 points when a match ends after 90 minutes', () {
      final match = _knockoutMatch(
        regularHome: 2,
        regularAway: 0,
      );

      expect(
        scoreTipForMatch(tip: _tip(2, 0), match: match).points,
        5,
      );
      expect(
        scoreTipForMatch(tip: _tip(3, 1), match: match).points,
        4,
      );
      expect(
        scoreTipForMatch(tip: _tip(1, 0), match: match).points,
        3,
      );
    });

    test('awards at most 5 points when a match ends after extra time', () {
      final match = _knockoutMatch(
        regularHome: 1,
        regularAway: 1,
        otHome: 2,
        otAway: 1,
        resultNote: 'EXTRA_TIME',
      );

      final exactResult = scoreTipForMatch(
        tip: _tip(1, 1, otHome: 2, otAway: 1),
        match: match,
      );
      expect(exactResult.points, 5);
      expect(exactResult.details, ['90 Min. exakt +3', 'n.V. exakt +2']);
      expect(
        scoreTipForMatch(
          tip: _tip(0, 0, otHome: 1, otAway: 0),
          match: match,
        ).points,
        3,
      );
    });

    test('awards 6 points for a fully exact penalty-shootout tip', () {
      final match = _knockoutMatch(
        regularHome: 1,
        regularAway: 1,
        otHome: 2,
        otAway: 2,
        penaltyHome: 5,
        penaltyAway: 4,
        resultNote: 'PENALTY_SHOOTOUT',
      );

      final result = scoreTipForMatch(
        tip: _tip(
          1,
          1,
          otHome: 2,
          otAway: 2,
          penaltyWinner: PenaltyWinnerSide.home,
        ),
        match: match,
      );

      expect(result.points, 6);
      expect(result.isExact, isTrue);
      expect(result.details, [
        '90 Min. exakt +3',
        'Remis n.V. +1',
        'n.V. exakt +1',
        'Sieger i.E. +1',
      ]);
    });

    test('ignores a penalty prediction when the real match ends in extra time',
        () {
      final match = _knockoutMatch(
        regularHome: 1,
        regularAway: 1,
        otHome: 2,
        otAway: 1,
        resultNote: 'EXTRA_TIME',
      );

      final result = scoreTipForMatch(
        tip: _tip(
          1,
          1,
          otHome: 2,
          otAway: 1,
          penaltyWinner: PenaltyWinnerSide.home,
        ),
        match: match,
      );

      expect(result.points, 5);
    });

    test('does not score an incomplete draft', () {
      final match = _knockoutMatch(
        regularHome: 1,
        regularAway: 1,
        otHome: 1,
        otAway: 1,
        penaltyHome: 4,
        penaltyAway: 5,
        resultNote: 'PENALTY_SHOOTOUT',
      );

      expect(
        scoreTipForMatch(
          tip: _tip(1, 1, otHome: 1, otAway: 1, isComplete: false),
          match: match,
        ).points,
        0,
      );
      expect(
        scoreTipForMatch(
          tip: _tip(1, 1, otHome: 1, otAway: 1),
          match: match,
        ).points,
        0,
      );
    });
  });

  group('scoreLiveTip knockout preview', () {
    test('uses the extra-time path when the current score is a draw', () {
      final match = _knockoutMatch(
        regularHome: 1,
        regularAway: 1,
        status: MatchStatus.live,
      );

      final exact = scoreLiveTip(
        tip: _tip(1, 1, otHome: 2, otAway: 1),
        match: match,
      );
      final draw = scoreLiveTip(
        tip: _tip(0, 0, otHome: 1, otAway: 0),
        match: match,
      );

      expect(exact.points, 3);
      expect(exact.details, ['90 Min. exakt +3']);
      expect(draw.points, 2);
      expect(draw.details, ['Remis nach 90 Min. +2']);
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
        tipPoints: 4,
        exactCount: 0,
        differenceCount: 0,
        tendencyCount: 2,
        rank: 0,
      ),
      const Standing(
        uid: 'a',
        displayName: 'Ana',
        totalPoints: 4,
        tipPoints: 4,
        exactCount: 1,
        differenceCount: 0,
        tendencyCount: 1,
        rank: 0,
      ),
      const Standing(
        uid: 'c',
        displayName: 'Chris',
        totalPoints: 2,
        tipPoints: 2,
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
        tipPoints: 4,
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

    test('keeps later Brazil exit calls unresolved after round-of-32 win', () {
      final matches = [
        CupMatch(
          id: 'ko-brazil',
          homeTeam: 'Brasilien',
          awayTeam: 'Japan',
          kickoff: DateTime(2026, 6, 29),
          stage: 'Sechzehntelfinale',
          group: '',
          status: MatchStatus.finalResult,
          homeScore: 2,
          awayScore: 1,
          winner: 'Brazil',
        ),
      ];

      expect(
        calculateExtraPoints(
          const VoleoUser(
            uid: 'philipp',
            nickname: 'Philipp',
            isAnonymous: false,
            riskTeam: 'Brasilien',
            riskStage: 'Achtelfinale',
          ),
          matches,
        ),
        0,
      );
      expect(
        calculateCurrentRiskPoints(
          'Brasilien',
          'Viertelfinale',
          matches,
        ),
        isNull,
      );
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

CupMatch _knockoutMatch({
  required int regularHome,
  required int regularAway,
  int? otHome,
  int? otAway,
  int? penaltyHome,
  int? penaltyAway,
  String? resultNote,
  MatchStatus status = MatchStatus.finalResult,
}) {
  return CupMatch(
    id: 'ko-1',
    homeTeam: 'Deutschland',
    awayTeam: 'Frankreich',
    kickoff: DateTime(2026, 7, 10),
    stage: 'Achtelfinale',
    group: '',
    status: status,
    homeScore: penaltyHome ?? otHome ?? regularHome,
    awayScore: penaltyAway ?? otAway ?? regularAway,
    regularHomeScore: regularHome,
    regularAwayScore: regularAway,
    otHomeScore: otHome,
    otAwayScore: otAway,
    penaltyHomeScore: penaltyHome,
    penaltyAwayScore: penaltyAway,
    winner: (penaltyHome ?? otHome ?? regularHome) >
            (penaltyAway ?? otAway ?? regularAway)
        ? 'Deutschland'
        : 'Frankreich',
    resultNote: resultNote,
  );
}

Tip _tip(
  int home,
  int away, {
  int? otHome,
  int? otAway,
  PenaltyWinnerSide? penaltyWinner,
  bool isComplete = true,
}) {
  return Tip(
    uid: 'u1',
    matchId: 'ko-1',
    predictedHome: home,
    predictedAway: away,
    predictedOtHome: otHome,
    predictedOtAway: otAway,
    predictedPenaltyWinner: penaltyWinner,
    isComplete: isComplete,
    lockedAt: DateTime(2026, 7, 10),
    points: 0,
  );
}
