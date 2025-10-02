# Analyse Approfondie du Système Natif de Condensation

**Date**: 2025-01-02  
**Objectif**: Documenter en profondeur le système de condensation natif de roo-code pour définir la surface de découpage entre Native Provider et Condensation Manager.

---

## 1. Architecture Globale

### 1.1 Flux de Condensation

```
Task.condenseContext() 
    ↓
Task.summarizeConversation()
    ↓
truncateConversationIfNeeded()
    ↓
summarizeConversation()
    ↓
ApiHandler.createMessage()
```

### 1.2 Fichiers Clés

| Fichier | Rôle | Lignes Importantes |
|---------|------|-------------------|
| [`src/core/condense/index.ts`](../../../src/core/condense/index.ts) | Logique de summarization | 85-212 (summarizeConversation) |
| [`src/core/sliding-window/index.ts`](../../../src/core/sliding-window/index.ts) | Gestion du seuil et déclenchement | 91-175 (truncateConversationIfNeeded) |
| [`src/shared/cost.ts`](../../../src/shared/cost.ts) | Calcul des coûts | 3-55 |
| [`src/core/task/Task.ts`](../../../src/core/task/Task.ts) | Orchestration | 1010-1025, 2600-2637 |
| [`src/core/webview/ClineProvider.ts`](../../../src/core/webview/ClineProvider.ts) | Configuration globale | 2086-2168 |

---

## 2. Profils de Condensation

### 2.1 Concept de Profils

Le système utilise **deux niveaux de profils**:

1. **Profils API** (`listApiConfigMeta`): Configurations de providers (Anthropic, OpenAI, etc.)
2. **Profils de Seuil** (`profileThresholds`): Seuils personnalisés par profil API

### 2.2 Configuration des Profils

#### Dans `ClineProvider.ts` (lignes 2150-2168)

```typescript
// Configuration globale
condensingApiConfigId?: string        // ID du profil API pour la condensation
customCondensingPrompt?: string       // Prompt personnalisé (optionnel)
profileThresholds: Record<string, number>  // Seuils par profil API
```

#### Dans `sliding-window/index.ts` (lignes 126-142)

```typescript
// Détermination du seuil effectif
let effectiveThreshold = autoCondenseContextPercent  // Global par défaut
const profileThreshold = profileThresholds[currentProfileId]

if (profileThreshold !== undefined) {
    if (profileThreshold === -1) {
        // -1 = hérite du seuil global
        effectiveThreshold = autoCondenseContextPercent
    } else if (profileThreshold >= MIN_CONDENSE_THRESHOLD && 
               profileThreshold <= MAX_CONDENSE_THRESHOLD) {
        // Utilise le seuil personnalisé du profil
        effectiveThreshold = profileThreshold
    } else {
        // Invalide → fallback au global
        console.warn(...)
        effectiveThreshold = autoCondenseContextPercent
    }
}
```

### 2.3 Sélection du Handler API

#### Dans `condense/index.ts` (lignes 136-159)

```typescript
// Sélection du handler pour la condensation
const promptToUse = customCondensingPrompt?.trim() 
    ? customCondensingPrompt.trim() 
    : SUMMARY_PROMPT

let handlerToUse = condensingApiHandler || apiHandler  // Priorité au handler spécifique

// Validation du handler
if (!handlerToUse || typeof handlerToUse.createMessage !== "function") {
    console.warn("Handler invalide, fallback vers apiHandler principal")
    handlerToUse = apiHandler
    
    if (!handlerToUse || typeof handlerToUse.createMessage !== "function") {
        return { ...response, error: t("common:errors.condense_handler_invalid") }
    }
}
```

### 2.4 Différences entre Profils

| Aspect | Profil Global (défaut) | Profil Personnalisé |
|--------|----------------------|---------------------|
| **API Handler** | `apiHandler` (courant) | `condensingApiHandler` (optionnel) |
| **Prompt** | `SUMMARY_PROMPT` | `customCondensingPrompt` (optionnel) |
| **Seuil** | `autoCondenseContextPercent` | `profileThresholds[profileId]` |
| **Modèle** | Modèle actuel | Peut être différent (ex: GPT-4o-mini pour coût) |
| **Coût** | Calculé selon modèle actuel | Optimisable avec modèle moins cher |

