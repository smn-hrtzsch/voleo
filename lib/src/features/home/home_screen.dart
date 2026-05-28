import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/app_shell.dart';
import '../shared/async_value_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    final league = ref.watch(leagueProvider);

    return AppShell(
      title: 'Voleo',
      selectedIndex: 0,
      child: AsyncValueView<List<CupMatch>>(
        value: matches,
        data: (items) {
          final nextMatches = items.take(3).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              league.when(
                data: (value) => _LeagueHero(
                  title: value?.name ?? 'WM-Runde',
                  inviteCode: value?.inviteCode ?? 'VOLEO26',
                ),
                error: (_, __) => const SizedBox.shrink(),
                loading: () => const LinearProgressIndicator(),
              ),
              const SizedBox(height: 16),
              Text('Naechste Spiele',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final match in nextMatches)
                _MatchCard(
                  match: match,
                  onTap: () => context.go('/tip/${match.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LeagueHero extends StatelessWidget {
  const _LeagueHero({required this.title, required this.inviteCode});

  final String title;
  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Code $inviteCode'),
              ],
            ),
          ),
          Icon(Icons.emoji_events, color: scheme.primary, size: 40),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.onTap});

  final CupMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd.MM. HH:mm').format(match.kickoff);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.sports_soccer),
        title: Text('${match.homeTeam} - ${match.awayTeam}'),
        subtitle: Text('${match.stage} · $date'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
