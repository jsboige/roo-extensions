# 🐛 Bug Critique : Corruption JSON de mcp_settings.json

## 📋 Résumé Exécutif

**Sévérité :** 🔴 CRITIQUE  
**Impact :** Corruption du fichier de configuration MCP, blocage possible du système  
**Cause racine identifiée :** ✅ Trouvée dans `quickfiles-server/src/index.ts` (`../../mcps/internal/servers/quickfiles-server/src/index.ts`)  
**Status :** 🔍 Diagnostiqué - Correctif à implémenter

---

## 🎯 Description du Bug

Le fichier `mcp_settings.json` (`C:/Users/MYIA/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`) peut être **corrompu** lors de l'utilisation de l'outil `restart_mcp_servers` du serveur MCP Quickfiles, entraînant :

- Ajout de braces `}` en trop à la fin du fichier
- Contenu JSON invalide
- Impossibilité de démarrer les serveurs MCP
- Perte potentielle de configuration

---

## 🔍 Investigation

### Étape 1 : Examen du Fichier Corrompu

Le fichier `mcp_settings.json` actuel (examiné le 2025-10-13) est **valide** et se termine correctement à la ligne 513 :

```json
  }
}
```

✅ **Conclusion :** Le fichier n'est pas actuellement corrompu, mais le bug existe toujours et peut se reproduire.

### Étape 2 : Identification des Outils Suspects

Deux outils modifient `mcp_settings.json` :

1. ✅ **`roo-state-manager/manage-mcp-settings.ts` (`../../mcps/internal/servers/roo-state-manager/src/tools/manage-mcp-settings.ts`)** - Code correct avec mécanisme de sécurité
2. ❌ **`quickfiles-server/index.ts` (`../../mcps/internal/servers/quickfiles-server/src/index.ts`)** - **CONTIENT LE BUG**

---

## 🐛 Analyse de la Cause Racine

### Code Problématique

```typescript
// quickfiles-server/src/index.ts:813-839
private async handleRestartMcpServers(args: z.infer<typeof RestartMcpServersArgsSchema>) {
    const { servers } = args;
    const settingsPath = 'C:/Users/MYIA/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json';
    const results = [];
    try {
      // ❌ LECTURE UNIQUE AU DÉBUT
      const settingsRaw = await fs.readFile(settingsPath, 'utf-8');
      const settings = JSON.parse(settingsRaw);
      
      if (!settings.mcpServers) {
        throw new Error("La section 'mcpServers' est manquante dans le fichier de configuration.");
      }
      
      // ❌ BOUCLE AVEC ÉCRITURES MULTIPLES SANS RELECTURE
      for (const serverName of servers) {
        if (settings.mcpServers[serverName]) {
            settings.mcpServers[serverName].enabled = false;
            await fs.writeFile(settingsPath, JSON.stringify(settings, null, 2)); // ⚠️ ÉCRITURE 1
            await new Promise(resolve => setTimeout(resolve, 1000));
            settings.mcpServers[serverName].enabled = true;
            await fs.writeFile(settingsPath, JSON.stringify(settings, null, 2)); // ⚠️ ÉCRITURE 2
            results.push({ server: serverName, status: 'success' });
        } else {
            results.push({ server: serverName, status: 'error', reason: 'Server not found in settings' });
        }
      }
    } catch (error) {
       return { content: [{ type: 'text' as const, text: `Erreur lors du redémarrage des serveurs: ${(error as Error).message}` }]};
    }
    return { content: [{ type: 'text' as const, text: JSON.stringify(results) }] };
}
```

### Problèmes Identifiés

#### 🔴 **PROBLÈME 1 : Écritures Multiples Sans Relecture**

**Nature :** Le fichier est lu **UNE SEULE FOIS** (ligne 818), puis écrit **2 fois par serveur** sans jamais relire entre les écritures.

**Scénario de corruption :**

