import 'voleo_models.dart';

enum ScoreClassification { none, tendency, difference, exact }

class ScoreResult {
  const ScoreResult({
    required this.points,
    required this.classification,
    this.details = const [],
  });

  final int points;
  final ScoreClassification classification;
  final List<String> details;

  bool get isExact => classification == ScoreClassification.exact;
  bool get isDifference => classification == ScoreClassification.difference;
  bool get isTendency => classification != ScoreClassification.none;
}

const _noScore = ScoreResult(
  points: 0,
  classification: ScoreClassification.none,
);

ScoreResult scoreTip({
  required int predictedHome,
  required int predictedAway,
  required int actualHome,
  required int actualAway,
}) {
  if (predictedHome == actualHome && predictedAway == actualAway) {
    return const ScoreResult(
      points: 4,
      classification: ScoreClassification.exact,
    );
  }

  final predictedDiff = predictedHome - predictedAway;
  final actualDiff = actualHome - actualAway;
  if (predictedDiff == actualDiff && actualDiff != 0) {
    return const ScoreResult(
      points: 3,
      classification: ScoreClassification.difference,
    );
  }

  if (_sign(predictedDiff) == _sign(actualDiff)) {
    return const ScoreResult(
      points: 2,
      classification: ScoreClassification.tendency,
    );
  }

  return _noScore;
}

ScoreResult scoreTipForMatch({required Tip tip, required CupMatch match}) {
  if (!isTipCompleteForMatch(tip, match)) return _noScore;

  final actualRegularHome = match.regularHomeScore ?? match.homeScore;
  final actualRegularAway = match.regularAwayScore ?? match.awayScore;
  if (actualRegularHome == null || actualRegularAway == null) return _noScore;

  if (!match.isKnockout) {
    return scoreTip(
      predictedHome: tip.predictedHome,
      predictedAway: tip.predictedAway,
      actualHome: actualRegularHome,
      actualAway: actualRegularAway,
    );
  }

  final endedInPenalties = match.penaltyHomeScore != null ||
      match.penaltyAwayScore != null ||
      match.resultNote == 'PENALTY_SHOOTOUT' ||
      match.resultNote == 'n.E.';
  final endedInExtraTime = endedInPenalties ||
      match.otHomeScore != null ||
      match.otAwayScore != null ||
      match.resultNote == 'EXTRA_TIME' ||
      match.resultNote == 'n.V.';

  if (!endedInExtraTime) {
    return _scoreKnockoutRegulation(
      predictedHome: tip.predictedHome,
      predictedAway: tip.predictedAway,
      actualHome: actualRegularHome,
      actualAway: actualRegularAway,
    );
  }

  final actualOtHome = match.otHomeScore;
  final actualOtAway = match.otAwayScore;
  if (actualOtHome == null || actualOtAway == null) return _noScore;

  var points = 0;
  final details = <String>[];
  final regularExact = tip.predictedHome == actualRegularHome &&
      tip.predictedAway == actualRegularAway;
  final predictedRegularDraw = tip.predictedHome == tip.predictedAway;
  if (predictedRegularDraw && actualRegularHome == actualRegularAway) {
    if (regularExact) {
      points += 3;
      details.add('90 Min. exakt +3');
    } else {
      points += 2;
      details.add('Remis nach 90 Min. +2');
    }
  }

  final predictedOtHome = tip.predictedOtHome;
  final predictedOtAway = tip.predictedOtAway;
  if (predictedOtHome == null || predictedOtAway == null) {
    return ScoreResult(
      points: points,
      classification:
          points > 0 ? ScoreClassification.tendency : ScoreClassification.none,
      details: details,
    );
  }

  final otExact =
      predictedOtHome == actualOtHome && predictedOtAway == actualOtAway;
  final otTendency = _sign(predictedOtHome - predictedOtAway) ==
      _sign(actualOtHome - actualOtAway);

  if (!endedInPenalties) {
    if (otExact) {
      points += 2;
      details.add('n.V. exakt +2');
    } else if (otTendency) {
      points += 1;
      details.add('Tendenz n.V. +1');
    }
    final fullyExact = regularExact && otExact;
    return ScoreResult(
      points: points,
      classification: fullyExact
          ? ScoreClassification.exact
          : (points > 0
              ? ScoreClassification.tendency
              : ScoreClassification.none),
      details: details,
    );
  }

  if (otTendency) {
    points += 1;
    details.add('Remis n.V. +1');
  }
  if (otExact) {
    points += 1;
    details.add('n.V. exakt +1');
  }
  final actualPenaltyWinner = _penaltyWinnerForMatch(match);
  final penaltyWinnerExact = tip.predictedPenaltyWinner != null &&
      tip.predictedPenaltyWinner == actualPenaltyWinner;
  if (penaltyWinnerExact) {
    points += 1;
    details.add('Sieger i.E. +1');
  }

  final fullyExact = regularExact && otExact && penaltyWinnerExact;
  return ScoreResult(
    points: points,
    classification: fullyExact
        ? ScoreClassification.exact
        : (points > 0
            ? ScoreClassification.tendency
            : ScoreClassification.none),
    details: details,
  );
}

