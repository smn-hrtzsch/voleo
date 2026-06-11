import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';

// 1. Get access token from CLI or argument
let accessToken = process.argv[2];
if (!accessToken) {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(configPath)) {
    console.error('Error: Could not find firebase-tools.json config file. Please run "firebase login" first.');
    process.exit(1);
  }
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const refreshToken = config.tokens?.refresh_token;
  accessToken = config.tokens?.access_token;
  const expiresAt = config.tokens?.expires_at;

  if (!refreshToken) {
    console.error('Error: No refresh token found in firebase-tools.json. Please run "firebase login" first.');
    process.exit(1);
  }

  if (!accessToken || Date.now() >= expiresAt) {
    console.log('Access token expired. Refreshing token...');
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
}

const projectId = 'voleo-sho2303';

class FirestoreRestClient {
  constructor(projectId, accessToken) {
    this.projectId = projectId;
    this.accessToken = accessToken;
    this.baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  }

  document(collection, ...segments) {
    const fields = segments.pop();
    const docPath = `projects/${this.projectId}/databases/(default)/documents/${collection}/${segments.join('/')}`;
    return { name: docPath, fields };
  }

  documentFromName(name, fields) {
    return { name, fields };
  }

  async getDocument(...segments) {
    const url = `${this.baseUrl}/${segments.map(encodeURIComponent).join('/')}`;
    const response = await fetch(url, { headers: { authorization: `Bearer ${this.accessToken}` } });
    if (response.status === 404) return null;
    return await response.json();
  }

  async listDocuments(...segments) {
    let all = [];
    let pageToken = '';
    const basePath = `${this.baseUrl}/${segments.map(encodeURIComponent).join('/')}`;
    do {
      const url = basePath + (pageToken ? '?pageToken=' + pageToken : '');
      const response = await fetch(url, { headers: { authorization: `Bearer ${this.accessToken}` } });
      if (!response.ok) return all;
      const data = await response.json();
      if (data.documents) all = all.concat(data.documents);
      pageToken = data.nextPageToken || '';
    } while (pageToken);
    return all;
  }

