import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../domain/scoring.dart';
import '../domain/voleo_models.dart';
import '../domain/clock.dart';
import 'voleo_repository.dart';
import 'wc2026_group_stage.dart';

class LocalFirstVoleoRepository implements VoleoRepository {
  LocalFirstVoleoRepository() {
    _currentMatches = buildWc2026GroupStageMatches();
    unawaited(_loadFromDisk());
    unawaited(_refreshMatchesFromApi());
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(_refreshMatchesFromApi()),
    );
  }

  static const _uuid = Uuid();
  static final _openLigaDbUri =
      Uri.parse('https://api.openligadb.de/getmatchdata/wm2026/2026');

  final _user = StreamController<VoleoUser?>.broadcast();
  final _league = StreamController<League?>.broadcast();
  final _matches = StreamController<List<CupMatch>>.broadcast();
  final _tips = StreamController<List<Tip>>.broadcast();
  final _standings = StreamController<List<Standing>>.broadcast();
  Timer? _refreshTimer;

  VoleoUser? _currentUser;
  League? _currentLeague;
  List<CupMatch> _currentMatches = const [];
  final List<Tip> _currentTips = [];
  final List<LeagueMember> _members = [];

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
  Stream<List<League>> watchLeagues() {
    Future.microtask(() => _league.add(_currentLeague));
    return _league.stream.map((league) {
      if (league == null) return const <League>[];
      return [
        League(
          id: league.id,
          name: league.name,
          inviteCode: league.inviteCode,
          ownerUid: league.ownerUid,
          imageUrl: league.imageUrl,
          isActive: true,
        ),
      ];
    });
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
  Stream<List<Tip>> watchLeagueTips() {
    Future.microtask(() => _tips.add(List.unmodifiable(_currentTips)));
    return _tips.stream;
  }

  @override
  Stream<List<Standing>> watchStandings() {
    Future.microtask(_recomputeStandings);
    return _standings.stream;
  }

  @override
  Stream<List<String>> watchOfficialTable() {
    return Stream.value(const <String>[]);
  }

  @override
  Future<void> startSession({
    required String nickname,
    String? inviteCode,
  }) async {
    final uid = _currentUser?.uid ?? _uuid.v4();
    _currentUser = VoleoUser(
      uid: uid,
      nickname: nickname,
      isAnonymous: true,
    );
    _upsertMember(uid: uid, displayName: nickname, role: MemberRole.owner);
    _currentLeague = League(
      id: 'league-${inviteCode ?? 'demo'}',
      name: inviteCode == null ? 'Meine WM-Runde' : 'WM-Runde $inviteCode',
      inviteCode: inviteCode?.toUpperCase() ?? _createInviteCode(),
      ownerUid: uid,
    );
    await _persist();
    _emitAll();
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> signInWithCredential(auth.AuthCredential credential) async {}

  @override
  Future<void> linkWithGoogle() async {}

  @override
  Future<void> linkWithApple() async {}

  @override
  Future<void> unlinkProvider(String providerId) async {}

  @override
  Future<void> updateProfile({
    String? nickname,
    String? photoUrl,
  }) async {
    final user = _requireUser();
    if (nickname != null) {
      final normalized = _normalizeName(nickname);
      for (final member in _members) {
        if (member.uid == user.uid) continue;
        if (_normalizeName(member.displayName) == normalized) {
          throw StateError('Dieser Name ist in der Liga bereits vergeben.');
        }
      }
    }
    _currentUser = VoleoUser(
      uid: user.uid,
      nickname: nickname ?? user.nickname,
      isAnonymous: user.isAnonymous,
      photoUrl: photoUrl ?? user.photoUrl,
      email: user.email,
      providerIds: user.providerIds,
      favoriteTeam: user.favoriteTeam,
      predictedChampion: user.predictedChampion,
      riskTeam: user.riskTeam,
      riskStage: user.riskStage,
      themeModeName: user.themeModeName,
    );
    if (nickname != null) {
      _upsertMember(
        uid: user.uid,
        displayName: nickname,
        role: MemberRole.owner,
      );
    }
    await _persist();
    _emitAll();
  }

  @override
  Future<void> updateThemeMode(String modeName) async {}

  @override
  Future<void> uploadProfileImage(String filePath) async {
    await updateProfile(photoUrl: filePath);
  }

  @override
  Future<void> createLeague({required String name}) async {
    final user = _requireUser();
    _currentLeague = League(
      id: _uuid.v4(),
      name: name,
      inviteCode: _createInviteCode(),
      ownerUid: user.uid,
    );
    await _persist();
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
    await _persist();
    _emitAll();
  }

  @override
  Future<void> switchLeague({required String leagueId}) async {
    if (_currentLeague?.id != leagueId) {
      throw StateError('Diese Tipprunde ist lokal nicht vorhanden.');
    }
    _emitAll();
  }

  @override
  Future<void> leaveLeague({required String leagueId}) async {
    _emitAll();
  }

  @override
  Future<void> renameLeague({required String name}) async {
    final league = _currentLeague;
    if (league == null) throw StateError('Keine aktive Tipprunde.');
    _currentLeague = League(
      id: league.id,
      name: name.trim(),
      inviteCode: league.inviteCode,
      ownerUid: league.ownerUid,
      imageUrl: league.imageUrl,
      isActive: true,
    );
    await _persist();
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
    if (!canEditTip(match, VoleoClock.now)) {
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
    await _persist();
    _emitAll();
  }

  @override
  Future<void> deleteTip({required String matchId}) async {
    final user = _requireUser();
    final match = _currentMatches.firstWhere((match) => match.id == matchId);
    if (!canEditTip(match, VoleoClock.now)) {
      throw StateError('Tipps können ab Anpfiff nicht mehr gelöscht werden.');
    }
    _currentTips.removeWhere(
      (tip) => tip.uid == user.uid && tip.matchId == matchId,
    );
    await _persist();
    _emitAll();
  }

  @override
  Future<void> linkEmail(String email) async {
    final user = _requireUser();
    _currentUser = VoleoUser(
      uid: user.uid,
      nickname: user.nickname,
      isAnonymous: user.isAnonymous,
      photoUrl: user.photoUrl,
      email: email,
      providerIds: user.providerIds,
    );
    await _persist();
    _emitAll();
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _currentLeague = null;
    _currentTips.clear();
    _members.clear();
    await _persist();
    _emitAll();
  }

  @override
  Future<void> deleteAccount() async {
    _currentUser = null;
    _currentLeague = null;
    _currentTips.clear();
    _members.clear();
    await _persist();
    _emitAll();
  }

  void dispose() {
    _refreshTimer?.cancel();
    _user.close();
    _league.close();
    _matches.close();
    _tips.close();
    _standings.close();
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
    final standingSeeds = <Standing>[];
    final user = _currentUser;
    if (user != null) {
      var total = 0;
      var exact = 0;
      var difference = 0;
      var tendency = 0;
      for (final tip in _currentTips) {
        final match =
            _currentMatches.firstWhere((match) => match.id == tip.matchId);
        final actualHome = match.regularHomeScore ?? match.homeScore;
        final actualAway = match.regularAwayScore ?? match.awayScore;
        if (match.status != MatchStatus.finalResult ||
            actualHome == null ||
            actualAway == null) {
          continue;
        }
        final result = scoreTip(
          predictedHome: tip.predictedHome,
          predictedAway: tip.predictedAway,
          actualHome: actualHome,
          actualAway: actualAway,
        );
        total += result.points;
        if (result.isExact) exact++;
        if (result.points == 3) difference++;
        if (result.isTendency) tendency++;
      }
      final extraPoints = calculateExtraPoints(user, _currentMatches);
      total += extraPoints;
      standingSeeds.add(
        Standing(
          uid: user.uid,
          displayName: user.nickname,
          totalPoints: total,
          exactCount: exact,
          differenceCount: difference,
          tendencyCount: tendency,
          rank: 0,
          photoUrl: user.photoUrl,
        ),
      );
    }

    _standings.add(rankStandings(standingSeeds));
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _storeFile();
      final legacyFile = await _legacyStoreFile();
      final sourceFile = await file.exists() ? file : legacyFile;
      if (!await sourceFile.exists()) {
        _emitAll();
        return;
      }
      final decoded = jsonDecode(await sourceFile.readAsString());
      if (decoded is! Map<String, Object?>) return;

      final userJson = decoded['user'];
      if (userJson is Map<String, Object?>) {
        _currentUser = VoleoUser(
          uid: userJson['uid'] as String,
          nickname: userJson['nickname'] as String,
          isAnonymous: userJson['isAnonymous'] as bool? ?? true,
          photoUrl: userJson['photoUrl'] as String?,
          email: userJson['email'] as String?,
          providerIds: (userJson['providerIds'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              const [],
          favoriteTeam: userJson['favoriteTeam'] as String?,
          predictedChampion: userJson['predictedChampion'] as String?,
          riskTeam: userJson['riskTeam'] as String?,
          riskStage: userJson['riskStage'] as String?,
        );
        _upsertMember(
          uid: _currentUser!.uid,
          displayName: _currentUser!.nickname,
          role: MemberRole.owner,
        );
      }

      final leagueJson = decoded['league'];
      if (leagueJson is Map<String, Object?>) {
        _currentLeague = League(
          id: leagueJson['id'] as String,
          name: leagueJson['name'] as String,
          inviteCode: leagueJson['inviteCode'] as String,
          ownerUid: leagueJson['ownerUid'] as String,
          imageUrl: leagueJson['imageUrl'] as String?,
        );
      }

      final tipsJson = decoded['tips'];
      if (tipsJson is List) {
        _currentTips
          ..clear()
          ..addAll(
              tipsJson.whereType<Map<String, Object?>>().map(_tipFromJson));
      }
      if (sourceFile.path != file.path) {
        await _persist();
      }
      _emitAll();
    } catch (_) {
      _emitAll();
    }
  }

  Future<void> _persist() async {
    final file = await _storeFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'user': _currentUser == null
            ? null
            : {
                'uid': _currentUser!.uid,
                'nickname': _currentUser!.nickname,
                'isAnonymous': _currentUser!.isAnonymous,
                'photoUrl': _currentUser!.photoUrl,
                'email': _currentUser!.email,
                'providerIds': _currentUser!.providerIds,
                'favoriteTeam': _currentUser!.favoriteTeam,
                'predictedChampion': _currentUser!.predictedChampion,
                'riskTeam': _currentUser!.riskTeam,
                'riskStage': _currentUser!.riskStage,
              },
        'league': _currentLeague == null
            ? null
            : {
                'id': _currentLeague!.id,
                'name': _currentLeague!.name,
                'inviteCode': _currentLeague!.inviteCode,
                'ownerUid': _currentLeague!.ownerUid,
                'imageUrl': _currentLeague!.imageUrl,
              },
        'tips': _currentTips.map(_tipToJson).toList(),
      }),
    );
  }

  Future<File> _storeFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/voleo_local_store.json');
    } catch (_) {
      return File('${Directory.systemTemp.path}/voleo_local_store.json');
    }
  }

  Future<File> _legacyStoreFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/voleo_demo_store.json');
    } catch (_) {
      return File('${Directory.systemTemp.path}/voleo_demo_store.json');
    }
  }

  Future<void> _refreshMatchesFromApi() async {
    try {
      final response = await http.get(_openLigaDbUri);
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return;
      final apiMatches = decoded
          .whereType<Map<String, Object?>>()
          .map(_matchFromOpenLigaDb)
          .nonNulls
          .toList()
        ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

      if (apiMatches.isNotEmpty) {
        _currentMatches = _mergeApiMatches(_currentMatches, apiMatches);
      }
      _emitAll();
    } catch (_) {
      // The bundled fixture list remains usable when the live API is offline.
    }
  }

  List<CupMatch> _mergeApiMatches(
    List<CupMatch> seeds,
    List<CupMatch> apiMatches,
  ) {
    return [
      for (final seed in seeds) _mergeApiMatch(seed, apiMatches),
    ]..sort((a, b) => a.kickoff.compareTo(b.kickoff));
  }

  CupMatch _mergeApiMatch(CupMatch seed, List<CupMatch> apiMatches) {
    for (final apiMatch in apiMatches) {
      if (_sameFixture(apiMatch, seed)) {
        return seed.copyWith(
          status: apiMatch.status,
          homeScore: apiMatch.homeScore,
          awayScore: apiMatch.awayScore,
        );
      }
    }
    return seed;
  }

  bool _sameFixture(CupMatch apiMatch, CupMatch seed) {
    final sameTeams = _teamKey(apiMatch.homeTeam) == _teamKey(seed.homeTeam) &&
        _teamKey(apiMatch.awayTeam) == _teamKey(seed.awayTeam);
    final sameDay = apiMatch.kickoff.year == seed.kickoff.year &&
        apiMatch.kickoff.month == seed.kickoff.month &&
        apiMatch.kickoff.day == seed.kickoff.day;
    return sameTeams && sameDay;
  }

  CupMatch? _matchFromOpenLigaDb(Map<String, Object?> match) {
    final id = match['matchID'] ?? match['matchId'];
    final team1 = match['team1'];
    final team2 = match['team2'];
    if (id == null ||
        team1 is! Map<String, Object?> ||
        team2 is! Map<String, Object?>) {
      return null;
    }

    final homeTeam = team1['teamName'] as String?;
    final awayTeam = team2['teamName'] as String?;
    final kickoffRaw = match['matchDateTimeUTC'] as String? ??
        match['matchDateTime'] as String?;
    if (homeTeam == null ||
        awayTeam == null ||
        kickoffRaw == null ||
        homeTeam.isEmpty ||
        awayTeam.isEmpty ||
        homeTeam.toUpperCase() == 'TBD' ||
        awayTeam.toUpperCase() == 'TBD') {
      return null;
    }

    final groupName = _groupName(match['group']);
    final finalResult = _finalResult(match['matchResults']);
    return CupMatch(
      id: 'openligadb-$id',
      homeTeam: _germanTeamName(homeTeam),
      awayTeam: _germanTeamName(awayTeam),
      kickoff: DateTime.parse(kickoffRaw).toLocal(),
      stage: 'Gruppenphase',
      group: groupName ?? '',
      status:
          finalResult == null ? MatchStatus.scheduled : MatchStatus.finalResult,
      homeScore: finalResult?.$1,
      awayScore: finalResult?.$2,
      source: 'openligadb',
    );
  }

  String? _groupName(Object? group) {
    if (group is! Map<String, Object?>) return null;
    final raw = group['groupName'] as String?;
    if (raw == null) return null;
    final match = RegExp(r'([A-L])$').firstMatch(raw.trim());
    return match?.group(1) ??
        raw.replaceAll('Group ', '').replaceAll('Gruppe ', '');
  }

  (int, int)? _finalResult(Object? results) {
    if (results is! List) return null;
    for (final result in results.whereType<Map<String, Object?>>()) {
      if (result['resultTypeName'] == 'Endergebnis' ||
          result['resultTypeID'] == 2) {
        final home = result['pointsTeam1'];
        final away = result['pointsTeam2'];
        if (home is int && away is int) return (home, away);
      }
    }
    return null;
  }

  Tip _tipFromJson(Map<String, Object?> json) {
    return Tip(
      uid: json['uid'] as String,
      matchId: json['matchId'] as String,
      predictedHome: json['predictedHome'] as int,
      predictedAway: json['predictedAway'] as int,
      lockedAt: DateTime.parse(json['lockedAt'] as String),
      points: json['points'] as int? ?? 0,
    );
  }

  Map<String, Object?> _tipToJson(Tip tip) {
    return {
      'uid': tip.uid,
      'matchId': tip.matchId,
      'predictedHome': tip.predictedHome,
      'predictedAway': tip.predictedAway,
      'lockedAt': tip.lockedAt.toIso8601String(),
      'points': tip.points,
    };
  }

  String _createInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _teamKey(String value) {
    return value
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp('[^a-z0-9]'), '');
  }

  String _germanTeamName(String value) {
    const names = {
      'Australia': 'Australien',
      'Austria': 'Österreich',
      'Belgium': 'Belgien',
      'Bosnia and Herzegovina': 'Bosnien und Herzegowina',
      'Brazil': 'Brasilien',
      'Canada': 'Kanada',
      'Cape Verde': 'Kap Verde',
      'Colombia': 'Kolumbien',
      'Czechia': 'Tschechien',
      'DR Congo': 'DR Kongo',
      'Ecuador': 'Ecuador',
      'Egypt': 'Ägypten',
      'England': 'England',
      'France': 'Frankreich',
      'Germany': 'Deutschland',
      'Ghana': 'Ghana',
      'Haiti': 'Haiti',
      'Iran': 'Iran',
      'Iraq': 'Irak',
      'Ivory Coast': 'Elfenbeinküste',
      'Japan': 'Japan',
      'Jordan': 'Jordanien',
      'Mexico': 'Mexiko',
      'Morocco': 'Marokko',
      'Netherlands': 'Niederlande',
      'New Zealand': 'Neuseeland',
      'Norway': 'Norwegen',
      'Panama': 'Panama',
      'Paraguay': 'Paraguay',
      'Portugal': 'Portugal',
      'Qatar': 'Katar',
      'Saudi Arabia': 'Saudi-Arabien',
      'Scotland': 'Schottland',
      'Senegal': 'Senegal',
      'South Africa': 'Südafrika',
      'South Korea': 'Südkorea',
      'Spain': 'Spanien',
      'Sweden': 'Schweden',
      'Switzerland': 'Schweiz',
      'Tunisia': 'Tunesien',
      'Turkiye': 'Türkei',
      'Türkiye': 'Türkei',
      'United States': 'USA',
      'USA': 'USA',
      'Uruguay': 'Uruguay',
      'Uzbekistan': 'Usbekistan',
    };
    return names[value] ?? value;
  }

  @override
  Future<void> updateExtraPicks({
    String? favoriteTeam,
    String? predictedChampion,
    String? riskTeam,
    String? riskStage,
  }) async {
    final user = _currentUser;
    if (user == null) throw StateError('Kein aktiver Benutzer.');

    final sortedMatches = [..._currentMatches]
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    final tournamentStarted = sortedMatches.isNotEmpty &&
        VoleoClock.now.isAfter(sortedMatches.first.kickoff);
    if (tournamentStarted) {
      throw StateError(
          'Das Turnier hat bereits begonnen. Tipps können nicht mehr geändert werden.');
    }

    _currentUser = VoleoUser(
      uid: user.uid,
      nickname: user.nickname,
      isAnonymous: user.isAnonymous,
      photoUrl: user.photoUrl,
      email: user.email,
      providerIds: user.providerIds,
      favoriteTeam: favoriteTeam ?? user.favoriteTeam,
      predictedChampion: predictedChampion ?? user.predictedChampion,
      riskTeam: riskTeam ?? user.riskTeam,
      riskStage: riskStage ?? user.riskStage,
    );
    await _persist();
    _emitAll();
  }

  @override
  Future<VoleoUser?> getUser(String uid) async {
    if (_currentUser?.uid == uid) return _currentUser;
    // Look up in _members for mock/local data
    final memberIndex = _members.indexWhere((m) => m.uid == uid);
    if (memberIndex != -1) {
      final member = _members[memberIndex];
      // Generate stable mock picks based on uid hash
      final teams = [
        'Deutschland',
        'Spanien',
        'Frankreich',
        'England',
        'Italien',
        'Portugal',
        'Argentinien',
        'Brasilien'
      ];
      final fav = teams[uid.hashCode % teams.length];
      final champ = teams[(uid.hashCode + 1) % teams.length];
      final risk = teams[(uid.hashCode + 2) % teams.length];
      return VoleoUser(
        uid: uid,
        nickname: member.displayName,
        isAnonymous: true,
        favoriteTeam: fav,
        predictedChampion: champ,
        riskTeam: risk,
        riskStage: 'Achtelfinale',
      );
    }
    return null;
  }
}
