#!/usr/bin/env node

/**
 * Script de test pour le détecteur de stockage Roo
 * Teste la détection automatique et l'analyse des conversations
 */

import { RooStorageDetector } from '../build/utils/roo-storage-detector.js';
import * as path from 'path';
import * as os from 'os';

async function runTests() {
  console.log('🔍 Test du détecteur de stockage Roo\n');

  try {
    // Test 1: Détection automatique
    console.log('📍 Test 1: Détection automatique du stockage Roo...');
    const detection = await RooStorageDetector.detectRooStorage();
    
    console.log(`✅ Détection terminée:`);
    console.log(`   - Stockage trouvé: ${detection.found ? 'OUI' : 'NON'}`);
    console.log(`   - Emplacements détectés: ${detection.locations.length}`);
    console.log(`   - Conversations trouvées: ${detection.totalConversations}`);
    console.log(`   - Taille totale: ${formatBytes(detection.totalSize)}`);
    
    if (detection.errors.length > 0) {
      console.log(`   - Erreurs: ${detection.errors.length}`);
      detection.errors.forEach(error => console.log(`     ⚠️  ${error}`));
    }

    // Affichage des emplacements détectés
    if (detection.locations.length > 0) {
      console.log('\n📂 Emplacements de stockage détectés:');
      detection.locations.forEach((location, index) => {
        console.log(`   ${index + 1}. ${location.globalStoragePath}`);
        console.log(`      - Tasks: ${location.tasksPath}`);
        console.log(`      - Settings: ${location.settingsPath}`);
      });
    }

    // Affichage des conversations récentes
    if (detection.conversations.length > 0) {
      console.log('\n💬 Conversations récentes (5 dernières):');
      const recentConversations = detection.conversations
        .sort((a, b) => new Date(b.lastActivity).getTime() - new Date(a.lastActivity).getTime())
        .slice(0, 5);

      recentConversations.forEach((conv, index) => {
        console.log(`   ${index + 1}. ${conv.taskId}`);
        console.log(`      - Messages: ${conv.messageCount}`);
        console.log(`      - Dernière activité: ${new Date(conv.lastActivity).toLocaleString()}`);
        console.log(`      - Taille: ${formatBytes(conv.size)}`);
        console.log(`      - API: ${conv.hasApiHistory ? '✅' : '❌'} | UI: ${conv.hasUiMessages ? '✅' : '❌'}`);
        if (conv.metadata?.title) {
          console.log(`      - Titre: ${conv.metadata.title}`);
        }
      });
    }

    // Test 2: Statistiques globales
    console.log('\n📊 Test 2: Statistiques globales...');
    const stats = await RooStorageDetector.getStorageStats();
    
    console.log(`✅ Statistiques:`);
    console.log(`   - Emplacements: ${stats.totalLocations}`);
    console.log(`   - Conversations: ${stats.totalConversations}`);
    console.log(`   - Taille totale: ${formatBytes(stats.totalSize)}`);
    console.log(`   - Plus ancienne: ${stats.oldestConversation || 'N/A'}`);
    console.log(`   - Plus récente: ${stats.newestConversation || 'N/A'}`);

    // Test 3: Recherche d'une conversation spécifique
    if (detection.conversations.length > 0) {
      const firstConv = detection.conversations[0];
      console.log(`\n🔎 Test 3: Recherche de la conversation ${firstConv.taskId}...`);
      
      const foundConv = await RooStorageDetector.findConversation(firstConv.taskId);
      console.log(`✅ Conversation ${foundConv ? 'trouvée' : 'non trouvée'}`);
      
      if (foundConv) {
        console.log(`   - Path: ${foundConv.path}`);
        console.log(`   - Messages: ${foundConv.messageCount}`);
      }
    }

    // Test 4: Validation de chemins
    console.log('\n🛡️  Test 4: Validation de chemins...');
    
    const testPaths = [
      path.join(os.homedir(), '.vscode', 'extensions', 'test'),
      '/chemin/inexistant',
      process.cwd(),
    ];

    for (const testPath of testPaths) {
      const isValid = await RooStorageDetector.validateCustomPath(testPath);
      console.log(`   ${testPath}: ${isValid ? '✅ Valide' : '❌ Invalide'}`);
    }

    console.log('\n🎉 Tous les tests terminés avec succès!');

  } catch (error) {
    console.error('❌ Erreur lors des tests:', error);
    process.exit(1);
  }
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Vérification que le build existe
import * as fs from 'fs';
const buildPath = path.join(process.cwd(), 'build');

if (!fs.existsSync(buildPath)) {
  console.log('⚠️  Le répertoire build n\'existe pas. Compilation en cours...');
  
  const { spawn } = await import('child_process');
  const buildProcess = spawn('npm', ['run', 'build'], { stdio: 'inherit' });
  
  buildProcess.on('close', (code) => {
    if (code === 0) {
      console.log('✅ Compilation terminée. Lancement des tests...\n');
      runTests();
    } else {
      console.error('❌ Erreur de compilation');
      process.exit(1);
    }
  });
} else {
  runTests();
}