import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

// 1. Get access token
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

async function run() {
  console.log('Fetching leagues...');
  const leaguesRes = await fetch(`${baseUrl}/leagues?pageSize=1000`, {
    headers: { authorization: `Bearer ${accessToken}` }
  });
  const leaguesData = await leaguesRes.json();
  const leagues = leaguesData.documents ?? [];

  for (const league of leagues) {
    const leagueId = league.name.split('/').pop();
    console.log(`Processing league: ${leagueId}...`);

    // 1. Delete members starting with mock-user-
    const membersRes = await fetch(`${baseUrl}/leagues/${leagueId}/members?pageSize=1000`, {
      headers: { authorization: `Bearer ${accessToken}` }
    });
    const membersData = await membersRes.json();
    const members = membersData.documents ?? [];
    
    const memberDeletes = [];
    for (const member of members) {
      const uid = member.name.split('/').pop();
      if (uid.startsWith('mock-user-')) {
        memberDeletes.push({ delete: member.name });
      }
    }

    if (memberDeletes.length > 0) {
      console.log(`Deleting ${memberDeletes.length} mock members in league ${leagueId}...`);
      await fetch(`${baseUrl}:batchWrite`, {
        method: 'POST',
        headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
        body: JSON.stringify({ writes: memberDeletes }),
      });
    }

    // 2. Delete standings starting with mock-user-
    const standingsRes = await fetch(`${baseUrl}/leagues/${leagueId}/standings?pageSize=1000`, {
      headers: { authorization: `Bearer ${accessToken}` }
    });
    const standingsData = await standingsRes.json();
    const standings = standingsData.documents ?? [];
    
    const standingDeletes = [];
    for (const st of standings) {
      const uid = st.name.split('/').pop();
      if (uid.startsWith('mock-user-')) {
        standingDeletes.push({ delete: st.name });
      }
    }

    if (standingDeletes.length > 0) {
      console.log(`Deleting ${standingDeletes.length} mock standings in league ${leagueId}...`);
      await fetch(`${baseUrl}:batchWrite`, {
        method: 'POST',
        headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
        body: JSON.stringify({ writes: standingDeletes }),
      });
    }

    // 3. Delete tips submitted by mock users
    const tipsRes = await fetch(`${baseUrl}/leagues/${leagueId}/tips?pageSize=1000`, {
      headers: { authorization: `Bearer ${accessToken}` }
    });
    const tipsData = await tipsRes.json();
    const tips = tipsData.documents ?? [];
    
    const tipDeletes = [];
    for (const tip of tips) {
      const uid = tip.fields.uid?.stringValue;
      if (uid && uid.startsWith('mock-user-')) {
        tipDeletes.push({ delete: tip.name });
      }
    }

    if (tipDeletes.length > 0) {
      console.log(`Deleting ${tipDeletes.length} mock tips in league ${leagueId}...`);
      for (let i = 0; i < tipDeletes.length; i += 200) {
        await fetch(`${baseUrl}:batchWrite`, {
          method: 'POST',
          headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
          body: JSON.stringify({ writes: tipDeletes.slice(i, i + 200) }),
        });
      }
    }
  }

  // 4. Delete mock user profiles from users collection
  console.log('Fetching users collection...');
  const usersRes = await fetch(`${baseUrl}/users?pageSize=1000`, {
    headers: { authorization: `Bearer ${accessToken}` }
  });
  const usersData = await usersRes.json();
  const users = usersData.documents ?? [];
  
  const userDeletes = [];
  for (const u of users) {
    const uid = u.name.split('/').pop();
    if (uid.startsWith('mock-user-')) {
      userDeletes.push({ delete: u.name });
    }
  }

  if (userDeletes.length > 0) {
    console.log(`Deleting ${userDeletes.length} mock user profile documents...`);
    for (let i = 0; i < userDeletes.length; i += 200) {
      await fetch(`${baseUrl}:batchWrite`, {
        method: 'POST',
        headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
        body: JSON.stringify({ writes: userDeletes.slice(i, i + 200) }),
      });
    }
  }

  console.log('Test users removed from all leagues and collections successfully!');
}

run().catch(console.error);
