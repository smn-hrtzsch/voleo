import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/clock.dart';
import '../../domain/flags.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';

class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({super.key});

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initializedTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeDefaultTab(List<CupMatch> matches) {
    if (_initializedTab) return;
    
    final hasKoStarted = matches.any((m) =>
        (m.stage == 'Sechzehntelfinale' ||
         m.stage == 'Achtelfinale' ||
         m.stage == 'Viertelfinale' ||
         m.stage == 'Halbfinale' ||
         m.stage == 'Spiel um Platz 3' ||
         m.stage == 'Finale') &&
        (m.status == MatchStatus.live || m.status == MatchStatus.finalResult));
    
    final groupStageOver = VoleoClock.now.isAfter(DateTime(2026, 6, 28, 22));
    
    if (hasKoStarted || groupStageOver) {
      _tabController.index = 1; // Turnierbaum
    } else {
      _tabController.index = 0; // Gruppen
    }
    _initializedTab = true;
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Turnierstand',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gruppentabellen'),
            Tab(text: 'Turnierbaum'),
          ],
        ),
      ),
      body: AsyncValueView<List<CupMatch>>(
        value: matchesAsync,
        data: (matches) {
          _initializeDefaultTab(matches);
          
          return TabBarView(
            controller: _tabController,
            children: [
              _GroupStandingsView(matches: matches),
              _TournamentTreeView(matches: matches),
            ],
          );
        },
      ),
    );
  }
}

class _GroupStandingsView extends StatelessWidget {
  const _GroupStandingsView({required this.matches});

  final List<CupMatch> matches;

  Map<String, List<_TeamRow>> _calculateGroupTables() {
    final groupMatches = matches.where((m) => m.stage.startsWith('Gruppe') || m.group.isNotEmpty).toList();
    final groupTeams = <String, Set<String>>{};
    
    for (final m in groupMatches) {
      if (m.group.isNotEmpty) {
        groupTeams.putIfAbsent(m.group, () => <String>{}).addAll([m.homeTeam, m.awayTeam]);
      }
    }

    final tables = <String, Map<String, _TeamRow>>{};
    for (final entry in groupTeams.entries) {
      final group = entry.key;
      tables[group] = {
        for (final team in entry.value) team: _TeamRow(team: team)
      };
    }

    for (final m in groupMatches) {
      if (m.group.isEmpty) continue;
      final groupTable = tables[m.group];
      if (groupTable == null) continue;

      if (m.status == MatchStatus.finalResult || m.status == MatchStatus.live) {
        final hs = m.homeScore;
        final as = m.awayScore;
        if (hs != null && as != null) {
          final homeRow = groupTable[m.homeTeam] ?? _TeamRow(team: m.homeTeam);
          final awayRow = groupTable[m.awayTeam] ?? _TeamRow(team: m.awayTeam);

          homeRow.played++;
          awayRow.played++;
          homeRow.goalsFor += hs;
          homeRow.goalsAgainst += as;
          awayRow.goalsFor += as;
          awayRow.goalsAgainst += hs;

          if (hs > as) {
            homeRow.won++;
            awayRow.lost++;
          } else if (as > hs) {
            awayRow.won++;
            homeRow.lost++;
          } else {
            homeRow.drawn++;
            awayRow.drawn++;
          }

          groupTable[m.homeTeam] = homeRow;
          groupTable[m.awayTeam] = awayRow;
        }
      }
    }

    final sortedTables = <String, List<_TeamRow>>{};
    for (final group in tables.keys.toList()..sort()) {
      final teamRows = tables[group]!.values.toList();
      teamRows.sort((a, b) {
        final pts = b.points.compareTo(a.points);
        if (pts != 0) return pts;
        final diff = b.goalDiff.compareTo(a.goalDiff);
        if (diff != 0) return diff;
        final goals = b.goalsFor.compareTo(a.goalsFor);
        if (goals != 0) return goals;
        return a.team.compareTo(b.team);
      });
      sortedTables[group] = teamRows;
    }

    return sortedTables;
  }

