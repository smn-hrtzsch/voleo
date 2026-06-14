import 'clock.dart';

enum MatchStatus { scheduled, live, finalResult }

enum MemberRole { owner, member }

class OfficialTables {
  const OfficialTables({
    this.teams = const [],
    this.groups = const {},
    this.fairPlayScores = const {},
  });

  final List<String> teams;
  final Map<String, List<OfficialTeamStanding>> groups;
  final Map<String, int> fairPlayScores;

  bool get hasGroups => groups.isNotEmpty;
  bool get hasFairPlayScores => fairPlayScores.isNotEmpty;
}

class OfficialTeamStanding {
  const OfficialTeamStanding({
    required this.position,
    required this.team,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  final int position;
  final String team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;
}

class VoleoUser {
  const VoleoUser({
    required this.uid,
    required this.nickname,
    required this.isAnonymous,
    this.photoUrl,
    this.email,
    this.providerIds = const [],
    this.favoriteTeam,
    this.predictedChampion,
    this.riskTeam,
    this.riskStage,
    this.themeModeName,
  });

  final String uid;
  final String nickname;
  final bool isAnonymous;
  final String? photoUrl;
  final String? email;
  final List<String> providerIds;
  final String? favoriteTeam;
  final String? predictedChampion;
  final String? riskTeam;
  final String? riskStage;
  final String? themeModeName;

  bool get hasGoogleProvider => providerIds.contains('google.com');
  bool get hasAppleProvider => providerIds.contains('apple.com');
  bool get hasLinkedProvider => providerIds.isNotEmpty;
}

class League {
  const League({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUid,
    this.imageUrl,
    this.isActive = false,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String ownerUid;
  final String? imageUrl;
  final bool isActive;
}

class LeagueMember {
  const LeagueMember({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.totalPoints,
  });

  final String uid;
  final String displayName;
  final MemberRole role;
  final int totalPoints;
}

class CupMatch {
  const CupMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoff,
    required this.stage,
    required this.group,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.winner,
    this.resultNote,
    this.source = 'openligadb',
    this.regularHomeScore,
    this.regularAwayScore,
    this.otHomeScore,
    this.otAwayScore,
    this.penaltyHomeScore,
    this.penaltyAwayScore,
    this.originalId,
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime kickoff;
  final String stage;
  final String group;
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;
  final String? winner;
  final String? resultNote;
  final String source;
  final int? regularHomeScore;
  final int? regularAwayScore;
  final int? otHomeScore;
  final int? otAwayScore;
  final int? penaltyHomeScore;
  final int? penaltyAwayScore;
  final String? originalId;

  bool get isLocked => VoleoClock.now.isAfter(kickoff);

  CupMatch copyWith({
    String? id,
    MatchStatus? status,
    int? homeScore,
    int? awayScore,
    String? winner,
    String? resultNote,
    int? regularHomeScore,
    int? regularAwayScore,
    int? otHomeScore,
    int? otAwayScore,
    int? penaltyHomeScore,
    int? penaltyAwayScore,
    String? originalId,
  }) {
    return CupMatch(
      id: id ?? this.id,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      kickoff: kickoff,
      stage: stage,
      group: group,
      status: status ?? this.status,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      winner: winner ?? this.winner,
      resultNote: resultNote ?? this.resultNote,
      source: source,
      regularHomeScore: regularHomeScore ?? this.regularHomeScore,
      regularAwayScore: regularAwayScore ?? this.regularAwayScore,
      otHomeScore: otHomeScore ?? this.otHomeScore,
      otAwayScore: otAwayScore ?? this.otAwayScore,
      penaltyHomeScore: penaltyHomeScore ?? this.penaltyHomeScore,
      penaltyAwayScore: penaltyAwayScore ?? this.penaltyAwayScore,
      originalId: originalId ?? this.originalId,
    );
  }
}

class Tip {
  const Tip({
    required this.uid,
    required this.matchId,
    required this.predictedHome,
    required this.predictedAway,
    required this.lockedAt,
    required this.points,
    this.updatedAt,
  });

  final String uid;
  final String matchId;
  final int predictedHome;
  final int predictedAway;
  final DateTime lockedAt;
  final int points;
  final DateTime? updatedAt;

  Tip copyWith({int? predictedHome, int? predictedAway, int? points}) {
    return Tip(
      uid: uid,
      matchId: matchId,
      predictedHome: predictedHome ?? this.predictedHome,
      predictedAway: predictedAway ?? this.predictedAway,
      lockedAt: lockedAt,
      points: points ?? this.points,
      updatedAt: updatedAt,
    );
  }
}

class Standing {
  const Standing({
    required this.uid,
    required this.displayName,
    required this.totalPoints,
    required this.exactCount,
    required this.differenceCount,
    required this.tendencyCount,
    required this.rank,
    this.photoUrl,
    this.favoriteTeam,
    this.predictedChampion,
  });

  final String uid;
  final String displayName;
  final int totalPoints;
  final int exactCount;
  final int differenceCount;
  final int tendencyCount;
  final int rank;
  final String? photoUrl;
  final String? favoriteTeam;
  final String? predictedChampion;
}
