import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_first_voleo_repository.dart';
import 'data/voleo_repository.dart';
import 'domain/voleo_models.dart';

final repositoryProvider = Provider<VoleoRepository>((ref) {
  final repository = LocalFirstVoleoRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final userProvider = StreamProvider<VoleoUser?>((ref) {
  return ref.watch(repositoryProvider).watchUser();
});

final leagueProvider = StreamProvider<League?>((ref) {
  return ref.watch(repositoryProvider).watchLeague();
});

final matchesProvider = StreamProvider<List<CupMatch>>((ref) {
  return ref.watch(repositoryProvider).watchMatches();
});

final tipsProvider = StreamProvider<List<Tip>>((ref) {
  return ref.watch(repositoryProvider).watchTips();
});

final standingsProvider = StreamProvider<List<Standing>>((ref) {
  return ref.watch(repositoryProvider).watchStandings();
});
