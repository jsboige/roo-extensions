#!/usr/bin/env node
/**
 * Script de test simple pour vérifier l'extraction des titres markdown
 */

import * as fs from 'fs/promises';
import * as fsSync from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de test temporaire
const TEST_DIR = path.join(__dirname, 'temp-markdown-extraction-test');

// Fonction principale
async function main() {
  try {
    // Créer le dossier de test
    await fs.mkdir(TEST_DIR, { recursive: true });
    console.log(`Dossier de test créé: ${TEST_DIR}`);
    
    // Créer un fichier markdown de test
    const testFilePath = path.join(TEST_DIR, 'test.md');
    await fs.writeFile(testFilePath, '# Titre principal\n\nTexte\n\n## Sous-titre\n\nTexte\n\n### Sous-sous-titre\n\nTexte');
    console.log(`Fichier markdown de test créé: ${testFilePath}`);
    
    // Extraire les titres
    const titles = extractMarkdownTitles(testFilePath);
    console.log('Titres extraits:');
    console.log(titles);
    
    // Nettoyer
    await fs.rm(TEST_DIR, { recursive: true, force: true });
    console.log(`Dossier de test supprimé`);
  } catch (error) {
    console.error(`Erreur: ${error.message}`);
  }
}

// Fonction d'extraction des titres markdown
function extractMarkdownTitles(filePath) {
  try {
    // Lire le contenu du fichier
    const content = fsSync.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');
    const titles = [];
    
    // Expression régulière pour détecter les titres markdown (# Titre, ## Sous-titre, etc.)
    const titleRegex = /^(#{1,6})\s+(.+)$/;
    
    for (const line of lines) {
      const match = line.match(titleRegex);
      if (match) {
        const level = match[1].length; // Nombre de # (1-6)
        const text = match[2].trim();  // Texte du titre
        titles.push({ level, text });
      }
    }
    
    return titles;
  } catch (error) {
    console.error(`Erreur lors de la lecture du fichier markdown ${filePath}: ${error.message}`);
    return [];
  }
}

// Exécuter le script
main().catch(console.error);