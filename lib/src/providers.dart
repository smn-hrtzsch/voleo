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

class SessionTransitionController extends Notifier<bool> {
  @override
  bool build() => false;

  set value(bool next) => state = next;
}

final sessionTransitionProvider =
    NotifierProvider<SessionTransitionController, bool>(
        SessionTransitionController.new);

class ForceOnboardingController extends Notifier<bool> {
  @override
  bool build() => false;

  set value(bool next) => state = next;
}

final forceOnboardingProvider =
    NotifierProvider<ForceOnboardingController, bool>(
        ForceOnboardingController.new);

class ComingFromRulesDialogController extends Notifier<bool> {
  @override
  bool build() => false;

  set value(bool next) => state = next;
}

final comingFromRulesDialogProvider =
    NotifierProvider<ComingFromRulesDialogController, bool>(
        ComingFromRulesDialogController.new);

class ShowRulesDialogController extends Notifier<bool> {
  @override
  bool build() => false;

  set value(bool next) => state = next;
}

final showRulesDialogProvider =
    NotifierProvider<ShowRulesDialogController, bool>(
        ShowRulesDialogController.new);

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    ref.listen(userProvider, (_, next) {
      final modeName = next.value?.themeModeName;
      if (modeName == null || modeName.isEmpty) return;
      final mode = _themeModeFromName(modeName);
      if (mode == state) return;
      state = mode;
      unawaited(_saveLocal(mode));
    });
    unawaited(_load());
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _saveLocal(mode);
    if (ref.read(userProvider).value != null) {
      await ref.read(repositoryProvider).updateThemeMode(mode.name);
    }
  }

  Future<void> _saveLocal(ThemeMode mode) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(mode.name);
  }

  Future<void> _load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return;
      final raw = (await file.readAsString()).trim();
      final mode = _themeModeFromName(raw);
      state = mode;
    } catch (_) {
      state = ThemeMode.system;
    }
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/voleo_settings/theme_mode.txt');
  }

  ThemeMode _themeModeFromName(String value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}

class PendingLoginError extends Notifier<String?> {
  @override
  String? build() => null;

  set value(String? val) => state = val;
}

final pendingLoginErrorProvider =
    NotifierProvider<PendingLoginError, String?>(PendingLoginError.new);
