#!/usr/bin/env node

/**
 * Script pour vérifier la présence de BOM UTF-8 dans un fichier
 */

const fs = require('fs');

const filePath = process.argv[2];

if (!filePath) {
  console.error('Usage: node check-bom-in-file.js <chemin_fichier>');
  process.exit(1);
}

try {
  const bytes = fs.readFileSync(filePath);
  const bomPresent = bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF;

  console.log(`Fichier: ${filePath}`);
  console.log(`Taille: ${bytes.length} octets`);
  console.log(`Premiers octets: ${bytes[0].toString(16).padStart(2, '0')} ${bytes[1].toString(16).padStart(2, '0')} ${bytes[2].toString(16).padStart(2, '0')}`);
  console.log(`BOM UTF-8 présent: ${bomPresent ? 'OUI ❌' : 'NON ✅'}`);

  process.exit(bomPresent ? 1 : 0);
} catch (error) {
  console.error(`Erreur: ${error.message}`);
  process.exit(1);
}
