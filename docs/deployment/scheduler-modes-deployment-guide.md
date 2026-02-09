# Guide de Déploiement - Scheduler & Modes Provider

**Date:** 2026-02-09
**Machine testée:** myia-po-2024
**Statut:** ✅ VALIDÉ

## Résumé

Deux problèmes identifiés et résolus sur myia-po-2024:

1. **Scheduler Roo Code** : Fonctionne correctement avec `.roo/schedules.json`
2. **Modes Provider** : Les champs `"model"` dans `custom_modes.json` étaient incorrects

---

## 1. Scheduler Roo Code

### ❌ Hypothèse incorrecte (exploration agents)

Les agents d'exploration ont suggéré que Roo Code lit depuis `%APPDATA%\...\kyle-hoskins.roo-scheduler\` (ancien système Roo Scheduler extension). **C'est FAUX** pour Roo Code moderne.

### ✅ Réalité validée

**Roo Code lit bien `.roo/schedules.json` dans le workspace !**

**Preuve:**
- Fichier modifié manuellement : `timeInterval: "5"` (5 minutes)
- Champs mis à jour automatiquement par Roo Code :
  ```json
  "lastExecutionTime": "2026-02-09T15:15:00.425Z",
  "lastTaskId": "019c42f8-62bf-76ec-a39c-88594224da23",
  "nextExecutionTime": "2026-02-09T15:20:00.425Z"
  ```
- Tâche créée dans `%APPDATA%\...\rooveterinaryinc.roo-cline\tasks\019c42f8-62bf-76ec-a39c-88594224da23\`

### Configuration validée

**Fichier:** `.roo/schedules.json`

```json
{
  "schedules": [
    {
      "id": "1770646864223",
      "name": "Claude-Code Assistant",
      "mode": "orchestrator-simple",
      "taskInstructions": "Tu es lance par le planificateur automatique...",
      "scheduleType": "time",
      "timeInterval": "180",  // 3h en production
      "timeUnit": "minute",
      "selectedDays": { "sun": true, "mon": true, ... },
      "startMinute": "00",  // Staggering: 00, 30, 00, 30, 00, 30 pour 6 machines
      "active": true,
      "taskInteraction": "skip"
    }
  ]
}
```

### Déploiement sur autres machines

**Statut actuel:**
- ✅ myia-po-2024 : Testé et validé (5min + 180min)
- ❓ myia-ai-01 : À vérifier
- ❓ myia-po-2023 : À vérifier
- ❓ myia-po-2026 : À vérifier
- ❓ myia-web1 : À vérifier

**Action:** Chaque machine doit :
1. Vérifier que `.roo/schedules.json` existe (issue #429)
2. Modifier `timeInterval` temporairement à `"5"` pour tester
3. Attendre 5 minutes et vérifier que `lastExecutionTime` se met à jour
4. Restaurer `timeInterval: "180"` (3h) une fois validé
5. **Redémarrer VS Code** après toute modification de `.roo/schedules.json`

---

## 2. Modes Provider Configuration

### ❌ Configuration incorrecte

Les modes déployés utilisaient des providers Anthropic/Qwen au lieu des providers Z.AI configurés:

```json
{
  "slug": "code-simple",
  "model": "qwen/qwen3-235b-a22b"  // ❌ INCORRECT
},
{
  "slug": "code-complex",
  "model": "anthropic/claude-sonnet-4.5"  // ❌ INCORRECT
}
```

### ✅ Configuration correcte

Les modes doivent utiliser les providers configurés dans Roo Code settings:

```json
{
  "slug": "code-simple",
  "model": "simple"  // ✅ Provider maison (xx.myia.io, GLM-4.7 Flash)
},
{
  "slug": "code-complex",
  "model": "default"  // ✅ Provider Z.AI (souscription, GLM-4.7)
}
```

**Mapping providers:**
- `-simple` modes → `"simple"` (provider maison)
- `-complex` modes → `"default"` (provider Z.AI)

### Script de correction

**Fichier:** [`scripts/deployment/fix-modes-provider-config.ps1`](../../scripts/deployment/fix-modes-provider-config.ps1)

**Usage:**
```powershell
# Dry-run (vérifier sans modifier)
.\scripts\deployment\fix-modes-provider-config.ps1 -WhatIf

