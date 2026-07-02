process.env.NODE_ENV = "test";

const assert = require("node:assert/strict");
const test = require("node:test");

const { __test } = require("./index");

test("team pick points use team aliases from provider names", () => {
  const points = __test.calculateExtraPoints(
    {
      favoriteTeam: "Deutschland",
      predictedChampion: "Elfenbeinküste",
    },
    [
      {
        homeTeam: "Germany",
        awayTeam: "Qatar",
        status: "finalResult",
        homeScore: 2,
        awayScore: 0,
      },
      {
        homeTeam: "Côte d'Ivoire",
        awayTeam: "Brazil",
        status: "finalResult",
        homeScore: 1,
        awayScore: 0,
      },
    ]
  );

  assert.equal(points, 20);
});

test("risk pick stage lookup uses team aliases", () => {
  const stage = __test.getEliminationStage("Deutschland", [
    {
      homeTeam: "Germany",
      awayTeam: "Brazil",
      stage: "Achtelfinale",
      status: "finalResult",
      homeScore: 0,
      awayScore: 1,
    },
  ]);

  assert.equal(stage, "Achtelfinale");
});

test("risk team tiers use team aliases", () => {
  assert.equal(__test.getTier("Germany"), "Absolute Titelfavoriten");
  assert.equal(
    __test.getTier("Bosnia and Herzegovina"),
    "Durchschnittliches Team"
  );
});

test("group-stage risk pick is penalized as soon as team reaches knockouts", () => {
  const points = __test.calculateExtraPoints({
    riskTeam: "Belgien",
    riskStage: "Gruppenphase",
  }, [{
    homeTeam: "Belgien",
    awayTeam: "Bester 3. Gruppe A/E/H/I/J",
    stage: "Sechzehntelfinale",
    status: "scheduled",
  }]);

  assert.equal(points, -40);
});

test("risk pick is not awarded early merely because its round was reached", () => {
  const points = __test.calculateExtraPoints({
    riskTeam: "Belgien",
    riskStage: "Sechzehntelfinale",
  }, [{
    homeTeam: "Belgien",
    awayTeam: "Bester 3. Gruppe A/E/H/I/J",
    stage: "Sechzehntelfinale",
    status: "scheduled",
  }]);

  assert.equal(points, 0);
});

test("winning a knockout match immediately disproves an exit in that round", () => {
  const points = __test.calculateExtraPoints({
    riskTeam: "Belgien",
    riskStage: "Sechzehntelfinale",
  }, [{
    homeTeam: "Belgien",
    awayTeam: "Kanada",
    stage: "Sechzehntelfinale",
    status: "finalResult",
    homeScore: 2,
    awayScore: 0,
  }]);

  assert.equal(points, -30);
});

test("winning the round of 32 keeps later Brazil exit calls unresolved", () => {
  const matches = [{
    homeTeam: "Brasilien",
    awayTeam: "Japan",
    stage: "Sechzehntelfinale",
    status: "finalResult",
    homeScore: 2,
    awayScore: 1,
    winner: "Brasilien",
  }];

  assert.equal(__test.calculateExtraPoints({
    riskTeam: "Brasilien",
    riskStage: "Achtelfinale",
  }, matches), 0);
  assert.equal(__test.calculateExtraPoints({
    riskTeam: "Brasilien",
    riskStage: "Viertelfinale",
  }, matches), 0);
});

test("keeps already resolved participants across later full syncs", () => {
  const preserved = __test.preserveResolvedParticipants({
    homeTeam: "Sieger Gruppe G",
    awayTeam: "Bester 3. Gruppe A/E/H/I/J",
  }, {
    homeTeam: "Belgien",
    awayTeam: "Bester 3. Gruppe A/E/H/I/J",
  });

  assert.equal(preserved.homeTeam, "Belgien");
  assert.equal(preserved.awayTeam, "Bester 3. Gruppe A/E/H/I/J");
});

