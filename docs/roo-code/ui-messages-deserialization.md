# Désérialisation ui_messages.json dans roo-code

## Vue d'ensemble

L'extension roo-code utilise un système de désérialisation simple mais robuste pour traiter les fichiers `ui_messages.json`. Le système repose sur :
1. **Lecture directe JSON** via `JSON.parse()` avec gestion d'erreurs
2. **Schéma de validation Zod** pour garantir la cohérence des types
3. **Parsing sécurisé** via une fonction `safeJsonParse()` pour gérer les cas limites
4. **Aucune regex fragile** contrairement aux approches de parsing manuel

## Fichiers Clés

### roo-code/packages/types/src/message.ts
**Rôle** : Définitions TypeScript complètes des types de messages  
**Classes/Fonctions principales** :
- `ClineMessage` : Type principal pour tous les messages UI
- `clineMessageSchema` : Schéma Zod de validation
- `ClineAsk` : Union des types de questions (12 types)
- `ClineSay` : Union des types de déclarations (30 types)

**Structure ClineMessage** :
```typescript
export const clineMessageSchema = z.object({
	ts: z.number(),                          // Timestamp
	type: z.union([z.literal("ask"), z.literal("say")]),
	ask: clineAskSchema.optional(),          // Type de question
	say: clineSaySchema.optional(),          // Type de déclaration
	text: z.string().optional(),             // Contenu textuel ou JSON stringifié
	images: z.array(z.string()).optional(),  // Images encodées
	partial: z.boolean().optional(),         // Message en cours de streaming
	reasoning: z.string().optional(),        // Raisonnement interne
	conversationHistoryIndex: z.number().optional(),
	checkpoint: z.record(z.string(), z.unknown()).optional(),
	progressStatus: toolProgressStatusSchema.optional(),
	contextCondense: contextCondenseSchema.optional(),
	isProtected: z.boolean().optional(),
	apiProtocol: z.union([z.literal("openai"), z.literal("anthropic")]).optional(),
})
```

### roo-code/src/core/task-persistence/taskMessages.ts
**Rôle** : Lecture/écriture des fichiers `ui_messages.json`  
**Fonctions principales** :
- `readTaskMessages()` : Lit et parse le fichier JSON
- `saveTaskMessages()` : Sauvegarde les messages via `safeWriteJson()`

**Code de désérialisation** :
```typescript
export async function readTaskMessages({
	taskId,
	globalStoragePath,
}: ReadTaskMessagesOptions): Promise<ClineMessage[]> {
	const taskDir = await getTaskDirectoryPath(globalStoragePath, taskId)
	const filePath = path.join(taskDir, GlobalFileNames.uiMessages)
	const fileExists = await fileExistsAtPath(filePath)

	if (fileExists) {
		return JSON.parse(await fs.readFile(filePath, "utf8"))
	}

	return []
}
```

**Liens** : Utilisé par `ClineProvider` pour initialiser les tâches depuis l'historique

### roo-code/src/shared/safeJsonParse.ts
**Rôle** : Parsing JSON sécurisé avec fallback  
**Fonction principale** : `safeJsonParse<T>()`

**Implémentation** :
```typescript
export function safeJsonParse<T>(jsonString: string | null | undefined, defaultValue?: T): T | undefined {
	if (!jsonString) {
		return defaultValue
	}

	try {
		return JSON.parse(jsonString) as T
	} catch (error) {
		console.error("Error parsing JSON:", error)
		return defaultValue
	}
}
```

**Utilisé pour** : Parser le champ `text` des messages contenant du JSON imbriqué

### roo-code/webview-ui/src/components/chat/ChatRow.tsx
**Rôle** : Rendu UI des messages avec parsing contextuel  
**Parsing spécifique** :
```typescript
// Parsing des informations d'API request
const [cost, apiReqCancelReason, apiReqStreamingFailedMessage] = useMemo(() => {
	if (message.text !== null && message.text !== undefined && message.say === "api_req_started") {
		const info = safeJsonParse<ClineApiReqInfo>(message.text)
		return [info?.cost, info?.cancelReason, info?.streamingFailedMessage]
	}
	return [undefined, undefined, undefined]
}, [message.text, message.say])
```

## Types de Messages

### Type "ask" - Demandes utilisateur

**Types supportés** (12 variantes) :
```typescript
export const clineAsks = [
	"followup",                    // Question de clarification
	"command",                     // Permission d'exécuter commande
	"command_output",              // Permission de lire output
	"completion_result",           // Tâche terminée
	"tool",                        // Permission d'utiliser un outil
	"api_req_failed",              // Échec API, retry?
	"resume_task",                 // Confirmation de reprise
	"resume_completed_task",       // Reprise tâche complétée
	"mistake_limit_reached",       // Trop d'erreurs
	"browser_action_launch",       // Permission navigateur
	"use_mcp_server",              // Permission MCP
	"auto_approval_max_req_reached" // Limite auto-approval
] as const
```

