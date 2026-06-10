import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const refreshToken = config.tokens.refresh_token;

let accessToken = config.tokens.access_token;
const expiresAt = config.tokens.expires_at;

if (!accessToken || Date.now() >= expiresAt) {
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
const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

async function getDoc(path) {
  const url = `${baseUrl}/${path}`;
  const response = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (response.status === 404) return null;
  return await response.json();
}

async function listDocs(path) {
  const url = `${baseUrl}/${path}`;
  const response = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (response.status === 404) return [];
  const data = await response.json();
  return data.documents ?? [];
}

const userDoc = await getDoc('users/SKqNUlbDAhblyfAXpM8Sk1kf2Vt2');
console.log('User Simon:', JSON.stringify(userDoc?.fields, null, 2));

const leagues = await listDocs('leagues');
console.log('Leagues count:', leagues.length);
for (const l of leagues) {
  console.log(`- League: ${l.name.split('/').pop()}, name: ${l.fields.name?.stringValue}, invite: ${l.fields.inviteCode?.stringValue}`);
}

const match = await getDoc('matches/wc-ko-sf-1');
console.log('Match wc-ko-sf-1:', JSON.stringify(match?.fields, null, 2));
