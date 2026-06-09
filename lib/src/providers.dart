import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

import 'data/firestore_voleo_repository.dart';
import 'data/voleo_repository.dart';
import 'domain/voleo_models.dart';

final repositoryProvider = Provider<VoleoRepository>((ref) {
  return FirestoreVoleoRepository(
    firestore: FirebaseFirestore.instance,
    firebaseAuth: FirebaseAuth.instance,
  );
});

final userProvider = StreamProvider<VoleoUser?>((ref) {
  return ref.watch(repositoryProvider).watchUser();
});

final leagueProvider = StreamProvider<League?>((ref) {
  return ref.watch(repositoryProvider).watchLeague();
});

final leaguesProvider = StreamProvider<List<League>>((ref) {
  return ref.watch(repositoryProvider).watchLeagues();
});

final matchesProvider = StreamProvider<List<CupMatch>>((ref) {
  return ref.watch(repositoryProvider).watchMatches();
});

final tipsProvider = StreamProvider<List<Tip>>((ref) {
  return ref.watch(repositoryProvider).watchTips();
});

final leagueTipsProvider = StreamProvider<List<Tip>>((ref) {
  return ref.watch(repositoryProvider).watchLeagueTips();
});

final standingsProvider = StreamProvider<List<Standing>>((ref) {
  return ref.watch(repositoryProvider).watchStandings();
});

class CachedInviteCode extends Notifier<String?> {
  @override
  String? build() => null;

  set value(String? val) => state = val;
}

final cachedInviteCodeProvider =
    NotifierProvider<CachedInviteCode, String?>(CachedInviteCode.new);

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    unawaited(_load());
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(mode.name);
  }

  Future<void> _load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return;
      final raw = (await file.readAsString()).trim();
      final mode = ThemeMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => ThemeMode.system,
      );
      state = mode;
    } catch (_) {
      state = ThemeMode.system;
    }
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/voleo_settings/theme_mode.txt');
  }
}