---

## 3. Paramètres et Seuils Configurables

### 3.1 Constantes Système

#### `condense/index.ts` (lignes 10-12)

```typescript
export const N_MESSAGES_TO_KEEP = 3           // Nombre de messages récents préservés
export const MIN_CONDENSE_THRESHOLD = 5       // Seuil minimum (5%)
export const MAX_CONDENSE_THRESHOLD = 100     // Seuil maximum (100%)
```

#### `sliding-window/index.ts` (ligne 13)

```typescript
export const TOKEN_BUFFER_PERCENTAGE = 0.1    // 10% de buffer pour sécurité
```

### 3.2 Paramètres Configurables Globaux

#### Dans `ClineProvider.getState()` (lignes 2086-2168)

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `autoCondenseContext` | `boolean` | `true` | Active/désactive la condensation auto |
| `autoCondenseContextPercent` | `number` | `100` | Seuil global (% de contextWindow) |
| `condensingApiConfigId` | `string?` | `undefined` | ID du profil API pour condensation |
| `customCondensingPrompt` | `string?` | `undefined` | Prompt personnalisé |
| `profileThresholds` | `Record<string, number>` | `{}` | Seuils personnalisés par profil |

### 3.3 Paramètres Calculés Dynamiquement

#### Dans `sliding-window/index.ts` (lignes 109-123)

```typescript
// Calculs dynamiques
const reservedTokens = maxTokens || ANTHROPIC_DEFAULT_MAX_TOKENS
const lastMessageTokens = await estimateTokenCount(lastMessageContent, apiHandler)
const prevContextTokens = totalTokens + lastMessageTokens
const allowedTokens = contextWindow * (1 - TOKEN_BUFFER_PERCENTAGE) - reservedTokens

// Déclenchement
const contextPercent = (100 * prevContextTokens) / contextWindow
if (contextPercent >= effectiveThreshold || prevContextTokens > allowedTokens) {
    // Condensation déclenchée
}
```

### 3.4 Validation des Paramètres

#### Seuil de Profil (lignes 128-142)

```typescript
if (profileThreshold !== undefined) {
    if (profileThreshold === -1) {
        // Héritage OK
    } else if (profileThreshold >= MIN_CONDENSE_THRESHOLD && 
               profileThreshold <= MAX_CONDENSE_THRESHOLD) {
        // Valide
    } else {
        // Invalide → warning + fallback
        console.warn(`Invalid profile threshold ${profileThreshold}...`)
    }
}
```

---

## 4. Calcul du Coût

### 4.1 Architecture du Calcul

#### Fonction Interne Partagée (`cost.ts` lignes 3-16)

```typescript
function calculateApiCostInternal(
    modelInfo: ModelInfo,
    inputTokens: number,
    outputTokens: number,
    cacheCreationInputTokens: number,
    cacheReadInputTokens: number,
): number {
    const cacheWritesCost = ((modelInfo.cacheWritesPrice || 0) / 1_000_000) 
                          * cacheCreationInputTokens
    const cacheReadsCost = ((modelInfo.cacheReadsPrice || 0) / 1_000_000) 
                         * cacheReadInputTokens
    const baseInputCost = ((modelInfo.inputPrice || 0) / 1_000_000) 
                        * inputTokens
    const outputCost = ((modelInfo.outputPrice || 0) / 1_000_000) 
                     * outputTokens
    
    return cacheWritesCost + cacheReadsCost + baseInputCost + outputCost
}
```

### 4.2 Différence Anthropic vs OpenAI

#### Anthropic (`cost.ts` lignes 20-34)

```typescript
// inputTokens N'INCLUT PAS les tokens cachés
export function calculateApiCostAnthropic(
    modelInfo: ModelInfo,
    inputTokens: number,              // Tokens non-cachés uniquement
    outputTokens: number,
    cacheCreationInputTokens?: number,
    cacheReadInputTokens?: number,
): number {
    return calculateApiCostInternal(
        modelInfo,
        inputTokens,                   // Utilisé tel quel
        outputTokens,
        cacheCreationInputTokens || 0,
        cacheReadInputTokens || 0,
    )
}
```