ScoreResult scoreLiveTip({required Tip tip, required CupMatch match}) {
  if (!isTipCompleteForMatch(tip, match)) return _noScore;
  final actualHome = match.regularHomeScore ?? match.homeScore ?? 0;
  final actualAway = match.regularAwayScore ?? match.awayScore ?? 0;
  if (!match.isKnockout) {
    return scoreTip(
      predictedHome: tip.predictedHome,
      predictedAway: tip.predictedAway,
      actualHome: actualHome,
      actualAway: actualAway,
    );
  }
  if (actualHome == actualAway) {
    if (tip.predictedHome != tip.predictedAway) return _noScore;
    if (tip.predictedHome == actualHome && tip.predictedAway == actualAway) {
      return const ScoreResult(
        points: 3,
        classification: ScoreClassification.exact,
        details: ['90 Min. exakt +3'],
      );
    }
    return const ScoreResult(
      points: 2,
      classification: ScoreClassification.tendency,
      details: ['Remis nach 90 Min. +2'],
    );
  }
  return _scoreKnockoutRegulation(
    predictedHome: tip.predictedHome,
    predictedAway: tip.predictedAway,
    actualHome: actualHome,
    actualAway: actualAway,
  );
}

bool isTipSelectionComplete({
  required CupMatch match,
  required int home,
  required int away,
  int? otHome,
  int? otAway,
  PenaltyWinnerSide? penaltyWinner,
}) {
  if (!match.isKnockout || home != away) return true;
  if (otHome == null || otAway == null || otHome < home || otAway < away) {
    return false;
  }
  if (otHome != otAway) return true;
  return penaltyWinner != null;
}

bool isTipCompleteForMatch(Tip tip, CupMatch match) {
  if (!tip.isComplete) return false;
  return isTipSelectionComplete(
    match: match,
    home: tip.predictedHome,
    away: tip.predictedAway,
    otHome: tip.predictedOtHome,
    otAway: tip.predictedOtAway,
    penaltyWinner: tip.predictedPenaltyWinner,
  );
}

ScoreResult _scoreKnockoutRegulation({
  required int predictedHome,
  required int predictedAway,
  required int actualHome,
  required int actualAway,
}) {
  if (predictedHome == actualHome && predictedAway == actualAway) {
    return const ScoreResult(
      points: 5,
      classification: ScoreClassification.exact,
      details: ['90 Min. exakt +5'],
    );
  }
  final predictedDiff = predictedHome - predictedAway;
  final actualDiff = actualHome - actualAway;
  if (predictedDiff == actualDiff && actualDiff != 0) {
    return const ScoreResult(
      points: 4,
      classification: ScoreClassification.difference,
      details: ['Tordifferenz nach 90 Min. +4'],
    );
  }
  if (_sign(predictedDiff) == _sign(actualDiff)) {
    return const ScoreResult(
      points: 3,
      classification: ScoreClassification.tendency,
      details: ['Tendenz nach 90 Min. +3'],
    );
  }
  return _noScore;
}

