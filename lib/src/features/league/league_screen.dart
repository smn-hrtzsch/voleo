import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';
import '../shared/app_toast.dart';
import '../shared/user_tips_bottom_sheet.dart';
import '../../domain/scoring.dart';
import '../shared/live_pulse_dot.dart';

class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key});

  @override
  ConsumerState<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends ConsumerState<LeagueScreen> {
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
          final sortedMatches = [...matches]
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

          final liveMatches =
              matches.where((m) => m.status == MatchStatus.live).toList();

          final List<_LiveStanding> liveStandings = standings.map((s) {
            int total = s.totalPoints;
            int tipPoints = s.tipPoints;
            int exact = s.exactCount;
            int diff = s.differenceCount;
            int tendency = s.tendencyCount;
            bool updated = false;

            final userTips = leagueTips.where((t) => t.uid == s.uid).toList();

            for (final match in liveMatches) {
              final tip = userTips.cast<Tip?>().firstWhere(
                    (t) => t?.matchId == match.id,
                    orElse: () => null,
                  );
              if (tip != null) {
                final score = scoreLiveTip(tip: tip, match: match);

                final pts = getLiveMatchTotalPoints(
                  tipPoints: score.points,
                  favoriteTeam: s.favoriteTeam,
                  predictedChampion: s.predictedChampion,
                  match: match,
                );

                total += pts;
                tipPoints += score.points;
                updated = true;
                if (score.isExact) {
                  exact++;
                } else if (score.isDifference) {
                  diff++;
                } else if (score.isTendency) {
                  tendency++;
                }
              }
            }

            return _LiveStanding(
              standing: s,
              totalPoints: total,
              tipPoints: tipPoints,
              exactCount: exact,
              differenceCount: diff,
              tendencyCount: tendency,
              rank: s.rank,
              hasLiveUpdates: updated,
            );
          }).toList();

          liveStandings.sort((a, b) {
            final pts = b.totalPoints.compareTo(a.totalPoints);
            if (pts != 0) return pts;
            final ex = b.exactCount.compareTo(a.exactCount);
            if (ex != 0) return ex;
            final df = b.differenceCount.compareTo(a.differenceCount);
            if (df != 0) return df;
            return b.tendencyCount.compareTo(a.tendencyCount);
          });

          final List<_LiveStanding> rankedLiveStandings = [];
          int currentRank = 1;
          _LiveStanding? prev;
          for (int i = 0; i < liveStandings.length; i++) {
            final cur = liveStandings[i];
            if (prev != null) {
              final samePoints = cur.totalPoints == prev.totalPoints &&
                  cur.exactCount == prev.exactCount &&
                  cur.differenceCount == prev.differenceCount &&
                  cur.tendencyCount == prev.tendencyCount;
              if (!samePoints) {
                currentRank = i + 1;
              }
            }
            rankedLiveStandings.add(_LiveStanding(
              standing: cur.standing,
              totalPoints: cur.totalPoints,
              tipPoints: cur.tipPoints,
              exactCount: cur.exactCount,
              differenceCount: cur.differenceCount,
              tendencyCount: cur.tendencyCount,
              rank: currentRank,
              hasLiveUpdates: cur.hasLiveUpdates,
            ));
            prev = cur;
          }

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
              if (rankedLiveStandings.isEmpty)
                const Text('Noch keine Spieler in dieser Runde.')
              else
                for (final liveStanding in rankedLiveStandings) ...[
                  Card(
                    child: ListTile(
                      leading: _RankAvatar(
                        standing: liveStanding.standing,
                        overrideRank: liveStanding.rank,
                      ),
                      title: Text(liveStanding.standing.displayName),
                      subtitle: Text(
                        '${liveStanding.exactCount} exakt · ${liveStanding.differenceCount} Diff. · ${liveStanding.tendencyCount} Tend.',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (liveStanding.hasLiveUpdates) ...[
                            const LivePulseDot(),
                            const SizedBox(width: 6),
                          ],
                          _PointsSummary(
                            totalPoints: liveStanding.totalPoints,
                            tipPoints: liveStanding.tipPoints,
                            isLive: liveStanding.hasLiveUpdates,
                          ),
                        ],
                      ),
                      onTap: () {
                        final userTips = leagueTips
                            .where(
                                (tip) => tip.uid == liveStanding.standing.uid)
                            .toList();
                        _showUserTips(
                          context,
                          liveStanding.standing.displayName,
                          sortedMatches,
                          userTips,
                          liveStanding.standing,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 12),
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
    final leaguesVal = ref.read(leaguesProvider).value ?? [];
    if (leaguesVal.length <= 1) {
      if (context.mounted) {
        showAppToast(
          context,
          'Du kannst deine einzige Tipprunde nicht verlassen. Tritt erst einer anderen Tipprunde bei.',
          type: AppToastType.error,
        );
      }
      return;
    }

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

      // Invalidate providers so UI refreshes and switches to the other league
      ref.invalidate(leagueProvider);
      ref.invalidate(leaguesProvider);
      ref.invalidate(leagueTipsProvider);
      ref.invalidate(standingsProvider);

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

  void _showUserTips(
    BuildContext context,
    String displayName,
    List<CupMatch> matches,
    List<Tip> userTips,
    Standing? standing,
  ) {
    showUserTipsBottomSheet(
      context: context,
      ref: ref,
      displayName: displayName,
      matches: matches,
      userTips: userTips,
      standing: standing,
    );
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
                      Row(
                        children: [
                          Text(
                            league.inviteCode,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Code kopieren',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: league.inviteCode),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Code kopiert.'),
                                ),
                              );
                            },
                          ),
                        ],
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
  const _RankAvatar({required this.standing, this.overrideRank});

  final Standing standing;
  final int? overrideRank;

  @override
  Widget build(BuildContext context) {
    final photoUrl = standing.photoUrl;
    final hasImage = photoUrl != null && photoUrl.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    Widget avatarChild;
    if (hasImage) {
      avatarChild = ClipOval(
        child: photoUrl.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                errorWidget: (context, url, error) => _buildInitials(context),
                placeholder: (context, url) => const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Image.file(
                File(photoUrl.startsWith('file://')
                    ? Uri.parse(photoUrl).toFilePath()
                    : photoUrl),
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

    final rank = overrideRank ?? standing.rank;
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

class _LiveStanding {
  const _LiveStanding({
    required this.standing,
    required this.totalPoints,
    required this.tipPoints,
    required this.exactCount,
    required this.differenceCount,
    required this.tendencyCount,
    required this.rank,
    required this.hasLiveUpdates,
  });

  final Standing standing;
  final int totalPoints;
  final int tipPoints;
  final int exactCount;
  final int differenceCount;
  final int tendencyCount;
  final int rank;
  final bool hasLiveUpdates;
}

class _PointsSummary extends StatelessWidget {
  const _PointsSummary({
    required this.totalPoints,
    required this.tipPoints,
    required this.isLive,
  });

  final int totalPoints;
  final int tipPoints;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalColor = isLive ? Colors.green : scheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$totalPoints',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: totalColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          '$tipPoints Tipps',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