  async patchDocument(docPath, fields) {
    const url = `${this.baseUrl}/${docPath}`;
    const response = await fetch(url + '?updateMask.fieldPaths=homeScore&updateMask.fieldPaths=awayScore&updateMask.fieldPaths=regularHomeScore&updateMask.fieldPaths=regularAwayScore&updateMask.fieldPaths=status&updateMask.fieldPaths=winner&updateMask.fieldPaths=updatedAt', {
      method: 'PATCH',
      headers: {
        authorization: `Bearer ${this.accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ fields }),
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Firestore patch failed: ${text}`);
    }
  }

  async batchWrite(writes) {
    if (writes.length === 0) return;
    const response = await fetch(`https://firestore.googleapis.com/v1/projects/${this.projectId}/databases/(default)/documents:batchWrite`, {
      method: 'POST',
      headers: { authorization: `Bearer ${this.accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ writes }),
    });
    if (!response.ok) {
      const err = await response.text();
      console.error('batchWrite failed:', err);
    }
  }
}

const firestore = new FirestoreRestClient(projectId, accessToken);

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

function scoreTip(predictedHome, predictedAway, actualHome, actualAway) {
  if (predictedHome === actualHome && predictedAway === actualAway) {
    return { points: 4, isExact: true, isTendency: true };
  }
  const predictedDiff = predictedHome - predictedAway;
  const actualDiff = actualHome - actualAway;
  if (predictedDiff === actualDiff && actualDiff !== 0) {
    return { points: 3, isExact: false, isTendency: true };
  }
  if (Math.sign(predictedDiff) === Math.sign(actualDiff)) {
    return { points: 2, isExact: false, isTendency: true };
  }
  return { points: 0, isExact: false, isTendency: false };
}

function getTier(team) {
  const favorites = ['Argentinien', 'Brasilien', 'Deutschland', 'England', 'Frankreich', 'Portugal', 'Spanien'];
  const tops = ['Belgien', 'Japan', 'Kroatien', 'Marokko', 'Niederlande', 'Norwegen', 'Schweiz', 'Senegal', 'Uruguay'];
  const mids = [
    'Algerien', 'Australien', 'Bosnien und Herzegowina', 'Bosnien-Herzegowina', 'Bosnien Herzegowina', 'Bosnia and Herzegovina',
    'Kolumbien', 'Ecuador', 'Elfenbeinküste', 'Ghana', 'Mexiko', 'Österreich', 'Schweden', 'Südkorea', 'Tschechien', 'Türkei', 'USA'
  ];
  if (favorites.includes(team)) return 'Absolute Titelfavoriten';
  if (tops.includes(team)) return 'Top Team';
  if (mids.includes(team)) return 'Durchschnittliches Team';
  return 'Gurkentruppe';
}

function getMatchWinner(match) {
  if (match.winner) return match.winner;
  if (match.status !== 'finalResult' || match.homeScore == null || match.awayScore == null) {
    return null;
  }
  if (match.homeScore > match.awayScore) return match.homeTeam;
  if (match.awayScore > match.homeScore) return match.awayTeam;
  return null;
}

function getEliminationStage(team, allMatches) {
  const teamMatches = allMatches.filter(
    (m) => m.homeTeam === team || m.awayTeam === team
  );
  if (teamMatches.length === 0) return null;

  const knockouts = teamMatches.filter((m) => !m.stage.startsWith('Gruppe') && !m.stage.includes('Runde'));

  for (const m of knockouts) {
    if (m.status === 'finalResult') {
      const winner = getMatchWinner(m);
      if (winner && winner !== team) {
        const stage = m.stage.toLowerCase();
        if (stage.includes('sechzehntelfinale') || stage.includes('32')) {
          return 'Sechzehntelfinale';
        }
        if (stage.includes('achtel') || stage.includes('16')) {
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
      getMatchWinner(m) === team
  );
  if (hasWonFinal) return 'Champion';

  const groupMatches = allMatches.filter((m) => m.stage.startsWith('Gruppe') || m.stage.includes('Runde'));
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
      if (match.status === 'finalResult') {
        if (getMatchWinner(match) === fav) {
          extraPoints += 10;
        }
      }
    }
  }

  const championTipp = readString(userFields.predictedChampion);
  if (championTipp) {
    for (const match of allMatches) {
      if (match.status === 'finalResult') {
        if (getMatchWinner(match) === championTipp) {
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

// Points recalculation function for all leagues
async function recalculateAllScores() {
  console.log('\nStarte Punkteberechnung für alle Ligen...');
  const allMatchesDocs = await firestore.listDocuments('matches');
  const allMatches = allMatchesDocs.map(doc => {
    const fields = doc.fields;
    return {
      id: idFromName(doc.name),
      homeTeam: readString(fields.homeTeam),
      awayTeam: readString(fields.awayTeam),
      homeScore: fields.homeScore ? readInt(fields.homeScore) : null,
      awayScore: fields.awayScore ? readInt(fields.awayScore) : null,
      regularHomeScore: fields.regularHomeScore ? readInt(fields.regularHomeScore) : null,
      regularAwayScore: fields.regularAwayScore ? readInt(fields.regularAwayScore) : null,
      status: readString(fields.status),
      stage: readString(fields.stage),
      winner: readString(fields.winner),
      kickoff: fields.kickoff?.timestampValue,
    };
  });

  const finalMatches = allMatches.filter(m => m.status === 'finalResult');
  const finalMatchById = new Map(finalMatches.map((m) => [m.id, m]));
  const leagues = await firestore.listDocuments('leagues');

  for (const league of leagues) {
    const leagueId = idFromName(league.name);
    console.log(`Berechne Liga: ${readString(league.fields.name) ?? leagueId}...`);
    const members = await firestore.listDocuments('leagues', leagueId, 'members');
    
    // Fetch user documents for extra points
    const userFieldsMap = new Map();
    for (const member of members) {
      const uid = idFromName(member.name);
      try {
        const userDoc = await firestore.getDocument('users', uid);
        if (userDoc && userDoc.fields) {
          userFieldsMap.set(uid, userDoc.fields);
        }
      } catch (err) {
        console.error(`Fehler beim Laden von User ${uid}:`, err);
      }
    }

    const displayNames = new Map(
      members.map((m) => [idFromName(m.name), readString(m.fields.displayName) ?? 'Spieler'])
    );

    const photoUrls = new Map(
      members.map((m) => {
        const uid = idFromName(m.name);
        const userFields = userFieldsMap.get(uid);
        const userPhoto = userFields ? readString(userFields.photoUrl) : null;
        return [uid, userPhoto ?? readString(m.fields.photoUrl) ?? null];
      })
    );

    const tips = await firestore.listDocuments('leagues', leagueId, 'tips');
    const stats = new Map();
    const writes = [];

    // Initialize stats
    for (const member of members) {
      const uid = idFromName(member.name);
      const joinedAtRaw = member.fields?.joinedAt?.timestampValue;
      const joinedAt = joinedAtRaw ? new Date(joinedAtRaw) : new Date(0);
      const leftAtRaw = member.fields?.leftAt?.timestampValue;
      const leftAt = leftAtRaw ? new Date(leftAtRaw) : null;

      const frozenPoints = member.fields?.frozenPoints ? readInt(member.fields.frozenPoints) : 0;
      const frozenExactCount = member.fields?.frozenExactCount ? readInt(member.fields.frozenExactCount) : 0;
      const frozenTendencyCount = member.fields?.frozenTendencyCount ? readInt(member.fields.frozenTendencyCount) : 0;

      stats.set(uid, {
        displayName: displayNames.get(uid) ?? 'Spieler',
        photoUrl: photoUrls.get(uid) ?? null,
        totalPoints: frozenPoints,
        exactCount: frozenExactCount,
        tendencyCount: frozenTendencyCount,
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
      if (!current || current.leftAt !== null) continue;

      const matchKickoff = new Date(match.kickoff);
      if (matchKickoff < current.joinedAt) continue;

      const actualHome = match.regularHomeScore !== null ? match.regularHomeScore : match.homeScore;
      const actualAway = match.regularAwayScore !== null ? match.regularAwayScore : match.awayScore;

      const score = scoreTip(
        readInt(tipData.predictedHome),
        readInt(tipData.predictedAway),
        actualHome,
        actualAway
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

    // Add extra points for active users
    for (const [uid, current] of stats.entries()) {
      if (current.leftAt !== null) continue;
      const userFields = userFieldsMap.get(uid);
      const activeMatches = allMatches.filter((m) => new Date(m.kickoff) >= current.joinedAt);
      const extra = calculateExtraPoints(userFields, activeMatches);
      current.totalPoints += extra;
    }

    // Generate update writes for member list & standings
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
      writes.push({
        update: firestore.document('leagues', leagueId, 'members', uid, {
          totalPoints: intValue(standing.totalPoints),
          exactCount: intValue(standing.exactCount),
          tendencyCount: intValue(standing.tendencyCount),
          updatedAt: timestampValue(new Date().toISOString()),
        }),
        updateMask: { fieldPaths: ['totalPoints', 'exactCount', 'tendencyCount', 'updatedAt'] }
      });
    }

    await firestore.batchWrite(writes);
  }
  console.log('Punkteberechnung abgeschlossen!');
}

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});
const ask = (query) => new Promise((resolve) => rl.question(query, resolve));

async function main() {
  try {
    console.log('Lade Spiele aus Firestore...');
    const allMatchesDocs = await firestore.listDocuments('matches');
    
    const matches = allMatchesDocs.map(doc => {
      const f = doc.fields;
      return {
        id: idFromName(doc.name),
        homeTeam: readString(f.homeTeam),
        awayTeam: readString(f.awayTeam),
        kickoff: new Date(f.kickoff.timestampValue),
        status: readString(f.status),
        stage: readString(f.stage),
      };
    }).sort((a, b) => a.kickoff - b.kickoff);

    // Filter to live, scheduled, or very recently completed matches (last 24 hours)
    const now = new Date();
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const activeMatches = matches.filter(m => 
      m.status === 'live' || 
      m.status === 'scheduled' || 
      (m.status === 'finalResult' && m.kickoff >= oneDayAgo)
    );

    if (activeMatches.length === 0) {
      console.log('Keine aktiven, anstehenden oder kürzlich beendeten Spiele gefunden.');
      rl.close();
      return;
    }

    console.log('\nVerfügbare Spiele:');
    activeMatches.forEach((m, index) => {
      const kickoffStr = m.kickoff.toLocaleString('de-DE', { timeZone: 'Europe/Berlin' });
      console.log(`[${index + 1}] ${m.homeTeam} - ${m.awayTeam} (${m.stage}, ${kickoffStr}) [Status: ${m.status}]`);
    });

    const choice = await ask('\nWähle ein Spiel (Nummer eingeben): ');
    const matchIndex = parseInt(choice, 10) - 1;
    if (isNaN(matchIndex) || matchIndex < 0 || matchIndex >= activeMatches.length) {
      console.error('Ungültige Auswahl.');
      rl.close();
      return;
    }

    const selectedMatch = activeMatches[matchIndex];
    console.log(`\nAusgewähltes Spiel: ${selectedMatch.homeTeam} - ${selectedMatch.awayTeam}`);

    const homeScoreStr = await ask(`Tore für ${selectedMatch.homeTeam}: `);
    const homeScore = parseInt(homeScoreStr, 10);
    const awayScoreStr = await ask(`Tore für ${selectedMatch.awayTeam}: `);
    const awayScore = parseInt(awayScoreStr, 10);

    if (isNaN(homeScore) || isNaN(awayScore)) {
      console.error('Ungültige Toreingabe.');
      rl.close();
      return;
    }

    let winner = null;
    const isKoPhase = !selectedMatch.stage.startsWith('Gruppe') && !selectedMatch.stage.includes('Runde');
    if (isKoPhase) {
      if (homeScore === awayScore) {
        console.log(`\nK.O.-Phase erkannt und reguläres Unentschieden.`);
        console.log(`1) ${selectedMatch.homeTeam}`);
        console.log(`2) ${selectedMatch.awayTeam}`);
        const winnerChoice = await ask('Wer kam weiter/hat im Elfmeterschießen gewonnen? (1 oder 2): ');
        if (winnerChoice === '1') winner = selectedMatch.homeTeam;
        else if (winnerChoice === '2') winner = selectedMatch.awayTeam;
        else {
          console.error('Ungültige Auswahl.');
          rl.close();
          return;
        }
      } else {
        winner = homeScore > awayScore ? selectedMatch.homeTeam : selectedMatch.awayTeam;
      }
    }

    console.log('\nZusammenfassung der Änderung:');
    console.log(`Spiel ID: ${selectedMatch.id}`);
    console.log(`Ergebnis: ${homeScore} : ${awayScore}`);
    if (winner) console.log(`Sieger: ${winner}`);

    const confirm = await ask('\nMöchtest du dieses Ergebnis speichern und die Punkte berechnen? (ja/nein): ');
    if (confirm.toLowerCase() !== 'ja' && confirm.toLowerCase() !== 'j') {
      console.log('Abgebrochen.');
      rl.close();
      return;
    }

    const fields = {
      status: stringValue('finalResult'),
      homeScore: intValue(homeScore),
      awayScore: intValue(awayScore),
      regularHomeScore: intValue(homeScore),
      regularAwayScore: intValue(awayScore),
      winner: winner ? stringValue(winner) : { nullValue: null },
      updatedAt: timestampValue(new Date().toISOString()),
    };

    console.log('\nSchreibe Ergebnis in die Firestore-Datenbank...');
    await firestore.patchDocument(`matches/${selectedMatch.id}`, fields);
    console.log('Spielergebnis erfolgreich aktualisiert!');

    await recalculateAllScores();

    console.log('\nFallback-Prozess erfolgreich abgeschlossen!');
  } catch (error) {
    console.error('Fehler während der Ausführung:', error);
  } finally {
    rl.close();
  }
}

main();
