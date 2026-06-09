import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';
import '../shared/app_toast.dart';

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
                  onSwitchLeague: _switchLeague,
                  onRenameLeague: () => _renameLeague(league),
                  onJoinLeague: _joinLeague,
                  onCreateLeague: _createLeague,
                  onLeaveLeague: () =>
                      _confirmLeaveLeague(context, ref, league),
                ),
                const SizedBox(height: 16),
              ],
              if (league == null) ...[
                _LeagueSetupCard(
                  onJoinLeague: _joinLeague,
                  onCreateLeague: _createLeague,
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
        showAppToast(context, 'Tipprunde umbenannt.',
            type: AppToastType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppToast(context, 'Umbenennen fehlgeschlagen: $error',
            type: AppToastType.error);
      }
    }
  }

  Future<void> _switchLeague(String leagueId) async {
    try {
      await ref.read(repositoryProvider).switchLeague(leagueId: leagueId);
      ref.invalidate(leagueProvider);
      ref.invalidate(leaguesProvider);
      ref.invalidate(leagueTipsProvider);
      ref.invalidate(standingsProvider);
      if (mounted) {
        showAppToast(context, 'Tipprunde gewechselt.',
            type: AppToastType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppToast(
            context, _formatLeagueError('Wechsel fehlgeschlagen', error),
            type: AppToastType.error);
      }
    }
  }

  Future<void> _joinLeague() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tipprunde beitreten'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Einladungscode',
            prefixIcon: Icon(Icons.key_outlined),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Beitreten'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      await ref.read(repositoryProvider).joinLeague(inviteCode: code);
      if (mounted) {
        showAppToast(context, 'Tipprunde beigetreten.',
            type: AppToastType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppToast(
            context, _formatLeagueError('Beitritt fehlgeschlagen', error),
            type: AppToastType.error);
      }
    }
  }

  Future<void> _createLeague() async {
    final controller = TextEditingController(text: 'Meine WM-Runde');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Tipprunde'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name der Tipprunde',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(repositoryProvider).createLeague(name: name);
      if (mounted) {
        showAppToast(context, 'Tipprunde erstellt.',
            type: AppToastType.success);
      }
    } catch (error) {
      if (mounted) {
        showAppToast(
            context, _formatLeagueError('Erstellung fehlgeschlagen', error),
            type: AppToastType.error);
      }
    }
  }

  Future<void> _confirmLeaveLeague(
      BuildContext context, WidgetRef ref, League league) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tipprunde verlassen?'),
          content: Text(
            'Möchtest du die Tipprunde "${league.name}" wirklich verlassen? '
            'Dein Punktestand bleibt eingefroren, bis du der Tipprunde wieder beitrittst.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Verlassen'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).leaveLeague(leagueId: league.id);
      if (context.mounted) {
        showAppToast(
            context, 'Du hast die Tipprunde "${league.name}" verlassen.',
            type: AppToastType.success);
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context,
            _formatLeagueError('Fehler beim Verlassen der Tipprunde', e),
            type: AppToastType.error);
      }
    }
  }

  String _formatLeagueError(String prefix, Object error) {
    final raw = error.toString();
    if (raw.contains('Dieser Name ist in der Liga bereits vergeben')) {
      return '$prefix: Dein Spitzname ist in dieser Tipprunde schon vergeben. Bitte ändere deinen Namen im Profil und versuche es erneut.';
    }
    if (raw.contains('permission-denied') ||
        raw.contains('PERMISSION_DENIED')) {
      return '$prefix: Keine Berechtigung in Firestore. Bitte Regeln deployen.';
    }
    return '$prefix: $raw';
  }
}

class _LeagueControlCard extends StatelessWidget {
  const _LeagueControlCard({
    required this.league,
    required this.leagues,
    required this.isOwner,
    required this.onSwitchLeague,
    required this.onRenameLeague,
    required this.onJoinLeague,
    required this.onCreateLeague,
    required this.onLeaveLeague,
  });

