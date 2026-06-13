const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const OPENLIGADB_URL = 'https://api.openligadb.de/getmatchdata/wm2026/2026';
const FOOTBALL_DATA_WC_MATCHES_URL = 'https://api.football-data.org/v4/competitions/WC/matches?season=2026';

const TEAM_ALIASES = new Map(Object.entries({
  qatar: 'katar',
  switzerland: 'schweiz',
  brazil: 'brasilien',
  morocco: 'marokko',
  haiti: 'haiti',
  scotland: 'schottland',
  australia: 'australien',
  turkiye: 'turkei',
  turkey: 'turkei',
  germany: 'deutschland',
  curacao: 'curacao',
  netherlands: 'niederlande',
  japan: 'japan',
  coteivoire: 'elfenbeinkuste',
  ivorycoast: 'elfenbeinkuste',
  ecuador: 'ecuador',
  sweden: 'schweden',
  tunisia: 'tunesien',
  spain: 'spanien',
  capeverde: 'kapverde',
  belgium: 'belgien',
  egypt: 'agypten',
  saudiarabia: 'saudiarabien',
  uruguay: 'uruguay',
  iran: 'iran',
  newzealand: 'neuseeland',
  france: 'frankreich',
  senegal: 'senegal',
  iraq: 'irak',
  norway: 'norwegen',
  argentina: 'argentinien',
  algeria: 'algerien',
  austria: 'osterreich',
  jordan: 'jordanien',
  portugal: 'portugal',
  drcongo: 'drkongo',
  congodr: 'drkongo',
  england: 'england',
  croatia: 'kroatien',
  ghana: 'ghana',
  panama: 'panama',
  uzbekistan: 'usbekistan',
  colombia: 'kolumbien',
  canada: 'kanada',
  bosniaherzegovina: 'bosnienherzegowina',
  bosniaandherzegovina: 'bosnienherzegowina',
  mexico: 'mexiko',
  southafrica: 'sudafrika',
  southkorea: 'sudkorea',
  czechia: 'tschechien',
  czechrepublic: 'tschechien',
  unitedstates: 'usa',
  usa: 'usa',
  paraguay: 'paraguay',
}));

const FIXTURES_LIST = [
  ['A', 'Mexiko', 'Südafrika'],
  ['A', 'Südkorea', 'Tschechien'],
  ['B', 'Kanada', 'Bosnien-Herzegowina'],
  ['D', 'USA', 'Paraguay'],
  ['B', 'Katar', 'Schweiz'],
  ['C', 'Brasilien', 'Marokko'],
  ['C', 'Haiti', 'Schottland'],
  ['D', 'Australien', 'Türkei'],
  ['E', 'Deutschland', 'Curaçao'],
  ['F', 'Niederlande', 'Japan'],
  ['E', 'Elfenbeinküste', 'Ecuador'],
  ['F', 'Schweden', 'Tunesien'],
  ['H', 'Spanien', 'Kap Verde'],
  ['G', 'Belgien', 'Ägypten'],
  ['H', 'Saudi-Arabien', 'Uruguay'],
  ['G', 'Iran', 'Neuseeland'],
  ['I', 'Frankreich', 'Senegal'],
  ['I', 'Irak', 'Norwegen'],
  ['J', 'Argentinien', 'Algerien'],
  ['J', 'Österreich', 'Jordanien'],
  ['K', 'Portugal', 'DR Kongo'],
  ['L', 'England', 'Kroatien'],
  ['L', 'Ghana', 'Panama'],
  ['K', 'Usbekistan', 'Kolumbien'],
  ['A', 'Tschechien', 'Südafrika'],
  ['B', 'Schweiz', 'Bosnien-Herzegowina'],
  ['B', 'Kanada', 'Katar'],
  ['A', 'Mexiko', 'Südkorea'],
  ['D', 'USA', 'Australien'],
  ['C', 'Schottland', 'Marokko'],
  ['C', 'Brasilien', 'Haiti'],
  ['D', 'Türkei', 'Paraguay'],
  ['F', 'Niederlande', 'Schweden'],
  ['E', 'Deutschland', 'Elfenbeinküste'],
  ['E', 'Ecuador', 'Curaçao'],
  ['F', 'Tunesien', 'Japan'],
  ['H', 'Spanien', 'Saudi-Arabien'],
  ['G', 'Belgien', 'Iran'],
  ['H', 'Uruguay', 'Kap Verde'],
  ['G', 'Neuseeland', 'Ägypten'],
  ['J', 'Argentinien', 'Österreich'],
  ['I', 'Frankreich', 'Irak'],
  ['I', 'Norwegen', 'Senegal'],
  ['J', 'Jordanien', 'Algerien'],
  ['K', 'Portugal', 'Usbekistan'],
  ['L', 'England', 'Ghana'],
  ['L', 'Panama', 'Kroatien'],
  ['K', 'Kolumbien', 'DR Kongo'],
  ['B', 'Schweiz', 'Kanada'],
  ['B', 'Bosnien-Herzegowina', 'Katar'],
  ['C', 'Marokko', 'Haiti'],
  ['C', 'Schottland', 'Brasilien'],
  ['A', 'Südafrika', 'Südkorea'],
  ['A', 'Tschechien', 'Mexiko'],
  ['E', 'Curaçao', 'Elfenbeinküste'],
  ['E', 'Ecuador', 'Deutschland'],
  ['F', 'Japan', 'Schweden'],
  ['F', 'Tunesien', 'Niederlande'],
  ['D', 'Paraguay', 'Australien'],
  ['D', 'Türkei', 'USA'],
  ['I', 'Norwegen', 'Frankreich'],
  ['I', 'Senegal', 'Irak'],
  ['H', 'Kap Verde', 'Saudi-Arabien'],
  ['H', 'Uruguay', 'Spanien'],
  ['G', 'Ägypten', 'Iran'],
  ['G', 'Neuseeland', 'Belgien'],
  ['L', 'Kroatien', 'Ghana'],
  ['L', 'Panama', 'England'],
  ['K', 'Kolumbien', 'Portugal'],
  ['K', 'DR Kongo', 'Usbekistan'],
  ['J', 'Algerien', 'Österreich'],
  ['J', 'Jordanien', 'Argentinien'],
];

const GROUP_BY_FIXTURE = new Map(
  FIXTURES_LIST.map(([group, home, away]) => [`${teamKey(home)}:${teamKey(away)}`, group])
);

function getStaticId(homeTeam, awayTeam) {
  const homeKey = teamKey(homeTeam);
  const awayKey = teamKey(awayTeam);
  const index = FIXTURES_LIST.findIndex(([group, home, away]) => teamKey(home) === homeKey && teamKey(away) === awayKey);
  if (index !== -1) {
    const group = FIXTURES_LIST[index][0];
    return `wc2026-g${group.toLowerCase()}-${index + 1}`;
  }
  return null;
}

