import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../domain/voleo_models.dart';

abstract class VoleoRepository {
  Stream<VoleoUser?> watchUser();
  Stream<League?> watchLeague();
  Stream<List<League>> watchLeagues();
  Stream<List<CupMatch>> watchMatches();
  Stream<List<Tip>> watchTips();
  Stream<List<Tip>> watchLeagueTips();
  Stream<List<Standing>> watchStandings();
  Stream<OfficialTables> watchOfficialTables();

  Future<void> startSession({
    required String nickname,
    String? inviteCode,
  });

  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signInWithCredential(auth.AuthCredential credential);
  Future<void> linkWithGoogle();
  Future<void> linkWithApple();
  Future<void> unlinkProvider(String providerId);
  Future<void> updateProfile({
    String? nickname,
    String? photoUrl,
  });
  Future<void> updateThemeMode(String modeName);
  Future<void> uploadProfileImage(String filePath);

  Future<void> createLeague({required String name});
  Future<void> joinLeague({required String inviteCode});
  Future<void> switchLeague({required String leagueId});
  Future<void> leaveLeague({required String leagueId});
  Future<void> renameLeague({required String name});
  Future<void> saveTip({
    required String matchId,
    required int home,
    required int away,
    int? otHome,
    int? otAway,
    PenaltyWinnerSide? penaltyWinner,
  });
  Future<void> deleteTip({required String matchId});
  Future<void> linkEmail(String email);
  Future<void> signOut();
  Future<void> deleteAccount();

  Future<void> updateExtraPicks({
    String? favoriteTeam,
    String? predictedChampion,
    String? riskTeam,
    String? riskStage,
  });

  Future<VoleoUser?> getUser(String uid);
}
