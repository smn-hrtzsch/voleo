import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/app_shell.dart';
import '../shared/async_value_view.dart';

class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Liga',
      selectedIndex: 2,
      child: AsyncValueView<List<Standing>>(
        value: ref.watch(standingsProvider),
        data: (standings) {
          if (standings.isEmpty) {
            return const Center(
                child: Text('Noch keine Spieler in dieser Runde.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: standings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final standing = standings[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${standing.rank}')),
                  title: Text(standing.displayName),
                  subtitle: Text(
                    '${standing.exactCount} exakt · ${standing.tendencyCount} Tendenzen',
                  ),
                  trailing: Text(
                    '${standing.totalPoints}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