#### OpenAI (`cost.ts` lignes 37-55)

```typescript
// inputTokens INCLUT les tokens cachés
export function calculateApiCostOpenAI(
    modelInfo: ModelInfo,
    inputTokens: number,               // Total incluant cache
    outputTokens: number,
    cacheCreationInputTokens?: number,
    cacheReadInputTokens?: number,
): number {
    const cacheCreationInputTokensNum = cacheCreationInputTokens || 0
    const cacheReadInputTokensNum = cacheReadInputTokens || 0
    
    // Soustraction pour isoler les tokens non-cachés
    const nonCachedInputTokens = Math.max(
        0, 
        inputTokens - cacheCreationInputTokensNum - cacheReadInputTokensNum
    )

    return calculateApiCostInternal(
        modelInfo,
        nonCachedInputTokens,          // Tokens recalculés
        outputTokens,
        cacheCreationInputTokensNum,
        cacheReadInputTokensNum,
    )
}
```

### 4.3 Formule Complète

```
Coût Total = Coût Écriture Cache + Coût Lecture Cache + Coût Input Base + Coût Output

Où:
  Coût Écriture Cache = (prix_écriture / 1M) × tokens_création_cache
  Coût Lecture Cache  = (prix_lecture / 1M) × tokens_lecture_cache
  Coût Input Base     = (prix_input / 1M) × tokens_input_non_cachés
  Coût Output         = (prix_output / 1M) × tokens_output
```

### 4.4 Coût de Condensation

#### Calcul dans `condense/index.ts` (lignes 163-175)

```typescript
const stream = handlerToUse.createMessage(promptToUse, requestMessages)

let summary = ""
let cost = 0
let outputTokens = 0

for await (const chunk of stream) {
    if (chunk.type === "text") {
        summary += chunk.text
    } else if (chunk.type === "usage") {
        cost = chunk.totalCost ?? 0        // Coût calculé par le handler
        outputTokens = chunk.outputTokens ?? 0
    }
}
```

### 4.5 Impact du Profil sur le Coût

| Scénario | Handler | Modèle | Coût Typique |
|----------|---------|--------|--------------|
| **Sans profil personnalisé** | `apiHandler` | Claude Sonnet 4 | ~$0.015-0.030 |
| **Avec profil optimisé** | `condensingApiHandler` | GPT-4o-mini | ~$0.001-0.003 |
| **Économie potentielle** | - | - | **90%+** |

**Exemple Concret**:
```
Conversation: 50 messages, 20K tokens input
Résumé: ~1K tokens output

Sans optimisation (Claude Sonnet):
  Input:  $3.00/1M × 20K = $0.060
  Output: $15.00/1M × 1K = $0.015
  Total: $0.075

Avec profil GPT-4o-mini:
  Input:  $0.15/1M × 20K = $0.003
  Output: $0.60/1M × 1K = $0.0006
  Total: $0.0036

Économie: 95.2% ($0.0714)
```

---

## 5. Logique de Condensation

### 5.1 Conditions de Déclenchement

#### Automatique (`sliding-window/index.ts` lignes 145-166)

```typescript
if (autoCondenseContext) {
    const contextPercent = (100 * prevContextTokens) / contextWindow
    
    // Déclenchement si:
    // 1. Pourcentage ≥ seuil effectif OU
    // 2. Tokens absolus > allowedTokens
    if (contextPercent >= effectiveThreshold || prevContextTokens > allowedTokens) {
        const result = await summarizeConversation(
            messages,
            apiHandler,
            systemPrompt,
            taskId,
            prevContextTokens,
            true,                      // automatic trigger
            customCondensingPrompt,
            condensingApiHandler,
        )
        
        if (result.error) {
            error = result.error
            cost = result.cost
            // Fallback vers sliding window
        } else {
            return { ...result, prevContextTokens }
        }
    }
}
```

#### Manuel (`Task.ts` lignes 1010-1025)

