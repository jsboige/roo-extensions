# Procédure d'Enregistrement Heartbeat

**Issue:** #460
**Date:** 2026-02-12
**Machines concernées:** myia-po-2024, myia-po-2023, myia-web1

---

## Contexte

Le système de heartbeat RooSync permet de suivre l'état online/offline des machines de la flotte. Actuellement, seulement 1/6 machines a un heartbeat actif (myia-po-2025).

**Objectif:** Enregistrer et démarrer le service heartbeat sur les 3 machines manquantes.

---

## Prérequis

- MCP `roo-state-manager` configuré et chargé dans Claude Code
- Accès à `G:/Mon Drive/Synchronisation/RooSync/.shared-state/heartbeat.json`
- VS Code doit être redémarré pour charger les outils MCP si des modifications ont été faites

---

## Procédure pour chaque machine

### Étape 1 : Identifier le machineId

```bash
# Windows PowerShell
$machineId = $env:COMPUTERNAME.ToLower()
Write-Host "Machine ID: $machineId"
```

Sortie attendue : `myia-po-2024`, `myia-po-2023`, ou `myia-web1`

### Étape 2 : Enregistrer le heartbeat

**Dans Claude Code (avec MCPs chargés) :**

Utiliser l'outil MCP `roosync_heartbeat_service` avec action `register` :

```
Utilise l'outil roosync_heartbeat_service avec les paramètres suivants :
- action: "register"
- machineId: "<machineId>" (remplacer par la valeur obtenue à l'étape 1)
- metadata: {
    "hostname": "<hostname>",
    "platform": "win32",
    "registeredBy": "manual-procedure",
    "registeredAt": "<timestamp ISO>"
  }
```

**Résultat attendu :**
```json
{
  "success": true,
  "message": "Heartbeat enregistré pour <machineId>",
  "result": {
    "action": "register",
    "machineId": "<machineId>",
    "timestamp": "2026-02-12T...",
    "status": "online",
    "isNewMachine": true
  }
}
```

### Étape 3 : Démarrer le service heartbeat

**Dans Claude Code (avec MCPs chargés) :**

Utiliser l'outil MCP `roosync_heartbeat_service` avec action `start` :

```
Utilise l'outil roosync_heartbeat_service avec les paramètres suivants :
- action: "start"
- machineId: "<machineId>"
- heartbeatInterval: 30000 (30 secondes)
- offlineTimeout: 120000 (2 minutes)
- enableAutoSync: true
```

**Résultat attendu :**
```json
{
  "success": true,
  "message": "Service de heartbeat démarré pour <machineId>",
  "result": {
    "action": "start",
    "machineId": "<machineId>",
    "startedAt": "2026-02-12T...",
    "config": {
      "heartbeatInterval": 30000,
      "offlineTimeout": 120000,
      "autoSyncEnabled": true
    }
  }
}
```

### Étape 4 : Vérifier l'état

**Option A - Via outil MCP :**

```
Utilise l'outil roosync_heartbeat_status avec les paramètres suivants :
- filter: "all"
- includeHeartbeats: true
- forceCheck: true
```

**Option B - Vérification manuelle du fichier :**

```bash
# Lire le fichier heartbeat.json
cat "G:/Mon Drive/Synchronisation/RooSync/.shared-state/heartbeat.json"
```

Vérifier que :
- `"<machineId>"` apparaît dans `heartbeats`
- `status: "online"`
- `onlineMachines` contient `"<machineId>"`
- `statistics.onlineCount` a augmenté de 1

---

## Validation Globale

Après avoir exécuté la procédure sur les 3 machines, vérifier :

| Machine | Status Attendu | Heartbeat Actif |
|---------|----------------|-----------------|
| myia-po-2025 | ✅ ONLINE | Oui (déjà actif) |
| myia-po-2024 | ✅ ONLINE | Oui (nouveau) |
| myia-po-2023 | ✅ ONLINE | Oui (nouveau) |
| myia-web1 | ✅ ONLINE | Oui (nouveau) |
| myia-ai-01 | ❌ OFFLINE | - (machine éteinte?) |
| myia-po-2026 | ❌ OFFLINE | - (machine éteinte?) |

**Objectif :** 4/6 machines online (66%)

---

## Troubleshooting

### Erreur : "machineId est requis pour l'action register"

**Cause :** Le paramètre `machineId` n'a pas été fourni ou est vide.

**Solution :** Vérifier que `$env:COMPUTERNAME.ToLower()` retourne une valeur valide.

### Erreur : "Heartbeat service déjà démarré"

**Cause :** Le service est déjà actif sur cette machine.

**Solution :** Vérifier l'état avec `roosync_heartbeat_status`. Si le service est actif mais la machine n'apparaît pas online, arrêter le service (`action: "stop"`) et le redémarrer.

### Heartbeat enregistré mais machine pas online

**Cause :** Le service n'envoie pas de heartbeats automatiques.

**Solution :** S'assurer que l'action `start` a bien été exécutée après `register`.

### Machine redevient offline après quelques minutes

**Cause probable :** Le process Claude Code a été fermé, arrêtant le service heartbeat.

**Solution :** Le service heartbeat tourne tant que Claude Code est ouvert. Pour un heartbeat permanent, il faudrait :
- Option A : Intégrer le heartbeat dans le scheduler Roo (tâche récurrente toutes les 30s)
- Option B : Créer un service Windows standalone

---

## Script Automatisé (Alternative)

Pour automatiser cette procédure, utiliser le script Node.js :

```bash
# Sur chaque machine
cd c:/dev/roo-extensions
node scripts/roosync/register-heartbeat.js
```

⚠️ **Note :** Ce script nécessite que les modules roo-state-manager soient importables.

---

## Prochaines Étapes

Une fois les 3 machines enregistrées :

1. **Documenter dans #460** : Mettre à jour l'issue avec les résultats
2. **Dashboard refresh** : Exécuter `roosync_refresh_dashboard` pour refléter les changements
3. **Machines offline** : Investiguer myia-ai-01 et myia-po-2026 (machines éteintes?)
4. **Automatisation** : Intégrer le heartbeat dans le workflow coordinator ou scheduler

---

**Procédure complète - Prête pour exécution**
