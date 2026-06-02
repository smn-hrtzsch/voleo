import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/app_shell.dart';
import '../shared/async_value_view.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  final _pageController = PageController();
  String _selectedGroup = 'Alle';
  int _selectedDayIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(tipsProvider).valueOrNull ?? const <Tip>[];
    return AppShell(
      title: 'Spiele',
      selectedIndex: 1,
      child: AsyncValueView<List<CupMatch>>(
        value: ref.watch(matchesProvider),
        data: (matches) {
          final sorted = [...matches]
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
          final groups = [
            'Alle',
            ...{
              for (final match in sorted)
                if (match.group.isNotEmpty) match.group
            }.toList()
              ..sort(),
          ];
          final filtered = _selectedGroup == 'Alle'
              ? sorted
              : sorted.where((match) => match.group == _selectedGroup).toList();
          final days = _groupByDay(filtered);
          final dayKeys = days.keys.toList()..sort();
          final safeDayIndex = dayKeys.isEmpty
              ? 0
              : _selectedDayIndex.clamp(0, dayKeys.length - 1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ChoiceChip(
                      label: Text(
                          group == 'Alle' ? 'Alle Gruppen' : 'Gruppe $group'),
                      selected: group == _selectedGroup,
                      onSelected: (_) {
                        setState(() {
                          _selectedGroup = group;
                          _selectedDayIndex = 0;
                        });
                        _pageController.jumpToPage(0);
                      },
                    );
                  },
                ),
              ),
              if (dayKeys.isEmpty)
                const Expanded(
                  child: Center(child: Text('Keine Spiele für diesen Filter.')),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: safeDayIndex == 0
                            ? null
                            : () => _goToDay(safeDayIndex - 1),
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Vorheriger Spieltag',
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _formatDay(dayKeys[safeDayIndex]),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${safeDayIndex + 1} von ${dayKeys.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: safeDayIndex == dayKeys.length - 1
                            ? null
                            : () => _goToDay(safeDayIndex + 1),
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Nächster Spieltag',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: dayKeys.length,
                    onPageChanged: (index) {
                      setState(() => _selectedDayIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final dayMatches =
                          days[dayKeys[index]] ?? const <CupMatch>[];
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: dayMatches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, matchIndex) {
                          final match = dayMatches[matchIndex];
                          return _MatchCard(
                            match: match,
                            tip: _tipForMatch(tips, match.id),
                            onTap: () => context.go('/tip/${match.id}'),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _goToDay(int index) {
    setState(() => _selectedDayIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

Map<DateTime, List<CupMatch>> _groupByDay(List<CupMatch> matches) {
  final result = <DateTime, List<CupMatch>>{};
  for (final match in matches) {
    final day =
        DateTime(match.kickoff.year, match.kickoff.month, match.kickoff.day);
    result.putIfAbsent(day, () => []).add(match);
  }
  return result;
}

String _formatDay(DateTime day) {
  const weekdays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  return '${weekdays[day.weekday - 1]}, ${DateFormat('dd.MM.yyyy').format(day)}';
}

Tip? _tipForMatch(List<Tip> tips, String matchId) {
  for (final tip in tips) {
    if (tip.matchId == matchId) return tip;
  }
  return null;
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.onTap,
    this.tip,
  });

  final CupMatch match;
  final Tip? tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(match.kickoff);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: _StatusIcon(status: match.status),
        title: Text('${match.homeTeam} - ${match.awayTeam}'),
        subtitle: Text('${match.stage} · Anpfiff $time Uhr'),
        trailing: match.status == MatchStatus.finalResult
            ? _ScoreBadge(
                label: 'Ergebnis',
                score: '${match.homeScore}:${match.awayScore}',
                isResult: true,
              )
            : tip == null
                ? Text('Tippen', style: TextStyle(color: scheme.primary))
                : _ScoreBadge(
                    label: 'Tipp',
                    score: '${tip!.predictedHome}:${tip!.predictedAway}',
                  ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.label,
    required this.score,
    this.isResult = false,
  });

  final String label;
  final String score;
  final bool isResult;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isResult ? scheme.primaryContainer : scheme.secondaryContainer,
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

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MatchStatus.scheduled => const Icon(Icons.schedule),
      MatchStatus.live => const Icon(Icons.radar),
      MatchStatus.finalResult => const Icon(Icons.check_circle),
    };
  }
}