**Structure exemple - followup** :
```json
{
	"ts": 1758114669801,
	"type": "ask",
	"ask": "followup",
	"text": "{\"question\":\"What is the path?\",\"follow_up\":[\"./config\",\"./src\"]}"
}
```

**Structure exemple - tool** :
```json
{
	"ts": 1758114676450,
	"type": "ask",
	"ask": "tool",
	"text": "{\"tool\":\"newTask\",\"mode\":\"code\",\"content\":\"Implement feature X\"}",
	"partial": false
}
```

### Type "say" - Déclarations système

**Types supportés** (30 variantes) :
```typescript
export const clineSays = [
	"error",                       // Erreur générale
	"api_req_started",             // Requête API initiée (🔴 IMPORTANT)
	"api_req_finished",            // Requête API terminée
	"api_req_retried",             // Retry requête API
	"api_req_retry_delayed",       // Retry retardé
	"api_req_deleted",             // Requête annulée
	"text",                        // Texte simple
	"reasoning",                   // Raisonnement interne
	"completion_result",           // Résultat final
	"user_feedback",               // Feedback utilisateur
	"user_feedback_diff",          // Diff de feedback
	"command_output",              // Output de commande
	"shell_integration_warning",   // Avertissement shell
	"browser_action",              // Action navigateur
	"browser_action_result",       // Résultat action navigateur
	"mcp_server_request_started",  // Requête MCP initiée
	"mcp_server_response",         // Réponse MCP
	"subtask_result",              // Résultat sous-tâche
	"checkpoint_saved",            // Checkpoint sauvegardé
	"rooignore_error",             // Erreur .rooignore
	"diff_error",                  // Erreur diff
	"condense_context",            // Condensation contexte
	"condense_context_error",      // Erreur condensation
	"codebase_search_result",      // Résultats recherche
	"user_edit_todos"              // Édition todos utilisateur
] as const
```

**🔴 Message critique : api_req_started**

Ce type contient les informations de requête avec JSON stringifié dans `text` :
```json
{
	"ts": 1758115714707,
	"type": "say",
	"say": "api_req_started",
	"text": "{\"request\":\"<task>\\n# Instructions\\n...\",\"cost\":0.42,\"cancelReason\":null}"
}
```

**Champs dans le JSON** :
- `request` : Contenu de la requête (peut contenir des instructions `new_task`)
- `cost` : Coût estimé
- `cancelReason` : Raison d'annulation (null si pas annulé)
- `streamingFailedMessage` : Message d'erreur de streaming

## Pipeline de Désérialisation

```
┌────────────────────────────┐
│ Fichier ui_messages.json   │
│ sur disque                 │
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│ fs.readFile(filePath)      │
│ ➜ readTaskMessages()       │
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│ JSON.parse(content)        │
│ ➜ ClineMessage[]           │
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│ Validation Zod (optionnel) │
│ ➜ clineMessageSchema       │
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│ Chargement dans Task       │
│ ➜ this.clineMessages       │
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│ Envoi vers Webview         │
│ ➜ postMessageToWebview()   │
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│ Rendu dans ChatView        │
│ ➜ ChatRow composants       │
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│ Parsing contextuel         │
│ ➜ safeJsonParse(text)      │
└────────────────────────────┘
```

### Étape 1 : Lecture fichier

**Fichier** : `src/core/task-persistence/taskMessages.ts:17`  
**Fonction** : `readTaskMessages()`  
**Description** : Lit le fichier depuis le système de fichiers et retourne un tableau vide si absent

### Étape 2 : Parsing JSON

**Ligne** : `JSON.parse(await fs.readFile(filePath, "utf8"))`  
**Description** : Parse direct sans regex - si le JSON est invalide, une exception est levée

### Étape 3 : Validation Type (Runtime)

**Fichier** : `packages/types/src/message.ts:164`  
**Fonction** : `clineMessageSchema.parse()`  
**Description** : Validation Zod optionnelle pour garantir la conformité

### Étape 4 : Chargement dans Task

**Fichier** : `src/core/webview/ClineProvider.ts:1318`  
**Fonction** : `loadHistoryItem()`  
**Description** : Charge les messages dans l'instance Task pour restauration

### Étape 5 : Envoi Webview

**Fichier** : `src/core/webview/ClineProvider.ts:1`  
**Description** : Envoie les messages via `postMessageToWebview()` pour rendu UI

### Étape 6 : Rendu UI

**Fichier** : `webview-ui/src/components/chat/ChatView.tsx:1`  
**Description** : Map chaque message vers un composant `ChatRow`

### Étape 7 : Parsing Contextuel

