/**
 * Test complet du workflow d'extraction des plans de titres markdown
 * et d'utilisation des numéros de ligne pour extraire des sections spécifiques
 *
 * Ce script prépare les données de test et fournit des instructions pour tester
 * le workflow suivant via Roo :
 * 1. Utilisation de l'outil extract_markdown_outline pour obtenir le plan des titres
 * 2. Utilisation des numéros de ligne retournés pour extraire des sections spécifiques
 * 3. Vérification que les extraits correspondent bien aux sections attendues
 */

import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel en ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// URLs de test
const TEST_URLS = [
  'https://en.wikipedia.org/wiki/Markdown',
  'https://docs.github.com/en/get-started',
  'https://github.com/jsboige/mcp-servers'
];

// Profondeurs de titres à tester
const DEPTHS_TO_TEST = [1, 2, 3];

// Fonction principale
async function main() {
  console.log('===== Préparation du test du workflow d\'extraction des plans de titres =====');
  
  // Créer un répertoire pour les résultats des tests si nécessaire
  const testResultsDir = path.join(__dirname, 'test-results');
  if (!fs.existsSync(testResultsDir)) {
    fs.mkdirSync(testResultsDir);
  }
  
  // Créer les fichiers de test pour chaque étape du workflow
  
  // Étape 1: Extraction des plans de titres avec différentes profondeurs
  for (const depth of DEPTHS_TO_TEST) {
    const outlineTestData = {
      urls: TEST_URLS.map(url => ({ url })),
      max_depth: depth
    };
    
    const outlineTestFilePath = path.join(testResultsDir, `outline-depth-${depth}.json`);
    fs.writeFileSync(outlineTestFilePath, JSON.stringify(outlineTestData, null, 2));
    console.log(`Fichier de test pour l'extraction avec profondeur ${depth} créé: ${outlineTestFilePath}`);
  }
  
  // Étape 2: Préparation du fichier pour le test d'extraction de sections
  // Ce fichier sera complété manuellement avec les numéros de ligne obtenus à l'étape 1
  const sectionsTestData = {
    urls: TEST_URLS.map(url => ({
      url,
      sections: [
        // Ces sections seront à compléter manuellement avec les numéros de ligne
        // obtenus à partir des résultats de l'étape 1
        { name: "Section 1", start_line: null, end_line: null },
        { name: "Section 2", start_line: null, end_line: null },
        { name: "Section 3", start_line: null, end_line: null }
      ]
    }))
  };
  
  const sectionsTestFilePath = path.join(testResultsDir, 'sections-to-extract.json');
  fs.writeFileSync(sectionsTestFilePath, JSON.stringify(sectionsTestData, null, 2));
  console.log(`Fichier de test pour l'extraction de sections créé: ${sectionsTestFilePath}`);
  
  // Étape 3: Préparation du fichier pour le test de validation des sections extraites
  const validationTestFilePath = path.join(testResultsDir, 'validation-results.json');
  fs.writeFileSync(validationTestFilePath, JSON.stringify({
    results: [],
    success: false,
    notes: "Ce fichier sera rempli avec les résultats de validation"
  }, null, 2));
  console.log(`Fichier pour les résultats de validation créé: ${validationTestFilePath}`);
  
  // Afficher les instructions pour tester le workflow
  console.log('\n===== Instructions pour tester le workflow d\'extraction des plans de titres =====');
  console.log('\nÉtape 1: Extraction des plans de titres avec différentes profondeurs');
  console.log('Pour chaque fichier outline-depth-X.json, exécuter dans Roo:');
  console.log('```');
  console.log('<use_mcp_tool>');
  console.log('<server_name>jinavigator</server_name>');
  console.log('<tool_name>extract_markdown_outline</tool_name>');
  console.log('<arguments>');
  console.log('// Contenu du fichier outline-depth-X.json');
  console.log('</arguments>');
  console.log('</use_mcp_tool>');
  console.log('```');
  
  console.log('\nÉtape 2: Compléter le fichier sections-to-extract.json');
  console.log('1. Examiner les résultats de l\'étape 1 pour identifier des sections intéressantes');
  console.log('2. Noter les numéros de ligne de début et de fin pour chaque section');
  console.log('3. Compléter le fichier sections-to-extract.json avec ces numéros');
  
  console.log('\nÉtape 3: Extraction des sections spécifiques');
  console.log('Pour chaque URL dans le fichier sections-to-extract.json, exécuter dans Roo:');
  console.log('```');
  console.log('<use_mcp_tool>');
  console.log('<server_name>jinavigator</server_name>');
  console.log('<tool_name>multi_convert</tool_name>');
  console.log('<arguments>');
  console.log('{');
  console.log('  "urls": [');
  console.log('    // Pour chaque section de l\'URL:');
  console.log('    { "url": "URL_ICI", "start_line": DEBUT, "end_line": FIN }');
  console.log('  ]');
  console.log('}');
  console.log('</arguments>');
  console.log('</use_mcp_tool>');
  console.log('```');
  
  console.log('\nÉtape 4: Validation des sections extraites');
  console.log('1. Vérifier que chaque section extraite contient bien le contenu attendu');
  console.log('2. Documenter les résultats dans le fichier validation-results.json');
  
  console.log('\n===== Exemple de workflow complet =====');
  console.log('\n1. Extraction du plan des titres:');
  console.log('```');
  console.log('<use_mcp_tool>');
  console.log('<server_name>jinavigator</server_name>');
  console.log('<tool_name>extract_markdown_outline</tool_name>');
  console.log('<arguments>');
  console.log('{');
  console.log('  "urls": [');
  console.log('    { "url": "https://en.wikipedia.org/wiki/Markdown" }');
  console.log('  ],');
  console.log('  "max_depth": 3');
  console.log('}');
  console.log('</arguments>');
  console.log('</use_mcp_tool>');
  console.log('```');
  
  console.log('\n2. Extraction d\'une section spécifique:');
  console.log('```');
  console.log('<use_mcp_tool>');
  console.log('<server_name>jinavigator</server_name>');
  console.log('<tool_name>multi_convert</tool_name>');
  console.log('<arguments>');
  console.log('{');
  console.log('  "urls": [');
  console.log('    { "url": "https://en.wikipedia.org/wiki/Markdown", "start_line": 10, "end_line": 20 }');
  console.log('  ]');
  console.log('}');
  console.log('</arguments>');
  console.log('</use_mcp_tool>');
  console.log('```');
  
  console.log('\n===== Démonstration interactive =====');
  console.log('\nPour une démonstration interactive complète, exécuter les commandes suivantes dans Roo:');
  
  console.log('\n1. Extraire le plan des titres de la page Markdown sur Wikipedia:');
  console.log('```');
  console.log('<use_mcp_tool>');
  console.log('<server_name>jinavigator</server_name>');
  console.log('<tool_name>extract_markdown_outline</tool_name>');
  console.log('<arguments>');
  console.log('{');
  console.log('  "urls": [');
  console.log('    { "url": "https://en.wikipedia.org/wiki/Markdown" }');
  console.log('  ],');
  console.log('  "max_depth": 3');
  console.log('}');
  console.log('</arguments>');
  console.log('</use_mcp_tool>');
  console.log('```');
  
  console.log('\n2. Identifier une section intéressante et noter son numéro de ligne');
  console.log('Par exemple, si "History" est à la ligne 50 et "Syntax" à la ligne 100:');
  
  console.log('\n3. Extraire cette section spécifique:');
  console.log('```');
  console.log('<use_mcp_tool>');
  console.log('<server_name>jinavigator</server_name>');
  console.log('<tool_name>multi_convert</tool_name>');
  console.log('<arguments>');
  console.log('{');
  console.log('  "urls": [');
  console.log('    { "url": "https://en.wikipedia.org/wiki/Markdown", "start_line": 50, "end_line": 100 }');
  console.log('  ]');
  console.log('}');
  console.log('</arguments>');
  console.log('</use_mcp_tool>');
  console.log('```');
  
  console.log('\n4. Vérifier que le contenu extrait correspond bien à la section "History"');
  
  console.log('\n===== Tests terminés =====');
}

// Exécuter la fonction principale
main().catch(error => {
  console.error('Erreur lors de l\'exécution des tests:', error);
  process.exit(1);
});