const { existsSync } = require('fs');
const { join } = require('path');

console.log('=== TEST CHEMINS SHARED STATE ===');

// Simuler la logique de findSharedStatePath()
const _dirname = process.cwd();

const possiblePaths = [
  process.env.SHARED_STATE_PATH,
  join(process.env.USERPROFILE || '', '.roo', '.shared-state'),
  join(process.cwd(), '.shared-state'),
  join(_dirname, '../../../../.shared-state'),
  'g:/Mon Drive/Synchronisation/RooSync/.shared-state'
].filter(Boolean);

console.log('Chemins possibles :');
possiblePaths.forEach((path, index) => {
  console.log(`${index}: ${path}`);
  try {
    const exists = existsSync(path);
    console.log(`   -> EXISTS: ${exists}`);
    if (exists) {
      console.log(`   -> SERAIT UTILISÉ !`);
    }
  } catch (error) {
    console.log(`   -> ERREUR: ${error.message}`);
  }
});

console.log('\nRépertoire de travail actuel :', process.cwd());
console.log('USERPROFILE :', process.env.USERPROFILE);
console.log('SHARED_STATE_PATH :', process.env.SHARED_STATE_PATH);