import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../../providers.dart';
import '../shared/app_toast.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  final _nicknameController = TextEditingController();
  final _inviteController = TextEditingController();
  final _leagueNameController = TextEditingController(text: 'Meine WM-Runde');
  bool _isLoading = false;
  String _step2Mode = ''; // 'join' or 'create' or ''
  bool _didHandleCachedInvite = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _inviteController.dispose();
    _leagueNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(userProvider, (prev, next) {
      final user = next.value;
      if (user == null) {
        setState(() {
          _currentStep = 0;
          _step2Mode = '';
        });
        return;
      }

      final code = ref.read(cachedInviteCodeProvider);
      if (code != null && !_didHandleCachedInvite) {
        _didHandleCachedInvite = true;
        _handleAutoJoin(code);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Voleo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'WM 2026 Tippspiel',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              _buildStepProgress(),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 32),
              if (_currentStep == 0)
                _buildNicknameStep(colorScheme)
              else if (_currentStep == 1)
                _buildLinkAccountStep(colorScheme)
              else
                _buildLeagueStep(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == _currentStep;
        final isDone = index < _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActive ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : (isDone ? activeColor.withAlpha(153) : inactiveColor),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  Widget _buildNicknameStep(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wie möchtest du heißen?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Dieser Name wird in den Tipprunden und Bestenlisten angezeigt.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nicknameController,
          textInputAction: TextInputAction.done,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Dein Spitzname',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onSubmitted: (_) => _submitNickname(),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isLoading ? null : _submitNickname,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Weiter'),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Bereits registriert?',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _signInWithGoogle,
          icon:
              SvgPicture.asset('assets/google_logo.svg', width: 18, height: 18),
          label: const Text('Mit Google anmelden'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _signInWithApple,
          icon: const FaIcon(FontAwesomeIcons.apple, size: 20),
          label: const Text('Mit Apple anmelden'),
        ),
      ],
    );
  }

  Widget _buildLinkAccountStep(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Konto sichern',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Verknüpfe dein Konto, damit deine Tipps und Punkte gerettet sind, falls du die App neu installierst.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _linkGoogle,
          icon:
              SvgPicture.asset('assets/google_logo.svg', width: 20, height: 20),
          label: const Text('Mit Google verknüpfen'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _linkApple,
          icon: const FaIcon(FontAwesomeIcons.apple, size: 22),
          label: const Text('Mit Apple verknüpfen'),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _currentStep = 2;
                  });
                },
          child: const Text('Überspringen & Später verknüpfen'),
        ),
        TextButton.icon(
          onPressed: _isLoading ? null : () => setState(() => _currentStep = 0),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Zurück'),
        ),
      ],
    );
  }

  Widget _buildLeagueStep(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Runde auswählen',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Tritt einer bestehenden Tipprunde bei oder erstelle deine eigene, um zu starten.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          elevation: _step2Mode == 'join' ? 2 : 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _step2Mode == 'join'
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _step2Mode = 'join';
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.group_add_outlined,
                        color: _step2Mode == 'join'
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Einer Tipprunde beitreten',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _step2Mode == 'join'
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                ),
                      ),
                    ],
                  ),
                  if (_step2Mode == 'join') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _inviteController,
                      textCapitalization: TextCapitalization.characters,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Einladungscode',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _joinLeague,
                      child: const Text('Tipprunde beitreten'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: _step2Mode == 'create' ? 2 : 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _step2Mode == 'create'
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _step2Mode = 'create';
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: _step2Mode == 'create'
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Eigene Tipprunde erstellen',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _step2Mode == 'create'
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                ),
                      ),
                    ],
                  ),
                  if (_step2Mode == 'create') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _leagueNameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Name der Tipprunde',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _createLeague,
                      child: const Text('Tipprunde erstellen'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _isLoading ? null : () => setState(() => _currentStep = 1),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Zurück'),
        ),
      ],
    );
  }

  Future<void> _submitNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      showAppToast(context, 'Bitte einen Namen eingeben.',
          type: AppToastType.error);
      return;
    }
    setState(() => _isLoading = true);
    try {
      ref.read(forceOnboardingProvider.notifier).value = false;
      final repo = ref.read(repositoryProvider);
      if (auth.FirebaseAuth.instance.currentUser == null) {
        await auth.FirebaseAuth.instance.signInAnonymously();
      }
      await repo.updateProfile(nickname: nickname);
      if (!mounted) return;
      setState(() {
        _currentStep = 1;
      });
    } catch (e) {
      if (mounted) {
        showAppToast(context, _formatError('Speichern fehlgeschlagen', e),
            type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLoading = true);
    try {
      ref.read(forceOnboardingProvider.notifier).value = false;
      await ref.read(repositoryProvider).linkWithGoogle();
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
      });
    } catch (e) {
      await _handleLinkError(
        error: e,
        providerName: 'Google-Konto',
        retryLink: _linkGoogle,
        switchCredential: e is auth.FirebaseAuthException ? e.credential : null,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkApple() async {
    setState(() => _isLoading = true);
    try {
      ref.read(forceOnboardingProvider.notifier).value = false;
      await ref.read(repositoryProvider).linkWithApple();
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
      });
    } catch (e) {
      await _handleLinkError(
        error: e,
        providerName: 'Apple-Konto',
        retryLink: _linkApple,
        switchCredential: e is auth.FirebaseAuthException ? e.credential : null,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      ref.read(forceOnboardingProvider.notifier).value = false;
      await ref.read(repositoryProvider).signInWithGoogle();
      if (mounted) {
        setState(() => _currentStep = 2);
      }
    } catch (e) {
      if (_isUserCanceledAuth(e)) return;
      if (mounted) {
        showAppToast(context, _formatError('Login fehlgeschlagen', e),
            type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      ref.read(forceOnboardingProvider.notifier).value = false;
      await ref.read(repositoryProvider).signInWithApple();
      if (mounted) {
        setState(() => _currentStep = 2);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, _formatError('Login fehlgeschlagen', e),
            type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinLeague() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty) {
      showAppToast(context, 'Bitte Einladungscode eingeben.',
          type: AppToastType.error);
      return;
    }
    if (!_hasActiveFirebaseSession()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).joinLeague(inviteCode: code);
    } catch (e) {
      if (mounted) {
        showAppToast(context, _formatError('Beitritt fehlgeschlagen', e),
            type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createLeague() async {
    final name = _leagueNameController.text.trim();
    if (name.isEmpty) {
      showAppToast(context, 'Bitte einen Namen für die Runde eingeben.',
          type: AppToastType.error);
      return;
    }
    if (!_hasActiveFirebaseSession()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).createLeague(name: name);
    } catch (e) {
      if (mounted) {
        showAppToast(context, _formatError('Erstellung fehlgeschlagen', e),
            type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAutoJoin(String code) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).joinLeague(inviteCode: code);
      ref.read(cachedInviteCodeProvider.notifier).value = null;
    } catch (e) {
      ref.read(cachedInviteCodeProvider.notifier).value = null;
      if (mounted) {
        showAppToast(
          context,
          _formatError(
              'Automatischer Beitritt zur Runde $code fehlgeschlagen', e),
          type: AppToastType.error,
        );
      }
      setState(() {
        _currentStep = 2;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _hasActiveFirebaseSession() {
    if (auth.FirebaseAuth.instance.currentUser != null) return true;
    setState(() {
      _currentStep = 0;
      _step2Mode = '';
    });
    showAppToast(context, 'Bitte lege zuerst einen Spitznamen fest.',
        type: AppToastType.error);
    return false;
  }

  Future<void> _handleLinkError({
    required Object error,
    required String providerName,
    required Future<void> Function() retryLink,
    required auth.AuthCredential? switchCredential,
  }) async {
    if (!mounted) return;
    if (_isUserCanceledAuth(error)) return;
    if (error is! auth.FirebaseAuthException ||
        !_isAlreadyLinkedError(error.code)) {
      showAppToast(context, _formatError('Verknüpfung fehlgeschlagen', error),
          type: AppToastType.error);
      return;
    }

    setState(() => _isLoading = false);
    if (error.code == 'provider-already-linked') {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('$providerName bereits verknüpft'),
            content: Text(
              'Dieses $providerName ist bereits mit deinem aktuellen Voleo-Konto verknüpft.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

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
    if (choice == _LinkedAccountChoice.switchAccount) {
      if (switchCredential == null) {
        showAppToast(
          context,
          'Dieses Konto kann nicht direkt gewechselt werden. Bitte melde dich über den Startbildschirm an.',
          type: AppToastType.error,
        );
        return;
      }
      await _signInWithExistingCredential(switchCredential);
    } else {
      await retryLink();
    }
  }

  Future<void> _signInWithExistingCredential(
    auth.AuthCredential credential,
  ) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).signInWithCredential(credential);
      if (mounted) setState(() => _currentStep = 2);
    } catch (e) {
      if (mounted) {
        showAppToast(context, _formatError('Konto-Wechsel fehlgeschlagen', e),
            type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isAlreadyLinkedError(String code) {
    return code == 'credential-already-in-use' ||
        code == 'account-exists-with-different-credential' ||
        code == 'email-already-in-use' ||
        code == 'provider-already-linked';
  }

  String _formatError(String prefix, Object error) {
    if (error is auth.FirebaseAuthException) {
      return '$prefix: ${_authErrorMessage(error.code)}';
    }
    final raw = error.toString();
    if (raw.contains('permission-denied') ||
        raw.contains('PERMISSION_DENIED')) {
      return '$prefix: Keine Berechtigung in Firestore. Bitte Regeln deployen.';
    }
    if (raw.contains('not-found') || raw.contains('nicht gefunden')) {
      return '$prefix: Diese Tipprunde wurde nicht gefunden.';
    }
    return '$prefix: $raw';
  }

  String _authErrorMessage(String code) {
    return switch (code) {
      'credential-already-in-use' ||
      'account-exists-with-different-credential' ||
      'email-already-in-use' =>
        'Dieses Konto ist bereits mit einem anderen Voleo-Konto verknüpft.',
      'provider-already-linked' =>
        'Dieser Anbieter ist bereits mit diesem Voleo-Konto verknüpft.',
      'network-request-failed' => 'Netzwerkfehler. Bitte Verbindung prüfen.',
      'user-disabled' => 'Dieses Konto wurde deaktiviert.',
      _ => code,
    };
  }

  bool _isUserCanceledAuth(Object error) {
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
