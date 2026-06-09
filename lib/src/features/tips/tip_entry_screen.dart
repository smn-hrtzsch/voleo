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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipp'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(widget.returnPath),
        ),
      ),
      body: SafeArea(
        child: AsyncValueView<List<CupMatch>>(
          value: ref.watch(matchesProvider),
          data: (matches) {
            final match =
                matches.firstWhere((item) => item.id == widget.matchId);
            final existingTip = _tipForMatch(
              ref.watch(tipsProvider).value ?? const <Tip>[],
              match.id,
            );
            final allTips =
                ref.watch(leagueTipsProvider).value ?? const <Tip>[];
            final standings =
                ref.watch(standingsProvider).value ?? const <Standing>[];
            final displayNames = {
              for (final standing in standings)
                standing.uid: standing.displayName,
            };
            if (!_didSeedTip && existingTip != null) {
              _homeGoals = existingTip.predictedHome;
              _awayGoals = existingTip.predictedAway;
              _didSeedTip = true;
            }
            final scoreResult = _scoreResult(match, existingTip);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                              child: _MatchupTeamLabel(
                                teamName: match.homeTeam,
                                isHome: true,
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text(
                                '-:-',
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            Expanded(
                              child: _MatchupTeamLabel(
                                teamName: match.awayTeam,
                                isHome: false,
                              ),
                            ),
                          ],
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
                        if (match.status == MatchStatus.finalResult) ...[
                          const SizedBox(height: 12),
                          Chip(
                            avatar: const Icon(Icons.sports_score, size: 18),
                            label: Text(
                              'Offizielles Ergebnis: ${match.homeScore}:${match.awayScore}',
                            ),
                          ),
                        ],
                        if (existingTip != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: InputChip(
                              avatar: const Icon(Icons.check, size: 18),
                              label: Text(
                                'Dein Tipp: ${existingTip.predictedHome}:${existingTip.predictedAway}',
                              ),
                              deleteIcon: !match.isLocked
                                  ? Icon(
                                      Icons.delete_outline,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    )
                                  : null,
                              onDeleted: !match.isLocked && !_isSaving
                                  ? () => _deleteTip(match)
                                  : null,
                              deleteButtonTooltipMessage: 'Tipp löschen',
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ScoreWheel(
                        label: match.homeTeam,
                        value: _homeGoals,
                        onChanged: (value) =>
                            setState(() => _homeGoals = value),
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
                        onChanged: (value) =>
                            setState(() => _awayGoals = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      _isSaving || match.isLocked ? null : () => _save(match),
                  icon: const Icon(Icons.save),
                  label: Text(match.isLocked ? 'Gesperrt' : 'Tipp speichern'),
                ),
                if (match.isLocked) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Tipps der Runde',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final tip
                      in allTips.where((tip) => tip.matchId == match.id))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text(
                              displayNames[tip.uid] ?? 'Spieler',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tip.predictedHome}:${tip.predictedAway}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (match.status == MatchStatus.finalResult) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${tip.points} Punkte',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
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
      if (mounted) context.go(widget.returnPath);
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
        _didSeedTip = false;
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
  });

  final String teamName;
  final bool isHome;

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
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
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

Tip? _tipForMatch(List<Tip> tips, String matchId) {
  for (final tip in tips) {
    if (tip.matchId == matchId) return tip;
  }
  return null;
}

ScoreResult? _scoreResult(CupMatch match, Tip? tip) {
  if (tip == null ||
      match.status != MatchStatus.finalResult ||
      match.homeScore == null ||
      match.awayScore == null) {
    return null;
  }
  return scoreTip(
    predictedHome: tip.predictedHome,
    predictedAway: tip.predictedAway,
    actualHome: match.homeScore!,
    actualAway: match.awayScore!,
  );
}

String _scoreLabel(ScoreResult result) {
  if (result.isExact) return '${result.points} Punkte: exaktes Ergebnis';
  if (result.points == 3) return '3 Punkte: richtige Tordifferenz';
  if (result.isTendency) return '${result.points} Punkte: richtige Tendenz';
  return '0 Punkte';
}

String _matchContextLabel(CupMatch match) {
  if (match.group.isNotEmpty) return 'Gruppe ${match.group}';
  return match.stage;
}

class _ScoreWheel extends StatelessWidget {
  const _ScoreWheel({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  static const _maxGoals = 12;

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          height: 156,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CupertinoPicker.builder(
            scrollController: FixedExtentScrollController(initialItem: value),
            itemExtent: 48,
            diameterRatio: 1.35,
            selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
              background: Color(0x1A000000),
            ),
            onSelectedItemChanged: onChanged,
            childCount: _maxGoals + 1,
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
      ],
    );
  }
}
