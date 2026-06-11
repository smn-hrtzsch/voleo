import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/scoring.dart';
import '../domain/voleo_models.dart';
import '../domain/clock.dart';
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
  Future<void>? _googleSignInInitialization;

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
        final rawPhotoUrl = data['photoUrl'] as String?;
        final isLocalPath = rawPhotoUrl != null &&
            rawPhotoUrl.isNotEmpty &&
            !rawPhotoUrl.startsWith('http');
        final photoUrl = isLocalPath
            ? currentUser.photoURL
            : rawPhotoUrl ?? currentUser.photoURL;
        return VoleoUser(
          uid: currentUser.uid,
          nickname: data['nickname'] as String? ?? 'Spieler',
          isAnonymous: currentUser.isAnonymous,
          photoUrl: photoUrl,
          email: data['email'] as String? ?? currentUser.email,
          providerIds: _providerIds(currentUser),
          favoriteTeam: data['favoriteTeam'] as String?,
          predictedChampion: data['predictedChampion'] as String?,
          riskTeam: data['riskTeam'] as String?,
          riskStage: data['riskStage'] as String?,
          themeModeName: data['themeMode'] as String?,
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
          .map((snap) => snap.data()?['activeLeagueId'] as String?)
          .distinct()
          .asyncExpand((activeLeagueId) {
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
    return _firestore.collection('matches').snapshots().map((snapshot) {
      final staticMatches = buildWc2026GroupStageMatches();
      final firestoreMatches = snapshot.docs.map(_matchFromDoc).toList();

      final mergedMap = <String, CupMatch>{};

      // First, put all static matches into the map by ID
      for (final m in staticMatches) {
        mergedMap[m.id] = m;
      }

      String normalizeTeam(String name) {
        final lower = name.toLowerCase().trim();
        if (lower == 'bosnia and herzegovina' ||
            lower == 'bosnien und herzegowina' ||
            lower == 'bosnien-herzegowina' ||
            lower == 'bosnien herzegowina') {
          return 'bosnienherzegowina';
        }
        return lower.replaceAll('-', '').replaceAll(' ', '');
      }

      int statusPriority(MatchStatus status) {
        switch (status) {
          case MatchStatus.finalResult:
            return 3;
          case MatchStatus.live:
            return 2;
          case MatchStatus.scheduled:
            return 1;
        }
      }

      // Then, for each firestore match:
      for (final fm in firestoreMatches) {
        // 1. Try to find by ID
        if (mergedMap.containsKey(fm.id)) {
          final existing = mergedMap[fm.id]!;
          if (statusPriority(fm.status) >= statusPriority(existing.status)) {
            mergedMap[fm.id] = fm;
          }
          continue;
        }

        // 2. Fallback: Try to find by content (teams + kickoff) to avoid duplicates
        // with different IDs (e.g. from different simulation scripts)
        String? duplicateId;
        for (final entry in mergedMap.entries) {
          final sm = entry.value;
          if (normalizeTeam(sm.homeTeam) == normalizeTeam(fm.homeTeam) &&
              normalizeTeam(sm.awayTeam) == normalizeTeam(fm.awayTeam) &&
              sm.kickoff.difference(fm.kickoff).abs() < const Duration(hours: 12)) {
            duplicateId = entry.key;
            break;
          }
        }

        if (duplicateId != null) {
          final existing = mergedMap[duplicateId]!;
          if (statusPriority(fm.status) >= statusPriority(existing.status)) {
            // Keep the static match ID, but update with firestore data
            mergedMap[duplicateId] = fm.copyWith(id: duplicateId);
          }
        } else {
          mergedMap[fm.id] = fm;
        }
      }

      final merged = mergedMap.values.toList();
      merged.sort((a, b) => a.kickoff.compareTo(b.kickoff));
      return merged;
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

      late StreamController<List<Standing>> controller;
      StreamSubscription? membersSub;
      StreamSubscription? standingsSub;
      final Map<String, StreamSubscription> userSubs = {};
      final Map<String, Map<String, dynamic>> userDataMap = {};
      QuerySnapshot<Map<String, dynamic>>? lastStandingsSnap;
      QuerySnapshot<Map<String, dynamic>>? lastMembersSnap;

      controller = StreamController<List<Standing>>(
        onListen: () {
          void updateController() {
            if (lastStandingsSnap == null || lastMembersSnap == null) return;

            final standings =
                lastStandingsSnap!.docs.map(_standingFromDoc).toList();
            final memberDataMap = {
              for (final doc in lastMembersSnap!.docs) doc.id: doc.data()
            };

            final updatedStandings = standings.map((s) {
              final memberData = memberDataMap[s.uid];
              final userData = userDataMap[s.uid];
              final photoUrl = memberData?['photoUrl'] as String? ??
                  userData?['photoUrl'] as String? ??
                  s.photoUrl;
              final displayName = memberData?['displayName'] as String? ??
                  userData?['nickname'] as String? ??
                  s.displayName;

              return Standing(
                uid: s.uid,
                displayName: displayName,
                totalPoints: s.totalPoints,
                exactCount: s.exactCount,
                tendencyCount: s.tendencyCount,
                rank: s.rank,
                photoUrl: photoUrl,
              );
            }).toList();

            final existingUids = updatedStandings.map((s) => s.uid).toSet();
            bool addedAny = false;

            for (final memberDoc in lastMembersSnap!.docs) {
              final memberData = memberDoc.data();
              final uid = memberDoc.id;
              final leftAt = memberData['leftAt'];
              if (leftAt != null) {
                continue;
              }

              if (!existingUids.contains(uid)) {
                final userData = userDataMap[uid];
                updatedStandings.add(Standing(
                  uid: uid,
                  displayName: memberData['displayName'] as String? ??
                      userData?['nickname'] as String? ??
                      'Spieler',
                  totalPoints: memberData['totalPoints'] as int? ?? 0,
                  exactCount: memberData['exactCount'] as int? ?? 0,
                  tendencyCount: memberData['tendencyCount'] as int? ?? 0,
                  rank: 0,
                  photoUrl: memberData['photoUrl'] as String? ??
                      userData?['photoUrl'] as String?,
                ));
                addedAny = true;
              }
            }

            if (addedAny || lastStandingsSnap!.docs.isEmpty) {
              controller.add(rankStandings(updatedStandings));
            } else {
              controller.add(updatedStandings);
            }
          }

          membersSub =
              leagueRef.collection('members').snapshots().listen((membersSnap) {
            lastMembersSnap = membersSnap;
            final currentUids = membersSnap.docs.map((doc) => doc.id).toSet();
            final toCancel = userSubs.keys
                .where((uid) => !currentUids.contains(uid))
                .toList();
            for (final uid in toCancel) {
              userSubs[uid]?.cancel();
              userSubs.remove(uid);
              userDataMap.remove(uid);
            }

            for (final uid in currentUids) {
              if (!userSubs.containsKey(uid)) {
                userSubs[uid] = _firestore
                    .collection('users')
                    .doc(uid)
                    .snapshots()
                    .listen((userDocSnap) {
                  if (userDocSnap.exists) {
                    final data = userDocSnap.data();
                    if (data != null) {
                      userDataMap[uid] = data;
                      updateController();
                    }
                  }
                }, onError: (e) {
                  debugPrint('Error caching user $uid: $e');
                });
              }
            }

            standingsSub?.cancel();
            standingsSub = leagueRef
                .collection('standings')
                .orderBy('rank')
                .snapshots()
                .listen((standingsSnap) {
              lastStandingsSnap = standingsSnap;
              updateController();
            }, onError: controller.addError);
          }, onError: controller.addError);
        },
        onCancel: () {
          membersSub?.cancel();
          standingsSub?.cancel();
          for (final sub in userSubs.values) {
            sub.cancel();
          }
          userSubs.clear();
          userDataMap.clear();
        },
      );

      return controller.stream;
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
    await _initializeGoogleSignIn(googleSignIn);
    final googleUser = await _authenticateGoogle(
      googleSignIn,
      preferLightweight: true,
    );

    final googleAuth = googleUser.authentication;
    final credential = auth.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        try {
          await user.delete();
        } catch (_) {}
        await _auth.signOut();
        await GoogleSignIn.instance.signOut();
        throw auth.FirebaseAuthException(
          code: 'user-not-found',
          message:
              'Es existiert noch kein Voleo-Konto für diesen Google-Account. Bitte registriere dich zuerst.',
        );
      }
      await _ensureUserDocument(
        user,
        nickname: user.displayName ?? googleUser.displayName ?? 'Spieler',
        providerPhotoUrl: googleUser.photoUrl,
      );
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
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        try {
          await user.delete();
        } catch (_) {}
        await _auth.signOut();
        throw auth.FirebaseAuthException(
          code: 'user-not-found',
          message:
              'Es existiert noch kein Voleo-Konto für diesen Apple-Account. Bitte registriere dich zuerst.',
        );
      }
      await _ensureUserDocument(user, nickname: user.displayName ?? 'Spieler');
      await _ensureActiveLeague(user);
    }
  }

  @override
  Future<void> signInWithCredential(auth.AuthCredential credential) async {
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        try {
          await user.delete();
        } catch (_) {}
        await _auth.signOut();
        throw auth.FirebaseAuthException(
          code: 'user-not-found',
          message:
              'Es existiert noch kein Voleo-Konto für diese Anmeldedaten. Bitte registriere dich zuerst.',
        );
      }
      await _ensureUserDocument(user, nickname: user.displayName ?? 'Spieler');
      await _ensureActiveLeague(user);
    }
  }

  @override
  Future<void> linkWithGoogle() async {
    final user = _requireFirebaseUser();
    final googleSignIn = GoogleSignIn.instance;
    await _initializeGoogleSignIn(googleSignIn);
    final googleUser = await _authenticateGoogle(googleSignIn);

    final googleAuth = googleUser.authentication;
    final credential = auth.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await user.linkWithCredential(credential);
    await user.reload();
    final updatedUser = _auth.currentUser ?? user;
    await _ensureUserDocument(
      updatedUser,
      nickname: updatedUser.displayName ?? googleUser.displayName ?? 'Spieler',
      providerPhotoUrl: googleUser.photoUrl,
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
    final updatedUser = _auth.currentUser ?? user;
    await _ensureUserDocument(
      updatedUser,
      nickname: updatedUser.displayName ?? 'Spieler',
    );
  }

  @override
  Future<void> unlinkProvider(String providerId) async {
    final user = _requireFirebaseUser();
    auth.User unlinkedUser;
    try {
      unlinkedUser = await user.unlink(providerId);
    } on auth.FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login' || providerId != 'google.com') {
        rethrow;
      }
      final googleSignIn = GoogleSignIn.instance;
      await _initializeGoogleSignIn(googleSignIn);
      final googleUser = await _authenticateGoogle(googleSignIn);
      final googleAuth = googleUser.authentication;
      final credential = auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      unlinkedUser = await user.unlink(providerId);
    }
    if (providerId == 'google.com') {
      await GoogleSignIn.instance.signOut();
    }
    await unlinkedUser.reload();
    final updatedUser = _auth.currentUser ?? unlinkedUser;
    final providerIds = _providerIds(updatedUser);
    if (providerIds.contains(providerId)) {
      throw StateError(
        'Die Verknüpfung konnte in Firebase Auth nicht entfernt werden.',
      );
    }
    await _firestore.collection('users').doc(updatedUser.uid).set({
      'providerIds': providerIds,
      'email': updatedUser.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateThemeMode(String modeName) async {
    final user = _requireFirebaseUser();
    await _firestore.collection('users').doc(user.uid).set({
      'themeMode': modeName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateProfile({
    String? nickname,
    String? photoUrl,
  }) async {
    final user = _requireFirebaseUser();

    final leaguesSnapshot = await _firestore
        .collection('leagues')
        .where('memberIds', arrayContains: user.uid)
        .get();

    if (nickname != null) {
      for (final doc in leaguesSnapshot.docs) {
        await _ensureDisplayNameAvailable(
          leagueId: doc.id,
          uid: user.uid,
          displayName: nickname,
        );
      }
    }

    final updates = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (nickname != null) updates['nickname'] = nickname;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(user.uid);
    batch.set(userRef, updates, SetOptions(merge: true));

    for (final doc in leaguesSnapshot.docs) {
      final memberRef = doc.reference.collection('members').doc(user.uid);
      batch.set(
          memberRef,
          {
            if (nickname != null) 'displayName': nickname,
            if (photoUrl != null) 'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }

    await batch.commit();

    if (nickname != null) {
      await user.updateDisplayName(nickname);
    }
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }
  }

  @override
  Future<void> uploadProfileImage(String filePath) async {
    final user = _requireFirebaseUser();
    final ref = _storage.ref('users/${user.uid}/profile.jpg');
    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    await updateProfile(photoUrl: url);
  }

  @override
  Future<void> updateExtraPicks({
    String? favoriteTeam,
    String? predictedChampion,
    String? riskTeam,
    String? riskStage,
  }) async {
    final user = _requireFirebaseUser();

    final matchesSnapshot = await _firestore.collection('matches').get();
    final kickoffs = matchesSnapshot.docs
        .map((doc) => doc.data()['kickoff'] as Timestamp?)
        .whereType<Timestamp>()
        .map((t) => t.toDate())
        .toList()
      ..sort();

    final tournamentStarted =
        kickoffs.isNotEmpty && VoleoClock.now.isAfter(kickoffs.first);
    if (tournamentStarted) {
      throw StateError(
          'Das Turnier hat bereits begonnen. Tipps können nicht mehr geändert werden.');
    }

    final updates = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (favoriteTeam != null) updates['favoriteTeam'] = favoriteTeam;
    if (predictedChampion != null) {
      updates['predictedChampion'] = predictedChampion;
    }
    if (riskTeam != null) updates['riskTeam'] = riskTeam;
    if (riskStage != null) updates['riskStage'] = riskStage;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(updates, SetOptions(merge: true));
  }

  @override
  Future<VoleoUser?> getUser(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      if (data == null) {
        debugPrint(
            'FirestoreVoleoRepository.getUser($uid) -> document is null');
        return null;
      }
      final user = VoleoUser(
        uid: uid,
        nickname: data['nickname'] as String? ?? 'Spieler',
        isAnonymous: data['isAnonymous'] as bool? ?? true,
        photoUrl: data['photoUrl'] as String?,
        email: data['email'] as String?,
        providerIds: List<String>.from(data['providerIds'] ?? const <String>[]),
        favoriteTeam: data['favoriteTeam'] as String?,
        predictedChampion: data['predictedChampion'] as String?,
        riskTeam: data['riskTeam'] as String?,
        riskStage: data['riskStage'] as String?,
        themeModeName: data['themeMode'] as String?,
      );
      debugPrint(
          'FirestoreVoleoRepository.getUser($uid) -> loaded: ${user.nickname}, favoriteTeam: ${user.favoriteTeam}, predictedChampion: ${user.predictedChampion}');
      return user;
    } catch (e) {
      debugPrint(
          'FirestoreVoleoRepository.getUser($uid) -> network get failed: $e. Retrying from cache...');
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        final data = userDoc.data();
        if (data == null) {
          debugPrint(
              'FirestoreVoleoRepository.getUser($uid) -> cache doc is null');
          return null;
        }
        final user = VoleoUser(
          uid: uid,
          nickname: data['nickname'] as String? ?? 'Spieler',
          isAnonymous: data['isAnonymous'] as bool? ?? true,
          photoUrl: data['photoUrl'] as String?,
          email: data['email'] as String?,
          providerIds:
              List<String>.from(data['providerIds'] ?? const <String>[]),
          favoriteTeam: data['favoriteTeam'] as String?,
          predictedChampion: data['predictedChampion'] as String?,
          riskTeam: data['riskTeam'] as String?,
          riskStage: data['riskStage'] as String?,
          themeModeName: data['themeMode'] as String?,
        );
        debugPrint(
            'FirestoreVoleoRepository.getUser($uid) -> loaded from cache: ${user.nickname}, favoriteTeam: ${user.favoriteTeam}, predictedChampion: ${user.predictedChampion}');
        return user;
      } catch (cacheErr) {
        debugPrint(
            'FirestoreVoleoRepository.getUser($uid) -> cache get failed: $cacheErr');
        return null;
      }
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
      'photoUrl': await _photoUrlFor(user),
      'totalPoints': 0,
      'exactCount': 0,
      'tendencyCount': 0,
      'frozenPoints': 0,
      'frozenExactCount': 0,
      'frozenTendencyCount': 0,
      'joinedAt': FieldValue.serverTimestamp(),
      'leftAt': null,
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

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final activeId = userDoc.data()?['activeLeagueId'] as String?;

    final memberDoc = await league.collection('members').doc(user.uid).get();
    final memberData = memberDoc.data();

    final Map<String, Object?> memberUpdates = {
      'uid': user.uid,
      'displayName': displayName,
      'photoUrl': await _photoUrlFor(user),
      'joinedAt': FieldValue.serverTimestamp(),
      'leftAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (memberDoc.exists && memberData != null) {
      memberUpdates['frozenPoints'] = memberData['totalPoints'] ?? 0;
      memberUpdates['frozenExactCount'] = memberData['exactCount'] ?? 0;
      memberUpdates['frozenTendencyCount'] = memberData['tendencyCount'] ?? 0;
    } else {
      memberUpdates['role'] = 'member';
      memberUpdates['totalPoints'] = 0;
      memberUpdates['exactCount'] = 0;
      memberUpdates['tendencyCount'] = 0;
      memberUpdates['frozenPoints'] = 0;
      memberUpdates['frozenExactCount'] = 0;
      memberUpdates['frozenTendencyCount'] = 0;
    }

    await league
        .collection('members')
        .doc(user.uid)
        .set(memberUpdates, SetOptions(merge: true));

    await league.set({
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Copy existing tips to the new league
    if (activeId != null && activeId.isNotEmpty) {
      final tipsSnapshot = await _firestore
          .collection('leagues')
          .doc(activeId)
          .collection('tips')
          .where('uid', isEqualTo: user.uid)
          .get();
      if (tipsSnapshot.docs.isNotEmpty) {
        final tipsBatch = _firestore.batch();
        for (final tipDoc in tipsSnapshot.docs) {
          final data = tipDoc.data();
          final newTipRef = league.collection('tips').doc(tipDoc.id);
          tipsBatch.set(newTipRef, {
            'uid': user.uid,
            'matchId': data['matchId'],
            'predictedHome': data['predictedHome'],
            'predictedAway': data['predictedAway'],
            'lockedAt': data['lockedAt'],
            'points': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await tipsBatch.commit();
      }
    }

    await _firestore.collection('users').doc(user.uid).set({
      'activeLeagueId': league.id,
      'leagueIds': FieldValue.arrayUnion([league.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> leaveLeague({required String leagueId}) async {
    final user = _requireFirebaseUser();
    final leagueRef = _firestore.collection('leagues').doc(leagueId);
    final memberDoc = await leagueRef.collection('members').doc(user.uid).get();
    if (!memberDoc.exists) {
      throw StateError('Du bist kein Mitglied dieser Tipprunde.');
    }

    final data = memberDoc.data();
    final totalPoints = data?['totalPoints'] as int? ?? 0;
    final exactCount = data?['exactCount'] as int? ?? 0;
    final tendencyCount = data?['tendencyCount'] as int? ?? 0;

    await leagueRef.collection('members').doc(user.uid).set({
      'leftAt': FieldValue.serverTimestamp(),
      'frozenPoints': totalPoints,
      'frozenExactCount': exactCount,
      'frozenTendencyCount': tendencyCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await leagueRef.set({
      'memberIds': FieldValue.arrayRemove([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final userDocRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userDocRef.get();
    final userData = userDoc.data();
    final leagueIds = List<String>.from(userData?['leagueIds'] as List? ?? []);
    leagueIds.remove(leagueId);

    final activeId = userData?['activeLeagueId'] as String?;
    final nextActive = (activeId == leagueId)
        ? (leagueIds.isNotEmpty ? leagueIds.first : '')
        : activeId ?? '';

    await userDocRef.set({
      'leagueIds': leagueIds,
      'activeLeagueId': nextActive,
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
    final matches = await watchMatches().first;
    final match = matches.where((match) => match.id == matchId).firstOrNull;
    if (match == null) return;
    if (!canEditTip(match, VoleoClock.now)) {
      throw StateError('Tipps sind ab Anpfiff gesperrt.');
    }

    final leaguesSnapshot = await _firestore
        .collection('leagues')
        .where('memberIds', arrayContains: user.uid)
        .get();
    if (leaguesSnapshot.docs.isEmpty) {
      throw StateError('Du bist in keiner Tipprunde Mitglied.');
    }

    final batch = _firestore.batch();
    for (final league in leaguesSnapshot.docs) {
      final tipRef =
          league.reference.collection('tips').doc('${user.uid}_$matchId');
      batch.set(
          tipRef,
          {
            'uid': user.uid,
            'matchId': matchId,
            'predictedHome': home,
            'predictedAway': away,
            'lockedAt': Timestamp.fromDate(match.kickoff),
            'points': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> deleteTip({required String matchId}) async {
    final user = _requireFirebaseUser();
    final matches = await watchMatches().first;
    final match = matches.where((match) => match.id == matchId).firstOrNull;
    if (match == null) return;
    if (!canEditTip(match, VoleoClock.now)) {
      throw StateError('Tipps können ab Anpfiff nicht mehr gelöscht werden.');
    }

    final leaguesSnapshot = await _firestore
        .collection('leagues')
        .where('memberIds', arrayContains: user.uid)
        .get();
    if (leaguesSnapshot.docs.isEmpty) {
      throw StateError('Du bist in keiner Tipprunde Mitglied.');
    }

    final batch = _firestore.batch();
    for (final league in leaguesSnapshot.docs) {
      final tipRef =
          league.reference.collection('tips').doc('${user.uid}_$matchId');
      batch.delete(tipRef);
    }
    await batch.commit();
  }

  @override
  Future<void> linkEmail(String email) async {
    await _firestore.collection('users').doc(_requireFirebaseUser().uid).set({
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteCurrentUserData() async {
    final user = _requireFirebaseUser();
    final uid = user.uid;

    final leaguesSnapshot = await _firestore
        .collection('leagues')
        .where('memberIds', arrayContains: uid)
        .get();

    final batch = _firestore.batch();

    for (final leagueDoc in leaguesSnapshot.docs) {
      final memberRef = leagueDoc.reference.collection('members').doc(uid);
      batch.delete(memberRef);

      final standingRef = leagueDoc.reference.collection('standings').doc(uid);
      batch.delete(standingRef);

      batch.set(
          leagueDoc.reference,
          {
            'memberIds': FieldValue.arrayRemove([uid]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      final tipsSnapshot = await leagueDoc.reference
          .collection('tips')
          .where('uid', isEqualTo: uid)
          .get();
      for (final tipDoc in tipsSnapshot.docs) {
        batch.delete(tipDoc.reference);
      }
    }

    final userRef = _firestore.collection('users').doc(uid);
    batch.delete(userRef);

    await batch.commit();
  }

  @override
  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      final currentUser = _auth.currentUser ?? user;
      if (currentUser.isAnonymous || _providerIds(currentUser).isEmpty) {
        try {
          await _deleteCurrentUserData();
        } catch (e) {
          debugPrint('Error deleting user data during signOut: $e');
        }
        try {
          await currentUser.delete();
        } on auth.FirebaseAuthException catch (error) {
          if (error.code != 'requires-recent-login') rethrow;
        } catch (e) {
          debugPrint('Error deleting auth user during signOut: $e');
        }
      }
    } catch (e) {
      debugPrint('Error during reload or checking providers in signOut: $e');
    } finally {
      await _auth.signOut();
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _requireFirebaseUser();
    try {
      await _deleteCurrentUserData();
    } catch (e) {
      debugPrint('Error deleting user data during deleteAccount: $e');
    }
    try {
      await user.delete();
    } on auth.FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login') rethrow;
    } finally {
      await _auth.signOut();
    }
  }

  auth.User _requireFirebaseUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Keine aktive Sitzung.');
    return user;
  }

  Future<void> _ensureUserDocument(
    auth.User user, {
    required String nickname,
    String? providerPhotoUrl,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final existing = await userRef.get();
    final existingData = existing.data();
    final existingNickname = existingData?['nickname'] as String?;
    final existingPhotoUrl = existingData?['photoUrl'] as String?;
    final isLocalPath = existingPhotoUrl != null &&
        existingPhotoUrl.isNotEmpty &&
        !existingPhotoUrl.startsWith('http');
    final shouldUseProviderPhoto =
        (existingPhotoUrl == null || existingPhotoUrl.isEmpty || isLocalPath) &&
            ((providerPhotoUrl != null && providerPhotoUrl.isNotEmpty) ||
                (user.photoURL != null && user.photoURL!.isNotEmpty));
    final photoUrl = shouldUseProviderPhoto
        ? providerPhotoUrl ?? user.photoURL
        : existingPhotoUrl;
    await userRef.set({
      'nickname': existingNickname ?? nickname,
      'email': user.email,
      'photoUrl': photoUrl,
      'providerIds': _providerIds(user),
      if (existingData?['themeMode'] == null) 'themeMode': 'system',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await _updateLeagueProfilePhoto(user.uid, photoUrl);
    }
  }

  Future<void> _initializeGoogleSignIn(GoogleSignIn googleSignIn) async {
    _googleSignInInitialization ??= googleSignIn.initialize(
      serverClientId: const String.fromEnvironment(
        'WEB_CLIENT_ID',
        defaultValue:
            '506754202518-7og1f456io4vbp7ib7ij6hjdsiirpvbd.apps.googleusercontent.com',
      ),
    );
    await _googleSignInInitialization;
  }

  Future<GoogleSignInAccount> _authenticateGoogle(
    GoogleSignIn googleSignIn, {
    bool preferLightweight = false,
  }) async {
    if (preferLightweight) {
      final lightweightAttempt =
          googleSignIn.attemptLightweightAuthentication();
      if (lightweightAttempt != null) {
        final account = await lightweightAttempt;
        if (account != null) return account;
      }
    }
    return googleSignIn.authenticate();
  }

  Future<void> _updateLeagueProfilePhoto(String uid, String photoUrl) async {
    final leaguesSnapshot = await _firestore
        .collection('leagues')
        .where('memberIds', arrayContains: uid)
        .get();
    if (leaguesSnapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final league in leaguesSnapshot.docs) {
      batch.set(
        league.reference.collection('members').doc(uid),
        {'photoUrl': photoUrl, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
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

  Future<String?> _photoUrlFor(auth.User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['photoUrl'] as String? ?? user.photoURL;
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
      winner: data['winner'] as String?,
      resultNote: data['resultNote'] as String?,
      source: data['source'] as String? ?? 'openligadb',
      regularHomeScore: data['regularHomeScore'] as int?,
      regularAwayScore: data['regularAwayScore'] as int?,
      otHomeScore: data['otHomeScore'] as int?,
      otAwayScore: data['otAwayScore'] as int?,
      penaltyHomeScore: data['penaltyHomeScore'] as int?,
      penaltyAwayScore: data['penaltyAwayScore'] as int?,
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
