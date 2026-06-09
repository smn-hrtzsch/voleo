import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/flags.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  final _pageController = PageController();
  String _selectedGroup = 'Alle';
  String _selectedRound = 'Alle';
  String _selectedTeam = 'Alle';
  bool _swipeByDay = true;
  bool _didSetInitialDay = false;
  int _selectedDayIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Spiele')),
      body: AsyncValueView<List<CupMatch>>(
        value: ref.watch(matchesProvider),
        data: (matches) {
          final sorted = [...matches]
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
          final groups = _groupsFor(sorted);
          final rounds = _roundsFor(sorted);
          final teams = _teamsFor(sorted);
          final filtered = sorted.where((match) {
            final groupMatches =
                _selectedGroup == 'Alle' || match.group == _selectedGroup;
            final roundMatches =
                _selectedRound == 'Alle' || _roundFor(match) == _selectedRound;
            final teamMatches = _selectedTeam == 'Alle' ||
                match.homeTeam == _selectedTeam ||
                match.awayTeam == _selectedTeam;
            return groupMatches && roundMatches && teamMatches;
          }).toList();
          final days = _groupByDay(filtered);
          final dayKeys = days.keys.toList()..sort();
          _setInitialDay(dayKeys);
          final safeDayIndex = dayKeys.isEmpty
              ? 0
              : _selectedDayIndex.clamp(0, dayKeys.length - 1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterRail(
                swipeByDay: _swipeByDay,
                selectedRound: _selectedRound,
                selectedTeam: _selectedTeam,
                selectedGroup: _selectedGroup,
                rounds: rounds,
                teams: teams,
                groups: groups,
                onToggleDateMode: () {
                  setState(() => _swipeByDay = !_swipeByDay);
                },
                onRoundChanged: (value) => _changeFilter(round: value),
                onTeamChanged: (value) => _changeFilter(team: value),
                onGroupChanged: (value) => _changeFilter(group: value),
              ),
              if (dayKeys.isEmpty)
                const Expanded(
                  child: Center(child: Text('Keine Spiele für diesen Filter.')),
                )
              else if (_swipeByDay) ...[
                _DaySwitcher(
                  day: dayKeys[safeDayIndex],
                  index: safeDayIndex,
                  count: dayKeys.length,
                  onPrevious: safeDayIndex == 0
                      ? null
                      : () => _goToDay(safeDayIndex - 1),
                  onNext: safeDayIndex == dayKeys.length - 1
                      ? null
                      : () => _goToDay(safeDayIndex + 1),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: dayKeys.length,
                    onPageChanged: (index) {
                      setState(() => _selectedDayIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final day = dayKeys[index];
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        children: [
                          _DayMatchCard(
                            day: day,
                            matches: days[day] ?? const <CupMatch>[],
                            tips: tips,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ] else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    itemCount: dayKeys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final day = dayKeys[index];
                      return _DayMatchCard(
                        day: day,
                        matches: days[day] ?? const <CupMatch>[],
                        tips: tips,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _setInitialDay(List<DateTime> dayKeys) {
    if (_didSetInitialDay || dayKeys.isEmpty) return;
    _didSetInitialDay = true;
    final today = _dayFor(DateTime.now());
    final todayIndex = dayKeys.indexWhere((day) => day == today);
    final nextIndex = dayKeys.indexWhere((day) => day.isAfter(today));
    final index = todayIndex != -1
        ? todayIndex
        : nextIndex != -1
            ? nextIndex
            : dayKeys.length - 1;
    _selectedDayIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  void _changeFilter({String? round, String? team, String? group}) {
    setState(() {
      _selectedRound = round ?? _selectedRound;
      _selectedTeam = team ?? _selectedTeam;
      _selectedGroup = group ?? _selectedGroup;
      _selectedDayIndex = 0;
      _didSetInitialDay = false;
    });
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

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.swipeByDay,
    required this.selectedRound,
    required this.selectedTeam,
    required this.selectedGroup,
    required this.rounds,
    required this.teams,
    required this.groups,
    required this.onToggleDateMode,
    required this.onRoundChanged,
    required this.onTeamChanged,
    required this.onGroupChanged,
  });

  final bool swipeByDay;
  final String selectedRound;
  final String selectedTeam;
  final String selectedGroup;
  final List<String> rounds;
  final List<String> teams;
  final List<String> groups;
  final VoidCallback onToggleDateMode;
  final ValueChanged<String> onRoundChanged;
  final ValueChanged<String> onTeamChanged;
  final ValueChanged<String> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            selected: swipeByDay,
            label: Text(swipeByDay ? 'Datum · Swipe' : 'Datum · Liste'),
            avatar: const Icon(Icons.calendar_today_outlined, size: 18),
            onSelected: (_) => onToggleDateMode(),
          ),
          const SizedBox(width: 8),
          _MenuChip(
            label: selectedRound == 'Alle' ? 'Runde' : selectedRound,
            values: rounds,
            onSelected: onRoundChanged,
          ),
          const SizedBox(width: 8),
          _MenuChip(
            label: selectedTeam == 'Alle' ? 'Mannschaft' : selectedTeam,
            values: teams,
            onSelected: onTeamChanged,
          ),
          const SizedBox(width: 8),
          _MenuChip(
            label: selectedGroup == 'Alle' ? 'Gruppe' : 'Gruppe $selectedGroup',
            values: groups,
            onSelected: onGroupChanged,
          ),
        ],
      ),
    );
  }
}

class _MenuChip extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.values,
    required this.onSelected,
  });

  final String label;
  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in values)
          PopupMenuItem(value: value, child: Text(_labelFor(value))),
      ],
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.expand_more, size: 18),
      ),
    );
  }

  String _labelFor(String value) {
    if (value == 'Alle') return 'Alle';
    if (RegExp(r'^[A-L]$').hasMatch(value)) return 'Gruppe $value';
    return value;
  }
}