function teamKey(value) {
  const key = String(value || "")
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/&/g, "und")
    .replace(/[^a-z0-9]/g, "");
  return TEAM_ALIASES.get(key) ?? key;
}

function groupKey(groupName) {
  if (!groupName) return "";
  const match = String(groupName).trim().match(/([A-L])$/);
  return match?.[1] ?? "";
}

function groupForFixture(homeTeam, awayTeam) {
  return GROUP_BY_FIXTURE.get(`${teamKey(homeTeam)}:${teamKey(awayTeam)}`) ?? "";
}

function determineWinner(match) {
  if (!match.matchResults || match.matchResults.length === 0) return null;
  const results = match.matchResults;

  const penalty = results.find(r => r.resultTypeID === 4 || r.resultTypeName === "nach Elfmeterschießen");
  if (penalty) {
    if (penalty.pointsTeam1 > penalty.pointsTeam2) return match.team1?.teamName;
    if (penalty.pointsTeam2 > penalty.pointsTeam1) return match.team2?.teamName;
  }

  const extraTime = results.find(r => r.resultTypeID === 3 || r.resultTypeName === "nach Verlängerung");
  if (extraTime) {
    if (extraTime.pointsTeam1 > extraTime.pointsTeam2) return match.team1?.teamName;
    if (extraTime.pointsTeam2 > extraTime.pointsTeam1) return match.team2?.teamName;
  }

  const finalResult = results.find(r => r.resultTypeID === 2 || r.resultTypeName === "Endergebnis");
  if (finalResult) {
    if (finalResult.pointsTeam1 > finalResult.pointsTeam2) return match.team1?.teamName;
    if (finalResult.pointsTeam2 > finalResult.pointsTeam1) return match.team2?.teamName;
  }

  return null;
}

function determineResultNote(match) {
  if (!match.matchResults || match.matchResults.length === 0) return null;
  const results = match.matchResults;
  const penalty = results.find(r => r.resultTypeID === 4 || r.resultTypeName === "nach Elfmeterschießen");
  if (penalty) return "n.E.";
  const extraTime = results.find(r => r.resultTypeID === 3 || r.resultTypeName === "nach Verlängerung");
  if (extraTime) return "n.V.";
  return null;
}

function normalizeMatch(match) {
  const homeTeam = match.team1?.teamName;
  const awayTeam = match.team2?.teamName;
  const kickoff = match.matchDateTimeUTC ?? match.matchDateTime;
  if (!homeTeam || !awayTeam || !kickoff) return null;
  const id = getStaticId(homeTeam, awayTeam) || String(match.matchID ?? match.matchId ?? "");
  if (!id) return null;

  const results = match.matchResults ?? [];
  const regResult = results.find(r => r.resultTypeID === 2 || r.resultTypeName === "Endergebnis");
  const otResult = results.find(r => r.resultTypeID === 3 || r.resultTypeName === "nach Verlängerung");
  const penResult = results.find(r => r.resultTypeID === 4 || r.resultTypeName === "nach Elfmeterschießen");

  const regularHomeScore = regResult !== undefined ? regResult.pointsTeam1 : null;
  const regularAwayScore = regResult !== undefined ? regResult.pointsTeam2 : null;
  const otHomeScore = otResult !== undefined ? otResult.pointsTeam1 : null;
  const otAwayScore = otResult !== undefined ? otResult.pointsTeam2 : null;
  const penaltyHomeScore = penResult !== undefined ? penResult.pointsTeam1 : null;
  const penaltyAwayScore = penResult !== undefined ? penResult.pointsTeam2 : null;

  const isFinished = match.matchIsFinished;
  const kickoffDate = new Date(kickoff);
  const now = new Date();
  const status = isFinished ? "finalResult" : (now > kickoffDate ? "live" : "scheduled");

  let homeScore = null;
  let awayScore = null;

  if (status === "live") {
    if (match.goals && match.goals.length > 0) {
      const lastGoal = match.goals[match.goals.length - 1];
      homeScore = lastGoal.scoreTeam1;
      awayScore = lastGoal.scoreTeam2;
    } else {
      homeScore = 0;
      awayScore = 0;
    }
  } else if (status === "finalResult") {
    homeScore = penaltyHomeScore !== null ? penaltyHomeScore : (otHomeScore !== null ? otHomeScore : (regularHomeScore !== null ? regularHomeScore : null));
    awayScore = penaltyAwayScore !== null ? penaltyAwayScore : (otAwayScore !== null ? otAwayScore : (regularAwayScore !== null ? regularAwayScore : null));
  }

  return {
    id,
    homeTeam,
    awayTeam,
    kickoff,
    stage: match.group?.groupName ?? "WM 2026",
    group: groupKey(match.group?.groupName) || groupForFixture(homeTeam, awayTeam),
    status,
    homeScore,
    awayScore,
    winner: determineWinner(match) ?? null,
    resultNote: determineResultNote(match) ?? null,
    source: "openligadb",
    updatedAt: new Date().toISOString(),
    regularHomeScore,
    regularAwayScore,
    otHomeScore,
    otAwayScore,
    penaltyHomeScore,
    penaltyAwayScore,
  };
}

function matchKey(homeTeam, awayTeam) {
  return `${teamKey(homeTeam)}:${teamKey(awayTeam)}`;
}

function isLiveWindow(match, now = new Date()) {
  const kickoff = new Date(match.kickoff);
  const startsSoon = kickoff.getTime() - now.getTime() <= 60 * 60 * 1000;
  const notTooOld = now.getTime() - kickoff.getTime() <= 4 * 60 * 60 * 1000;
  return startsSoon && notTooOld && match.status !== "finalResult";
}

function normalizeFootballDataMatch(match) {
  const homeTeam = match.homeTeam?.name;
  const awayTeam = match.awayTeam?.name;
  const kickoff = match.utcDate;
  if (!homeTeam || !awayTeam || !kickoff) return null;

  let status = "scheduled";
  if (["IN_PLAY", "PAUSED", "EXTRA_TIME", "PENALTY_SHOOTOUT"].includes(match.status)) {
    status = "live";
  } else if (["FINISHED", "AWARDED"].includes(match.status)) {
    status = "finalResult";
  }

  const fullTime = match.score?.fullTime ?? {};
  const halfTime = match.score?.halfTime ?? {};
  return {
    providerId: String(match.id),
    homeTeam,
    awayTeam,
    kickoff,
    status,
    rawStatus: match.status,
    minute: match.minute ?? null,
    homeScore: fullTime.home ?? null,
    awayScore: fullTime.away ?? null,
    halfHomeScore: halfTime.home ?? null,
    halfAwayScore: halfTime.away ?? null,
    lastUpdated: match.lastUpdated ?? null,
  };
}

async function fetchOpenLigaMatches() {
  const response = await fetch(OPENLIGADB_URL);
  if (!response.ok) {
    throw new Error(`OpenLigaDB request failed with ${response.status}`);
  }
  return (await response.json()).map(normalizeMatch).filter(Boolean);
}

