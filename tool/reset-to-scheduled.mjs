import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

// 1. Get access token from local firebase-tools config
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

function stringValue(v) { return { stringValue: v ?? '' }; }
function timestampValue(v) { return { timestampValue: v }; }
function nullableIntValue(v) { return v === null ? { nullValue: null } : { integerValue: String(v) }; }
function intValue(v) { return { integerValue: String(v) }; }

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
    winner: { nullValue: null },
    resultNote: { nullValue: null },
    source: stringValue('local-fallback'),
    updatedAt: timestampValue(new Date().toISOString()),
  };
}

async function run() {
  // 1. Reset matches
  const rawMatches = JSON.parse(fs.readFileSync('./tool/group_stage_matches.json', 'utf8'));
  const matchWrites = rawMatches.map(match => ({
    update: {
      name: `projects/${projectId}/databases/(default)/documents/matches/${match.id}`,
      fields: fieldsForMatch(match)
    }
  }));

  // Fetch current matches in Firestore to find any that should be deleted
  console.log('Fetching matches from Firestore...');
  const listMatchesRes = await fetch(`${baseUrl}/matches?pageSize=1000`, {
    headers: { authorization: `Bearer ${accessToken}` }
  });
  const listMatchesData = await listMatchesRes.json();
  const currentDocs = listMatchesData.documents ?? [];
  const keepIds = new Set(rawMatches.map(m => m.id));

  const deletes = [];
  for (const doc of currentDocs) {
    const id = doc.name.split('/').pop();
    if (!keepIds.has(id)) {
      deletes.push({ delete: doc.name });
    }
  }
  console.log(`Found ${deletes.length} matches in Firestore that need to be deleted.`);

  const allMatchWrites = [...matchWrites, ...deletes];
  console.log(`Resetting ${allMatchWrites.length} matches...`);
  for (let i = 0; i < allMatchWrites.length; i += 200) {
    const chunk = allMatchWrites.slice(i, i + 200);
    const response = await fetch(`${baseUrl}:batchWrite`, {
      method: 'POST',
      headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ writes: chunk }),
    });
    await response.json();
  }

  // 2. Fetch all leagues
  console.log('Fetching leagues...');
  const leaguesRes = await fetch(`${baseUrl}/leagues?pageSize=1000`, {
    headers: { authorization: `Bearer ${accessToken}` }
  });
  const leaguesData = await leaguesRes.json();
  const leagues = leaguesData.documents ?? [];

  for (const league of leagues) {
    const leagueId = league.name.split('/').pop();
    console.log(`Resetting league ${leagueId}...`);

    // Reset league tips to 0 points
    const tipsRes = await fetch(`${baseUrl}/leagues/${leagueId}/tips?pageSize=1000`, {
      headers: { authorization: `Bearer ${accessToken}` }
    });
    const tipsData = await tipsRes.json();
    const tips = tipsData.documents ?? [];
    const tipWrites = tips.map(tip => ({
      update: {
        name: tip.name,
        fields: {
          ...tip.fields,
          points: intValue(0)
        }
      },
      updateMask: { fieldPaths: ['points'] }
    }));

    if (tipWrites.length > 0) {
      console.log(`Resetting ${tipWrites.length} tips...`);
      for (let i = 0; i < tipWrites.length; i += 200) {
        await fetch(`${baseUrl}:batchWrite`, {
          method: 'POST',
          headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
          body: JSON.stringify({ writes: tipWrites.slice(i, i + 200) }),
        });
      }
    }

    // Reset standings to 0 points/exact/tendency, rank 1
    const standingsRes = await fetch(`${baseUrl}/leagues/${leagueId}/standings?pageSize=1000`, {
      headers: { authorization: `Bearer ${accessToken}` }
    });
    const standingsData = await standingsRes.json();
    const standings = standingsData.documents ?? [];
    const standingsWrites = standings.map(st => ({
      update: {
        name: st.name,
        fields: {
          ...st.fields,
          totalPoints: intValue(0),
          exactCount: intValue(0),
          tendencyCount: intValue(0),
          rank: intValue(1),
          updatedAt: timestampValue(new Date().toISOString())
        }
      }
    }));

    if (standingsWrites.length > 0) {
      console.log(`Resetting ${standingsWrites.length} standings...`);
      for (let i = 0; i < standingsWrites.length; i += 200) {
        await fetch(`${baseUrl}:batchWrite`, {
          method: 'POST',
          headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
          body: JSON.stringify({ writes: standingsWrites.slice(i, i + 200) }),
        });
      }
    }
  }

  console.log('Database reset to scheduled (production) state successfully!');
}

run().catch(console.error);