**Fichier** : `webview-ui/src/components/chat/ChatRow.tsx:182`  
**Fonction** : `safeJsonParse<T>(message.text)`  
**Description** : Parse le JSON imbriqué selon le type de message

## Extraction newTask

### Mécanisme d'extraction

**roo-code utilise un outil dédié `new_task`** plutôt que du parsing regex. L'instruction est stockée dans le champ `text` du message d'outil :

**Fichier** : `src/core/tools/newTaskTool.ts:11`

```typescript
export async function newTaskTool(
	cline: Task,
	block: ToolUse,
	askApproval: AskApproval,
	handleError: HandleError,
	pushToolResult: PushToolResult,
	removeClosingTag: RemoveClosingTag,
) {
	const mode: string | undefined = block.params.mode
	const message: string | undefined = block.params.message
	
	// Validation des paramètres
	if (!mode) {
		cline.recordToolError("new_task")
		pushToolResult(await cline.sayAndCreateMissingParamError("new_task", "mode"))
		return
	}
	
	if (!message) {
		cline.recordToolError("new_task")
		pushToolResult(await cline.sayAndCreateMissingParamError("new_task", "message"))
		return
	}
	
	// Un-escape des backslashes pour sous-tâches hiérarchiques
	const unescapedMessage = message.replace(/\\\@/g, "\@")
	
	// Création de la nouvelle tâche
	const newCline = await provider.initClineWithTask(unescapedMessage, undefined, cline)
	
	// Changement de mode
	await provider.handleModeSwitch(mode)
	
	// Mise en pause de la tâche parente
	cline.isPaused = true
	cline.emit(RooCodeEventName.TaskPaused)
}
```

### Format du message tool

**Dans ui_messages.json** :
```json
{
	"ts": 1758114676450,
	"type": "ask",
	"ask": "tool",
	"text": "{\"tool\":\"newTask\",\"mode\":\"code\",\"content\":\"Implement a new feature for the application\"}"
}
```

**Parsing côté webview** :
```typescript
const tool = useMemo(
	() => (message.ask === "tool" ? safeJsonParse<ClineSayTool>(message.text) : null),
	[message.ask, message.text],
)
```

### Détection des instructions newTask

**Approche roo-code** : Pas de regex, utilisation du système de types

```typescript
// Dans ChatRow.tsx - détection d'un outil newTask
if (tool?.tool === "newTask") {
	// Affichage spécifique pour newTask
	// Affiche le mode et le message
}
```

**Pas de parsing regex fragile** - Le système repose sur la structure typée du JSON.

## Gestion des Cas Complexes

### JSON Stringifié Imbriqué

**Problème** : Le champ `text` peut contenir du JSON stringifié  
**Solution** : Fonction `safeJsonParse()` avec gestion d'erreurs

**Exemple** : Message `api_req_started`
```typescript
const apiReqInfo = safeJsonParse<ClineApiReqInfo>(message.text)
// Si parsing échoue, retourne undefined plutôt que crash
```

### Multi-lignes dans instructions

**Problème** : Les instructions peuvent contenir des newlines  
**Solution** : Aucun traitement spécial nécessaire - JSON.parse() gère nativement

**Exemple** :
```json
{
	"text": "{\"tool\":\"newTask\",\"content\":\"Line 1\\nLine 2\\nLine 3\"}"
}
```

### Patterns spéciaux

**Pattern détecté** : `[new_task in X mode: 'Y']`

Ce pattern n'est PAS utilisé dans les ui_messages.json. C'est un format d'affichage dans l'historique de conversation API (`api_conversation_history.json`), pas dans les messages UI.

**Dans api_conversation_history.json** :
```json
{
	"role": "user",
	"content": [{ 
		"type": "text", 
		"text": "[new_task completed] Result: Task finished successfully" 
	}]
}
```

**Génération** : Voir `src/core/task/Task.ts:972`

### Mécanismes de fallback

1. **`safeJsonParse()`** retourne `defaultValue` ou `undefined` si échec
2. **Validation Zod** optionnelle pour garantir structure
3. **Checks conditionnels** avant accès aux propriétés :
   ```typescript
   if (message.text !== null && message.text !== undefined) {
       const parsed = safeJsonParse(message.text)
       // Utilise parsed seulement si non-undefined
   }
   ```

## Patterns et Regex Utilisés

### Aucune regex pour la désérialisation !

**roo-code n'utilise PAS de regex** pour parser les ui_messages.json. Tout repose sur :
- `JSON.parse()` natif
- Types TypeScript
- Validation Zod
- Pattern matching sur les énumérations

**Seul usage de regex** : Nettoyage de chaînes dans des cas spécifiques non liés à la désérialisation

**Exemple - Unescape dans newTask** :
```typescript
const unescapedMessage = message.replace(/\\\@/g, "\@")
```

## Recommandations pour roo-state-manager

### 1. Adopter la même architecture