class _DaySwitcher extends StatelessWidget {
  const _DaySwitcher({
    required this.day,
    required this.index,
    required this.count,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime day;
  final int index;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _formatDay(day),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${index + 1} von $count',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _DayMatchCard extends StatelessWidget {
  const _DayMatchCard({
    required this.day,
    required this.matches,
    required this.tips,
  });

  final DateTime day;
  final List<CupMatch> matches;
  final List<Tip> tips;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDay(day),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final match in matches)
              _MatchRow(
                match: match,
                tip: _tipForMatch(tips, match.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, this.tip});

  final CupMatch match;
  final Tip? tip;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(match.kickoff);
    final homeFlag = CountryFlags.getFlag(match.homeTeam);
    final awayFlag = CountryFlags.getFlag(match.awayTeam);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go('/matches/tip/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                match.homeTeam,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(homeFlag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            SizedBox(
              width: 50,
              child: Text(
                match.status == MatchStatus.finalResult
                    ? '${match.homeScore}:${match.awayScore}'
                    : time,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: match.status == MatchStatus.finalResult
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Text(awayFlag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                match.awayTeam,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (tip != null)
              Text(
                '${tip!.predictedHome}:${tip!.predictedAway}',
                style: Theme.of(context).textTheme.labelLarge,
              )
            else
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

Map<DateTime, List<CupMatch>> _groupByDay(List<CupMatch> matches) {
  final result = <DateTime, List<CupMatch>>{};
  for (final match in matches) {
    final day = _dayFor(match.kickoff);
    result.putIfAbsent(day, () => []).add(match);
  }
  return result;
}

DateTime _dayFor(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

List<String> _groupsFor(List<CupMatch> matches) {
  return [
    'Alle',
    ...{
      for (final match in matches)
        if (match.group.isNotEmpty) match.group,
    }.toList()
      ..sort(),
  ];
}

List<String> _roundsFor(List<CupMatch> matches) {
  final rounds = {for (final match in matches) _roundFor(match)}.toList()
    ..sort();
  return ['Alle', ...rounds];
}

List<String> _teamsFor(List<CupMatch> matches) {
  final teams = {
    for (final match in matches) ...[match.homeTeam, match.awayTeam],
  }.toList()
    ..sort();
  return ['Alle', ...teams];
}

String _roundFor(CupMatch match) {
  if (match.stage.startsWith('Gruppe')) return 'Gruppenphase';
  return match.stage.isEmpty ? 'Gruppenphase' : match.stage;
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
  return '${weekdays[day.weekday - 1]}, ${DateFormat('dd.MM.').format(day)}';
}

Tip? _tipForMatch(List<Tip> tips, String matchId) {
  for (final tip in tips) {
    if (tip.matchId == matchId) return tip;
  }
  return null;
}
