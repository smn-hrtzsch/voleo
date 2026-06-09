import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/scoring.dart';
import '../domain/voleo_models.dart';
import 'voleo_repository.dart';
import 'wc2026_group_stage.dart';

class FirestoreVoleoRepository implements VoleoRepository {
  FirestoreVoleoRepository({
    required FirebaseFirestore firestore,
    required auth.FirebaseAuth firebaseAuth,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _auth = firebaseAuth,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final auth.FirebaseAuth _auth;
  final FirebaseStorage _storage;

  @override
  Stream<VoleoUser?> watchUser() {
    return _auth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) return Stream.value(null);
      return _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .map((doc) {
        final currentUser = _auth.currentUser ?? firebaseUser;
        final data = doc.data();
        if (data == null) {
          return VoleoUser(
            uid: currentUser.uid,
            nickname: currentUser.displayName ?? 'Spieler',
            isAnonymous: currentUser.isAnonymous,
            photoUrl: currentUser.photoURL,
            email: currentUser.email,
            providerIds: _providerIds(currentUser),
          );
        }
        return VoleoUser(
          uid: currentUser.uid,
          nickname: data['nickname'] as String? ?? 'Spieler',
          isAnonymous: currentUser.isAnonymous,
          photoUrl: data['photoUrl'] as String? ?? currentUser.photoURL,
          email: data['email'] as String? ?? currentUser.email,
          providerIds: _providerIds(currentUser),
        );
      });
    });
  }

  @override
  Stream<League?> watchLeague() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .asyncExpand((userSnapshot) {
        final activeLeagueId =
            userSnapshot.data()?['activeLeagueId'] as String?;
        if (activeLeagueId == null || activeLeagueId.isEmpty) {
          return Stream.value(null);
        }
        return _firestore
            .collection('leagues')
            .doc(activeLeagueId)
            .snapshots()
            .asyncMap((league) async {
          final data = league.data();
          if (data == null) return null;
          final inviteCode = data['inviteCode'] as String? ?? 'VOLEO26';
          if (data['ownerUid'] == user.uid &&
              data['inviteCodeMigrated'] != true &&
              _looksDeterministicInviteCode(inviteCode)) {
            final migratedCode = await _createInviteCode();
            await league.reference.set({
              'inviteCode': migratedCode,
              'inviteCodeMigrated': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            return League(
              id: league.id,
              name: data['name'] as String? ?? 'WM-Runde',
              inviteCode: migratedCode,
              ownerUid: data['ownerUid'] as String? ?? user.uid,
              imageUrl: data['imageUrl'] as String?,
              isActive: true,
            );
          }
          return League(
            id: league.id,
            name: data['name'] as String? ?? 'WM-Runde',
            inviteCode: inviteCode,
            ownerUid: data['ownerUid'] as String? ?? user.uid,
            imageUrl: data['imageUrl'] as String?,
            isActive: true,
          );
        });
      });
    });
  }

  @override
  Stream<List<League>> watchLeagues() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(const <League>[]);
      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .asyncExpand((userSnapshot) {
        final activeLeagueId =
            userSnapshot.data()?['activeLeagueId'] as String?;
        return _firestore
            .collection('leagues')
            .where('memberIds', arrayContains: user.uid)
            .snapshots()
            .map((snapshot) {
          final leagues = snapshot.docs.map((league) {
            final data = league.data();
            return League(
              id: league.id,
              name: data['name'] as String? ?? 'WM-Runde',
              inviteCode: data['inviteCode'] as String? ?? 'VOLEO26',
              ownerUid: data['ownerUid'] as String? ?? user.uid,
              imageUrl: data['imageUrl'] as String?,
              isActive: league.id == activeLeagueId,
            );
          }).toList()
            ..sort((a, b) {
              if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
              return a.name.compareTo(b.name);
            });
          return leagues;
        });
      });
    });
  }

  @override
  Stream<List<CupMatch>> watchMatches() {
    return _firestore
        .collection('matches')
        .orderBy('kickoff')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return buildWc2026GroupStageMatches();
      }
      return snapshot.docs.map(_matchFromDoc).toList();
    });
  }

  @override
  Stream<List<Tip>> watchTips() {
    return watchLeagueTips().map((tips) {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return const <Tip>[];
      return tips.where((tip) => tip.uid == uid).toList();
    });
  }

  @override
  Stream<List<Tip>> watchLeagueTips() {
    return watchLeague().asyncExpand((league) {
      if (league == null) return Stream.value(const <Tip>[]);
      return _firestore
          .collection('leagues')
          .doc(league.id)
          .collection('tips')
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_tipFromDoc).toList());
    });
  }

  @override
  Stream<List<Standing>> watchStandings() {
    return watchLeague().asyncExpand((league) {
      if (league == null) return Stream.value(const <Standing>[]);
      final leagueRef = _firestore.collection('leagues').doc(league.id);
      return leagueRef
          .collection('standings')
          .orderBy('rank')
          .snapshots()
          .asyncExpand((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          return Stream.value(snapshot.docs.map(_standingFromDoc).toList());
        }
        return leagueRef.collection('members').snapshots().map((members) {
          final standings = members.docs.map((doc) {
            final data = doc.data();
            return Standing(
              uid: doc.id,
              displayName: data['displayName'] as String? ?? 'Spieler',
              totalPoints: data['totalPoints'] as int? ?? 0,
              exactCount: data['exactCount'] as int? ?? 0,
              tendencyCount: data['tendencyCount'] as int? ?? 0,
              rank: 0,
              photoUrl: data['photoUrl'] as String?,
            );
          }).toList();
          return rankStandings(standings);
        });
      });
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
    } else {
      await createLeague(name: 'Meine WM-Runde');
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      serverClientId: const String.fromEnvironment(
        'WEB_CLIENT_ID',
        defaultValue:
            '506754202518-7og1f456io4vbp7ib7ij6hjdsiirpvbd.apps.googleusercontent.com',
      ),
    );
    final googleUser = await googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;
    final credential = auth.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      await _ensureUserDocument(user, nickname: user.displayName ?? 'Spieler');
      await _ensureActiveLeague(user);
    }
  }

  @override
  Future<void> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final credential = auth.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      await _ensureUserDocument(user, nickname: user.displayName ?? 'Spieler');
      await _ensureActiveLeague(user);
    }
  }

  @override
  Future<void> linkWithGoogle() async {
    final user = _requireFirebaseUser();
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      serverClientId: const String.fromEnvironment(
        'WEB_CLIENT_ID',
        defaultValue:
            '506754202518-7og1f456io4vbp7ib7ij6hjdsiirpvbd.apps.googleusercontent.com',
      ),
    );
    final googleUser = await googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;
    final credential = auth.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await user.linkWithCredential(credential);
    await user.reload();
    await _ensureUserDocument(
      _auth.currentUser ?? user,
      nickname: (_auth.currentUser ?? user).displayName ?? 'Spieler',
    );
  }

  @override
  Future<void> linkWithApple() async {
    final user = _requireFirebaseUser();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final credential = auth.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    await user.linkWithCredential(credential);
    await user.reload();
    await _ensureUserDocument(
      _auth.currentUser ?? user,
      nickname: (_auth.currentUser ?? user).displayName ?? 'Spieler',
    );
  }

  @override
  Future<void> updateProfile({
    String? nickname,
    String? photoUrl,
  }) async {
    final user = _requireFirebaseUser();
    final leagueId = await _activeLeagueIdFor(user.uid);
    if (nickname != null && leagueId != null) {
      await _ensureDisplayNameAvailable(
        leagueId: leagueId,
        uid: user.uid,
        displayName: nickname,
      );
    }
    final updates = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (nickname != null) updates['nickname'] = nickname;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(updates, SetOptions(merge: true));
    if (nickname != null) {
      await user.updateDisplayName(nickname);
    }
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }
    if (leagueId != null && (nickname != null || photoUrl != null)) {
      await _firestore
          .collection('leagues')
          .doc(leagueId)
          .collection('members')
          .doc(user.uid)
          .set({
        if (nickname != null) 'displayName': nickname,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<void> uploadProfileImage(String filePath) async {
    final user = _requireFirebaseUser();
    try {
      final ref = _storage.ref('users/${user.uid}/profile.jpg');
      await ref.putFile(
        File(filePath),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await updateProfile(photoUrl: url);
    } on FirebaseException {
      await updateProfile(photoUrl: filePath);
    }
  }

  @override
  Future<void> createLeague({required String name}) async {
    final user = _requireFirebaseUser();
    final inviteCode = await _createInviteCode();
    final league = _firestore.collection('leagues').doc();
    await league.set({
      'name': name,
      'inviteCode': inviteCode,
      'ownerUid': user.uid,
      'memberIds': [user.uid],
      'scoringPreset': 'classic',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await league.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'role': 'owner',
      'displayName': await _displayNameFor(user),
      'photoUrl': user.photoURL,
      'totalPoints': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('users').doc(user.uid).set({
      'activeLeagueId': league.id,
      'leagueIds': FieldValue.arrayUnion([league.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final league = leagues.docs.first.reference;
    final displayName = await _displayNameFor(user);
    await _ensureDisplayNameAvailable(
      leagueId: league.id,
      uid: user.uid,
      displayName: displayName,
    );
    await league.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'role': 'member',
      'displayName': displayName,
      'photoUrl': user.photoURL,
      'totalPoints': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await league.set({
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('users').doc(user.uid).set({
      'activeLeagueId': league.id,
      'leagueIds': FieldValue.arrayUnion([league.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> switchLeague({required String leagueId}) async {
    final user = _requireFirebaseUser();
    final member = await _firestore
        .collection('leagues')
        .doc(leagueId)
        .collection('members')
        .doc(user.uid)
        .get();
    if (!member.exists) {
      throw StateError('Du bist kein Mitglied dieser Tipprunde.');
    }
    await _firestore.collection('users').doc(user.uid).set({
      'activeLeagueId': leagueId,
      'leagueIds': FieldValue.arrayUnion([leagueId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> renameLeague({required String name}) async {
    final user = _requireFirebaseUser();
    final leagueId = await _activeLeagueIdFor(user.uid);
    if (leagueId == null) throw StateError('Keine aktive Tipprunde.');
    final league = await _firestore.collection('leagues').doc(leagueId).get();
    if (league.data()?['ownerUid'] != user.uid) {
      throw StateError('Nur Admins können die Tipprunde umbenennen.');
    }
    await league.reference.set({
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
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
    final matches = await watchMatches().first;
    final match = matches.firstWhere((match) => match.id == matchId);
    if (!canEditTip(match, DateTime.now())) {
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
      'lockedAt': Timestamp.fromDate(match.kickoff),
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

  Future<void> _ensureUserDocument(
    auth.User user, {
    required String nickname,
  }) async {
    await _firestore.collection('users').doc(user.uid).set({
      'nickname': nickname,
      'email': user.email,
      'photoUrl': user.photoURL,
      'providerIds': _providerIds(user),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureActiveLeague(auth.User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final activeLeagueId = userDoc.data()?['activeLeagueId'] as String?;
    if (activeLeagueId != null && activeLeagueId.isNotEmpty) return;
    await createLeague(name: 'Meine WM-Runde');
  }

  Future<String> _displayNameFor(auth.User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['nickname'] as String? ??
        user.displayName ??
        'Spieler';
  }

  Future<String?> _activeLeagueIdFor(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    return userDoc.data()?['activeLeagueId'] as String?;
  }

  Future<void> _ensureDisplayNameAvailable({
    required String leagueId,
    required String uid,
    required String displayName,
  }) async {
    final normalized = _normalizeName(displayName);
    if (normalized.isEmpty) {
      throw StateError('Bitte gib einen Namen ein.');
    }
    final members = await _firestore
        .collection('leagues')
        .doc(leagueId)
        .collection('members')
        .get();
    for (final member in members.docs) {
      if (member.id == uid) continue;
      final existingName = member.data()['displayName'] as String? ?? '';
      if (_normalizeName(existingName) == normalized) {
        throw StateError('Dieser Name ist in der Liga bereits vergeben.');
      }
    }
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _providerIds(auth.User user) {
    return [
      for (final provider in user.providerData)
        if (provider.providerId != 'firebase') provider.providerId,
    ];
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
      group: data['group'] as String? ?? '',
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
      photoUrl: data['photoUrl'] as String?,
    );
  }

  bool _looksDeterministicInviteCode(String code) {
    return code == 'VOLEO26' || RegExp(r'^[A-Z0-9]{4}26$').hasMatch(code);
  }

  Future<String> _createInviteCode() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = List.generate(
        6,
        (_) => alphabet[random.nextInt(alphabet.length)],
      ).join();
      final existing = await _firestore
          .collection('leagues')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    throw StateError(
        'Es konnte kein eindeutiger Einladungscode erzeugt werden.');
  }
}
