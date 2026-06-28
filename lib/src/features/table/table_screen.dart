import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/clock.dart';
import '../../domain/flags.dart';
import '../../domain/scoring.dart';
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

  List<_TeamRow> _getSortedThirds(
      Map<String, List<_TeamRow>> tables, OfficialTables officialTables) {
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
      if (officialTables.hasFairPlayScores) {
        final fairPlay = (officialTables.fairPlayScores[b.team] ?? 0)
            .compareTo(officialTables.fairPlayScores[a.team] ?? 0);
        if (fairPlay != 0) return fairPlay;
      }
      final rankA = _fifaRanking[a.team] ?? 999;
      final rankB = _fifaRanking[b.team] ?? 999;
      final ranking = rankA.compareTo(rankB);
      if (ranking != 0) return ranking;
      return a.team.compareTo(b.team);
    });
    return thirds;
  }

  Set<String> _calculateBestThirds(
      Map<String, List<_TeamRow>> tables, OfficialTables officialTables) {
    return _getSortedThirds(tables, officialTables)
        .take(8)
        .map((row) => row.team)
        .toSet();
  }

  String _normalizeTeamName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower == 'bosnia and herzegovina' ||
        lower == 'bosnien und herzegowina' ||
        lower == 'bosnien-herzegowina' ||
        lower == 'bosnien herzegowina') {
      return 'Bosnien-Herzegowina';
    }
    return name;
  }

  Map<String, List<_TeamRow>> _calculateGroupTables(
      OfficialTables officialTables) {
    final groupMatches = matches
        .where((m) =>
            m.stage.startsWith('Gruppe') ||
            m.stage.contains('Runde') ||
            m.group.isNotEmpty)
        .toList();
    final groupTeams = <String, Set<String>>{};

    for (final m in groupMatches) {
      if (m.group.isNotEmpty) {
        final home = _normalizeTeamName(m.homeTeam);
        final away = _normalizeTeamName(m.awayTeam);
        groupTeams.putIfAbsent(m.group, () => <String>{}).addAll([home, away]);
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
          final home = _normalizeTeamName(m.homeTeam);
          final away = _normalizeTeamName(m.awayTeam);
          final homeRow = groupTable[home] ?? _TeamRow(team: home);
          final awayRow = groupTable[away] ?? _TeamRow(team: away);

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

          groupTable[home] = homeRow;
          groupTable[away] = awayRow;
        }
      }
    }

    final sortedTables = <String, List<_TeamRow>>{};
    for (final group in tables.keys.toList()..sort()) {
      final teamRows = tables[group]!.values.toList();
      final matchesForGroup = groupMatches
          .where((match) => match.group == group)
          .map(_completedMatchRow)
          .whereType<_CompletedMatchRow>()
          .toList();
      sortedTables[group] = _sortGroupRows(
        teamRows,
        matchesForGroup,
        officialTables.fairPlayScores,
      );
    }

    return sortedTables;
  }

  _CompletedMatchRow? _completedMatchRow(CupMatch match) {
    if (match.status != MatchStatus.finalResult &&
        match.status != MatchStatus.live) {
      return null;
    }
    final homeScore = match.homeScore;
    final awayScore = match.awayScore;
    if (homeScore == null || awayScore == null) return null;
    return _CompletedMatchRow(
      home: _normalizeTeamName(match.homeTeam),
      away: _normalizeTeamName(match.awayTeam),
      homeScore: homeScore,
      awayScore: awayScore,
    );
  }

  List<_TeamRow> _sortGroupRows(
    List<_TeamRow> rows,
    List<_CompletedMatchRow> groupMatches,
    Map<String, int> fairPlayScores,
  ) {
    final byPoints = <int, List<_TeamRow>>{};
    for (final row in rows) {
      byPoints.putIfAbsent(row.points, () => <_TeamRow>[]).add(row);
    }
    final sortedPoints = byPoints.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final points in sortedPoints)
        ..._sortPointTie(byPoints[points]!, groupMatches, fairPlayScores),
    ];
  }

  List<_TeamRow> _sortPointTie(
    List<_TeamRow> tiedRows,
    List<_CompletedMatchRow> groupMatches,
    Map<String, int> fairPlayScores,
  ) {
    if (tiedRows.length <= 1) return tiedRows;
    return _sortHeadToHeadTie(tiedRows, groupMatches, fairPlayScores);
  }

  List<_TeamRow> _sortHeadToHeadTie(
    List<_TeamRow> tiedRows,
    List<_CompletedMatchRow> groupMatches,
    Map<String, int> fairPlayScores,
  ) {
    final tiedTeams = tiedRows.map((row) => row.team).toSet();
    final headToHead = {
      for (final row in tiedRows) row.team: _TieStats(),
    };
    for (final match in groupMatches) {
      if (!tiedTeams.contains(match.home) || !tiedTeams.contains(match.away)) {
        continue;
      }
      headToHead[match.home]!.apply(match.homeScore, match.awayScore);
      headToHead[match.away]!.apply(match.awayScore, match.homeScore);
    }

    final sorted = [...tiedRows]..sort((a, b) {
        final h2h =
            _compareHeadToHead(headToHead[a.team]!, headToHead[b.team]!);
        if (h2h != 0) return h2h;
        return _compareFinalTieBreakers(a, b, fairPlayScores);
      });

    final grouped = <String, List<_TeamRow>>{};
    for (final row in sorted) {
      final stats = headToHead[row.team]!;
      final key = '${stats.points}:${stats.goalDiff}:${stats.goalsFor}';
      grouped.putIfAbsent(key, () => <_TeamRow>[]).add(row);
    }

    if (grouped.length <= 1) {
      return sorted;
    }

    return [
      for (final group in grouped.values)
        if (group.length == tiedRows.length)
          ...group
        else
          ..._sortHeadToHeadTie(group, groupMatches, fairPlayScores),
    ];
  }

  int _compareHeadToHead(_TieStats a, _TieStats b) {
    final points = b.points.compareTo(a.points);
    if (points != 0) return points;
    final diff = b.goalDiff.compareTo(a.goalDiff);
    if (diff != 0) return diff;
    return b.goalsFor.compareTo(a.goalsFor);
  }

  int _compareFinalTieBreakers(
    _TeamRow a,
    _TeamRow b,
    Map<String, int> fairPlayScores,
  ) {
    final diff = b.goalDiff.compareTo(a.goalDiff);
    if (diff != 0) return diff;
    final goals = b.goalsFor.compareTo(a.goalsFor);
    if (goals != 0) return goals;
    if (fairPlayScores.isNotEmpty) {
      final fairPlay =
          (fairPlayScores[b.team] ?? 0).compareTo(fairPlayScores[a.team] ?? 0);
      if (fairPlay != 0) return fairPlay;
    }
    final rankA = _fifaRanking[a.team] ?? 999;
    final rankB = _fifaRanking[b.team] ?? 999;
    final ranking = rankA.compareTo(rankB);
    if (ranking != 0) return ranking;
    return a.team.compareTo(b.team);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officialTablesAsync = ref.watch(officialTablesProvider);
    final officialTables = officialTablesAsync.value ?? const OfficialTables();
    final tables = _calculateGroupTables(officialTables);
    if (tables.isEmpty) {
      return const Center(child: Text('Keine Gruppenspiele geladen.'));
    }
    final bestThirds = _calculateBestThirds(tables, officialTables);
    final sortedThirds = _getSortedThirds(tables, officialTables);
    final user = ref.watch(userProvider).value;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length + 1,
      itemBuilder: (context, index) {
        if (index == tables.length) {
          return _BestThirdsTableCard(
            rows: sortedThirds,
            user: user,
          );
        }
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

class _CompletedMatchRow {
  const _CompletedMatchRow({
    required this.home,
    required this.away,
    required this.homeScore,
    required this.awayScore,
  });

  final String home;
  final String away;
  final int homeScore;
  final int awayScore;
}

class _TieStats {
  int points = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get goalDiff => goalsFor - goalsAgainst;

  void apply(int scored, int conceded) {
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      points += 3;
    } else if (scored == conceded) {
      points += 1;
    }
  }
}

const _fifaRanking = <String, int>{
  'Spanien': 1,
  'Argentinien': 2,
  'Frankreich': 3,
  'England': 4,
  'Portugal': 5,
  'Niederlande': 6,
  'Brasilien': 7,
  'Belgien': 8,
  'Deutschland': 9,
  'Kroatien': 10,
  'Marokko': 11,
  'Kolumbien': 13,
  'USA': 14,
  'Mexiko': 15,
  'Uruguay': 16,
  'Schweiz': 17,
  'Senegal': 18,
  'Iran': 20,
  'Japan': 22,
  'Österreich': 23,
  'Ecuador': 24,
  'Türkei': 25,
  'Australien': 26,
  'Kanada': 27,
  'Norwegen': 29,
  'Panama': 30,
  'Ägypten': 34,
  'Algerien': 35,
  'Tunesien': 36,
  'Paraguay': 39,
  'Elfenbeinküste': 40,
  'Katar': 51,
  'Irak': 58,
  'Südafrika': 61,
  'Bosnien-Herzegowina': 72,
  'Kap Verde': 82,
  'Jordanien': 84,
  'Neuseeland': 86,
};

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
      ..sort((a, b) => _matchSlot(a).compareTo(_matchSlot(b)));
  }

  int _matchSlot(CupMatch match) {
    final matchNumberStr = RegExp(r'-(\d+)$').firstMatch(match.id)?.group(1);
    final idx = int.tryParse(matchNumberStr ?? '') ?? 999;
    if (idx == 999) return 999;

    if (match.stage == 'Sechzehntelfinale') {
      const sfMap = {
        2: 0, // sf-2 (Germany vs Paraguay)
        5: 1, // sf-5 (Frankreich vs Schweden)
        1: 2, // sf-1 (South Africa vs Canada)
        3: 3, // sf-3 (Netherlands vs Marokko)
        11: 4, // sf-11 (Portugal vs Kroatien)
        12: 5, // sf-12 (Spanien vs Österreich)
        9: 6, // sf-9 (USA vs Bosnien-Herzegowina)
        10: 7, // sf-10 (Belgien vs Senegal)
        4: 8, // sf-4 (Brasilien vs Japan)
        6: 9, // sf-6 (Elfenbeinküste vs Norwegen)
        7: 10, // sf-7 (Mexiko vs Ecuador)
        8: 11, // sf-8 (England vs DR Kongo)
        14: 12, // sf-14 (Argentinien vs Kap Verde)
        16: 13, // sf-16 (Zweiter Gruppe D vs Zweiter G)
        13: 14, // sf-13 (Schweiz vs Algerien)
        15: 15, // sf-15 (Sieger Gruppe K vs Bester 3.)
      };
      return sfMap[idx] ?? idx;
    }

    if (match.stage == 'Achtelfinale') {
      const afMap = {
        1: 0, // af-1
        2: 1, // af-2
        5: 2, // af-5
        6: 3, // af-6
        3: 4, // af-3
        4: 5, // af-4
        7: 6, // af-7
        8: 7, // af-8
      };
      return afMap[idx] ?? idx;
    }

    if (match.stage == 'Viertelfinale') {
      const vfMap = {
        1: 0, // vf-1
        2: 1, // vf-2
        3: 2, // vf-3
        4: 3, // vf-4
      };
      return vfMap[idx] ?? idx;
    }

    if (match.stage == 'Halbfinale') {
      const hfMap = {
        1: 0, // hf-1
        2: 1, // hf-2
      };
      return hfMap[idx] ?? idx;
    }

    return idx;
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
          height: 2100,
          child: Stack(
            children: [
              Positioned.fill(
                top: 40,
                child: CustomPaint(
                  painter: _BracketConnectorPainter(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRoundColumn(context, 'Sechzehntelfinale', sf, 16),
                  const SizedBox(width: 42),
                  _buildRoundColumn(context, 'Achtelfinale', af, 8),
                  const SizedBox(width: 42),
                  _buildRoundColumn(context, 'Viertelfinale', vf, 4),
                  const SizedBox(width: 42),
                  _buildRoundColumn(context, 'Halbfinale', hf, 2),
                  const SizedBox(width: 42),
                  _buildRoundColumn(context, 'Finals', finals, 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundColumn(BuildContext context, String title,
      List<CupMatch> roundMatches, int slots) {
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (title == 'Finals') {
      final finalMatches = matches.where((m) => m.stage == 'Finale').toList();
      final p3Matches =
          matches.where((m) => m.stage == 'Spiel um Platz 3').toList();

      body = Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: finalMatches.isNotEmpty
                ? _TournamentMatchCard(
                    match: finalMatches[0],
                    matchIndex: 1,
                    roundLabel: 'Finale',
                  )
                : const _PlaceholderMatchCard(),
          ),
          Align(
            alignment:
                const Alignment(0, 0.5), // Positioned at 75% height (step * 12)
            child: p3Matches.isNotEmpty
                ? _TournamentMatchCard(
                    match: p3Matches[0],
                    matchIndex: 1,
                    roundLabel: 'Spiel um Platz 3',
                  )
                : const _PlaceholderMatchCard(),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (roundMatches.isEmpty)
            for (var i = 0; i < slots; i++) const _PlaceholderMatchCard()
          else
            for (var i = 0; i < slots; i++)
              if (i < roundMatches.length)
                _TournamentMatchCard(
                  match: roundMatches[i],
                  matchIndex: i + 1,
                  roundLabel: title,
                )
              else
                const _PlaceholderMatchCard(),
        ],
      );
    }

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
            child: body,
          ),
        ],
      ),
    );
  }
}

