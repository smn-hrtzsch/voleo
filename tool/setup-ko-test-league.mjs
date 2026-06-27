import { execFileSync } from 'node:child_process';

const projectId = 'voleo-sho2303';
const leagueId = 'ko-ui-test-simon';
const simonUid = 'SKqNUlbDAhblyfAXpM8Sk1kf2Vt2';
const expectedEmail = 'simon.hoertzsch@gmail.com';
const accessToken = execFileSync('gcloud', ['auth', 'print-access-token'], {
  encoding: 'utf8',
}).trim();
const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
const databaseName = `projects/${projectId}/databases/(default)/documents`;

const stringValue = (value) => ({ stringValue: value });
const intValue = (value) => ({ integerValue: String(value) });
const boolValue = (value) => ({ booleanValue: value });
const nullValue = () => ({ nullValue: null });
const timestampValue = (value) => ({ timestampValue: value });
const arrayValue = (values) => ({ arrayValue: { values } });

function documentName(...segments) {
  return `${databaseName}/${segments.map(encodeURIComponent).join('/')}`;
}

async function request(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      authorization: `Bearer ${accessToken}`,
      ...(options.body ? { 'content-type': 'application/json' } : {}),
      ...options.headers,
    },
  });
  if (!response.ok) {
    throw new Error(`${options.method ?? 'GET'} ${url} failed with ${response.status}: ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

async function getDocument(...segments) {
  const url = `${baseUrl}/${segments.map(encodeURIComponent).join('/')}`;
  const response = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(`GET ${url} failed with ${response.status}: ${await response.text()}`);
  }
  return response.json();
}

async function listDocuments(...segments) {
  const documents = [];
  let pageToken = null;
  do {
    const url = new URL(`${baseUrl}/${segments.map(encodeURIComponent).join('/')}`);
    url.searchParams.set('pageSize', '300');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const data = await request(url);
    documents.push(...(data.documents ?? []));
    pageToken = data.nextPageToken ?? null;
  } while (pageToken);
  return documents;
}

async function batchWrite(writes) {
  if (writes.length === 0) return;
  const data = await request(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:batchWrite`,
    { method: 'POST', body: JSON.stringify({ writes }) },
  );
  const failed = (data.status ?? []).filter((status) => status.code && status.code !== 0);
  if (failed.length > 0) {
    throw new Error(`Firestore batch contained failed writes: ${JSON.stringify(failed)}`);
  }
}

function updateWrite(segments, fields, fieldPaths = null, transforms = []) {
  return {
    update: { name: documentName(...segments), fields },
    ...(fieldPaths ? { updateMask: { fieldPaths } } : {}),
    ...(transforms.length > 0 ? { updateTransforms: transforms } : {}),
  };
}

function deleteWrite(name) {
  return { delete: name };
}

function nullableInt(value) {
  return value == null ? nullValue() : intValue(value);
}

function nullableString(value) {
  return value == null ? nullValue() : stringValue(value);
}

function isoOffset(now, { days = 0, minutes = 0 }) {
  return new Date(now.getTime() + days * 86_400_000 + minutes * 60_000).toISOString();
}

const now = new Date();
const nowIso = now.toISOString();
const joinedAt = isoOffset(now, { days: -10 });

const simonDoc = await getDocument('users', simonUid);
const simonEmail = simonDoc?.fields?.email?.stringValue;
const simonName = simonDoc?.fields?.nickname?.stringValue;
const previousActiveLeagueId = simonDoc?.fields?.activeLeagueId?.stringValue;
if (simonEmail !== expectedEmail || simonName !== 'Simon') {
  throw new Error(`Refusing to continue: expected Simon/${expectedEmail}, got ${simonName}/${simonEmail}.`);
}

const testUsers = [
  { uid: 'ko-test-anna', nickname: 'Anna Test' },
  { uid: 'ko-test-ben', nickname: 'Ben Test' },
  { uid: 'ko-test-charlotte', nickname: 'Charlotte Testspielerin' },
  { uid: 'ko-test-daniel', nickname: 'Daniel Test' },
];
const members = [{ uid: simonUid, nickname: 'Simon', role: 'owner' }, ...testUsers.map((user) => ({
  ...user,
  role: 'member',
}))];
const memberIds = members.map((member) => member.uid);

