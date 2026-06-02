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
    final tips = ref.watch(tipsProvider).valueOrNull ?? const <Tip>[];

    return AppShell(
      title: 'Voleo',
      selectedIndex: 0,
      child: AsyncValueView<List<CupMatch>>(
        value: matches,
        data: (items) {
          final now = DateTime.now();
          final nextMatches = items
              .where((match) => match.kickoff.isAfter(now))
              .toList()
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
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
              Text('Nächste offene Tipps',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${nextMatches.length} Spiele sind noch tippbar. Tipps sind bis zum Anpfiff möglich.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              for (final match in nextMatches)
                _MatchCard(
                  match: match,
                  tip: _tipForMatch(tips, match.id),
                  onTap: () => context.go('/tip/${match.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

Tip? _tipForMatch(List<Tip> tips, String matchId) {
  for (final tip in tips) {
    if (tip.matchId == matchId) return tip;
  }
  return null;
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
  const _MatchCard({required this.match, required this.onTap, this.tip});

  final CupMatch match;
  final Tip? tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd.MM. HH:mm').format(match.kickoff);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.sports_soccer),
        title: Text('${match.homeTeam} - ${match.awayTeam}'),
        subtitle: Text('${match.stage} · Anpfiff $date Uhr'),
        trailing: tip == null
            ? const Icon(Icons.chevron_right)
            : _ScoreBadge(
                label: 'Tipp',
                score: '${tip!.predictedHome}:${tip!.predictedAway}',
              ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.label, required this.score});

  final String label;
  final String score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontSize: 10, height: 1),
              ),
              const SizedBox(width: 6),
              Text(
                score,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(height: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