```
Temps T0: Lecture initiale de mcp_settings.json
Temps T1: Écriture 1 (server-a.enabled = false)
Temps T2: Attente 1 seconde
Temps T3: Écriture 2 (server-a.enabled = true)
Temps T4: Écriture 3 (server-b.enabled = false)  ← Écrase TOUT depuis T0, pas depuis T3 !
Temps T5: Attente 1 seconde
Temps T6: Écriture 4 (server-b.enabled = true)   ← Écrase TOUT depuis T0, pas depuis T5 !
```

**Risque :** Si le fichier a été modifié par un autre processus entre T0 et T6, ces modifications seront **écrasées**.

#### 🔴 **PROBLÈME 2 : Race Condition avec Autres Outils**

**Scénario critique :**

```
Process A (quickfiles-server):        Process B (roo-state-manager):
T0: Lit mcp_settings.json              
T1: Modifie en mémoire (server-a)      
T2:                                    T2: Lit mcp_settings.json
T3:                                    T3: Modifie en mémoire (server-c)
T4: Écrit sur disque (server-a)        
T5:                                    T5: Écrit sur disque (server-c) ← ÉCRASE les modifications de Process A !
```

**Résultat :** Les modifications du Process A sont **perdues**.

#### 🔴 **PROBLÈME 3 : Pas d'Écriture Atomique**

**Risque :** Si le processus Node.js est interrompu (crash, kill, panne) pendant `fs.writeFile` :
- Le fichier peut être **tronqué** (partiellement écrit)
- Le JSON devient **invalide**
- Les braces `}` manquantes ou en trop

**Pattern d'écriture non-sécurisé :**
```typescript
// ❌ MAUVAIS - Écriture directe
await fs.writeFile(path, JSON.stringify(data));
```

**Pattern d'écriture sécurisé :**
```typescript
// ✅ BON - Écriture atomique avec fichier temporaire
const tmpPath = path + '.tmp';
await fs.writeFile(tmpPath, JSON.stringify(data, null, 2), 'utf-8');
await fs.rename(tmpPath, path); // Atomique sur la plupart des systèmes
```

#### 🟡 **PROBLÈME 4 : Pas de Validation Après Écriture**

Aucune vérification que :
- Le fichier a bien été écrit
- Le JSON est valide après écriture
- La structure du fichier est intacte

---

## 💡 Solutions Proposées

### Solution 1 : Correction Minimale (Recommandée pour Fix Rapide)

**Approche :** Relire le fichier avant chaque écriture dans la boucle.

**Diff :**

```diff
--- a/mcps/internal/servers/quickfiles-server/src/index.ts
+++ b/mcps/internal/servers/quickfiles-server/src/index.ts
@@ -813,24 +813,32 @@ private async handleRestartMcpServers(args: z.infer<typeof RestartMcpServersArg
   const { servers } = args;
   const settingsPath = 'C:/Users/MYIA/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json';
   const results = [];
   try {
-    const settingsRaw = await fs.readFile(settingsPath, 'utf-8');
-    const settings = JSON.parse(settingsRaw);
-    if (!settings.mcpServers) {
-      throw new Error("La section 'mcpServers' est manquante dans le fichier de configuration.");
-    }
     for (const serverName of servers) {
-      if (settings.mcpServers[serverName]) {
-          settings.mcpServers[serverName].enabled = false;
-          await fs.writeFile(settingsPath, JSON.stringify(settings, null, 2));
+      // ✅ Relire le fichier avant chaque modification
+      let settingsRaw = await fs.readFile(settingsPath, 'utf-8');
+      let settings = JSON.parse(settingsRaw);
+      
+      if (!settings.mcpServers) {
+        throw new Error("La section 'mcpServers' est manquante dans le fichier de configuration.");
+      }
+      
+      if (settings.mcpServers[serverName]) {
+          // Désactiver
+          settings.mcpServers[serverName].enabled = false;
+          await fs.writeFile(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
           await new Promise(resolve => setTimeout(resolve, 1000));
-          settings.mcpServers[serverName].enabled = true;
-          await fs.writeFile(settingsPath, JSON.stringify(settings, null, 2));
+          
+          // ✅ Relire à nouveau avant de réactiver
+          settingsRaw = await fs.readFile(settingsPath, 'utf-8');
+          settings = JSON.parse(settingsRaw);
+          
+          // Réactiver
+          settings.mcpServers[serverName].enabled = true;
+          await fs.writeFile(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
           results.push({ server: serverName, status: 'success' });
       } else {
           results.push({ server: serverName, status: 'error', reason: 'Server not found in settings' });
       }
     }
   } catch (error) {
```

