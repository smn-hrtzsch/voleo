import { createSign } from 'node:crypto';

const OPENLIGADB_URL = 'https://api.openligadb.de/getmatchdata/wm2026/2026';
const FIRESTORE_SCOPE = 'https://www.googleapis.com/auth/datastore';
const GROUP_BY_FIXTURE = new Map(
  [
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
  ].map(([group, home, away]) => [`${teamKey(home)}:${teamKey(away)}`, group]),
);
const args = new Set(process.argv.slice(2));
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const dryRun = args.has('--dry-run');
if (!dryRun && !serviceAccountJson) {
  throw new Error(
    'Missing FIREBASE_SERVICE_ACCOUNT_JSON. Configure the GitHub Actions secret or run with --dry-run.',
  );
}

const response = await fetch(OPENLIGADB_URL);
if (!response.ok) {
  throw new Error(`OpenLigaDB request failed with ${response.status}`);
}

const rawMatches = await response.json();
const groupMatches = rawMatches.map(normalizeMatch).filter(Boolean);

let matches = [...groupMatches];

if (dryRun) {
  const koPreview = getKnockoutMatches();
  matches = [...groupMatches, ...koPreview];
  console.log(JSON.stringify({ dryRun: true, matches: matches.length }, null, 2));
  console.log(JSON.stringify(matches.slice(0, 5), null, 2));
  process.exit(0);
}

const serviceAccount = JSON.parse(serviceAccountJson);
const accessToken = await createAccessToken(serviceAccount);
const firestore = new FirestoreRestClient(serviceAccount.project_id, accessToken);

// Get existing matches from Firestore to preserve scores/results of TBD/knockout matches
const existingMatchesDocs = await firestore.listDocuments('matches').catch(() => []);
const existingMatchMap = new Map();
for (const doc of existingMatchesDocs) {
  const id = doc.name.split('/').pop();
  const fields = doc.fields;
  if (fields) {
    const homeVal = fields.homeScore?.integerValue ?? fields.homeScore?.doubleValue;
    const awayVal = fields.awayScore?.integerValue ?? fields.awayScore?.doubleValue;
    existingMatchMap.set(id, {
      homeScore: homeVal != null ? parseInt(homeVal, 10) : null,
      awayScore: awayVal != null ? parseInt(awayVal, 10) : null,
      status: fields.status?.stringValue ?? 'scheduled',
    });
  }
}

// Merge generated knockout matches with existing scores
const koMatches = getKnockoutMatches().map((m) => {
  const existing = existingMatchMap.get(m.id);
  if (existing) {
    return {
      ...m,
      homeScore: existing.homeScore,
      awayScore: existing.awayScore,
      status: existing.status,
    };
  }
  return m;
});

matches = [...groupMatches, ...koMatches];

await firestore.batchWrite(
  matches.map((match) => ({
    update: firestore.document('matches', match.id, fieldsForMatch(match)),
  })),
);

await recalculateScores(
  firestore,
  matches,
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
    group: groupKey(match.group?.groupName) || groupForFixture(homeTeam, awayTeam),
    status: finalResult ? 'finalResult' : 'scheduled',
    homeScore: finalResult?.pointsTeam1 ?? null,
    awayScore: finalResult?.pointsTeam2 ?? null,
    source: 'openligadb',
    updatedAt: new Date().toISOString(),
  };
}

