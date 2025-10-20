# 🚨 Bug Critique : Architecture `machineId` RooSync v2

**Date** : 2025-10-20  
**Gravité** : 🔴 **CRITIQUE**  
**Impact** : Tous les outils messaging (send, reply, amend, read_inbox)  
**Statut** : ✅ Diagnostic complet - ⏳ Attente validation correction

---

## 📋 Résumé Exécutif

**Problème** : 3 outils messaging RooSync lisent le `machineId` depuis `sync-config.json` au lieu de `process.env.ROOSYNC_MACHINE_ID`, causant l'envoi de messages avec un expéditeur **incorrect** (dernière machine ayant écrit `sync-config.json` au lieu de la machine courante).

**Conséquence directe** : Quand `myia-ai-01` envoie un message, il apparaît comme provenant de `myia-po-2024`.

**Solution** : Remplacer `getLocalMachineId(sharedStatePath)` par `loadRooSyncConfig().machineId` dans 3 fichiers.

---

## 🔍 Diagnostic Détaillé

### 1. Architecture Attendue (Design Pattern Correct)

#### 1.1 Source de Vérité : `.env` Local

**Fichier** : `mcps/internal/servers/roo-state-manager/.env`

```env
ROOSYNC_MACHINE_ID=myia-ai-01
```

**Chargement** : `roosync-config.ts:85`

```typescript
const machineId = process.env.ROOSYNC_MACHINE_ID!;
```

**Design** : Chaque machine possède son propre fichier `.env` avec son `machineId` unique.

#### 1.2 `sync-config.json` : Fichier PARTAGÉ

**Fichier** : `G:/Mon Drive/Synchronisation/RooSync/.shared-state/sync-config.json`

**Structure attendue** :

```json
{
  "version": "2.0.0",
  "machines": {
    "myia-po-2024": {
      "sdddSpecs": [],
      "mcpServers": []
    },
    "myia-ai-01": {
      "sdddSpecs": [],
      "mcpServers": []
    }
  }
}
```

**Rôle** : Inventaire partagé des configurations de toutes les machines.

---

### 2. Bug Identifié : Fonction `getLocalMachineId()` Incorrecte

#### 2.1 Fichiers Impactés

**3 outils messaging** contiennent la fonction bugguée identique :

| Fichier | Lignes | Bug | Impact |
|---------|--------|-----|--------|
| `send_message.ts` | 46-64 | ✅ Confirmé | Message envoyé avec mauvais `from` |
| `amend_message.ts` | 34-52 | ✅ Confirmé | Amendement avec mauvais `senderId` |
| `read_inbox.ts` | 31-49 | ✅ Confirmé | Lecture inbox d'une mauvaise machine |

#### 2.2 Code Buggué

```typescript
function getLocalMachineId(sharedStatePath: string): string {
  const configPath = join(sharedStatePath, 'sync-config.json');
  
  if (!existsSync(configPath)) {
    throw new Error(`Fichier sync-config.json introuvable`);
  }
  
  try {
    const configContent = readFileSync(configPath, 'utf-8');
    const config = JSON.parse(configContent);
    
    if (!config.machineId) {
      throw new Error('machineId absent dans sync-config.json');
    }
    
    return config.machineId;
  } catch (error) {
    throw new Error(`Erreur lecture sync-config.json`);
  }
}
```

**Problème** : Lit `sync-config.json:3` qui contient `"machineId": "myia-po-2024"`.

---

### 3. Preuve du Bug : État Actuel `sync-config.json`

**Fichier réel** : `G:/Mon Drive/Synchronisation/RooSync/.shared-state/sync-config.json`

```json
{
  "version": "2.0.0",
  "machineId": "myia-po-2024",
  "machines": {
    "myia-po-2024": {}
  }
}
```

**Scénario du bug** :

1. **Contexte** : `myia-po-2024` a exécuté `roosync_init` en dernier
2. **Action** : `myia-ai-01` utilise `roosync_send_message`
3. **Bug** : `getLocalMachineId()` lit `sync-config.json` ligne 3
4. **Résultat** : Message envoyé avec `from: "myia-po-2024"` au lieu de `from: "myia-ai-01"`

---

### 4. Outils Non Impactés