async function fetchFirestoreMatches() {
  const matchesSnap = await db.collection("matches").get();
  const statusRank = { finalResult: 3, live: 2, scheduled: 1 };
  const byMatch = new Map();

  for (const doc of matchesSnap.docs) {
    const data = doc.data();
    const kickoff = data.kickoff?.toDate ? data.kickoff.toDate().toISOString() : data.kickoff;
    if (!data.homeTeam || !data.awayTeam || !kickoff) continue;

    const match = {
      id: doc.id,
      homeTeam: data.homeTeam,
      awayTeam: data.awayTeam,
      kickoff,
      stage: data.stage,
      group: data.group,
      status: data.status ?? "scheduled",
      homeScore: data.homeScore ?? null,
      awayScore: data.awayScore ?? null,
      winner: data.winner ?? null,
      resultNote: data.resultNote ?? null,
      source: data.source ?? "firestore",
      tipsCanonicalizedAt: data.tipsCanonicalizedAt ?? null,
    };
    const key = matchKey(match.homeTeam, match.awayTeam);
    const existing = byMatch.get(key);
    const rank = (statusRank[match.status] ?? 0) + (match.source === "football-data" ? 1 : 0);
    const existingRank = existing ? (statusRank[existing.status] ?? 0) + (existing.source === "football-data" ? 1 : 0) : -1;
    if (!existing || rank > existingRank || (!existing.tipsCanonicalizedAt && match.tipsCanonicalizedAt)) {
      byMatch.set(key, match);
    }
  }

  return [...byMatch.values()];
}

async function fetchFootballDataMatches() {
  const token = process.env.FOOTBALL_DATA_TOKEN;
  if (!token) {
    console.warn("FOOTBALL_DATA_TOKEN secret is not configured. Skipping football-data.org live overlay.");
    return { matches: [], headers: {}, status: 0 };
  }

  let response;
  try {
    response = await fetch(FOOTBALL_DATA_WC_MATCHES_URL, {
      headers: { "X-Auth-Token": token },
    });
  } catch (error) {
    console.warn("football-data.org request failed before receiving a response.", error);
    return { matches: [], headers: {}, status: 0 };
  }
  const headers = {
    apiVersion: response.headers.get("x-api-version"),
    authenticatedClient: response.headers.get("x-authenticated-client"),
    requestCounterReset: response.headers.get("x-requestcounter-reset"),
    requestsAvailable: response.headers.get("x-requestsavailable"),
  };

  if (response.status === 429) {
    console.warn("football-data.org rate limit reached.", headers);
    return { matches: [], headers, status: response.status };
  }
  if (!response.ok) {
    console.warn(`football-data.org request failed with ${response.status}.`, headers);
    return { matches: [], headers, status: response.status };
  }

  const data = await response.json();
  const matches = (data.matches ?? []).map(normalizeFootballDataMatch).filter(Boolean);
  return { matches, headers, status: response.status };
}

function applyFootballDataOverlay(openLigaMatch, footballDataMatch) {
  if (!footballDataMatch) return openLigaMatch;
  if (footballDataMatch.status !== "scheduled" &&
      (footballDataMatch.homeScore === null || footballDataMatch.awayScore === null)) {
    return openLigaMatch;
  }

  return {
    ...openLigaMatch,
    status: footballDataMatch.status,
    homeScore: footballDataMatch.homeScore,
    awayScore: footballDataMatch.awayScore,
    source: "football-data",
    providerStatus: footballDataMatch.rawStatus,
    providerUpdatedAt: footballDataMatch.lastUpdated,
    minute: footballDataMatch.minute,
  };
}

function mergeFootballDataOverlay(openLigaMatches, footballDataMatches, { liveOnly = false } = {}) {
  const footballByMatch = new Map(footballDataMatches.map((m) => [matchKey(m.homeTeam, m.awayTeam), m]));
  const now = new Date();
  return openLigaMatches.map((match) => {
    if (liveOnly && !isLiveWindow(match, now)) return match;
    return applyFootballDataOverlay(match, footballByMatch.get(matchKey(match.homeTeam, match.awayTeam)));
  });
}

function logLiveProviderComparison(openLigaMatches, footballDataMatches, footballHeaders) {
  const footballByMatch = new Map(footballDataMatches.map((m) => [matchKey(m.homeTeam, m.awayTeam), m]));
  const now = new Date();
  const relevant = openLigaMatches.filter((match) => isLiveWindow(match, now));
  console.log(`Live provider check: ${relevant.length} relevant match(es). football-data headers: ${JSON.stringify(footballHeaders)}`);
  for (const match of relevant) {
    const fd = footballByMatch.get(matchKey(match.homeTeam, match.awayTeam));
    console.log("Live provider comparison", JSON.stringify({
      match: `${match.homeTeam} - ${match.awayTeam}`,
      kickoff: match.kickoff,
      openLiga: {
        status: match.status,
        score: `${match.homeScore ?? "-"}:${match.awayScore ?? "-"}`,
      },
      footballData: fd ? {
        status: fd.rawStatus,
        normalizedStatus: fd.status,
        minute: fd.minute,
        score: `${fd.homeScore ?? "-"}:${fd.awayScore ?? "-"}`,
        lastUpdated: fd.lastUpdated,
      } : null,
    }));
  }
}

function scoreTip(predictedHome, predictedAway, actualHome, actualAway) {
  if (predictedHome === actualHome && predictedAway === actualAway) {
    return { points: 4, isExact: true, isTendency: true };
  }
  const predictedDiff = predictedHome - predictedAway;
  const actualDiff = actualHome - actualAway;
  if (predictedDiff === actualDiff && actualDiff !== 0) {
    return { points: 3, isExact: false, isTendency: true };
  }
  if (Math.sign(predictedDiff) === Math.sign(actualDiff)) {
    return { points: 2, isExact: false, isTendency: true };
  }
  return { points: 0, isExact: false, isTendency: false };
}

function getTier(team) {
  const favorites = ["Argentinien", "Brasilien", "Deutschland", "England", "Frankreich", "Portugal", "Spanien"];
  const tops = ["Belgien", "Japan", "Kroatien", "Marokko", "Niederlande", "Norwegen", "Schweiz", "Senegal", "Uruguay"];
  const mids = [
    "Algerien", "Australien", "Bosnien und Herzegowina", "Bosnien-Herzegowina", "Bosnien Herzegowina",
    "Bosnia and Herzegovina", "Kolumbien", "Ecuador", "Elfenbeinküste", "Ghana", "Mexiko", "Österreich",
    "Schweden", "Südkorea", "Tschechien", "Türkei", "USA"
  ];
  if (favorites.includes(team)) return "Absolute Titelfavoriten";
  if (tops.includes(team)) return "Top Team";
  if (mids.includes(team)) return "Durchschnittliches Team";
  return "Gurkentruppe";
}