  final League league;
  final List<League> leagues;
  final bool isOwner;
  final Future<void> Function(String leagueId) onSwitchLeague;
  final VoidCallback onRenameLeague;
  final VoidCallback onJoinLeague;
  final VoidCallback onCreateLeague;
  final VoidCallback onLeaveLeague;

  void _showLeaguePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Tipprunde wechseln',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in leagues)
                        ListTile(
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: item.id == league.id
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          leading: Icon(
                            item.id == league.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: item.id == league.id ? scheme.primary : null,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.inviteCode,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            if (item.id != league.id) {
                              onSwitchLeague(item.id);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final webLink = 'https://voleo-sho2303.web.app/join/${league.inviteCode}';
    final shareMessage = 'Tritt meiner Voleo-Tipprunde bei:\n'
        '$webLink\n'
        'Code: ${league.inviteCode}';
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap:
                  leagues.length > 1 ? () => _showLeaguePicker(context) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipprunde',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  league.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (leagues.length > 1) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                        ],
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
              ),
            ),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onJoinLeague,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Beitreten'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCreateLeague,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Neu'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Einladungscode',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        league.inviteCode,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () async {
                    await SharePlus.instance.share(
                      ShareParams(text: shareMessage),
                    );
                  },
                  icon: const Icon(Icons.share),
                  tooltip: 'Einladung teilen',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onLeaveLeague,
                  icon: const Icon(Icons.exit_to_app),
                  style: IconButton.styleFrom(
                    foregroundColor: scheme.error,
                    backgroundColor: scheme.errorContainer,
                  ),
                  tooltip: 'Tipprunde verlassen',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueSetupCard extends StatelessWidget {
  const _LeagueSetupCard({
    required this.onJoinLeague,
    required this.onCreateLeague,
  });

  final VoidCallback onJoinLeague;
  final VoidCallback onCreateLeague;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tipprunde',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoinLeague,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Tipprunde beitreten'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onCreateLeague,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Neue Tipprunde erstellen'),
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
    final photoUrl = standing.photoUrl;
    final hasImage = photoUrl != null && photoUrl.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    Widget avatarChild;
    if (hasImage) {
      avatarChild = ClipOval(
        child: photoUrl.startsWith('http')
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitials(context),
              )
            : Image.file(
                File(photoUrl),
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitials(context),
              ),
      );
    } else {
      avatarChild = _buildInitials(context);
    }

    final rank = standing.rank;
    final Color badgeBg;
    final Color badgeFg;
    if (rank == 1) {
      badgeBg = const Color(0xffffd700); // Gold
      badgeFg = Colors.black87;
    } else if (rank == 2) {
      badgeBg = const Color(0xffc0c0c0); // Silver
      badgeFg = Colors.black87;
    } else if (rank == 3) {
      badgeBg = const Color(0xffcd7f32); // Bronze
      badgeFg = Colors.white;
    } else {
      badgeBg = scheme.primary;
      badgeFg = scheme.onPrimary;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surfaceContainerHighest,
          ),
          child: avatarChild,
        ),
        Positioned(
          right: -3,
          bottom: -3,
          child: CircleAvatar(
            radius: 10,
            backgroundColor: badgeBg,
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: badgeFg,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitials(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = standing.displayName.isEmpty
        ? 'S'
        : standing.displayName.characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.photoUrl, required this.label});

  final String? photoUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hasImage = photoUrl != null && photoUrl!.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    Widget avatarChild;
    if (hasImage) {
      avatarChild = ClipOval(
        child: photoUrl!.startsWith('http')
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitials(context),
              )
            : Image.file(
                File(photoUrl!),
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitials(context),
              ),
      );
    } else {
      avatarChild = _buildInitials(context);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
      ),
      child: avatarChild,
    );
  }

  Widget _buildInitials(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = label.isEmpty ? 'S' : label.characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
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
