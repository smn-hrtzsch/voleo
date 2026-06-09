import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';

class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key});

  @override
  ConsumerState<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends ConsumerState<LeagueScreen> {
  String? _selectedPhase;

  @override
  Widget build(BuildContext context) {
    final standingsValue = ref.watch(standingsProvider);
    final league = ref.watch(leagueProvider).value;
    final leagues = ref.watch(leaguesProvider).value ?? const <League>[];
    final user = ref.watch(userProvider).value;
    final leagueTips = ref.watch(leagueTipsProvider).value ?? const <Tip>[];
    final matches = ref.watch(matchesProvider).value ?? const <CupMatch>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Liga')),
      body: AsyncValueView<List<Standing>>(
        value: standingsValue,
        data: (standings) {
          final displayNames = {
            for (final standing in standings)
              standing.uid: standing.displayName,
          };
          final standingsByUid = {
            for (final standing in standings) standing.uid: standing,
          };
          final sortedMatches = [...matches]
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
          final phases = _phasesFor(sortedMatches);
          final activePhase =
              _selectedPhase == null || !phases.contains(_selectedPhase)
                  ? _currentPhaseFor(sortedMatches)
                  : _selectedPhase!;
          final today = DateTime.now();
          final visibleMatches = sortedMatches.where((match) {
            return _phaseFor(match) == activePhase &&
                !_dayFor(match.kickoff).isAfter(_dayFor(today));
          }).toList();
          final days = _groupByDay(visibleMatches);
          final dayKeys = days.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (league != null) ...[
                _LeagueControlCard(
                  league: league,
                  leagues: leagues.isEmpty ? [league] : leagues,
                  isOwner: user?.uid == league.ownerUid,
                  onSwitchLeague: (leagueId) =>
                      ref.read(repositoryProvider).switchLeague(
                            leagueId: leagueId,
                          ),
                  onRenameLeague: () => _renameLeague(league),
                ),
                const SizedBox(height: 16),
              ],
              Text('Tabelle', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (standings.isEmpty)
                const Text('Noch keine Spieler in dieser Runde.')
              else
                for (final standing in standings) ...[
                  Card(
                    child: ListTile(
                      leading: _RankAvatar(standing: standing),
                      title: Text(standing.displayName),
                      subtitle: Text(
                        '${standing.exactCount} exakt · ${standing.tendencyCount} Tendenzen',
                      ),
                      trailing: Text(
                        '${standing.totalPoints}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              if (leagueTips.isNotEmpty && dayKeys.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Tipps der Runde',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: phases.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final phase = phases[index];
                      return ChoiceChip(
                        label: Text(phase),
                        selected: phase == activePhase,
                        onSelected: (_) {
                          setState(() => _selectedPhase = phase);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                for (final day in dayKeys) ...[
                  _LeagueDaySection(
                    day: day,
                    matches: days[day] ?? const <CupMatch>[],
                    standings: standings,
                    tips: leagueTips,
                    displayNames: displayNames,
                    standingsByUid: standingsByUid,
                  ),
                  const SizedBox(height: 8),
                ],
              ] else if (leagueTips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Tipps der Runde',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                    'Für diese Phase ist noch kein Spieltag angebrochen.'),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _renameLeague(League league) async {
    final controller = TextEditingController(text: league.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tipprunde umbenennen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == league.name) return;
    try {
      await ref.read(repositoryProvider).renameLeague(name: name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tipprunde umbenannt.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Umbenennen fehlgeschlagen: $error')),
        );
      }
    }
  }
}

class _LeagueControlCard extends StatelessWidget {
  const _LeagueControlCard({
    required this.league,
    required this.leagues,
    required this.isOwner,
    required this.onSwitchLeague,
    required this.onRenameLeague,
  });

  final League league;
  final List<League> leagues;
  final bool isOwner;
  final ValueChanged<String> onSwitchLeague;
  final VoidCallback onRenameLeague;

  @override
  Widget build(BuildContext context) {
    final link = 'https://voleo.capycode.de/join/${league.inviteCode}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: league.id,
                      isExpanded: true,
                      icon: const Icon(Icons.expand_more),
                      items: [
                        for (final item in leagues)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null && value != league.id) {
                          onSwitchLeague(value);
                        }
                      },
                    ),
                  ),
                ),
                if (isOwner)
                  IconButton(
                    onPressed: onRenameLeague,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Tipprunde umbenennen',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Einladungscode ${league.inviteCode}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Einladungslink kopiert.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: 'Einladungslink kopieren',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankAvatar extends StatelessWidget {
  const _RankAvatar({required this.standing});

  final Standing standing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _MemberAvatar(photoUrl: standing.photoUrl, label: standing.displayName),
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

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.photoUrl, required this.label});

  final String? photoUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final image = _imageProvider(photoUrl);
    return CircleAvatar(
      backgroundImage: image,
      child: image == null ? Text(label.characters.first.toUpperCase()) : null,
    );
  }
}

ImageProvider? _imageProvider(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http')) return NetworkImage(value);
  return FileImage(File(value));
}

List<String> _phasesFor(List<CupMatch> matches) {
  final phases = {for (final match in matches) _phaseFor(match)}.toList();
  phases.sort((a, b) => _phaseOrder(a).compareTo(_phaseOrder(b)));
  return phases;
}

String _currentPhaseFor(List<CupMatch> matches) {
  if (matches.isEmpty) return 'Gruppenphase';
  final now = DateTime.now();
  final today = _dayFor(now);
  for (final match in matches) {
    if (_dayFor(match.kickoff) == today) return _phaseFor(match);
  }
  for (final match in matches) {
    if (match.kickoff.isAfter(now)) return _phaseFor(match);
  }
  return _phaseFor(matches.last);
}

String _phaseFor(CupMatch match) {
  final stage = match.stage.trim();
  if (stage.startsWith('Gruppe') || match.group.isNotEmpty) {
    return 'Gruppenphase';
  }
  if (stage.isEmpty) return 'Gruppenphase';
  return stage;
}

int _phaseOrder(String phase) {
  const order = {
    'Gruppenphase': 0,
    'Sechzehntelfinale': 1,
    'Achtelfinale': 2,
    'Viertelfinale': 3,
    'Halbfinale': 4,
    'Spiel um Platz 3': 5,
    'Finale': 6,
  };
  return order[phase] ?? 99;
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

class _LeagueDaySection extends StatelessWidget {
  const _LeagueDaySection({
    required this.day,
    required this.matches,
    required this.standings,
    required this.tips,
    required this.displayNames,
    required this.standingsByUid,
  });

  final DateTime day;
  final List<CupMatch> matches;
  final List<Standing> standings;
  final List<Tip> tips;
  final Map<String, String> displayNames;
  final Map<String, Standing> standingsByUid;

  @override
  Widget build(BuildContext context) {
    final unlockedMatchIds = {
      for (final match in matches)
        if (match.isLocked) match.id,
    };
    final visibleTips =
        tips.where((tip) => unlockedMatchIds.contains(tip.matchId)).toList();
    final tipsByUser = <String, List<Tip>>{};
    for (final tip in visibleTips) {
      tipsByUser.putIfAbsent(tip.uid, () => []).add(tip);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDay(day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${matches.length} Spiele',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (visibleTips.isEmpty)
              const Text('Tipps werden ab Anpfiff sichtbar.')
            else
              for (final standing in standings)
                if ((tipsByUser[standing.uid] ?? const <Tip>[]).isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _MemberAvatar(
                      photoUrl: standing.photoUrl,
                      label: displayNames[standing.uid] ?? 'Spieler',
                    ),
                    title: Text(displayNames[standing.uid] ?? 'Spieler'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showUserTips(
                      context,
                      displayNames[standing.uid] ?? 'Spieler',
                      matches,
                      tipsByUser[standing.uid] ?? const <Tip>[],
                      standing,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showUserTips(
    BuildContext context,
    String displayName,
    List<CupMatch> matches,
    List<Tip> userTips,
    Standing? standing,
  ) {
    final matchesById = {for (final match in matches) match.id: match};
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                _MemberAvatar(photoUrl: standing?.photoUrl, label: displayName),
                const SizedBox(width: 12),
                Text(displayName,
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            for (final tip in userTips) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${matchesById[tip.matchId]?.homeTeam ?? 'Spiel'} - '
                  '${matchesById[tip.matchId]?.awayTeam ?? tip.matchId}',
                ),
                trailing: Text(
                  '${tip.predictedHome}:${tip.predictedAway}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text('${tip.points} Punkte'),
              ),
              const Divider(),
            ],
          ],
        );
      },
    );
  }
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