function stageRank(stage) {
  switch (stage) {
    case "Gruppenphase": return 0;
    case "Sechzehntelfinale": return 1;
    case "Achtelfinale": return 2;
    case "Viertelfinale": return 3;
    case "Halbfinale": return 4;
    case "Finale": return 5;
    case "Champion": return 6;
  }
  return 99;
}

function getMatchWinner(match) {
  if (match.winner) return match.winner;
  if (match.status !== "finalResult" || match.homeScore == null || match.awayScore == null) {
    return null;
  }
  if (match.homeScore > match.awayScore) return match.homeTeam;
  if (match.awayScore > match.homeScore) return match.awayTeam;
  return null;
}

function getEliminationStage(team, allMatches) {
  const teamMatches = allMatches.filter((m) => m.homeTeam === team || m.awayTeam === team);
  if (teamMatches.length === 0) return null;

  const knockouts = teamMatches.filter((m) => !m.stage.startsWith("Gruppe") && !m.stage.includes("Runde"));

  for (const m of knockouts) {
    if (m.status === "finalResult") {
      const winner = getMatchWinner(m);
      if (winner && winner !== team) {
        const stage = m.stage.toLowerCase();
        if (stage.includes("sechzehntel") || stage.includes("32")) return "Sechzehntelfinale";
        if (stage.includes("achtel") || stage.includes("16")) return "Achtelfinale";
        if (stage.includes("viertel") || stage.includes("quarter")) return "Viertelfinale";
        if (stage.includes("halb") || stage.includes("semi")) return "Halbfinale";
        if (stage.includes("final")) return "Finale";
      }
    }
  }

  const hasWonFinal = knockouts.some(
    (m) =>
      m.stage.toLowerCase().includes("final") &&
      !m.stage.toLowerCase().includes("halb") &&
      !m.stage.toLowerCase().includes("viertel") &&
      m.status === "finalResult" &&
      getMatchWinner(m) === team
  );
  if (hasWonFinal) return "Champion";

  const groupMatches = allMatches.filter((m) => m.stage.startsWith("Gruppe") || m.stage.includes("Runde"));
  const allGroupsFinished = groupMatches.length > 0 && groupMatches.every((m) => m.status === "finalResult");
  if (allGroupsFinished && knockouts.length === 0) {
    return "Gruppenphase";
  }

  return null;
}

function calculateRiskPoints(team, predictedStage, actualStage) {
  const tier = getTier(team);
  const isCorrect = stageRank(actualStage) <= stageRank(predictedStage);

  if (tier === "Absolute Titelfavoriten") {
    if (predictedStage === "Gruppenphase") return isCorrect ? 70 : -70;
    if (predictedStage === "Sechzehntelfinale") return isCorrect ? 60 : -60;
    if (predictedStage === "Achtelfinale") return isCorrect ? 50 : -50;
    if (predictedStage === "Viertelfinale") return isCorrect ? 30 : -30;
    if (predictedStage === "Halbfinale") return isCorrect ? 15 : -15;
    if (predictedStage === "Finale") return isCorrect ? 5 : -5;
  } else if (tier === "Top Team") {
    if (predictedStage === "Gruppenphase") return isCorrect ? 40 : -40;
    if (predictedStage === "Sechzehntelfinale") return isCorrect ? 30 : -30;
    if (predictedStage === "Achtelfinale") return isCorrect ? 20 : -20;
    if (predictedStage === "Viertelfinale") return isCorrect ? 20 : -20;
    if (predictedStage === "Halbfinale") return isCorrect ? 40 : -40;
    if (predictedStage === "Finale") return isCorrect ? 50 : -50;
  } else if (tier === "Durchschnittliches Team") {
    if (predictedStage === "Gruppenphase") return isCorrect ? 5 : -5;
    if (predictedStage === "Sechzehntelfinale") return isCorrect ? 10 : -10;
    if (predictedStage === "Achtelfinale") return isCorrect ? 15 : -15;
    if (predictedStage === "Viertelfinale") return isCorrect ? 35 : -35;
    if (predictedStage === "Halbfinale") return isCorrect ? 55 : -55;
    if (predictedStage === "Finale") return isCorrect ? 65 : -65;
  } else {
    // Gurkentruppe
    if (predictedStage === "Gruppenphase") return isCorrect ? 5 : -5;
    if (predictedStage === "Sechzehntelfinale") return isCorrect ? 15 : -15;
    if (predictedStage === "Achtelfinale") return isCorrect ? 30 : -30;
    if (predictedStage === "Viertelfinale") return isCorrect ? 50 : -50;
    if (predictedStage === "Halbfinale") return isCorrect ? 65 : -65;
    if (predictedStage === "Finale") return isCorrect ? 80 : -80;
  }
  return 0;
}

function calculateExtraPoints(userData, allMatches) {
  let extraPoints = 0;
  if (!userData) return 0;

  const fav = userData.favoriteTeam;
  if (fav) {
    for (const match of allMatches) {
      if (match.status === "finalResult") {
        if (getMatchWinner(match) === fav) {
          extraPoints += 10;
        }
      }
    }
  }

  const championTipp = userData.predictedChampion;
  if (championTipp) {
    for (const match of allMatches) {
      if (match.status === "finalResult") {
        if (getMatchWinner(match) === championTipp) {
          extraPoints += 10;
        }
      }
    }
  }

  const rTeam = userData.riskTeam;
  const rStage = userData.riskStage;
  if (rTeam && rStage) {
    const actualStage = getEliminationStage(rTeam, allMatches);
    if (actualStage) {
      extraPoints += calculateRiskPoints(rTeam, rStage, actualStage);
    }
  }

  return extraPoints;
}