# Appliquer les corrections
.\scripts\deployment\fix-modes-provider-config.ps1

# Sans backup
.\scripts\deployment\fix-modes-provider-config.ps1 -Backup:$false
```

**Résultat sur myia-po-2024:**
```
Résumé des modifications:
  - Modes complex → 'default': 5
  - Modes simple → 'simple': 5
  - Inchangés: 0
```

**Fichier modifié:**
```
C:\Users\<USER>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json
```

**⚠️ IMPORTANT:** Redémarrer VS Code après exécution du script.

### Déploiement sur autres machines

Chaque machine doit :
1. Copier le script [`fix-modes-provider-config.ps1`](../../scripts/deployment/fix-modes-provider-config.ps1) localement
2. Exécuter avec `-WhatIf` pour vérifier
3. Exécuter sans `-WhatIf` pour appliquer
4. **Redémarrer VS Code**
5. Vérifier en créant une nouvelle tâche Roo dans un mode `-simple` puis `-complex`

---

## 3. Investigation Agents : Leçons Apprises

### ⚠️ Avertissement : Ne pas faire confiance aveuglément aux agents

Les 2 agents Explore lancés en parallèle ont retourné des informations **partiellement incorrectes** :

1. **Scheduler location** : Suggéré `%APPDATA%\..\kyle-hoskins.roo-scheduler\` (ancien système) au lieu de `.roo/schedules.json` (workspace)
2. **Modes schema** : Suggéré que le champ `"model"` n'existe pas dans le schema, alors qu'il fonctionne bien dans Roo Code

**Cause probable:**
- Les agents ont lu le code source de Roo Code mais n'ont pas testé le comportement réel
- Documentation officielle manquante ou obsolète pour les nouvelles fonctionnalités

**Leçon:** Toujours **tester** les conclusions des agents avant de les documenter ou partager.

### ✅ Méthodologie correcte appliquée

1. **Hypothèse** (agent) → `.roo/schedules.json` ne devrait pas fonctionner
2. **Test réel** → Modifier `timeInterval: "5"`, attendre, observer
3. **Validation** → `lastExecutionTime` mis à jour, tâche créée
4. **Conclusion** → L'hypothèse de l'agent était incorrecte

---

## 4. Checklist Validation Multi-Machine

| Machine | .roo/schedules.json | Scheduler OK | Modes fixed | VS Code restarted |
|---------|---------------------|--------------|-------------|-------------------|
| myia-po-2024 | ✅ | ✅ (5min + 180min) | ✅ | ✅ |
| myia-ai-01 | ? | ? | ? | ? |
| myia-po-2023 | ? | ? | ? | ? |
| myia-po-2026 | ? | ? | ? | ? |
| myia-web1 | ? | ? | ? | ? |

---

## 5. Actions Requises

### Pour chaque machine (myia-ai-01, po-2023, po-2026, web1)

1. **Scheduler test:**
   ```powershell
   # Modifier .roo/schedules.json
   "timeInterval": "5"  # 5 minutes pour test

   # Redémarrer VS Code
   # Attendre 5 minutes
   # Vérifier lastExecutionTime dans .roo/schedules.json
   # Vérifier tâche créée dans %APPDATA%\...\tasks\

   # Restaurer
   "timeInterval": "180"  # 3h production
   ```

2. **Modes provider fix:**
   ```powershell
   cd c:\dev\roo-extensions
   .\scripts\deployment\fix-modes-provider-config.ps1 -WhatIf
   .\scripts\deployment\fix-modes-provider-config.ps1

   # Redémarrer VS Code
   ```

3. **Signaler résultat sur RooSync** avec:
   - Scheduler fonctionne ? (oui/non)
   - Modes corrigés ? (oui/non)
   - Problèmes rencontrés ?

---

## 6. Documentation Mise à Jour

- ✅ Script correction créé : [`fix-modes-provider-config.ps1`](../../scripts/deployment/fix-modes-provider-config.ps1)
- ✅ Guide déploiement : Ce fichier
- ⏳ À mettre à jour : Issue #429 (scheduler) avec validation
- ⏳ À créer : Issue pour correction modes (si nécessaire)

---

**Résumé:** Les deux systèmes fonctionnent correctement sur myia-po-2024. Les autres machines doivent appliquer les mêmes corrections et valider.
