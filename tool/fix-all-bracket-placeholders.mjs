import { execSync } from 'child_process';

const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim();
const projectId = 'voleo-sho2303';

const updates = {
  'wc-ko-af-1': { homeTeam: 'Sieger Sechzehntelfinale 2', awayTeam: 'Sieger Sechzehntelfinale 5' },
  'wc-ko-af-2': { homeTeam: 'Sieger Sechzehntelfinale 1', awayTeam: 'Sieger Sechzehntelfinale 3' },
  'wc-ko-af-3': { homeTeam: 'Sieger Sechzehntelfinale 4', awayTeam: 'Sieger Sechzehntelfinale 6' },
  'wc-ko-af-4': { homeTeam: 'Sieger Sechzehntelfinale 7', awayTeam: 'Sieger Sechzehntelfinale 8' },
  'wc-ko-af-5': { homeTeam: 'Sieger Sechzehntelfinale 11', awayTeam: 'Sieger Sechzehntelfinale 12' },
  'wc-ko-af-6': { homeTeam: 'Sieger Sechzehntelfinale 9', awayTeam: 'Sieger Sechzehntelfinale 10' },
  'wc-ko-af-7': { homeTeam: 'Sieger Sechzehntelfinale 14', awayTeam: 'Sieger Sechzehntelfinale 16' },
  'wc-ko-af-8': { homeTeam: 'Sieger Sechzehntelfinale 13', awayTeam: 'Sieger Sechzehntelfinale 15' },
  
  'wc-ko-vf-1': { homeTeam: 'Sieger Achtelfinale 1', awayTeam: 'Sieger Achtelfinale 2' },
  'wc-ko-vf-2': { homeTeam: 'Sieger Achtelfinale 5', awayTeam: 'Sieger Achtelfinale 6' },
  'wc-ko-vf-3': { homeTeam: 'Sieger Achtelfinale 3', awayTeam: 'Sieger Achtelfinale 4' },
  'wc-ko-vf-4': { homeTeam: 'Sieger Achtelfinale 7', awayTeam: 'Sieger Achtelfinale 8' },
  
  'wc-ko-hf-1': { homeTeam: 'Sieger Viertelfinale 1', awayTeam: 'Sieger Viertelfinale 2' },
  'wc-ko-hf-2': { homeTeam: 'Sieger Viertelfinale 3', awayTeam: 'Sieger Viertelfinale 4' },
  
  'wc-ko-p3-1': { homeTeam: 'Verlierer Halbfinale 1', awayTeam: 'Verlierer Halbfinale 2' },
  'wc-ko-fi-1': { homeTeam: 'Sieger Halbfinale 1', awayTeam: 'Sieger Halbfinale 2' },
};

console.log('Starting Firestore updates...');
for (const [matchId, teams] of Object.entries(updates)) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/matches/${matchId}?updateMask.fieldPaths=homeTeam&updateMask.fieldPaths=awayTeam`;
  const body = {
    fields: {
      homeTeam: { stringValue: teams.homeTeam },
      awayTeam: { stringValue: teams.awayTeam },
    }
  };
  
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  
  if (response.ok) {
    console.log(`✔ Updated ${matchId}`);
  } else {
    console.error(`❌ Failed to update ${matchId}:`, await response.text());
  }
}
console.log('Firestore updates finished.');
