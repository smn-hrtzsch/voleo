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
const leagueId = 'VxekZ4yyTJRvsI1P3Wqy';

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
    return (await response.json()).documents ?? [];
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

// First 5 Matches definition
const matchesData = [
  { id: 'wc2026-ga-1', homeTeam: 'Mexiko', awayTeam: 'Südafrika', kickoff: '2026-06-11T19:00:00Z', stage: '1. Runde', group: 'A', status: 'finalResult', homeScore: 2, awayScore: 1 },
  { id: 'wc2026-ga-2', homeTeam: 'Südkorea', awayTeam: 'Tschechien', kickoff: '2026-06-12T02:00:00Z', stage: '1. Runde', group: 'A', status: 'finalResult', homeScore: 1, awayScore: 1 },
  { id: 'wc2026-gb-3', homeTeam: 'Kanada', awayTeam: 'Bosnien und Herzegowina', kickoff: '2026-06-12T19:00:00Z', stage: '1. Runde', group: 'B', status: 'finalResult', homeScore: 0, awayScore: 2 },
  { id: 'wc2026-gd-4', homeTeam: 'USA', awayTeam: 'Paraguay', kickoff: '2026-06-13T01:00:00Z', stage: '1. Runde', group: 'D', status: 'finalResult', homeScore: 3, awayScore: 0 },
  { id: 'wc2026-gb-5', homeTeam: 'Katar', awayTeam: 'Schweiz', kickoff: '2026-06-13T19:00:00Z', stage: '1. Runde', group: 'B', status: 'live', homeScore: 1, awayScore: 2 },
];

console.log('Writing simulated matches to Firestore...');
const matchWrites = matchesData.map(match => ({
  update: firestore.document('matches', match.id, {
    homeTeam: stringValue(match.homeTeam),
    awayTeam: stringValue(match.awayTeam),
    kickoff: timestampValue(match.kickoff),
    stage: stringValue(match.stage),
    group: stringValue(match.group),
    status: stringValue(match.status),
    homeScore: nullableIntValue(match.homeScore),
    awayScore: nullableIntValue(match.awayScore),
    source: stringValue('openligadb'),
    updatedAt: timestampValue(new Date().toISOString()),
  })
}));
await firestore.batchWrite(matchWrites);

// 3 Mock Users + 2 Real Users UIDs
const mockUsers = [
  { uid: 'mock-user-max', nickname: 'Max', favoriteTeam: 'Kanada', predictedChampion: 'Deutschland', riskTeam: 'Spanien', riskStage: 'Gruppenphase' },
  { uid: 'mock-user-anna', nickname: 'Anna', favoriteTeam: 'Mexiko', predictedChampion: 'Brasilien', riskTeam: 'Portugal', riskStage: 'Halbfinale' },
  { uid: 'mock-user-felix', nickname: 'Felix', favoriteTeam: 'USA', predictedChampion: 'England', riskTeam: 'Niederlande', riskStage: 'Achtelfinale' },
  { uid: 'mock-user-clara', nickname: 'Clara', favoriteTeam: 'Deutschland', predictedChampion: 'Frankreich', riskTeam: 'Schweiz', riskStage: 'Achtelfinale' },
  { uid: 'mock-user-jonas', nickname: 'Jonas', favoriteTeam: 'Kroatien', predictedChampion: 'Spanien', riskTeam: 'Panama', riskStage: 'Viertelfinale' }
];

console.log('Writing mock user profiles to Firestore...');
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

// Update league document with member IDs
const uids = [
  'SKqNUlbDAhblyfAXpM8Sk1kf2Vt2',
  'JZMz6Tfks8WhKCTn1TSOlOSisqt1',
  'mock-user-max',
  'mock-user-anna',
  'mock-user-felix',
  'mock-user-clara',
  'mock-user-jonas'
];

console.log('Updating league members list and restoring details...');
await firestore.setDocument(`leagues/${leagueId}`, {
  name: stringValue('Meine WM-Runde'),
  inviteCode: stringValue('BLFPKY'),
  ownerUid: stringValue('SKqNUlbDAhblyfAXpM8Sk1kf2Vt2'),
  memberIds: arrayValue(uids.map(uid => stringValue(uid))),
  scoringPreset: stringValue('classic'),
  createdAt: timestampValue('2026-06-09T09:39:54Z'),
  updatedAt: timestampValue(new Date().toISOString()),
});