const matches = [
  {
    id: 'ko-test-final-90',
    homeTeam: 'Marokko',
    awayTeam: 'Norwegen',
    kickoff: isoOffset(now, { days: -3 }),
    stage: 'Achtelfinale',
    status: 'finalResult',
    homeScore: 2,
    awayScore: 0,
    regularHomeScore: 2,
    regularAwayScore: 0,
    winner: 'Marokko',
  },
  {
    id: 'ko-test-final-ot',
    homeTeam: 'Argentinien',
    awayTeam: 'Niederlande',
    kickoff: isoOffset(now, { days: -2 }),
    stage: 'Viertelfinale',
    status: 'finalResult',
    homeScore: 2,
    awayScore: 1,
    regularHomeScore: 1,
    regularAwayScore: 1,
    otHomeScore: 2,
    otAwayScore: 1,
    winner: 'Argentinien',
    resultNote: 'EXTRA_TIME',
  },
  {
    id: 'ko-test-final-penalties',
    homeTeam: 'Belgien',
    awayTeam: 'Kroatien',
    kickoff: isoOffset(now, { days: -1 }),
    stage: 'Halbfinale',
    status: 'finalResult',
    homeScore: 5,
    awayScore: 6,
    regularHomeScore: 0,
    regularAwayScore: 0,
    otHomeScore: 1,
    otAwayScore: 1,
    penaltyHomeScore: 4,
    penaltyAwayScore: 5,
    winner: 'Kroatien',
    resultNote: 'PENALTY_SHOOTOUT',
  },
  {
    id: 'ko-test-live',
    homeTeam: 'Japan',
    awayTeam: 'Südkorea',
    kickoff: isoOffset(now, { minutes: -30 }),
    stage: 'Halbfinale',
    status: 'live',
    homeScore: 1,
    awayScore: 1,
  },
  {
    id: 'ko-test-scheduled-incomplete',
    homeTeam: 'Deutschland',
    awayTeam: 'Frankreich',
    kickoff: isoOffset(now, { days: 1 }),
    stage: 'Finale',
    status: 'scheduled',
  },
  {
    id: 'ko-test-scheduled-long-names',
    homeTeam: 'Bosnien und Herzegowina',
    awayTeam: 'Elfenbeinküste',
    kickoff: isoOffset(now, { days: 2 }),
    stage: 'Finale',
    status: 'scheduled',
  },
];
const matchById = new Map(matches.map((match) => [match.id, match]));

