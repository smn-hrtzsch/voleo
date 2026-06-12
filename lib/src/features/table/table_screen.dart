import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/clock.dart';
import '../../domain/flags.dart';
import '../../domain/voleo_models.dart';
import '../../providers.dart';
import '../shared/async_value_view.dart';
import '../shared/live_pulse_dot.dart';
import '../shared/team_name_with_picks.dart';

bool isPlaceholderTeam(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('sieger') ||
      lower.startsWith('zweiter') ||
      lower.startsWith('dritter') ||
      lower.startsWith('bester') ||
      lower.startsWith('verlierer') ||
      lower.contains('gruppe') ||
      lower.contains('sechzehntelfinale') ||
      lower.contains('achtelfinale') ||
      lower.contains('viertel') ||
      lower.contains('halb') ||
      lower.contains('platz 3') ||
      lower.contains('finale') ||
      lower.startsWith('tbd') ||
      lower.trim().isEmpty;
}

class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({super.key});

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen>
    with SingleTickerProviderStateMixin {
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

class _GroupStandingsView extends ConsumerWidget {
  const _GroupStandingsView({required this.matches});

  final List<CupMatch> matches;

  Set<String> _calculateBestThirds(
      Map<String, List<_TeamRow>> tables, List<String> officialTable) {
    final thirds = <_TeamRow>[];
    for (final group in tables.keys) {
      final rows = tables[group]!;
      if (rows.length > 2) {
        thirds.add(rows[2]);
      }
    }
    thirds.sort((a, b) {
      final pts = b.points.compareTo(a.points);
      if (pts != 0) return pts;
      final diff = b.goalDiff.compareTo(a.goalDiff);
      if (diff != 0) return diff;
      final goals = b.goalsFor.compareTo(a.goalsFor);
      if (goals != 0) return goals;
      if (officialTable.isNotEmpty) {
        final idxA = officialTable.indexOf(a.team);
        final idxB = officialTable.indexOf(b.team);
        if (idxA != -1 && idxB != -1) {
          return idxA.compareTo(idxB);
        }
      }
      return a.team.compareTo(b.team);
    });
    return thirds.take(8).map((row) => row.team).toSet();
  }

  Map<String, List<_TeamRow>> _calculateGroupTables(
      List<String> officialTable) {
    final groupMatches = matches
        .where((m) =>
            m.stage.startsWith('Gruppe') ||
            m.stage.contains('Runde') ||
            m.group.isNotEmpty)
        .toList();
    final groupTeams = <String, Set<String>>{};

    for (final m in groupMatches) {
      if (m.group.isNotEmpty) {
        groupTeams
            .putIfAbsent(m.group, () => <String>{})
            .addAll([m.homeTeam, m.awayTeam]);
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

          if (m.status == MatchStatus.live) {
            homeRow.isLive = true;
            awayRow.isLive = true;
          }

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
        if (officialTable.isNotEmpty) {
          final idxA = officialTable.indexOf(a.team);
          final idxB = officialTable.indexOf(b.team);
          if (idxA != -1 && idxB != -1) {
            return idxA.compareTo(idxB);
          }
        }
        return a.team.compareTo(b.team);
      });
      sortedTables[group] = teamRows;
    }

    return sortedTables;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officialTableAsync = ref.watch(officialTableProvider);
    final officialTable = officialTableAsync.value ?? const <String>[];
    final tables = _calculateGroupTables(officialTable);
    if (tables.isEmpty) {
      return const Center(child: Text('Keine Gruppenspiele geladen.'));
    }
    final bestThirds = _calculateBestThirds(tables, officialTable);
    final user = ref.watch(userProvider).value;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final group = tables.keys.elementAt(index);
        final rows = tables[group]!;
        return _GroupTableCard(
          group: group,
          rows: rows,
          bestThirds: bestThirds,
          user: user,
        );
      },
    );
  }
}

class _TeamRow {
  _TeamRow({
    required this.team,
  });

  final String team;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  bool isLive = false;

  int get points => won * 3 + drawn;
  int get goalDiff => goalsFor - goalsAgainst;
}

class _GroupTableCard extends StatelessWidget {
  const _GroupTableCard({
    required this.group,
    required this.rows,
    required this.bestThirds,
    required this.user,
  });