**Avantages :**
- ✅ Fix simple et rapide
- ✅ Réduit fortement les risques de race condition
- ✅ Compatible avec le code existant

**Inconvénients :**
- ⚠️ Ne résout pas complètement les race conditions
- ⚠️ Pas d'écriture atomique

---

### Solution 2 : Écriture Atomique avec Fichier Temporaire (Recommandée pour Production)

**Approche :** Utiliser un fichier temporaire et `rename` atomique.

**Code :**

```typescript
private async handleRestartMcpServers(args: z.infer<typeof RestartMcpServersArgsSchema>) {
  const { servers } = args;
  const settingsPath = 'C:/Users/MYIA/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json';
  const results = [];
  
  // ✅ Fonction d'écriture atomique
  const writeSettingsAtomic = async (settings: any): Promise<void> => {
    const tmpPath = settingsPath + '.tmp';
    const content = JSON.stringify(settings, null, 2);
    
    // Valider le JSON avant écriture
    JSON.parse(content);
    
    // Écrire dans un fichier temporaire
    await fs.writeFile(tmpPath, content, 'utf-8');
    
    // Renommer atomiquement (la plupart des FS garantissent l'atomicité)
    await fs.rename(tmpPath, settingsPath);
  };
  
  try {
    for (const serverName of servers) {
      // ✅ Relire avant chaque modification
      const settingsRaw = await fs.readFile(settingsPath, 'utf-8');
      const settings = JSON.parse(settingsRaw);
      
      if (!settings.mcpServers) {
        throw new Error("La section 'mcpServers' est manquante dans le fichier de configuration.");
      }
      
      if (settings.mcpServers[serverName]) {
        // Désactiver
        settings.mcpServers[serverName].enabled = false;
        await writeSettingsAtomic(settings); // ✅ Écriture atomique
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // Relire à nouveau
        const settingsRaw2 = await fs.readFile(settingsPath, 'utf-8');
        const settings2 = JSON.parse(settingsRaw2);
        
        // Réactiver
        settings2.mcpServers[serverName].enabled = true;
        await writeSettingsAtomic(settings2); // ✅ Écriture atomique
        
        results.push({ server: serverName, status: 'success' });
      } else {
        results.push({ server: serverName, status: 'error', reason: 'Server not found in settings' });
      }
    }
  } catch (error) {
    return { content: [{ type: 'text' as const, text: `Erreur lors du redémarrage des serveurs: ${(error as Error).message}` }]};
  }
  
  return { content: [{ type: 'text' as const, text: JSON.stringify(results) }] };
}
```

**Avantages :**
- ✅ Écriture atomique (pas de corruption partielle)
- ✅ Validation JSON avant écriture
- ✅ Protection contre les interruptions de processus
- ✅ Relecture entre chaque modification

**Inconvénients :**
- ⚠️ Légèrement plus complexe
- ⚠️ Ne résout toujours pas les race conditions entre processus

---

### Solution 3 : Lock File (Recommandée pour Robustesse Maximum)

**Approche :** Utiliser un fichier de verrouillage pour empêcher les écritures concurrentes.

