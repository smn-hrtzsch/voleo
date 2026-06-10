import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const refreshToken = config.tokens.refresh_token;

let accessToken = config.tokens.access_token;
const expiresAt = config.tokens.expires_at;

if (!accessToken || Date.now() >= expiresAt) {
  console.log('Refreshing access token...');
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    }),
  });
  const tokenData = await tokenResponse.json();
  accessToken = tokenData.access_token;
}

const projectId = 'voleo-sho2303';
const leagueId = 'VxekZ4yyTJRvsI1P3Wqy';
const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

class FirestoreRestClient {
  constructor(projectId, accessToken) {
    this.projectId = projectId;
    this.accessToken = accessToken;
    this.baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  }

  async getDocument(...segments) {
    const url = `${this.baseUrl}/${segments.map(encodeURIComponent).join('/')}`;
    const response = await fetch(url, { headers: { authorization: `Bearer ${this.accessToken}` } });
    if (response.status === 404) return null;
    return await response.json();
  }

  async listDocuments(...segments) {
    let all = [];
    let pageToken = "";
    const basePath = `${this.baseUrl}/${segments.map(encodeURIComponent).join('/')}`;
    do {
      const url = basePath + "?pageSize=1000" + (pageToken ? "&pageToken=" + pageToken : "");
      const response = await fetch(url, { headers: { authorization: `Bearer ${this.accessToken}` } });
      if (!response.ok) return all;
      const data = await response.json();
      if (data.documents) all = all.concat(data.documents);
      pageToken = data.nextPageToken || "";
    } while (pageToken);
    return all;
  }

