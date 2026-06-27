const functions = require("firebase-functions");
const admin = require("firebase-admin");
const THIRD_PLACE_MATRIX = require("./third-place-matrix");

admin.initializeApp();
const db = admin.firestore();

const OPENLIGADB_URL = 'https://api.openligadb.de/getmatchdata/wm2026/2026';
const FOOTBALL_DATA_WC_MATCHES_URL = 'https://api.football-data.org/v4/competitions/WC/matches?season=2026';
const FOOTBALL_DATA_WC_STANDINGS_URL = 'https://api.football-data.org/v4/competitions/WC/standings?season=2026';

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
  cotedivoire: 'elfenbeinkuste',
  ivorycoast: 'elfenbeinkuste',
  ecuador: 'ecuador',
  sweden: 'schweden',
  tunisia: 'tunesien',
  spain: 'spanien',
  capeverde: 'kapverde',
  capeverdeislands: 'kapverde',
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
  korearepublic: 'sudkorea',
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

function isSameTeam(a, b) {
  return teamKey(a) === teamKey(b);
}

function displayTeamName(value) {
  const key = teamKey(value);
  const fixture = FIXTURES_LIST.find(([, home, away]) => teamKey(home) === key || teamKey(away) === key);
  if (!fixture) return String(value || "");
  return teamKey(fixture[1]) === key ? fixture[1] : fixture[2];
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

const STATUS_RANK = { scheduled: 1, live: 2, finalResult: 3 };

function statusRank(status) {
  return STATUS_RANK[status] ?? 0;
}

function timestampMillis(value) {
  if (!value) return 0;
  if (value.toDate) return value.toDate().getTime();
  const time = new Date(value).getTime();
  return Number.isFinite(time) ? time : 0;
}

function hasConflictingFinalScore(first, second) {
  return first?.status === "finalResult" &&
    second?.status === "finalResult" &&
    first.homeScore != null && first.awayScore != null &&
    second.homeScore != null && second.awayScore != null &&
    (first.homeScore !== second.homeScore || first.awayScore !== second.awayScore);
}

function shouldKeepExistingMatch(existing, nextMatch) {
  if (!existing) return false;

  const existingStatus = existing.status ?? "scheduled";
  const nextStatus = nextMatch.status ?? "scheduled";
  const existingSource = existing.source ?? "openligadb";
  const nextSource = nextMatch.source ?? "openligadb";

  if (existingSource === "football-data" &&
      nextSource === "openligadb" &&
      hasConflictingFinalScore(existing, nextMatch)) {
    return false;
  }

  if (statusRank(nextStatus) < statusRank(existingStatus)) return true;
  if (nextStatus === "finalResult" && existingStatus !== "finalResult") return false;
  if (existingSource === "football-data" &&
      nextSource !== "football-data" &&
      existingStatus !== "scheduled") {
    return true;
  }

  if (existingSource === "football-data" && nextSource === "football-data") {
    const existingProviderUpdatedAt = timestampMillis(existing.providerUpdatedAt);
    const nextProviderUpdatedAt = timestampMillis(nextMatch.providerUpdatedAt);
    if (existingProviderUpdatedAt > 0 &&
        nextProviderUpdatedAt > 0 &&
        nextProviderUpdatedAt < existingProviderUpdatedAt) {
      return true;
    }
  }

  return false;
}

function isLiveWindow(match, now = new Date()) {
  const kickoff = new Date(match.kickoff);
  const startsSoon = kickoff.getTime() - now.getTime() <= 60 * 60 * 1000;
  const notTooOld = now.getTime() - kickoff.getTime() <= 4 * 60 * 60 * 1000;
  return startsSoon && notTooOld && match.status !== "finalResult";
}

function isRecentMatchWindow(match, now = new Date()) {
  const kickoff = new Date(match.kickoff);
  const startsSoon = kickoff.getTime() - now.getTime() <= 60 * 60 * 1000;
  const notTooOld = now.getTime() - kickoff.getTime() <= 4 * 60 * 60 * 1000;
  return startsSoon && notTooOld;
}

function normalizeFootballDataMatch(match) {
  const homeTeam = match.homeTeam?.name ? displayTeamName(match.homeTeam.name) : null;
  const awayTeam = match.awayTeam?.name ? displayTeamName(match.awayTeam.name) : null;
  const kickoff = match.utcDate;
  const knockoutStage = {
    LAST_32: "Sechzehntelfinale",
    LAST_16: "Achtelfinale",
    QUARTER_FINALS: "Viertelfinale",
    SEMI_FINALS: "Halbfinale",
    THIRD_PLACE: "Spiel um Platz 3",
    FINAL: "Finale",
  }[match.stage] ?? null;
  if ((!homeTeam || !awayTeam) && !knockoutStage) return null;
  if (!kickoff) return null;

  const kickoffDate = new Date(kickoff);
  const now = new Date();
  let status = "scheduled";
  if (["IN_PLAY", "PAUSED", "EXTRA_TIME", "PENALTY_SHOOTOUT"].includes(match.status)) {
    status = "live";
  } else if (["FINISHED", "AWARDED"].includes(match.status)) {
    status = "finalResult";
  } else if (now > kickoffDate) {
    status = "live";
  }

  const fullTime = match.score?.fullTime ?? {};
  const halfTime = match.score?.halfTime ?? {};
  const winner = match.score?.winner === "HOME_TEAM"
    ? homeTeam
    : match.score?.winner === "AWAY_TEAM"
      ? awayTeam
      : null;
  const resultNote = match.score?.duration && match.score.duration !== "REGULAR"
    ? match.score.duration
    : null;
  return {
    providerId: String(match.id),
    homeTeam: homeTeam ?? null,
    awayTeam: awayTeam ?? null,
    kickoff,
    stage: knockoutStage,
    status,
    rawStatus: match.status,
    minute: match.minute ?? null,
    homeScore: fullTime.home ?? null,
    awayScore: fullTime.away ?? null,
    halfHomeScore: halfTime.home ?? null,
    halfAwayScore: halfTime.away ?? null,
    winner,
    resultNote,
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
    console.warn("FOOTBALL_DATA_TOKEN secret is not configured. Skipping football-data.org match overlay.");
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

async function fetchFootballDataStandings() {
  const token = process.env.FOOTBALL_DATA_TOKEN;
  if (!token) {
    console.warn("FOOTBALL_DATA_TOKEN secret is not configured. Skipping football-data.org standings.");
    return { groups: {}, teams: [], headers: {}, status: 0 };
  }

  let response;
  try {
    response = await fetch(FOOTBALL_DATA_WC_STANDINGS_URL, {
      headers: { "X-Auth-Token": token },
    });
  } catch (error) {
    console.warn("football-data.org standings request failed before receiving a response.", error);
    return { groups: {}, teams: [], headers: {}, status: 0 };
  }

  const headers = {
    apiVersion: response.headers.get("x-api-version"),
    authenticatedClient: response.headers.get("x-authenticated-client"),
    requestCounterReset: response.headers.get("x-requestcounter-reset"),
    requestsAvailable: response.headers.get("x-requestsavailable"),
  };

  if (response.status === 429) {
    console.warn("football-data.org standings rate limit reached.", headers);
    return { groups: {}, teams: [], headers, status: response.status };
  }
  if (!response.ok) {
    console.warn(`football-data.org standings request failed with ${response.status}.`, headers);
    return { groups: {}, teams: [], headers, status: response.status };
  }

  const data = await response.json();
  const groups = {};
  const teams = [];
  for (const standing of data.standings ?? []) {
    if (standing.type && standing.type !== "TOTAL") continue;
    const group = groupKey(standing.group);
    const rows = [];
    for (const row of standing.table ?? []) {
      const team = displayTeamName(row.team?.name);
      if (!team) continue;
      rows.push({
        position: Number(row.position ?? 0),
        team,
        played: Number(row.playedGames ?? 0),
        won: Number(row.won ?? 0),
        drawn: Number(row.draw ?? 0),
        lost: Number(row.lost ?? 0),
        goalsFor: Number(row.goalsFor ?? 0),
        goalsAgainst: Number(row.goalsAgainst ?? 0),
        goalDifference: Number(row.goalDifference ?? 0),
        points: Number(row.points ?? 0),
      });
      teams.push(team);
    }
    if (group && rows.length > 0) {
      rows.sort((a, b) => a.position - b.position);
      groups[group] = rows;
    }
  }

  return { groups, teams, headers, status: response.status };
}

async function syncOfficialTable({ allowOpenLigaFallback = true } = {}) {
  let tableSource = "none";
  let tableStatus = 0;
  let tableChanged = false;

  try {
    console.log("Fetching official group standings from football-data.org...");
    const standings = await fetchFootballDataStandings();
    tableStatus = standings.status;
    if (standings.teams.length > 0) {
      tableSource = "football-data";

      const existingTableSnap = await db.collection("settings").doc("official_table").get();
      const existingData = existingTableSnap.exists ? existingTableSnap.data() : {};
      tableChanged =
        JSON.stringify(existingData.teams ?? []) !== JSON.stringify(standings.teams) ||
        JSON.stringify(existingData.groups ?? {}) !== JSON.stringify(standings.groups);

      if (tableChanged) {
        await db.collection("settings").doc("official_table").set({
          teams: standings.teams,
          groups: standings.groups,
          source: tableSource,
          providerStatus: standings.status,
          providerHeaders: standings.headers,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log("Synced football-data.org official table order to Firestore.");
      } else {
        console.log("Official table order unchanged. Skipping write.");
      }
      return { tableSource, tableStatus, tableChanged };
    }

    if (!allowOpenLigaFallback) {
      console.log("No football-data.org group standings available. Keeping existing official table.");
      return { tableSource, tableStatus, tableChanged };
    }

    console.log("Fetching official table from OpenLigaDB as fallback...");
    const tableResponse = await fetch("https://api.openligadb.de/getbltable/wm2026/2026");
    tableStatus = tableResponse.status;
    if (tableResponse.ok) {
      tableSource = "openligadb";
      const tableData = await tableResponse.json();
      const officialOrder = tableData.map((t) => displayTeamName(t.teamName));

      const existingTableSnap = await db.collection("settings").doc("official_table").get();
      const existingData = existingTableSnap.exists ? existingTableSnap.data() : {};
      tableChanged =
        JSON.stringify(existingData.teams ?? []) !== JSON.stringify(officialOrder) ||
        Object.keys(existingData.groups ?? {}).length > 0;

      if (tableChanged) {
        await db.collection("settings").doc("official_table").set({
          teams: officialOrder,
          groups: {},
          source: tableSource,
          providerStatus: tableResponse.status,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log("Synced OpenLigaDB official table fallback to Firestore.");
      } else {
        console.log("Official table fallback unchanged. Skipping write.");
      }
    } else {
      console.warn(`Failed to fetch official table fallback: ${tableResponse.status}`);
    }
  } catch (err) {
    console.error("Failed to fetch/save official table:", err);
  }

  return { tableSource, tableStatus, tableChanged };
}

function applyFootballDataOverlay(openLigaMatch, footballDataMatch) {
  if (!footballDataMatch) return openLigaMatch;
  if (footballDataMatch.status !== "scheduled" &&
      (footballDataMatch.homeScore === null || footballDataMatch.awayScore === null)) {
    return openLigaMatch;
  }

  const conflictingFinalResult = hasConflictingFinalScore(openLigaMatch, footballDataMatch);
  if (conflictingFinalResult) {
    console.warn("Final provider result conflict; keeping OpenLigaDB result.", JSON.stringify({
      match: `${openLigaMatch.homeTeam} - ${openLigaMatch.awayTeam}`,
      openLiga: `${openLigaMatch.homeScore}:${openLigaMatch.awayScore}`,
      footballData: `${footballDataMatch.homeScore}:${footballDataMatch.awayScore}`,
      footballDataUpdatedAt: footballDataMatch.lastUpdated,
    }));
    return openLigaMatch;
  }

  return {
    ...openLigaMatch,
    status: footballDataMatch.status,
    homeScore: footballDataMatch.homeScore,
    awayScore: footballDataMatch.awayScore,
    winner: footballDataMatch.status === "finalResult" ? footballDataMatch.winner : null,
    resultNote: footballDataMatch.resultNote,
    source: "football-data",
    providerStatus: footballDataMatch.rawStatus,
    providerUpdatedAt: footballDataMatch.lastUpdated,
    minute: footballDataMatch.minute,
  };
}

function mergeFootballDataOverlay(openLigaMatches, footballDataMatches, { liveOnly = false } = {}) {
  const footballByMatch = new Map(footballDataMatches
    .filter((m) => m.homeTeam && m.awayTeam)
    .map((m) => [matchKey(m.homeTeam, m.awayTeam), m]));
  const now = new Date();
  return openLigaMatches.map((match) => {
    if (liveOnly && !isRecentMatchWindow(match, now)) return match;
    return applyFootballDataOverlay(match, footballByMatch.get(matchKey(match.homeTeam, match.awayTeam)));
  });
}

function logLiveProviderComparison(openLigaMatches, footballDataMatches, footballHeaders) {
  const footballByMatch = new Map(footballDataMatches.map((m) => [matchKey(m.homeTeam, m.awayTeam), m]));
  const now = new Date();
  const relevant = openLigaMatches.filter((match) => isRecentMatchWindow(match, now));
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
  if (favorites.some((t) => isSameTeam(t, team))) return "Absolute Titelfavoriten";
  if (tops.some((t) => isSameTeam(t, team))) return "Top Team";
  if (mids.some((t) => isSameTeam(t, team))) return "Durchschnittliches Team";
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
  const teamMatches = allMatches.filter((m) => isSameTeam(m.homeTeam, team) || isSameTeam(m.awayTeam, team));
  if (teamMatches.length === 0) return null;

  const knockouts = teamMatches.filter((m) => !m.stage.startsWith("Gruppe") && !m.stage.includes("Runde"));

  for (const m of knockouts) {
    if (m.status === "finalResult") {
      const winner = getMatchWinner(m);
      if (winner && !isSameTeam(winner, team)) {
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
      isSameTeam(getMatchWinner(m), team)
  );
  if (hasWonFinal) return "Champion";

  const groupMatches = allMatches.filter((m) => m.stage.startsWith("Gruppe") || m.stage.includes("Runde"));
  const allGroupsFinished = groupMatches.length > 0 && groupMatches.every((m) => m.status === "finalResult");
  if (allGroupsFinished && knockouts.length === 0) {
    return "Gruppenphase";
  }

  return null;
}

function getDeepestReachedStage(team, allMatches) {
  let deepest = null;
  for (const match of allMatches) {
    if (match.stage.startsWith("Gruppe") || match.stage.includes("Runde")) continue;
    if (!isSameTeam(match.homeTeam, team) && !isSameTeam(match.awayTeam, team)) continue;

    const stage = match.stage.toLowerCase();
    let reached = null;
    if (stage.includes("sechzehntel") || stage.includes("32")) reached = "Sechzehntelfinale";
    else if (stage.includes("achtel") || stage.includes("16")) reached = "Achtelfinale";
    else if (stage.includes("viertel") || stage.includes("quarter")) reached = "Viertelfinale";
    else if (stage.includes("halb") || stage.includes("semi")) reached = "Halbfinale";
    else if (stage.includes("final")) reached = "Finale";

    if (reached && (deepest === null || stageRank(reached) > stageRank(deepest))) {
      deepest = reached;
    }
    if (reached && match.status === "finalResult" && isSameTeam(getMatchWinner(match), team)) {
      const nextStage = {
        Sechzehntelfinale: "Achtelfinale",
        Achtelfinale: "Viertelfinale",
        Viertelfinale: "Halbfinale",
        Halbfinale: "Finale",
      }[reached];
      if (nextStage && (deepest === null || stageRank(nextStage) > stageRank(deepest))) {
        deepest = nextStage;
      }
    }
  }
  return deepest;
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
        if (isSameTeam(getMatchWinner(match), fav)) {
          extraPoints += 10;
        }
      }
    }
  }

  const championTipp = userData.predictedChampion;
  if (championTipp) {
    for (const match of allMatches) {
      if (match.status === "finalResult") {
        if (isSameTeam(getMatchWinner(match), championTipp)) {
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
    } else {
      const reachedStage = getDeepestReachedStage(rTeam, allMatches);
      if (reachedStage && stageRank(reachedStage) > stageRank(rStage)) {
        // Reaching a later round already proves an earlier elimination pick wrong.
        // Positive risk points still wait until the actual elimination is final.
        extraPoints += calculateRiskPoints(rTeam, rStage, reachedStage);
      }
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

function isPlaceholderTeam(name) {
  const lower = String(name ?? "").toLowerCase();
  return lower.startsWith("sieger") ||
    lower.startsWith("zweiter") ||
    lower.startsWith("dritter") ||
    lower.startsWith("bester") ||
    lower.startsWith("verlierer") ||
    lower.includes("gruppe");
}

function preserveResolvedParticipants(template, existing) {
  if (!existing) return template;
  return {
    ...template,
    homeTeam: isPlaceholderTeam(template.homeTeam) && !isPlaceholderTeam(existing.homeTeam)
      ? existing.homeTeam
      : template.homeTeam,
    awayTeam: isPlaceholderTeam(template.awayTeam) && !isPlaceholderTeam(existing.awayTeam)
      ? existing.awayTeam
      : template.awayTeam,
  };
}

function mergeProviderKnockoutMatches(providerMatches, templates, existingMatchMap = new Map()) {
  const stageOrder = [
    "Sechzehntelfinale",
    "Achtelfinale",
    "Viertelfinale",
    "Halbfinale",
    "Spiel um Platz 3",
    "Finale",
  ];
  const merged = [];

  for (const stage of stageOrder) {
    const stageTemplates = templates.filter((match) => match.stage === stage)
      .sort((a, b) => new Date(a.kickoff) - new Date(b.kickoff));
    const stageProviders = providerMatches.filter((match) => match.stage === stage)
      .sort((a, b) => new Date(a.kickoff) - new Date(b.kickoff));

    for (let index = 0; index < stageTemplates.length; index++) {
      const template = stageTemplates[index];
      const existing = existingMatchMap.get(template.id);
      const preserved = preserveResolvedParticipants(template, existing);
      const provider = stageProviders[index];
      if (!provider) {
        merged.push(preserved);
        continue;
      }
      merged.push({
        ...preserved,
        ...provider,
        id: template.id,
        homeTeam: provider.homeTeam ?? preserved.homeTeam,
        awayTeam: provider.awayTeam ?? preserved.awayTeam,
        stage,
        group: "",
        source: "football-data",
        providerStatus: provider.rawStatus,
        providerUpdatedAt: provider.lastUpdated,
      });
    }
  }
  return merged;
}

function calculateCompletedGroupTables(groupMatches) {
  const tables = {};
  for (const match of groupMatches) {
    if (!match.group || match.status !== "finalResult" ||
        match.homeScore == null || match.awayScore == null) continue;
    const table = (tables[match.group] ??= {});
    const home = (table[teamKey(match.homeTeam)] ??= {
      team: displayTeamName(match.homeTeam), points: 0, goalsFor: 0, goalsAgainst: 0,
    });
    const away = (table[teamKey(match.awayTeam)] ??= {
      team: displayTeamName(match.awayTeam), points: 0, goalsFor: 0, goalsAgainst: 0,
    });
    home.goalsFor += match.homeScore;
    home.goalsAgainst += match.awayScore;
    away.goalsFor += match.awayScore;
    away.goalsAgainst += match.homeScore;
    if (match.homeScore > match.awayScore) home.points += 3;
    else if (match.awayScore > match.homeScore) away.points += 3;
    else {
      home.points += 1;
      away.points += 1;
    }
  }

  const completed = {};
  for (const [group, table] of Object.entries(tables)) {
    const matches = groupMatches.filter((match) => match.group === group);
    if (matches.length !== 6 || !matches.every((match) => match.status === "finalResult")) continue;
    completed[group] = Object.values(table).sort((a, b) =>
      b.points - a.points ||
      (b.goalsFor - b.goalsAgainst) - (a.goalsFor - a.goalsAgainst) ||
      b.goalsFor - a.goalsFor ||
      a.team.localeCompare(b.team));
  }
  return completed;
}

function resolveDirectGroupSlots(matches, groupMatches) {
  const hasDirectSlots = matches.some((match) =>
    /^(Sieger|Zweiter) Gruppe [A-L]$/.test(match.homeTeam) ||
    /^(Sieger|Zweiter) Gruppe [A-L]$/.test(match.awayTeam));
  if (!hasDirectSlots) return matches;

  const tables = calculateCompletedGroupTables(groupMatches);
  const resolve = (slot) => {
    const parsed = /^(Sieger|Zweiter) Gruppe ([A-L])$/.exec(slot);
    if (!parsed) return slot;
    const [, rank, group] = parsed;
    return tables[group]?.[rank === "Sieger" ? 0 : 1]?.team ?? slot;
  };
  for (const match of matches) {
    match.homeTeam = resolve(match.homeTeam);
    match.awayTeam = resolve(match.awayTeam);
  }
  return matches;
}

function getThirdPlaceAssignments(completedTables) {
  if (Object.keys(completedTables).length !== 12) return null;
  const thirds = Object.entries(completedTables).map(([group, rows]) => ({
    group,
    ...rows[2],
  })).sort((a, b) =>
    b.points - a.points ||
    (b.goalsFor - b.goalsAgainst) - (a.goalsFor - a.goalsAgainst) ||
    b.goalsFor - a.goalsFor ||
    a.team.localeCompare(b.team));

  const eighth = thirds[7];
  const ninth = thirds[8];
  if (!eighth || !ninth) return null;
  if (eighth.points === ninth.points &&
      eighth.goalsFor - eighth.goalsAgainst === ninth.goalsFor - ninth.goalsAgainst &&
      eighth.goalsFor === ninth.goalsFor) {
    // Wait for official fair-play/ranking data instead of guessing a tied cutoff.
    return null;
  }

  const qualifying = thirds.slice(0, 8);
  const combination = qualifying.map((row) => row.group).sort().join("");
  const allocation = THIRD_PLACE_MATRIX[combination];
  if (!allocation) return null;

  const winnerGroups = ["A", "B", "D", "E", "G", "I", "K", "L"];
  const thirdByGroup = new Map(qualifying.map((row) => [row.group, row.team]));
  return Object.fromEntries(winnerGroups.map((winnerGroup, index) => [
    winnerGroup,
    thirdByGroup.get(allocation[index]),
  ]));
}

function resolveThirdPlaceSlots(matches, groupMatches) {
  const assignments = getThirdPlaceAssignments(calculateCompletedGroupTables(groupMatches));
  if (!assignments) return matches;
  const winnerGroupByMatchId = {
    "wc-ko-sf-3": "E",
    "wc-ko-sf-6": "I",
    "wc-ko-sf-7": "A",
    "wc-ko-sf-8": "L",
    "wc-ko-sf-9": "G",
    "wc-ko-sf-10": "D",
    "wc-ko-sf-13": "B",
    "wc-ko-sf-16": "K",
  };
  for (const match of matches) {
    const winnerGroup = winnerGroupByMatchId[match.id];
    if (!winnerGroup || !match.awayTeam.startsWith("Bester 3.")) continue;
    match.awayTeam = assignments[winnerGroup] ?? match.awayTeam;
  }
  return matches;
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
  const audit = {
    leagueCount: 0,
    activeMembers: 0,
    finalMatches: finalMatches.length,
    scoredTips: 0,
    duplicateTipsDeleted: 0,
    orphanTipsDeleted: 0,
    standingsWritten: 0,
    standingsDeleted: 0,
    issues: [],
  };
  if (finalMatches.length === 0) return audit;
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
    audit.leagueCount += 1;
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
        audit.duplicateTipsDeleted += 1;
      }
    });

    // Score tips
    for (const { tipDoc, data, match } of userMatchTips.values()) {
      const uid = data.uid;
      const current = stats.get(uid);
      if (!current) {
        batch.delete(tipDoc.ref);
        audit.orphanTipsDeleted += 1;
        continue;
      }

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

      if (data.points !== score.points) {
        batch.update(tipDoc.ref, { points: score.points });
      }
      audit.scoredTips += 1;

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
    audit.activeMembers += activeStats.length;
    const ranked = rankStandings(activeStats);

    // Delete standings for members who have left the league
    for (const standing of stats.values()) {
      if (standing.leftAt !== null) {
        const standingRef = db.collection("leagues").doc(leagueId).collection("standings").doc(standing.uid);
        batch.delete(standingRef);
        audit.standingsDeleted += 1;
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
      audit.standingsWritten += 1;
    }

    await batch.commit();
  }
  console.log("Score recalculation audit", JSON.stringify(audit));
  return audit;
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

async function writeSyncStatus(kind, data) {
  try {
    await db.collection("settings").doc("sync_status").set({
      [kind]: {
        ...data,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (error) {
    console.warn(`Failed to write sync status for ${kind}.`, error);
  }
}

async function syncFullResults({ includeTable = true, includeCleanup = false, forceRecalculate = false, reason = "scheduled" } = {}) {
  console.log(`Starting full syncResults job (${reason})...`);
  const openLigaMatches = await fetchOpenLigaMatches();
  const footballData = await fetchFootballDataMatches();
  const providerMatches = mergeFootballDataOverlay(openLigaMatches, footballData.matches);
  const groupMatches = providerMatches.filter((match) => match.group);

  let tableSource = "none";
  let tableStatus = 0;
  if (includeTable) {
    const tableResult = await syncOfficialTable({ allowOpenLigaFallback: true });
    tableSource = tableResult.tableSource;
    tableStatus = tableResult.tableStatus;
  }

  const matchesSnap = await db.collection("matches").get();
  const existingMatchMap = new Map();
  matchesSnap.forEach((doc) => {
    const data = doc.data();
    existingMatchMap.set(doc.id, {
      homeTeam: data.homeTeam ?? null,
      awayTeam: data.awayTeam ?? null,
      homeScore: data.homeScore ?? null,
      awayScore: data.awayScore ?? null,
      status: data.status ?? "scheduled",
      winner: data.winner ?? null,
      resultNote: data.resultNote ?? null,
      source: data.source ?? "openligadb",
      providerStatus: data.providerStatus ?? null,
      providerUpdatedAt: data.providerUpdatedAt ?? null,
      minute: data.minute ?? null,
    });
  });

  const koTemplates = getKnockoutMatches().map((m) => {
    const existing = existingMatchMap.get(m.id);
    const resolvedTemplate = preserveResolvedParticipants(m, existing);
    if (existing) {
      return {
        ...resolvedTemplate,
        homeScore: existing.homeScore,
        awayScore: existing.awayScore,
        status: existing.status,
        winner: existing.winner ?? null,
        resultNote: existing.resultNote ?? null,
      };
    }
    return {
      ...resolvedTemplate,
      winner: null,
      resultNote: null,
    };
  });
  const providerKnockouts = footballData.matches.filter((match) => match.stage);
  const koMatches = mergeProviderKnockoutMatches(providerKnockouts, koTemplates, existingMatchMap);
  resolveDirectGroupSlots(koMatches, groupMatches);
  resolveThirdPlaceSlots(koMatches, groupMatches);

  const allMatches = [...groupMatches, ...koMatches];

  let matchesChanged = false;
  let finalMatchesChanged = false;
  let progressionChanged = false;
  const effectiveAllMatches = [];

  const matchBatch = db.batch();
  for (const rawMatch of allMatches) {
    let match = rawMatch;
    const existing = existingMatchMap.get(match.id);
    if (shouldKeepExistingMatch(existing, match)) {
      match = {
        ...match,
        status: existing.status,
        homeScore: existing.homeScore,
        awayScore: existing.awayScore,
        winner: existing.winner ?? match.winner ?? null,
        resultNote: existing.resultNote ?? match.resultNote ?? null,
        source: existing.source,
        providerStatus: existing.providerStatus ?? match.providerStatus ?? null,
        providerUpdatedAt: existing.providerUpdatedAt ?? match.providerUpdatedAt ?? null,
        minute: existing.minute ?? match.minute ?? null,
      };
    }
    effectiveAllMatches.push(match);
    const changed = !existing ||
      existing.homeTeam !== match.homeTeam ||
      existing.awayTeam !== match.awayTeam ||
      existing.homeScore !== match.homeScore ||
      existing.awayScore !== match.awayScore ||
      existing.status !== match.status ||
      existing.winner !== match.winner ||
      existing.resultNote !== match.resultNote ||
      existing.source !== (match.source ?? "openligadb") ||
      existing.providerStatus !== (match.providerStatus ?? null) ||
      existing.providerUpdatedAt !== (match.providerUpdatedAt ?? null) ||
      existing.minute !== (match.minute ?? null);

    if (changed) {
      matchesChanged = true;
      if (existing && (existing.homeTeam !== match.homeTeam || existing.awayTeam !== match.awayTeam)) {
        progressionChanged = true;
      }
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
        providerStatus: match.providerStatus ?? null,
        providerUpdatedAt: match.providerUpdatedAt ?? null,
        minute: match.minute ?? null,
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

  if (includeCleanup) {
    await cleanupDuplicateTips(allMatches);
  }

  if (forceRecalculate || finalMatchesChanged || progressionChanged) {
    const finalMatches = effectiveAllMatches.filter((m) => m.status === "finalResult");
    const audit = await recalculateScores(effectiveAllMatches, finalMatches);
    await writeSyncStatus("scoreAudit", {
      reason,
      ...audit,
      ok: (audit?.issues ?? []).length === 0,
    });
  } else {
    console.log("No final matches changed. Skipping scores recalculation.");
  }
  await writeSyncStatus("full", {
    reason,
    ok: true,
    matchesChanged,
    finalMatchesChanged,
    progressionChanged,
    groupMatches: groupMatches.length,
    totalMatches: effectiveAllMatches.length,
    footballDataStatus: footballData.status,
    footballDataMatches: footballData.matches.length,
    footballDataHeaders: footballData.headers,
    tableSource,
    tableStatus,
  });
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

if (process.env.NODE_ENV === "test") {
  exports.__test = {
    calculateExtraPoints,
    getEliminationStage,
    getDeepestReachedStage,
    getTier,
    isSameTeam,
    teamKey,
    applyFootballDataOverlay,
    isRecentMatchWindow,
    shouldKeepExistingMatch,
    preserveResolvedParticipants,
    mergeProviderKnockoutMatches,
    calculateCompletedGroupTables,
    resolveDirectGroupSlots,
    getThirdPlaceAssignments,
    resolveThirdPlaceSlots,
  };
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
      await writeSyncStatus("live", {
        ok: true,
        disabled: true,
      });
      return null;
    }

    let openLigaMatches;
    try {
      openLigaMatches = await fetchOpenLigaMatches();
    } catch (error) {
      console.warn("OpenLigaDB live request failed. Falling back to Firestore matches.", error);
      openLigaMatches = await fetchFirestoreMatches();
    }
    const liveCandidates = openLigaMatches.filter((match) => isRecentMatchWindow(match));
    const footballData = await fetchFootballDataMatches();
    logLiveProviderComparison(openLigaMatches, footballData.matches, footballData.headers);
    const groupOverlayMatches = mergeFootballDataOverlay(openLigaMatches, footballData.matches, { liveOnly: true })
      .filter((match) => match.group);
    const knockoutOverlayMatches = mergeProviderKnockoutMatches(
      footballData.matches.filter((match) => match.stage),
      getKnockoutMatches()
    );
    const overlayMatches = [...groupOverlayMatches, ...knockoutOverlayMatches]
      .filter((match) => isRecentMatchWindow(match));

    if (overlayMatches.length === 0) {
      console.log("No live-window matches. Skipping fast live write.");
      await writeSyncStatus("live", {
        ok: true,
        changedCount: 0,
        finalTransition: false,
        skippedStaleCount: 0,
        liveCandidates: liveCandidates.length,
        overlayMatches: 0,
      });
      return null;
    }

    const now = new Date();
    await canonicalizeKickoffTips(overlayMatches, now);

    let changedCount = 0;
    let finalTransition = false;
    let finalResultChanged = false;
    let skippedStaleCount = 0;
    let tableSource = "none";
    let tableStatus = 0;
    let tableChanged = false;
    const batch = db.batch();
    for (const match of overlayMatches) {
      const docRef = db.collection("matches").doc(match.id);
      const existingDoc = await docRef.get();
      const existing = existingDoc.data() ?? {};
      const existingStatus = existing.status ?? "scheduled";
      const existingSource = existing.source ?? "openligadb";
      const matchSource = match.source ?? "openligadb";
      if (shouldKeepExistingMatch(existingDoc.exists ? existing : null, match)) {
        skippedStaleCount += 1;
        continue;
      }
      const changed = !existingDoc.exists ||
        (existing.homeScore ?? null) !== match.homeScore ||
        (existing.awayScore ?? null) !== match.awayScore ||
        existingStatus !== match.status ||
        existingSource !== matchSource;
      if (!changed) continue;

      if (existingStatus !== "finalResult" && match.status === "finalResult") {
        finalTransition = true;
      }
      if (match.status === "finalResult" &&
          (existingStatus !== "finalResult" ||
            (existing.homeScore ?? null) !== match.homeScore ||
            (existing.awayScore ?? null) !== match.awayScore)) {
        finalResultChanged = true;
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
      const tableResult = await syncOfficialTable({ allowOpenLigaFallback: false });
      tableSource = tableResult.tableSource;
      tableStatus = tableResult.tableStatus;
      tableChanged = tableResult.tableChanged;
    } else {
      console.log("Fast live sync found no Firestore changes.");
    }

    await writeSyncStatus("live", {
      ok: true,
      changedCount,
      finalTransition,
      finalResultChanged,
      skippedStaleCount,
      liveCandidates: liveCandidates.length,
      overlayMatches: overlayMatches.length,
      footballDataStatus: footballData.status,
      footballDataMatches: footballData.matches.length,
      footballDataHeaders: footballData.headers,
      tableSource,
      tableStatus,
      tableChanged,
    });

    if (finalResultChanged) {
      try {
        await syncFullResults({ includeTable: true, includeCleanup: false, forceRecalculate: true, reason: "live-final-result-change" });
      } catch (error) {
        console.warn("Skipping immediate full recalculation after final result change.", error);
      }
    }
    return null;
  } catch (error) {
    console.error("syncLiveResults job failed with error:", error);
    await writeSyncStatus("live", {
      ok: false,
      error: String(error?.message ?? error),
    });
    return null;
  }
});

exports.syncResults = functions.region("europe-west3").runWith({
  timeoutSeconds: 300,
  memory: "256MB",
  secrets: ["FOOTBALL_DATA_TOKEN"],
}).pubsub.schedule("0 * * * *").onRun(async (context) => {
  try {
    if (await isSyncDisabled()) {
      console.log("Sync is disabled via settings/sync_config.");
      await writeSyncStatus("full", {
        ok: true,
        disabled: true,
        reason: "hourly",
      });
      return null;
    }
    const now = new Date();
    await syncFullResults({
      includeTable: true,
      includeCleanup: now.getUTCHours() === 0,
      forceRecalculate: true,
      reason: "hourly",
    });
    return null;
  } catch (error) {
    console.error("syncResults job failed with error:", error);
    await writeSyncStatus("full", {
      ok: false,
      reason: "hourly",
      error: String(error?.message ?? error),
    });
    return null;
  }
});
