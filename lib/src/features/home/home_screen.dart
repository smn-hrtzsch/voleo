import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/flags.dart';
import '../../domain/clock.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';
import '../shared/live_pulse_dot.dart';
import '../shared/user_tips_bottom_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(showRulesDialogProvider, (prev, next) {
      if (next) {
        ref.read(showRulesDialogProvider.notifier).value = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _InfoTippspielCard.showRulesDialog(context, ref);
        });
      }
    });

    final matches = ref.watch(matchesProvider);
    final league = ref.watch(leagueProvider);
    final leagueValue = league.value;
    final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
    final leagueTips = ref.watch(leagueTipsProvider).value ?? const <Tip>[];
    final standings = ref.watch(standingsProvider).value ?? const <Standing>[];
    final user = ref.watch(userProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Voleo')),
      body: AsyncValueView<List<CupMatch>>(
        value: matches,
        data: (items) {
          final now = VoleoClock.now;
          final upcomingMatches = items
              .where(
                  (m) => m.kickoff.isAfter(now) || m.status == MatchStatus.live)
              .toList()
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

          final List<CupMatch> displayMatches;
          if (upcomingMatches.isNotEmpty) {
            displayMatches = upcomingMatches.take(5).toList();
          } else {
            final finaleMatch = items.firstWhere(
              (m) => m.stage == 'Finale',
              orElse: () => items.firstWhere(
                (m) => m.id == 'wc-ko-fi-1',
                orElse: () => items.last,
              ),
            );
            displayMatches = [finaleMatch];
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 16),
            children: [
              _LeagueHero(
                title: leagueValue?.name ?? 'WM-Runde',
                inviteCode: leagueValue?.inviteCode ?? 'VOLEO26',
                onTap: () => context.go('/league'),
              ),
              const SizedBox(height: 16),
              _TopThreeCard(
                standings: standings,
                matches: items,
                tips: leagueTips,
              ),
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

class _TopThreeCard extends ConsumerWidget {
  const _TopThreeCard({
    required this.standings,
    required this.matches,
    required this.tips,
  });

  final List<Standing> standings;
  final List<CupMatch> matches;
  final List<Tip> tips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  onTap: () {
                    final userTips =
                        tips.where((tip) => tip.uid == standing.uid).toList();
                    showUserTipsBottomSheet(
                      context: context,
                      ref: ref,
                      displayName: standing.displayName,
                      matches: matches,
                      userTips: userTips,
                      standing: standing,
                    );
                  },
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
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
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
    final isLive = match.status == MatchStatus.live;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go('/home/tip/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 58,
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
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : DefaultTextStyle(
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
                      (match.status == MatchStatus.finalResult ||
                              match.status == MatchStatus.live)
                          ? '${match.homeScore}:${match.awayScore}'
                          : '-:-',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isLive
                                ? Colors.green
                                : match.status == MatchStatus.finalResult
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

class _InfoTippspielCard extends ConsumerWidget {
  const _InfoTippspielCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.info_outline, color: scheme.primary, size: 28),
        title: const Text(
          'Infos zum Tippspiel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Regeln, Punktevergabe & Team-Picks'),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => showRulesDialog(context, ref),
      ),
    );
  }

  static void showRulesDialog(BuildContext context, WidgetRef ref) {
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
                    'Tendenz: +2 Punkte (z.B. Tipp 2:0, Spiel endet 3:0)'),
                _buildBulletPoint('Falscher Tipp: 0 Punkte'),
                const SizedBox(height: 12),
                _buildSectionTitle(context, 'Mannschafts-Booster'),
                _buildBulletPoint(
                    'Lieblingsmannschaft: +10 Punkte für jeden Sieg deiner Lieblingsmannschaft!'),
                _buildBulletPoint(
                    'Favorit (WM-Tipp): +10 Punkte für jeden Sieg deiner getippten Weltmeister-Mannschaft!'),
                _buildBulletPointWithWidget(
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        const TextSpan(
                          text:
                              'Hinweis: Diese beiden Teams müssen vor Turnierstart gewählt werden und können im Nachgang nicht mehr geändert werden (du kannst die Mannschaften im ',
                        ),
                        TextSpan(
                          text: 'Profil-Tab',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pop(context);
                              ref
                                  .read(comingFromRulesDialogProvider.notifier)
                                  .value = true;
                              context.go('/profile');
                            },
                        ),
                        const TextSpan(
                          text: ' wählen).',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionTitle(context, 'WM-Risiko-Tipp'),
                _buildBulletPoint(
                    'Du tippst ein Team, von dem du hoffst, dass es die WM nicht gewinnt, und sagst dessen Ausscheiden (z.B. Gruppenphase, Achtelfinale, etc.) voraus.'),
                _buildBulletPoint(
                    'Punkte und Risiko berechnen sich nach den Stärke-Tiers der Mannschaften:'),
                _buildBulletPoint(
                    'Favoriten (z.B. Frankreich): Frühes Ausscheiden (Gruppenphase) bringt/kostet +/-70 Punkte bei Erfolg/Misserfolg. Späteres Ausscheiden (Halbfinale) bringt/kostet +/-15 Punkte.'),
                _buildBulletPoint(
                    'Gurkentruppen (z.B. Curaçao): Frühes Ausscheiden bringt/kostet +/-5 Punkte. Weites Kommen (Halbfinale) bringt/kostet +/-65 Punkte.'),
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

  static Widget _buildSectionTitle(BuildContext context, String title) {
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

  static Widget _buildBulletPoint(String text) {
    return _buildBulletPointWithWidget(Text(text));
  }

  static Widget _buildBulletPointWithWidget(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: child),
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

  return Row(
    mainAxisAlignment:
        isRightAligned ? MainAxisAlignment.end : MainAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (isRightAligned) ...[
        for (final m in markers) m,
        const SizedBox(width: 4),
      ],
      Flexible(child: textWidget),
      if (!isRightAligned) ...[
        const SizedBox(width: 4),
        for (final m in markers) m,
      ],
    ],
  );
}
