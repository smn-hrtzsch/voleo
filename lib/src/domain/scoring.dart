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
  if (predictedDiff == actualDiff && actualDiff != 0) {
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

bool isSameTeam(String a, String b) {
  final normA = a.toLowerCase().trim();
  final normB = b.toLowerCase().trim();
  if (normA == normB) return true;

  bool isBosnia(String name) {
    return name == 'bosnia and herzegovina' ||
        name == 'bosnien und herzegowina' ||
        name == 'bosnien-herzegowina' ||
        name == 'bosnien herzegowina';
  }

  if (isBosnia(normA) && isBosnia(normB)) return true;

  return normA.replaceAll('-', '').replaceAll(' ', '') ==
      normB.replaceAll('-', '').replaceAll(' ', '');
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

bool _isGroupStage(String stage) {
  return stage.startsWith('Gruppe') || stage.contains('Runde');
}

String? getEliminationStage(String team, List<CupMatch> matches) {
  final teamMatches = matches
      .where(
          (m) => isSameTeam(m.homeTeam, team) || isSameTeam(m.awayTeam, team))
      .toList();
  if (teamMatches.isEmpty) return null;

  final knockouts = teamMatches.where((m) => !_isGroupStage(m.stage)).toList();

  for (final m in knockouts) {
    if (m.status == MatchStatus.finalResult) {
      final winner = getMatchWinner(m);
      if (winner != null && winner != team) {
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
      getMatchWinner(m) != null &&
      isSameTeam(getMatchWinner(m)!, team));
  if (hasWonFinal) {
    return 'Champion';
  }

  final groupMatches = matches.where((m) => _isGroupStage(m.stage)).toList();
  final teamGroupMatches =
      teamMatches.where((m) => _isGroupStage(m.stage)).toList();
  final teamGroupFinished = teamGroupMatches.isNotEmpty &&
      teamGroupMatches.every((m) => m.status == MatchStatus.finalResult);

  if (teamGroupFinished && knockouts.isEmpty) {
    // If the team finished its group matches and has no knockout matches,
    // it's either out or not yet assigned.
    // If all group matches of the tournament are finished, it's definitely out.
    final allGroupsFinished = groupMatches.isNotEmpty &&
        groupMatches.every((m) => m.status == MatchStatus.finalResult);
    if (allGroupsFinished) {
      return 'Gruppenphase';
    }

    // Or if some knockout matches are already scheduled with real teams (not placeholders),
    // and this team is not among them, it's likely out.
    final hasDeterminedKnockouts = matches.any((m) =>
        !_isGroupStage(m.stage) &&
        !_isPlaceholder(m.homeTeam) &&
        !_isPlaceholder(m.awayTeam));

    if (hasDeterminedKnockouts) {
      return 'Gruppenphase';
    }
  }

  return null;
}

bool _isPlaceholder(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('sieger') ||
      lower.startsWith('zweiter') ||
      lower.startsWith('dritter') ||
      lower.startsWith('bester') ||
      lower.startsWith('verlierer') ||
      lower.contains('gruppe') ||
      lower.contains('sechzehntelfinale') ||
      lower.contains('achtelfinale') ||
      lower.contains('viertel') ||
      lower.contains('halb') ||
      lower.contains('platz 3') ||
      lower.contains('finale') ||
      lower.startsWith('tbd') ||
      lower.trim().isEmpty;
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
      if (match.status == MatchStatus.finalResult) {
        final winner = getMatchWinner(match);
        if (winner != null && isSameTeam(winner, fav)) {
          extraPoints += 10;
        }
      }
    }
  }

  // 2. Favorit
  final championTipp = user.predictedChampion;
  if (championTipp != null && championTipp.isNotEmpty) {
    for (final match in matches) {
      if (match.status == MatchStatus.finalResult) {
        final winner = getMatchWinner(match);
        if (winner != null && isSameTeam(winner, championTipp)) {
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

String? getMatchWinner(CupMatch match) {
  if (match.winner != null && match.winner!.isNotEmpty) {
    return match.winner;
  }
  if (match.status != MatchStatus.finalResult ||
      match.homeScore == null ||
      match.awayScore == null) {
    return null;
  }
  if (match.homeScore! > match.awayScore!) {
    return match.homeTeam;
  }
  if (match.awayScore! > match.homeScore!) {
    return match.awayTeam;
  }
  return null;
}

int getMatchTotalPoints({
  required int tipPoints,
  required String? favoriteTeam,
  required String? predictedChampion,
  required CupMatch match,
}) {
  final winner = getMatchWinner(match);
  var total = tipPoints;
  if (winner != null &&
      favoriteTeam != null &&
      isSameTeam(favoriteTeam, winner)) total += 10;
  if (winner != null &&
      predictedChampion != null &&
      isSameTeam(predictedChampion, winner)) total += 10;
  return total;
}

String getEvaluationLabel({
  required int tipPoints,
  required String? favoriteTeam,
  required String? predictedChampion,
  required CupMatch match,
}) {
  final winner = getMatchWinner(match);
  final isFavWin = winner != null &&
      favoriteTeam != null &&
      isSameTeam(favoriteTeam, winner);
  final isChampWin = winner != null &&
      predictedChampion != null &&
      isSameTeam(predictedChampion, winner);

  final baseLabel = tipPoints == 4
      ? 'exakt'
      : tipPoints == 3
          ? 'Differenz'
          : tipPoints == 2
              ? 'Tendenz'
              : 'falsch';

  final boosters = <String>[];
  if (isFavWin) boosters.add('Lieblings-Team');
  if (isChampWin) boosters.add('Favorit-Booster');

  if (boosters.isEmpty) return baseLabel;
  return '$baseLabel\n+ ${boosters.join('\n+ ')}';
}
