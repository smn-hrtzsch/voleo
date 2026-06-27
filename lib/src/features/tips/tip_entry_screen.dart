import 'dart:async';

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
  int _otHomeGoals = 0;
  int _otAwayGoals = 0;
  PenaltyWinnerSide? _penaltyWinner;
  bool _isSaving = false;
  bool _hasEdited = false;
  bool _didSeedTip = false;
  bool _allowPop = false;
  bool _isOtExpanded = false;
  bool _isPenaltyExpanded = false;
  bool _hasOtSelection = false;
  CupMatch? _currentMatch;
  Timer? _otExpansionTimer;
  Timer? _penaltyExpansionTimer;

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
  void dispose() {
    _otExpansionTimer?.cancel();
    _penaltyExpansionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Tipp'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _leave(_currentMatch),
        ),
      ),
      body: SafeArea(
        child: AsyncValueView<List<CupMatch>>(
          value: ref.watch(matchesProvider),
          data: (matches) {
            final match =
                matches.where((item) => item.id == widget.matchId).firstOrNull;
            _currentMatch = match;
            if (match == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Spiel wurde nicht gefunden.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.canPop()
                          ? _navigateBack()
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
                _otHomeGoals =
                    existingTip.predictedOtHome ?? existingTip.predictedHome;
                _otAwayGoals =
                    existingTip.predictedOtAway ?? existingTip.predictedAway;
                _penaltyWinner = existingTip.predictedPenaltyWinner;
                _hasOtSelection = existingTip.predictedOtHome != null &&
                    existingTip.predictedOtAway != null;
                _didSeedTip = true;
              }
            } else {
              _didSeedTip = false;
            }
            final scoreResult = _scoreResult(match, existingTip);
            final existingTipComplete = existingTip != null &&
                isTipCompleteForMatch(existingTip, match);
            final showPenaltySection = match.isKnockout &&
                _homeGoals == _awayGoals &&
                _otHomeGoals == _otAwayGoals &&
                (_hasOtSelection || _isOtExpanded || _penaltyWinner != null);

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
                                    final isHomeWinner = match.isKnockout &&
                                        isFinished &&
                                        winner != null &&
                                        isSameTeam(winner, match.homeTeam);
                                    final isHomeLoser = match.isKnockout &&
                                        isFinished &&
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
                                    final isAwayWinner = match.isKnockout &&
                                        isFinished &&
                                        winner != null &&
                                        isSameTeam(winner, match.awayTeam);
                                    final isAwayLoser = match.isKnockout &&
                                        isFinished &&
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
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                    border: existingTipComplete
                                        ? null
                                        : Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Icon(
                                          existingTipComplete
                                              ? Icons.check
                                              : Icons.warning_amber_rounded,
                                          size: 18,
                                          color: existingTipComplete
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 28),
                                        child: _TipSummary(
                                          tip: existingTip,
                                          match: match,
                                          isComplete: existingTipComplete,
                                        ),
                                      ),
                                      if (!match.isLocked)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: GestureDetector(
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
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (scoreResult != null) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: ActionChip(
                                  avatar: const Icon(Icons.stars, size: 18),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_pointsLabel(scoreResult.points)),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.info_outline, size: 17),
                                    ],
                                  ),
                                  onPressed: () => _showScoreDetails(
                                    context,
                                    tip: existingTip!,
                                    match: match,
                                    scoreResult: scoreResult,
                                  ),
                                ),
                              ),
                            ],
                            if (match.status == MatchStatus.live &&
                                existingTip != null) ...[
                              const SizedBox(height: 8),
                              (() {
                                final user = ref.watch(userProvider).value;
                                final previewScore = scoreLiveTip(
                                  tip: existingTip,
                                  match: match,
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
                                  if (match.isKnockout &&
                                      previewScore.details.isNotEmpty) {
                                    detail = previewScore.details.first
                                        .replaceFirst(RegExp(r' \+\d+$'), '');
                                  } else if (previewScore.isExact) {
                                    detail = 'exaktes Ergebnis';
                                  } else if (previewScore.isDifference) {
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
                  Text(
                    match.isKnockout
                        ? 'Ergebnis nach 90 Minuten'
                        : 'Dein Ergebnis',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ScoreWheel(
                          label: match.homeTeam,
                          value: _homeGoals,
                          enabled: !match.isLocked,
                          onChanged: (value) {
                            if (_homeGoals != value) {
                              _setRegularScore(home: value);
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
                              _setRegularScore(away: value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (match.isKnockout && _homeGoals == _awayGoals) ...[
                    const SizedBox(height: 24),
                    _PhaseExpansionHeader(
                      label: 'Ergebnis nach Verlängerung',
                      isExpanded: _isOtExpanded,
                      onTap: _toggleOtExpansion,
                      collapsedPreview: _PhaseScorePreview(
                        home: _otHomeGoals,
                        away: _otAwayGoals,
                      ),
                    ),
                    _PhaseBody(
                      isExpanded: _isOtExpanded,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ScoreStepper(
                                label: match.homeTeam,
                                value: _otHomeGoals,
                                minValue: _homeGoals,
                                onChanged: (value) => _setOtScore(home: value),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                ':',
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                            ),
                            Expanded(
                              child: _ScoreStepper(
                                label: match.awayTeam,
                                value: _otAwayGoals,
                                minValue: _awayGoals,
                                onChanged: (value) => _setOtScore(away: value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showPenaltySection) ...[
                      const SizedBox(height: 16),
                      _PhaseExpansionHeader(
                        label: 'Sieger im Elfmeterschießen',
                        isExpanded: _isPenaltyExpanded,
                        onTap: _togglePenaltyExpansion,
                        collapsedPreview: _PenaltyWinnerPreview(
                          match: match,
                          value: _penaltyWinner,
                        ),
                      ),
                      _PhaseBody(
                        isExpanded: _isPenaltyExpanded,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _PenaltyWinnerSelector(
                            match: match,
                            value: _penaltyWinner,
                            onChanged: (value) {
                              setState(() {
                                _penaltyWinner = value;
                                _hasEdited = true;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving || !_selectionIsComplete(match)
                        ? null
                        : () => _save(match),
                    icon: const Icon(Icons.save),
                    label: Text(
                      _selectionIsComplete(match)
                          ? 'Tipp speichern'
                          : 'Tipp noch unvollständig',
                    ),
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
                                        flex: 7,
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
                                        flex: 3,
                                        child: Text(
                                          'Pkt.',
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
                                    final finalScore =
                                        match.status == MatchStatus.finalResult
                                            ? scoreTipForMatch(
                                                tip: tip,
                                                match: match,
                                              )
                                            : null;
                                    final liveScore = isLive
                                        ? scoreLiveTip(tip: tip, match: match)
                                        : null;
                                    final liveTipPoints =
                                        liveScore?.points ?? 0;

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
                                      scoreResult: finalScore,
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
                                            scoreResult: liveScore,
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
                                            flex: 7,
                                            child: Row(
                                              children: [
                                                if (!isTipCompleteForMatch(
                                                    tip, match)) ...[
                                                  Icon(
                                                    Icons.warning_amber_rounded,
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                                  ),
                                                  const SizedBox(width: 2),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    _tipDetailLabel(tip, match),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color:
                                                          isTipCompleteForMatch(
                                                                  tip, match)
                                                              ? null
                                                              : Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .error,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
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
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    match.status ==
                                                            MatchStatus
                                                                .finalResult
                                                        ? '+$totalPts'
                                                        : match.status ==
                                                                MatchStatus.live
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
                                                ),
                                                if (match.status ==
                                                    MatchStatus.live) ...[
                                                  const SizedBox(width: 4),
                                                  const LivePulseDot(size: 7),
                                                ],
                                                if (match.status ==
                                                        MatchStatus
                                                            .finalResult ||
                                                    match.status ==
                                                        MatchStatus.live)
                                                  IconButton(
                                                    tooltip: 'Wertung anzeigen',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    constraints:
                                                        const BoxConstraints(
                                                      minWidth: 28,
                                                      minHeight: 28,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    icon: const Icon(
                                                      Icons.info_outline,
                                                      size: 18,
                                                    ),
                                                    onPressed: () =>
                                                        _showRoundTipDetails(
                                                      context,
                                                      playerName: displayNames[
                                                              tip.uid] ??
                                                          'Spieler',
                                                      tipLabel: _tipDetailLabel(
                                                          tip, match),
                                                      points: match.status ==
                                                              MatchStatus
                                                                  .finalResult
                                                          ? totalPts
                                                          : liveTotalPts,
                                                      evaluation: match
                                                                  .status ==
                                                              MatchStatus
                                                                  .finalResult
                                                          ? evalStr
                                                          : liveEvalStr,
                                                    ),
                                                  ),
                                              ],
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
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave(_currentMatch);
      },
      child: scaffold,
    );
  }

  Future<void> _save(CupMatch match) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(repositoryProvider).saveTip(
            matchId: match.id,
            home: _homeGoals,
            away: _awayGoals,
            otHome: match.isKnockout && _homeGoals == _awayGoals
                ? _otHomeGoals
                : null,
            otAway: match.isKnockout && _homeGoals == _awayGoals
                ? _otAwayGoals
                : null,
            penaltyWinner: _penaltyWinner,
          );
      if (mounted) {
        _navigateBack();
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
        _otHomeGoals = 0;
        _otAwayGoals = 0;
        _penaltyWinner = null;
        _hasOtSelection = false;
        _isOtExpanded = false;
        _isPenaltyExpanded = false;
        _hasEdited = false;
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

  void _setRegularScore({int? home, int? away}) {
    _otExpansionTimer?.cancel();
    _penaltyExpansionTimer?.cancel();
    setState(() {
      _homeGoals = home ?? _homeGoals;
      _awayGoals = away ?? _awayGoals;
      if (_homeGoals == _awayGoals) {
        if (_otHomeGoals < _homeGoals) _otHomeGoals = _homeGoals;
        if (_otAwayGoals < _awayGoals) _otAwayGoals = _awayGoals;
      } else {
        _penaltyWinner = null;
        _isOtExpanded = false;
        _isPenaltyExpanded = false;
      }
      _hasEdited = true;
    });
    if (_homeGoals == _awayGoals) _scheduleOtExpansion();
  }

  void _setOtScore({int? home, int? away}) {
    _penaltyExpansionTimer?.cancel();
    setState(() {
      _otHomeGoals = home ?? _otHomeGoals;
      _otAwayGoals = away ?? _otAwayGoals;
      _penaltyWinner = null;
      _hasOtSelection = true;
      if (_otHomeGoals != _otAwayGoals) _isPenaltyExpanded = false;
      _hasEdited = true;
    });
    if (_otHomeGoals == _otAwayGoals) _schedulePenaltyExpansion();
  }

  void _toggleOtExpansion() {
    _otExpansionTimer?.cancel();
    _penaltyExpansionTimer?.cancel();
    setState(() => _isOtExpanded = !_isOtExpanded);
    if (_isOtExpanded &&
        _otHomeGoals == _otAwayGoals &&
        _penaltyWinner == null) {
      _schedulePenaltyExpansion();
    }
  }

  void _togglePenaltyExpansion() {
    _penaltyExpansionTimer?.cancel();
    setState(() => _isPenaltyExpanded = !_isPenaltyExpanded);
  }

  void _scheduleOtExpansion() {
    _otExpansionTimer?.cancel();
    _otExpansionTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted || _homeGoals != _awayGoals || _isOtExpanded) return;
      setState(() => _isOtExpanded = true);
      if (_otHomeGoals == _otAwayGoals && _penaltyWinner == null) {
        _schedulePenaltyExpansion();
      }
    });
  }

  void _schedulePenaltyExpansion() {
    _penaltyExpansionTimer?.cancel();
    _penaltyExpansionTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted ||
          !_isOtExpanded ||
          _otHomeGoals != _otAwayGoals ||
          _isPenaltyExpanded) {
        return;
      }
      setState(() => _isPenaltyExpanded = true);
    });
  }

  bool _selectionIsComplete(CupMatch match) {
    return isTipSelectionComplete(
      match: match,
      home: _homeGoals,
      away: _awayGoals,
      otHome:
          match.isKnockout && _homeGoals == _awayGoals ? _otHomeGoals : null,
      otAway:
          match.isKnockout && _homeGoals == _awayGoals ? _otAwayGoals : null,
      penaltyWinner: _penaltyWinner,
    );
  }

  Future<void> _leave(CupMatch? match) async {
    if (_isSaving) return;
    if (match != null &&
        !match.isLocked &&
        _hasEdited &&
        !_selectionIsComplete(match)) {
      setState(() => _isSaving = true);
      try {
        await ref.read(repositoryProvider).saveTip(
              matchId: match.id,
              home: _homeGoals,
              away: _awayGoals,
              otHome: _otHomeGoals,
              otAway: _otAwayGoals,
              penaltyWinner: _penaltyWinner,
            );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Entwurf konnte nicht gespeichert werden: $error')),
          );
          setState(() => _isSaving = false);
        }
        return;
      }
    }
    if (mounted) _navigateBack();
  }

  void _navigateBack() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(widget.returnPath);
      }
    });
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
    final nameStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
          color:
              isWinner ? Colors.green : Theme.of(context).colorScheme.onSurface,
        );
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
        style: nameStyle,
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
  if (tip == null || match.status != MatchStatus.finalResult) {
    return null;
  }
  return scoreTipForMatch(tip: tip, match: match);
}

String _pointsLabel(int points) {
  return points == 1 ? '1 Punkt' : '$points Punkte';
}

List<String> _scoreReasonLines(ScoreResult result) {
  if (result.details.isNotEmpty) return result.details;
  if (result.isExact) return const ['Exaktes Ergebnis'];
  if (result.isDifference) return const ['Richtige Tordifferenz'];
  if (result.isTendency) return const ['Richtige Tendenz'];
  return const ['Keine Übereinstimmung'];
}

Future<void> _showScoreDetails(
  BuildContext context, {
  required Tip tip,
  required CupMatch match,
  required ScoreResult scoreResult,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Punktevergabe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tipDetailLabel(tip, match),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _pointsLabel(scoreResult.points),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scoreResult.points > 0 ? Colors.green : null,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          for (final reason in _scoreReasonLines(scoreResult))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $reason'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    ),
  );
}

Future<void> _showRoundTipDetails(
  BuildContext context, {
  required String playerName,
  required String tipLabel,
  required int points,
  required String evaluation,
}) {
  final reasons = evaluation
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(playerName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipp: $tipLabel',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _pointsLabel(points),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: points > 0 ? Colors.green : null,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $reason'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    ),
  );
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

String _tipDetailLabel(Tip tip, CupMatch match) {
  if (!match.isKnockout) {
    return '${tip.predictedHome}:${tip.predictedAway}';
  }
  final parts = <String>['${tip.predictedHome}:${tip.predictedAway}'];
  if (tip.predictedOtHome != null && tip.predictedOtAway != null) {
    parts.add('${tip.predictedOtHome}:${tip.predictedOtAway} n.V.');
  }
  final winner = switch (tip.predictedPenaltyWinner) {
    PenaltyWinnerSide.home => match.homeTeam,
    PenaltyWinnerSide.away => match.awayTeam,
    null => null,
  };
  if (winner != null) parts.add('$winner i.E.');
  if (!isTipCompleteForMatch(tip, match)) parts.add('unvollständig');
  return parts.join(' · ');
}

class _TipSummary extends StatelessWidget {
  const _TipSummary({
    required this.tip,
    required this.match,
    required this.isComplete,
  });

  final Tip tip;
  final CupMatch match;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final color = isComplete
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.error;
    if (!match.isKnockout) {
      return Text(
        'Dein Tipp: ${tip.predictedHome}:${tip.predictedAway}',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      );
    }

    final winner = switch (tip.predictedPenaltyWinner) {
      PenaltyWinnerSide.home => match.homeTeam,
      PenaltyWinnerSide.away => match.awayTeam,
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Dein Tipp',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          '90 Min. ${tip.predictedHome}:${tip.predictedAway}',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        if (tip.predictedOtHome != null && tip.predictedOtAway != null)
          Text(
            '${tip.predictedOtHome}:${tip.predictedOtAway} n.V.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        if (!isComplete &&
            tip.predictedHome == tip.predictedAway &&
            (tip.predictedOtHome == null || tip.predictedOtAway == null))
          Text(
            'Ergebnis n.V. fehlt',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        if (winner != null)
          Text(
            '$winner i.E.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        if (!isComplete &&
            winner == null &&
            tip.predictedOtHome != null &&
            tip.predictedOtHome == tip.predictedOtAway)
          Text(
            'Sieger i.E. fehlt',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
      ],
    );
  }
}

class _PhaseExpansionHeader extends StatelessWidget {
  const _PhaseExpansionHeader({
    required this.label,
    required this.isExpanded,
    required this.onTap,
    this.collapsedPreview,
  });

  final String label;
  final Widget? collapsedPreview;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ],
              ),
              if (!isExpanded && collapsedPreview != null) ...[
                const SizedBox(height: 8),
                DefaultTextStyle.merge(
                  style: TextStyle(color: scheme.primary),
                  child: collapsedPreview!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseScorePreview extends StatelessWidget {
  const _PhaseScorePreview({required this.home, required this.away});

  final int home;
  final int away;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$home : $away',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _PenaltyWinnerPreview extends StatelessWidget {
  const _PenaltyWinnerPreview({required this.match, required this.value});

  final CupMatch match;
  final PenaltyWinnerSide? value;

  @override
  Widget build(BuildContext context) {
    final team = switch (value) {
      PenaltyWinnerSide.home => match.homeTeam,
      PenaltyWinnerSide.away => match.awayTeam,
      null => null,
    };
    if (team == null) {
      return Text(
        'Sieger wählen',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          CountryFlags.getFlag(team),
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            team,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

class _PhaseBody extends StatelessWidget {
  const _PhaseBody({
    required this.isExpanded,
    required this.child,
  });

  final bool isExpanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return isExpanded ? child : const SizedBox.shrink();
  }
}

class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({
    required this.label,
    required this.value,
    required this.minValue,
    required this.onChanged,
  });

  static const _maxGoals = 12;

  final String label;
  final int value;
  final int minValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: Center(
            child: Text(
              label,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 156,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Expanded(
                child: IconButton(
                  tooltip: 'Tor hinzufügen',
                  onPressed:
                      value < _maxGoals ? () => onChanged(value + 1) : null,
                  icon: const Icon(Icons.add),
                ),
              ),
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Expanded(
                child: IconButton(
                  tooltip: 'Tor entfernen',
                  onPressed:
                      value > minValue ? () => onChanged(value - 1) : null,
                  icon: const Icon(Icons.remove),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PenaltyWinnerSelector extends StatelessWidget {
  const _PenaltyWinnerSelector({
    required this.match,
    required this.value,
    required this.onChanged,
  });

  final CupMatch match;
  final PenaltyWinnerSide? value;
  final ValueChanged<PenaltyWinnerSide?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          RadioGroup<PenaltyWinnerSide>(
            groupValue: value,
            onChanged: onChanged,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == PenaltyWinnerSide.home,
                    label: '${match.homeTeam} als Sieger wählen',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onChanged(PenaltyWinnerSide.home),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            match.homeTeam,
                            maxLines: 3,
                            softWrap: true,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  CountryFlags.getFlag(match.homeTeam),
                  style: const TextStyle(fontSize: 24),
                ),
                Radio<PenaltyWinnerSide>(value: PenaltyWinnerSide.home),
                Radio<PenaltyWinnerSide>(value: PenaltyWinnerSide.away),
                Text(
                  CountryFlags.getFlag(match.awayTeam),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == PenaltyWinnerSide.away,
                    label: '${match.awayTeam} als Sieger wählen',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onChanged(PenaltyWinnerSide.away),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            match.awayTeam,
                            maxLines: 3,
                            softWrap: true,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (value == null) ...[
            const SizedBox(height: 6),
            Text(
              'Bitte ein finales Siegerteam auswählen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
    final targetItem = widget.value;
    if (widget.value != oldWidget.value) {
      if (_controller.hasClients && _controller.selectedItem != targetItem) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _controller.hasClients &&
              _controller.selectedItem != targetItem) {
            _controller.jumpToItem(targetItem);
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