**Installation dépendance :**
```bash
npm install proper-lockfile
```

**Code :**

```typescript
import lockfile from 'proper-lockfile';

private async handleRestartMcpServers(args: z.infer<typeof RestartMcpServersArgsSchema>) {
  const { servers } = args;
  const settingsPath = 'C:/Users/MYIA/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json';
  const results = [];
  
  // ✅ Fonction d'écriture atomique avec lock
  const writeSettingsWithLock = async (settings: any): Promise<void> => {
    const tmpPath = settingsPath + '.tmp';
    const content = JSON.stringify(settings, null, 2);
    
    // Valider le JSON
    JSON.parse(content);
    
    // Acquérir le lock
    const release = await lockfile.lock(settingsPath, {
      retries: {
        retries: 10,
        minTimeout: 100,
        maxTimeout: 1000
      }
    });
    
    try {
      // Écrire atomiquement
      await fs.writeFile(tmpPath, content, 'utf-8');
      await fs.rename(tmpPath, settingsPath);
    } finally {
      // Toujours libérer le lock
      await release();
    }
  };
  
  try {
    for (const serverName of servers) {
      // ✅ Acquérir le lock pour la lecture
      const releaseLock = await lockfile.lock(settingsPath, {
        retries: { retries: 10, minTimeout: 100, maxTimeout: 1000 }
      });
      
      try {
        const settingsRaw = await fs.readFile(settingsPath, 'utf-8');
        const settings = JSON.parse(settingsRaw);
        
        if (!settings.mcpServers) {
          throw new Error("La section 'mcpServers' est manquante dans le fichier de configuration.");
        }
        
        if (settings.mcpServers[serverName]) {
          // Désactiver
          settings.mcpServers[serverName].enabled = false;
          await writeSettingsWithLock(settings); // ✅ Écriture avec lock
          await new Promise(resolve => setTimeout(resolve, 1000));
          
          // Relire
          const settingsRaw2 = await fs.readFile(settingsPath, 'utf-8');
          const settings2 = JSON.parse(settingsRaw2);
          
          // Réactiver
          settings2.mcpServers[serverName].enabled = true;
          await writeSettingsWithLock(settings2); // ✅ Écriture avec lock
          
          results.push({ server: serverName, status: 'success' });
        } else {
          results.push({ server: serverName, status: 'error', reason: 'Server not found in settings' });
        }
      } finally {
        await releaseLock();
      }
    }
  } catch (error) {
    return { content: [{ type: 'text' as const, text: `Erreur lors du redémarrage des serveurs: ${(error as Error).message}` }]};
  }
  
  return { content: [{ type: 'text' as const, text: JSON.stringify(results) }] };
}
```

**Avantages :**
- ✅ Écriture atomique
- ✅ Protection totale contre les race conditions
- ✅ Retry automatique si le fichier est verrouillé
- ✅ Solution robuste pour la production

**Inconvénients :**
- ⚠️ Nécessite une dépendance externe
- ⚠️ Plus complexe à implémenter

---

## 🧪 Tests de Validation

### Test 1 : Redémarrage Multiple de Serveurs

```typescript
// Tester le redémarrage de plusieurs serveurs en même temps
await restart_mcp_servers({ servers: ['quickfiles', 'roo-state-manager', 'git'] });

// Vérifier que mcp_settings.json est toujours valide
const settings = JSON.parse(await fs.readFile(settingsPath, 'utf-8'));
console.assert(settings.mcpServers !== undefined);
```

### Test 2 : Race Condition Simulée

```typescript
// Lancer deux redémarrages en parallèle
const [result1, result2] = await Promise.all([
  restart_mcp_servers({ servers: ['quickfiles'] }),
  restart_mcp_servers({ servers: ['git'] })
]);

// Vérifier que le fichier n'est pas corrompu
const settings = JSON.parse(await fs.readFile(settingsPath, 'utf-8'));
console.assert(settings.mcpServers.quickfiles !== undefined);
console.assert(settings.mcpServers.git !== undefined);
```