// Mock Tips
const simulatedTips = {
  // Simon (SKqNUlbDAhblyfAXpM8Sk1kf2Vt2): total = 4 + 0 + 4 + 2 = 10
  'SKqNUlbDAhblyfAXpM8Sk1kf2Vt2': {
    'wc2026-ga-1': [2, 1], // Mex vs RSA (2:1) -> Exact (4)
    'wc2026-ga-2': [1, 2], // Kor vs Cze (1:1) -> Wrong (0)
    'wc2026-gb-3': [0, 2], // Can vs BIH (0:2) -> Exact (4)
    'wc2026-gd-4': [2, 0], // USA vs Par (3:0) -> Tendency (2)
    'wc2026-gb-5': [0, 2]  // Kat vs Sui (1:2) -> Live (no points yet)
  },
  // Hortzsch 2 (JZMz6Tfks8WhKCTn1TSOlOSisqt1): total = 3 + 4 + 2 + 4 = 13
  'JZMz6Tfks8WhKCTn1TSOlOSisqt1': {
    'wc2026-ga-1': [1, 0], // Mex vs RSA (2:1) -> Diff (3)
    'wc2026-ga-2': [1, 1], // Kor vs Cze (1:1) -> Exact (4)
    'wc2026-gb-3': [1, 2], // Can vs BIH (0:2) -> Tendency (2)
    'wc2026-gd-4': [3, 0], // USA vs Par (3:0) -> Exact (4)
    'wc2026-gb-5': [1, 2]  // Kat vs Sui (1:2) -> Live (no points yet)
  },
  // Max: total = 0 + 3 + 0 + 4 = 7
  'mock-user-max': {
    'wc2026-ga-1': [1, 1], // Mex vs RSA (2:1) -> Wrong (0)
    'wc2026-ga-2': [0, 0], // Kor vs Cze (1:1) -> Diff (3)
    'wc2026-gb-3': [2, 1], // Can vs BIH (0:2) -> Wrong (0)
    'wc2026-gd-4': [3, 0], // USA vs Par (3:0) -> Exact (4)
    'wc2026-gb-5': [1, 3]  // Kat vs Sui (1:2) -> Live
  },
  // Anna: total = 2 + 3 + 2 + 0 = 7
  'mock-user-anna': {
    'wc2026-ga-1': [2, 0], // Mex vs RSA (2:1) -> Tendency (2)
    'wc2026-ga-2': [2, 2], // Kor vs Cze (1:1) -> Diff (3)
    'wc2026-gb-3': [0, 1], // Can vs BIH (0:2) -> Tendency (2)
    'wc2026-gd-4': [1, 1], // USA vs Par (3:0) -> Wrong (0)
    'wc2026-gb-5': [0, 0]  // Kat vs Sui (1:2) -> Live
  },
  // Felix: total = 0 + 0 + 4 + 2 = 6
  'mock-user-felix': {
    'wc2026-ga-1': [0, 1], // Mex vs RSA (2:1) -> Wrong (0)
    'wc2026-ga-2': [2, 1], // Kor vs Cze (1:1) -> Wrong (0)
    'wc2026-gb-3': [0, 2], // Can vs BIH (0:2) -> Exact (4)
    'wc2026-gd-4': [2, 1], // USA vs Par (3:0) -> Tendency (2)
    'wc2026-gb-5': [1, 1]  // Kat vs Sui (1:2) -> Live
  },
  // Clara: total = 4 + 4 + 0 + 2 = 10
  'mock-user-clara': {
    'wc2026-ga-1': [2, 1], // Mex vs RSA (2:1) -> Exact (4)
    'wc2026-ga-2': [1, 1], // Kor vs Cze (1:1) -> Exact (4)
    'wc2026-gb-3': [2, 0], // Can vs BIH (0:2) -> Wrong (0)
    'wc2026-gd-4': [1, 0], // USA vs Par (3:0) -> Tendency (2)
    'wc2026-gb-5': [1, 1]  // Kat vs Sui (1:2) -> Live
  },
  // Jonas: total = 3 + 3 + 4 + 0 = 10
  'mock-user-jonas': {
    'wc2026-ga-1': [3, 2], // Mex vs RSA (2:1) -> Diff (3)
    'wc2026-ga-2': [2, 2], // Kor vs Cze (1:1) -> Diff (3)
    'wc2026-gb-3': [0, 2], // Can vs BIH (0:2) -> Exact (4)
    'wc2026-gd-4': [1, 1], // USA vs Par (3:0) -> Wrong (0)
    'wc2026-gb-5': [2, 2]  // Kat vs Sui (1:2) -> Live
  }
};

