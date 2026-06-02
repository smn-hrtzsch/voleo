import '../domain/voleo_models.dart';

List<CupMatch> buildWc2026GroupStageMatches() {
  final rows = <({String group, String home, String away, DateTime kickoff})>[
    (
      group: 'A',
      home: 'Mexiko',
      away: 'Südafrika',
      kickoff: DateTime(2026, 6, 11, 21)
    ),
    (
      group: 'A',
      home: 'Südkorea',
      away: 'Tschechien',
      kickoff: DateTime(2026, 6, 12, 4)
    ),
    (
      group: 'B',
      home: 'Kanada',
      away: 'Bosnien und Herzegowina',
      kickoff: DateTime(2026, 6, 12, 21)
    ),
    (
      group: 'D',
      home: 'USA',
      away: 'Paraguay',
      kickoff: DateTime(2026, 6, 13, 3)
    ),
    (
      group: 'B',
      home: 'Katar',
      away: 'Schweiz',
      kickoff: DateTime(2026, 6, 13, 21)
    ),
    (
      group: 'C',
      home: 'Brasilien',
      away: 'Marokko',
      kickoff: DateTime(2026, 6, 14)
    ),
    (
      group: 'C',
      home: 'Haiti',
      away: 'Schottland',
      kickoff: DateTime(2026, 6, 14, 3)
    ),
    (
      group: 'D',
      home: 'Australien',
      away: 'Türkei',
      kickoff: DateTime(2026, 6, 14, 6)
    ),
    (
      group: 'E',
      home: 'Deutschland',
      away: 'Curaçao',
      kickoff: DateTime(2026, 6, 14, 19)
    ),
    (
      group: 'F',
      home: 'Niederlande',
      away: 'Japan',
      kickoff: DateTime(2026, 6, 14, 22)
    ),
    (
      group: 'E',
      home: 'Elfenbeinküste',
      away: 'Ecuador',
      kickoff: DateTime(2026, 6, 15, 1)
    ),
    (
      group: 'F',
      home: 'Schweden',
      away: 'Tunesien',
      kickoff: DateTime(2026, 6, 15, 4)
    ),
    (
      group: 'H',
      home: 'Spanien',
      away: 'Kap Verde',
      kickoff: DateTime(2026, 6, 15, 18)
    ),
    (
      group: 'G',
      home: 'Belgien',
      away: 'Ägypten',
      kickoff: DateTime(2026, 6, 15, 21)
    ),
    (
      group: 'H',
      home: 'Saudi-Arabien',
      away: 'Uruguay',
      kickoff: DateTime(2026, 6, 16)
    ),
    (
      group: 'G',
      home: 'Iran',
      away: 'Neuseeland',
      kickoff: DateTime(2026, 6, 16, 3)
    ),
    (
      group: 'I',
      home: 'Frankreich',
      away: 'Senegal',
      kickoff: DateTime(2026, 6, 16, 21)
    ),
    (
      group: 'I',
      home: 'Irak',
      away: 'Norwegen',
      kickoff: DateTime(2026, 6, 17)
    ),
    (
      group: 'J',
      home: 'Argentinien',
      away: 'Algerien',
      kickoff: DateTime(2026, 6, 17, 3)
    ),
    (
      group: 'J',
      home: 'Österreich',
      away: 'Jordanien',
      kickoff: DateTime(2026, 6, 17, 6)
    ),
    (
      group: 'K',
      home: 'Portugal',
      away: 'DR Kongo',
      kickoff: DateTime(2026, 6, 17, 19)
    ),
    (
      group: 'L',
      home: 'England',
      away: 'Kroatien',
      kickoff: DateTime(2026, 6, 17, 22)
    ),
    (
      group: 'L',
      home: 'Ghana',
      away: 'Panama',
      kickoff: DateTime(2026, 6, 18, 1)
    ),
    (
      group: 'K',
      home: 'Usbekistan',
      away: 'Kolumbien',
      kickoff: DateTime(2026, 6, 18, 4)
    ),
    (
      group: 'A',
      home: 'Tschechien',
      away: 'Südafrika',
      kickoff: DateTime(2026, 6, 18, 18)
    ),
    (
      group: 'B',
      home: 'Schweiz',
      away: 'Bosnien und Herzegowina',
      kickoff: DateTime(2026, 6, 18, 21)
    ),
    (group: 'B', home: 'Kanada', away: 'Katar', kickoff: DateTime(2026, 6, 19)),
    (
      group: 'A',
      home: 'Mexiko',
      away: 'Südkorea',
      kickoff: DateTime(2026, 6, 19, 3)
    ),
    (
      group: 'D',
      home: 'USA',
      away: 'Australien',
      kickoff: DateTime(2026, 6, 19, 21)
    ),
    (
      group: 'C',
      home: 'Schottland',
      away: 'Marokko',
      kickoff: DateTime(2026, 6, 20)
    ),
    (
      group: 'C',
      home: 'Brasilien',
      away: 'Haiti',
      kickoff: DateTime(2026, 6, 20, 2, 30)
    ),
    (
      group: 'D',
      home: 'Türkei',
      away: 'Paraguay',
      kickoff: DateTime(2026, 6, 20, 5)
    ),
    (
      group: 'F',
      home: 'Niederlande',
      away: 'Schweden',
      kickoff: DateTime(2026, 6, 20, 19)
    ),
    (
      group: 'E',
      home: 'Deutschland',
      away: 'Elfenbeinküste',
      kickoff: DateTime(2026, 6, 20, 22)
    ),
    (
      group: 'E',
      home: 'Ecuador',
      away: 'Curaçao',
      kickoff: DateTime(2026, 6, 21, 2)
    ),
    (
      group: 'F',
      home: 'Tunesien',
      away: 'Japan',
      kickoff: DateTime(2026, 6, 21, 6)
    ),
    (
      group: 'H',
      home: 'Spanien',
      away: 'Saudi-Arabien',
      kickoff: DateTime(2026, 6, 21, 18)
    ),
    (
      group: 'G',
      home: 'Belgien',
      away: 'Iran',
      kickoff: DateTime(2026, 6, 21, 21)
    ),
    (
      group: 'H',
      home: 'Uruguay',
      away: 'Kap Verde',
      kickoff: DateTime(2026, 6, 22)
    ),
    (
      group: 'G',
      home: 'Neuseeland',
      away: 'Ägypten',
      kickoff: DateTime(2026, 6, 22, 3)
    ),
    (
      group: 'J',
      home: 'Argentinien',
      away: 'Österreich',
      kickoff: DateTime(2026, 6, 22, 19)
    ),
    (
      group: 'I',
      home: 'Frankreich',
      away: 'Irak',
      kickoff: DateTime(2026, 6, 22, 23)
    ),
    (
      group: 'I',
      home: 'Norwegen',
      away: 'Senegal',
      kickoff: DateTime(2026, 6, 23, 2)
    ),
    (
      group: 'J',
      home: 'Jordanien',
      away: 'Algerien',
      kickoff: DateTime(2026, 6, 23, 5)
    ),
    (
      group: 'K',
      home: 'Portugal',
      away: 'Usbekistan',
      kickoff: DateTime(2026, 6, 23, 19)
    ),
    (
      group: 'L',
      home: 'England',
      away: 'Ghana',
      kickoff: DateTime(2026, 6, 23, 22)
    ),
    (
      group: 'L',
      home: 'Panama',
      away: 'Kroatien',
      kickoff: DateTime(2026, 6, 24, 1)
    ),
    (
      group: 'K',
      home: 'Kolumbien',
      away: 'DR Kongo',
      kickoff: DateTime(2026, 6, 24, 4)
    ),
    (
      group: 'B',
      home: 'Schweiz',
      away: 'Kanada',
      kickoff: DateTime(2026, 6, 24, 21)
    ),
    (
      group: 'B',
      home: 'Bosnien und Herzegowina',
      away: 'Katar',
      kickoff: DateTime(2026, 6, 24, 21)
    ),
    (
      group: 'C',
      home: 'Marokko',
      away: 'Haiti',
      kickoff: DateTime(2026, 6, 25)
    ),
    (
      group: 'C',
      home: 'Schottland',
      away: 'Brasilien',
      kickoff: DateTime(2026, 6, 25)
    ),
    (
      group: 'A',
      home: 'Südafrika',
      away: 'Südkorea',
      kickoff: DateTime(2026, 6, 25, 3)
    ),
    (
      group: 'A',
      home: 'Tschechien',
      away: 'Mexiko',
      kickoff: DateTime(2026, 6, 25, 3)
    ),
    (
      group: 'E',
      home: 'Curaçao',
      away: 'Elfenbeinküste',
      kickoff: DateTime(2026, 6, 25, 22)
    ),
    (
      group: 'E',
      home: 'Ecuador',
      away: 'Deutschland',
      kickoff: DateTime(2026, 6, 25, 22)
    ),
    (
      group: 'F',
      home: 'Japan',
      away: 'Schweden',
      kickoff: DateTime(2026, 6, 26, 1)
    ),
    (
      group: 'F',
      home: 'Tunesien',
      away: 'Niederlande',
      kickoff: DateTime(2026, 6, 26, 1)
    ),
    (
      group: 'D',
      home: 'Paraguay',
      away: 'Australien',
      kickoff: DateTime(2026, 6, 26, 4)
    ),
    (
      group: 'D',
      home: 'Türkei',
      away: 'USA',
      kickoff: DateTime(2026, 6, 26, 4)
    ),
    (
      group: 'I',
      home: 'Norwegen',
      away: 'Frankreich',
      kickoff: DateTime(2026, 6, 26, 21)
    ),
    (
      group: 'I',
      home: 'Senegal',
      away: 'Irak',
      kickoff: DateTime(2026, 6, 26, 21)
    ),
    (
      group: 'H',
      home: 'Kap Verde',
      away: 'Saudi-Arabien',
      kickoff: DateTime(2026, 6, 27, 2)
    ),
    (
      group: 'H',
      home: 'Uruguay',
      away: 'Spanien',
      kickoff: DateTime(2026, 6, 27, 2)
    ),
    (
      group: 'G',
      home: 'Ägypten',
      away: 'Iran',
      kickoff: DateTime(2026, 6, 27, 5)
    ),
    (
      group: 'G',
      home: 'Neuseeland',
      away: 'Belgien',
      kickoff: DateTime(2026, 6, 27, 5)
    ),
    (
      group: 'L',
      home: 'Kroatien',
      away: 'Ghana',
      kickoff: DateTime(2026, 6, 27, 23)
    ),
    (
      group: 'L',
      home: 'Panama',
      away: 'England',
      kickoff: DateTime(2026, 6, 27, 23)
    ),
    (
      group: 'K',
      home: 'Kolumbien',
      away: 'Portugal',
      kickoff: DateTime(2026, 6, 28, 1, 30)
    ),
    (
      group: 'K',
      home: 'DR Kongo',
      away: 'Usbekistan',
      kickoff: DateTime(2026, 6, 28, 1, 30)
    ),
    (
      group: 'J',
      home: 'Algerien',
      away: 'Österreich',
      kickoff: DateTime(2026, 6, 28, 4)
    ),
    (
      group: 'J',
      home: 'Jordanien',
      away: 'Argentinien',
      kickoff: DateTime(2026, 6, 28, 4)
    ),
  ];

  return [
    for (var index = 0; index < rows.length; index++)
      CupMatch(
        id: 'wc2026-g${rows[index].group.toLowerCase()}-${index + 1}',
        homeTeam: rows[index].home,
        awayTeam: rows[index].away,
        kickoff: rows[index].kickoff,
        stage: 'Gruppe ${rows[index].group}',
        group: rows[index].group,
        status: MatchStatus.scheduled,
      ),
  ];
}