const tips = [
  { uid: 'ko-test-anna', matchId: 'ko-test-scheduled-long-names', home: 1, away: 1, otHome: 2, otAway: 1 },
  { uid: 'ko-test-ben', matchId: 'ko-test-scheduled-long-names', home: 2, away: 0 },
  { uid: 'ko-test-charlotte', matchId: 'ko-test-scheduled-long-names', home: 0, away: 0, otHome: 1, otAway: 1, penaltyWinner: 'away' },
  { uid: 'ko-test-daniel', matchId: 'ko-test-scheduled-long-names', home: 0, away: 1 },
  { uid: simonUid, matchId: 'ko-test-scheduled-incomplete', home: 1, away: 1, otHome: 2, otAway: 2, isComplete: false },
  { uid: 'ko-test-anna', matchId: 'ko-test-scheduled-incomplete', home: 1, away: 1, otHome: 2, otAway: 1 },
  { uid: 'ko-test-ben', matchId: 'ko-test-scheduled-incomplete', home: 2, away: 1 },
  { uid: 'ko-test-charlotte', matchId: 'ko-test-scheduled-incomplete', home: 0, away: 0, otHome: 0, otAway: 0, penaltyWinner: 'home' },
  { uid: 'ko-test-daniel', matchId: 'ko-test-scheduled-incomplete', home: 1, away: 1, otHome: 1, otAway: 1, penaltyWinner: 'away' },
  { uid: simonUid, matchId: 'ko-test-live', home: 1, away: 1, otHome: 2, otAway: 1 },
  { uid: 'ko-test-anna', matchId: 'ko-test-live', home: 0, away: 0, otHome: 1, otAway: 1, penaltyWinner: 'home' },
  { uid: 'ko-test-ben', matchId: 'ko-test-live', home: 2, away: 1 },
  { uid: 'ko-test-charlotte', matchId: 'ko-test-live', home: 1, away: 1, otHome: 1, otAway: 1, penaltyWinner: 'away' },
  { uid: 'ko-test-daniel', matchId: 'ko-test-live', home: 0, away: 1 },
  { uid: simonUid, matchId: 'ko-test-final-90', home: 2, away: 0, points: 5, classification: 'exact' },
  { uid: 'ko-test-anna', matchId: 'ko-test-final-90', home: 3, away: 1, points: 4, classification: 'difference' },
  { uid: 'ko-test-ben', matchId: 'ko-test-final-90', home: 1, away: 0, points: 3, classification: 'tendency' },
  { uid: 'ko-test-charlotte', matchId: 'ko-test-final-90', home: 1, away: 1, otHome: 2, otAway: 1, points: 0 },
  { uid: 'ko-test-daniel', matchId: 'ko-test-final-90', home: 0, away: 1, points: 0 },
  { uid: simonUid, matchId: 'ko-test-final-ot', home: 1, away: 1, otHome: 2, otAway: 1, points: 5, classification: 'exact' },
  { uid: 'ko-test-anna', matchId: 'ko-test-final-ot', home: 0, away: 0, otHome: 1, otAway: 0, points: 3, classification: 'tendency' },
  { uid: 'ko-test-ben', matchId: 'ko-test-final-ot', home: 1, away: 1, otHome: 1, otAway: 2, points: 3, classification: 'tendency' },
  { uid: 'ko-test-charlotte', matchId: 'ko-test-final-ot', home: 1, away: 1, otHome: 2, otAway: 2, penaltyWinner: 'home', points: 3, classification: 'tendency' },
  { uid: 'ko-test-daniel', matchId: 'ko-test-final-ot', home: 0, away: 0, otHome: 2, otAway: 1, points: 4, classification: 'tendency' },
  { uid: simonUid, matchId: 'ko-test-final-penalties', home: 0, away: 0, otHome: 1, otAway: 1, penaltyWinner: 'away', points: 6, classification: 'exact' },
  { uid: 'ko-test-anna', matchId: 'ko-test-final-penalties', home: 1, away: 1, otHome: 2, otAway: 2, penaltyWinner: 'away', points: 4, classification: 'tendency' },
  { uid: 'ko-test-ben', matchId: 'ko-test-final-penalties', home: 0, away: 0, otHome: 1, otAway: 1, penaltyWinner: 'home', points: 5, classification: 'tendency' },
  { uid: 'ko-test-charlotte', matchId: 'ko-test-final-penalties', home: 1, away: 0, points: 0 },
  { uid: 'ko-test-daniel', matchId: 'ko-test-final-penalties', home: 0, away: 0, otHome: 1, otAway: 1, points: 0, isComplete: false },
].map((tip) => ({ isComplete: true, points: 0, ...tip }));

const standings = [
  { uid: simonUid, displayName: 'Simon', totalPoints: 16, exactCount: 3, differenceCount: 0, tendencyCount: 0, rank: 1 },
  { uid: 'ko-test-anna', displayName: 'Anna Test', totalPoints: 11, exactCount: 0, differenceCount: 1, tendencyCount: 2, rank: 2 },
  { uid: 'ko-test-ben', displayName: 'Ben Test', totalPoints: 11, exactCount: 0, differenceCount: 0, tendencyCount: 3, rank: 3 },
  { uid: 'ko-test-daniel', displayName: 'Daniel Test', totalPoints: 4, exactCount: 0, differenceCount: 0, tendencyCount: 1, rank: 4 },
  { uid: 'ko-test-charlotte', displayName: 'Charlotte Testspielerin', totalPoints: 3, exactCount: 0, differenceCount: 0, tendencyCount: 1, rank: 5 },
];

const writes = [];
writes.push(updateWrite(['leagues', leagueId], {
  name: stringValue('K.O.-UI Testliga'),
  inviteCode: stringValue('KOTEST'),
  inviteCodeMigrated: boolValue(true),
  ownerUid: stringValue(simonUid),
  memberIds: arrayValue(memberIds.map(stringValue)),
  scoringPreset: stringValue('knockout-test'),
  isTestLeague: boolValue(true),
  previousActiveLeagueId: nullableString(previousActiveLeagueId),
  createdAt: timestampValue(nowIso),
  updatedAt: timestampValue(nowIso),
}));

