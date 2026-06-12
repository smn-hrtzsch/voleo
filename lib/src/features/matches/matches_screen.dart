import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/clock.dart';
import '../../domain/flags.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';
import '../shared/live_pulse_dot.dart';
import '../shared/team_name_with_picks.dart';

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
  bool _swipeByDay = false;
  bool _didSetInitialDay = false;
  bool _didSetInitialFilters = false;
  int _selectedDayIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _determineCurrentStage(List<CupMatch> matches) {
    if (matches.isEmpty) return 'Alle';

    // 1. Find live matches
    final liveMatches =
        matches.where((m) => m.status == MatchStatus.live).toList();
    if (liveMatches.isNotEmpty) {
      return _roundFor(liveMatches.first);
    }

    // 2. Find next upcoming match (scheduled matches)
    final upcoming = matches
        .where((m) => m.status == MatchStatus.scheduled)
        .toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    if (upcoming.isNotEmpty) {
      return _roundFor(upcoming.first);
    }

    // 3. Fallback to last finished match
    final finished = matches
        .where((m) => m.status == MatchStatus.finalResult)
        .toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    if (finished.isNotEmpty) {
      return _roundFor(finished.last);
    }

    return 'Alle';
  }

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
    final user = ref.watch(userProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Spiele')),
      body: AsyncValueView<List<CupMatch>>(
        value: ref.watch(matchesProvider),
        data: (matches) {
          final sorted = [...matches]
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
          if (!_didSetInitialFilters) {
            _selectedRound = _determineCurrentStage(sorted);
            _didSetInitialFilters = true;
          }
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
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
                        children: [
                          _DayMatchCard(
                            day: day,
                            matches: days[day] ?? const <CupMatch>[],
                            tips: tips,
                            user: user,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ] else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
                    itemCount: dayKeys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final day = dayKeys[index];
                      return _DayMatchCard(
                        day: day,
                        matches: days[day] ?? const <CupMatch>[],
                        tips: tips,
                        user: user,
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
    final today = _dayFor(VoleoClock.now);
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
            showCheckmark: false,
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
            showFlags: true,
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
    this.showFlags = false,
  });

  final String label;
  final List<String> values;
  final ValueChanged<String> onSelected;
  final bool showFlags;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in values)
          PopupMenuItem(
            value: value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showFlags && value != 'Alle') ...[
                  Text(CountryFlags.getFlag(value),
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                ],
                Text(_labelFor(value)),
              ],
            ),
          ),
      ],
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showFlags && label != 'Mannschaft' && label != 'Alle') ...[
              Text(CountryFlags.getFlag(label),
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
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
    this.user,
  });

  final DateTime day;
  final List<CupMatch> matches;
  final List<Tip> tips;
  final VoleoUser? user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDay(day),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Tipp',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Divider(height: 1),
            ),
            for (final match in matches)
              _MatchRow(
                match: match,
                tip: _tipForMatch(tips, match),
                user: user,
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, this.tip, this.user});

  final CupMatch match;
  final Tip? tip;
  final VoleoUser? user;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(match.kickoff);
    final homeFlag = CountryFlags.getFlag(match.homeTeam);
    final awayFlag = CountryFlags.getFlag(match.awayTeam);
    final scheme = Theme.of(context).colorScheme;
    final isLive = match.status == MatchStatus.live;

    final hasProgression =
        match.otHomeScore != null || match.penaltyHomeScore != null;
    final progressionParts = <String>[];
    if (match.otHomeScore != null) {
      progressionParts.add('${match.otHomeScore}:${match.otAwayScore} n.V.');
    }
    if (match.penaltyHomeScore != null) {
      progressionParts
          .add('${match.penaltyHomeScore}:${match.penaltyAwayScore} i.E.');
    }
    final progressionText = progressionParts.join(' • ');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/matches/tip/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: isLive
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LivePulseDot(),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _TeamSlot(
                          teamName: match.homeTeam,
                          flag: homeFlag,
                          user: user,
                          isHome: true,
                          isWinner: false,
                          isLoser: false,
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: _buildScoreProgression(
                            context, match, scheme, isLive),
                      ),
                      Expanded(
                        child: _TeamSlot(
                          teamName: match.awayTeam,
                          flag: awayFlag,
                          user: user,
                          isHome: false,
                          isWinner: false,
                          isLoser: false,
                        ),
                      ),
                    ],
                  ),
                  if (hasProgression)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        progressionText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 48,
              child: Align(
                alignment: Alignment.center,
                child: tip != null
                    ? Text(
                        '${tip!.predictedHome}:${tip!.predictedAway}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                      )
                    : Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSlot extends StatelessWidget {
  const _TeamSlot({
    required this.teamName,
    required this.flag,
    required this.user,
    required this.isHome,
    this.isWinner = false,
    this.isLoser = false,
  });

  final String teamName;
  final String flag;
  final VoleoUser? user;
  final bool isHome;
  final bool isWinner;
  final bool isLoser;

  @override
  Widget build(BuildContext context) {
    final name = TeamNameWithPicks(
      teamName: teamName,
      user: user,
      isRightAligned: isHome,
      isWinner: isWinner,
      isLoser: isLoser,
    );
    final flagText = Text(flag, style: const TextStyle(fontSize: 21));
    final children = isHome
        ? <Widget>[
            Expanded(child: name),
            const SizedBox(width: 5),
            flagText,
          ]
        : <Widget>[
            flagText,
            const SizedBox(width: 5),
            Expanded(child: name),
          ];
    return Row(children: children);
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
    ..sort((a, b) => _roundOrder(a).compareTo(_roundOrder(b)));
  return ['Alle', ...rounds];
}

int _roundOrder(String round) {
  switch (round) {
    case 'Gruppenphase':
      return 1;
    case 'Sechzehntelfinale':
      return 2;
    case 'Achtelfinale':
      return 3;
    case 'Viertelfinale':
      return 4;
    case 'Halbfinale':
      return 5;
    case 'Spiel um Platz 3':
      return 6;
    case 'Finale':
      return 7;
    default:
      return 99;
  }
}

List<String> _teamsFor(List<CupMatch> matches) {
  final teams = {
    for (final match in matches) ...[match.homeTeam, match.awayTeam],
  }.where((t) => !isPlaceholderTeam(t)).toList()
    ..sort();
  return ['Alle', ...teams];
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

String _roundFor(CupMatch match) {
  if (match.stage.startsWith('Gruppe') || match.stage.contains('Runde')) {
    return 'Gruppenphase';
  }
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

Tip? _tipForMatch(List<Tip> tips, CupMatch match) {
  for (final tip in tips) {
    if (tip.matchId == match.id) return tip;
    if (match.originalId != null) {
      final cleanTipId = tip.matchId.replaceAll('openligadb-', '');
      final cleanOrigId = match.originalId!.replaceAll('openligadb-', '');
      if (cleanTipId == cleanOrigId) return tip;
    }
  }
  return null;
}

Widget _buildScoreProgression(
    BuildContext context, CupMatch match, ColorScheme scheme, bool isLive) {
  if (match.status != MatchStatus.finalResult &&
      match.status != MatchStatus.live) {
    return Text(
      '-:-',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
    );
  }

  final mainHome = match.regularHomeScore ?? match.homeScore ?? 0;
  final mainAway = match.regularAwayScore ?? match.awayScore ?? 0;

  return Text(
    '$mainHome:$mainAway',
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isLive ? Colors.green : scheme.primary,
        ),
  );
}