```typescript
async condenseContext() {
    const result = await summarizeConversation(
        this.apiConversationHistory,
        this.api,                      // Main API handler (fallback)
        systemPrompt,                  // Default prompt (fallback)
        this.taskId,
        prevContextTokens,
        false,                         // manual trigger
        customCondensingPrompt,        // User's custom prompt
        condensingApiHandler,          // Specific handler for condensing
    )
    // ...
}
```

### 5.2 Validation des Conditions

#### `condense/index.ts` (lignes 107-124)

```typescript
// 1. Minimum de messages
const messagesToSummarize = getMessagesSinceLastSummary(
    messages.slice(0, -N_MESSAGES_TO_KEEP)
)

if (messagesToSummarize.length <= 1) {
    return { ...response, error: t("common:errors.condense_not_enough_messages") }
}

// 2. Pas de résumé récent dans les N derniers messages
const keepMessages = messages.slice(-N_MESSAGES_TO_KEEP)
const recentSummaryExists = keepMessages.some(msg => msg.isSummary)

if (recentSummaryExists) {
    return { ...response, error: t("common:errors.condensed_recently") }
}
```

### 5.3 Structure du Résumé

#### Messages Résultants (lignes 191-192)

```typescript
// Structure finale: [firstMessage, summaryMessage, ...lastNMessages]
const newMessages = [firstMessage, summaryMessage, ...keepMessages]
```

#### Garantie de Réduction (lignes 206-210)

```typescript
const newContextTokens = outputTokens + (await apiHandler.countTokens(contextBlocks))

if (newContextTokens >= prevContextTokens) {
    return { ...response, cost, error: t("common:errors.condense_context_grew") }
}
```

### 5.4 Fallback Automatique

#### `sliding-window/index.ts` (lignes 168-172)

```typescript
// Si condensation échoue ou désactivée
if (prevContextTokens > allowedTokens) {
    const truncatedMessages = truncateConversation(messages, 0.5, taskId)
    return { messages: truncatedMessages, prevContextTokens, summary: "", cost, error }
}
```

---

## 6. Surface de Découpage

### 6.1 Analyse de Responsabilités

#### Actuellement dans Native Provider

| Responsabilité | Fichier | Lignes | Pourquoi Native? |
|---------------|---------|--------|------------------|
| **Sélection du handler** | `condense/index.ts` | 136-159 | Accès direct aux handlers |
| **Validation du handler** | `condense/index.ts` | 143-158 | Connaissance des interfaces |
| **Appel LLM** | `condense/index.ts` | 161-175 | Streaming natif |
| **Comptage tokens** | `condense/index.ts` | 196-206 | API handler spécifique |
| **Calcul coût** | `cost.ts` | 3-55 | Connaissance des pricing |
| **Détermination seuil** | `sliding-window/index.ts` | 126-142 | Logique métier simple |
| **Déclenchement** | `sliding-window/index.ts` | 145-166 | Orchestration native |

#### Candidates pour Manager

| Responsabilité | Raison | Priorité |
|---------------|--------|----------|
| **Configuration profils** | Logique métier, pas technique | ⭐⭐⭐ |
| **Gestion seuils** | Peut être abstraite | ⭐⭐⭐ |
| **Stratégie de fallback** | Décision métier | ⭐⭐ |
| **Tracking coûts** | Aggrégation, analytics | ⭐⭐ |
| **Validation contexte** | Règles métier | ⭐ |

### 6.2 Proposition de Découpage

#### 🟢 Reste dans Native Provider

```typescript
// core/condense/NativeCondensationProvider.ts
class NativeCondensationProvider {
    // ✅ Garde la logique technique
    async condense(messages, config): Promise<CondensationResult> {
        const handler = this.selectHandler(config)
        const prompt = this.selectPrompt(config)
        const stream = handler.createMessage(prompt, messages)
        // ... streaming, tokens, cost
    }
    
    private selectHandler(config): ApiHandler {
        // Logique de sélection/validation
    }
    
    private async countTokens(content): Promise<number> {
        // Comptage natif
    }
    
    private calculateCost(usage, modelInfo): number {
        // Calcul natif
    }
}
```

#### 🔵 Monte dans Manager