PenaltyWinnerSide? _penaltyWinnerForMatch(CupMatch match) {
  final penaltyHome = match.penaltyHomeScore;
  final penaltyAway = match.penaltyAwayScore;
  if (penaltyHome != null && penaltyAway != null) {
    if (penaltyHome > penaltyAway) return PenaltyWinnerSide.home;
    if (penaltyAway > penaltyHome) return PenaltyWinnerSide.away;
  }
  if (match.winner != null) {
    if (isSameTeam(match.winner!, match.homeTeam)) {
      return PenaltyWinnerSide.home;
    }
    if (isSameTeam(match.winner!, match.awayTeam)) {
      return PenaltyWinnerSide.away;
    }
  }
  return null;
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
          tipPoints: current.tipPoints,
          exactCount: current.exactCount,
          differenceCount: current.differenceCount,
          tendencyCount: current.tendencyCount,
          rank: rank,
          photoUrl: current.photoUrl,
          favoriteTeam: current.favoriteTeam,
          predictedChampion: current.predictedChampion,
        );
      }(),
  ];
}

int _sign(int value) {
  if (value > 0) return 1;
  if (value < 0) return -1;
  return 0;
}

String _teamKey(String value) {
  var key = value.toLowerCase().trim();

  // Replace diacritics and special characters
  key = key.replaceAll('&', 'und');

  const diacritics = {
    'ä': 'a',
    'ö': 'o',
    'ü': 'u',
    'ß': 'ss',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ć': 'c',
    'š': 's',
    'ž': 'z',
  };

  diacritics.forEach((char, replacement) {
    key = key.replaceAll(char, replacement);
  });

  // Remove everything except a-z0-9
  key = key.replaceAll(RegExp(r'[^a-z0-9]'), '');

  const teamAliases = {
    'qatar': 'katar',
    'switzerland': 'schweiz',
    'brazil': 'brasilien',
    'morocco': 'marokko',
    'haiti': 'haiti',
    'scotland': 'schottland',
    'australia': 'australien',
    'turkiye': 'turkei',
    'turkey': 'turkei',
    'germany': 'deutschland',
    'curacao': 'curacao',
    'netherlands': 'niederlande',
    'japan': 'japan',
    'coteivoire': 'elfenbeinkuste',
    'cotedivoire': 'elfenbeinkuste',
    'ivorycoast': 'elfenbeinkuste',
    'ecuador': 'ecuador',
    'sweden': 'schweden',
    'tunisia': 'tunesien',
    'spain': 'spanien',
    'capeverde': 'kapverde',
    'capeverdeislands': 'kapverde',
    'belgium': 'belgien',
    'egypt': 'agypten',
    'saudiarabia': 'saudiarabien',
    'uruguay': 'uruguay',
    'iran': 'iran',
    'newzealand': 'neuseeland',
    'france': 'frankreich',
    'senegal': 'senegal',
    'iraq': 'irak',
    'norway': 'norwegen',
    'argentina': 'argentinien',
    'algeria': 'algerien',
    'austria': 'osterreich',
    'jordan': 'jordanien',
    'portugal': 'portugal',
    'drcongo': 'drkongo',
    'congodr': 'drkongo',
    'england': 'england',
    'croatia': 'kroatien',
    'ghana': 'ghana',
    'panama': 'panama',
    'uzbekistan': 'usbekistan',
    'colombia': 'kolumbien',
    'canada': 'kanada',
    'bosniaherzegovina': 'bosnienherzegowina',
    'bosniaandherzegovina': 'bosnienherzegowina',
    'mexico': 'mexiko',
    'southafrica': 'sudafrika',
    'southkorea': 'sudkorea',
    'korearepublic': 'sudkorea',
    'czechia': 'tschechien',
    'czechrepublic': 'tschechien',
    'unitedstates': 'usa',
    'usa': 'usa',
    'paraguay': 'paraguay',
  };

  return teamAliases[key] ?? key;
}

