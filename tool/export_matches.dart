// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:voleo/src/data/wc2026_group_stage.dart';

void main() {
  final matches = buildWc2026GroupStageMatches();
  final jsonList = matches.map((m) => {
    'id': m.id,
    'homeTeam': m.homeTeam,
    'awayTeam': m.awayTeam,
    'kickoff': m.kickoff.toUtc().toIso8601String(),
    'stage': m.stage,
    'group': m.group,
    'status': m.status.name,
    'homeScore': m.homeScore,
    'awayScore': m.awayScore,
  }).toList();

  final file = File('tool/group_stage_matches.json');
  file.writeAsStringSync(jsonEncode(jsonList));
  print('Exported ${jsonList.length} matches to ${file.path}');
}