### Test 3 : Interruption de Processus

```bash
# Lancer le redémarrage puis kill le processus pendant l'écriture
node test-restart.js &
PID=$!
sleep 0.5
kill -9 $PID

# Vérifier que le fichier n'est pas corrompu
cat mcp_settings.json | jq . # Doit afficher du JSON valide
```

---

## 📊 Impact et Recommandations

### Impact du Bug

| Critère | Évaluation | Note |
|---------|------------|------|
| **Fréquence** | Moyenne (arrive lors des redémarrages multiples) | ⚠️ |
| **Sévérité** | Critique (bloque tout le système MCP) | 🔴 |
| **Détectabilité** | Faible (corruption silencieuse) | 🔴 |
| **Risque Global** | **ÉLEVÉ** | 🔴🔴🔴 |

### Recommandations

1. **Court terme (Urgent - 1-2 jours)** 🔴
   - Implémenter **Solution 1** (relecture avant écriture)
   - Créer une sauvegarde automatique de `mcp_settings.json` avant chaque écriture
   - Documenter le problème pour les utilisateurs

2. **Moyen terme (1 semaine)** 🟡
   - Implémenter **Solution 2** (écriture atomique)
   - Ajouter des tests unitaires
   - Créer un script de réparation pour les fichiers corrompus

3. **Long terme (1 mois)** 🟢
   - Implémenter **Solution 3** (lock file)
   - Centraliser la gestion de `mcp_settings.json` dans un seul service
   - Créer un mécanisme de validation automatique

---

## 🛠️ Script de Réparation

Pour réparer un `mcp_settings.json` corrompu :

```typescript
// repair-mcp-settings.ts
import * as fs from 'fs/promises';
import * as path from 'path';

const SETTINGS_PATH = 'C:/Users/MYIA/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json';

async function repairMcpSettings() {
  try {
    // Lire le fichier
    const content = await fs.readFile(SETTINGS_PATH, 'utf-8');
    
    // Essayer de parser comme JSON
    try {
      const settings = JSON.parse(content);
      console.log('✅ Le fichier est déjà valide !');
      return;
    } catch (parseError) {
      console.log('⚠️ Le fichier est corrompu, tentative de réparation...');
      
      // Chercher les braces en trop
      let cleaned = content;
      
      // Supprimer les braces finales en trop
      const lastBrace = cleaned.lastIndexOf('}');
      cleaned = cleaned.substring(0, lastBrace + 1);
      
      // Essayer de parser à nouveau
      const settings = JSON.parse(cleaned);
      
      // Créer une sauvegarde
      const backupPath = SETTINGS_PATH + '.backup.' + Date.now();
      await fs.writeFile(backupPath, content, 'utf-8');
      console.log(`📁 Sauvegarde créée: ${backupPath}`);
      
      // Écrire le fichier réparé
      await fs.writeFile(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf-8');
      console.log('✅ Fichier réparé avec succès !');
    }
  } catch (error) {
    console.error('❌ Impossible de réparer le fichier:', error);
    console.log('💡 Restaurez manuellement depuis une sauvegarde');
  }
}

repairMcpSettings();
```

---

## 📚 Références

- [Node.js fs.writeFile Documentation](https://nodejs.org/api/fs.html#fspromiseswritefilefile-data-options)
- [Atomic File Writes Pattern](https://github.com/nodejs/node/issues/7005)
- [proper-lockfile npm package](https://www.npmjs.com/package/proper-lockfile)
- [Race Conditions in File Systems](https://en.wikipedia.org/wiki/Race_condition#File_systems)

---

**Dernière mise à jour :** 2025-10-13T15:14:00Z  
**Analyste :** Roo Debug  
**Status :** ✅ Diagnostiqué - En attente d'implémentation du correctif