test("uses partial football-data knockout fixtures as tournament preview", () => {
  const templates = [
    { id: "wc-ko-sf-1", stage: "Sechzehntelfinale", kickoff: "2026-06-29T17:00:00Z", homeTeam: "Zweiter Gruppe A", awayTeam: "Zweiter Gruppe B" },
    { id: "wc-ko-sf-2", stage: "Sechzehntelfinale", kickoff: "2026-06-29T20:00:00Z", homeTeam: "Sieger Gruppe C", awayTeam: "Zweiter Gruppe F" },
  ];
  const providers = [
    { providerId: "2", stage: "Sechzehntelfinale", kickoff: "2026-06-29T20:30:00Z", homeTeam: "Deutschland", awayTeam: null, status: "scheduled" },
    { providerId: "1", stage: "Sechzehntelfinale", kickoff: "2026-06-28T19:00:00Z", homeTeam: "Südafrika", awayTeam: "Kanada", status: "scheduled" },
  ];

  const merged = __test.mergeProviderKnockoutMatches(providers, templates);

  assert.equal(merged[0].id, "wc-ko-sf-1");
  assert.equal(merged[0].homeTeam, "Südafrika");
  assert.equal(merged[0].awayTeam, "Kanada");
  assert.equal(merged[0].kickoff, "2026-06-28T19:00:00Z");
  assert.equal(merged[1].homeTeam, "Deutschland");
  assert.equal(merged[1].awayTeam, "Zweiter Gruppe F");
});

test("resolves direct group slots from completed match results", () => {
  const groupMatches = [
    ["Belgien", "Iran", 2, 0],
    ["Ägypten", "Neuseeland", 2, 0],
    ["Belgien", "Ägypten", 1, 1],
    ["Iran", "Neuseeland", 2, 1],
    ["Ägypten", "Iran", 2, 1],
    ["Neuseeland", "Belgien", 0, 3],
  ].map(([homeTeam, awayTeam, homeScore, awayScore], index) => ({
    id: `g-${index}`,
    group: "G",
    stage: "3. Runde",
    status: "finalResult",
    homeTeam,
    awayTeam,
    homeScore,
    awayScore,
  }));
  const matches = [{
    homeTeam: "Sieger Gruppe G",
    awayTeam: "Zweiter Gruppe G",
  }];

  __test.resolveDirectGroupSlots(matches, groupMatches);

  assert.equal(matches[0].homeTeam, "Belgien");
  assert.equal(matches[0].awayTeam, "Ägypten");
});

test("FIFA third-place matrix contains all official combinations", () => {
  const matrix = require("./third-place-matrix");
  assert.equal(Object.keys(matrix).length, 495);
  assert.equal(matrix.ABCDEFGH, "HGBCAFDE");
});

test("assigns qualifying third-placed teams using the FIFA matrix", () => {
  const qualifying = new Set("ABCDEFGH".split(""));
  const tables = Object.fromEntries("ABCDEFGHIJKL".split("").map((group, index) => [
    group,
    [
      { team: `Winner ${group}`, points: 9, goalsFor: 8, goalsAgainst: 1 },
      { team: `Runner-up ${group}`, points: 6, goalsFor: 5, goalsAgainst: 2 },
      {
        team: `Third ${group}`,
        points: qualifying.has(group) ? 4 : 1,
        goalsFor: qualifying.has(group) ? 4 : 1,
        goalsAgainst: qualifying.has(group) ? 3 : 5,
      },
      { team: `Fourth ${group}`, points: 0, goalsFor: 0, goalsAgainst: 8 },
    ],
  ]));

  const assignments = __test.getThirdPlaceAssignments(tables);

  assert.equal(assignments.A, "Third H");
  assert.equal(assignments.E, "Third C");
  assert.equal(assignments.K, "Third D");
});

