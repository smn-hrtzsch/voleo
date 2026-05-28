import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../domain/voleo_models.dart';
import 'voleo_repository.dart';

class FirestoreVoleoRepository implements VoleoRepository {
  FirestoreVoleoRepository({
    required FirebaseFirestore firestore,
    required auth.FirebaseAuth firebaseAuth,
  })  : _firestore = firestore,
        _auth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final auth.FirebaseAuth _auth;

  @override
  Stream<VoleoUser?> watchUser() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      final doc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();
      final data = doc.data();
      if (data == null) {
        return VoleoUser(
          uid: firebaseUser.uid,
          nickname: firebaseUser.displayName ?? 'Spieler',
          email: firebaseUser.email,
        );
      }
      return VoleoUser(
        uid: firebaseUser.uid,
        nickname: data['nickname'] as String? ?? 'Spieler',
        email: data['email'] as String?,
      );
    });
  }

  @override
  Stream<League?> watchLeague() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore
        .collectionGroup('members')
        .where(FieldPath.documentId, isEqualTo: uid)
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return null;
      final leagueRef = snapshot.docs.first.reference.parent.parent;
      if (leagueRef == null) return null;
      final league = await leagueRef.get();
      final data = league.data();
      if (data == null) return null;
      return League(
        id: league.id,
        name: data['name'] as String,
        inviteCode: data['inviteCode'] as String,
        ownerUid: data['ownerUid'] as String,
      );
    });
  }

  @override
  Stream<List<CupMatch>> watchMatches() {
    return _firestore
        .collection('matches')
        .orderBy('kickoff')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_matchFromDoc).toList());
  }

  @override
  Stream<List<Tip>> watchTips() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collectionGroup('tips')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_tipFromDoc).toList());
  }

  @override
  Stream<List<Standing>> watchStandings() {
    return watchLeague().asyncExpand((league) {
      if (league == null) return Stream.value(const <Standing>[]);
      return _firestore
          .collection('leagues')
          .doc(league.id)
          .collection('standings')
          .orderBy('rank')
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_standingFromDoc).toList());
    });
  }

  @override
  Future<void> startSession({
    required String nickname,
    String? inviteCode,
  }) async {
    final credential =
        _auth.currentUser == null ? await _auth.signInAnonymously() : null;
    final user = credential?.user ?? _auth.currentUser!;
    await _firestore.collection('users').doc(user.uid).set({
      'nickname': nickname,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (inviteCode != null && inviteCode.isNotEmpty) {
      await joinLeague(inviteCode: inviteCode);
    }
  }

  @override
  Future<void> createLeague({required String name}) async {
    final user = _requireFirebaseUser();
    final inviteCode = _createInviteCode(name);
    final league = _firestore.collection('leagues').doc();
    await league.set({
      'name': name,
      'inviteCode': inviteCode,
      'ownerUid': user.uid,
      'scoringPreset': 'classic',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await league.collection('members').doc(user.uid).set({
      'role': 'owner',
      'displayName': user.displayName ?? 'Spieler',
      'totalPoints': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> joinLeague({required String inviteCode}) async {
    final user = _requireFirebaseUser();
    final leagues = await _firestore
        .collection('leagues')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();
    if (leagues.docs.isEmpty) {
      throw StateError('Diese Tipprunde wurde nicht gefunden.');
    }
    await leagues.docs.first.reference.collection('members').doc(user.uid).set({
      'role': 'member',
      'displayName': user.displayName ?? 'Spieler',
      'totalPoints': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveTip({
    required String matchId,
    required int home,
    required int away,
  }) async {
    final user = _requireFirebaseUser();
    final league = await watchLeague().first;
    if (league == null) throw StateError('Keine aktive Tipprunde.');
    final match = await _firestore.collection('matches').doc(matchId).get();
    final kickoff = (match.data()?['kickoff'] as Timestamp?)?.toDate();
    if (kickoff == null || DateTime.now().isAfter(kickoff)) {
      throw StateError('Tipps sind ab Anpfiff gesperrt.');
    }
    await _firestore
        .collection('leagues')
        .doc(league.id)
        .collection('tips')
        .doc('${user.uid}_$matchId')
        .set({
      'uid': user.uid,
      'matchId': matchId,
      'predictedHome': home,
      'predictedAway': away,
      'lockedAt': Timestamp.fromDate(kickoff),
      'points': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> linkEmail(String email) async {
    await _firestore.collection('users').doc(_requireFirebaseUser().uid).set({
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> signOut() => _auth.signOut();

  auth.User _requireFirebaseUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Keine aktive Sitzung.');
    return user;
  }

  CupMatch _matchFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final statusName = data['status'] as String? ?? 'scheduled';
    return CupMatch(
      id: doc.id,
      homeTeam: data['homeTeam'] as String,
      awayTeam: data['awayTeam'] as String,
      kickoff: (data['kickoff'] as Timestamp).toDate(),
      stage: data['stage'] as String? ?? 'Gruppenphase',
      status: MatchStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => MatchStatus.scheduled,
      ),
      homeScore: data['homeScore'] as int?,
      awayScore: data['awayScore'] as int?,
      source: data['source'] as String? ?? 'openligadb',
    );
  }

  Tip _tipFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Tip(
      uid: data['uid'] as String,
      matchId: data['matchId'] as String,
      predictedHome: data['predictedHome'] as int,
      predictedAway: data['predictedAway'] as int,
      lockedAt: (data['lockedAt'] as Timestamp).toDate(),
      points: data['points'] as int? ?? 0,
    );
  }

  Standing _standingFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Standing(
      uid: doc.id,
      displayName: data['displayName'] as String,
      totalPoints: data['totalPoints'] as int? ?? 0,
      exactCount: data['exactCount'] as int? ?? 0,
      tendencyCount: data['tendencyCount'] as int? ?? 0,
      rank: data['rank'] as int? ?? 0,
    );
  }

  String _createInviteCode(String name) {
    final normalized =
        name.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '').padRight(4, 'X');
    return '${normalized.substring(0, 4)}26';
  }
}