  async batchWrite(writes) {
    if (writes.length === 0) return;
    const response = await fetch(`https://firestore.googleapis.com/v1/projects/${this.projectId}/databases/(default)/documents:batchWrite`, {
      method: 'POST',
      headers: { authorization: `Bearer ${this.accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ writes }),
    });
    if (!response.ok) {
      console.error('Batch failed:', await response.text());
    }
  }
}

const firestore = new FirestoreRestClient(projectId, accessToken);

function stringValue(value) { return { stringValue: value }; }
function intValue(value) { return { integerValue: String(value) }; }
function timestampValue(value) { return { timestampValue: value }; }

const uids = [
  'SKqNUlbDAhblyfAXpM8Sk1kf2Vt2', // Simon
  'mock-user-max',
  'mock-user-anna',
  'mock-user-felix',
  'mock-user-clara',
  'mock-user-jonas'
];

const mockTips = {
  'SKqNUlbDAhblyfAXpM8Sk1kf2Vt2': { hf1: [2, 1], hf2: [1, 1] },
  'mock-user-max': { hf1: [1, 2], hf2: [2, 2] },
  'mock-user-felix': { hf1: [1, 1], hf2: [0, 1] },
  'mock-user-clara': { hf1: [0, 0], hf2: [2, 0] },
  'mock-user-jonas': { hf1: [3, 2], hf2: [1, 1] },
  'mock-user-anna': { hf1: [1, 1], hf2: [1, 2] }
};

// Halbfinale match templates
const hfPairings = [
  { id: 'wc-ko-hf-1', h: 'Japan', a: 'Kanada', kickoff: '2026-07-15T19:00:00Z' },
  { id: 'wc-ko-hf-2', h: 'Jordanien', a: 'Irak', kickoff: '2026-07-16T19:00:00Z' }
];

function scoreTip(ph, pa, ah, aa) {
  if (ph === ah && pa === aa) return { points: 4, exact: true };
  const pd = ph - pa;
  const ad = ah - aa;
  if (pd === ad && ad !== 0) return { points: 3, exact: false };
  if (Math.sign(pd) === Math.sign(ad)) return { points: 2, exact: false };
  return { points: 0, exact: false };
}

async function run() {
  // 1. Set/Fix Halbfinale match dates and schedule them
  console.log('Scheduling Halbfinale matches with correct dates...');
  const hfWrites = hfPairings.map(p => ({
    update: {
      name: `projects/${projectId}/databases/(default)/documents/matches/${p.id}`,
      fields: {
        homeTeam: stringValue(p.h),
        awayTeam: stringValue(p.a),
        kickoff: timestampValue(p.kickoff),
        stage: stringValue('Halbfinale'),
        status: stringValue('scheduled'),
        source: stringValue('openligadb'),
        updatedAt: timestampValue(new Date().toISOString()),
      }
    }
  }));
  await firestore.batchWrite(hfWrites);

  // 2. Write tips for both matches for all users
  console.log('Writing tips for all users...');
  const tipWrites = [];
  for (const uid of uids) {
    const tips = mockTips[uid];
    if (tips) {
      tipWrites.push({
        update: {
          name: `projects/${projectId}/databases/(default)/documents/leagues/${leagueId}/tips/${uid}_wc-ko-hf-1`,
          fields: {
            uid: stringValue(uid),
            matchId: stringValue('wc-ko-hf-1'),
            predictedHome: intValue(tips.hf1[0]),
            predictedAway: intValue(tips.hf1[1]),
            lockedAt: timestampValue('2026-07-15T19:00:00Z'),
            points: intValue(0),
            updatedAt: timestampValue(new Date().toISOString())
          }
        }
      });
      tipWrites.push({
        update: {
          name: `projects/${projectId}/databases/(default)/documents/leagues/${leagueId}/tips/${uid}_wc-ko-hf-2`,
          fields: {
            uid: stringValue(uid),
            matchId: stringValue('wc-ko-hf-2'),
            predictedHome: intValue(tips.hf2[0]),
            predictedAway: intValue(tips.hf2[1]),
            lockedAt: timestampValue('2026-07-16T19:00:00Z'),
            points: intValue(0),
            updatedAt: timestampValue(new Date().toISOString())
          }
        }
      });
    }
  }
  await firestore.batchWrite(tipWrites);

  // 3. Simulate the Halbfinale match results with progression!
  console.log('Simulating Halbfinale match results...');
  
  // Halbfinale 1 (Japan vs Kanada): 1:1 (regular), 2:1 (OT)
  const hf1Result = {
    id: 'wc-ko-hf-1',
    status: 'finalResult',
    winner: 'Japan',
    resultNote: 'n.V.',
    homeScore: 2,
    awayScore: 1,
    regularHomeScore: 1,
    regularAwayScore: 1,
    otHomeScore: 2,
    otAwayScore: 1
  };

  // Halbfinale 2 (Jordanien vs Irak): 1:1 (regular), 1:1 (OT), 5:4 (Penalties)
  const hf2Result = {
    id: 'wc-ko-hf-2',
    status: 'finalResult',
    winner: 'Jordanien',
    resultNote: 'n.E.',
    homeScore: 5,
    awayScore: 4,
    regularHomeScore: 1,
    regularAwayScore: 1,
    otHomeScore: 1,
    otAwayScore: 1,
    penaltyHomeScore: 5,
    penaltyAwayScore: 4
  };

  const results = [hf1Result, hf2Result];
  const matchResultWrites = results.map(res => {
    const fields = {
      homeTeam: stringValue(res.id === 'wc-ko-hf-1' ? 'Japan' : 'Jordanien'),
      awayTeam: stringValue(res.id === 'wc-ko-hf-1' ? 'Kanada' : 'Irak'),
      kickoff: timestampValue(res.id === 'wc-ko-hf-1' ? '2026-07-15T19:00:00Z' : '2026-07-16T19:00:00Z'),
      stage: stringValue('Halbfinale'),
      status: stringValue(res.status),
      winner: stringValue(res.winner),
      resultNote: stringValue(res.resultNote),
      homeScore: intValue(res.homeScore),
      awayScore: intValue(res.awayScore),
      regularHomeScore: intValue(res.regularHomeScore),
      regularAwayScore: intValue(res.regularAwayScore),
      otHomeScore: intValue(res.otHomeScore),
      otAwayScore: intValue(res.otAwayScore),
      updatedAt: timestampValue(new Date().toISOString())
    };
    if (res.penaltyHomeScore !== undefined) {
      fields.penaltyHomeScore = intValue(res.penaltyHomeScore);
      fields.penaltyAwayScore = intValue(res.penaltyAwayScore);
    }
    return {
      update: {
        name: `projects/${projectId}/databases/(default)/documents/matches/${res.id}`,
        fields
      }
    };
  });
  await firestore.batchWrite(matchResultWrites);

  // 4. Recalculate everything to update points & standings
  console.log('Recalculating all league standings & points...');
  
  // Load matches
  const matches = await firestore.listDocuments('matches');
  const matchMap = new Map();
  for (const m of matches) {
    const id = m.name.split('/').pop();
    const f = m.fields;
    matchMap.set(id, {
      id,
      hs: f.homeScore?.integerValue ? parseInt(f.homeScore.integerValue) : null,
      as: f.awayScore?.integerValue ? parseInt(f.awayScore.integerValue) : null,
      regHs: f.regularHomeScore?.integerValue ? parseInt(f.regularHomeScore.integerValue) : null,
      regAs: f.regularAwayScore?.integerValue ? parseInt(f.regularAwayScore.integerValue) : null,
      status: f.status.stringValue,
      home: f.homeTeam.stringValue,
      away: f.awayTeam.stringValue,
      winner: f.winner?.stringValue,
      stage: f.stage?.stringValue || 'Gruppenphase',
      kickoff: f.kickoff.timestampValue
    });
  }

  // Load members
  const members = await firestore.listDocuments('leagues', leagueId, 'members');
  const userDocs = new Map();
  for (const uid of uids) {
    const doc = await firestore.getDocument('users', uid);
    if (doc && doc.fields) userDocs.set(uid, doc.fields);
  }

  // Load all tips
  const allTips = await firestore.listDocuments('leagues', leagueId, 'tips');
  const userStats = new Map();
  for (const uid of uids) userStats.set(uid, { points: 0, exact: 0, tendency: 0 });

  const updatedTips = [];
  for (const t of allTips) {
    const f = t.fields;
    const uid = f.uid.stringValue;
    const mid = f.matchId.stringValue;
    const match = matchMap.get(mid);
    if (!userStats.has(uid)) continue;

    let pts = 0;
    if (match && match.status === 'finalResult') {
      const ph = parseInt(f.predictedHome.integerValue);
      const pa = parseInt(f.predictedAway.integerValue);
      // scoring uses regular time score if available, falling back to homeScore/awayScore
      const ah = match.regHs !== null ? match.regHs : match.hs;
      const aa = match.regAs !== null ? match.regAs : match.as;

      if (ah !== null && aa !== null) {
        const score = scoreTip(ph, pa, ah, aa);
        pts = score.points;

        const stats = userStats.get(uid);
        stats.points += pts;
        if (score.exact) stats.exact += 1;
        if (pts >= 2) stats.tendency += 1;
      }
    }

    updatedTips.push({
      update: {
        name: t.name,
        fields: { ...f, points: intValue(pts), updatedAt: timestampValue(new Date().toISOString()) }
      }
    });
  }
  await firestore.batchWrite(updatedTips);

  // Add extra/booster points
  for (const [uid, stats] of userStats.entries()) {
    const uFields = userDocs.get(uid);
    if (!uFields) continue;
    const fav = uFields.favoriteTeam?.stringValue;
    const champ = uFields.predictedChampion?.stringValue;

    for (const m of matchMap.values()) {
      if (m.status === 'finalResult') {
        const winner = m.regHs > m.regAs ? m.home : (m.regAs > m.regHs ? m.away : m.winner);
        if (fav && winner === fav) stats.points += 10;
        if (champ && winner === champ) stats.points += 10;
      }
    }
  }

  // Rewrite standings with correct ranks
  const sorted = Array.from(userStats.entries()).sort((a, b) => b[1].points - a[1].points || b[1].exact - a[1].exact);
  
  // First, delete old standings to be sure
  const oldStandings = await firestore.listDocuments('leagues', leagueId, 'standings');
  if (oldStandings.length > 0) {
    const deleteWrites = oldStandings.map(s => ({ delete: s.name }));
    await firestore.batchWrite(deleteWrites);
  }

  const standingsWrites = [];
  for (let i = 0; i < sorted.length; i++) {
    const [uid, stats] = sorted[i];
    const uFields = userDocs.get(uid);
    standingsWrites.push({
      update: {
        name: `projects/${projectId}/databases/(default)/documents/leagues/${leagueId}/standings/${uid}`,
        fields: {
          displayName: stringValue(uFields?.nickname?.stringValue || "Spieler"),
          totalPoints: intValue(stats.points),
          exactCount: intValue(stats.exact),
          tendencyCount: intValue(stats.tendency),
          rank: intValue(i + 1),
          photoUrl: uFields?.photoUrl ? stringValue(uFields.photoUrl.stringValue) : { nullValue: null },
          updatedAt: timestampValue(new Date().toISOString())
        }
      }
    });
  }
  await firestore.batchWrite(standingsWrites);

  // Update league member stats
  const memberWrites = sorted.map(([uid, stats]) => {
    const uFields = userDocs.get(uid);
    return {
      update: {
        name: `projects/${projectId}/databases/(default)/documents/leagues/${leagueId}/members/${uid}`,
        fields: {
          displayName: stringValue(uFields?.nickname?.stringValue || "Spieler"),
          totalPoints: intValue(stats.points),
          exactCount: intValue(stats.exact),
          tendencyCount: intValue(stats.tendency),
          photoUrl: uFields?.photoUrl ? stringValue(uFields.photoUrl.stringValue) : { nullValue: null },
          role: stringValue(uid === "SKqNUlbDAhblyfAXpM8Sk1kf2Vt2" ? "owner" : "member"),
          joinedAt: timestampValue("2026-06-09T09:39:54Z"),
          updatedAt: timestampValue(new Date().toISOString())
        }
      }
    };
  });
  await firestore.batchWrite(memberWrites);

  console.log('Halbfinale matches simulated, tips evaluated and standings updated successfully!');
}

run().catch(err => console.error(err));