function getKnockoutMatches() {
  const list = [];
  const sfMatches = [
    ['Zweiter Gruppe A', 'Zweiter Gruppe B', '2026-06-29T17:00:00Z'],
    ['Sieger Gruppe C', 'Zweiter Gruppe F', '2026-06-29T20:00:00Z'],
    ['Sieger Gruppe E', 'Bester 3. Gruppe A/B/C/D/F', '2026-06-30T17:00:00Z'],
    ['Sieger Gruppe F', 'Zweiter Gruppe C', '2026-06-30T20:00:00Z'],
    ['Zweiter Gruppe E', 'Zweiter Gruppe I', '2026-07-01T17:00:00Z'],
    ['Sieger Gruppe I', 'Bester 3. Gruppe C/D/F/G/H', '2026-07-01T20:00:00Z'],
    ['Sieger Gruppe A', 'Bester 3. Gruppe C/E/F/H/I', '2026-07-02T17:00:00Z'],
    ['Sieger Gruppe L', 'Bester 3. Gruppe E/H/I/J/K', '2026-07-02T20:00:00Z'],
    ['Sieger Gruppe G', 'Bester 3. Gruppe A/E/H/I/J', '2026-07-03T17:00:00Z'],
    ['Sieger Gruppe D', 'Bester 3. Gruppe B/E/F/I/J', '2026-07-03T20:00:00Z'],
    ['Sieger Gruppe H', 'Zweiter Gruppe J', '2026-07-04T17:00:00Z'],
    ['Zweiter Gruppe K', 'Zweiter Gruppe L', '2026-07-04T20:00:00Z'],
    ['Sieger Gruppe B', 'Bester 3. Gruppe E/F/G/I/J', '2026-07-05T17:00:00Z'],
    ['Zweiter Gruppe D', 'Zweiter Gruppe G', '2026-07-05T20:00:00Z'],
    ['Sieger Gruppe J', 'Zweiter Gruppe H', '2026-07-06T17:00:00Z'],
    ['Sieger Gruppe K', 'Bester 3. Gruppe D/E/I/J/L', '2026-07-06T20:00:00Z'],
  ];

  for (let i = 0; i < sfMatches.length; i++) {
    const m = sfMatches[i];
    list.push({
      id: `wc-ko-sf-${i + 1}`,
      homeTeam: m[0],
      awayTeam: m[1],
      kickoff: m[2],
      stage: 'Sechzehntelfinale',
      group: '',
      status: 'scheduled',
      homeScore: null,
      awayScore: null,
    });
  }

  const afMatches = [
    ['Sieger Sechzehntelfinale 1', 'Sieger Sechzehntelfinale 3', '2026-07-07T17:00:00Z'],
    ['Sieger Sechzehntelfinale 2', 'Sieger Sechzehntelfinale 4', '2026-07-07T20:00:00Z'],
    ['Sieger Sechzehntelfinale 5', 'Sieger Sechzehntelfinale 7', '2026-07-08T17:00:00Z'],
    ['Sieger Sechzehntelfinale 6', 'Sieger Sechzehntelfinale 8', '2026-07-08T20:00:00Z'],
    ['Sieger Sechzehntelfinale 9', 'Sieger Sechzehntelfinale 11', '2026-07-09T17:00:00Z'],
    ['Sieger Sechzehntelfinale 10', 'Sieger Sechzehntelfinale 12', '2026-07-09T20:00:00Z'],
    ['Sieger Sechzehntelfinale 13', 'Sieger Sechzehntelfinale 15', '2026-07-10T17:00:00Z'],
    ['Sieger Sechzehntelfinale 14', 'Sieger Sechzehntelfinale 16', '2026-07-10T20:00:00Z'],
  ];

  for (let i = 0; i < afMatches.length; i++) {
    const m = afMatches[i];
    list.push({
      id: `wc-ko-af-${i + 1}`,
      homeTeam: m[0],
      awayTeam: m[1],
      kickoff: m[2],
      stage: 'Achtelfinale',
      group: '',
      status: 'scheduled',
      homeScore: null,
      awayScore: null,
    });
  }

  const vfMatches = [
    ['Sieger Achtelfinale 1', 'Sieger Achtelfinale 3', '2026-07-12T17:00:00Z'],
    ['Sieger Achtelfinale 2', 'Sieger Achtelfinale 4', '2026-07-12T20:00:00Z'],
    ['Sieger Achtelfinale 5', 'Sieger Achtelfinale 7', '2026-07-13T17:00:00Z'],
    ['Sieger Achtelfinale 6', 'Sieger Achtelfinale 8', '2026-07-13T20:00:00Z'],
  ];

  for (let i = 0; i < vfMatches.length; i++) {
    const m = vfMatches[i];
    list.push({
      id: `wc-ko-vf-${i + 1}`,
      homeTeam: m[0],
      awayTeam: m[1],
      kickoff: m[2],
      stage: 'Viertelfinale',
      group: '',
      status: 'scheduled',
      homeScore: null,
      awayScore: null,
    });
  }

  const hfMatches = [
    ['Sieger Viertelfinale 1', 'Sieger Viertelfinale 3', '2026-07-15T19:00:00Z'],
    ['Sieger Viertelfinale 2', 'Sieger Viertelfinale 4', '2026-07-16T19:00:00Z'],
  ];

  for (let i = 0; i < hfMatches.length; i++) {
    const m = hfMatches[i];
    list.push({
      id: `wc-ko-hf-${i + 1}`,
      homeTeam: m[0],
      awayTeam: m[1],
      kickoff: m[2],
      stage: 'Halbfinale',
      group: '',
      status: 'scheduled',
      homeScore: null,
      awayScore: null,
    });
  }

  list.push({
    id: `wc-ko-p3-1`,
    homeTeam: 'Verlierer Halbfinale 1',
    awayTeam: 'Verlierer Halbfinale 2',
    kickoff: '2026-07-18T19:00:00Z',
    stage: 'Spiel um Platz 3',
    group: '',
    status: 'scheduled',
    homeScore: null,
    awayScore: null,
  });

  list.push({
    id: `wc-ko-fi-1`,
    homeTeam: 'Sieger Halbfinale 1',
    awayTeam: 'Sieger Halbfinale 2',
    kickoff: '2026-07-19T19:00:00Z',
    stage: 'Finale',
    group: '',
    status: 'scheduled',
    homeScore: null,
    awayScore: null,
  });

  return list;
}

function rankStandings(entries) {
  const sorted = entries.sort((a, b) => {
    const points = b.totalPoints - a.totalPoints;
    if (points !== 0) return points;
    const exact = b.exactCount - a.exactCount;
    if (exact !== 0) return exact;
    const difference = (b.differenceCount ?? 0) - (a.differenceCount ?? 0);
    if (difference !== 0) return difference;
    return a.displayName.localeCompare(b.displayName);
  });

  let rank = 0;
  let previous = "";
  return sorted.map((standing, index) => {
    const key = `${standing.totalPoints}:${standing.exactCount}:${standing.differenceCount ?? 0}`;
    if (key !== previous) {
      rank = index + 1;
      previous = key;
    }
    return { ...standing, rank };
  });
}

