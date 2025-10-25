# PATTERN 8 Fix - Extraction Instructions newTask depuis ask/tool

**Date** : 21 octobre 2025, 03:10 UTC+2  
**Auteur** : Roo Debug Mode  
**Mission** : Corriger l'extraction des instructions newTask dans le squelette de la tâche `cb7e564f-152f-48e3-8eff-f424d7ebc6bd`

---

## 🎯 Problème Identifié

Le squelette de la tâche `cb7e564f-152f-48e3-8eff-f424d7ebc6bd` ne contenait **PAS** le champ `childTaskInstructionPrefixes`, empêchant le matching hiérarchique des sous-tâches.

**Cause** : Le PATTERN 7 récemment ajouté cherchait uniquement les messages de type `{type: 'say', say: 'api_req_started'}`, mais le format réel observé dans cb7e564f est :

```json
{
  "ts": 1756539267433,
  "type": "ask",
  "ask": "tool",
  "text": "{\"tool\":\"newTask\",\"mode\":\"🪲 Debug\",\"content\":\"Bonjour. Nous sommes à la dernière étape...\"}"
}
```

---

## ✅ Solution Appliquée : PATTERN 8

Un nouveau pattern a été ajouté dans [`roo-storage-detector.ts`](../mcps/internal/servers/roo-state-manager/src/utils/roo-storage-detector.ts) après le PATTERN 7 (ligne ~1428).

### Code du PATTERN 8

```typescript
// 🎯 PATTERN 8: Messages ask/tool avec newTask stringifié (FIX pour cb7e564f)
// Détecte spécifiquement: {type:"ask", ask:"tool", text:"{\"tool\":\"newTask\",...}"}
// Ce pattern est TOUJOURS ACTIF pour assurer la capture des instructions newTask
if (message.type === 'ask' && (message as any).ask === 'tool' && typeof message.text === 'string') {
  try {
    // Parser le JSON stringifié dans message.text
    const toolData = JSON.parse(message.text);
    
    // Vérifier que c'est bien un message newTask avec du contenu
    if (toolData && 
        toolData.tool === 'newTask' && 
        typeof toolData.content === 'string' && 
        toolData.content.trim().length > 20) {
      
      // Nettoyer le mode (retirer les emojis et caractères spéciaux)
      const rawMode = String(toolData.mode || 'task');
      const cleanMode = rawMode.replace(/[^\w\s]/g, '').trim().toLowerCase();
      
      const instruction: NewTaskInstruction = {
        timestamp: new Date(message.timestamp || (message as any).ts || 0).getTime(),
        mode: cleanMode || 'task',
        message: toolData.content.trim()
      };
      
      instructions.push(instruction);
      
      if (process.env.ROO_DEBUG_INSTRUCTIONS === '1') {
        console.log(`[extractFromMessageFile] ✅ PATTERN 8: newTask depuis ask/tool stringifié: mode=${cleanMode}, len=${toolData.content.length}`);
      }
    }
  } catch (e) {
    // Parsing JSON échoué, ignorer ce message
    if (process.env.ROO_DEBUG_INSTRUCTIONS === '1') {
      console.log(`[extractFromMessageFile] ⚠️ PATTERN 8: Failed to parse ask/tool message.text as JSON:`, e);
    }
  }
}
```

---

## 🔍 Logique de Détection

1. **Condition de Déclenchement** :
   - `message.type === 'ask'` 
   - `message.ask === 'tool'`
   - `message.text` est une string (JSON stringifié)

2. **Parsing** :
   - Parse `message.text` comme JSON
   - Extrait `toolData.tool`, `toolData.mode`, `toolData.content`

3. **Validation** :
   - Vérifie `toolData.tool === 'newTask'`
   - Vérifie que `toolData.content` est une string de > 20 caractères

4. **Normalisation** :
   - Nettoie le mode en retirant emojis et caractères spéciaux
   - Crée l'instruction avec timestamp, mode normalisé, et contenu

5. **Debug Logging** :
   - Si `ROO_DEBUG_INSTRUCTIONS=1`, log les détections réussies

---

## 🧪 Instructions de Test

### Étape 1 : Rebuild du MCP

```powershell
cd mcps/internal/servers/roo-state-manager
npm run build
```

✅ **Build réussi** (vérifié le 21/10/2025 à 03:10)

### Étape 2 : Redémarrer le MCP

Via l'outil `rebuild_and_restart_mcp` :

```json
{
  "mcp_name": "roo-state-manager"
}
```

### Étape 3 : Forcer la Reconstruction du Squelette

Utiliser l'outil `build_skeleton_cache` avec :

```json
{
  "force_rebuild": true,
  "workspace_filter": "d:/Dev/roo-extensions"
}
```

Ou cibler spécifiquement la tâche cb7e564f :

```bash
# Via MCP ou script personnalisé
rebuild_skeleton("cb7e564f-152f-48e3-8eff-f424d7ebc6bd")
```

### Étape 4 : Vérifier le Squelette

Utiliser `get_task_tree` ou `view_conversation_tree` pour vérifier que le squelette de `cb7e564f` contient maintenant :

```json
{
  "childTaskInstructionPrefixes": [
    {
      "timestamp": 1756539267433,
      "mode": "debug",  // ou "debug" nettoyé de "🪲 Debug"
      "prefix": "Bonjour. Nous sommes à la dernière étape..."
    }
  ]
}
```

---

## 📊 Impact Attendu

- **Tâche cb7e564f** : Le champ `childTaskInstructionPrefixes` devrait maintenant être correctement extrait
- **Matching Hiérarchique** : Les sous-tâches déléguées via `newTask` seront correctement reliées à leur parent
- **Autres Tâches** : Toutes les tâches utilisant le format `{type:"ask", ask:"tool"}` bénéficieront de ce fix

---

## ⚠️ Notes Importantes

1. **PATTERN 8 est TOUJOURS ACTIF** : Contrairement à certains patterns désactivables via `onlyJsonFormat`, celui-ci s'exécute systématiquement pour garantir la capture des instructions newTask.

2. **Complémentarité avec PATTERN 7** : PATTERN 7 détecte les balises `<task>` dans `api_req_started`, PATTERN 8 détecte les messages `ask/tool` stringifiés. Les deux coexistent sans conflit.

3. **Normalisation du Mode** : Les emojis (ex: "🪲") sont retirés du mode pour assurer la cohérence avec les autres squelettes.

4. **Sécurité** : Le parsing JSON est entouré d'un try/catch pour éviter les crashes sur des messages malformés.

---

## 🚀 Prochaines Étapes (par l'Orchestrateur)

1. ✅ **Code ajouté et compilé avec succès**
2. ⏳ **Rebuild du MCP** (à faire)
3. ⏳ **Vérification du squelette cb7e564f** (à valider)
4. ⏳ **Test du matching hiérarchique** (à confirmer)

---

## 📝 Changelog

| Date | Action | Détail |
|------|--------|--------|
| 2025-10-21 03:10 | Création PATTERN 8 | Ajout du pattern ask/tool stringifié |
| 2025-10-21 03:10 | Build réussi | Compilation TypeScript OK |
| 2025-10-21 03:10 | Documentation | Création de ce fichier |

---

**Fin du rapport PATTERN 8 Fix**