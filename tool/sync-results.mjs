import { createSign } from 'node:crypto';

const OPENLIGADB_URL = 'https://api.openligadb.de/getmatchdata/wm2026';
const FIRESTORE_SCOPE = 'https://www.googleapis.com/auth/datastore';
const args = new Set(process.argv.slice(2));
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const dryRun = args.has('--dry-run') || !serviceAccountJson;

const response = await fetch(OPENLIGADB_URL);
if (!response.ok) {
  throw new Error(`OpenLigaDB request failed with ${response.status}`);
}

const rawMatches = await response.json();
const matches = rawMatches.map(normalizeMatch).filter(Boolean);

if (dryRun) {
  console.log(JSON.stringify({ dryRun: true, matches: matches.length }, null, 2));
  console.log(JSON.stringify(matches.slice(0, 5), null, 2));
  process.exit(0);
}

const serviceAccount = JSON.parse(serviceAccountJson);
const accessToken = await createAccessToken(serviceAccount);
const firestore = new FirestoreRestClient(serviceAccount.project_id, accessToken);

await firestore.batchWrite(
  matches.map((match) => ({
    update: firestore.document('matches', match.id, fieldsForMatch(match)),
  })),
);

await recalculateScores(
  firestore,
  matches.filter((match) => match.status === 'finalResult'),
);

console.log(JSON.stringify({ dryRun: false, synced: matches.length }, null, 2));

function normalizeMatch(match) {
  const id = String(match.matchID ?? match.matchId ?? '');
  const homeTeam = match.team1?.teamName;
  const awayTeam = match.team2?.teamName;
  const kickoff = match.matchDateTimeUTC ?? match.matchDateTime;
  if (!id || !homeTeam || !awayTeam || !kickoff) return null;

  const finalResult = (match.matchResults ?? []).find((result) => {
    return result.resultTypeName === 'Endergebnis' || result.resultTypeID === 2;
  });

  return {
    id: `openligadb-${id}`,
    homeTeam,
    awayTeam,
    kickoff: new Date(kickoff).toISOString(),
    stage: match.group?.groupName ?? 'WM 2026',
    status: finalResult ? 'finalResult' : 'scheduled',
    homeScore: finalResult?.pointsTeam1 ?? null,
    awayScore: finalResult?.pointsTeam2 ?? null,
    source: 'openligadb',
    updatedAt: new Date().toISOString(),
  };
}

async function recalculateScores(firestore, finalMatches) {
  if (finalMatches.length === 0) return;

  const finalMatchById = new Map(finalMatches.map((match) => [match.id, match]));
  const leagues = await firestore.listDocuments('leagues');

  for (const league of leagues) {
    const leagueId = idFromName(league.name);
    const members = await firestore.listDocuments('leagues', leagueId, 'members');
    const displayNames = new Map(
      members.map((member) => [
        idFromName(member.name),
        readString(member.fields.displayName) ?? 'Spieler',
      ]),
    );
    const tips = await firestore.listDocuments('leagues', leagueId, 'tips');
    const stats = new Map();
    const writes = [];

    for (const tip of tips) {
      const tipData = tip.fields;
      const matchId = readString(tipData.matchId);
      const match = finalMatchById.get(matchId);
      if (!match) continue;

      const uid = readString(tipData.uid);
      const score = scoreTip(
        readInt(tipData.predictedHome),
        readInt(tipData.predictedAway),
        match.homeScore,
        match.awayScore,
      );

      writes.push({
        update: firestore.documentFromName(tip.name, {
          points: intValue(score.points),
        }),
        updateMask: { fieldPaths: ['points'] },
      });

      const current = stats.get(uid) ?? {
        displayName: displayNames.get(uid) ?? 'Spieler',
        totalPoints: 0,
        exactCount: 0,
        tendencyCount: 0,
      };
      current.totalPoints += score.points;
      if (score.isExact) current.exactCount += 1;
      if (score.isTendency) current.tendencyCount += 1;
      stats.set(uid, current);
    }

    for (const [uid, standing] of rankStandings([...stats.entries()])) {
      writes.push({
        update: firestore.document('leagues', leagueId, 'standings', uid, {
          displayName: stringValue(standing.displayName),
          totalPoints: intValue(standing.totalPoints),
          exactCount: intValue(standing.exactCount),
          tendencyCount: intValue(standing.tendencyCount),
          rank: intValue(standing.rank),
          updatedAt: timestampValue(new Date().toISOString()),
        }),
      });
    }

    await firestore.batchWrite(writes);
  }
}

function fieldsForMatch(match) {
  return {
    homeTeam: stringValue(match.homeTeam),
    awayTeam: stringValue(match.awayTeam),
    kickoff: timestampValue(match.kickoff),
    stage: stringValue(match.stage),
    status: stringValue(match.status),
    homeScore: nullableIntValue(match.homeScore),
    awayScore: nullableIntValue(match.awayScore),
    source: stringValue(match.source),
    updatedAt: timestampValue(match.updatedAt),
  };
}

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

function rankStandings(entries) {
  const sorted = entries.sort((a, b) => {
    const points = b[1].totalPoints - a[1].totalPoints;
    if (points !== 0) return points;
    const exact = b[1].exactCount - a[1].exactCount;
    if (exact !== 0) return exact;
    return a[1].displayName.localeCompare(b[1].displayName);
  });

  let rank = 0;
  let previous;
  return sorted.map(([uid, standing], index) => {
    const key = `${standing.totalPoints}:${standing.exactCount}`;
    if (key !== previous) {
      rank = index + 1;
      previous = key;
    }
    return [uid, { ...standing, rank }];
  });
}

async function createAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: FIRESTORE_SCOPE,
      aud: serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;
  const signature = createSign('RSA-SHA256')
    .update(unsigned)
    .sign(serviceAccount.private_key, 'base64url');

  const tokenResponse = await fetch(
    serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token',
    {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${unsigned}.${signature}`,
      }),
    },
  );

  if (!tokenResponse.ok) {
    throw new Error(`OAuth token request failed with ${tokenResponse.status}`);
  }
  return (await tokenResponse.json()).access_token;
}

class FirestoreRestClient {
  constructor(projectId, accessToken) {
    this.projectId = projectId;
    this.accessToken = accessToken;
    this.baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  }

  document(...segmentsAndFields) {
    const fields = segmentsAndFields.pop();
    return {
      name: `${this.baseUrl}/${segmentsAndFields.map(encodeURIComponent).join('/')}`,
      fields,
    };
  }

  documentFromName(name, fields) {
    return { name, fields };
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
      throw new Error(`Firestore batchWrite failed with ${response.status}`);
    }
  }
}

function idFromName(name) {
  return name.split('/').at(-1);
}

function readString(field) {
  return field?.stringValue;
}

function readInt(field) {
  return Number.parseInt(field?.integerValue ?? '0', 10);
}

function stringValue(value) {
  return { stringValue: value };
}

function intValue(value) {
  return { integerValue: String(value) };
}

function nullableIntValue(value) {
  return value == null ? { nullValue: null } : intValue(value);
}

function timestampValue(value) {
  return { timestampValue: value };
}

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}
