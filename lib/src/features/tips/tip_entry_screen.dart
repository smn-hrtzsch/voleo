import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/flags.dart';
import '../../domain/scoring.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';
import '../shared/live_pulse_dot.dart';

class TipEntryScreen extends ConsumerStatefulWidget {
  const TipEntryScreen({
    required this.matchId,
    required this.returnPath,
    super.key,
  });

  final String matchId;
  final String returnPath;

  @override
  ConsumerState<TipEntryScreen> createState() => _TipEntryScreenState();
}

class _TipEntryScreenState extends ConsumerState<TipEntryScreen> {
  int _homeGoals = 0;
  int _awayGoals = 0;
  bool _isSaving = false;
  bool _didSeedTip = false;

  final Map<String, VoleoUser> _loadedUsers = {};

  Future<void> _loadUserIfNeeded(String uid) async {
    if (_loadedUsers.containsKey(uid)) return;
    _loadedUsers[uid] = VoleoUser(uid: uid, nickname: '', isAnonymous: true);
    final repo = ref.read(repositoryProvider);
    final user = await repo.getUser(uid);
    if (user != null && mounted) {
      setState(() {
        _loadedUsers[uid] = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipp'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(widget.returnPath),
        ),
      ),
      body: SafeArea(
        child: AsyncValueView<List<CupMatch>>(
          value: ref.watch(matchesProvider),
          data: (matches) {
            final match =
                matches.where((item) => item.id == widget.matchId).firstOrNull;
            if (match == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Spiel wurde nicht gefunden.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(widget.returnPath),
                      child: const Text('Zurück'),
                    ),
                  ],
                ),
              );
            }
            final existingTip = _tipForMatch(
              ref.watch(tipsProvider).value ?? const <Tip>[],
              match,
            );
            final allTips =
                ref.watch(leagueTipsProvider).value ?? const <Tip>[];
            final standings =
                ref.watch(standingsProvider).value ?? const <Standing>[];
            final displayNames = {
              for (final standing in standings)
                standing.uid: standing.displayName,
            };
            if (existingTip != null) {
              if (!_didSeedTip) {
                _homeGoals = existingTip.predictedHome;
                _awayGoals = existingTip.predictedAway;
                _didSeedTip = true;
              }
            } else {
              _didSeedTip = false;
            }
            final scoreResult = _scoreResult(match, existingTip);

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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                _matchContextLabel(match),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: () {
                                    final winner = getMatchWinner(match);
                                    final isFinished =
                                        match.status == MatchStatus.finalResult;
                                    final isHomeWinner = isFinished &&
                                        winner != null &&
                                        isSameTeam(winner, match.homeTeam);
                                    final isHomeLoser = isFinished &&
                                        winner != null &&
                                        !isSameTeam(winner, match.homeTeam);
                                    return _MatchupTeamLabel(
                                      teamName: match.homeTeam,
                                      isHome: true,
                                      isWinner: isHomeWinner,
                                      isLoser: isHomeLoser,
                                    );
                                  }(),
                                ),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    match.status == MatchStatus.finalResult ||
                                            match.status == MatchStatus.live
                                        ? '${match.regularHomeScore ?? match.homeScore}:${match.regularAwayScore ?? match.awayScore}'
                                        : '-:-',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              match.status == MatchStatus.live
                                                  ? Colors.green
                                                  : null,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: () {
                                    final winner = getMatchWinner(match);
                                    final isFinished =
                                        match.status == MatchStatus.finalResult;
                                    final isAwayWinner = isFinished &&
                                        winner != null &&
                                        isSameTeam(winner, match.awayTeam);
                                    final isAwayLoser = isFinished &&
                                        winner != null &&
                                        !isSameTeam(winner, match.awayTeam);
                                    return _MatchupTeamLabel(
                                      teamName: match.awayTeam,
                                      isHome: false,
                                      isWinner: isAwayWinner,
                                      isLoser: isAwayLoser,
                                    );
                                  }(),
                                ),
                              ],
                            ),
                            if (hasProgression)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Center(
                                  child: Text(
                                    progressionText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                DateFormat('dd.MM.yyyy HH:mm')
                                    .format(match.kickoff),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            if (existingTip != null) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Dein Tipp: ${existingTip.predictedHome}:${existingTip.predictedAway}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                      if (!match.isLocked) ...[
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: _isSaving
                                              ? null
                                              : () => _deleteTip(match),
                                          child: Icon(
                                            Icons.cancel,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (scoreResult != null) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Chip(
                                  avatar: const Icon(Icons.stars, size: 18),
                                  label: Text(_scoreLabel(scoreResult)),
                                ),
                              ),
                            ],
                            if (match.status == MatchStatus.live &&
                                existingTip != null) ...[
                              const SizedBox(height: 8),
                              (() {
                                final user = ref.watch(userProvider).value;
                                final previewScore = scoreTip(
                                  predictedHome: existingTip.predictedHome,
                                  predictedAway: existingTip.predictedAway,
                                  actualHome: match.homeScore ?? 0,
                                  actualAway: match.awayScore ?? 0,
                                );
                                final pts = getLiveMatchTotalPoints(
                                  tipPoints: previewScore.points,
                                  favoriteTeam: user?.favoriteTeam,
                                  predictedChampion: user?.predictedChampion,
                                  match: match,
                                );
                                String labelText;
                                if (pts == 0) {
                                  labelText = 'Voraussichtlich: +0';
                                } else {
                                  String detail = '';
                                  if (previewScore.isExact) {
                                    detail = 'exaktes Ergebnis';
                                  } else if (previewScore.points == 3) {
                                    detail = 'richtige Tordifferenz';
                                  } else if (previewScore.isTendency) {
                                    detail = 'richtige Tendenz';
                                  }
                                  labelText = detail.isNotEmpty
                                      ? 'Voraussichtlich: +$pts ($detail)'
                                      : 'Voraussichtlich: +$pts';
                                }
                                return Center(
                                  child: Chip(
                                    avatar: const LivePulseDot(),
                                    label: Text(
                                      labelText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                );
                              })(),
                            ],
                          ],
                        ),
                      ),
                      if (match.status == MatchStatus.live)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: Colors.green, width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LivePulseDot(),
                                const SizedBox(width: 4),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!match.isLocked) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ScoreWheel(
                          label: match.homeTeam,
                          value: _homeGoals,
                          enabled: !match.isLocked,
                          onChanged: (value) {
                            if (_homeGoals != value) {
                              setState(() => _homeGoals = value);
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          ':',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                      Expanded(
                        child: _ScoreWheel(
                          label: match.awayTeam,
                          value: _awayGoals,
                          enabled: !match.isLocked,
                          onChanged: (value) {
                            if (_awayGoals != value) {
                              setState(() => _awayGoals = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : () => _save(match),
                    icon: const Icon(Icons.save),
                    label: const Text('Tipp speichern'),
                  ),
                ],
                if (match.isLocked) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Tipps der Runde',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Column(
                        children: [
                          (() {
                            final rawTips = allTips
                                .where((tip) =>
                                    (tip.matchId == match.id ||
                                        (match.originalId != null &&
                                            tip.matchId.replaceAll(
                                                    'openligadb-', '') ==
                                                match.originalId!.replaceAll(
                                                    'openligadb-', ''))) &&
                                    displayNames.containsKey(tip.uid))
                                .toList();
                            final Map<String, Tip> uniqueTips = {};
                            for (final tip in rawTips) {
                              final existing = uniqueTips[tip.uid];
                              if (existing == null) {
                                uniqueTips[tip.uid] = tip;
                              } else {
                                if (tip.matchId.startsWith('openligadb-') &&
                                    !existing.matchId
                                        .startsWith('openligadb-')) {
                                  uniqueTips[tip.uid] = tip;
                                }
                              }
                            }
                            final matchTips = uniqueTips.values.toList();
                            if (matchTips.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                    child: Text(
                                        'Keine Tipps von anderen Spielern.')),
                              );
                            }
                            return Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          'Spieler',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Tipp',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Punkte',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Text(
                                          'Wertung',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                for (final tip in matchTips) ...[
                                  (() {
                                    _loadUserIfNeeded(tip.uid);
                                    final userProfile = _loadedUsers[tip.uid];
                                    final isPlaceholder =
                                        userProfile?.nickname.isEmpty ?? true;
                                    final isLive =
                                        match.status == MatchStatus.live;
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
                                            favoriteTeam: isPlaceholder
                                                ? null
                                                : userProfile?.favoriteTeam,
                                            predictedChampion: isPlaceholder
                                                ? null
                                                : userProfile
                                                    ?.predictedChampion,
                                            match: match,
                                          )
                                        : 0;

                                    final totalPts = getMatchTotalPoints(
                                      tipPoints: tip.points,
                                      favoriteTeam: isPlaceholder
                                          ? null
                                          : userProfile?.favoriteTeam,
                                      predictedChampion: isPlaceholder
                                          ? null
                                          : userProfile?.predictedChampion,
                                      match: match,
                                    );

                                    final evalStr = getEvaluationLabel(
                                      tipPoints: tip.points,
                                      favoriteTeam: isPlaceholder
                                          ? null
                                          : userProfile?.favoriteTeam,
                                      predictedChampion: isPlaceholder
                                          ? null
                                          : userProfile?.predictedChampion,
                                      match: match,
                                    );

                                    final liveEvalStr = isLive
                                        ? getLiveEvaluationLabel(
                                            tipPoints: liveTipPoints,
                                            favoriteTeam: isPlaceholder
                                                ? null
                                                : userProfile?.favoriteTeam,
                                            predictedChampion: isPlaceholder
                                                ? null
                                                : userProfile
                                                    ?.predictedChampion,
                                            match: match,
                                          )
                                        : '';

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              displayNames[tip.uid] ??
                                                  'Spieler',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '${tip.predictedHome}:${tip.predictedAway}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: match.status ==
                                                          MatchStatus
                                                              .finalResult
                                                      ? (totalPts > 0
                                                          ? Colors.green
                                                              .withAlpha(38)
                                                          : Colors.grey
                                                              .withAlpha(38))
                                                      : match.status ==
                                                              MatchStatus.live
                                                          ? Colors.green
                                                              .withAlpha(38)
                                                          : Colors.blue
                                                              .withAlpha(38),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      match.status ==
                                                              MatchStatus
                                                                  .finalResult
                                                          ? '+$totalPts'
                                                          : match.status ==
                                                                  MatchStatus
                                                                      .live
                                                              ? '+$liveTotalPts'
                                                              : '-',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: match.status ==
                                                                MatchStatus
                                                                    .finalResult
                                                            ? (totalPts > 0
                                                                ? Colors.green
                                                                : Colors.grey)
                                                            : match.status ==
                                                                    MatchStatus
                                                                        .live
                                                                ? Colors.green
                                                                : Colors.blue,
                                                      ),
                                                    ),
                                                    if (match.status ==
                                                        MatchStatus.live) ...[
                                                      const SizedBox(width: 4),
                                                      const LivePulseDot(
                                                          size: 6),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 6,
                                            child: Text(
                                              match.status ==
                                                      MatchStatus.finalResult
                                                  ? evalStr
                                                  : match.status ==
                                                          MatchStatus.live
                                                      ? liveEvalStr
                                                      : '-',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: match.status ==
                                                        MatchStatus.finalResult
                                                    ? (totalPts > 0
                                                        ? Colors.green
                                                        : Colors.grey)
                                                    : match.status ==
                                                            MatchStatus.live
                                                        ? (liveTotalPts > 0
                                                            ? Colors.green
                                                            : Colors.grey)
                                                        : Colors.grey,
                                                fontWeight: match.status ==
                                                        MatchStatus.finalResult
                                                    ? (totalPts > 0
                                                        ? FontWeight.w500
                                                        : FontWeight.normal)
                                                    : match.status ==
                                                            MatchStatus.live
                                                        ? (liveTotalPts > 0
                                                            ? FontWeight.w500
                                                            : FontWeight.normal)
                                                        : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })(),
                                  if (tip != matchTips.last)
                                    const Divider(height: 1),
                                ],
                              ],
                            );
                          })(),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save(CupMatch match) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(repositoryProvider).saveTip(
            matchId: match.id,
            home: _homeGoals,
            away: _awayGoals,
          );
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(widget.returnPath);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTip(CupMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tipp löschen?'),
          content: const Text(
            'Möchtest du deinen Tipp für dieses Spiel wirklich löschen?',
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
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(repositoryProvider).deleteTip(matchId: match.id);
      if (!mounted) return;
      setState(() {
        _homeGoals = 0;
        _awayGoals = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tipp gelöscht.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Löschen: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _MatchupTeamLabel extends StatelessWidget {
  const _MatchupTeamLabel({
    required this.teamName,
    required this.isHome,
    this.isWinner = false,
    this.isLoser = false,
  });

  final String teamName;
  final bool isHome;
  final bool isWinner;
  final bool isLoser;

  @override
  Widget build(BuildContext context) {
    final flag = Text(
      CountryFlags.getFlag(teamName),
      style: const TextStyle(fontSize: 24),
    );
    final name = Expanded(
      child: Text(
        teamName,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        textAlign: isHome ? TextAlign.right : TextAlign.left,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment:
          isHome ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: isHome
          ? [name, const SizedBox(width: 8), flag]
          : [flag, const SizedBox(width: 8), name],
    );
  }
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

ScoreResult? _scoreResult(CupMatch match, Tip? tip) {
  final actualHome = match.regularHomeScore ?? match.homeScore;
  final actualAway = match.regularAwayScore ?? match.awayScore;
  if (tip == null ||
      match.status != MatchStatus.finalResult ||
      actualHome == null ||
      actualAway == null) {
    return null;
  }
  return scoreTip(
    predictedHome: tip.predictedHome,
    predictedAway: tip.predictedAway,
    actualHome: actualHome,
    actualAway: actualAway,
  );
}

String _scoreLabel(ScoreResult result) {
  if (result.isExact) return '${result.points} Punkte: exaktes Ergebnis';
  if (result.points == 3) return '3 Punkte: richtige Tordifferenz';
  if (result.isTendency) return '${result.points} Punkte: richtige Tendenz';
  return '0 Punkte';
}

String _matchContextLabel(CupMatch match) {
  if (match.group.isNotEmpty) {
    return '${match.stage} · Gruppe ${match.group}';
  }
  if (match.stage == 'Finale' || match.stage == 'Spiel um Platz 3') {
    return match.stage;
  }
  final parts = match.id.split('-');
  if (parts.length >= 4 &&
      (match.stage.contains('finale') || match.stage.contains('Finale'))) {
    final num = parts.last;
    return '${match.stage} $num';
  }
  return match.stage;
}

class _ScoreWheel extends StatefulWidget {
  const _ScoreWheel({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  static const _maxGoals = 12;

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  State<_ScoreWheel> createState() => _ScoreWheelState();
}

class _ScoreWheelState extends State<_ScoreWheel> {
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ScoreWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (_controller.hasClients && _controller.selectedItem != widget.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _controller.hasClients &&
              _controller.selectedItem != widget.value) {
            _controller.jumpToItem(widget.value);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          widget.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        IgnorePointer(
          ignoring: !widget.enabled,
          child: Opacity(
            opacity: widget.enabled ? 1.0 : 0.72,
            child: Container(
              height: 156,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CupertinoPicker.builder(
                scrollController: _controller,
                itemExtent: 48,
                diameterRatio: 1.35,
                selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                  background: Color(0x1A000000),
                ),
                onSelectedItemChanged: widget.onChanged,
                childCount: _ScoreWheel._maxGoals + 1,
                itemBuilder: (context, index) {
                  return Center(
                    child: Text(
                      '$index',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