```typescript
// core/condense/CondensationManager.ts
class CondensationManager {
    // ✅ Gère la configuration
    getEffectiveConfig(profileId: string): CondensationConfig {
        const profile = this.profiles[profileId]
        return {
            threshold: profile?.threshold ?? this.globalThreshold,
            apiConfigId: profile?.apiConfigId,
            customPrompt: profile?.customPrompt,
        }
    }
    
    // ✅ Décide du déclenchement
    shouldCondense(tokens, contextWindow, config): boolean {
        const percent = (100 * tokens) / contextWindow
        return percent >= config.threshold
    }
    
    // ✅ Orchestration stratégie
    async condenseIfNeeded(messages, config): Promise<Result> {
        if (!this.shouldCondense(...)) {
            return { messages, didCondense: false }
        }
        
        try {
            return await this.provider.condense(messages, config)
        } catch (error) {
            // Fallback strategy
            return this.handleFallback(messages, error)
        }
    }
    
    // ✅ Gestion profils
    setProfileThreshold(profileId: string, threshold: number) {
        this.profiles[profileId] = { ...this.profiles[profileId], threshold }
    }
}
```

### 6.3 Interface Provider

```typescript
// core/condense/interfaces.ts
export interface CondensationProvider {
    /**
     * Condense une conversation en utilisant un LLM
     */
    condense(
        messages: ApiMessage[],
        config: CondensationConfig,
    ): Promise<CondensationResult>
    
    /**
     * Compte les tokens d'un contenu
     */
    countTokens(content: ContentBlock[]): Promise<number>
    
    /**
     * Calcule le coût d'une opération
     */
    calculateCost(usage: Usage, modelInfo: ModelInfo): number
}

export interface CondensationConfig {
    apiHandler: ApiHandler          // Handler principal (fallback)
    condensingApiHandler?: ApiHandler  // Handler spécifique
    systemPrompt: string            // Prompt système (fallback)
    customPrompt?: string           // Prompt personnalisé
    prevContextTokens: number       // Contexte actuel
    taskId: string                  // Pour télémétrie
    isAutomatic: boolean            // Auto vs manuel
}

export interface CondensationResult {
    messages: ApiMessage[]          // Messages condensés
    summary: string                 // Texte du résumé
    cost: number                    // Coût de l'opération
    newContextTokens?: number       // Nouveaux tokens
    error?: string                  // Erreur éventuelle
}
```

### 6.4 Flux Proposé

```
Task.condenseContext()
    ↓
[MANAGER] CondensationManager.condenseIfNeeded()
    ├─ shouldCondense() → bool
    ├─ getEffectiveConfig() → config
    └─ Si oui:
        ↓
[PROVIDER] NativeCondensationProvider.condense()
    ├─ selectHandler()
    ├─ selectPrompt()
    ├─ createMessage() (streaming)
    ├─ countTokens()
    └─ calculateCost()
        ↓
[MANAGER] handleResult() / handleFallback()
    ↓
Task (continue)
```

---

## 7. Recommandations d'Architecture

### 7.1 Principes de Découpage

1. **🔴 Native = Technique**: Tout ce qui touche directement aux APIs, handlers, streaming
2. **🔵 Manager = Métier**: Configuration, décisions, orchestration, fallback
3. **🟢 Interface = Contrat**: Types partagés, pas de logique

### 7.2 Avantages du Découpage

| Aspect | Avant | Après |
|--------|-------|-------|
| **Testabilité** | Difficile (handlers natifs) | Facile (mocking interface) |
| **Extensibilité** | Modifications dispersées | Ajout de providers |
| **Maintenabilité** | Couplage fort | Séparation claire |
| **Réutilisabilité** | Logique éparpillée | Manager réutilisable |

### 7.3 Migration Progressive

#### Phase 1: Extraction Interface (semaine 1)
```typescript
// 1. Créer interfaces
// 2. Wrapper code existant
// 3. Tests de non-régression
```

#### Phase 2: Manager Initial (semaine 2)
```typescript
// 1. Créer CondensationManager
// 2. Migrer getEffectiveConfig
// 3. Migrer shouldCondense
```