class _BracketConnectorPainter extends CustomPainter {
  const _BracketConnectorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(150)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const columnWidth = 190.0;
    const gap = 42.0;
    final step = size.height / 16;
    for (var round = 0; round < 4; round++) {
      final leftX = round * (columnWidth + gap) + columnWidth;
      final rightX = leftX + gap;
      final groupSize = 1 << round;
      final nextGroupSize = groupSize * 2;
      final lineCount = 8 >> round;
      for (var i = 0; i < lineCount; i++) {
        final y1 = step * (i * nextGroupSize + groupSize / 2);
        final y2 = step * (i * nextGroupSize + groupSize + groupSize / 2);
        final midY = (y1 + y2) / 2;
        canvas.drawLine(Offset(leftX, y1), Offset(leftX + gap / 2, y1), paint);
        canvas.drawLine(Offset(leftX, y2), Offset(leftX + gap / 2, y2), paint);
        canvas.drawLine(
            Offset(leftX + gap / 2, y1), Offset(leftX + gap / 2, y2), paint);
        canvas.drawLine(
            Offset(leftX + gap / 2, midY), Offset(rightX, midY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter oldDelegate) {
    return oldDelegate.color != color;
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

    final matchNumberStr = RegExp(r'-(\d+)$').firstMatch(match.id)?.group(1);
    final idx = int.tryParse(matchNumberStr ?? '') ?? matchIndex;

    switch (match.stage) {
      case 'Sechzehntelfinale':
        return '1/16 Finale $idx';
      case 'Achtelfinale':
        return 'Achtelfinale $idx';
      case 'Viertelfinale':
        return 'Viertelfinale $idx';
      case 'Halbfinale':
        return 'Halbfinale $idx';
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

    final winner = match.isKnockout && isFinal ? getMatchWinner(match) : null;
    final isHomeWinner = winner != null && isSameTeam(winner, match.homeTeam);
    final isAwayWinner = winner != null && isSameTeam(winner, match.awayTeam);

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
    final tipComplete = tip != null && isTipCompleteForMatch(tip, match);

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
                    isWinner: isHomeWinner,
                    isLoser: winner != null && !isHomeWinner,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isHomeWinner ? FontWeight.bold : FontWeight.normal,
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
                      color: isHomeWinner ? Colors.green : null,
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
                    isWinner: isAwayWinner,
                    isLoser: winner != null && !isAwayWinner,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isAwayWinner ? FontWeight.bold : FontWeight.normal,
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
                      color: isAwayWinner ? Colors.green : null,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!tipComplete) ...[
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      'Tipp: ${tip.predictedHome}:${tip.predictedAway}',
                      style: TextStyle(
                        fontSize: 9,
                        color: tipComplete
                            ? scheme.onPrimaryContainer
                            : scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
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

class _BestThirdsTableCard extends StatelessWidget {
  const _BestThirdsTableCard({
    required this.rows,
    required this.user,
  });

  final List<_TeamRow> rows;
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
              'Beste drittplatzierte Mannschaften',
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
                    final isAdvanced = i < 8;
                    final rankColor =
                        isAdvanced ? Colors.green : scheme.onSurfaceVariant;

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
                              fontWeight: isAdvanced
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
                                        fontWeight: isAdvanced
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
                        Text(
                          '${row.played}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${row.goalsFor}:${row.goalsAgainst}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${row.goalDiff > 0 ? "+" : ""}${row.goalDiff}',
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
                              color: isAdvanced ? scheme.primary : null,
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
