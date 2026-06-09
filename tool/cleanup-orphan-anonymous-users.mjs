import fs from 'node:fs';

const projectId = 'voleo-sho2303';
const shouldDelete = process.argv.includes('--delete');
const firebaseToolsConfigPath = `${process.env.HOME}/.config/configstore/firebase-tools.json`;
const authExportPath = process.env.FIREBASE_AUTH_EXPORT ?? '/private/tmp/voleo-auth-users.json';
const firestoreBase = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
let accessToken;

async function getAccessToken() {
  if (accessToken) return accessToken;
  if (!fs.existsSync(firebaseToolsConfigPath)) {
    throw new Error('Firestore cleanup requires Firebase CLI login.');
  }
  const firebaseToolsConfig = JSON.parse(fs.readFileSync(firebaseToolsConfigPath, 'utf8'));
  const token = firebaseToolsConfig.tokens?.access_token;
  const expiresAt = firebaseToolsConfig.tokens?.expires_at ?? 0;
  if (!token || Date.now() > expiresAt) {
    throw new Error('Firebase CLI access token is missing or expired. Run `firebase login --reauth` or `firebase auth:export` first.');
  }
  accessToken = token;
  return accessToken;
}

function pathUrl(path) {
  return path.split('/').map(encodeURIComponent).join('/');
}

async function firestoreFetch(url, options = {}) {
  const token = await getAccessToken();
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(`Firestore REST failed: ${response.status} ${await response.text()}`);
  }
  return response.json();
}

async function getDocument(path) {
  return firestoreFetch(`${firestoreBase}/${pathUrl(path)}`);
}

async function runQuery({ parentPath, collectionId, fieldPath, op, value }) {
  const parent = parentPath ? `/${pathUrl(parentPath)}` : '';
  const result = await firestoreFetch(`${firestoreBase}${parent}:runQuery`, {
    method: 'POST',
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        where: {
          fieldFilter: {
            field: { fieldPath },
            op,
            value,
          },
        },
      },
    }),
  });
  return (result ?? []).map((row) => row.document).filter(Boolean);
}

async function commitWrites(writes) {
  if (!writes.length) return;
  await firestoreFetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
    {
      method: 'POST',
      body: JSON.stringify({ writes }),
    },
  );
}

function documentName(path) {
  return `projects/${projectId}/databases/(default)/documents/${path}`;
}

function docId(document) {
  return decodeURIComponent(document.name.split('/').at(-1));
}

function stringArrayField(document, field) {
  return document?.fields?.[field]?.arrayValue?.values?.map((value) => value.stringValue) ?? [];
}

function stringField(document, field) {
  return document?.fields?.[field]?.stringValue;
}

async function deleteAuthUser(uid) {
  const token = await getAccessToken();
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:delete`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ localId: uid }),
    },
  );
  if (!response.ok) {
    throw new Error(`Auth delete failed for ${uid}: ${response.status} ${await response.text()}`);
  }
}

if (!fs.existsSync(authExportPath)) {
  throw new Error(`Missing auth export at ${authExportPath}. Run: firebase auth:export ${authExportPath} --format=json --project ${projectId}`);
}
const users = JSON.parse(fs.readFileSync(authExportPath, 'utf8')).users ?? [];

const candidates = [];
for (const user of users) {
  if ((user.providerUserInfo ?? []).length > 0) continue;
  const uid = user.localId;
  const doc = await getDocument(`users/${uid}`);
  const providerIds = stringArrayField(doc, 'providerIds');
  if (doc && providerIds.length > 0) continue;
  candidates.push({
    uid,
    createdAt: user.createdAt ?? null,
    lastSignInAt: user.lastLoginAt ?? null,
    hasUserDoc: Boolean(doc),
    nickname: stringField(doc, 'nickname') ?? null,
  });
}

console.log(JSON.stringify({ delete: shouldDelete, count: candidates.length, candidates }, null, 2));

if (shouldDelete) {
  for (const candidate of candidates) {
    const leagues = await runQuery({
      collectionId: 'leagues',
      fieldPath: 'memberIds',
      op: 'ARRAY_CONTAINS',
      value: { stringValue: candidate.uid },
    });
    const writes = [];
    for (const league of leagues) {
      const leagueId = docId(league);
      writes.push({ delete: documentName(`leagues/${leagueId}/members/${candidate.uid}`) });
      writes.push({ delete: documentName(`leagues/${leagueId}/standings/${candidate.uid}`) });
      const tips = await runQuery({
        parentPath: `leagues/${leagueId}`,
        collectionId: 'tips',
        fieldPath: 'uid',
        op: 'EQUAL',
        value: { stringValue: candidate.uid },
      });
      for (const tip of tips) writes.push({ delete: tip.name });
      writes.push({
        transform: {
          document: documentName(`leagues/${leagueId}`),
          fieldTransforms: [
            {
              fieldPath: 'memberIds',
              removeAllFromArray: { values: [{ stringValue: candidate.uid }] },
            },
            {
              fieldPath: 'updatedAt',
              setToServerValue: 'REQUEST_TIME',
            },
          ],
        },
      });
    }
    writes.push({ delete: documentName(`users/${candidate.uid}`) });
    await commitWrites(writes);
    await deleteAuthUser(candidate.uid);
  }
}
