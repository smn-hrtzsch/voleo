import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

// 1. Get access token from config
const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const refreshToken = config.tokens.refresh_token;

let accessToken = config.tokens.access_token;
const expiresAt = config.tokens.expires_at;

if (!accessToken || Date.now() >= expiresAt) {
  console.log('Access token is expired or missing. Refreshing OAuth access token from Google...');
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    }),
  });

  if (!tokenResponse.ok) {
    const errText = await tokenResponse.text();
    throw new Error(`Token request failed with ${tokenResponse.status}: ${errText}`);
  }
  const tokenData = await tokenResponse.json();
  accessToken = tokenData.access_token;
  console.log('Access token refreshed.');
} else {
  console.log('Using existing valid access token from config.');
}

const projectId = 'voleo-sho2303';

class FirestoreRestClient {
  constructor(projectId, accessToken) {
    this.projectId = projectId;
    this.accessToken = accessToken;
    this.baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  }

  document(...segmentsAndFields) {
    const fields = segmentsAndFields.pop();
    return {
      name: `projects/${this.projectId}/databases/(default)/documents/${segmentsAndFields.map(encodeURIComponent).join('/')}`,
      fields,
    };
  }

  documentFromName(name, fields) {
    return { name, fields };
  }

  async getDocument(...segments) {
    const url = `${this.baseUrl}/${segments.map(encodeURIComponent).join('/')}`;
    const response = await fetch(url, {
      headers: { authorization: `Bearer ${this.accessToken}` },
    });
    if (response.status === 404) return null;
    if (!response.ok) {
      throw new Error(`Firestore get failed with ${response.status}: ${url}`);
    }
    return await response.json();
  }

