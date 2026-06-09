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
  bool _swipeByDay = false;
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
    final user = ref.watch(userProvider).value;
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
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
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
                tip: _tipForMatch(tips, match.id),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go('/matches/tip/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                time,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _TeamSlot(
                      teamName: match.homeTeam,
                      flag: homeFlag,
                      user: user,
                      isHome: true,
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      match.status == MatchStatus.finalResult
                          ? '${match.homeScore}:${match.awayScore}'
                          : '-:-',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: match.status == MatchStatus.finalResult
                                ? scheme.primary
                                : scheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                          ),
                    ),
                  ),
                  Expanded(
                    child: _TeamSlot(
                      teamName: match.awayTeam,
                      flag: awayFlag,
                      user: user,
                      isHome: false,
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
  });

  final String teamName;
  final String flag;
  final VoleoUser? user;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final name =
        _buildTeamName(context, teamName, user, isRightAligned: isHome);
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

Widget _buildTeamName(
  BuildContext context,
  String teamName,
  VoleoUser? user, {
  required bool isRightAligned,
}) {
  final List<Widget> markers = [];
  if (user != null) {
    if (user.favoriteTeam == teamName) {
      markers.add(
        const Icon(
          Icons.star,
          color: Colors.amber,
          size: 14,
        ),
      );
    }
    if (user.predictedChampion == teamName) {
      markers.add(
        const Icon(
          Icons.sports_soccer,
          color: Colors.blue,
          size: 14,
        ),
      );
    }
    if (user.riskTeam == teamName) {
      markers.add(
        const Icon(
          Icons.close,
          color: Colors.red,
          size: 14,
        ),
      );
    }
  }

  final textWidget = Text(
    teamName,
    textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
    maxLines: 2,
    softWrap: true,
    overflow: TextOverflow.ellipsis,
  );

  if (markers.isEmpty) {
    return textWidget;
  }

  final List<Widget> children = [];
  if (isRightAligned) {
    for (var i = 0; i < markers.length; i++) {
      children.add(markers[i]);
      children.add(const SizedBox(width: 2));
    }
    children.add(Flexible(child: textWidget));
  } else {
    children.add(Flexible(child: textWidget));
    for (var i = 0; i < markers.length; i++) {
      children.add(const SizedBox(width: 2));
      children.add(markers[i]);
    }
  }

  return Row(
    mainAxisAlignment:
        isRightAligned ? MainAxisAlignment.end : MainAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: children,
  );
}