  final String group;
  final List<_TeamRow> rows;
  final Set<String> bestThirds;
  final VoleoUser? user;

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
                0: FixedColumnWidth(22), // Rank
                1: FlexColumnWidth(1.0), // Team Name
                2: FixedColumnWidth(24), // Sp
                3: FixedColumnWidth(52), // Tore
                4: FixedColumnWidth(34), // Diff
                5: FixedColumnWidth(28), // Pkt
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(color: scheme.outlineVariant, width: 1),
                    ),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('#',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.grey)),
                    ),
                    Text('Team',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.grey)),
                    Text('Sp',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.grey)),
                    Text('Tore',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.grey)),
                    Text('Diff',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.grey)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Pkt',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.grey)),
                    ),
                  ],
                ),
                for (var i = 0; i < rows.length; i++)
                  (() {
                    final row = rows[i];
                    final flag = CountryFlags.getFlag(row.team);
                    final isTopTwo = i < 2;
                    final isAdvancedThird =
                        i == 2 && bestThirds.contains(row.team);
                    final rankColor = isTopTwo
                        ? Colors.green
                        : isAdvancedThird
                            ? Colors.green
                            : scheme.onSurfaceVariant;

                    return TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: i == rows.length - 1
                                ? Colors.transparent
                                : scheme.outlineVariant.withAlpha(50),
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
                              fontWeight: (isTopTwo || isAdvancedThird)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: rankColor,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Text(flag, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: TeamNameWithPicks(
                                      teamName: row.team,
                                      user: user,
                                      isRightAligned: false,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            (isTopTwo || isAdvancedThird)
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (row.isLive) ...[
                                    const SizedBox(width: 4),
                                    const LivePulseDot(),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text('${row.played}',
                            style: const TextStyle(fontSize: 12)),
                        Text('${row.goalsFor}:${row.goalsAgainst}',
                            style: const TextStyle(fontSize: 11)),
                        Text(
                          row.goalDiff > 0
                              ? '+${row.goalDiff}'
                              : '${row.goalDiff}',
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
                              color: (isTopTwo || isAdvancedThird)
                                  ? scheme.primary
                                  : null,
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
    final p3Matches =
        matches.where((m) => m.stage == 'Spiel um Platz 3').toList();
    final finals = [...finalMatches, ...p3Matches]
      ..sort((a, b) => b.stage.compareTo(a.stage));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          height:
              2000, // Increased height to prevent overflow in columns with many matches
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

  Widget _buildRoundColumn(
      BuildContext context, String title, List<CupMatch> roundMatches) {
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
                  for (var i = 0; i < 4; i++) const _PlaceholderMatchCard()
                else
                  for (var i = 0; i < roundMatches.length; i++)
                    _TournamentMatchCard(
                      match: roundMatches[i],
                      matchIndex: i + 1,
                      roundLabel: title,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentMatchCard extends ConsumerWidget {
  const _TournamentMatchCard({
    required this.match,
    this.matchIndex = 0,
    this.roundLabel = '',
  });

  final CupMatch match;
  final int matchIndex;
  final String roundLabel;

  String _matchLabel() {
    if (match.stage == 'Finale') return 'Finale';
    if (match.stage == 'Spiel um Platz 3') return 'Platz 3';
    if (matchIndex <= 0) return '';
    switch (match.stage) {
      case 'Sechzehntelfinale':
        return '1/16 Finale $matchIndex';
      case 'Achtelfinale':
        return 'Achtelfinale $matchIndex';
      case 'Viertelfinale':
        return 'Viertelfinale $matchIndex';
      case 'Halbfinale':
        return 'Halbfinale $matchIndex';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(userProvider).value;
    final isLive = match.status == MatchStatus.live;
    final isFinal = match.status == MatchStatus.finalResult;
    final isScheduled = match.status == MatchStatus.scheduled;

    final homeFlag = CountryFlags.getFlag(match.homeTeam);
    final awayFlag = CountryFlags.getFlag(match.awayTeam);

    final isHomeWinner = isFinal && match.winner == match.homeTeam;
    final isAwayWinner = isFinal && match.winner == match.awayTeam;

    // Own tip
    final tips = ref.watch(tipsProvider).value ?? const <Tip>[];
    final tip = tips.cast<Tip?>().firstWhere(
      (t) {
        if (t == null) return false;
        if (t.matchId == match.id) return true;
        if (match.originalId != null) {
          final cleanTipId = t.matchId.replaceAll('openligadb-', '');
          final cleanOrigId = match.originalId!.replaceAll('openligadb-', '');
          if (cleanTipId == cleanOrigId) return true;
        }
        return false;
      },
      orElse: () => null,
    );
    final hasTip = tip != null;

    return GestureDetector(
      onTap: () {
        // Use push so the back button returns to the tournament tree
        context.push('/table/tip/${match.id}');
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
            // Match label + time/live
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _matchLabel(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive) ...[
                      const LivePulseDot(),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      isLive
                          ? 'LIVE'
                          : DateFormat('dd.MM. HH:mm').format(match.kickoff),
                      style: TextStyle(
                        fontSize: 9,
                        color: isLive ? Colors.green : Colors.grey,
                        fontWeight:
                            isLive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
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
                  child: TeamNameWithPicks(
                    teamName: match.homeTeam,
                    user: user,
                    isRightAligned: false,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isHomeWinner ? FontWeight.bold : FontWeight.normal,
                      color: isHomeWinner ? scheme.primary : null,
                    ),
                  ),
                ),
                if (isLive || isFinal)
                  Text(
                    '${match.homeScore ?? 0}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isHomeWinner ? FontWeight.bold : FontWeight.normal,
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
                  child: TeamNameWithPicks(
                    teamName: match.awayTeam,
                    user: user,
                    isRightAligned: false,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isAwayWinner ? FontWeight.bold : FontWeight.normal,
                      color: isAwayWinner ? scheme.primary : null,
                    ),
                  ),
                ),
                if (isLive || isFinal)
                  Text(
                    '${match.awayScore ?? 0}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isAwayWinner ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
              ],
            ),
            // Own tip
            if (hasTip) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Tipp: ${tip.predictedHome}:${tip.predictedAway}',
                  style: TextStyle(
                    fontSize: 9,
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else if (isScheduled) ...[
              const SizedBox(height: 4),
              Text(
                'Kein Tipp',
                style: TextStyle(
                  fontSize: 9,
                  color: scheme.onSurfaceVariant.withAlpha(100),
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
          style: TextStyle(
              fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