**Éviter** : Parsing regex des contenus de messages  
**Adopter** : Désérialisation directe via JSON.parse()

```typescript
// ❌ ÉVITER - Approche fragile avec regex
const newTaskMatch = content.match(/\[new_task in (\w+) mode: '([^']+)'\]/)

// ✅ ADOPTER - Approche robuste roo-code
const messages: ClineMessage[] = JSON.parse(fileContent)
messages.filter(m => m.ask === "tool")
        .map(m => safeJsonParse<ToolMessage>(m.text))
        .filter(tool => tool?.tool === "newTask")
```

### 2. Utiliser les types roo-code

**Importer** : `@roo-code/types` pour cohérence

```typescript
import { ClineMessage, ClineAsk, ClineSay } from "@roo-code/types"

// Validation
const messageSchema = clineMessageSchema // Réutiliser le schéma Zod
```

### 3. Implémenter safeJsonParse

```typescript
export function safeJsonParse<T>(
	jsonString: string | null | undefined,
	defaultValue?: T
): T | undefined {
	if (!jsonString) return defaultValue
	
	try {
		return JSON.parse(jsonString) as T
	} catch (error) {
		console.error("JSON parse error:", error)
		return defaultValue
	}
}
```

### 4. Stratégie de détection newTask

**Au lieu de regex** sur le contenu texte, filtrer par structure :

```typescript
function extractNewTaskInstructions(messages: ClineMessage[]): NewTaskInfo[] {
	return messages
		.filter(m => m.ask === "tool")
		.map(m => {
			const tool = safeJsonParse<{ tool: string; mode: string; content: string }>(m.text)
			if (tool?.tool === "newTask") {
				return {
					mode: tool.mode,
					message: tool.content,
					timestamp: m.ts
				}
			}
			return null
		})
		.filter((item): item is NewTaskInfo => item !== null)
}
```

### 5. Pipeline de traitement recommandé

```typescript
class UIMessagesParser {
	async parseConversation(taskId: string): Promise<ParsedConversation> {
		// 1. Lire le fichier
		const content = await fs.readFile(uiMessagesPath, 'utf8')
		
		// 2. Parser JSON
		const messages: ClineMessage[] = JSON.parse(content)
		
		// 3. Valider (optionnel)
		messages.forEach(m => clineMessageSchema.parse(m))
		
		// 4. Extraire les informations structurées
		const toolCalls = this.extractToolCalls(messages)
		const apiRequests = this.extractApiRequests(messages)
		const newTasks = this.extractNewTasks(messages)
		
		return {
			messages,
			toolCalls,
			apiRequests,
			newTasks,
			metadata: this.extractMetadata(messages)
		}
	}
	
	private extractToolCalls(messages: ClineMessage[]) {
		return messages
			.filter(m => m.ask === "tool")
			.map(m => safeJsonParse<ToolMessage>(m.text))
			.filter(tool => tool !== undefined)
	}
	
	private extractApiRequests(messages: ClineMessage[]) {
		return messages
			.filter(m => m.say === "api_req_started")
			.map(m => safeJsonParse<ApiReqInfo>(m.text))
			.filter(info => info !== undefined)
	}
	
	private extractNewTasks(messages: ClineMessage[]) {
		return this.extractToolCalls(messages)
			.filter(tool => tool.tool === "newTask")
			.map(tool => ({
				mode: tool.mode,
				message: tool.content,
				parentTaskId: /* ID de la tâche parente */
			}))
	}
}
```

### 6. Gestion des erreurs

```typescript
try {
	const messages = JSON.parse(content)
	// Traitement
} catch (error) {
	if (error instanceof SyntaxError) {
		// JSON corrompu - tentative de réparation ou skip
		logger.error(`Corrupted ui_messages.json for task ${taskId}:`, error)
		return { messages: [], errors: [error] }
	}
	throw error
}
```

## Avantages de l'approche roo-code

✅ **Robustesse** : Aucune dépendance aux regex fragiles  
✅ **Maintenabilité** : Types TypeScript garantissent la cohérence  
✅ **Performance** : JSON.parse() natif très performant  
✅ **Extensibilité** : Ajout de nouveaux types sans refactoring  
✅ **Testabilité** : Schémas Zod permettent tests exhaustifs  

## Conclusion

L'approche de roo-code pour la désérialisation des `ui_messages.json` est **structurée, typée et sans regex**. Elle repose sur :

1. **Lecture directe** via `fs.readFile()` + `JSON.parse()`
2. **Types stricts** via `@roo-code/types` et Zod
3. **Parsing sécurisé** via `safeJsonParse()` pour JSON imbriqué
4. **Pas de regex** pour l'extraction de contenu structuré

Pour roo-state-manager, adopter cette approche éliminera les problèmes de regex fragiles et garantira une compatibilité parfaite avec le format natif de roo-code.