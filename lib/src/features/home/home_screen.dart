import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final user = ref.watch(userProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Voleo')),
      body: AsyncValueView<List<CupMatch>>(
        value: matches,
        data: (items) {
          final now = DateTime.now();
          final upcomingMatches = items
              .where(
                  (m) => m.kickoff.isAfter(now) || m.status == MatchStatus.live)
              .toList()
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

          final displayMatches = upcomingMatches.take(5).toList();

          if (displayMatches.length < 5) {
            final finished = items
                .where((m) => m.status == MatchStatus.finalResult)
                .toList()
              ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
            for (final m in finished) {
              if (displayMatches.length >= 5) break;
              if (!displayMatches.contains(m)) {
                displayMatches.add(m);
              }
            }
            displayMatches.sort((a, b) => a.kickoff.compareTo(b.kickoff));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 16),
            children: [
              _LeagueHero(
                title: leagueValue?.name ?? 'WM-Runde',
                inviteCode: leagueValue?.inviteCode ?? 'VOLEO26',
                onTap: () => context.go('/league'),
              ),
              const SizedBox(height: 16),
              _TopThreeCard(standings: standings),
              const SizedBox(height: 12),
              const _InfoTippspielCard(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nächste Spiele',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/matches'),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Alle Spiele'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _NextMatchesCard(
                matches: displayMatches,
                tips: tips,
                user: user,
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
  const _LeagueHero({
    required this.title,
    required this.inviteCode,
    required this.onTap,
  });

  final String title;
  final String inviteCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 112,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.groups_outlined),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Liga: $title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Code: $inviteCode',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Code kopieren',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: inviteCode),
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
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right),
                  iconAlignment: IconAlignment.end,
                  label: const Text('zur Liga'),
                ),
              ],
            ),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
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

class _NextMatchesCard extends StatelessWidget {
  const _NextMatchesCard({
    required this.matches,
    required this.tips,
    this.user,
  });

  final List<CupMatch> matches;
  final List<Tip> tips;
  final VoleoUser? user;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Keine anstehenden Spiele.')),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    'Datum',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Spiel',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
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
            for (var i = 0; i < matches.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _NextMatchRow(
                match: matches[i],
                tip: _tipForMatch(tips, matches[i].id),
                user: user,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NextMatchRow extends StatelessWidget {
  const _NextMatchRow({required this.match, this.tip, this.user});

  final CupMatch match;
  final Tip? tip;
  final VoleoUser? user;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd.MM.').format(match.kickoff);
    final time = DateFormat('HH:mm').format(match.kickoff);
    final homeFlag = CountryFlags.getFlag(match.homeTeam);
    final awayFlag = CountryFlags.getFlag(match.awayTeam);
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go('/home/tip/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ) ??
                    const TextStyle(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date),
                    Text(time),
                  ],
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

class _InfoTippspielCard extends StatelessWidget {
  const _InfoTippspielCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.info_outline, color: scheme.primary, size: 28),
        title: const Text(
          'Infos zum Tippspiel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Regeln, Punktevergabe & Sonderregeln'),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => _showRulesDialog(context),
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.gavel, color: scheme.primary),
              const SizedBox(width: 10),
              const Text('Regeln & Punkte'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionTitle(context, 'Tippabgabe'),
                const Text(
                  'Tipps können bis zum offiziellen Anpfiff des jeweiligen Spiels abgegeben und geändert werden. Danach sind Tipps gesperrt.',
                ),
                const SizedBox(height: 12),
                _buildSectionTitle(context, 'Punktevergabe für Spiele'),
                _buildBulletPoint(
                    'Exaktes Ergebnis: +4 Punkte (z.B. Tipp 2:1, Spiel endet 2:1)'),
                _buildBulletPoint(
                    'Tordifferenz: +3 Punkte (z.B. Tipp 3:1, Spiel endet 2:0)'),
                _buildBulletPoint(
                    'Tendenz: +2 Punkte (z.B. Tipp 2:0, Spiel endet 3:1)'),
                _buildBulletPoint('Falscher Tipp: 0 Punkte'),
                const SizedBox(height: 12),
                _buildSectionTitle(context, 'Mannschafts-Booster'),
                _buildBulletPoint(
                    'Lieblingsmannschaft: +10 Punkte für jeden Sieg deiner Lieblingsmannschaft!'),
                _buildBulletPoint(
                    'Favorit (WM-Tipp): +10 Punkte für jeden Sieg deiner getippten Weltmeister-Mannschaft!'),
                _buildBulletPoint(
                    'Hinweis: Diese beiden Teams müssen vor Turnierstart gewählt werden und können im Nachgang nicht mehr geändert werden.'),
                const SizedBox(height: 12),
                _buildSectionTitle(context, 'WM-Risiko-Tipp'),
                _buildBulletPoint(
                    'Du tippst ein Team, von dem du hoffst, dass es die WM nicht gewinnt, und sagst dessen Ausscheiden (z.B. Gruppenphase, Achtelfinale, etc.) voraus.'),
                _buildBulletPoint(
                    'Punkte und Risiko berechnen sich nach den Stärke-Tiers der Mannschaften:'),
                _buildBulletPoint(
                    'Favoriten (z.B. Frankreich): Frühes Ausscheiden (Gruppenphase) bringt +30 Punkte bei Erfolg, bei Misserfolg gibt es -30 Punkte. Späteres Ausscheiden (Halbfinale) bringt/kostet +/-10 Punkte.'),
                _buildBulletPoint(
                    'Gurkentruppen (z.B. Curaçao): Frühes Ausscheiden bringt/kostet +/-5 Punkte. Weites Kommen (Viertelfinale/Halbfinale) bringt/kostet +/-30 Punkte.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
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