**Outils OK** (n'utilisent PAS `getLocalMachineId()`) :

| Fichier | Raison | Status |
|---------|--------|--------|
| `reply_message.ts` | Utilise inversion automatique | ✅ OK |
| `get_message.ts` | Pas besoin de `machineId` local | ✅ OK |
| `mark_message_read.ts` | Pas besoin de `machineId` local | ✅ OK |
| `archive_message.ts` | Pas besoin de `machineId` local | ✅ OK |

**MessageManager.ts** : ✅ OK - Ne lit jamais `sync-config.json`, prend `from` en paramètre.

---

## 🛠️ Solution Proposée

### Approche A : Utiliser `loadRooSyncConfig()` (RECOMMANDÉE)

**Avantages** :
- ✅ Utilise la source de vérité existante
- ✅ Validation automatique du `machineId`
- ✅ Cohérence avec le reste du système
- ✅ Une seule fonction à maintenir

**Implémentation** :

```typescript
import { loadRooSyncConfig } from '../../config/roosync-config.js';

function getLocalMachineId(): string {
  const config = loadRooSyncConfig();
  return config.machineId;
}
```

**Fichiers à modifier** :

1. `send_message.ts:46-64`
2. `amend_message.ts:34-52`
3. `read_inbox.ts:31-49`

**Diff type pour `send_message.ts`** :

```diff
- import { existsSync, readFileSync } from 'fs';
- import { join } from 'path';
+ import { loadRooSyncConfig } from '../../config/roosync-config.js';

- function getLocalMachineId(sharedStatePath: string): string {
-   const configPath = join(sharedStatePath, 'sync-config.json');
-   
-   if (!existsSync(configPath)) {
-     throw new Error(`Fichier introuvable`);
-   }
-   
-   try {
-     const configContent = readFileSync(configPath, 'utf-8');
-     const config = JSON.parse(configContent);
-     
-     if (!config.machineId) {
-       throw new Error('machineId absent');
-     }
-     
-     return config.machineId;
-   } catch (error) {
-     throw new Error(`Erreur lecture`);
-   }
- }
+ function getLocalMachineId(): string {
+   const config = loadRooSyncConfig();
+   return config.machineId;
+ }

  export async function sendMessage(args: SendMessageArgs): Promise<...> {
-   const from = getLocalMachineId(sharedStatePath);
+   const from = getLocalMachineId();
```

---

### Approche B : Créer Fonction Centralisée (Alternative)

**Fichier** : `src/utils/get-machine-id.ts`

```typescript
import { loadRooSyncConfig } from '../config/roosync-config.js';

export function getLocalMachineId(): string {
  const config = loadRooSyncConfig();
  return config.machineId;
}
```

**Avantage** : Point d'entrée unique pour obtenir le `machineId`.

---

## ⚠️ Impact et Risques

### Impact du Bug Actuel

**Sévérité** : 🔴 **CRITIQUE**

| Outil | Impact | Exemple |
|-------|--------|---------|
| `roosync_send_message` | Message envoyé avec mauvais expéditeur | `myia-ai-01` envoie avec `from: "myia-po-2024"` |
| `roosync_amend_message` | Amendement refusé | Impossible d'amender ses propres messages |
| `roosync_read_inbox` | Lit inbox d'une autre machine | `myia-ai-01` lit inbox de `myia-po-2024` |

### Blocage Utilisateur

**Contexte** : Impossible d'envoyer le message de suivi via `roosync_send_message` tant que le bug n'est pas corrigé.

**Raison** : Le message serait envoyé avec `from: "myia-po-2024"` au lieu de `from: "myia-ai-01"`.

---

## 🎯 Plan de Correction

### Étape 1 : Validation Approche (VOUS ÊTES ICI)

**Action** : Choisir entre Approche A (recommandée) ou Approche B.

**Question** : Quelle approche préférez-vous ?
- **Approche A** : Modifier directement `getLocalMachineId()` dans les 3 fichiers
- **Approche B** : Créer `utils/get-machine-id.ts` centralisé

### Étape 2 : Implémentation Correction

**Fichiers à modifier** :
1. `send_message.ts` (lignes 46-97)
2. `amend_message.ts` (lignes 34-81)
3. `read_inbox.ts` (lignes 31-117)

**Actions** :
- Remplacer fonction `getLocalMachineId(sharedStatePath)` bugguée
- Supprimer imports inutiles
- Ajouter import `loadRooSyncConfig`
- Tester avec message réel

### Étape 3 : Correction `sync-config.json` (Optionnel)

**Action** : Supprimer `machineId` global de `sync-config.json`.

**Avant** :
```json
{
  "version": "2.0.0",
  "machineId": "myia-po-2024",
  "machines": {}
}
```

**Après** :
```json
{
  "version": "2.0.0",
  "machines": {}
}
```

**Raison** : Éviter confusion future.

### Étape 4 : Tests

**Tests unitaires** :
- Vérifier que `getLocalMachineId()` retourne `.env:ROOSYNC_MACHINE_ID`
- Vérifier que les messages sont envoyés avec le bon `from`

**Tests E2E** :
1. `myia-ai-01` envoie message
2. `myia-ai-01` lit inbox
3. `myia-ai-01` amende message

### Étape 5 : Rebuild et Déploiement

```bash
cd mcps/internal/servers/roo-state-manager
npm run build
```

### Étape 6 : Documentation

**Fichiers à mettre à jour** :
- `docs/roosync/messaging-system-guide.md`
- `docs/integration/02-points-integration-roosync.md`
- `mcps/internal/servers/roo-state-manager/README.md`

---

## 📚 Références

### Fichiers Analysés

| Fichier | Rôle | Status |
|---------|------|--------|
| `roosync-config.ts` | Source de vérité `machineId` | ✅ OK |
| `send_message.ts` | Outil messaging | ❌ Buggué |
| `amend_message.ts` | Outil messaging | ❌ Buggué |
| `read_inbox.ts` | Outil messaging | ❌ Buggué |
| `reply_message.ts` | Outil messaging | ✅ OK |
| `MessageManager.ts` | Service messaging | ✅ OK |
| `sync-config.json` | Config partagée | ⚠️ Contient `machineId` superflu |

### Recherche Sémantique Effectuée

**Query** : `machineId configuration sync-config.json RooSync messaging getLocalMachineId`

**Résultats** : 50+ occurrences analysées, bug identifié dans 3 fichiers.

---

## ✅ Conclusion

**Bug confirmé** : 3 outils messaging lisent `machineId` depuis `sync-config.json` au lieu de `.env`.

**Solution recommandée** : **Approche A** - Utiliser `loadRooSyncConfig().machineId` directement.

**Prochaine étape** : **Validation utilisateur** pour choisir approche et autoriser implémentation.

---

**Rapport généré le** : 2025-10-20  
**Agent** : myia-ai-01  
**Mode** : Code (claude-sonnet-4-5)