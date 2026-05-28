import '../domain/voleo_models.dart';

abstract class VoleoRepository {
  Stream<VoleoUser?> watchUser();
  Stream<League?> watchLeague();
  Stream<List<CupMatch>> watchMatches();
  Stream<List<Tip>> watchTips();
  Stream<List<Standing>> watchStandings();

  Future<void> startSession({
    required String nickname,
    String? inviteCode,
  });

  Future<void> createLeague({required String name});
  Future<void> joinLeague({required String inviteCode});
  Future<void> saveTip({
    required String matchId,
    required int home,
    required int away,
  });
  Future<void> linkEmail(String email);
  Future<void> signOut();
}
