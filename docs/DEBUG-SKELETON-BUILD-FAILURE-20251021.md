# 🐛 Rapport Debug : Échec Construction Squelettes cb7e564f et 18141742

**Date:** 2025-10-21 02:55 UTC+2  
**Analyste:** Debug Mode  
**Priorité:** 🔴 CRITIQUE

---

## 📋 Résumé Exécutif

**Problème:** Le rebuild du cache de squelettes a retourné "Built: 2" mais les fichiers `.skeleton` n'existent PAS sur disque pour deux tâches.

**Cause racine identifiée:** Le parsing des balises `<task>` est **désactivé** dans `extractNewTaskInstructionsFromUI()` via le flag `onlyJsonFormat=true`, empêchant l'extraction des instructions pour ces tâches.

---

## 🔍 Analyse Détaillée

### 1. Tâches Problématiques

- **cb7e564f-152f-48e3-8eff-f424d7ebc6bd** : Validation MCP github-projects
- **18141742-f376-4053-8e1f-804d79daaf6d** : Validation post-refactorisation

### 2. Pattern de Message Détecté

Les deux tâches commencent avec un message contenant une **balise `<task>`** (et NON `<new_task>`) :

```json
{
  "ts": 1754311157689,
  "type": "say",
  "say": "text",
  "text": "Bonjour,\n\n**Mission :**\n..."
}
{
  "ts": 1754311158627,
  "type": "say",
  "say": "api_req_started",
  "text": "{\"request\":\"<task>\\nBonjour,\\n\\n**Mission :**\\n...\\n</task>\\n\\n<environment_details>..."
}
```

### 3. Code Problématique

**Fichier:** [`mcps/internal/servers/roo-state-manager/src/utils/roo-storage-detector.ts`](mcps/internal/servers/roo-state-manager/src/utils/roo-storage-detector.ts)

#### Ligne 1034 : Appel avec `onlyJsonFormat=true`

```typescript
private static async extractNewTaskInstructionsFromUI(
  uiMessagesPath: string,
  maxLines: number = 0
): Promise<NewTaskInstruction[]> {
  const instructions: NewTaskInstruction[] = [];
  
  // 🎯 CORRECTION CRITIQUE : Extraire UNIQUEMENT depuis ui_messages.json
  await this.extractFromMessageFile(uiMessagesPath, instructions, maxLines, true);
  //                                                                           ^^^^
  //                                                               onlyJsonFormat=TRUE
  
  return instructions;
}
```

#### Lignes 1216-1235 : Pattern désactivé

```typescript
// 🎯 PATTERN 2: Balises task simples (user/assistant) - DÉSACTIVÉ si onlyJsonFormat
if (!onlyJsonFormat) {  // <--- ❌ PATTERN DÉSACTIVÉ
  const taskPattern = /<task>([\s\S]*?)<\/task>/gi;
  let taskMatch;
  while ((taskMatch = taskPattern.exec(contentText)) !== null) {
    const taskContent = taskMatch[1].trim();
    
    if (taskContent.length > 20) { // Filtrer les contenus trop courts
      const instruction: NewTaskInstruction = {
        timestamp: new Date(message.timestamp || message.ts || 0).getTime(),
        mode: 'task',
        message: taskContent,
      };
      instructions.push(instruction);
      console.log(`✅ BALISE TASK SIMPLE AJOUTÉE: ${taskContent.substring(0, 50)}...`);
    } else {
      console.log(`⚠️ BALISE TASK REJETÉE (trop courte: ${taskContent.length} chars)`);
    }
  }
}
```

### 4. Chaîne de Causalité

```
1. extractNewTaskInstructionsFromUI(uiMessagesPath)
   └─> appelle extractFromMessageFile(..., onlyJsonFormat=true)
       └─> PATTERN 2 (balises <task>) DÉSACTIVÉ
           └─> instructions[] reste VIDE
               └─> childTaskInstructionPrefixes[] reste VIDE
                   └─> Squelette NON construit
                       └─> Fichier .skeleton ABSENT
```

### 5. Impact

- ❌ Aucune instruction extraite pour cb7e564f et 18141742
- ❌ `childTaskInstructionPrefixes` vide
- ❌ Index radix-tree incomplet
- ❌ Hiérarchies parent-enfant brisées
- ⚠️ Autres tâches utilisant `<task>` potentiellement affectées

