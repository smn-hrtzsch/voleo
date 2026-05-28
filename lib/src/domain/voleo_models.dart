enum MatchStatus { scheduled, live, finalResult }

enum MemberRole { owner, member }

class VoleoUser {
  const VoleoUser({
    required this.uid,
    required this.nickname,
    this.email,
  });

  final String uid;
  final String nickname;
  final String? email;
}

class League {
  const League({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUid,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String ownerUid;
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
    required this.status,
    this.homeScore,
    this.awayScore,
    this.source = 'openligadb',
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final DateTime kickoff;
  final String stage;
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;
  final String source;

  bool get isLocked => DateTime.now().isAfter(kickoff);

  CupMatch copyWith({
    MatchStatus? status,
    int? homeScore,
    int? awayScore,
  }) {
    return CupMatch(
      id: id,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      kickoff: kickoff,
      stage: stage,
      status: status ?? this.status,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      source: source,
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
  });

  final String uid;
  final String matchId;
  final int predictedHome;
  final int predictedAway;
  final DateTime lockedAt;
  final int points;

  Tip copyWith({int? predictedHome, int? predictedAway, int? points}) {
    return Tip(
      uid: uid,
      matchId: matchId,
      predictedHome: predictedHome ?? this.predictedHome,
      predictedAway: predictedAway ?? this.predictedAway,
      lockedAt: lockedAt,
      points: points ?? this.points,
    );
  }
}

class Standing {
  const Standing({
    required this.uid,
    required this.displayName,
    required this.totalPoints,
    required this.exactCount,
    required this.tendencyCount,
    required this.rank,
  });

  final String uid;
  final String displayName;
  final int totalPoints;
  final int exactCount;
  final int tendencyCount;
  final int rank;
}
