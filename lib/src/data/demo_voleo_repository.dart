import 'dart:async';

import 'package:uuid/uuid.dart';

import '../domain/scoring.dart';
import '../domain/voleo_models.dart';
import 'voleo_repository.dart';

class DemoVoleoRepository implements VoleoRepository {
  DemoVoleoRepository() {
    _recomputeStandings();
  }

  static const _uuid = Uuid();

  final _user = StreamController<VoleoUser?>.broadcast();
  final _league = StreamController<League?>.broadcast();
  final _matches = StreamController<List<CupMatch>>.broadcast();
  final _tips = StreamController<List<Tip>>.broadcast();
  final _standings = StreamController<List<Standing>>.broadcast();

  VoleoUser? _currentUser;
  League? _currentLeague;
  final List<Tip> _currentTips = [];
  final List<LeagueMember> _members = [
    const LeagueMember(
      uid: 'demo-ana',
      displayName: 'Ana',
      role: MemberRole.member,
      totalPoints: 7,
    ),
    const LeagueMember(
      uid: 'demo-max',
      displayName: 'Max',
      role: MemberRole.member,
      totalPoints: 5,
    ),
  ];

  final List<CupMatch> _currentMatches = [
    CupMatch(
      id: 'wc2026-001',
      homeTeam: 'Mexiko',
      awayTeam: 'Suedafrika',
      kickoff: DateTime(2026, 6, 11, 21),
      stage: 'Gruppenphase',
      status: MatchStatus.scheduled,
    ),
    CupMatch(
      id: 'wc2026-002',
      homeTeam: 'Kanada',
      awayTeam: 'TBD',
      kickoff: DateTime(2026, 6, 12, 3),
      stage: 'Gruppenphase',
      status: MatchStatus.scheduled,
    ),
    CupMatch(
      id: 'wc2026-003',
      homeTeam: 'USA',
      awayTeam: 'TBD',
      kickoff: DateTime(2026, 6, 12, 21),
      stage: 'Gruppenphase',
      status: MatchStatus.scheduled,
    ),
  ];

  @override
  Stream<VoleoUser?> watchUser() {
    Future.microtask(() => _user.add(_currentUser));
    return _user.stream;
  }

  @override
  Stream<League?> watchLeague() {
    Future.microtask(() => _league.add(_currentLeague));
    return _league.stream;
  }

  @override
  Stream<List<CupMatch>> watchMatches() {
    Future.microtask(() => _matches.add(List.unmodifiable(_currentMatches)));
    return _matches.stream;
  }

  @override
  Stream<List<Tip>> watchTips() {
    Future.microtask(() => _tips.add(List.unmodifiable(_currentTips)));
    return _tips.stream;
  }

  @override
  Stream<List<Standing>> watchStandings() {
    Future.microtask(_recomputeStandings);
    return _standings.stream;
  }

  @override
  Future<void> startSession({
    required String nickname,
    String? inviteCode,
  }) async {
    final uid = _currentUser?.uid ?? _uuid.v4();
    _currentUser = VoleoUser(uid: uid, nickname: nickname);
    _upsertMember(uid: uid, displayName: nickname, role: MemberRole.owner);
    _currentLeague = League(
      id: 'league-${inviteCode ?? 'demo'}',
      name: inviteCode == null ? 'Meine WM-Runde' : 'WM-Runde $inviteCode',
      inviteCode: inviteCode?.toUpperCase() ?? 'VOLEO26',
      ownerUid: uid,
    );
    _emitAll();
  }

  @override
  Future<void> createLeague({required String name}) async {
    final user = _requireUser();
    _currentLeague = League(
      id: _uuid.v4(),
      name: name,
      inviteCode: _createInviteCode(name),
      ownerUid: user.uid,
    );
    _emitAll();
  }

  @override
  Future<void> joinLeague({required String inviteCode}) async {
    final user = _requireUser();
    _currentLeague = League(
      id: 'league-${inviteCode.toUpperCase()}',
      name: 'WM-Runde ${inviteCode.toUpperCase()}',
      inviteCode: inviteCode.toUpperCase(),
      ownerUid: user.uid,
    );
    _emitAll();
  }

  @override
  Future<void> saveTip({
    required String matchId,
    required int home,
    required int away,
  }) async {
    final user = _requireUser();
    final match = _currentMatches.firstWhere((match) => match.id == matchId);
    if (!canEditTip(match, DateTime.now())) {
      throw StateError('Tipps sind ab Anpfiff gesperrt.');
    }

    final existingIndex = _currentTips.indexWhere(
      (tip) => tip.uid == user.uid && tip.matchId == matchId,
    );
    final tip = Tip(
      uid: user.uid,
      matchId: matchId,
      predictedHome: home,
      predictedAway: away,
      lockedAt: match.kickoff,
      points: 0,
    );
    if (existingIndex == -1) {
      _currentTips.add(tip);
    } else {
      _currentTips[existingIndex] = tip;
    }
    _emitAll();
  }

  @override
  Future<void> linkEmail(String email) async {
    final user = _requireUser();
    _currentUser = VoleoUser(
      uid: user.uid,
      nickname: user.nickname,
      email: email,
    );
    _emitAll();
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _currentLeague = null;
    _currentTips.clear();
    _emitAll();
  }

  VoleoUser _requireUser() {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Keine aktive Sitzung.');
    }
    return user;
  }

  void _upsertMember({
    required String uid,
    required String displayName,
    required MemberRole role,
  }) {
    _members.removeWhere((member) => member.uid == uid);
    _members.add(
      LeagueMember(
        uid: uid,
        displayName: displayName,
        role: role,
        totalPoints: 0,
      ),
    );
  }

  void _emitAll() {
    _user.add(_currentUser);
    _league.add(_currentLeague);
    _matches.add(List.unmodifiable(_currentMatches));
    _tips.add(List.unmodifiable(_currentTips));
    _recomputeStandings();
  }

  void _recomputeStandings() {
    final standingSeeds = <Standing>[
      const Standing(
        uid: 'demo-ana',
        displayName: 'Ana',
        totalPoints: 7,
        exactCount: 1,
        tendencyCount: 2,
        rank: 1,
      ),
      const Standing(
        uid: 'demo-max',
        displayName: 'Max',
        totalPoints: 5,
        exactCount: 0,
        tendencyCount: 3,
        rank: 2,
      ),
    ];

    final user = _currentUser;
    if (user != null) {
      var total = 0;
      var exact = 0;
      var tendency = 0;
      for (final tip in _currentTips) {
        final match =
            _currentMatches.firstWhere((match) => match.id == tip.matchId);
        if (match.status != MatchStatus.finalResult ||
            match.homeScore == null ||
            match.awayScore == null) {
          continue;
        }
        final result = scoreTip(
          predictedHome: tip.predictedHome,
          predictedAway: tip.predictedAway,
          actualHome: match.homeScore!,
          actualAway: match.awayScore!,
        );
        total += result.points;
        if (result.isExact) exact++;
        if (result.isTendency) tendency++;
      }
      standingSeeds.add(
        Standing(
          uid: user.uid,
          displayName: user.nickname,
          totalPoints: total,
          exactCount: exact,
          tendencyCount: tendency,
          rank: 0,
        ),
      );
    }

    _standings.add(rankStandings(standingSeeds));
  }

  String _createInviteCode(String name) {
    final normalized =
        name.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '').padRight(4, 'X');
    return '${normalized.substring(0, 4)}26';
  }
}