writes.push(updateWrite(
  ['users', simonUid],
  {
    activeLeagueId: stringValue(leagueId),
    updatedAt: timestampValue(nowIso),
  },
  ['activeLeagueId', 'updatedAt'],
  [{
    fieldPath: 'leagueIds',
    appendMissingElements: { values: [stringValue(leagueId)] },
  }],
));

for (const member of members) {
  writes.push(updateWrite(['leagues', leagueId, 'members', member.uid], {
    uid: stringValue(member.uid),
    role: stringValue(member.role),
    displayName: stringValue(member.nickname),
    totalPoints: intValue(0),
    exactCount: intValue(0),
    differenceCount: intValue(0),
    tendencyCount: intValue(0),
    frozenPoints: intValue(0),
    frozenExactCount: intValue(0),
    frozenDifferenceCount: intValue(0),
    frozenTendencyCount: intValue(0),
    joinedAt: timestampValue(joinedAt),
    leftAt: nullValue(),
    updatedAt: timestampValue(nowIso),
  }));
}

for (const match of matches) {
  writes.push(updateWrite(['leagues', leagueId, 'testMatches', match.id], {
    homeTeam: stringValue(match.homeTeam),
    awayTeam: stringValue(match.awayTeam),
    kickoff: timestampValue(match.kickoff),
    stage: stringValue(match.stage),
    group: stringValue(''),
    status: stringValue(match.status),
    homeScore: nullableInt(match.homeScore),
    awayScore: nullableInt(match.awayScore),
    regularHomeScore: nullableInt(match.regularHomeScore),
    regularAwayScore: nullableInt(match.regularAwayScore),
    otHomeScore: nullableInt(match.otHomeScore),
    otAwayScore: nullableInt(match.otAwayScore),
    penaltyHomeScore: nullableInt(match.penaltyHomeScore),
    penaltyAwayScore: nullableInt(match.penaltyAwayScore),
    winner: nullableString(match.winner),
    resultNote: nullableString(match.resultNote),
    source: stringValue('test-simulation'),
    isTestMatch: boolValue(true),
    updatedAt: timestampValue(nowIso),
  }));
}

for (const tip of tips) {
  const match = matchById.get(tip.matchId);
  writes.push(updateWrite(['leagues', leagueId, 'tips', `${tip.uid}_${tip.matchId}`], {
    uid: stringValue(tip.uid),
    matchId: stringValue(tip.matchId),
    predictedHome: intValue(tip.home),
    predictedAway: intValue(tip.away),
    predictedOtHome: nullableInt(tip.otHome),
    predictedOtAway: nullableInt(tip.otAway),
    predictedPenaltyWinner: nullableString(tip.penaltyWinner),
    isComplete: boolValue(tip.isComplete),
    lockedAt: timestampValue(match.kickoff),
    points: intValue(tip.points),
    updatedAt: timestampValue(nowIso),
  }));
}

for (const standing of standings) {
  writes.push(updateWrite(['leagues', leagueId, 'standings', standing.uid], {
    displayName: stringValue(standing.displayName),
    totalPoints: intValue(standing.totalPoints),
    exactCount: intValue(standing.exactCount),
    differenceCount: intValue(standing.differenceCount),
    tendencyCount: intValue(standing.tendencyCount),
    rank: intValue(standing.rank),
    updatedAt: timestampValue(nowIso),
  }));
}

const expectedNames = new Set(writes.map((write) => write.update?.name).filter(Boolean));
for (const collection of ['members', 'testMatches', 'tips', 'standings']) {
  for (const document of await listDocuments('leagues', leagueId, collection)) {
    if (!expectedNames.has(document.name)) writes.push(deleteWrite(document.name));
  }
}

await batchWrite(writes);

console.log(JSON.stringify({
  ok: true,
  leagueId,
  leagueName: 'K.O.-UI Testliga',
  previousActiveLeagueId,
  memberCount: members.length,
  matchCount: matches.length,
  tipCount: tips.length,
  finalMatches: matches.filter((match) => match.status === 'finalResult').length,
  liveMatches: matches.filter((match) => match.status === 'live').length,
  scheduledMatches: matches.filter((match) => match.status === 'scheduled').length,
}, null, 2));
