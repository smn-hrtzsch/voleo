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
