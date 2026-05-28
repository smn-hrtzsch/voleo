import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/app_shell.dart';
import '../shared/async_value_view.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Spiele',
      selectedIndex: 1,
      child: AsyncValueView<List<CupMatch>>(
        value: ref.watch(matchesProvider),
        data: (matches) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final match = matches[index];
            return Card(
              child: ListTile(
                onTap: () => context.go('/tip/${match.id}'),
                leading: _StatusIcon(status: match.status),
                title: Text('${match.homeTeam} - ${match.awayTeam}'),
                subtitle: Text(
                  '${match.stage} · ${DateFormat('dd.MM. HH:mm').format(match.kickoff)}',
                ),
                trailing: Text(
                  match.status == MatchStatus.finalResult
                      ? '${match.homeScore}:${match.awayScore}'
                      : 'Tippen',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MatchStatus.scheduled => const Icon(Icons.schedule),
      MatchStatus.live => const Icon(Icons.radar),
      MatchStatus.finalResult => const Icon(Icons.check_circle),
    };
  }
}
