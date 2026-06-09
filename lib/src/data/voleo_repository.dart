import '../domain/voleo_models.dart';

abstract class VoleoRepository {
  Stream<VoleoUser?> watchUser();
  Stream<League?> watchLeague();
  Stream<List<League>> watchLeagues();
  Stream<List<CupMatch>> watchMatches();
  Stream<List<Tip>> watchTips();
  Stream<List<Tip>> watchLeagueTips();
  Stream<List<Standing>> watchStandings();

  Future<void> startSession({
    required String nickname,
    String? inviteCode,
  });

  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> linkWithGoogle();
  Future<void> linkWithApple();
  Future<void> updateProfile({
    String? nickname,
    String? photoUrl,
  });
  Future<void> uploadProfileImage(String filePath);

  Future<void> createLeague({required String name});
  Future<void> joinLeague({required String inviteCode});
  Future<void> switchLeague({required String leagueId});
  Future<void> renameLeague({required String name});
  Future<void> saveTip({
    required String matchId,
    required int home,
    required int away,
  });
  Future<void> linkEmail(String email);
  Future<void> signOut();
}