async function recalculateScores(allMatches, finalMatches) {
  if (finalMatches.length === 0) return;
  const finalMatchById = new Map();
  for (const m of finalMatches) {
    finalMatchById.set(m.id, m);
    finalMatchById.set(`openligadb-${m.id}`, m);
    const staticId = getStaticId(m.homeTeam, m.awayTeam);
    if (staticId) {
      finalMatchById.set(staticId, m);
    }
  }

  const leaguesSnap = await db.collection("leagues").get();
  for (const leagueDoc of leaguesSnap.docs) {
    const leagueId = leagueDoc.id;
    const membersSnap = await db.collection("leagues").doc(leagueId).collection("members").get();
    
    // Fetch user documents for extra points
    const userFieldsMap = new Map();
    for (const memberDoc of membersSnap.docs) {
      const uid = memberDoc.id;
      try {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists) {
          userFieldsMap.set(uid, userDoc.data());
        }
      } catch (err) {
        console.error(`Failed to load user doc for ${uid}:`, err);
      }
    }

    const displayNames = new Map(
      membersSnap.docs.map((doc) => [doc.id, doc.data().displayName ?? "Spieler"])
    );

    const photoUrls = new Map(
      membersSnap.docs.map((doc) => {
        const uid = doc.id;
        const userData = userFieldsMap.get(uid);
        return [uid, userData?.photoUrl ?? doc.data().photoUrl ?? null];
      })
    );

    const tipsSnap = await db.collection("leagues").doc(leagueId).collection("tips").get();
    const stats = new Map();
    const batch = db.batch();

    // Initialize stats
    membersSnap.forEach((memberDoc) => {
      const uid = memberDoc.id;
      const data = memberDoc.data();
      const joinedAt = data.joinedAt ? data.joinedAt.toDate() : new Date(0);
      const leftAt = data.leftAt ? data.leftAt.toDate() : null;

      const frozenPoints = data.frozenPoints ?? 0;
      const frozenExactCount = data.frozenExactCount ?? 0;
      const frozenDifferenceCount = data.frozenDifferenceCount ?? 0;
      const frozenTendencyCount = data.frozenTendencyCount ?? 0;

      stats.set(uid, {
        uid,
        displayName: displayNames.get(uid) ?? "Spieler",
        photoUrl: photoUrls.get(uid) ?? null,
        totalPoints: leftAt !== null ? frozenPoints : frozenPoints,
        exactCount: leftAt !== null ? frozenExactCount : frozenExactCount,
        differenceCount: leftAt !== null ? frozenDifferenceCount : frozenDifferenceCount,
        tendencyCount: leftAt !== null ? frozenTendencyCount : frozenTendencyCount,
        joinedAt,
        leftAt,
      });
    });

    // Deduplicate and cleanup tips (e.g. if the user tipped the same match via multiple IDs)
    const userMatchTips = new Map();
    tipsSnap.forEach((tipDoc) => {
      const data = tipDoc.data();
      const matchId = data.matchId;
      const match = finalMatchById.get(matchId);
      if (!match) return;

      const uid = data.uid;
      const key = `${uid}:${match.id}`;
      const existing = userMatchTips.get(key);
      if (!existing) {
        userMatchTips.set(key, { tipDoc, data, match });
      } else {
        const parseTime = (val) => {
          if (!val) return 0;
          if (val.toDate) return val.toDate().getTime();
          return new Date(val).getTime();
        };
        const curTime = parseTime(data.updatedAt);
        const prevTime = parseTime(existing.data.updatedAt);
        
        if (curTime > prevTime) {
          // Delete the old duplicate from Firestore
          batch.delete(existing.tipDoc.ref);
          userMatchTips.set(key, { tipDoc, data, match });
        } else {
          // Delete this duplicate from Firestore
          batch.delete(tipDoc.ref);
        }
      }
    });

    // Score tips
    for (const { tipDoc, data, match } of userMatchTips.values()) {
      const uid = data.uid;
      const current = stats.get(uid);
      if (!current) continue;

      if (current.leftAt !== null) continue;

      const matchKickoff = new Date(match.kickoff);
      if (matchKickoff < current.joinedAt) continue;

      const actualHome = match.regularHomeScore !== undefined && match.regularHomeScore !== null ? match.regularHomeScore : match.homeScore;
      const actualAway = match.regularAwayScore !== undefined && match.regularAwayScore !== null ? match.regularAwayScore : match.awayScore;

      const score = scoreTip(
        data.predictedHome ?? 0,
        data.predictedAway ?? 0,
        actualHome,
        actualAway
      );

      // Update tip points in Firestore
      batch.update(tipDoc.ref, { points: score.points });

      current.totalPoints += score.points;
      if (score.isExact) {
        current.exactCount += 1;
      } else if (score.points === 3) {
        current.differenceCount = (current.differenceCount ?? 0) + 1;
      } else if (score.isTendency) {
        current.tendencyCount += 1;
      }
      stats.set(uid, current);
    }

    // Add extra points for each active user
    for (const [uid, current] of stats.entries()) {
      if (current.leftAt !== null) continue;
      const userData = userFieldsMap.get(uid);
      const activeMatches = allMatches.filter((m) => new Date(m.kickoff) >= current.joinedAt);
      const extra = calculateExtraPoints(userData, activeMatches);
      current.totalPoints += extra;
    }

    // Rank and update standings
    const activeStats = [...stats.values()].filter((s) => s.leftAt === null);
    const ranked = rankStandings(activeStats);

    // Delete standings for members who have left the league
    for (const standing of stats.values()) {
      if (standing.leftAt !== null) {
        const standingRef = db.collection("leagues").doc(leagueId).collection("standings").doc(standing.uid);
        batch.delete(standingRef);
      }
    }

    for (const standing of ranked) {
      const standingRef = db.collection("leagues").doc(leagueId).collection("standings").doc(standing.uid);
      batch.set(standingRef, {
        displayName: standing.displayName,
        totalPoints: standing.totalPoints,
        exactCount: standing.exactCount,
        differenceCount: standing.differenceCount ?? 0,
        tendencyCount: standing.tendencyCount,
        rank: standing.rank,
        photoUrl: standing.photoUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    await batch.commit();
  }
}

async function cleanupDuplicateTips(allMatches) {
  const matchByKnownId = new Map();
  for (const match of allMatches) {
    matchByKnownId.set(match.id, match);
    matchByKnownId.set(`openligadb-${match.id}`, match);
    const staticId = getStaticId(match.homeTeam, match.awayTeam);
    if (staticId) {
      matchByKnownId.set(staticId, match);
    }
  }

  const parseTime = (val) => {
    if (!val) return 0;
    if (val.toDate) return val.toDate().getTime();
    return new Date(val).getTime();
  };

  let deletedCount = 0;
  const leaguesSnap = await db.collection("leagues").get();
  for (const leagueDoc of leaguesSnap.docs) {
    const tipsSnap = await leagueDoc.ref.collection("tips").get();
    const userMatchTips = new Map();
    const batch = db.batch();
    let leagueDeletedCount = 0;

    tipsSnap.forEach((tipDoc) => {
      const data = tipDoc.data();
      const match = matchByKnownId.get(data.matchId);
      if (!match) return;

      const key = `${data.uid}:${match.id}`;
      const existing = userMatchTips.get(key);
      if (!existing) {
        userMatchTips.set(key, { tipDoc, data });
        return;
      }

      const curTime = parseTime(data.updatedAt);
      const prevTime = parseTime(existing.data.updatedAt);
      if (curTime > prevTime) {
        batch.delete(existing.tipDoc.ref);
        userMatchTips.set(key, { tipDoc, data });
      } else {
        batch.delete(tipDoc.ref);
      }
      leagueDeletedCount += 1;
      deletedCount += 1;
    });

    if (leagueDeletedCount > 0) {
      await batch.commit();
    }
  }

  if (deletedCount > 0) {
    console.log(`Cleaned up ${deletedCount} duplicate tip document(s).`);
  }
}

function equivalentTipMatchIds(match) {
  const ids = new Set([match.id, `openligadb-${match.id}`]);
  const staticId = getStaticId(match.homeTeam, match.awayTeam);
  if (staticId) ids.add(staticId);
  return [...ids];
}

function targetTipMatchId(match) {
  return getStaticId(match.homeTeam, match.awayTeam) ?? match.id;
}

async function canonicalizeTipsForMatch(match) {
  const parseTime = (val) => {
    if (!val) return 0;
    if (val.toDate) return val.toDate().getTime();
    return new Date(val).getTime();
  };

  const ids = new Set(equivalentTipMatchIds(match));
  const targetMatchId = targetTipMatchId(match);
  let updatedCount = 0;
  let deletedCount = 0;
  const leaguesSnap = await db.collection("leagues").get();

  for (const leagueDoc of leaguesSnap.docs) {
    const tipsSnap = await leagueDoc.ref.collection("tips").get();
    if (tipsSnap.empty) continue;

    const uniqueTips = new Map();
    const batch = db.batch();
    let leagueChangedCount = 0;

    tipsSnap.forEach((tipDoc) => {
      const data = tipDoc.data();
      if (!ids.has(data.matchId)) return;

      const key = `${data.uid}:${targetMatchId}`;
      const existing = uniqueTips.get(key);
      if (!existing) {
        uniqueTips.set(key, { tipDoc, data });
        return;
      }

      const curTime = parseTime(data.updatedAt);
      const prevTime = parseTime(existing.data.updatedAt);
      if (curTime > prevTime) {
        batch.delete(existing.tipDoc.ref);
        uniqueTips.set(key, { tipDoc, data });
      } else {
        batch.delete(tipDoc.ref);
      }
      leagueChangedCount += 1;
      deletedCount += 1;
    });

    for (const { tipDoc, data } of uniqueTips.values()) {
      if (data.matchId !== targetMatchId) {
        batch.update(tipDoc.ref, {
          matchId: targetMatchId,
          updatedAt: data.updatedAt ?? admin.firestore.FieldValue.serverTimestamp(),
        });
        leagueChangedCount += 1;
        updatedCount += 1;
      }
    }

    if (leagueChangedCount > 0) {
      await batch.commit();
    }
  }

  console.log(`Canonicalized tips for ${match.homeTeam} - ${match.awayTeam} to ${targetMatchId}: updated ${updatedCount}, deleted ${deletedCount}.`);
  return { updatedCount, deletedCount };
}

async function canonicalizeKickoffTips(liveCandidates, now) {
  for (const match of liveCandidates) {
    const kickoff = new Date(match.kickoff);
    const msSinceKickoff = now.getTime() - kickoff.getTime();
    if (msSinceKickoff < 30 * 1000) continue;

    const matchRef = db.collection("matches").doc(match.id);
    const matchSnap = await matchRef.get();
    const currentTargetMatchId = targetTipMatchId(match);
    if (matchSnap.exists && matchSnap.data().tipsCanonicalizedMatchId === currentTargetMatchId) continue;

    await canonicalizeTipsForMatch(match);
    await matchRef.set({
      tipsCanonicalizedAt: admin.firestore.FieldValue.serverTimestamp(),
      tipsCanonicalizedMatchId: currentTargetMatchId,
    }, { merge: true });
  }
}

async function isSyncDisabled() {
  const configSnap = await db.collection("settings").doc("sync_config").get();
  return configSnap.exists && configSnap.data().disabled === true;
}

async function syncFullResults({ includeTable = true, includeCleanup = false, forceRecalculate = false, reason = "scheduled" } = {}) {
  console.log(`Starting full syncResults job (${reason})...`);
  const groupMatches = await fetchOpenLigaMatches();

  const matchesSnap = await db.collection("matches").get();
  const existingMatchMap = new Map();
  matchesSnap.forEach((doc) => {
    const data = doc.data();
      existingMatchMap.set(doc.id, {
        homeScore: data.homeScore ?? null,
        awayScore: data.awayScore ?? null,
        status: data.status ?? "scheduled",
        winner: data.winner ?? null,
        resultNote: data.resultNote ?? null,
        source: data.source ?? "openligadb",
      });
  });

  const koMatches = getKnockoutMatches().map((m) => {
    const existing = existingMatchMap.get(m.id);
    if (existing) {
      return {
        ...m,
        homeScore: existing.homeScore,
        awayScore: existing.awayScore,
        status: existing.status,
        winner: existing.winner ?? null,
        resultNote: existing.resultNote ?? null,
      };
    }
    return {
      ...m,
      winner: null,
      resultNote: null,
    };
  });

  const allMatches = [...groupMatches, ...koMatches];

  let matchesChanged = false;
  let finalMatchesChanged = false;
  const effectiveAllMatches = [];

  const matchBatch = db.batch();
  for (const rawMatch of allMatches) {
    let match = rawMatch;
    const existing = existingMatchMap.get(match.id);
    if (existing?.status === "finalResult" && match.status !== "finalResult") {
      match = {
        ...match,
        status: existing.status,
        homeScore: existing.homeScore,
        awayScore: existing.awayScore,
        winner: existing.winner ?? match.winner ?? null,
        resultNote: existing.resultNote ?? match.resultNote ?? null,
        source: existing.source,
      };
    } else if (existing?.source === "football-data" && isLiveWindow(match) && match.status !== "finalResult") {
      match = {
        ...match,
        status: existing.status,
        homeScore: existing.homeScore,
        awayScore: existing.awayScore,
        source: existing.source,
      };
    }
    effectiveAllMatches.push(match);
    const changed = !existing ||
      existing.homeScore !== match.homeScore ||
      existing.awayScore !== match.awayScore ||
      existing.status !== match.status ||
      existing.winner !== match.winner ||
      existing.resultNote !== match.resultNote ||
      existing.source !== (match.source ?? "openligadb");

    if (changed) {
      matchesChanged = true;
      if (match.status === "finalResult" || (existing && existing.status !== "finalResult" && match.status === "finalResult")) {
        finalMatchesChanged = true;
      }

      const docRef = db.collection("matches").doc(match.id);
      matchBatch.set(docRef, {
        homeTeam: match.homeTeam,
        awayTeam: match.awayTeam,
        kickoff: admin.firestore.Timestamp.fromDate(new Date(match.kickoff)),
        stage: match.stage,
        group: match.group,
        status: match.status,
        homeScore: match.homeScore,
        awayScore: match.awayScore,
        winner: match.winner ?? null,
        resultNote: match.resultNote ?? null,
        source: match.source ?? "openligadb",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }

  if (matchesChanged) {
    await matchBatch.commit();
    console.log("Synced changed matches to Firestore.");
  } else {
    console.log("No matches changed. Skipping matches Firestore write.");
  }

  if (includeTable) {
    try {
      console.log("Fetching official table from OpenLigaDB...");
      const tableResponse = await fetch("https://api.openligadb.de/getbltable/wm2026/2026");
      if (tableResponse.ok) {
        const tableData = await tableResponse.json();
        const officialOrder = tableData.map((t) => t.teamName);

        const existingTableSnap = await db.collection("settings").doc("official_table").get();
        const existingTeams = existingTableSnap.exists ? existingTableSnap.data().teams : [];
        const tableChanged = JSON.stringify(existingTeams) !== JSON.stringify(officialOrder);

        if (tableChanged) {
          await db.collection("settings").doc("official_table").set({
            teams: officialOrder,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log("Synced official table to Firestore.");
        } else {
          console.log("Official table unchanged. Skipping write.");
        }
      } else {
        console.warn(`Failed to fetch official table: ${tableResponse.status}`);
      }
    } catch (err) {
      console.error("Failed to fetch/save official table:", err);
    }
  }

  if (includeCleanup) {
    await cleanupDuplicateTips(allMatches);
  }

  if (forceRecalculate || finalMatchesChanged) {
    const finalMatches = effectiveAllMatches.filter((m) => m.status === "finalResult");
    await recalculateScores(effectiveAllMatches, finalMatches);
  } else {
    console.log("No final matches changed. Skipping scores recalculation.");
  }
  console.log("Full syncResults job completed successfully.");
}

async function deleteQuerySnapshot(snapshot) {
  if (snapshot.empty) return 0;

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return snapshot.size;
}

async function deleteSubcollection(collectionRef) {
  let deletedCount = 0;
  while (true) {
    const snapshot = await collectionRef.limit(450).get();
    if (snapshot.empty) break;
    deletedCount += await deleteQuerySnapshot(snapshot);
  }
  return deletedCount;
}

async function deleteLeagueTree(leagueRef) {
  const [tipsDeleted, standingsDeleted, membersDeleted] = await Promise.all([
    deleteSubcollection(leagueRef.collection("tips")),
    deleteSubcollection(leagueRef.collection("standings")),
    deleteSubcollection(leagueRef.collection("members")),
  ]);
  await leagueRef.delete();
  console.log(`Deleted empty league ${leagueRef.id}: tips=${tipsDeleted}, standings=${standingsDeleted}, members=${membersDeleted}.`);
}

function hasNoActiveMembers(leagueData) {
  const memberIds = leagueData?.memberIds;
  return Array.isArray(memberIds) && memberIds.length === 0;
}

exports.deleteEmptyLeague = functions.region("europe-west3").firestore
  .document("leagues/{leagueId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;
    if (!hasNoActiveMembers(change.after.data())) return null;

    await deleteLeagueTree(change.after.ref);
    return null;
  });

exports.cleanupEmptyLeagues = functions.region("europe-west3").runWith({
  timeoutSeconds: 300,
  memory: "256MB",
}).pubsub.schedule("0 * * * *").onRun(async () => {
  const leaguesSnap = await db.collection("leagues").get();
  let deletedCount = 0;

  for (const leagueDoc of leaguesSnap.docs) {
    if (!hasNoActiveMembers(leagueDoc.data())) continue;
    await deleteLeagueTree(leagueDoc.ref);
    deletedCount += 1;
  }

  console.log(`cleanupEmptyLeagues deleted ${deletedCount} empty league(s).`);
  return null;
});

exports.syncLiveResults = functions.region("europe-west3").runWith({
  timeoutSeconds: 120,
  memory: "256MB",
  secrets: ["FOOTBALL_DATA_TOKEN"],
}).pubsub.schedule("* * * * *").onRun(async (context) => {
  try {
    if (await isSyncDisabled()) {
      console.log("Sync is disabled via settings/sync_config.");
      return null;
    }

    let openLigaMatches;
    try {
      openLigaMatches = await fetchOpenLigaMatches();
    } catch (error) {
      console.warn("OpenLigaDB live request failed. Falling back to Firestore matches.", error);
      openLigaMatches = await fetchFirestoreMatches();
    }
    const liveCandidates = openLigaMatches.filter((match) => isLiveWindow(match));
    if (liveCandidates.length === 0) {
      console.log("No live-window matches. Skipping fast live write.");
      return null;
    }

    const now = new Date();
    await canonicalizeKickoffTips(liveCandidates, now);

    const footballData = await fetchFootballDataMatches();
    logLiveProviderComparison(openLigaMatches, footballData.matches, footballData.headers);
    const overlayMatches = mergeFootballDataOverlay(openLigaMatches, footballData.matches, { liveOnly: true })
      .filter((match) => isLiveWindow(match) || match.source === "football-data");

    let changedCount = 0;
    let finalTransition = false;
    const batch = db.batch();
    for (const match of overlayMatches) {
      const docRef = db.collection("matches").doc(match.id);
      const existingDoc = await docRef.get();
      const existing = existingDoc.data() ?? {};
      const changed = !existingDoc.exists ||
        (existing.homeScore ?? null) !== match.homeScore ||
        (existing.awayScore ?? null) !== match.awayScore ||
        (existing.status ?? "scheduled") !== match.status ||
        (existing.source ?? "openligadb") !== (match.source ?? "openligadb");
      if (!changed) continue;

      if ((existing.status ?? "scheduled") !== "finalResult" && match.status === "finalResult") {
        finalTransition = true;
      }
      changedCount += 1;
      batch.set(docRef, {
        homeTeam: match.homeTeam,
        awayTeam: match.awayTeam,
        kickoff: admin.firestore.Timestamp.fromDate(new Date(match.kickoff)),
        stage: match.stage,
        group: match.group,
        status: match.status,
        homeScore: match.homeScore,
        awayScore: match.awayScore,
        winner: match.status === "finalResult" ? match.winner ?? null : null,
        resultNote: match.resultNote ?? null,
        source: match.source ?? "openligadb",
        providerStatus: match.providerStatus ?? null,
        providerUpdatedAt: match.providerUpdatedAt ?? null,
        minute: match.minute ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    if (changedCount > 0) {
      await batch.commit();
      console.log(`Fast live sync wrote ${changedCount} changed match document(s).`);
    } else {
      console.log("Fast live sync found no Firestore changes.");
    }

    if (finalTransition) {
      try {
        await syncFullResults({ includeTable: true, includeCleanup: false, forceRecalculate: true, reason: "live-final-transition" });
      } catch (error) {
        console.warn("Skipping immediate full recalculation after live final transition.", error);
      }
    }
    return null;
  } catch (error) {
    console.error("syncLiveResults job failed with error:", error);
    return null;
  }
});

exports.syncResults = functions.region("europe-west3").runWith({
  timeoutSeconds: 300,
  memory: "256MB",
}).pubsub.schedule("0 * * * *").onRun(async (context) => {
  try {
    if (await isSyncDisabled()) {
      console.log("Sync is disabled via settings/sync_config.");
      return null;
    }
    const now = new Date();
    await syncFullResults({
      includeTable: true,
      includeCleanup: now.getUTCHours() === 0,
      forceRecalculate: false,
      reason: "hourly",
    });
    return null;
  } catch (error) {
    console.error("syncResults job failed with error:", error);
    return null;
  }
});
