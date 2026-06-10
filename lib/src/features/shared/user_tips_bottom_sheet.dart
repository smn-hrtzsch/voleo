import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/clock.dart';
import '../../domain/flags.dart';
import '../../domain/scoring.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import 'live_pulse_dot.dart';

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
    CupMatch? activeMatch;
    // Finde das erste Spiel, das noch nicht beendet ist oder live ist
    final incomplete = widget.matches.where((m) => m.status != MatchStatus.finalResult).toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    
    if (incomplete.isNotEmpty) {
      activeMatch = incomplete.first;
    } else if (widget.matches.isNotEmpty) {
      // Wenn alle Spiele beendet sind, nimm das letzte
      final sorted = [...widget.matches]..sort((a, b) => a.kickoff.compareTo(b.kickoff));
      activeMatch = sorted.last;
    }

    if (activeMatch != null) {
      final isKo = activeMatch.stage == 'Sechzehntelfinale' ||
          activeMatch.stage == 'Achtelfinale' ||
          activeMatch.stage == 'Viertelfinale' ||
          activeMatch.stage == 'Halbfinale' ||
          activeMatch.stage == 'Spiel um Platz 3' ||
          activeMatch.stage == 'Finale';
      return isKo ? activeMatch.stage : 'Gruppenphase';
    }
    return 'Alle';
  }

  @override
  Widget build(BuildContext context) {
    // Filter matches
    final filteredMatches = widget.matches.where((match) {
      if (_selectedFilter == 'Alle') return true;
      if (_selectedFilter == 'Gruppenphase') {
        return match.stage.startsWith('Gruppe') || match.stage.contains('Runde');
      }
      return match.stage == _selectedFilter;
    }).toList();

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
              ),
              _buildTeamPickCard(
                context,
                'WM-Sieger Tipp',
                widget.userProfile?.predictedChampion,
                null,
                widget.showPicks,
              ),
              _buildTeamPickCard(
                context,
                'Risiko-Tipp',
                widget.userProfile?.riskTeam,
                widget.userProfile?.riskStage,
                widget.showPicks,
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const Divider(),
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
                    (t) => t?.matchId == match.id,
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

                  tipWidget = Text(
                    'Tipp: ${tip.predictedHome}:${tip.predictedAway} ($fullEval)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  );

                  if (match.status != MatchStatus.scheduled) {
                    trailingWidget = Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: totalPts > 0
                            ? Colors.green.withAlpha(38)
                            : Colors.grey.withAlpha(38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+$totalPts Pkt.',
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
                width: 60,
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
                        const SizedBox(width: 60),
                        const SizedBox(width: 8),
                        // Home Team Name (Right aligned)
                        Expanded(
                          flex: 3,
                          child: Text(
                            match.homeTeam,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            softWrap: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Flags and Score in the middle (Correct flags in the middle alignment)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(homeFlag, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 6),
                            Text(
                              (match.status == MatchStatus.finalResult ||
                                      match.status == MatchStatus.live)
                                  ? '${match.homeScore} : ${match.awayScore}'
                                  : '- : -',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isLive
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(awayFlag, style: const TextStyle(fontSize: 20)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // Away Team Name (Left aligned)
                        Expanded(
                          flex: 3,
                          child: Text(
                            match.awayTeam,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            softWrap: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        pointsWidget,
                      ],
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

  Widget _buildTeamPickCard(
    BuildContext context,
    String label,
    String? teamName,
    String? stage,
    bool isVisible,
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
                      color: isDark ? const Color(0xffa7f3d0) : const Color(0xff166534),
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
