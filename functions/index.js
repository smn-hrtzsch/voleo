const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const OPENLIGADB_URL = 'https://api.openligadb.de/getmatchdata/wm2026/2026';

const GROUP_BY_FIXTURE = new Map([
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
].map(([group, home, away]) => [`${teamKey(home)}:${teamKey(away)}`, group]));

function teamKey(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/&/g, "und")
    .replace(/[^a-z0-9]/g, "");
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
  const id = String(match.matchID ?? match.matchId ?? "");
  const homeTeam = match.team1?.teamName;
  const awayTeam = match.team2?.teamName;
  const kickoff = match.matchDateTimeUTC ?? match.matchDateTime;
  if (!id || !homeTeam || !awayTeam || !kickoff) return null;

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

  const homeScore = penaltyHomeScore !== null ? penaltyHomeScore : (otHomeScore !== null ? otHomeScore : (regularHomeScore !== null ? regularHomeScore : null));
  const awayScore = penaltyAwayScore !== null ? penaltyAwayScore : (otAwayScore !== null ? otAwayScore : (regularAwayScore !== null ? regularAwayScore : null));

  const isFinished = match.matchIsFinished;
  const kickoffDate = new Date(kickoff);
  const now = new Date();
  const status = isFinished ? "finalResult" : (now > kickoffDate ? "live" : "scheduled");

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
    return a.displayName.localeCompare(b.displayName);
  });

  let rank = 0;
  let previous = "";
  return sorted.map((standing, index) => {
    const key = `${standing.totalPoints}:${standing.exactCount}`;
    if (key !== previous) {
      rank = index + 1;
      previous = key;
    }
    return { ...standing, rank };
  });
}

async function recalculateScores(allMatches, finalMatches) {
  if (finalMatches.length === 0) return;
  const finalMatchById = new Map(finalMatches.map((m) => [m.id, m]));

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
      const frozenTendencyCount = data.frozenTendencyCount ?? 0;

      stats.set(uid, {
        uid,
        displayName: displayNames.get(uid) ?? "Spieler",
        photoUrl: photoUrls.get(uid) ?? null,
        totalPoints: leftAt !== null ? frozenPoints : frozenPoints,
        exactCount: leftAt !== null ? frozenExactCount : frozenExactCount,
        tendencyCount: leftAt !== null ? frozenTendencyCount : frozenTendencyCount,
        joinedAt,
        leftAt,
      });
    });

    // Score tips
    tipsSnap.forEach((tipDoc) => {
      const data = tipDoc.data();
      const matchId = data.matchId;
      const match = finalMatchById.get(matchId);
      if (!match) return;

      const uid = data.uid;
      const current = stats.get(uid);
      if (!current) return;

      if (current.leftAt !== null) return;

      const matchKickoff = new Date(match.kickoff);
      if (matchKickoff < current.joinedAt) return;

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
      if (score.isExact) current.exactCount += 1;
      if (score.isTendency) current.tendencyCount += 1;
      stats.set(uid, current);
    });

    // Add extra points for each active user
    for (const [uid, current] of stats.entries()) {
      if (current.leftAt !== null) continue;
      const userData = userFieldsMap.get(uid);
      const activeMatches = allMatches.filter((m) => new Date(m.kickoff) >= current.joinedAt);
      const extra = calculateExtraPoints(userData, activeMatches);
      current.totalPoints += extra;
    }

    // Rank and update standings
    const ranked = rankStandings([...stats.values()]);
    for (const standing of ranked) {
      const standingRef = db.collection("leagues").doc(leagueId).collection("standings").doc(standing.uid);
      batch.set(standingRef, {
        displayName: standing.displayName,
        totalPoints: standing.totalPoints,
        exactCount: standing.exactCount,
        tendencyCount: standing.tendencyCount,
        rank: standing.rank,
        photoUrl: standing.photoUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    await batch.commit();
  }
}

exports.syncResults = functions.region("europe-west3").runWith({
  timeoutSeconds: 300,
  memory: "256MB",
}).pubsub.schedule("*/5 * * * *").onRun(async (context) => {
  try {
    const configSnap = await db.collection("settings").doc("sync_config").get();
    if (configSnap.exists && configSnap.data().disabled === true) {
      console.log("Sync is disabled via settings/sync_config.");
      return null;
    }
    console.log("Starting syncResults job...");
    const response = await fetch(OPENLIGADB_URL);
    if (!response.ok) {
      throw new Error(`OpenLigaDB request failed with ${response.status}`);
    }
    const rawMatches = await response.json();
    const groupMatches = rawMatches.map(normalizeMatch).filter(Boolean);

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

    const matchBatch = db.batch();
    for (const match of allMatches) {
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
        source: "openligadb",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await matchBatch.commit();
    console.log(`Synced ${allMatches.length} matches to Firestore.`);

    const finalMatches = allMatches.filter((m) => m.status === "finalResult");
    if (finalMatches.length > 0) {
      await recalculateScores(allMatches, finalMatches);
    }
    console.log("syncResults job completed successfully.");
  } catch (error) {
    console.error("syncResults job failed with error:", error);
  }
});