function scoreTip(predictedHome, predictedAway, actualHome, actualAway) {
  if (predictedHome === actualHome && predictedAway === actualAway) {
    return { points: 4, isExact: true, isTendency: true };
  }
  const predictedDiff = predictedHome - predictedAway;
  const actualDiff = actualHome - actualAway;
  if (predictedDiff === actualDiff) {
    return { points: 3, isExact: false, isTendency: true };
  }
  if (Math.sign(predictedDiff) === Math.sign(actualDiff)) {
    return { points: 2, isExact: false, isTendency: true };
  }
  return { points: 0, isExact: false, isTendency: false };
}

console.log('Writing simulated tips to Firestore...');
const tipWrites = [];
const memberStats = {};

// Initialize stats
for (const uid of uids) {
  memberStats[uid] = {
    totalPoints: 0,
    exactCount: 0,
    tendencyCount: 0
  };
}

for (const uid of uids) {
  const tips = simulatedTips[uid];
  for (const matchId of Object.keys(tips)) {
    const [predHome, predAway] = tips[matchId];
    const match = matchesData.find(m => m.id === matchId);
    
    let points = 0;
    let isExact = false;
    let isTendency = false;
    
    if (match.status === 'finalResult') {
      const score = scoreTip(predHome, predAway, match.homeScore, match.awayScore);
      points = score.points;
      isExact = score.isExact;
      isTendency = score.isTendency;
      
      memberStats[uid].totalPoints += points;
      if (isExact) memberStats[uid].exactCount += 1;
      if (isTendency) memberStats[uid].tendencyCount += 1;
    }

    tipWrites.push({
      update: firestore.document('leagues', leagueId, 'tips', `${uid}_${matchId}`, {
        uid: stringValue(uid),
        matchId: stringValue(matchId),
        predictedHome: intValue(predHome),
        predictedAway: intValue(predAway),
        points: intValue(points),
        lockedAt: timestampValue(match.kickoff),
      })
    });
  }
}
await firestore.batchWrite(tipWrites);

// Fetch existing user fields to get nicknames and photoUrls
const userFieldsMap = new Map();
const memberWrites = [];
for (const uid of uids) {
  const userDoc = await firestore.getDocument('users', uid);
  if (userDoc && userDoc.fields) {
    userFieldsMap.set(uid, userDoc.fields);
  }
}

// Helper functions for extra points calculation
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