  @override
  Widget build(BuildContext context) {
    final tables = _calculateGroupTables();
    if (tables.isEmpty) {
      return const Center(child: Text('Keine Gruppenspiele geladen.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final group = tables.keys.elementAt(index);
        final rows = tables[group]!;
        return _GroupTableCard(group: group, rows: rows);
      },
    );
  }
}

class _TeamRow {
  _TeamRow({
    required this.team,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  final String team;
  int played;
  int won;
  int drawn;
  int lost;
  int goalsFor;
  int goalsAgainst;

  int get points => won * 3 + drawn;
  int get goalDiff => goalsFor - goalsAgainst;
}

class _GroupTableCard extends StatelessWidget {
  const _GroupTableCard({required this.group, required this.rows});

  final String group;
  final List<_TeamRow> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gruppe $group',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.0), // Rank
                1: FlexColumnWidth(4.5), // Team Name
                2: FlexColumnWidth(1.2), // Sp
                3: FlexColumnWidth(1.8), // Tore
                4: FlexColumnWidth(1.5), // Diff
                5: FlexColumnWidth(1.5), // Pkt
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: scheme.outlineVariant, width: 1),
                    ),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    ),
                    Text('Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    Text('Sp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    Text('Tore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    Text('Diff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Pkt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ),
                for (var i = 0; i < rows.length; i++)
                  (() {
                    final row = rows[i];
                    final flag = CountryFlags.getFlag(row.team);
                    final isTopTwo = i < 2;
                    final isTopThree = i == 2; // potentially qualifies

                    return TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: i == rows.length - 1 ? Colors.transparent : scheme.outlineVariant.withAlpha(50),
                            width: 0.5,
                          ),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isTopTwo ? FontWeight.bold : FontWeight.normal,
                              color: isTopTwo
                                  ? Colors.green
                                  : isTopThree
                                      ? Colors.orange
                                      : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Text(flag, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.team,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isTopTwo ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text('${row.played}', style: const TextStyle(fontSize: 12)),
                        Text('${row.goalsFor}:${row.goalsAgainst}', style: const TextStyle(fontSize: 12)),
                        Text(
                          row.goalDiff > 0 ? '+${row.goalDiff}' : '${row.goalDiff}',
                          style: TextStyle(
                            fontSize: 12,
                            color: row.goalDiff > 0
                                ? Colors.green
                                : row.goalDiff < 0
                                    ? Colors.red
                                    : null,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${row.points}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isTopTwo ? scheme.primary : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  })(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentTreeView extends StatelessWidget {
  const _TournamentTreeView({required this.matches});

  final List<CupMatch> matches;

  List<CupMatch> _getRoundMatches(String stage) {
    return matches.where((m) => m.stage == stage).toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
  }

  @override
  Widget build(BuildContext context) {
    final sf = _getRoundMatches('Sechzehntelfinale');
    final af = _getRoundMatches('Achtelfinale');
    final vf = _getRoundMatches('Viertelfinale');
    final hf = _getRoundMatches('Halbfinale');
    
    final finalMatches = matches.where((m) => m.stage == 'Finale').toList();
    final p3Matches = matches.where((m) => m.stage == 'Spiel um Platz 3').toList();
    final finals = [...finalMatches, ...p3Matches]..sort((a, b) => b.stage.compareTo(a.stage));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          height: 1650, // Fixed height allows MainAxisAlignment.spaceAround to align perfectly
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRoundColumn(context, 'Sechzehntelfinale', sf),
              const SizedBox(width: 24),
              _buildRoundColumn(context, 'Achtelfinale', af),
              const SizedBox(width: 24),
              _buildRoundColumn(context, 'Viertelfinale', vf),
              const SizedBox(width: 24),
              _buildRoundColumn(context, 'Halbfinale', hf),
              const SizedBox(width: 24),
              _buildRoundColumn(context, 'Finals', finals),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundColumn(BuildContext context, String title, List<CupMatch> roundMatches) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (roundMatches.isEmpty)
                  for (var i = 0; i < 4; i++)
                    const _PlaceholderMatchCard()
                else
                  for (final match in roundMatches)
                    _TournamentMatchCard(match: match),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentMatchCard extends ConsumerWidget {
  const _TournamentMatchCard({required this.match});

  final CupMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isLive = match.status == MatchStatus.live;
    final isFinal = match.status == MatchStatus.finalResult;

    final homeFlag = CountryFlags.getFlag(match.homeTeam);
    final awayFlag = CountryFlags.getFlag(match.awayTeam);

    final isHomeWinner = isFinal && match.winner == match.homeTeam;
    final isAwayWinner = isFinal && match.winner == match.awayTeam;

    return GestureDetector(
      onTap: () {
        // Navigate to single-match tip view
        context.go('/table/tip/${match.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLive ? Colors.green : scheme.outlineVariant.withAlpha(50),
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stage/Time label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (match.stage == 'Spiel um Platz 3')
                  const Text(
                    'Platz 3',
                    style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  isLive
                      ? 'LIVE'
                      : DateFormat('dd.MM. HH:mm').format(match.kickoff),
                  style: TextStyle(
                    fontSize: 9,
                    color: isLive ? Colors.green : Colors.grey,
                    fontWeight: isLive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Home Team Row
            Row(
              children: [
                Text(homeFlag, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    match.homeTeam,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isHomeWinner ? FontWeight.bold : FontWeight.normal,
                      color: isHomeWinner ? scheme.primary : null,
                    ),
                  ),
                ),
                if (isLive || isFinal)
                  Text(
                    '${match.homeScore ?? 0}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isHomeWinner ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            // Away Team Row
            Row(
              children: [
                Text(awayFlag, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    match.awayTeam,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isAwayWinner ? FontWeight.bold : FontWeight.normal,
                      color: isAwayWinner ? scheme.primary : null,
                    ),
                  ),
                ),
                if (isLive || isFinal)
                  Text(
                    '${match.awayScore ?? 0}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isAwayWinner ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderMatchCard extends StatelessWidget {
  const _PlaceholderMatchCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 60,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withAlpha(100),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(30),
          width: 1,
        ),
      ),
      child: const Center(
        child: Text(
          'TBD',
          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
