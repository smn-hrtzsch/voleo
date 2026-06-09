import 'voleo_models.dart';

class ScoreResult {
  const ScoreResult({
    required this.points,
    required this.isExact,
    required this.isTendency,
  });

  final int points;
  final bool isExact;
  final bool isTendency;
}

ScoreResult scoreTip({
  required int predictedHome,
  required int predictedAway,
  required int actualHome,
  required int actualAway,
}) {
  if (predictedHome == actualHome && predictedAway == actualAway) {
    return const ScoreResult(points: 4, isExact: true, isTendency: true);
  }

  final predictedDiff = predictedHome - predictedAway;
  final actualDiff = actualHome - actualAway;
  if (predictedDiff == actualDiff) {
    return const ScoreResult(points: 3, isExact: false, isTendency: true);
  }

  if (_sign(predictedDiff) == _sign(actualDiff)) {
    return const ScoreResult(points: 2, isExact: false, isTendency: true);
  }

  return const ScoreResult(points: 0, isExact: false, isTendency: false);
}

bool canEditTip(CupMatch match, DateTime now) {
  return now.isBefore(match.kickoff);
}

List<Standing> rankStandings(List<Standing> standings) {
  final sorted = [...standings]..sort((a, b) {
      final points = b.totalPoints.compareTo(a.totalPoints);
      if (points != 0) return points;
      final exact = b.exactCount.compareTo(a.exactCount);
      if (exact != 0) return exact;
      return a.displayName.compareTo(b.displayName);
    });

  var previousPoints = -1;
  var previousExact = -1;
  var rank = 0;
  return [
    for (var index = 0; index < sorted.length; index++)
      () {
        final current = sorted[index];
        if (current.totalPoints != previousPoints ||
            current.exactCount != previousExact) {
          rank = index + 1;
          previousPoints = current.totalPoints;
          previousExact = current.exactCount;
        }
        return Standing(
          uid: current.uid,
          displayName: current.displayName,
          totalPoints: current.totalPoints,
          exactCount: current.exactCount,
          tendencyCount: current.tendencyCount,
          rank: rank,
          photoUrl: current.photoUrl,
        );
      }(),
  ];
}

int _sign(int value) {
  if (value > 0) return 1;
  if (value < 0) return -1;
  return 0;
}

String getTier(String team) {
  final favorites = [
    'Argentinien',
    'Brasilien',
    'Deutschland',
    'England',
    'Frankreich',
    'Portugal',
    'Spanien'
  ];
  final tops = [
    'Belgien',
    'Japan',
    'Kroatien',
    'Marokko',
    'Niederlande',
    'Norwegen',
    'Schweiz',
    'Senegal',
    'Uruguay'
  ];
  final mids = [
    'Algerien',
    'Australien',
    'Bosnien und Herzegowina',
    'Bosnien-Herzegowina',
    'Bosnien Herzegowina',
    'Bosnia and Herzegovina',
    'Kolumbien',
    'Ecuador',
    'Elfenbeinküste',
    'Ghana',
    'Mexiko',
    'Österreich',
    'Schweden',
    'Südkorea',
    'Tschechien',
    'Türkei',
    'USA'
  ];
  if (favorites.contains(team)) return 'Absolute Titelfavoriten';
  if (tops.contains(team)) return 'Top Team';
  if (mids.contains(team)) return 'Durchschnittliches Team';
  return 'Gurkentruppe';
}

String? getEliminationStage(String team, List<CupMatch> matches) {
  final teamMatches =
      matches.where((m) => m.homeTeam == team || m.awayTeam == team).toList();
  if (teamMatches.isEmpty) return null;

  final knockouts =
      teamMatches.where((m) => !m.stage.startsWith('Gruppe')).toList();

  for (final m in knockouts) {
    if (m.status == MatchStatus.finalResult &&
        m.homeScore != null &&
        m.awayScore != null) {
      final isHome = m.homeTeam == team;
      final won = isHome
          ? (m.homeScore! > m.awayScore!)
          : (m.awayScore! > m.homeScore!);
      if (!won) {
        final stage = m.stage.toLowerCase();
        if (stage.contains('sechzehntel') || stage.contains('32')) {
          return 'Sechzehntelfinale';
        }
        if (stage.contains('achtel') || stage.contains('16')) {
          return 'Achtelfinale';
        }
        if (stage.contains('viertel') || stage.contains('quarter')) {
          return 'Viertelfinale';
        }
        if (stage.contains('halb') || stage.contains('semi')) {
          return 'Halbfinale';
        }
        if (stage.contains('final')) {
          return 'Finale';
        }
      }
    }
  }

  final hasWonFinal = knockouts.any((m) =>
      m.stage.toLowerCase().contains('final') &&
      !m.stage.toLowerCase().contains('halb') &&
      !m.stage.toLowerCase().contains('viertel') &&
      m.status == MatchStatus.finalResult &&
      m.homeScore != null &&
      m.awayScore != null &&
      ((m.homeTeam == team && m.homeScore! > m.awayScore!) ||
          (m.awayTeam == team && m.awayScore! > m.homeScore!)));
  if (hasWonFinal) {
    return 'Champion';
  }

  final groupMatches =
      matches.where((m) => m.stage.startsWith('Gruppe')).toList();
  final allGroupsFinished = groupMatches.isNotEmpty &&
      groupMatches.every((m) => m.status == MatchStatus.finalResult);
  if (allGroupsFinished && knockouts.isEmpty) {
    return 'Gruppenphase';
  }

  return null;
}

