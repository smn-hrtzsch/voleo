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

test("final OpenLigaDB result wins when football-data final result conflicts", () => {
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
    rawStatus: "FINISHED",
    lastUpdated: "2026-06-21T18:07:46Z",
  };

  assert.deepEqual(
    __test.applyFootballDataOverlay(openLigaMatch, footballDataMatch),
    openLigaMatch
  );
});

test("recent final matches stay in the minute sync window", () => {
  const now = new Date("2026-06-21T18:10:00Z");
  assert.equal(__test.isRecentMatchWindow({
    kickoff: "2026-06-21T16:00:00Z",
    status: "finalResult",
  }, now), true);
});

test("correct OpenLigaDB final may replace a conflicting football-data final", () => {
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
  }), false);
});
