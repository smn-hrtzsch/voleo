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
        );
      }(),
  ];
}

int _sign(int value) {
  if (value > 0) return 1;
  if (value < 0) return -1;
  return 0;
}