int calculateRiskPoints(
    String team, String predictedStage, String actualStage) {
  final tier = getTier(team);
  final isCorrect = _stageRank(actualStage) <= _stageRank(predictedStage);

  if (tier == 'Absolute Titelfavoriten') {
    if (predictedStage == 'Gruppenphase') return isCorrect ? 70 : -70;
    if (predictedStage == 'Sechzehntelfinale') return isCorrect ? 60 : -60;
    if (predictedStage == 'Achtelfinale') return isCorrect ? 50 : -50;
    if (predictedStage == 'Viertelfinale') return isCorrect ? 30 : -30;
    if (predictedStage == 'Halbfinale') return isCorrect ? 15 : -15;
    if (predictedStage == 'Finale') return isCorrect ? 5 : -5;
  } else if (tier == 'Top Team') {
    if (predictedStage == 'Gruppenphase') return isCorrect ? 40 : -40;
    if (predictedStage == 'Sechzehntelfinale') return isCorrect ? 30 : -30;
    if (predictedStage == 'Achtelfinale') return isCorrect ? 20 : -20;
    if (predictedStage == 'Viertelfinale') return isCorrect ? 20 : -20;
    if (predictedStage == 'Halbfinale') return isCorrect ? 40 : -40;
    if (predictedStage == 'Finale') return isCorrect ? 50 : -50;
  } else if (tier == 'Durchschnittliches Team') {
    if (predictedStage == 'Gruppenphase') return isCorrect ? 5 : -5;
    if (predictedStage == 'Sechzehntelfinale') return isCorrect ? 10 : -10;
    if (predictedStage == 'Achtelfinale') return isCorrect ? 15 : -15;
    if (predictedStage == 'Viertelfinale') return isCorrect ? 35 : -35;
    if (predictedStage == 'Halbfinale') return isCorrect ? 55 : -55;
    if (predictedStage == 'Finale') return isCorrect ? 65 : -65;
  } else {
    // Gurkentruppe
    if (predictedStage == 'Gruppenphase') return isCorrect ? 5 : -5;
    if (predictedStage == 'Sechzehntelfinale') return isCorrect ? 15 : -15;
    if (predictedStage == 'Achtelfinale') return isCorrect ? 30 : -30;
    if (predictedStage == 'Viertelfinale') return isCorrect ? 50 : -50;
    if (predictedStage == 'Halbfinale') return isCorrect ? 65 : -65;
    if (predictedStage == 'Finale') return isCorrect ? 80 : -80;
  }
  return 0;
}

int _stageRank(String stage) {
  switch (stage) {
    case 'Gruppenphase':
      return 0;
    case 'Sechzehntelfinale':
      return 1;
    case 'Achtelfinale':
      return 2;
    case 'Viertelfinale':
      return 3;
    case 'Halbfinale':
      return 4;
    case 'Finale':
      return 5;
    case 'Champion':
      return 6;
  }
  return 99;
}

int calculateExtraPoints(VoleoUser user, List<CupMatch> matches) {
  var extraPoints = 0;

  // 1. Lieblingsmannschaft
  final fav = user.favoriteTeam;
  if (fav != null && fav.isNotEmpty) {
    for (final match in matches) {
      if (match.status == MatchStatus.finalResult &&
          match.homeScore != null &&
          match.awayScore != null) {
        if (match.homeTeam == fav && match.homeScore! > match.awayScore!) {
          extraPoints += 10;
        } else if (match.awayTeam == fav &&
            match.awayScore! > match.homeScore!) {
          extraPoints += 10;
        }
      }
    }
  }

  // 2. Favorit
  final championTipp = user.predictedChampion;
  if (championTipp != null && championTipp.isNotEmpty) {
    for (final match in matches) {
      if (match.status == MatchStatus.finalResult &&
          match.homeScore != null &&
          match.awayScore != null) {
        if (match.homeTeam == championTipp &&
            match.homeScore! > match.awayScore!) {
          extraPoints += 10;
        } else if (match.awayTeam == championTipp &&
            match.awayScore! > match.homeScore!) {
          extraPoints += 10;
        }
      }
    }
  }

  // 3. Risiko-Tipp
  final rTeam = user.riskTeam;
  final rStage = user.riskStage;
  if (rTeam != null &&
      rTeam.isNotEmpty &&
      rStage != null &&
      rStage.isNotEmpty) {
    final actualStage = getEliminationStage(rTeam, matches);
    if (actualStage != null) {
      extraPoints += calculateRiskPoints(rTeam, rStage, actualStage);
    }
  }

  return extraPoints;
}