bool isSameTeam(String a, String b) {
  return _teamKey(a) == _teamKey(b);
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
  if (favorites.any((t) => isSameTeam(t, team))) {
    return 'Absolute Titelfavoriten';
  }
  if (tops.any((t) => isSameTeam(t, team))) {
    return 'Top Team';
  }
  if (mids.any((t) => isSameTeam(t, team))) {
    return 'Durchschnittliches Team';
  }
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

String? getDeepestReachedStage(String team, List<CupMatch> matches) {
  String? deepest;
  for (final match in matches) {
    if (_isGroupStage(match.stage) ||
        (!isSameTeam(match.homeTeam, team) &&
            !isSameTeam(match.awayTeam, team))) {
      continue;
    }

    final stage = match.stage.toLowerCase();
    String? reached;
    if (stage.contains('sechzehntel') || stage.contains('32')) {
      reached = 'Sechzehntelfinale';
    } else if (stage.contains('achtel') || stage.contains('16')) {
      reached = 'Achtelfinale';
    } else if (stage.contains('viertel') || stage.contains('quarter')) {
      reached = 'Viertelfinale';
    } else if (stage.contains('halb') || stage.contains('semi')) {
      reached = 'Halbfinale';
    } else if (stage.contains('final')) {
      reached = 'Finale';
    }

    if (reached != null &&
        (deepest == null || _stageRank(reached) > _stageRank(deepest))) {
      deepest = reached;
    }
    if (reached != null &&
        match.status == MatchStatus.finalResult &&
        getMatchWinner(match) != null &&
        isSameTeam(getMatchWinner(match)!, team)) {
      final nextStage = switch (reached) {
        'Sechzehntelfinale' => 'Achtelfinale',
        'Achtelfinale' => 'Viertelfinale',
        'Viertelfinale' => 'Halbfinale',
        'Halbfinale' => 'Finale',
        _ => null,
      };
      if (nextStage != null &&
          (deepest == null || _stageRank(nextStage) > _stageRank(deepest))) {
        deepest = nextStage;
      }
    }
  }
  return deepest;
}

int? calculateCurrentRiskPoints(
  String team,
  String predictedStage,
  List<CupMatch> matches,
) {
  final actualStage = getEliminationStage(team, matches);
  if (actualStage != null) {
    return calculateRiskPoints(team, predictedStage, actualStage);
  }
  final reachedStage = getDeepestReachedStage(team, matches);
  if (reachedStage != null &&
      _stageRank(reachedStage) > _stageRank(predictedStage)) {
    return calculateRiskPoints(team, predictedStage, reachedStage);
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
    extraPoints += calculateCurrentRiskPoints(rTeam, rStage, matches) ?? 0;
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
      isSameTeam(favoriteTeam, winner)) {
    total += 10;
  }
  if (winner != null &&
      predictedChampion != null &&
      isSameTeam(predictedChampion, winner)) {
    total += 10;
  }
  return total;
}

String getEvaluationLabel({
  required int tipPoints,
  required String? favoriteTeam,
  required String? predictedChampion,
  required CupMatch match,
  ScoreResult? scoreResult,
}) {
  final winner = getMatchWinner(match);
  final isFavWin = winner != null &&
      favoriteTeam != null &&
      isSameTeam(favoriteTeam, winner);
  final isChampWin = winner != null &&
      predictedChampion != null &&
      isSameTeam(predictedChampion, winner);

  final baseLabel = match.isKnockout
      ? (scoreResult?.details.isNotEmpty == true
          ? scoreResult!.details.join('\n')
          : '$tipPoints Tipp-Punkte')
      : tipPoints == 4
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

String? getLiveMatchWinner(CupMatch match) {
  if (match.winner != null && match.winner!.isNotEmpty) {
    return match.winner;
  }
  final hs = match.homeScore;
  final as = match.awayScore;
  if (hs == null || as == null) return null;
  if (hs > as) return match.homeTeam;
  if (as > hs) return match.awayTeam;
  return null;
}

int getLiveMatchTotalPoints({
  required int tipPoints,
  required String? favoriteTeam,
  required String? predictedChampion,
  required CupMatch match,
}) {
  final winner = getLiveMatchWinner(match);
  var total = tipPoints;
  if (winner != null &&
      favoriteTeam != null &&
      isSameTeam(favoriteTeam, winner)) {
    total += 10;
  }
  if (winner != null &&
      predictedChampion != null &&
      isSameTeam(predictedChampion, winner)) {
    total += 10;
  }
  return total;
}

String getLiveEvaluationLabel({
  required int tipPoints,
  required String? favoriteTeam,
  required String? predictedChampion,
  required CupMatch match,
  ScoreResult? scoreResult,
}) {
  final winner = getLiveMatchWinner(match);
  final isFavWin = winner != null &&
      favoriteTeam != null &&
      isSameTeam(favoriteTeam, winner);
  final isChampWin = winner != null &&
      predictedChampion != null &&
      isSameTeam(predictedChampion, winner);

  final baseLabel = match.isKnockout
      ? (scoreResult?.details.isNotEmpty == true
          ? scoreResult!.details.join('\n')
          : '$tipPoints Tipp-Punkte')
      : tipPoints == 4
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
