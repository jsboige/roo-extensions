const fs = require('fs');
const path = require('path');

const baselinePath = 'g:/Mon Drive/Synchronisation/RooSync/.shared-state/sync-config.ref.json';

console.log('=== TEST BASLINE PARSING ===');
console.log('Chemin:', baselinePath);
console.log('Fichier existe:', fs.existsSync(baselinePath));

try {
  const content = fs.readFileSync(baselinePath, 'utf-8');
  console.log('Contenu lu, longueur:', content.length);
  console.log('Début du contenu:', content.substring(0, 200));
  
  const parsed = JSON.parse(content);
  console.log('JSON parsé avec succès');
  console.log('machineId:', parsed.machineId);
  console.log('version:', parsed.version);
} catch (error) {
  console.error('ERREUR:', error.message);
  console.error('Stack:', error.stack);
}