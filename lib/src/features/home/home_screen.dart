import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/flags.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    final league = ref.watch(leagueProvider);
    final leagueValue = league.value;
    final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
    final standings = ref.watch(standingsProvider).value ?? const <Standing>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Voleo')),
      body: AsyncValueView<List<CupMatch>>(
        value: matches,
        data: (items) {
          final now = DateTime.now();
          final todayMatches = items
              .where((match) => _isSameDay(match.kickoff, now))
              .toList()
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LeagueHero(
                title: leagueValue?.name ?? 'WM-Runde',
                inviteCode: leagueValue?.inviteCode ?? 'VOLEO26',
                imageUrl: leagueValue?.imageUrl,
                onTap: () => context.go('/league'),
              ),
              const SizedBox(height: 16),
              _TopThreeCard(standings: standings),
              const SizedBox(height: 20),
              Text('Heute', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                todayMatches.isEmpty
                    ? 'Heute finden keine Spiele statt.'
                    : '${todayMatches.length} Spiele finden heute statt.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              for (final match in todayMatches)
                _MatchCard(
                  match: match,
                  tip: _tipForMatch(tips, match.id),
                  onTap: () => context.go('/home/tip/${match.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Tip? _tipForMatch(List<Tip> tips, String matchId) {
  for (final tip in tips) {
    if (tip.matchId == matchId) return tip;
  }
  return null;
}

class _LeagueHero extends StatelessWidget {
  const _LeagueHero({
    required this.title,
    required this.inviteCode,
    required this.onTap,
    this.imageUrl,
  });

  final String title;
  final String inviteCode;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = imageUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 132,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null && image.isNotEmpty)
                Image.network(image, fit: BoxFit.cover)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                  ),
                ),
              ColoredBox(color: Colors.black.withValues(alpha: 0.24)),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Code $inviteCode',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white, size: 34),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopThreeCard extends StatelessWidget {
  const _TopThreeCard({required this.standings});

  final List<Standing> standings;

  @override
  Widget build(BuildContext context) {
    final topThree = standings.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard_outlined),
                const SizedBox(width: 8),
                Text(
                  'Top 3 Liga',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (topThree.isEmpty)
              const Text('Noch keine Punkte vergeben.')
            else
              for (final standing in topThree)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: _StandingAvatar(standing: standing),
                  title: Text(
                    standing.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${standing.totalPoints} Pkt.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StandingAvatar extends StatelessWidget {
  const _StandingAvatar({required this.standing});

  final Standing standing;

  @override
  Widget build(BuildContext context) {
    final photoUrl = standing.photoUrl;
    final imageProvider = photoUrl == null || photoUrl.isEmpty
        ? null
        : photoUrl.startsWith('http')
            ? NetworkImage(photoUrl) as ImageProvider
            : FileImage(File(photoUrl));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Text(standing.displayName.characters.first.toUpperCase())
              : null,
        ),
        Positioned(
          right: -3,
          bottom: -3,
          child: CircleAvatar(
            radius: 10,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              '${standing.rank}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 10,
                  ),
            ),
          ),
        ),
      ],
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
    final homeFlag = CountryFlags.getFlag(match.homeTeam);
    final awayFlag = CountryFlags.getFlag(match.awayTeam);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.sports_soccer),
        title:
            Text('$homeFlag ${match.homeTeam} - ${match.awayTeam} $awayFlag'),
        subtitle: Text('${match.stage} · $date Uhr'),
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
