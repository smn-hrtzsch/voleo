import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';

class JoinLeagueScreen extends ConsumerStatefulWidget {
  const JoinLeagueScreen({required this.inviteCode, super.key});

  final String inviteCode;

  @override
  ConsumerState<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends ConsumerState<JoinLeagueScreen> {
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProvider).value;
      if (user == null) {
        ref.read(cachedInviteCodeProvider.notifier).value = widget.inviteCode;
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    final leagues = ref.watch(leaguesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Einladung')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            Icons.group_add_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Tipprunde beitreten',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Code ${widget.inviteCode.toUpperCase()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          if (user == null)
            const Text(
              'Erstelle zuerst dein Profil. Danach kannst du den Link erneut öffnen oder den Code eingeben.',
              textAlign: TextAlign.center,
            )
          else if (leagues.isEmpty)
            const Text(
              'Du trittst dieser Tipprunde bei und sie wird als aktive Liga gesetzt.',
              textAlign: TextAlign.center,
            )
          else
            Text(
              'Du bleibst Mitglied deiner bisherigen Tipprunden. Diese Einladung wird als weitere Liga hinzugefügt und danach aktiv gesetzt.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: user == null || _isJoining ? null : _joinLeague,
            icon: _isJoining
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Beitreten'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(user == null ? '/' : '/league'),
            child: Text(user == null ? 'Zum Start' : 'Zur Liga'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinLeague() async {
    setState(() => _isJoining = true);
    try {
      await ref
          .read(repositoryProvider)
          .joinLeague(inviteCode: widget.inviteCode);
      if (mounted) context.go('/league');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beitritt fehlgeschlagen: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }
}
