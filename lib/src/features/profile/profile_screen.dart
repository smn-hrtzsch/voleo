import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../admin/admin_debug_screen.dart';
import '../../domain/flags.dart';
import '../../domain/clock.dart';
import '../../domain/scoring.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/app_toast.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _imagePicker = ImagePicker();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final comingFromRules = ref.watch(comingFromRulesDialogProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        leading: comingFromRules
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  ref.read(comingFromRulesDialogProvider.notifier).value =
                      false;
                  ref.read(showRulesDialogProvider.notifier).value = true;
                  context.go('/home');
                },
              )
            : null,
      ),
      body: user.when(
        data: (value) {
          if (value == null) {
            return const Center(child: Text('Kein aktiver Account.'));
          }
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _ProfileHeader(
                    user: value,
                    onEditName: () => _editName(value),
                    onPickImage: _pickProfileImage,
                  ),
                  const SizedBox(height: 24),
                  if (!value.hasLinkedProvider) ...[
                    _AnonymousWarning(),
                    const SizedBox(height: 20),
                  ],
                  _ThemeModeCard(
                    value: ref.watch(themeModeProvider),
                    onChanged: (mode) =>
                        ref.read(themeModeProvider.notifier).setThemeMode(mode),
                  ),
                  const SizedBox(height: 16),
                  _BoosterAndRiskPicksCard(user: value),
                  if (adminDebugUids.contains(value.uid)) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/profile/admin-debug'),
                      icon: const Icon(Icons.monitor_heart),
                      label: const Text('Sync Status'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Anmeldemethoden',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _ProviderTile(
                    icon: SvgPicture.asset(
                      'assets/google_logo.svg',
                      width: 20,
                      height: 20,
                    ),
                    title: value.hasGoogleProvider
                        ? 'Google verknüpft'
                        : 'Mit Google verknüpfen',
                    subtitle: value.hasGoogleProvider
                        ? value.email ?? 'Google Account'
                        : 'Account auf anderen Geräten nutzen',
                    isLinked: value.hasGoogleProvider,
                    onPressed: _isLoading || value.hasGoogleProvider
                        ? null
                        : _linkWithGoogle,
                    onUnlink: _isLoading || !value.hasGoogleProvider
                        ? null
                        : () => _confirmUnlinkProvider(
                              providerId: 'google.com',
                              providerName: 'Google',
                            ),
                  ),
                  const SizedBox(height: 10),
                  _ProviderTile(
                    icon: FaIcon(
                      FontAwesomeIcons.apple,
                      size: 21,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: value.hasAppleProvider
                        ? 'Apple verknüpft'
                        : 'Mit Apple verknüpfen',
                    subtitle: value.hasAppleProvider
                        ? value.email ?? 'Apple Account'
                        : 'Optional für Apple-Geräte',
                    isLinked: value.hasAppleProvider,
                    onPressed: _isLoading || value.hasAppleProvider
                        ? null
                        : _linkWithApple,
                    onUnlink: _isLoading || !value.hasAppleProvider
                        ? null
                        : () => _confirmUnlinkProvider(
                              providerId: 'apple.com',
                              providerName: 'Apple',
                            ),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _confirmSignOut(value),
                    icon: const Icon(Icons.logout),
                    label: const Text('Abmelden'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        _isLoading ? null : () => _confirmDeleteAccount(value),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Account löschen'),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child:
                        Text('Open Source · MIT License · de.capycode.voleo'),
                  ),
                ],
              ),
              if (_isLoading)
                const ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 82,
    );
    if (image == null) return;
    await _runProfileAction(
      () => ref.read(repositoryProvider).uploadProfileImage(image.path),
      'Profilbild aktualisiert.',
    );
  }

  Future<void> _editName(VoleoUser user) async {
    final controller = TextEditingController(text: user.nickname);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Profil bearbeiten'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nutzername',
              hintText: 'Nutzernamen eingeben',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || name == user.nickname) return;
    await _runProfileAction(
      () => ref.read(repositoryProvider).updateProfile(nickname: name),
      'Profil gespeichert.',
    );
  }

  Future<void> _linkWithGoogle() async {
    setState(() => _isLoading = true);
    var succeeded = false;
    try {
      await ref.read(repositoryProvider).linkWithGoogle();
      succeeded = true;
    } catch (error) {
      if (_isUserCanceledAuth(error)) return;
      if (error is auth.FirebaseAuthException &&
          _isAlreadyLinkedError(error.code)) {
        await _handleLinkedAccountError(
          providerName: 'Google',
          switchCredential: error.credential,
        );
        return;
      }
      if (mounted) {
        showAppToast(
          context,
          'Aktion fehlgeschlagen: $error',
          type: AppToastType.error,
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted && succeeded) {
      showAppToast(context, 'Google verknüpft.', type: AppToastType.success);
    }
  }

  Future<void> _linkWithApple() async {
    await _runProfileAction(
      () => ref.read(repositoryProvider).linkWithApple(),
      'Apple verknüpft.',
    );
  }

  Future<void> _confirmUnlinkProvider({
    required String providerId,
    required String providerName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$providerName-Verknüpfung entfernen?'),
          content: Text(
            'Du kannst dich danach nicht mehr mit $providerName anmelden, '
            'bis du das Konto wieder verknüpfst.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Entfernen'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).unlinkProvider(providerId);
      if (mounted) {
        showAppToast(
          context,
          '$providerName-Verknüpfung entfernt.',
          type: AppToastType.success,
        );
      }
    } catch (error) {
      if (_isUserCanceledAuth(error)) return;
      if (mounted) {
        showAppToast(
          context,
          'Aktion fehlgeschlagen: $error',
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSignOut(VoleoUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            user.isAnonymous ? 'Anonymen Account abmelden?' : 'Abmelden?',
          ),
          content: Text(
            !user.hasLinkedProvider
                ? 'Dieser Account ist nicht mit Google oder Apple verknüpft. '
                    'Beim Abmelden wird er inklusive Tipps und Mitgliedschaften gelöscht.'
                : 'Du kannst dich später wieder mit deinem verknüpften Account anmelden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(!user.hasLinkedProvider
                  ? 'Account löschen & abmelden'
                  : 'Abmelden'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _signOut();
  }

  Future<void> _signOut() async {
    final router = GoRouter.of(context);
    await _runProfileAction(
      () async {
        ref.read(sessionTransitionProvider.notifier).value = true;
        ref.read(forceOnboardingProvider.notifier).value = false;
        router.go('/loading');
        await ref.read(repositoryProvider).signOut();
        ref.read(forceOnboardingProvider.notifier).value = true;
        ref.read(sessionTransitionProvider.notifier).value = false;
        router.go('/');
      },
      null,
    );
  }

  Future<void> _confirmDeleteAccount(VoleoUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Account unwiderruflich löschen?'),
          content: const Text(
            'Bist du sicher? Alle deine Tipps, dein Punktestand und dein Account '
            'werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Account löschen'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final router = GoRouter.of(context);
    await _runProfileAction(
      () async {
        ref.read(sessionTransitionProvider.notifier).value = true;
        ref.read(forceOnboardingProvider.notifier).value = false;
        router.go('/loading');
        await ref.read(repositoryProvider).deleteAccount();
        ref.read(forceOnboardingProvider.notifier).value = true;
        ref.read(sessionTransitionProvider.notifier).value = false;
        router.go('/');
      },
      'Account erfolgreich gelöscht.',
    );
  }

  Future<void> _runProfileAction(
    Future<void> Function() action,
    String? successMessage,
  ) async {
    setState(() => _isLoading = true);
    final transitionController = ref.read(sessionTransitionProvider.notifier);
    try {
      await action();
      if (mounted && successMessage != null) {
        showAppToast(context, successMessage, type: AppToastType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppToast(context, 'Aktion fehlgeschlagen: $error',
            type: AppToastType.error);
      }
    } finally {
      transitionController.value = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLinkedAccountError({
    required String providerName,
    required auth.AuthCredential? switchCredential,
  }) async {
    if (!mounted) return;
    final choice = await showDialog<_LinkedAccountChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$providerName bereits verknüpft'),
          content: Text(
            'Dieses $providerName gehört bereits zu einem anderen Voleo-Konto. '
            'Möchtest du zu diesem Konto wechseln oder ein anderes Konto verknüpfen?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _LinkedAccountChoice.tryAnother),
              child: const Text('Anderes Konto'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _LinkedAccountChoice.switchAccount),
              child: const Text('Konto wechseln'),
            ),
          ],
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == _LinkedAccountChoice.tryAnother) {
      try {
        await ref.read(repositoryProvider).linkWithGoogle();
      } catch (error) {
        if (_isUserCanceledAuth(error)) return;
        rethrow;
      }
      return;
    }
    if (switchCredential == null) {
      showAppToast(
        context,
        'Dieses Konto kann nicht direkt gewechselt werden. Bitte melde dich über den Startbildschirm an.',
        type: AppToastType.error,
      );
      return;
    }
    await ref.read(repositoryProvider).signInWithCredential(switchCredential);
  }

  bool _isAlreadyLinkedError(String code) {
    return code == 'credential-already-in-use' ||
        code == 'account-exists-with-different-credential' ||
        code == 'email-already-in-use';
  }

  bool _isUserCanceledAuth(Object error) {
    if (error is GoogleSignInException) {
      return error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted;
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('canceled') ||
        raw.contains('cancelled') ||
        raw.contains('singlesigninexceptioncode.failed');
  }
}

enum _LinkedAccountChoice {
  switchAccount,
  tryAnother,
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onEditName,
    required this.onPickImage,
  });

  final VoleoUser user;
  final VoidCallback onEditName;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPickImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              _ProfileAvatar(user: user),
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(
                  Icons.edit,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                user.nickname,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: onEditName,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Namen bearbeiten',
            ),
          ],
        ),
        Text(
          user.email ?? 'Anonymer Account',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final VoleoUser user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl;
    ImageProvider? imageProvider;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http')) {
        imageProvider = CachedNetworkImageProvider(photoUrl);
      } else {
        final rawPath = photoUrl.startsWith('file://')
            ? Uri.parse(photoUrl).toFilePath()
            : photoUrl;
        imageProvider = FileImage(File(rawPath));
      }
    }
    return CircleAvatar(
      radius: 54,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(
              Icons.person,
              size: 54,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }
}

class _AnonymousWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Anonymer Account: Verknüpfe Google oder Apple, bevor du dich '
              'abmeldest oder das Gerät wechselst. Ohne Verknüpfung wird der '
              'Account beim Abmelden gelöscht.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contrast),
                const SizedBox(width: 8),
                Text(
                  'Darstellung',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_suggest_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Hell'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dunkel'),
                ),
              ],
              selected: {value},
              onSelectionChanged: (values) => onChanged(values.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLinked,
    required this.onPressed,
    this.onUnlink,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final bool isLinked;
  final VoidCallback? onPressed;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderSide = BorderSide(
      color: isDark ? const Color(0xff2f3545) : scheme.outlineVariant,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.fromBorderSide(borderSide),
      ),
      child: InkWell(
        onTap: isLinked ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isLinked)
                IconButton(
                  onPressed: onUnlink,
                  icon: const Icon(Icons.link_off_outlined),
                  color: scheme.error,
                  tooltip: 'Verknüpfung entfernen',
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoosterAndRiskPicksCard extends ConsumerStatefulWidget {
  const _BoosterAndRiskPicksCard({required this.user});

  final VoleoUser user;

  @override
  ConsumerState<_BoosterAndRiskPicksCard> createState() =>
      _BoosterAndRiskPicksCardState();
}

class _BoosterAndRiskPicksCardState
    extends ConsumerState<_BoosterAndRiskPicksCard> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final matchesValue = ref.watch(matchesProvider);
    final scheme = Theme.of(context).colorScheme;

    return matchesValue.when(
      data: (matches) {
        final sorted = [...matches]
          ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
        final tournamentStarted =
            sorted.isNotEmpty && VoleoClock.now.isAfter(sorted.first.kickoff);

        final teams = {
          for (final m in matches) ...[m.homeTeam, m.awayTeam]
        }.where((t) => !isPlaceholderTeam(t)).toList()
          ..sort();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rocket_launch_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Turnier-Picks & Booster',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tournamentStarted
                      ? 'Das Turnier hat bereits begonnen. Die Picks können nicht mehr geändert werden.'
                      : 'Wähle deine Teams vor Turnierstart. Später sind keine Änderungen möglich.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tournamentStarted
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                ),
                const Divider(height: 24),

                // 1. Lieblingsmannschaft
                _buildPickTile(
                  title: 'Lieblingsmannschaft (+10 Pkt./Sieg)',
                  value: widget.user.favoriteTeam,
                  teams: teams,
                  disabled: tournamentStarted || _isSaving,
                  points: (tournamentStarted &&
                          widget.user.favoriteTeam != null &&
                          widget.user.favoriteTeam!.isNotEmpty)
                      ? _countWins(widget.user.favoriteTeam!, matches) * 10
                      : null,
                  onSelected: (team) => _savePick(favoriteTeam: team),
                ),
                const SizedBox(height: 12),

                // 2. Favorit (WM-Sieger)
                _buildPickTile(
                  title: 'WM-Sieger Tipp (+10 Pkt./Sieg)',
                  value: widget.user.predictedChampion,
                  teams: teams,
                  disabled: tournamentStarted || _isSaving,
                  points: (tournamentStarted &&
                          widget.user.predictedChampion != null &&
                          widget.user.predictedChampion!.isNotEmpty)
                      ? _countWins(widget.user.predictedChampion!, matches) * 10
                      : null,
                  onSelected: (team) => _savePick(predictedChampion: team),
                ),
                const SizedBox(height: 12),

                // 3. Risiko-Tipp
                Text(
                  'WM-Risiko-Tipp (Gewinnen NICHT die WM)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                _buildPickTile(
                  title: 'Risiko-Mannschaft',
                  value: widget.user.riskTeam,
                  teams: teams,
                  groupByRiskTier: true,
                  disabled: tournamentStarted || _isSaving,
                  points: (tournamentStarted &&
                          widget.user.riskTeam != null &&
                          widget.user.riskTeam!.isNotEmpty &&
                          widget.user.riskStage != null &&
                          widget.user.riskStage!.isNotEmpty)
                      ? () {
                          return calculateCurrentRiskPoints(
                            widget.user.riskTeam!,
                            widget.user.riskStage!,
                            matches,
                          );
                        }()
                      : null,
                  onSelected: (team) =>
                      _savePick(riskTeam: team, riskStage: ''),
                ),
                const SizedBox(height: 12),
                _buildStageTile(
                  title: 'Ausscheidungs-Runde',
                  value: widget.user.riskStage,
                  disabled: tournamentStarted ||
                      _isSaving ||
                      widget.user.riskTeam == null ||
                      widget.user.riskTeam!.isEmpty,
                  onSelected: (stage) => _savePick(riskStage: stage),
                ),
                if (widget.user.riskTeam != null &&
                    widget.user.riskTeam!.isNotEmpty &&
                    widget.user.riskStage != null &&
                    widget.user.riskStage!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getRiskPointsInfo(
                          widget.user.riskTeam!, widget.user.riskStage!),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Counts how many completed matches [team] has won.
  int _countWins(String team, List<CupMatch> matches) {
    var wins = 0;
    for (final m in matches) {
      if (m.status != MatchStatus.finalResult) continue;
      final hs = m.homeScore;
      final as_ = m.awayScore;
      if (hs == null || as_ == null) continue;
      if (m.homeTeam == team && hs > as_) wins++;
      if (m.awayTeam == team && as_ > hs) wins++;
    }
    return wins;
  }

  Widget _buildPickTile({
    required String title,
    required String? value,
    required List<String> teams,
    required bool disabled,
    required ValueChanged<String> onSelected,
    bool groupByRiskTier = false,
    int? points,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    final flag = hasValue ? CountryFlags.getFlag(value) : '';
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: disabled
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Turnier-Picks können nach Turnierstart nicht mehr geändert werden.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              : () => _showTeamPickerDialog(
                    title,
                    value,
                    teams,
                    onSelected,
                    groupByRiskTier: groupByRiskTier,
                  ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            alignment: Alignment.centerLeft,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Row(
            children: [
              if (hasValue) ...[
                Text(flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                if (points != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${points >= 0 ? '+' : ''}$points Pkt.)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: points > 0
                          ? Colors.green
                          : (points < 0 ? Colors.red : Colors.grey),
                      fontSize: 13,
                    ),
                  ),
                ],
              ] else
                Text(
                  'Mannschaft wählen...',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
              const Spacer(),
              if (!disabled) const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageTile({
    required String title,
    required String? value,
    required bool disabled,
    required ValueChanged<String> onSelected,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: disabled
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Die Risiko-Ausscheidungsrunde kann nach Turnierstart nicht mehr geändert werden.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              : () => _showStagePickerDialog(value, onSelected),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            alignment: Alignment.centerLeft,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Row(
            children: [
              if (hasValue)
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                )
              else
                Text(
                  widget.user.riskTeam == null || widget.user.riskTeam!.isEmpty
                      ? 'Bitte zuerst Risiko-Mannschaft wählen...'
                      : 'Ausscheidungsrunde wählen...',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
              const Spacer(),
              if (!disabled) const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  void _showTeamPickerDialog(String title, String? selectedValue,
      List<String> teams, ValueChanged<String> onSelected,
      {bool groupByRiskTier = false}) {
    final groupedTeams = groupByRiskTier ? _teamsByRiskTier(teams) : null;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: groupByRiskTier
                ? ListView(
                    children: [
                      for (final entry in groupedTeams!.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                          child: Text(
                            entry.key,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        for (final team in entry.value)
                          _TeamPickerTile(
                            team: team,
                            selectedValue: selectedValue,
                            onSelected: onSelected,
                          ),
                      ],
                    ],
                  )
                : ListView.builder(
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      return _TeamPickerTile(
                        team: teams[index],
                        selectedValue: selectedValue,
                        onSelected: onSelected,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<String>> _teamsByRiskTier(List<String> teams) {
    final order = [
      'Absolute Titelfavoriten',
      'Top Team',
      'Durchschnittliches Team',
      'Gurkentruppe',
    ];
    return {
      for (final tier in order)
        tier: [
          for (final team in teams)
            if (getTier(team) == tier) team,
        ]..sort(),
    };
  }

  void _showStagePickerDialog(
    String? selectedValue,
    ValueChanged<String> onSelected,
  ) {
    final stages = [
      'Gruppenphase',
      'Sechzehntelfinale',
      'Achtelfinale',
      'Viertelfinale',
      'Halbfinale',
      'Finale'
    ];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Wann scheiden sie aus?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final stage in stages)
                ListTile(
                  title: Text(stage),
                  trailing: stage == selectedValue
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(stage);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  String _getRiskPointsInfo(String team, String stage) {
    final tier = getTier(team);
    final correct = calculateRiskPoints(team, stage, stage);
    final incorrect = -correct;
    return 'Risiko-Tier: $tier\nPluspunkte, wenn das Team spätestens im $stage ausscheidet: +$correct\nBleibt es länger im Turnier: $incorrect Punkte';
  }

  Future<void> _savePick({
    String? favoriteTeam,
    String? predictedChampion,
    String? riskTeam,
    String? riskStage,
  }) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(repositoryProvider).updateExtraPicks(
            favoriteTeam: favoriteTeam,
            predictedChampion: predictedChampion,
            riskTeam: riskTeam,
            riskStage: riskStage,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auswahl erfolgreich gespeichert.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _TeamPickerTile extends StatelessWidget {
  const _TeamPickerTile({
    required this.team,
    required this.selectedValue,
    required this.onSelected,
  });

  final String team;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final flag = CountryFlags.getFlag(team);
    final isSelected = team == selectedValue;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(team),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        Navigator.pop(context);
        onSelected(team);
      },
    );
  }
}

bool isPlaceholderTeam(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('sieger') ||
      lower.startsWith('zweiter') ||
      lower.startsWith('dritter') ||
      lower.startsWith('bester') ||
      lower.startsWith('verlierer') ||
      lower.contains('gruppe') ||
      lower.contains('sechzehntelfinale') ||
      lower.contains('achtelfinale') ||
      lower.contains('viertel') ||
      lower.contains('halb') ||
      lower.contains('platz 3') ||
      lower.contains('finale') ||
      lower.startsWith('tbd') ||
      lower.trim().isEmpty;
}
