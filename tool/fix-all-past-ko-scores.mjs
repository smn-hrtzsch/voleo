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
const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

class FirestoreRestClient {
  constructor(projectId, accessToken) {
    this.projectId = projectId;
    this.accessToken = accessToken;
    this.baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  }

  async listDocuments(...segments) {
    const url = `${this.baseUrl}/${segments.map(encodeURIComponent).join('/')}?pageSize=1000`;
    const response = await fetch(url, { headers: { authorization: `Bearer ${this.accessToken}` } });
    const data = await response.json();
    return data.documents ?? [];
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

const sfResultsMap = {
  'wc-ko-sf-1': { home: 'Mexiko', away: 'Uruguay', hs: 1, as: 1, winner: 'Mexiko', note: 'n.E.' },
  'wc-ko-sf-2': { home: 'Tschechien', away: 'Brasilien', hs: 0, as: 3, winner: 'Brasilien', note: '' },
  'wc-ko-sf-3': { home: 'Kanada', away: 'USA', hs: 2, as: 1, winner: 'Kanada', note: 'n.V.' },
  'wc-ko-sf-4': { home: 'Bosnien und Herzegowina', away: 'Australien', hs: 0, as: 1, winner: 'Australien', note: '' },
  'wc-ko-sf-5': { home: 'Deutschland', away: 'Belgien', hs: 2, as: 0, winner: 'Deutschland', note: '' },
  'wc-ko-sf-6': { home: 'Elfenbeinküste', away: 'Neuseeland', hs: 1, as: 2, winner: 'Neuseeland', note: '' },
  'wc-ko-sf-7': { home: 'Niederlande', away: 'Spanien', hs: 1, as: 2, winner: 'Spanien', note: '' },
  'wc-ko-sf-8': { home: 'Schweden', away: 'Saudi-Arabien', hs: 3, as: 0, winner: 'Schweden', note: '' },
  'wc-ko-sf-9': { home: 'Frankreich', away: 'Portugal', hs: 1, as: 1, winner: 'Portugal', note: 'n.E.' },
  'wc-ko-sf-10': { home: 'Senegal', away: 'Usbekistan', hs: 2, as: 0, winner: 'Senegal', note: '' },
  'wc-ko-sf-11': { home: 'Argentinien', away: 'England', hs: 2, as: 3, winner: 'England', note: 'n.V.' },
  'wc-ko-sf-12': { home: 'Österreich', away: 'Ghana', hs: 1, as: 0, winner: 'Österreich', note: '' },
  'wc-ko-sf-13': { home: 'Japan', away: 'Schottland', hs: 2, as: 1, winner: 'Japan', note: '' },
  'wc-ko-sf-14': { home: 'Haiti', away: 'Schweiz', hs: 0, as: 4, winner: 'Schweiz', note: '' },
  'wc-ko-sf-15': { home: 'Kolumbien', away: 'Ecuador', hs: 1, as: 2, winner: 'Ecuador', note: '' },
  'wc-ko-sf-16': { home: 'DR Kongo', away: 'Kroatien', hs: 0, as: 3, winner: 'Kroatien', note: '' }
};

async function run() {
  console.log('Fetching all matches from Firestore...');
  const matches = await firestore.listDocuments('matches');
  console.log(`Found ${matches.length} matches.`);

  const writes = [];
  for (const doc of matches) {
    const id = doc.name.split('/').pop();
    const f = doc.fields;
    
    // Only process KO matches that are finished (finalResult)
    if (!id.includes('-ko-') || f.status?.stringValue !== 'finalResult') {
      continue;
    }

    const homeTeam = f.homeTeam.stringValue;
    const awayTeam = f.awayTeam.stringValue;
    let winner = f.winner?.stringValue;
    let homeScore = parseInt(f.homeScore?.integerValue ?? '0');
    let awayScore = parseInt(f.awayScore?.integerValue ?? '0');
    let resultNote = f.resultNote?.stringValue ?? '';

    // Check if progression fields are missing
    if (f.regularHomeScore === undefined) {
      console.log(`Fixing progression scores for ${id} (${homeTeam} vs ${awayTeam})...`);

      const updatedFields = { ...f };

      // If it's in our Sechzehntelfinale map, use the predefined results
      if (sfResultsMap[id]) {
        const res = sfResultsMap[id];
        updatedFields.homeTeam = stringValue(res.home);
        updatedFields.awayTeam = stringValue(res.away);
        updatedFields.winner = stringValue(res.winner);
        updatedFields.resultNote = stringValue(res.note);

        if (res.note === 'n.E.') {
          updatedFields.regularHomeScore = intValue(res.hs);
          updatedFields.regularAwayScore = intValue(res.as);
          updatedFields.otHomeScore = intValue(res.hs);
          updatedFields.otAwayScore = intValue(res.as);
          const penHome = res.winner === res.home ? 5 : 4;
          const penAway = res.winner === res.away ? 5 : 4;
          updatedFields.penaltyHomeScore = intValue(penHome);
          updatedFields.penaltyAwayScore = intValue(penAway);
          updatedFields.homeScore = intValue(penHome);
          updatedFields.awayScore = intValue(penAway);
        } else if (res.note === 'n.V.') {
          const regScore = Math.min(res.hs, res.as);
          updatedFields.regularHomeScore = intValue(regScore);
          updatedFields.regularAwayScore = intValue(regScore);
          updatedFields.otHomeScore = intValue(res.hs);
          updatedFields.otAwayScore = intValue(res.as);
          updatedFields.homeScore = intValue(res.hs);
          updatedFields.awayScore = intValue(res.as);
        } else {
          updatedFields.regularHomeScore = intValue(res.hs);
          updatedFields.regularAwayScore = intValue(res.as);
          updatedFields.homeScore = intValue(res.hs);
          updatedFields.awayScore = intValue(res.as);
        }
      } else {
        // For Achtelfinale, Viertelfinale, etc.
        // If score is a draw (e.g. 0:0 or 1:1), it must have been a penalty shootout
        if (homeScore === awayScore) {
          resultNote = 'n.E.';
          updatedFields.resultNote = stringValue(resultNote);
          
          // Determine winner if winner is generic 'home'/'away'
          let resolvedWinner = winner;
          if (winner === 'home') resolvedWinner = homeTeam;
          if (winner === 'away') resolvedWinner = awayTeam;
          if (!resolvedWinner) resolvedWinner = homeTeam; // Fallback
          updatedFields.winner = stringValue(resolvedWinner);

          updatedFields.regularHomeScore = intValue(homeScore);
          updatedFields.regularAwayScore = intValue(awayScore);
          updatedFields.otHomeScore = intValue(homeScore);
          updatedFields.otAwayScore = intValue(awayScore);

          const penHome = resolvedWinner === homeTeam ? 5 : 4;
          const penAway = resolvedWinner === awayTeam ? 5 : 4;
          updatedFields.penaltyHomeScore = intValue(penHome);
          updatedFields.penaltyAwayScore = intValue(penAway);
          updatedFields.homeScore = intValue(penHome);
          updatedFields.awayScore = intValue(penAway);
        } else {
          // If different scores, check if winner is generic
          let resolvedWinner = winner;
          if (winner === 'home') resolvedWinner = homeTeam;
          if (winner === 'away') resolvedWinner = awayTeam;
          if (!resolvedWinner) resolvedWinner = homeScore > awayScore ? homeTeam : awayTeam;
          updatedFields.winner = stringValue(resolvedWinner);

          // If resultNote is empty, it was regular time
          if (!resultNote) {
            updatedFields.regularHomeScore = intValue(homeScore);
            updatedFields.regularAwayScore = intValue(awayScore);
          } else if (resultNote === 'n.V.') {
            // Overtime: regular time was a draw, e.g. if final is 2:1, regular was 1:1
            const regScore = Math.min(homeScore, awayScore);
            updatedFields.regularHomeScore = intValue(regScore);
            updatedFields.regularAwayScore = intValue(regScore);
            updatedFields.otHomeScore = intValue(homeScore);
            updatedFields.otAwayScore = intValue(awayScore);
          } else if (resultNote === 'n.E.') {
            // Penalties: regular and OT were draw, homeScore/awayScore are the penalty shootout score
            const regScore = 1; // Reconstruct as 1:1
            updatedFields.regularHomeScore = intValue(regScore);
            updatedFields.regularAwayScore = intValue(regScore);
            updatedFields.otHomeScore = intValue(regScore);
            updatedFields.otAwayScore = intValue(regScore);
            updatedFields.penaltyHomeScore = intValue(homeScore);
            updatedFields.penaltyAwayScore = intValue(awayScore);
          }
        }
      }

      updatedFields.updatedAt = timestampValue(new Date().toISOString());

      writes.push({
        update: {
          name: doc.name,
          fields: updatedFields
        }
      });
    }
  }

  if (writes.length > 0) {
    console.log(`Writing updates for ${writes.length} matches...`);
    await firestore.batchWrite(writes);
    console.log('Completed fixing past KO matches.');
  } else {
    console.log('No matches needed fixing.');
  }
}

run().catch(err => console.error(err));