test("football-data final result wins when OpenLigaDB final result conflicts", () => {
  const openLigaMatch = {
    homeTeam: "Spanien",
    awayTeam: "Saudi-Arabien",
    status: "finalResult",
    homeScore: 4,
    awayScore: 0,
    source: "openligadb",
  };
  const footballDataMatch = {
    homeTeam: "Spain",
    awayTeam: "Saudi Arabia",
    status: "finalResult",
    homeScore: 5,
    awayScore: 0,
    regularHomeScore: 5,
    regularAwayScore: 0,
    rawStatus: "FINISHED",
    lastUpdated: "2026-06-21T18:07:46Z",
  };

  const result = __test.applyFootballDataOverlay(openLigaMatch, footballDataMatch);
  assert.equal(result.homeScore, 5);
  assert.equal(result.awayScore, 0);
  assert.equal(result.source, "football-data");
  assert.equal(result.providerStatus, "FINISHED");
  assert.equal(result.regularHomeScore, 5);
  assert.equal(result.regularAwayScore, 0);
});

test("football-data regular score replaces an incorrect OpenLigaDB score for scoring", () => {
  const result = __test.applyFootballDataOverlay({
    homeTeam: "Norwegen",
    awayTeam: "Frankreich",
    status: "finalResult",
    homeScore: 0,
    awayScore: 0,
    regularHomeScore: 0,
    regularAwayScore: 0,
    source: "openligadb",
  }, {
    homeTeam: "Norway",
    awayTeam: "France",
    status: "finalResult",
    homeScore: 1,
    awayScore: 4,
    regularHomeScore: 1,
    regularAwayScore: 4,
    rawStatus: "FINISHED",
    lastUpdated: "2026-06-27T07:23:05Z",
  });

  assert.equal(result.regularHomeScore, 1);
  assert.equal(result.regularAwayScore, 4);
  assert.equal(__test.scoreTip(0, 2, result.regularHomeScore, result.regularAwayScore).points, 2);
});

test("recent final matches stay in the minute sync window", () => {
  const now = new Date("2026-06-21T18:10:00Z");
  assert.equal(__test.isRecentMatchWindow({
    kickoff: "2026-06-21T16:00:00Z",
    status: "finalResult",
  }, now), true);
});

test("final payload cannot erase an already known extra-time phase", () => {
  const result = __test.preserveExistingKnockoutPhase({
    status: "live",
    regularHomeScore: 1,
    regularAwayScore: 1,
    otHomeScore: 3,
    otAwayScore: 2,
    resultNote: "EXTRA_TIME",
  }, {
    status: "finalResult",
    source: "football-data",
    homeScore: 3,
    awayScore: 2,
    regularHomeScore: 3,
    regularAwayScore: 2,
    resultNote: null,
  });

  assert.equal(result.status, "finalResult");
  assert.equal(result.regularHomeScore, 1);
  assert.equal(result.regularAwayScore, 1);
  assert.equal(result.otHomeScore, 3);
  assert.equal(result.otAwayScore, 2);
  assert.equal(result.resultNote, "EXTRA_TIME");
  assert.equal(__test.scoreTipForMatch(tip(2, 1), result).points, 0);
});

test("OpenLigaDB final cannot replace an existing football-data final", () => {
  assert.equal(__test.shouldKeepExistingMatch({
    status: "finalResult",
    homeScore: 5,
    awayScore: 0,
    source: "football-data",
  }, {
    status: "finalResult",
    homeScore: 4,
    awayScore: 0,
    source: "openligadb",
  }), true);
});

test("knockout tips award 5, 4 and 3 points after 90 minutes", () => {
  const match = knockoutMatch({ regularHomeScore: 2, regularAwayScore: 0 });

  assert.equal(__test.scoreTipForMatch(tip(2, 0), match).points, 5);
  assert.equal(__test.scoreTipForMatch(tip(3, 1), match).points, 4);
  assert.equal(__test.scoreTipForMatch(tip(1, 0), match).points, 3);
});

test("knockout tips award at most 5 points after extra time", () => {
  const match = knockoutMatch({
    regularHomeScore: 1,
    regularAwayScore: 1,
    otHomeScore: 2,
    otAwayScore: 1,
    resultNote: "EXTRA_TIME",
  });

  assert.equal(__test.scoreTipForMatch(tip(1, 1, { predictedOtHome: 2, predictedOtAway: 1 }), match).points, 5);
  assert.equal(__test.scoreTipForMatch(tip(0, 0, { predictedOtHome: 1, predictedOtAway: 0 }), match).points, 3);
});