async function recalculateScores(firestore, allMatches, finalMatches) {
  if (finalMatches.length === 0) return;

  const finalMatchById = new Map(finalMatches.map((match) => [match.id, match]));
  const leagues = await firestore.listDocuments('leagues');

  for (const league of leagues) {
    const leagueId = idFromName(league.name);
    const members = await firestore.listDocuments('leagues', leagueId, 'members');
    // Fetch user documents for extra points and photoUrls
    const userFieldsMap = new Map();
    for (const member of members) {
      const uid = idFromName(member.name);
      try {
        const userDoc = await firestore.getDocument('users', uid);
        if (userDoc && userDoc.fields) {
          userFieldsMap.set(uid, userDoc.fields);
        }
      } catch (err) {
        console.error(`Failed to load user doc for ${uid}:`, err);
      }
    }

    const displayNames = new Map(
      members.map((member) => [
        idFromName(member.name),
        readString(member.fields.displayName) ?? 'Spieler',
      ]),
    );

    const photoUrls = new Map(
      members.map((member) => {
        const uid = idFromName(member.name);
        const userFields = userFieldsMap.get(uid);
        const userPhoto = userFields ? readString(userFields.photoUrl) : null;
        return [
          uid,
          userPhoto ?? readString(member.fields.photoUrl) ?? null,
        ];
      }),
    );

    const tips = await firestore.listDocuments('leagues', leagueId, 'tips');
    const stats = new Map();
    const writes = [];

    // Initialize stats map for all members so that if someone hasn't tipped they still get their extra points
    for (const member of members) {
      const uid = idFromName(member.name);
      const joinedAtRaw = member.fields?.joinedAt?.timestampValue;
      const joinedAt = joinedAtRaw ? new Date(joinedAtRaw) : new Date(0);
      const leftAtRaw = member.fields?.leftAt?.timestampValue;
      const leftAt = leftAtRaw ? new Date(leftAtRaw) : null;

      const frozenPoints = readInt(member.fields?.frozenPoints);
      const frozenExactCount = readInt(member.fields?.frozenExactCount);
      const frozenTendencyCount = readInt(member.fields?.frozenTendencyCount);

      stats.set(uid, {
        displayName: displayNames.get(uid) ?? 'Spieler',
        photoUrl: photoUrls.get(uid) ?? null,
        totalPoints: leftAt !== null ? frozenPoints : frozenPoints,
        exactCount: leftAt !== null ? frozenExactCount : frozenExactCount,
        tendencyCount: leftAt !== null ? frozenTendencyCount : frozenTendencyCount,
        joinedAt,
        leftAt,
      });
    }

    for (const tip of tips) {
      const tipData = tip.fields;
      const matchId = readString(tipData.matchId);
      const match = finalMatchById.get(matchId);
      if (!match) continue;

      const uid = readString(tipData.uid);
      const current = stats.get(uid);
      if (!current) continue;

      // Skip evaluation if the user is currently left
      if (current.leftAt !== null) {
        continue;
      }

      // Skip evaluation if the match started before the user joined
      const matchKickoff = new Date(match.kickoff);
      if (matchKickoff < current.joinedAt) {
        continue;
      }

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

      current.totalPoints += score.points;
      if (score.isExact) current.exactCount += 1;
      if (score.isTendency) current.tendencyCount += 1;
      stats.set(uid, current);
    }

    // Add extra points for each active user
    for (const [uid, current] of stats.entries()) {
      if (current.leftAt !== null) {
        continue;
      }
      const userFields = userFieldsMap.get(uid);
      const activeMatches = allMatches.filter((m) => new Date(m.kickoff) >= current.joinedAt);
      const extra = calculateExtraPoints(userFields, activeMatches);
      current.totalPoints += extra;
    }

    for (const [uid, standing] of rankStandings([...stats.entries()])) {
      writes.push({
        update: firestore.document('leagues', leagueId, 'standings', uid, {
          displayName: stringValue(standing.displayName),
          totalPoints: intValue(standing.totalPoints),
          exactCount: intValue(standing.exactCount),
          tendencyCount: intValue(standing.tendencyCount),
          rank: intValue(standing.rank),
          photoUrl: standing.photoUrl ? stringValue(standing.photoUrl) : { nullValue: null },
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
    group: stringValue(match.group),
    status: stringValue(match.status),
    homeScore: nullableIntValue(match.homeScore),
    awayScore: nullableIntValue(match.awayScore),
    source: stringValue(match.source),
    updatedAt: timestampValue(match.updatedAt),
  };
}

function groupKey(groupName) {
  if (!groupName) return '';
  const match = String(groupName).trim().match(/([A-L])$/);
  return match?.[1] ?? '';
}

function groupForFixture(homeTeam, awayTeam) {
  return GROUP_BY_FIXTURE.get(`${teamKey(homeTeam)}:${teamKey(awayTeam)}`) ?? '';
}

function teamKey(value) {
  return String(value)
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/&/g, 'und')
    .replace(/[^a-z0-9]/g, '');
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

function getTier(team) {
  const favorites = [
    'Argentinien',
    'Brasilien',
    'Deutschland',
    'England',
    'Frankreich',
    'Portugal',
    'Spanien'
  ];
  const tops = [
    'Belgien',
    'Japan',
    'Kroatien',
    'Marokko',
    'Niederlande',
    'Norwegen',
    'Schweiz',
    'Senegal',
    'Uruguay'
  ];
  const mids = [
    'Algerien',
    'Australien',
    'Bosnien und Herzegowina',
    'Bosnien-Herzegowina',
    'Bosnien Herzegowina',
    'Bosnia and Herzegovina',
    'Kolumbien',
    'Ecuador',
    'Elfenbeinküste',
    'Ghana',
    'Mexiko',
    'Österreich',
    'Schweden',
    'Südkorea',
    'Tschechien',
    'Türkei',
    'USA'
  ];
  if (favorites.includes(team)) return 'Absolute Titelfavoriten';
  if (tops.includes(team)) return 'Top Team';
  if (mids.includes(team)) return 'Durchschnittliches Team';
  return 'Gurkentruppe';
}

function getEliminationStage(team, allMatches) {
  const teamMatches = allMatches.filter(
    (m) => m.homeTeam === team || m.awayTeam === team
  );
  if (teamMatches.length === 0) return null;

  const knockouts = teamMatches.filter((m) => !m.stage.startsWith('Gruppe'));

  for (const m of knockouts) {
    if (
      m.status === 'finalResult' &&
      m.homeScore != null &&
      m.awayScore != null
    ) {
      const isHome = m.homeTeam === team;
      const won = isHome
          ? m.homeScore > m.awayScore
          : m.awayScore > m.homeScore;
      if (!won) {
        const stage = m.stage.toLowerCase();
        if (
          stage.includes('sechzehntel') ||
          stage.includes('achtel') ||
          stage.includes('32') ||
          stage.includes('16')
        ) {
          return 'Achtelfinale';
        }
        if (stage.includes('viertel') || stage.includes('quarter')) {
          return 'Viertelfinale';
        }
        if (stage.includes('halb') || stage.includes('semi')) {
          return 'Halbfinale';
        }
        if (stage.includes('final')) {
          return 'Finale';
        }
      }
    }
  }

  const hasWonFinal = knockouts.some(
    (m) =>
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

  const groupMatches = allMatches.filter((m) => m.stage.startsWith('Gruppe'));
  const allGroupsFinished =
    groupMatches.length > 0 && groupMatches.every((m) => m.status === 'finalResult');
  if (allGroupsFinished && knockouts.length === 0) {
    return 'Gruppenphase';
  }

  return null;
}

function calculateRiskPoints(team, predictedStage, actualStage) {
  const tier = getTier(team);
  const isCorrect = predictedStage === actualStage;

  if (tier === 'Absolute Titelfavoriten') {
    if (predictedStage === 'Gruppenphase') return isCorrect ? 70 : -70;
    if (predictedStage === 'Achtelfinale') return isCorrect ? 50 : -50;
    if (predictedStage === 'Viertelfinale') return isCorrect ? 30 : -30;
    if (predictedStage === 'Halbfinale') return isCorrect ? 15 : -15;
    if (predictedStage === 'Finale') return isCorrect ? 5 : -5;
  } else if (tier === 'Top Team') {
    if (predictedStage === 'Gruppenphase') return isCorrect ? 40 : -40;
    if (predictedStage === 'Achtelfinale') return isCorrect ? 20 : -20;
    if (predictedStage === 'Viertelfinale') return isCorrect ? 20 : -20;
    if (predictedStage === 'Halbfinale') return isCorrect ? 40 : -40;
    if (predictedStage === 'Finale') return isCorrect ? 50 : -50;
  } else if (tier === 'Durchschnittliches Team') {
    if (predictedStage === 'Gruppenphase') return isCorrect ? 5 : -5;
    if (predictedStage === 'Achtelfinale') return isCorrect ? 15 : -15;
    if (predictedStage === 'Viertelfinale') return isCorrect ? 35 : -35;
    if (predictedStage === 'Halbfinale') return isCorrect ? 55 : -55;
    if (predictedStage === 'Finale') return isCorrect ? 65 : -65;
  } else {
    // Gurkentruppe
    if (predictedStage === 'Gruppenphase') return isCorrect ? 5 : -5;
    if (predictedStage === 'Achtelfinale') return isCorrect ? 30 : -30;
    if (predictedStage === 'Viertelfinale') return isCorrect ? 50 : -50;
    if (predictedStage === 'Halbfinale') return isCorrect ? 65 : -65;
    if (predictedStage === 'Finale') return isCorrect ? 80 : -80;
  }
  return 0;
}

function calculateExtraPoints(userFields, allMatches) {
  let extraPoints = 0;
  if (!userFields) return 0;

  const fav = readString(userFields.favoriteTeam);
  if (fav) {
    for (const match of allMatches) {
      if (
        match.status === 'finalResult' &&
        match.homeScore != null &&
        match.awayScore != null
      ) {
        if (match.homeTeam === fav && match.homeScore > match.awayScore) {
          extraPoints += 10;
        } else if (
          match.awayTeam === fav &&
          match.awayScore > match.homeScore
        ) {
          extraPoints += 10;
        }
      }
    }
  }

  const championTipp = readString(userFields.predictedChampion);
  if (championTipp) {
    for (const match of allMatches) {
      if (
        match.status === 'finalResult' &&
        match.homeScore != null &&
        match.awayScore != null
      ) {
        if (
          match.homeTeam === championTipp &&
          match.homeScore > match.awayScore
        ) {
          extraPoints += 10;
        } else if (
          match.awayTeam === championTipp &&
          match.awayScore > match.homeScore
        ) {
          extraPoints += 10;
        }
      }
    }
  }

  const rTeam = readString(userFields.riskTeam);
  const rStage = readString(userFields.riskStage);
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

  // 1. Sechzehntelfinale (June 29 - July 3)
  const sfMatches = [
    ['Sieger Gruppe A', 'Zweiter Gruppe C', '2026-06-29T17:00:00Z'],
    ['Zweiter Gruppe A', 'Sieger Gruppe C', '2026-06-29T20:00:00Z'],
    ['Sieger Gruppe B', 'Zweiter Gruppe D', '2026-06-30T17:00:00Z'],
    ['Zweiter Gruppe B', 'Sieger Gruppe D', '2026-06-30T20:00:00Z'],
    ['Sieger Gruppe E', 'Zweiter Gruppe G', '2026-07-01T17:00:00Z'],
    ['Zweiter Gruppe E', 'Sieger Gruppe G', '2026-07-01T20:00:00Z'],
    ['Sieger Gruppe F', 'Zweiter Gruppe H', '2026-07-02T17:00:00Z'],
    ['Zweiter Gruppe F', 'Sieger Gruppe H', '2026-07-02T20:00:00Z'],
    ['Sieger Gruppe I', 'Zweiter Gruppe K', '2026-07-03T17:00:00Z'],
    ['Zweiter Gruppe I', 'Sieger Gruppe K', '2026-07-03T20:00:00Z'],
    ['Sieger Gruppe J', 'Zweiter Gruppe L', '2026-07-04T17:00:00Z'],
    ['Zweiter Gruppe J', 'Sieger Gruppe L', '2026-07-04T20:00:00Z'],
    ['Bester 3. Gruppe A/B/C', 'Sieger Gruppe H', '2026-07-05T17:00:00Z'],
    ['Bester 3. Gruppe D/E/F', 'Sieger Gruppe I', '2026-07-05T20:00:00Z'],
    ['Bester 3. Gruppe G/H/I', 'Sieger Gruppe J', '2026-07-06T17:00:00Z'],
    ['Bester 3. Gruppe J/K/L', 'Sieger Gruppe K', '2026-07-06T20:00:00Z'],
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
      source: 'openligadb',
      updatedAt: new Date().toISOString(),
    });
  }

  // 2. Achtelfinale (July 7 - July 10)
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
      source: 'openligadb',
      updatedAt: new Date().toISOString(),
    });
  }

  // 3. Viertelfinale (July 12 - July 13)
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
      source: 'openligadb',
      updatedAt: new Date().toISOString(),
    });
  }

  // 4. Halbfinale (July 15 - July 16)
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
      source: 'openligadb',
      updatedAt: new Date().toISOString(),
    });
  }

  // 5. Spiel um Platz 3 (July 18)
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
    source: 'openligadb',
    updatedAt: new Date().toISOString(),
  });

  // 6. Finale (July 19)
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
    source: 'openligadb',
    updatedAt: new Date().toISOString(),
  });

  return list;
}