  async setDocument(path, fields) {
    const url = `${this.baseUrl}/${path}`;
    const response = await fetch(url, {
      method: 'PATCH',
      headers: {
        authorization: `Bearer ${this.accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ fields }),
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Firestore set failed with ${response.status}: ${text}`);
    }
    return await response.json();
  }

  async listDocuments(...segments) {
    const url = `${this.baseUrl}/${segments.map(encodeURIComponent).join('/')}`;
    const response = await fetch(url, {
      headers: { authorization: `Bearer ${this.accessToken}` },
    });
    if (!response.ok && response.status !== 404) {
      throw new Error(`Firestore list failed with ${response.status}: ${url}`);
    }
    if (response.status === 404) return [];
    const data = await response.json();
    return data.documents ?? [];
  }

  async batchWrite(writes) {
    if (writes.length === 0) return;
    const response = await fetch(
      `https://firestore.googleapis.com/v1/projects/${this.projectId}/databases/(default)/documents:batchWrite`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.accessToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ writes }),
      },
    );
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Firestore batchWrite failed with ${response.status}: ${text}`);
    }
  }
}

const firestore = new FirestoreRestClient(projectId, accessToken);

function stringValue(value) { return { stringValue: value }; }
function intValue(value) { return { integerValue: String(value) }; }
function nullableIntValue(value) { return value == null ? { nullValue: null } : intValue(value); }
function timestampValue(value) { return { timestampValue: value }; }
function booleanValue(value) { return { booleanValue: value }; }
function arrayValue(values) { return { arrayValue: { values } }; }

// Disable functions sync
console.log('Disabling background sync job in Firestore settings...');
await firestore.setDocument('settings/sync_config', {
  disabled: booleanValue(true),
  updatedAt: timestampValue(new Date().toISOString()),
});

// Find active league
console.log('Finding active league...');
const leagues = await firestore.listDocuments('leagues');
if (leagues.length === 0) {
  throw new Error('No leagues found in Firestore!');
}
let leagueDoc = leagues.find(l => l.name.endsWith('VxekZ4yyTJRvsI1P3Wqy'));
if (!leagueDoc) {
  leagueDoc = leagues[0];
}
const leagueId = leagueDoc.name.split('/').pop();
console.log(`Using league ID: ${leagueId}`);

// Load group stage matches template
const matchesJson = JSON.parse(fs.readFileSync('tool/group_stage_matches.json', 'utf8'));
const groupMatches = matchesJson.filter(m => m.stage.includes('Runde') || m.group !== '');
const koMatches = matchesJson.filter(m => !m.stage.includes('Runde') && m.group === '');

console.log(`Loaded ${groupMatches.length} group matches and ${koMatches.length} KO matches.`);

// Read existing tips from Firestore to preserve user tips
console.log('Fetching existing tips from Firestore...');
const existingTipsDocs = await firestore.listDocuments('leagues', leagueId, 'tips');
const userTipsMap = {}; // { uid: { matchId: [home, away] } }
for (const doc of existingTipsDocs) {
  const fields = doc.fields;
  if (fields) {
    const uid = fields.uid.stringValue;
    const matchId = fields.matchId.stringValue;
    const home = parseInt(fields.predictedHome.integerValue, 10);
    const away = parseInt(fields.predictedAway.integerValue, 10);
    userTipsMap[uid] = userTipsMap[uid] || {};
    userTipsMap[uid][matchId] = [home, away];
  }
}

// Read members
console.log('Fetching league members...');
const membersDocs = await firestore.listDocuments('leagues', leagueId, 'members');
const uids = membersDocs.map(doc => doc.name.split('/').pop());
console.log(`League members: ${uids.join(', ')}`);

// Setup deterministic random results
let seed = 98765;
function random() {
  let x = Math.sin(seed++) * 10000;
  return x - Math.floor(x);
}
function randomGoals() {
  const r = random();
  if (r < 0.25) return 0;
  if (r < 0.55) return 1;
  if (r < 0.85) return 2;
  return 3;
}

// 1. Simulate results for all group stage matches
const simulatedMatches = [];
for (const m of groupMatches) {
  const homeScore = randomGoals();
  const awayScore = randomGoals();
  simulatedMatches.push({
    ...m,
    status: 'finalResult',
    homeScore,
    awayScore,
  });
}

// 2. Setup mock users
const mockUsers = [
  { uid: 'mock-user-max', nickname: 'Max', favoriteTeam: 'Kanada', predictedChampion: 'Deutschland', riskTeam: 'Spanien', riskStage: 'Gruppenphase' },
  { uid: 'mock-user-anna', nickname: 'Anna', favoriteTeam: 'Mexiko', predictedChampion: 'Brasilien', riskTeam: 'Portugal', riskStage: 'Halbfinale' },
  { uid: 'mock-user-felix', nickname: 'Felix', favoriteTeam: 'USA', predictedChampion: 'England', riskTeam: 'Niederlande', riskStage: 'Achtelfinale' },
  { uid: 'mock-user-clara', nickname: 'Clara', favoriteTeam: 'Deutschland', predictedChampion: 'Frankreich', riskTeam: 'Schweiz', riskStage: 'Achtelfinale' },
  { uid: 'mock-user-jonas', nickname: 'Jonas', favoriteTeam: 'Kroatien', predictedChampion: 'Spanien', riskTeam: 'Panama', riskStage: 'Viertelfinale' }
];

console.log('Writing/updating mock user profiles...');
const userWrites = mockUsers.map(user => ({
  update: firestore.document('users', user.uid, {
    nickname: stringValue(user.nickname),
    favoriteTeam: stringValue(user.favoriteTeam),
    predictedChampion: stringValue(user.predictedChampion),
    riskTeam: stringValue(user.riskTeam),
    riskStage: stringValue(user.riskStage),
    activeLeagueId: stringValue(leagueId),
    leagueIds: arrayValue([stringValue(leagueId)]),
    isAnonymous: booleanValue(true),
    createdAt: timestampValue(new Date().toISOString()),
    updatedAt: timestampValue(new Date().toISOString()),
  })
}));
await firestore.batchWrite(userWrites);

// Make sure mock users are in the league members list
const allUids = [...new Set([...uids, ...mockUsers.map(u => u.uid)])];

// Update league memberIds list
await firestore.setDocument(`leagues/${leagueId}`, {
  name: leagueDoc.fields.name,
  inviteCode: leagueDoc.fields.inviteCode,
  ownerUid: leagueDoc.fields.ownerUid,
  memberIds: arrayValue(allUids.map(uid => stringValue(uid))),
  scoringPreset: stringValue('classic'),
  createdAt: leagueDoc.fields.createdAt,
  updatedAt: timestampValue(new Date().toISOString()),
});

// Helper for scoring tips
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

// 3. Generate tips for bots & calculate points
const tipWrites = [];
const memberStats = {};
for (const uid of allUids) {
  memberStats[uid] = { totalPoints: 0, exactCount: 0, tendencyCount: 0 };
}

for (const uid of allUids) {
  const isBot = mockUsers.some(u => u.uid === uid);
  const existingUserTips = userTipsMap[uid] || {};

  for (const match of simulatedMatches) {
    let predHome, predAway;
    if (isBot) {
      // Generate bot tip
      predHome = randomGoals();
      predAway = randomGoals();
    } else {
      // Real user: check if they tipped this match
      if (existingUserTips[match.id] !== undefined) {
        [predHome, predAway] = existingUserTips[match.id];
      } else {
        // Did not tip: no points
        continue;
      }
    }

    const score = scoreTip(predHome, predAway, match.homeScore, match.awayScore);
    memberStats[uid].totalPoints += score.points;
    if (score.isExact) memberStats[uid].exactCount++;
    if (score.isTendency) memberStats[uid].tendencyCount++;

    tipWrites.push({
      update: firestore.document('leagues', leagueId, 'tips', `${uid}_${match.id}`, {
        uid: stringValue(uid),
        matchId: stringValue(match.id),
        predictedHome: intValue(predHome),
        predictedAway: intValue(predAway),
        points: intValue(score.points),
        lockedAt: timestampValue(match.kickoff),
      })
    });
  }
}
console.log(`Writing ${tipWrites.length} tips...`);
// Batch tips writes in chunks of 200
for (let i = 0; i < tipWrites.length; i += 200) {
  await firestore.batchWrite(tipWrites.slice(i, i + 200));
}

// 4. Calculate Group Tables
console.log('Calculating group tables...');
const groupTables = {}; // { 'A': { 'Mexiko': { pts, diff, goalsFor, team } } }
for (const m of simulatedMatches) {
  const g = m.group;
  if (!g) continue;
  groupTables[g] = groupTables[g] || {};
  groupTables[g][m.homeTeam] = groupTables[g][m.homeTeam] || { pts: 0, diff: 0, goalsFor: 0, team: m.homeTeam };
  groupTables[g][m.awayTeam] = groupTables[g][m.awayTeam] || { pts: 0, diff: 0, goalsFor: 0, team: m.awayTeam };

  const hs = m.homeScore;
  const as = m.awayScore;
  groupTables[g][m.homeTeam].goalsFor += hs;
  groupTables[g][m.homeTeam].diff += (hs - as);
  groupTables[g][m.awayTeam].goalsFor += as;
  groupTables[g][m.awayTeam].diff += (as - hs);

  if (hs > as) {
    groupTables[g][m.homeTeam].pts += 3;
  } else if (as > hs) {
    groupTables[g][m.awayTeam].pts += 3;
  } else {
    groupTables[g][m.homeTeam].pts += 1;
    groupTables[g][m.awayTeam].pts += 1;
  }
}

const sortedTables = {};
for (const g of Object.keys(groupTables)) {
  const teams = Object.values(groupTables[g]);
  teams.sort((a, b) => {
    const pts = b.pts - a.pts;
    if (pts !== 0) return pts;
    const diff = b.diff - a.diff;
    if (diff !== 0) return diff;
    const goals = b.goalsFor - a.goalsFor;
    if (goals !== 0) return goals;
    return a.team.localeCompare(b.team);
  });
  sortedTables[g] = teams;
}

// Determine qualified teams
const top1 = {}; // winner of group: groupName -> team
const top2 = {}; // runner-up of group: groupName -> team
const top3 = []; // list of 3rd place teams: { team, group, pts, diff, goalsFor }

for (const g of Object.keys(sortedTables)) {
  const list = sortedTables[g];
  top1[g] = list[0].team;
  top2[g] = list[1].team;
  top3.push({
    team: list[2].team,
    group: g,
    pts: list[2].pts,
    diff: list[2].diff,
    goalsFor: list[2].goalsFor,
  });
}

// Sort the 12 third-placed teams
top3.sort((a, b) => {
  const pts = b.pts - a.pts;
  if (pts !== 0) return pts;
  const diff = b.diff - a.diff;
  if (diff !== 0) return diff;
  const goals = b.goalsFor - a.goalsFor;
  if (goals !== 0) return goals;
  return a.team.localeCompare(b.team);
});

// Top 8 qualify
const qualified3rd = top3.slice(0, 8);
console.log('Qualified 3rd-placed teams:', qualified3rd.map(t => `${t.team} (Group ${t.group}, ${t.pts} pts, diff ${t.diff})`).join(', '));

// Distribute to the 4 slots:
// Bester 3. Gruppe A/B/C
// Bester 3. Gruppe D/E/F
// Bester 3. Gruppe G/H/I
// Bester 3. Gruppe J/K/L
function getBest3FromGroups(groupsList) {
  const candidates = qualified3rd.filter(t => groupsList.includes(t.group));
  if (candidates.length > 0) {
    const pick = candidates[0];
    const index = qualified3rd.indexOf(pick);
    qualified3rd.splice(index, 1);
    return pick.team;
  }
  if (qualified3rd.length > 0) {
    return qualified3rd.shift().team;
  }
  return 'TBD';
}

const best3ABC = getBest3FromGroups(['A', 'B', 'C']);
const best3DEF = getBest3FromGroups(['D', 'E', 'F']);
const best3GHI = getBest3FromGroups(['G', 'H', 'I']);
const best3JKL = getBest3FromGroups(['J', 'K', 'L']);

// 5. Build K.O. Phase Sechzehntelfinale matches with actual teams!
const resolvedKoMatches = [];

// Match definitions mapping
const sfMatchesMapping = [
  { id: 'wc-ko-sf-1', home: top1['A'], away: top2['C'] },
  { id: 'wc-ko-sf-2', home: top2['A'], away: top1['C'] },
  { id: 'wc-ko-sf-3', home: top1['B'], away: top2['D'] },
  { id: 'wc-ko-sf-4', home: top2['B'], away: top1['D'] },
  { id: 'wc-ko-sf-5', home: top1['E'], away: top2['G'] },
  { id: 'wc-ko-sf-6', home: top2['E'], away: top1['G'] },
  { id: 'wc-ko-sf-7', home: top1['F'], away: top2['H'] },
  { id: 'wc-ko-sf-8', home: top2['F'], away: top1['H'] },
  { id: 'wc-ko-sf-9', home: top1['I'], away: top2['K'] },
  { id: 'wc-ko-sf-10', home: top2['I'], away: top1['K'] },
  { id: 'wc-ko-sf-11', home: top1['J'], away: top2['L'] },
  { id: 'wc-ko-sf-12', home: top2['J'], away: top1['L'] },
  { id: 'wc-ko-sf-13', home: best3ABC, away: top1['H'] },
  { id: 'wc-ko-sf-14', home: best3DEF, away: top1['I'] },
  { id: 'wc-ko-sf-15', home: best3GHI, away: top1['J'] },
  { id: 'wc-ko-sf-16', home: best3JKL, away: top1['K'] },
];

console.log('Sechzehntelfinale matchups:');
for (const mapping of sfMatchesMapping) {
  const mTemplate = koMatches.find(m => m.id === mapping.id);
  resolvedKoMatches.push({
    ...mTemplate,
    homeTeam: mapping.home,
    awayTeam: mapping.away,
    status: 'scheduled',
    homeScore: null,
    awayScore: null,
  });
  console.log(`- ${mapping.home} vs ${mapping.away}`);
}

// Add the other K.O. rounds with placeholders
const remainingKoMatches = koMatches.filter(m => !m.id.startsWith('wc-ko-sf-'));
for (const m of remainingKoMatches) {
  resolvedKoMatches.push({
    ...m,
    status: 'scheduled',
    homeScore: null,
    awayScore: null,
  });
}

// 6. Calculate User Booster / Extra Points
const userFieldsMap = new Map();
for (const uid of allUids) {
  const userDoc = await firestore.getDocument('users', uid);
  if (userDoc && userDoc.fields) {
    userFieldsMap.set(uid, userDoc.fields);
  }
}

function getEliminationStage(team, allSimMatches) {
  const inSf = sfMatchesMapping.some(mapping => mapping.home === team || mapping.away === team);
  if (!inSf) {
    return 'Gruppenphase';
  }
  return null;
}

function getTier(team) {
  const favorites = ['Argentinien', 'Brasilien', 'Deutschland', 'England', 'Frankreich', 'Portugal', 'Spanien'];
  const tops = ['Belgien', 'Japan', 'Kroatien', 'Marokko', 'Niederlande', 'Norwegen', 'Schweiz', 'Senegal', 'Uruguay'];
  const mids = ['Algerien', 'Australien', 'Bosnien und Herzegowina', 'Bosnien-Herzegowina', 'Bosnien Herzegowina', 'Bosnia and Herzegovina', 'Kolumbien', 'Ecuador', 'Elfenbeinküste', 'Ghana', 'Mexiko', 'Österreich', 'Schweden', 'Südkorea', 'Tschechien', 'Türkei', 'USA'];
  if (favorites.includes(team)) return 'Absolute Titelfavoriten';
  if (tops.includes(team)) return 'Top Team';
  if (mids.includes(team)) return 'Durchschnittliches Team';
  return 'Gurkentruppe';
}

function stageRank(stage) {
  switch (stage) {
    case 'Gruppenphase': return 0;
    case 'Sechzehntelfinale': return 1;
    case 'Achtelfinale': return 2;
    case 'Viertelfinale': return 3;
    case 'Halbfinale': return 4;
    case 'Finale': return 5;
    case 'Champion': return 6;
  }
  return 99;
}

function calculateRiskPoints(team, predictedStage, actualStage) {
  const tier = getTier(team);
  const isCorrect = stageRank(actualStage) <= stageRank(predictedStage);
  if (tier === 'Absolute Titelfavoriten') {
    if (predictedStage === 'Gruppenphase') return isCorrect ? 70 : -70;
    if (predictedStage === 'Sechzehntelfinale') return isCorrect ? 60 : -60;
    if (predictedStage === 'Achtelfinale') return isCorrect ? 50 : -50;
    if (predictedStage === 'Viertelfinale') return isCorrect ? 30 : -30;
    if (predictedStage === 'Halbfinale') return isCorrect ? 15 : -15;
    if (predictedStage === 'Finale') return isCorrect ? 5 : -5;
  } else if (tier === 'Top Team') {
    if (predictedStage === 'Gruppenphase') return isCorrect ? 40 : -40;
    if (predictedStage === 'Sechzehntelfinale') return isCorrect ? 30 : -30;
    if (predictedStage === 'Achtelfinale') return isCorrect ? 20 : -20;
    if (predictedStage === 'Viertelfinale') return isCorrect ? 20 : -20;
    if (predictedStage === 'Halbfinale') return isCorrect ? 40 : -40;
    if (predictedStage === 'Finale') return isCorrect ? 50 : -50;
  } else if (tier === 'Durchschnittliches Team') {
    if (predictedStage === 'Gruppenphase') return isCorrect ? 5 : -5;
    if (predictedStage === 'Sechzehntelfinale') return isCorrect ? 10 : -10;
    if (predictedStage === 'Achtelfinale') return isCorrect ? 15 : -15;
    if (predictedStage === 'Viertelfinale') return isCorrect ? 35 : -35;
    if (predictedStage === 'Halbfinale') return isCorrect ? 55 : -55;
    if (predictedStage === 'Finale') return isCorrect ? 65 : -65;
  } else {
    // Gurkentruppe
    if (predictedStage === 'Gruppenphase') return isCorrect ? 5 : -5;
    if (predictedStage === 'Sechzehntelfinale') return isCorrect ? 15 : -15;
    if (predictedStage === 'Achtelfinale') return isCorrect ? 30 : -30;
    if (predictedStage === 'Viertelfinale') return isCorrect ? 50 : -50;
    if (predictedStage === 'Halbfinale') return isCorrect ? 65 : -65;
    if (predictedStage === 'Finale') return isCorrect ? 80 : -80;
  }
  return 0;
}

function getPickValues(uid) {
  const mock = mockUsers.find(u => u.uid === uid);
  if (mock) {
    return {
      favoriteTeam: mock.favoriteTeam,
      predictedChampion: mock.predictedChampion,
      riskTeam: mock.riskTeam,
      riskStage: mock.riskStage,
    };
  }
  const fields = userFieldsMap.get(uid);
  if (fields) {
    return {
      favoriteTeam: fields.favoriteTeam?.stringValue ?? null,
      predictedChampion: fields.predictedChampion?.stringValue ?? null,
      riskTeam: fields.riskTeam?.stringValue ?? null,
      riskStage: fields.riskStage?.stringValue ?? null,
    };
  }
  return {};
}

// Add extra booster points
for (const uid of allUids) {
  const picks = getPickValues(uid);
  let extraPoints = 0;

  // 1. Lieblingsteam
  const fav = picks.favoriteTeam;
  if (fav) {
    for (const match of simulatedMatches) {
      if (match.homeTeam === fav && match.homeScore > match.awayScore) {
        extraPoints += 10;
      } else if (match.awayTeam === fav && match.awayScore > match.homeScore) {
        extraPoints += 10;
      }
    }
  }

  // 2. Champion-Tipp
  const champ = picks.predictedChampion;
  if (champ) {
    for (const match of simulatedMatches) {
      if (match.homeTeam === champ && match.homeScore > match.awayScore) {
        extraPoints += 10;
      } else if (match.awayTeam === champ && match.awayScore > match.homeScore) {
        extraPoints += 10;
      }
    }
  }

  // 3. Risiko-Tipp
  const rTeam = picks.riskTeam;
  const rStage = picks.riskStage;
  if (rTeam && rStage) {
    const actualStage = getEliminationStage(rTeam, simulatedMatches);
    if (actualStage) {
      extraPoints += calculateRiskPoints(rTeam, rStage, actualStage);
    }
  }

  console.log(`User ${uid} gets ${extraPoints} extra/booster points.`);
  memberStats[uid].totalPoints += extraPoints;
}

// 7. Write all matches to Firestore
console.log('Writing simulated matches to Firestore...');
const matchWrites = [];
const allMatchesToWrite = [...simulatedMatches, ...resolvedKoMatches];
for (const match of allMatchesToWrite) {
  matchWrites.push({
    update: firestore.document('matches', match.id, {
      homeTeam: stringValue(match.homeTeam),
      awayTeam: stringValue(match.awayTeam),
      kickoff: timestampValue(match.kickoff),
      stage: stringValue(match.stage),
      group: stringValue(match.group || ''),
      status: stringValue(match.status),
      homeScore: nullableIntValue(match.homeScore),
      awayScore: nullableIntValue(match.awayScore),
      winner: match.winner ? stringValue(match.winner) : { nullValue: null },
      source: stringValue('openligadb'),
      updatedAt: timestampValue(new Date().toISOString()),
    })
  });
}
for (let i = 0; i < matchWrites.length; i += 200) {
  await firestore.batchWrite(matchWrites.slice(i, i + 200));
}

// 8. Write members collection to Firestore
console.log('Writing members stats...');
const memberWrites = [];
for (const uid of allUids) {
  const fields = userFieldsMap.get(uid);
  const nickname = fields?.nickname?.stringValue ?? mockUsers.find(u => u.uid === uid)?.nickname ?? 'Spieler';
  const photoUrl = fields?.photoUrl?.stringValue ?? null;
  const isOwner = uid === 'SKqNUlbDAhblyfAXpM8Sk1kf2Vt2';

  memberWrites.push({
    update: firestore.document('leagues', leagueId, 'members', uid, {
      displayName: stringValue(nickname),
      photoUrl: photoUrl ? stringValue(photoUrl) : { nullValue: null },
      role: stringValue(isOwner ? 'owner' : 'member'),
      joinedAt: timestampValue(fields?.createdAt?.timestampValue ?? new Date('2026-06-09T09:39:54Z').toISOString()),
      totalPoints: intValue(memberStats[uid].totalPoints),
      exactCount: intValue(memberStats[uid].exactCount),
      tendencyCount: intValue(memberStats[uid].tendencyCount),
    })
  });
}
await firestore.batchWrite(memberWrites);

// 9. Rank standings and write to Firestore
console.log('Ranking standings...');
const standingsList = allUids.map(uid => {
  const fields = userFieldsMap.get(uid);
  const nickname = fields?.nickname?.stringValue ?? mockUsers.find(u => u.uid === uid)?.nickname ?? 'Spieler';
  const photoUrl = fields?.photoUrl?.stringValue ?? null;
  return {
    uid,
    displayName: nickname,
    photoUrl,
    totalPoints: memberStats[uid].totalPoints,
    exactCount: memberStats[uid].exactCount,
    tendencyCount: memberStats[uid].tendencyCount,
  };
});

standingsList.sort((a, b) => {
  const points = b.totalPoints - a.totalPoints;
  if (points !== 0) return points;
  const exact = b.exactCount - a.exactCount;
  if (exact !== 0) return exact;
  return a.displayName.localeCompare(b.displayName);
});

let rank = 0;
let previousKey = null;
const standingsWrites = standingsList.map((standing, index) => {
  const key = `${standing.totalPoints}:${standing.exactCount}`;
  if (key !== previousKey) {
    rank = index + 1;
    previousKey = key;
  }
  return {
    update: firestore.document('leagues', leagueId, 'standings', standing.uid, {
      displayName: stringValue(standing.displayName),
      photoUrl: standing.photoUrl ? stringValue(standing.photoUrl) : { nullValue: null },
      totalPoints: intValue(standing.totalPoints),
      exactCount: intValue(standing.exactCount),
      tendencyCount: intValue(standing.tendencyCount),
      rank: intValue(rank),
      updatedAt: timestampValue(new Date().toISOString()),
    })
  };
});
await firestore.batchWrite(standingsWrites);

console.log('Group stage simulation completed successfully!');
