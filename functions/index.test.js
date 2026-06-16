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
