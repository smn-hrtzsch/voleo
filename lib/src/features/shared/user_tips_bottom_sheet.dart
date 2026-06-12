import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/clock.dart';
import '../../domain/flags.dart';
import '../../domain/scoring.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import 'live_pulse_dot.dart';
import 'team_name_with_picks.dart';

void showUserTipsBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String displayName,
  required List<CupMatch> matches,
  required List<Tip> userTips,
  required Standing? standing,
}) {
  final repository = ref.read(repositoryProvider);
  final userFuture = standing != null
      ? repository.getUser(standing.uid)
      : Future<VoleoUser?>.value(null);

  final allMatches = ref.read(matchesProvider).value ?? const <CupMatch>[];
  final earliestKickoff = allMatches.isNotEmpty
      ? allMatches.map((m) => m.kickoff).reduce((a, b) => a.isBefore(b) ? a : b)
      : null;
  final tournamentStarted =
      earliestKickoff != null && VoleoClock.now.isAfter(earliestKickoff);

  final currentUserId = ref.read(userProvider).value?.uid;
  final isCurrentUser = standing != null && standing.uid == currentUserId;
  final showPicks = isCurrentUser || tournamentStarted;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return FutureBuilder<VoleoUser?>(
            future: userFuture,
            builder: (context, snapshot) {
              final userProfile = snapshot.data;
              return UserTipsBottomSheetContent(
                scrollController: scrollController,
                displayName: displayName,
                standing: standing,
                matches: matches,
                userTips: userTips,
                userProfile: userProfile,
                isCurrentUser: isCurrentUser,
                showPicks: showPicks,
              );
            },
          );
        },
      );
    },
  );
}

class UserTipsBottomSheetContent extends StatefulWidget {
  const UserTipsBottomSheetContent({
    required this.scrollController,
    required this.displayName,
    required this.standing,
    required this.matches,
    required this.userTips,
    required this.userProfile,
    required this.isCurrentUser,
    required this.showPicks,
    super.key,
  });

  final ScrollController scrollController;
  final String displayName;
  final Standing? standing;
  final List<CupMatch> matches;
  final List<Tip> userTips;
  final VoleoUser? userProfile;
  final bool isCurrentUser;
  final bool showPicks;

  @override
  State<UserTipsBottomSheetContent> createState() =>
      _UserTipsBottomSheetContentState();
}