---

## 🎯 Solutions Proposées

### Option A : Activer le parsing des balises `<task>` (RECOMMANDÉ)

**Changement:** Ligne 1034, passer `onlyJsonFormat=false`

```typescript
await this.extractFromMessageFile(uiMessagesPath, instructions, maxLines, false);
//                                                                           ^^^^^
//                                                                           ACTIVÉ
```

**Avantages:**
- ✅ Fix immédiat, minimal
- ✅ Support complet des balises `<task>`
- ✅ Rétrocompatibilité

**Inconvénients:**
- ⚠️ Risque de contamination XML si `api_conversation_history.json` contient des balises condensées
- ⚠️ Nécessite validation que seul `ui_messages.json` est parsé

### Option B : Ajouter un pattern spécifique pour `<task>` en mode JSON

**Changement:** Ajouter un nouveau pattern après ligne 1388

```typescript
// PATTERN 7: Balises <task> dans api_req_started (TOUJOURS ACTIF)
if (message.type === 'say' && message.say === 'api_req_started' && typeof message.text === 'string') {
  try {
    const apiData = JSON.parse(message.text);
    
    if (apiData && typeof apiData.request === 'string') {
      const taskPattern = /<task>([\s\S]*?)<\/task>/gi;
      let taskMatch;
      
      while ((taskMatch = taskPattern.exec(apiData.request)) !== null) {
        const taskContent = taskMatch[1].trim();
        
        if (taskContent.length > 20) {
          const instruction: NewTaskInstruction = {
            timestamp: new Date(message.timestamp || message.ts || 0).getTime(),
            mode: 'task',
            message: taskContent,
          };
          instructions.push(instruction);
        }
      }
    }
  } catch (e) {
    // Parsing failed, continue
  }
}
```

**Avantages:**
- ✅ Ciblé sur le format réel des tâches problématiques
- ✅ Pas de risque de contamination
- ✅ Mode JSON strict maintenu

**Inconvénients:**
- ⚠️ Code dupliqué
- ⚠️ Maintenance plus complexe

### Option C : Analyse conditionnelle basée sur le contenu

**Approche:** Détecter dynamiquement si `ui_messages.json` contient des balises `<task>` avant de choisir le mode de parsing.

---

## 🧪 Plan de Test

1. **Validation du fix:**
   ```bash
   # Rebuild avec fix appliqué
   roo-state-manager build_skeleton_cache --force_rebuild=false
   
   # Vérifier fichiers créés
   ls -la C:/Users/jsboi/.../tasks/cb7e564f-152f-48e3-8eff-f424d7ebc6bd/.skeleton
   ls -la C:/Users/jsboi/.../tasks/18141742-f376-4053-8e1f-804d79daaf6d/.skeleton
   ```

2. **Vérification de non-régression:**
   - Tester sur 10 tâches utilisant `[new_task in X mode: 'Y']`
   - Vérifier que les patterns PATTERN 5 et 6 fonctionnent toujours

3. **Validation hiérarchique:**
   - Vérifier que les deux tâches apparaissent dans `get_task_tree`
   - Valider les relations parent-enfant

---

## 📊 Métriques

- **Tâches affectées:** 2 confirmées (potentiellement plus)
- **Pattern manquant:** `<task>...</task>` dans api_req_started
- **Temps d'analyse:** ~15 minutes
- **Complexité du fix:** FAIBLE (1 ligne) ou MOYENNE (nouveau pattern)

---

## 🚀 Recommandation

**Approche recommandée:** **Option B** (Pattern spécifique)

**Justification:**
1. Sécurisé : Pas de risque de contamination XML
2. Ciblé : Traite exactement le cas problématique
3. Maintenable : Code isolé, facile à tester
4. Documenté : Pattern clairement identifié

**Prochaine étape:** Implémenter Option B et tester sur les 2 tâches problématiques.

---

## 📝 Notes Additionnelles

- Le commentaire ligne 1030-1033 mentionne explicitement la "contamination XML" comme raison du flag `onlyJsonFormat`
- Les balises `<task>` apparaissent dans `api_req_started.text.request`, pas dans le flux XML condensé
- Aucun risque de contamination si on parse uniquement ce contexte spécifique

**Statut:** ✅ DIAGNOSTIC COMPLET | ⏳ EN ATTENTE DE FIX