import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';

class TipEntryScreen extends ConsumerStatefulWidget {
  const TipEntryScreen({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<TipEntryScreen> createState() => _TipEntryScreenState();
}

class _TipEntryScreenState extends ConsumerState<TipEntryScreen> {
  final _homeController = TextEditingController();
  final _awayController = TextEditingController();
  bool _isSaving = false;
  bool _didSeedTip = false;

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipp'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/matches'),
        ),
      ),
      body: SafeArea(
        child: AsyncValueView<List<CupMatch>>(
          value: ref.watch(matchesProvider),
          data: (matches) {
            final match =
                matches.firstWhere((item) => item.id == widget.matchId);
            final existingTip = _tipForMatch(
              ref.watch(tipsProvider).valueOrNull ?? const <Tip>[],
              match.id,
            );
            if (!_didSeedTip && existingTip != null) {
              _homeController.text = existingTip.predictedHome.toString();
              _awayController.text = existingTip.predictedAway.toString();
              _didSeedTip = true;
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(match.stage),
                        const SizedBox(height: 12),
                        Text(
                          '${match.homeTeam} - ${match.awayTeam}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(DateFormat('dd.MM.yyyy HH:mm')
                            .format(match.kickoff)),
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
                          Chip(
                            avatar: const Icon(Icons.check, size: 18),
                            label: Text(
                              'Dein Tipp: ${existingTip.predictedHome}:${existingTip.predictedAway}',
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
                    Expanded(child: _ScoreField(controller: _homeController)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(':'),
                    ),
                    Expanded(child: _ScoreField(controller: _awayController)),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      _isSaving || match.isLocked ? null : () => _save(match),
                  icon: const Icon(Icons.save),
                  label: Text(match.isLocked ? 'Gesperrt' : 'Tipp speichern'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save(CupMatch match) async {
    final home = int.tryParse(_homeController.text);
    final away = int.tryParse(_awayController.text);
    if (home == null || away == null || home < 0 || away < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gültiges Ergebnis eingeben.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(repositoryProvider).saveTip(
            matchId: match.id,
            home: home,
            away: away,
          );
      if (mounted) context.go('/matches');
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
}

Tip? _tipForMatch(List<Tip> tips, String matchId) {
  for (final tip in tips) {
    if (tip.matchId == matchId) return tip;
  }
  return null;
}

class _ScoreField extends StatelessWidget {
  const _ScoreField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(labelText: 'Tore'),
    );
  }
}