test("knockout tips award 6 points for an exact penalty shootout path", () => {
  const match = knockoutMatch({
    regularHomeScore: 1,
    regularAwayScore: 1,
    otHomeScore: 2,
    otAwayScore: 2,
    penaltyHomeScore: 5,
    penaltyAwayScore: 4,
    resultNote: "PENALTY_SHOOTOUT",
  });
  const score = __test.scoreTipForMatch(tip(1, 1, {
    predictedOtHome: 2,
    predictedOtAway: 2,
    predictedPenaltyWinner: "home",
  }), match);

  assert.equal(score.points, 6);
  assert.equal(score.isExact, true);
});

test("a penalty prediction is ignored when the real match ends in extra time", () => {
  const match = knockoutMatch({
    regularHomeScore: 1,
    regularAwayScore: 1,
    otHomeScore: 2,
    otAwayScore: 1,
    resultNote: "EXTRA_TIME",
  });
  const score = __test.scoreTipForMatch(tip(1, 1, {
    predictedOtHome: 2,
    predictedOtAway: 1,
    predictedPenaltyWinner: "home",
  }), match);

  assert.equal(score.points, 5);
});

test("incomplete knockout drafts do not score", () => {
  const match = knockoutMatch({
    regularHomeScore: 1,
    regularAwayScore: 1,
    otHomeScore: 1,
    otAwayScore: 1,
    penaltyHomeScore: 4,
    penaltyAwayScore: 5,
    resultNote: "PENALTY_SHOOTOUT",
  });

  assert.equal(__test.scoreTipForMatch(tip(1, 1, {
    predictedOtHome: 1,
    predictedOtAway: 1,
    isComplete: false,
  }), match).points, 0);
  assert.equal(__test.scoreTipForMatch(tip(1, 1, {
    predictedOtHome: 1,
    predictedOtAway: 1,
  }), match).points, 0);
});

test("football-data penalty scores are normalized into cumulative extra time and shootout scores", () => {
  const match = __test.normalizeFootballDataMatch({
    id: 42,
    utcDate: "2026-07-10T19:00:00Z",
    status: "FINISHED",
    stage: "QUARTER_FINALS",
    homeTeam: { name: "Germany" },
    awayTeam: { name: "France" },
    score: {
      winner: "HOME_TEAM",
      duration: "PENALTY_SHOOTOUT",
      fullTime: { home: 7, away: 6 },
      regularTime: { home: 1, away: 1 },
      extraTime: { home: 0, away: 0 },
      penalties: { home: 6, away: 5 },
    },
  });

  assert.equal(match.regularHomeScore, 1);
  assert.equal(match.otHomeScore, 1);
  assert.equal(match.penaltyHomeScore, 6);
  assert.equal(match.resultNote, "PENALTY_SHOOTOUT");
});

test("football-data live matches without a score start at zero", () => {
  const match = __test.normalizeFootballDataMatch({
    id: 43,
    utcDate: "2026-07-01T19:00:00Z",
    status: "IN_PLAY",
    stage: "LAST_16",
    homeTeam: { name: "Germany" },
    awayTeam: { name: "France" },
    score: {
      winner: null,
      duration: "REGULAR",
      fullTime: { home: null, away: null },
    },
  });

  assert.equal(match.status, "live");
  assert.equal(match.homeScore, 0);
  assert.equal(match.awayScore, 0);
  assert.equal(match.regularHomeScore, null);
  assert.equal(match.regularAwayScore, null);
});