function getEliminationStage(team, matches) {
  const teamMatches = matches.filter(m => m.homeTeam === team || m.awayTeam === team);
  if (teamMatches.length === 0) return null;
  const knockouts = teamMatches.filter(m => !m.stage.startsWith('Gruppe') && !m.stage.includes('Runde'));
  for (const m of knockouts) {
    if (m.status === 'finalResult' && m.homeScore != null && m.awayScore != null) {
      const isHome = m.homeTeam === team;
      const won = isHome ? (m.homeScore > m.awayScore) : (m.awayScore > m.homeScore);
      if (!won) {
        const stage = m.stage.toLowerCase();
        if (stage.includes('sechzehntel') || stage.includes('32')) return 'Sechzehntelfinale';
        if (stage.includes('achtel') || stage.includes('16')) return 'Achtelfinale';
        if (stage.includes('viertel') || stage.includes('quarter')) return 'Viertelfinale';
        if (stage.includes('halb') || stage.includes('semi')) return 'Halbfinale';
        if (stage.includes('final')) return 'Finale';
      }
    }
  }
  const hasWonFinal = knockouts.some(m =>
    m.stage.toLowerCase().includes('final') &&
    !m.stage.toLowerCase().includes('halb') &&
    !m.stage.toLowerCase().includes('viertel') &&
    m.status === 'finalResult' &&
    m.homeScore != null &&
    m.awayScore != null &&
    ((m.homeTeam === team && m.homeScore > m.awayScore) ||
     (m.awayTeam === team && m.awayScore > m.homeScore))
  );
  if (hasWonFinal) return 'Champion';
  
  const groupMatches = matches.filter(m => m.stage.startsWith('Gruppe') || m.stage.includes('Runde'));
  const allGroupsFinished = groupMatches.length > 0 && groupMatches.every(m => m.status === 'finalResult');
  if (allGroupsFinished && knockouts.length === 0) {
    return 'Gruppenphase';
  }
  return null;
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

// Calculate and add extra/booster points
for (const uid of uids) {
  const picks = getPickValues(uid);
  let extraPoints = 0;

  // 1. Lieblingsteam
  const fav = picks.favoriteTeam;
  if (fav) {
    for (const match of matchesData) {
      if (match.status === 'finalResult') {
        if (match.homeTeam === fav && match.homeScore > match.awayScore) {
          extraPoints += 10;
        } else if (match.awayTeam === fav && match.awayScore > match.homeScore) {
          extraPoints += 10;
        }
      }
    }
  }

  // 2. Champion-Tipp
  const champ = picks.predictedChampion;
  if (champ) {
    for (const match of matchesData) {
      if (match.status === 'finalResult') {
        if (match.homeTeam === champ && match.homeScore > match.awayScore) {
          extraPoints += 10;
        } else if (match.awayTeam === champ && match.awayScore > match.homeScore) {
          extraPoints += 10;
        }
      }
    }
  }

  // 3. Risiko-Tipp
  const rTeam = picks.riskTeam;
  const rStage = picks.riskStage;
  if (rTeam && rStage) {
    const actualStage = getEliminationStage(rTeam, matchesData);
    if (actualStage) {
      extraPoints += calculateRiskPoints(rTeam, rStage, actualStage);
    }
  }

  console.log(`User ${uid} gets ${extraPoints} extra/booster points.`);
  memberStats[uid].totalPoints += extraPoints;
}

// Write league members collection
console.log('Writing league members collection...');
for (const uid of uids) {
  const fields = userFieldsMap.get(uid);
  const nickname = fields?.nickname?.stringValue ?? 'Spieler';
  const photoUrl = fields?.photoUrl?.stringValue ?? null;
  const isOwner = uid === 'SKqNUlbDAhblyfAXpM8Sk1kf2Vt2'; // Simon is owner
  
  memberWrites.push({
    update: firestore.document('leagues', leagueId, 'members', uid, {
      displayName: stringValue(nickname),
      photoUrl: photoUrl ? stringValue(photoUrl) : { nullValue: null },
      role: stringValue(isOwner ? 'owner' : 'member'),
      joinedAt: timestampValue(new Date('2026-06-09T09:39:54Z').toISOString()),
      totalPoints: intValue(memberStats[uid].totalPoints),
      exactCount: intValue(memberStats[uid].exactCount),
      tendencyCount: intValue(memberStats[uid].tendencyCount),
    })
  });
}
await firestore.batchWrite(memberWrites);

// Rank standings
const standingsList = uids.map(uid => ({
  uid,
  displayName: userFieldsMap.get(uid)?.nickname?.stringValue ?? 'Spieler',
  photoUrl: userFieldsMap.get(uid)?.photoUrl?.stringValue ?? null,
  totalPoints: memberStats[uid].totalPoints,
  exactCount: memberStats[uid].exactCount,
  tendencyCount: memberStats[uid].tendencyCount
}));

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

console.log('Writing standings to Firestore...');
await firestore.batchWrite(standingsWrites);
console.log('Simulation setup completed successfully!');
