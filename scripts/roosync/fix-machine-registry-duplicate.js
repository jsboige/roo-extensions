/**
 * Script pour corriger le doublon case-sensitive MyIA-Web1 vs myia-web1
 *
 * Issue: #460
 * Date: 2026-02-12
 * Author: Claude Code (myia-po-2024)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Chemin du registre machine
const registryPath = "G:/Mon Drive/Synchronisation/RooSync/.shared-state/.machine-registry.json";

console.log('🔧 Fix doublon MyIA-Web1 vs myia-web1\n');

// Vérifier que le fichier existe
if (!fs.existsSync(registryPath)) {
    console.error(`❌ Fichier non trouvé : ${registryPath}`);
    process.exit(1);
}

// Backup du fichier original
const backupPath = `${registryPath}.backup-${new Date().toISOString().replace(/:/g, '-')}`;
fs.copyFileSync(registryPath, backupPath);
console.log(`✅ Backup créé : ${backupPath}`);

// Charger le registre (retirer le BOM UTF-8 si présent)
let rawData = fs.readFileSync(registryPath, 'utf8');
if (rawData.charCodeAt(0) === 0xFEFF) {
    rawData = rawData.substring(1);
}
const registry = JSON.parse(rawData);

// Compter les machines avant
const beforeCount = Object.keys(registry.machines).length;
console.log(`📊 Machines avant : ${beforeCount}`);

// Afficher les machines avec leur casse
console.log('\nMachines actuelles :');
for (const machineId of Object.keys(registry.machines)) {
    const isTarget = machineId === 'MyIA-Web1';
    const marker = isTarget ? ' ← À SUPPRIMER' : '';
    console.log(`  - ${machineId}${marker}`);
}

// Supprimer l'entrée avec casse incorrecte
if ('MyIA-Web1' in registry.machines) {
    delete registry.machines['MyIA-Web1'];
    console.log('\n✅ Entrée \'MyIA-Web1\' supprimée');
} else {
    console.log('\n⚠️  \'MyIA-Web1\' non trouvée dans le registre');
}

// Mettre à jour lastUpdated
registry.lastUpdated = new Date().toISOString();

// Compter les machines après
const afterCount = Object.keys(registry.machines).length;
console.log(`📊 Machines après : ${afterCount}`);

// Sauvegarder
const json = JSON.stringify(registry, null, 2);
fs.writeFileSync(registryPath, json, 'utf8');

console.log(`\n✅ Registre mis à jour : ${afterCount} machines (attendu: 6)`);
console.log(`📁 Fichier : ${registryPath}\n`);

// Validation
if (afterCount === 6) {
    console.log('✅ SUCCÈS : 6 machines dans le registre');
    process.exit(0);
} else {
    console.warn(`⚠️  Attention : ${afterCount} machines au lieu de 6 attendues`);
    process.exit(1);
}