class _UserTipsBottomSheetContentState
    extends State<UserTipsBottomSheetContent> {
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = _determineCurrentStage();
  }

  String _determineCurrentStage() {
    if (widget.matches.isEmpty) return 'Alle';

    // 1. Find live matches
    final liveMatches =
        widget.matches.where((m) => m.status == MatchStatus.live).toList();
    if (liveMatches.isNotEmpty) {
      return _roundFor(liveMatches.first);
    }

    // 2. Find next upcoming match (scheduled matches)
    final upcoming = widget.matches
        .where((m) => m.status == MatchStatus.scheduled)
        .toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    if (upcoming.isNotEmpty) {
      return _roundFor(upcoming.first);
    }

    // 3. Fallback to last finished match
    final finished = widget.matches
        .where((m) => m.status == MatchStatus.finalResult)
        .toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    if (finished.isNotEmpty) {
      return _roundFor(finished.last);
    }

    return 'Alle';
  }

  String _roundFor(CupMatch match) {
    if (match.stage.startsWith('Gruppe') || match.stage.contains('Runde')) {
      return 'Gruppenphase';
    }
    return match.stage.isEmpty ? 'Gruppenphase' : match.stage;
  }

  @override
  Widget build(BuildContext context) {
    // Filter matches
    final filteredMatches = widget.matches.where((match) {
      if (_selectedFilter == 'Alle') return true;
      if (_selectedFilter == 'Gruppenphase') {
        return match.stage.startsWith('Gruppe') ||
            match.stage.contains('Runde');
      }
      return match.stage == _selectedFilter;
    }).toList();

    final favPoints = (widget.showPicks &&
            widget.userProfile?.favoriteTeam != null &&
            widget.userProfile!.favoriteTeam!.isNotEmpty)
        ? _countWins(widget.userProfile!.favoriteTeam!, widget.matches) * 10
        : null;
    final champPoints = (widget.showPicks &&
            widget.userProfile?.predictedChampion != null &&
            widget.userProfile!.predictedChampion!.isNotEmpty)
        ? _countWins(widget.userProfile!.predictedChampion!, widget.matches) *
            10
        : null;
    final riskPoints = (widget.showPicks &&
            (widget.userProfile?.riskTeam?.isNotEmpty ?? false) &&
            (widget.userProfile?.riskStage?.isNotEmpty ?? false))
        ? () {
            final actual = getEliminationStage(
                widget.userProfile!.riskTeam!, widget.matches);
            return actual != null
                ? calculateRiskPoints(widget.userProfile!.riskTeam!,
                    widget.userProfile!.riskStage!, actual)
                : null;
          }()
        : null;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            _MemberAvatar(
              photoUrl: widget.standing?.photoUrl,
              label: widget.displayName,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.displayName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Team Picks Side-by-Side (Equal height using IntrinsicHeight)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTeamPickCard(
                context,
                'Lieblings-Team',
                widget.userProfile?.favoriteTeam,
                null,
                widget.showPicks,
                favPoints,
              ),
              _buildTeamPickCard(
                context,
                'WM-Sieger Tipp',
                widget.userProfile?.predictedChampion,
                null,
                widget.showPicks,
                champPoints,
              ),
              _buildTeamPickCard(
                context,
                'Risiko-Tipp',
                widget.userProfile?.riskTeam,
                widget.userProfile?.riskStage,
                widget.showPicks,
                riskPoints,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spiele & Tipps',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            // Stage filters dropdown
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedFilter = newValue;
                    });
                  }
                },
                items: <String>[
                  'Alle',
                  'Gruppenphase',
                  'Sechzehntelfinale',
                  'Achtelfinale',
                  'Viertelfinale',
                  'Halbfinale',
                  'Spiel um Platz 3',
                  'Finale'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const Divider(),
        if (filteredMatches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 54),
                const SizedBox(width: 4),
                const Expanded(flex: 3, child: SizedBox.shrink()),
                const SizedBox(width: 4),
                const SizedBox(width: 100, child: SizedBox.shrink()),
                const SizedBox(width: 4),
                const Expanded(flex: 3, child: SizedBox.shrink()),
                const SizedBox(width: 4),
                SizedBox(
                  width: 54,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Pkt.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        if (filteredMatches.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Keine Spiele in dieser Phase.'),
            ),
          )
        else
          for (final match in filteredMatches) ...[
            (() {
              final tip = widget.userTips.cast<Tip?>().firstWhere(
                (t) {
                  if (t == null) return false;
                  if (t.matchId == match.id) return true;
                  if (match.originalId != null) {
                    final cleanTipId = t.matchId.replaceAll('openligadb-', '');
                    final cleanOrigId =
                        match.originalId!.replaceAll('openligadb-', '');
                    if (cleanTipId == cleanOrigId) return true;
                  }
                  return false;
                },
                orElse: () => null,
              );
              final isMatchLocked = match.status != MatchStatus.scheduled ||
                  VoleoClock.now.isAfter(match.kickoff);
              final showTip = widget.isCurrentUser || isMatchLocked;

              final homeFlag = CountryFlags.getFlag(match.homeTeam);
              final awayFlag = CountryFlags.getFlag(match.awayTeam);

              Widget tipWidget;
              Widget? trailingWidget;

              if (showTip) {
                if (tip != null) {
                  final isLive = match.status == MatchStatus.live;
                  final liveTipPoints = isLive
                      ? scoreTip(
                          predictedHome: tip.predictedHome,
                          predictedAway: tip.predictedAway,
                          actualHome: match.homeScore ?? 0,
                          actualAway: match.awayScore ?? 0,
                        ).points
                      : 0;

                  final liveTotalPts = isLive
                      ? getLiveMatchTotalPoints(
                          tipPoints: liveTipPoints,
                          favoriteTeam: widget.userProfile?.favoriteTeam,
                          predictedChampion:
                              widget.userProfile?.predictedChampion,
                          match: match,
                        )
                      : 0;

                  final totalPts = getMatchTotalPoints(
                    tipPoints: tip.points,
                    favoriteTeam: widget.userProfile?.favoriteTeam,
                    predictedChampion: widget.userProfile?.predictedChampion,
                    match: match,
                  );

                  final fullEval = getEvaluationLabel(
                    tipPoints: tip.points,
                    favoriteTeam: widget.userProfile?.favoriteTeam,
                    predictedChampion: widget.userProfile?.predictedChampion,
                    match: match,
                  ).replaceAll('\n', ' ');

                  final isCompleted = match.status == MatchStatus.finalResult;

                  if (isCompleted) {
                    tipWidget = Text(
                      'Tipp: ${tip.predictedHome}:${tip.predictedAway} ($fullEval)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  } else if (isLive) {
                    final liveEval = getLiveEvaluationLabel(
                      tipPoints: liveTipPoints,
                      favoriteTeam: widget.userProfile?.favoriteTeam,
                      predictedChampion: widget.userProfile?.predictedChampion,
                      match: match,
                    ).replaceAll('\n', ' ');
                    tipWidget = Text(
                      'Tipp: ${tip.predictedHome}:${tip.predictedAway} (Voraussichtlich: $liveEval)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    );
                  } else {
                    tipWidget = Text(
                      'Tipp: ${tip.predictedHome}:${tip.predictedAway}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  }

                  if (isLive) {
                    trailingWidget = Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(38),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+$liveTotalPts',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const LivePulseDot(size: 6),
                      ],
                    );
                  } else if (isCompleted) {
                    trailingWidget = Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: totalPts > 0
                            ? Colors.green.withAlpha(38)
                            : Colors.grey.withAlpha(38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+$totalPts',
                        style: TextStyle(
                          color: totalPts > 0 ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }
                } else {
                  tipWidget = const Text(
                    'Kein Tipp',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
              } else {
                tipWidget = const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'Tipp verdeckt',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                );
              }
              final pointsWidget = SizedBox(
                width: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailingWidget ?? const SizedBox.shrink(),
                ),
              );

              final kickoffStr =
                  DateFormat('dd.MM. HH:mm').format(match.kickoff);
              final isLive = match.status == MatchStatus.live;
              final stageLabel = match.group.isNotEmpty
                  ? '${match.stage} · Gruppe ${match.group}'
                  : match.stage;

              final hasProgression =
                  match.otHomeScore != null || match.penaltyHomeScore != null;
              final progressionParts = <String>[];
              if (match.otHomeScore != null) {
                progressionParts
                    .add('${match.otHomeScore}:${match.otAwayScore} n.V.');
              }
              if (match.penaltyHomeScore != null) {
                progressionParts.add(
                    '${match.penaltyHomeScore}:${match.penaltyAwayScore} i.E.');
              }
              final progressionText = progressionParts.join(' • ');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$kickoffStr · $stageLabel',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        if (isLive) ...[
                          const SizedBox(width: 6),
                          const LivePulseDot(),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 40),
                        const SizedBox(width: 4),
                        // Home Team Name (Right aligned)
                        Expanded(
                          flex: 3,
                          child: TeamNameWithPicks(
                            teamName: match.homeTeam,
                            user: widget.userProfile,
                            isRightAligned: true,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Flags and Score in the middle (Correct flags in the middle alignment)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(homeFlag,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 36,
                              child: Text(
                                match.status == MatchStatus.finalResult ||
                                        match.status == MatchStatus.live
                                    ? '${match.regularHomeScore ?? match.homeScore} : ${match.regularAwayScore ?? match.awayScore}'
                                    : '- : -',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isLive
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(awayFlag,
                                style: const TextStyle(fontSize: 20)),
                          ],
                        ),
                        const SizedBox(width: 4),
                        // Away Team Name (Left aligned)
                        Expanded(
                          flex: 3,
                          child: TeamNameWithPicks(
                            teamName: match.awayTeam,
                            user: widget.userProfile,
                            isRightAligned: false,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        pointsWidget,
                      ],
                    ),
                    if (hasProgression)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Center(
                          child: Text(
                            progressionText,
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Center(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: tipWidget,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                  ],
                ),
              );
            })(),
          ],
      ],
    );
  }

  int _countWins(String team, List<CupMatch> matches) {
    var wins = 0;
    for (final m in matches) {
      if (m.status != MatchStatus.finalResult) continue;
      final hs = m.homeScore;
      final as_ = m.awayScore;
      if (hs == null || as_ == null) continue;
      if (m.homeTeam == team && hs > as_) wins++;
      if (m.awayTeam == team && as_ > hs) wins++;
    }
    return wins;
  }

  Widget _buildTeamPickCard(
    BuildContext context,
    String label,
    String? teamName,
    String? stage,
    bool isVisible,
    int? points,
  ) {
    final flag = (isVisible && teamName != null && teamName.isNotEmpty)
        ? CountryFlags.getFlag(teamName)
        : '';
    final displayName = isVisible
        ? (teamName != null && teamName.isNotEmpty ? teamName : 'Keine Wahl')
        : 'Geheim';
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      // Light green in Dark Mode, dark green in Light Mode
                      color: isDark
                          ? const Color(0xffa7f3d0)
                          : const Color(0xff166534),
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              if (!isVisible)
                const Icon(Icons.lock, size: 24, color: Colors.grey)
              else ...[
                if (flag.isNotEmpty)
                  Text(flag, style: const TextStyle(fontSize: 24))
                else
                  const Icon(Icons.help_outline, size: 24, color: Colors.grey),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stage != null && stage.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    stage,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (points != null) ...[
                  const SizedBox(height: 4),
                  (() {
                    final color = points > 0
                        ? Colors.green
                        : (points < 0 ? Colors.red : Colors.grey);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${points >= 0 ? '+' : ''}$points Pkt.',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    );
                  })(),
                ],
              ],
            ],
          ),
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
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
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
                File(photoUrl!.startsWith('file://')
                    ? Uri.parse(photoUrl!).toFilePath()
                    : photoUrl!),
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