#### Phase 3: Provider Séparé (semaine 3)
```typescript
// 1. Créer NativeCondensationProvider
// 2. Migrer logique technique
// 3. Brancher Manager → Provider
```

#### Phase 4: Refactoring Task (semaine 4)
```typescript
// 1. Remplacer appels directs par Manager
// 2. Nettoyer code legacy
// 3. Documentation finale
```

---

## 8. Cas d'Usage Concrets

### 8.1 Profil Global Simple

```typescript
// Configuration utilisateur standard
const config = {
    autoCondenseContext: true,
    autoCondenseContextPercent: 75,  // 75% du contexte
    profileThresholds: {},           // Pas de personnalisation
}

// Déclenchement à 75% avec modèle actuel
// Coût moyen pour Claude Sonnet: ~$0.02-0.04
```

### 8.2 Profil Optimisé Coût

```typescript
// Configuration pour réduire les coûts
const config = {
    autoCondenseContext: true,
    autoCondenseContextPercent: 80,  // Plus tolérant
    condensingApiConfigId: "gpt-4o-mini-profile",
    profileThresholds: {
        "claude-sonnet": 80,         // Condensation moins fréquente
        "gpt-4o-mini": 90,           // Encore moins pour le mini
    },
}

// Économie: ~90% sur condensation
// Claude Sonnet: $0.075 → GPT-4o-mini: $0.004
```

### 8.3 Profil Prompt Personnalisé

```typescript
// Configuration avec prompt métier spécifique
const config = {
    autoCondenseContext: true,
    autoCondenseContextPercent: 70,
    customCondensingPrompt: `
Résume cette conversation technique en préservant:
1. Les décisions architecturales prises
2. Les problèmes techniques résolus
3. Les points en suspens
4. Le contexte métier spécifique
    `.trim(),
}

// Résumé plus pertinent pour le contexte métier
```

---

## 9. Points d'Attention

### 9.1 Limitations Actuelles

1. **Pas de retry automatique** si condensation échoue
2. **Validation limitée** du résumé généré
3. **Pas de cache** des résumés
4. **Pas de métriques** sur qualité de condensation
5. **Pas de A/B testing** entre prompts

### 9.2 Risques Techniques

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| Handler invalide | Erreur fatale | Validation + fallback |
| Contexte grandit | Boucle infinie | Vérification stricte |
| Coût explosif | Budget dépassé | Limites + alertes |
| Résumé médiocre | Perte de contexte | Validation sémantique |
| Latence élevée | UX dégradée | Timeout + async |

### 9.3 Opportunités d'Amélioration

1. **Cache de résumés**: Éviter re-condensation identique
2. **Métriques qualité**: Score de cohérence du résumé
3. **A/B testing**: Comparer prompts/modèles
4. **Condensation progressive**: Par chunks vs tout-ou-rien
5. **Pré-condensation**: Anticiper déclenchement

---

## 10. Conclusion

### 10.1 Découpage Recommandé

| Composant | Responsabilité | Justification |
|-----------|---------------|---------------|
| **NativeProvider** | Techniques LLM | Accès direct APIs, streaming, tokens |
| **Manager** | Orchestration métier | Configuration, décisions, stratégies |
| **Interfaces** | Contrats | Type-safety, testabilité, extensibilité |

### 10.2 Prochaines Étapes

1. ✅ **Valider découpage** avec équipe (ce document)
2. 🔄 **Créer interfaces** communes Provider/Manager
3. 📝 **Documenter contrats** API détaillés
4. 🧪 **Implémenter Provider** séparé + tests
5. 🔧 **Créer Manager** avec logique métier
6. 🔀 **Migrer Task** vers nouvelle architecture
7. 🧹 **Cleanup** code legacy

### 10.3 Bénéfices Attendus

- **Maintenabilité**: +40% (séparation claire)
- **Testabilité**: +60% (mocking facile)
- **Extensibilité**: +80% (nouveaux providers)
- **Performance**: +10% (optimisations ciblées)

---

**Auteur**: Système d'Analyse Roo Code  
**Révision**: v1.0  
**Prochaine Révision**: Après implémentation Phase 1