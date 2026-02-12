/**
 * Script pour enregistrer et démarrer le heartbeat sur une machine
 *
 * Usage: node register-heartbeat.js [machineId]
 * Si machineId n'est pas fourni, utilise le hostname de la machine
 *
 * Issue: #460
 * Date: 2026-02-12
 * Author: Claude Code (myia-po-2024)
 */

import os from 'os';
import { getRooSyncService } from '../../mcps/internal/servers/roo-state-manager/build/src/services/RooSyncService.js';

// Obtenir le machineId
let machineId = process.argv[2];
if (!machineId) {
    machineId = os.hostname().toLowerCase();
}

console.log(`🔧 Enregistrement heartbeat pour ${machineId}\n`);

try {
    // Obtenir le service RooSync
    const rooSyncService = getRooSyncService();
    const heartbeatService = rooSyncService.getHeartbeatService();

    // 1. Register heartbeat
    console.log('📝 Étape 1/2 : Enregistrement du heartbeat...');

    await heartbeatService.registerHeartbeat(machineId, {
        hostname: os.hostname(),
        platform: os.platform(),
        arch: os.arch(),
        cpus: os.cpus().length,
        totalMem: Math.round(os.totalmem() / (1024 * 1024 * 1024)) + ' GB',
        registeredAt: new Date().toISOString()
    });

    const heartbeatData = heartbeatService.getHeartbeatData(machineId);
    if (heartbeatData) {
        console.log(`   ✅ Heartbeat enregistré`);
        console.log(`   - Statut: ${heartbeatData.status}`);
        console.log(`   - Dernier heartbeat: ${heartbeatData.lastHeartbeat}`);
    } else {
        console.error('   ❌ Échec de l\'enregistrement');
        process.exit(1);
    }

    // 2. Start heartbeat service
    console.log('\n🚀 Étape 2/2 : Démarrage du service...');

    await heartbeatService.startHeartbeatService(
        machineId,
        // Callback pour détection offline
        (offlineMachineId) => {
            console.log(`   ⚠️  Machine offline détectée: ${offlineMachineId}`);
        },
        // Callback pour retour online
        (onlineMachineId) => {
            console.log(`   ✅ Machine revenue online: ${onlineMachineId}`);
        }
    );

    console.log(`   ✅ Service démarré`);
    console.log(`   - Intervalle: 30s`);
    console.log(`   - Timeout offline: 2min`);
    console.log(`   - Auto-sync: activé`);

    console.log(`\n✅ SUCCÈS : Heartbeat configuré pour ${machineId}`);
    console.log(`\n💡 Le service heartbeat est maintenant actif.`);
    console.log(`   Pour vérifier l'état, consulter heartbeat.json ou utiliser roosync_heartbeat_status`);

    // Note: Le service tourne en arrière-plan, on ne termine pas le process immédiatement
    // On attend quelques secondes pour confirmer que le premier heartbeat est envoyé
    console.log(`\n⏳ Attente de 5 secondes pour confirmation du premier heartbeat...`);

    await new Promise(resolve => setTimeout(resolve, 5000));

    const updatedData = heartbeatService.getHeartbeatData(machineId);
    if (updatedData && updatedData.status === 'online') {
        console.log(`\n✅ Confirmation : ${machineId} est ONLINE`);
        process.exit(0);
    } else {
        console.warn(`\n⚠️  Attention : ${machineId} n'est pas online après 5 secondes`);
        process.exit(1);
    }

} catch (error) {
    console.error(`\n❌ ERREUR : ${error.message}`);
    console.error(error.stack);
    process.exit(1);
}