test("repairs tied football-data penalty scores from the cumulative final score", () => {
  const match = __test.normalizeFootballDataMatch({
    id: 537415,
    utcDate: "2026-06-29T20:30:00Z",
    status: "FINISHED",
    stage: "LAST_32",
    homeTeam: { name: "Germany" },
    awayTeam: { name: "Paraguay" },
    score: {
      winner: null,
      duration: "PENALTY_SHOOTOUT",
      fullTime: { home: 4, away: 5 },
      regularTime: { home: 1, away: 1 },
      extraTime: { home: 0, away: 0 },
      penalties: { home: 4, away: 4 },
    },
  });

  assert.equal(match.otHomeScore, 1);
  assert.equal(match.otAwayScore, 1);
  assert.equal(match.penaltyHomeScore, 3);
  assert.equal(match.penaltyAwayScore, 4);
  assert.equal(match.winner, "Paraguay");
});

test("places completed round-of-32 winners into their actual round-of-16 slots", () => {
  const templates = [
    { id: "wc-ko-sf-1", stage: "Sechzehntelfinale", kickoff: "2026-06-28T19:00:00Z", homeTeam: "Südafrika", awayTeam: "Kanada" },
    { id: "wc-ko-sf-2", stage: "Sechzehntelfinale", kickoff: "2026-06-29T20:30:00Z", homeTeam: "Deutschland", awayTeam: "Paraguay" },
    { id: "wc-ko-sf-3", stage: "Sechzehntelfinale", kickoff: "2026-06-30T01:00:00Z", homeTeam: "Niederlande", awayTeam: "Marokko" },
    { id: "wc-ko-sf-5", stage: "Sechzehntelfinale", kickoff: "2026-06-30T21:00:00Z", homeTeam: "Frankreich", awayTeam: "Schweden" },
    { id: "wc-ko-af-1", stage: "Achtelfinale", kickoff: "2026-07-04T21:00:00Z", homeTeam: "Sieger Sechzehntelfinale 2", awayTeam: "Sieger Sechzehntelfinale 5" },
    { id: "wc-ko-af-2", stage: "Achtelfinale", kickoff: "2026-07-04T17:00:00Z", homeTeam: "Sieger Sechzehntelfinale 1", awayTeam: "Sieger Sechzehntelfinale 3" },
  ];
  const providers = [
    { stage: "Sechzehntelfinale", kickoff: "2026-06-28T19:00:00Z", homeTeam: "Südafrika", awayTeam: "Kanada", status: "finalResult", homeScore: 0, awayScore: 1, winner: "Kanada" },
    { stage: "Sechzehntelfinale", kickoff: "2026-06-29T20:30:00Z", homeTeam: "Deutschland", awayTeam: "Paraguay", status: "finalResult", homeScore: 4, awayScore: 5, winner: "Paraguay" },
    { stage: "Sechzehntelfinale", kickoff: "2026-06-30T01:00:00Z", homeTeam: "Niederlande", awayTeam: "Marokko", status: "finalResult", homeScore: 0, awayScore: 1, winner: "Marokko" },
    { stage: "Achtelfinale", kickoff: "2026-07-04T17:00:00Z", homeTeam: "Kanada", awayTeam: null, status: "scheduled" },
    { stage: "Achtelfinale", kickoff: "2026-07-04T21:00:00Z", homeTeam: null, awayTeam: null, status: "scheduled" },
  ];

  const merged = __test.mergeProviderKnockoutMatches(providers, templates);
  const first = merged.find((match) => match.id === "wc-ko-af-1");
  const second = merged.find((match) => match.id === "wc-ko-af-2");

  assert.equal(first.homeTeam, "Paraguay");
  assert.equal(first.awayTeam, "Sieger Sechzehntelfinale 5");
  assert.equal(second.homeTeam, "Kanada");
  assert.equal(second.awayTeam, "Marokko");
});

function knockoutMatch(overrides) {
  return {
    id: "ko-1",
    homeTeam: "Deutschland",
    awayTeam: "Frankreich",
    stage: "Achtelfinale",
    group: "",
    status: "finalResult",
    ...overrides,
  };
}

function tip(predictedHome, predictedAway, overrides = {}) {
  return {
    predictedHome,
    predictedAway,
    isComplete: true,
    ...overrides,
  };
}
