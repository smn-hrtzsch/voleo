import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../../providers.dart';

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

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider).value;
    if (user != null) {
      _currentStep = user.isAnonymous ? 1 : 2;
    }
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
      if (user != null) {
        final code = ref.read(cachedInviteCodeProvider);
        if (code != null) {
          _handleAutoJoin(code);
        } else {
          setState(() {
            _currentStep = user.isAnonymous ? 1 : 2;
          });
        }
      }
    });

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Einen Moment bitte...'),
            ],
          ),
        ),
      );
    }

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
          onPressed: _submitNickname,
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
          onPressed: _signInWithGoogle,
          icon: SvgPicture.asset('assets/google_logo.svg', width: 18, height: 18),
          label: const Text('Mit Google anmelden'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _signInWithApple,
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
          onPressed: _linkGoogle,
          icon: SvgPicture.asset('assets/google_logo.svg', width: 20, height: 20),
          label: const Text('Mit Google verknüpfen'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _linkApple,
          icon: const FaIcon(FontAwesomeIcons.apple, size: 22),
          label: const Text('Mit Apple verknüpfen'),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () {
            setState(() {
              _currentStep = 2;
            });
          },
          child: const Text('Überspringen & Später verknüpfen'),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                        labelText: 'Einladungscode (z.B. BLFPKY)',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _joinLeague,
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                      onPressed: _createLeague,
                      child: const Text('Tipprunde erstellen'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Namen eingeben.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(repositoryProvider);
      if (auth.FirebaseAuth.instance.currentUser == null) {
        await auth.FirebaseAuth.instance.signInAnonymously();
      }
      await repo.updateProfile(nickname: nickname);
      setState(() {
        _currentStep = 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).linkWithGoogle();
      setState(() {
        _currentStep = 2;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verknüpfung fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkApple() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).linkWithApple();
      setState(() {
        _currentStep = 2;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verknüpfung fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).signInWithApple();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinLeague() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Einladungscode eingeben.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).joinLeague(inviteCode: code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beitritt fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createLeague() async {
    final name = _leagueNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Namen für die Runde eingeben.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(repositoryProvider).createLeague(name: name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erstellung fehlgeschlagen: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Automatischer Beitritt zur Runde $code fehlgeschlagen: $e')),
        );
      }
      setState(() {
        _currentStep = 2;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
