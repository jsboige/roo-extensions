
# Complete Provider Architecture & Strategies

**Version**: 2.0 - Consolidated  
**Date**: 2025-10-02  
**Status**: Production Design - Complete Reference

## Executive Summary

Ce document est la **référence complète** pour l'architecture de condensation multi-provider de roo-code. Il consolide les informations de trois documents sources pour fournir une vue d'ensemble exhaustive de:

- **4 Providers**: Native, Lossless, Truncation, Smart
- **Architecture Pass-Based**: Système modulaire et configurable
- **Profils API**: Configuration avancée avec handlers dédiés
- **UI Components**: Interface utilisateur complète

Ce document couvre ~3000 lignes d'architecture détaillée, de la configuration la plus simple à la plus avancée.

---

## Table des Matières

1. [Introduction & Philosophie](#1-introduction--philosophie)
2. [Native Provider](#2-native-provider)
3. [Lossless Provider](#3-lossless-provider)
4. [Truncation Provider](#4-truncation-provider)
5. [Smart Provider - Architecture Pass-Based](#5-smart-provider---architecture-pass-based)
6. [Matrice de Comparaison](#6-matrice-de-comparaison)
7. [Guide de Sélection](#7-guide-de-sélection)
8. [Patterns d'Utilisation](#8-patterns-dutilisation)

---

## 1. Introduction & Philosophie

### 1.1 Vue d'Ensemble des 4 Providers

L'architecture de condensation repose sur un système **modulaire et extensible** où chaque provider illustre une approche différente:

```
┌─────────────────────────────────────────────────────────┐
│                  Condensation Manager                    │
│  - Orchestration                                         │
│  - Configuration des profils                             │
│  - Décisions de déclenchement                           │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐      ┌─────▼──────┐    ┌─────▼──────┐
   │ Native  │      │  Lossless  │    │ Truncation │
   │ Provider│      │  Provider  │    │  Provider  │
   └─────────┘      └────────────┘    └────────────┘
        │
   ┌────▼────────┐
   │   Smart     │
   │  Provider   │
   │ (Pass-Based)│
   └─────────────┘
```

**Philosophie de Design**:

1. **Progressivité**: Du simple (Native) au sophistiqué (Smart)
2. **Composabilité**: Les providers peuvent être combinés
3. **Observabilité**: Chaque opération est traçable et mesurable
4. **Configurabilité**: De zero-config à ultra-paramétrable

### 1.2 Architecture de Base

#### Interface Provider Commune

```typescript
interface ICondensationProvider {
  // Identification
  readonly id: string
  readonly name: string
  readonly description: string
  readonly version: string
  
  // Capabilities
  getCapabilities(): ProviderCapabilities
  
  // Configuration
  getConfigSchema(): ConfigSchema
  validateConfig(config: any): ValidationResult
  
  // UI Integration (optionnel)
  getConfigComponent?(): ConfigComponentDescriptor
  
  // Core functionality
  condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult>
  
  estimateReduction(
    context: ConversationContext,
    config?: any
  ): Promise<TokenEstimate>
  
  estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number>
}

interface ProviderCapabilities {
  supportsLossless: boolean
  supportsLossy: boolean
  supportsLLMSummarization: boolean
  supportsParallelProcessing: boolean
  supportsMultiPass: boolean
  supportsFallback: boolean
  estimatedSpeed: 'fast' | 'medium' | 'slow'
}

interface ConversationContext {
  messages: ApiMessage[]
  tokenCount: number
  apiHandler: ApiHandler
  systemPrompt: string
}

interface CondensationOptions {
  targetTokens: number
  config?: any  // Provider-specific
}

interface CondensationResult {
  messages: ApiMessage[]
  stats: {
    originalTokens: number
    finalTokens: number
    reductionPercent: number
    cost: number
    operationsPerformed: string[]
  }
}
```

#### Provider Manager

```typescript
class CondensationProviderManager {
  private providers: Map<string, ICondensationProvider> = new Map()
  private activeProviderId: string = 'native'
  
  registerProvider(provider: ICondensationProvider): void {
    this.providers.set(provider.id, provider)
  }
  
  getProvider(id: string): ICondensationProvider | null {
    return this.providers.get(id) || null
  }
  
  listProviders(): ProviderInfo[] {
    return Array.from(this.providers.values()).map(p => ({
      id: p.id,
      name: p.name,
      description: p.description,
      capabilities: p.getCapabilities()
    }))
  }
  
  setActiveProvider(id: string): void {
    if (!this.providers.has(id)) {
      throw new Error(`Provider ${id} not found`)
    }
    this.activeProviderId = id
  }
  
  getActiveProvider(): ICondensationProvider {
    return this.providers.get(this.activeProviderId)!
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const provider = this.getActiveProvider()
    return provider.condense(context, options)
  }
}
```

### 1.3 Concepts Clés

#### Profils API

Un **profil API** définit une configuration spécifique pour les appels LLM:
- Handler API (provider, modèle, endpoint)
- Seuil de déclenchement personnalisé
- Prompt personnalisé (optionnel)

**Cas d'usage**: Utiliser GPT-4o-mini pour la condensation (économique) tout en gardant Claude Sonnet pour la conversation principale (qualité).

#### Zones de Messages

Les messages sont divisés en zones selon leur âge:

```
[First Message] [======= Old Zone =======] [Recent Messages (N derniers)]
     Always         Candidates for           Always preserved
    preserved       condensation
```

#### Opérations de Condensation

4 opérations fondamentales:

1. **KEEP**: Préserver intact
2. **SUPPRESS**: Supprimer entièrement (placeholder léger)
3. **TRUNCATE**: Réduire mécaniquement (premières lignes/caractères)
4. **SUMMARIZE**: Réduire via LLM (sémantique, coûteux)

---

## 2. Native Provider

### 2.1 Description et Use Case

Le **Native Provider** encapsule le système de condensation existant de roo-code, basé sur la summarization LLM batch.

**Caractéristiques**:
- Condensation LLM batch de la zone intermédiaire
- Préservation des N premiers et derniers messages
- Support des profils API pour optimisation coût
- Pas de configuration complexe

**Use Case**: Default provider, backward compatibility, utilisateurs qui veulent "juste que ça marche".

### 2.2 Configuration avec Profils API

#### Architecture des Profils

Le système utilise **deux niveaux de configuration**:

1. **Configuration Globale** (`ClineProvider`):
```typescript
interface GlobalCondensationConfig {
  autoCondenseContext: boolean              // Enable/disable auto
  autoCondenseContextPercent: number        // Global threshold (%)
  condensingApiConfigId?: string            // Profile ID for condensation
  customCondensingPrompt?: string           // Custom prompt override
  profileThresholds: Record<string, number> // Per-profile thresholds
}
```

2. **Profils API** (`listApiConfigMeta`):
```typescript
interface ApiProfile {
  id: string
  name: string
  provider: 'anthropic' | 'openai' | 'openrouter' | ...
  model: string
  endpoint?: string
  apiKey?: string
  // ... autres paramètres
}
```

#### Sélection du Handler

**Priorité de sélection** (du 007-native-system-deep-dive.md):

```typescript
private selectApiHandler(config: any): ApiHandler {
  // 1. Handler spécifique pour condensation (si configuré)
  if (config?.condensingApiConfigId) {
    const specificHandler = this.getHandlerForProfile(
      config.condensingApiConfigId
    )
    if (specificHandler && this.validateHandler(specificHandler)) {
      return specificHandler
    }
    // Warning si invalide, fallback
    console.warn(
      `Invalid condensing handler for profile ${config.condensingApiConfigId}`
    )
  }
  
  // 2. Fallback vers handler de conversation
  const conversationHandler = this.conversationApiHandler
  if (this.validateHandler(conversationHandler)) {
    return conversationHandler
  }
  
  // 3. Erreur fatale
  throw new Error('No valid API handler available for condensation')
}

private validateHandler(handler: any): boolean {
  return handler && typeof handler.createMessage === 'function'
}
```

#### Détermination du Seuil

**Logique de seuil effectif** (du sliding-window/index.ts):

```typescript
function getEffectiveThreshold(
  currentProfileId: string,
  globalThreshold: number,
  profileThresholds: Record<string, number>
): number {
  const MIN_THRESHOLD = 5
  const MAX_THRESHOLD = 100
  
  // Vérifier si un seuil personnalisé existe
  const profileThreshold = profileThresholds[currentProfileId]
  
  if (profileThreshold === undefined) {
    // Pas de personnalisation → global
    return globalThreshold
  }
  
  if (profileThreshold === -1) {
    // -1 signifie "hériter du global"
    return globalThreshold
  }
  
  if (profileThreshold >= MIN_THRESHOLD && 
      profileThreshold <= MAX_THRESHOLD) {
    // Valide → utiliser
    return profileThreshold
  }
  
  // Invalide → warning + fallback global
  console.warn(
    `Invalid threshold ${profileThreshold} for profile ${currentProfileId}, ` +
    `using global ${globalThreshold}%`
  )
  return globalThreshold
}
```

#### Exemple de Configuration Multi-Profil

```typescript
// Configuration globale
const config: GlobalCondensationConfig = {
  autoCondenseContext: true,
  autoCondenseContextPercent: 80,  // Seuil global: 80%
  
  // Profil dédié pour condensation (économique)
  condensingApiConfigId: 'gpt-4o-mini-profile',
  
  // Prompt personnalisé
  customCondensingPrompt: `
Résume cette conversation technique en préservant:
1. Les décisions architecturales
2. Les problèmes résolus
3. Les points en suspens
4. Le contexte métier
  `.trim(),
  
  // Seuils personnalisés par profil
  profileThresholds: {
    'claude-sonnet-4': 75,      // Plus agressif
    'gpt-4o': 85,               // Plus tolérant
    'gpt-4o-mini': -1,          // Hérite du global (80%)
    'claude-haiku': 70          // Très agressif
  }
}

// Résultat:
// - Conversation normale avec Claude Sonnet 4
// - Condensation déclenchée à 75% (seuil personnalisé)
// - Appel LLM via GPT-4o-mini (économique)
// - Prompt personnalisé appliqué
```

### 2.3 Implémentation

```typescript
class NativeCondensationProvider implements ICondensationProvider {
  readonly id = 'native'
  readonly name = 'Native LLM Condensation'
  readonly description = 'Original batch summarization with profile support'
  readonly version = '2.0.0'
  
  private conversationApiHandler: ApiHandler
  private profileConfig: GlobalCondensationConfig
  
  constructor(
    conversationHandler: ApiHandler,
    config: GlobalCondensationConfig
  ) {
    this.conversationApiHandler = conversationHandler
    this.profileConfig = config
  }
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: false,
      supportsLossy: true,
      supportsLLMSummarization: true,
      supportsParallelProcessing: false,
      supportsMultiPass: false,
      supportsFallback: false,
      estimatedSpeed: 'medium'
    }
  }
  
  getConfigSchema(): ConfigSchema {
    return {
      type: 'object',
      properties: {
        maxMessagesToKeep: {
          type: 'number',
          default: 3,
          min: 1,
          max: 10,
          description: 'Number of recent messages to preserve'
        },
        condensingApiConfigId: {
          type: 'string',
          description: 'Profile ID for condensation (optional)'
        },
        customCondensingPrompt: {
          type: 'string',
          description: 'Custom summarization prompt (optional)'
        }
      }
    }
  }
  
  async estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number> {
    const apiHandler = this.selectApiHandler(config)
    const modelInfo = apiHandler.getModelInfo()
    
    // Estimation basée sur le modèle
    const inputTokens = context.tokenCount
    const outputTokens = Math.min(1000, inputTokens * 0.1)  // ~10% du input
    
    return calculateCost({
      provider: modelInfo.provider,
      model: modelInfo.model,
      inputTokens,
      outputTokens,
      cacheCreationTokens: 0,
      cacheReadTokens: 0
    })
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const startTokens = context.tokenCount
    const apiHandler = this.selectApiHandler(options.config)
    const prompt = this.selectPrompt(options.config)
    const keepCount = options.config?.maxMessagesToKeep || 3
    
    // Validation
    const messagesToSummarize = this.getMessagesSinceLastSummary(
      context.messages.slice(0, -keepCount)
    )
    
    if (messagesToSummarize.length <= 1) {
      throw new Error('Not enough messages to condense')
    }
    
    const keepMessages = context.messages.slice(-keepCount)
    const recentSummaryExists = keepMessages.some(m => m.isSummary)
    
    if (recentSummaryExists) {
      throw new Error('Already condensed recently')
    }
    
    // Structure: [first, ...middle, ...recent]
    const firstMessage = context.messages[0]
    
    // Préparer le prompt avec les messages
    const requestMessages: ApiMessage[] = [
      {
        role: 'user',
        content: this.buildSummarizationRequest(
          messagesToSummarize,
          context.systemPrompt
        )
      }
    ]
    
    // Appel LLM
    const stream = apiHandler.createMessage(prompt, requestMessages)
    
    let summary = ''
    let cost = 0
    let outputTokens = 0
    
    for await (const chunk of stream) {
      if (chunk.type === 'text') {
        summary += chunk.text
      } else if (chunk.type === 'usage') {
        cost = chunk.totalCost ?? 0
        outputTokens = chunk.outputTokens ?? 0
      }
    }
    
    // Construire message de résumé
    const summaryMessage: ApiMessage = {
      role: 'assistant',
      content: summary,
      isSummary: true
    }
    
    // Recomposer
    const newMessages = [firstMessage, summaryMessage, ...keepMessages]
    
    // Calculer nouveaux tokens
    const contextBlocks = this.buildContextBlocks(
      newMessages,
      context.systemPrompt
    )
    const newTokens = outputTokens + await apiHandler.countTokens(contextBlocks)
    
    // Garantie de réduction
    if (newTokens >= startTokens) {
      throw new Error(
        `Condensation failed: context grew from ${startTokens} to ${newTokens}`
      )
    }
    
    return {
      messages: newMessages,
      stats: {
        originalTokens: startTokens,
        finalTokens: newTokens,
        reductionPercent: ((startTokens - newTokens) / startTokens) * 100,
        cost,
        operationsPerformed: ['batch_llm_summarization']
      }
    }
  }
  
  private selectApiHandler(config: any): ApiHandler {
    // Implémentation détaillée ci-dessus
    if (config?.condensingApiConfigId) {
      const handler = this.getHandlerForProfile(config.condensingApiConfigId)
      if (handler && this.validateHandler(handler)) {
        return handler
      }
    }
    return this.conversationApiHandler
  }
  
  private selectPrompt(config: any): string {
    const DEFAULT_PROMPT = `
You are a conversation summarizer. Create a concise summary of the provided 
conversation that preserves all critical information: decisions made, problems 
solved, and pending issues. Focus on technical details and context.
    `.trim()
    
    return config?.customCondensingPrompt?.trim() || DEFAULT_PROMPT
  }
  
  private getMessagesSinceLastSummary(messages: ApiMessage[]): ApiMessage[] {
    // Trouver le dernier résumé
    let lastSummaryIndex = -1
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isSummary) {
        lastSummaryIndex = i
        break
      }
    }
    
    // Retourner tous les messages après le dernier résumé
    return messages.slice(lastSummaryIndex + 1)
  }
  
  private buildSummarizationRequest(
    messages: ApiMessage[],
    systemPrompt: string
  ): string {
    // Format messages pour le LLM
    return `System Context:\n${systemPrompt}\n\n` +
           `Conversation to summarize:\n\n` +
           messages.map((m, i) => 
             `Message ${i + 1} (${m.role}):\n${this.formatMessage(m)}`
           ).join('\n\n')
  }
  
  private formatMessage(message: ApiMessage): string {
    if (typeof message.content === 'string') {
      return message.content
    }
    // Format complex content blocks
    return message.content.map(block => {
      if (block.type === 'text') return block.text
      if (block.type === 'tool_use') return `[Tool: ${block.name}]`
      if (block.type === 'tool_result') return `[Result: ...]`
      return ''
    }).join('\n')
  }
  
  private buildContextBlocks(
    messages: ApiMessage[],
    systemPrompt: string
  ): ContentBlock[] {
    // Construire les blocs pour compter les tokens
    return [
      { type: 'text', text: systemPrompt },
      ...messages.flatMap(m => this.messageToBlocks(m))
    ]
  }
}
```

### 2.4 Métriques et Monitoring

#### Métriques Clés

```typescript
interface NativeProviderMetrics {
  // Performance
  averageLatency: number          // ~2-5s
  tokensProcessedPerSecond: number
  
  // Efficacité
  averageReductionPercent: number // ~40-60%
  guaranteedReduction: boolean    // true (vérifié)
  
  // Coût
  averageCostPerCondensation: number
  costByProfile: Record<string, number>
  
  // Qualité
  summaryQualityScore?: number    // Si évaluation
  informationPreservation: number // Estimation
}
```

#### Exemple de Tracking

```typescript
class NativeProviderMonitor {
  private metrics: NativeProviderMetrics[] = []
  
  async trackCondensation(
    context: ConversationContext,
    result: CondensationResult,
    startTime: number
  ): Promise<void> {
    const latency = Date.now() - startTime
    const reduction = result.stats.reductionPercent
    
    this.metrics.push({
      timestamp: Date.now(),
      latency,
      reduction,
      cost: result.stats.cost,
      profileUsed: context.apiHandler.getModelInfo().model,
      originalTokens: result.stats.originalTokens,
      finalTokens: result.stats.finalTokens
    })
    
    // Alertes
    if (reduction < 20) {
      console.warn('Low reduction efficiency:', reduction)
    }
    if (result.stats.cost > 0.1) {
      console.warn('High condensation cost:', result.stats.cost)
    }
  }
  
  getAverageMetrics(): NativeProviderMetrics {
    // Calculer moyennes
    return {
      averageLatency: this.average('latency'),
      averageReductionPercent: this.average('reduction'),
      averageCostPerCondensation: this.average('cost'),
      // ...
    }
  }
}
```

### 2.5 Calcul du Coût par Provider

#### Différences Anthropic vs OpenAI

**Important** (du cost.ts):

```typescript
// Anthropic: inputTokens N'INCLUT PAS les tokens cachés
function calculateApiCostAnthropic(
  modelInfo: ModelInfo,
  inputTokens: number,              // Non-cachés uniquement
  outputTokens: number,
  cacheCreationInputTokens?: number,
  cacheReadInputTokens?: number
): number {
  const cacheWritesCost = 
    ((modelInfo.cacheWritesPrice || 0) / 1_000_000) * 
    (cacheCreationInputTokens || 0)
    
  const cacheReadsCost = 
    ((modelInfo.cacheReadsPrice || 0) / 1_000_000) * 
    (cacheReadInputTokens || 0)
    
  const baseInputCost = 
    ((modelInfo.inputPrice || 0) / 1_000_000) * inputTokens
    
  const outputCost = 
    ((modelInfo.outputPrice || 0) / 1_000_000) * outputTokens
  
  return cacheWritesCost + cacheReadsCost + baseInputCost + outputCost
}

// OpenAI: inputTokens INCLUT les tokens cachés
function calculateApiCostOpenAI(
  modelInfo: ModelInfo,
  inputTokens: number,               // Total incluant cache
  outputTokens: number,
  cacheCreationInputTokens?: number,
  cacheReadInputTokens?: number
): number {
  const cacheCreation = cacheCreationInputTokens || 0
  const cacheRead = cacheReadInputTokens || 0
  
  // Soustraire pour isoler tokens non-cachés
  const nonCachedInputTokens = Math.max(
    0,
    inputTokens - cacheCreation - cacheRead
  )
  
  // Même formule que Anthropic mais avec tokens recalculés
  return calculateApiCostInternal(
    modelInfo,
    nonCachedInputTokens,
    outputTokens,
    cacheCreation,
    cacheRead
  )
}
```

#### Impact du Profil sur le Coût

| Scénario | Handler | Modèle | Input | Output | Coût |
|----------|---------|--------|-------|--------|------|
| **Sans profil** | Conversation | Claude Sonnet 4 | 20K | 1K | $0.075 |
| **Avec profil GPT-4o-mini** | Condensation | GPT-4o-mini | 20K | 1K | $0.0036 |
| **Économie** | - | - | - | - | **95.2%** |

**Formule complète**:

```
Coût Total = Coût Écriture Cache + Coût Lecture Cache + 
             Coût Input Base + Coût Output

Où:
  Coût Écriture Cache = (prix_écriture / 1M) × tokens_création_cache
  Coût Lecture Cache  = (prix_lecture / 1M) × tokens_lecture_cache
  Coût Input Base     = (prix_input / 1M) × tokens_input_non_cachés
  Coût Output         = (prix_output / 1M) × tokens_output
```

---

## 3. Lossless Provider

### 3.1 Description et Optimisations

Le **Lossless Provider** effectue des optimisations **sans perte d'information** en exploitant la redondance et l'obsolescence dans les conversations.

**Principe**: Identifier et éliminer les duplications tout en préservant l'information complète via des références.

**Caractéristiques**:
- Aucune perte d'information
- Rapide (pas d'appel LLM)
- Gratuit (calcul local)
- Réduction modeste (20-40%)

**Use Case**: Prétraitement avant condensation lossy, ou utilisateur qui refuse toute perte d'info.

### 3.2 Les 4 Techniques d'Optimisation

#### 3.2.1 Déduplication des File Reads

**Problème**: Le même fichier peut être lu plusieurs fois dans une conversation, créant une duplication massive.

**Solution**: Remplacer les lectures anciennes par une référence vers la plus récente.

```typescript
async deduplicateFileReads(
  messages: ApiMessage[]
): Promise<{ messages: ApiMessage[], tokensSaved: number }> {
  const fileReads = new Map<string, {
    index: number
    content: string
    tokens: number
  }>()
  
  // Pass 1: Identifier toutes les lectures de fichiers
  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i]
    if (this.isToolResult(msg, 'read_file')) {
      const path = this.extractFilePath(msg)
      const content = this.extractContent(msg)
      const tokens = await this.countTokens(content)
      
      // Garder seulement la plus récente
      if (!fileReads.has(path) || fileReads.get(path)!.index < i) {
        fileReads.set(path, { index: i, content, tokens })
      }
    }
  }
  
  // Pass 2: Remplacer anciennes lectures par références
  let tokensSaved = 0
  const processed = messages.map((msg, i) => {
    if (this.isToolResult(msg, 'read_file')) {
      const path = this.extractFilePath(msg)
      const latest = fileReads.get(path)!
      
      if (i < latest.index) {
        // Lecture ancienne → référence
        tokensSaved += latest.tokens - 50  // Référence ~50 tokens
        return this.createFileReference(path, latest.index)
      }
    }
    return msg
  })
  
  return { messages: processed, tokensSaved }
}

private createFileReference(
  path: string,
  latestIndex: number
): ApiMessage {
  return {
    role: 'user',
    content: [{
      type: 'tool_result',
      tool_use_id: 'dedup_ref',
      content: `[File Reference] ${path} (see message #${latestIndex} for content)`
    }]
  }
}
```

**Exemple**:

```
Avant:
  Message 10: read_file(main.ts) → 2000 tokens
  Message 50: read_file(main.ts) → 2000 tokens (identique)
  Message 80: read_file(main.ts) → 2000 tokens (identique)

Après:
  Message 10: [Ref] main.ts → see message #80 (50 tokens)
  Message 50: [Ref] main.ts → see message #80 (50 tokens)
  Message 80: read_file(main.ts) → 2000 tokens (original)
  
Économie: 3900 tokens (65%)
```

#### 3.2.2 Consolidation des Tool Results

**Problème**: Les mêmes résultats d'outils peuvent être générés plusieurs fois (ex: même erreur répétée).

**Solution**: Détecter les résultats identiques et les consolider.

```typescript
async consolidateToolResults(
  messages: ApiMessage[]
): Promise<{ messages: ApiMessage[], tokensSaved: number }> {
  const resultGroups = new Map<string, {
    indices: number[]
    content: string
    tokens: number
  }>()
  
  // Grouper résultats identiques
  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i]
    if (this.hasToolResult(msg)) {
      const hash = this.hashToolResult(msg)
      const content = this.extractContent(msg)
      const tokens = await this.countTokens(content)
      
      if (!resultGroups.has(hash)) {
        resultGroups.set(hash, { indices: [], content, tokens })
      }
      resultGroups.get(hash)!.indices.push(i)
    }
  }
  
  // Consolider duplicatas
  let tokensSaved = 0
  const processed = messages.map((msg, i) => {
    if (this.hasToolResult(msg)) {
      const hash = this.hashToolResult(msg)
      const group = resultGroups.get(hash)!
      
      if (group.indices[0] === i) {
        // Première occurrence → garder
        if (group.indices.length > 1) {
          // Ajouter note de duplication
          return this.addDuplicationNote(msg, group.indices.length)
        }
        return msg
      } else {
        // Duplicata → référence
        tokensSaved += group.tokens - 30
        return this.createResultReference(group.indices[0])
      }
    }
    return msg
  })
  
  return { messages: processed, tokensSaved }
}

private hashToolResult(message: ApiMessage): string {
  // Hash stable du contenu (ignorer métadonnées)
  const content = this.extractContent(message)
  return crypto.createHash('sha256')
    .update(content)
    .digest('hex')
    .substring(0, 16)
}
```

#### 3.2.3 Suppression d'États Obsolètes

**Problème**: Certaines informations sont supersédées par des versions plus récentes (ex: brouillon vs version finale).

**Solution**: Identifier et supprimer les états intermédiaires obsolètes.

```typescript
async removeObsoleteState(
  messages: ApiMessage[]
): Promise<{ messages: ApiMessage[], tokensSaved: number }> {
  const stateTracking = new Map<string, {
    versions: Array<{ index: number, version: string }>
  }>()
  
  // Identifier les versions d'états
  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i]
    const state = this.extractStateInfo(msg)
    
    if (state) {
      const key = state.entityId
      if (!stateTracking.has(key)) {
        stateTracking.set(key, { versions: [] })
      }
      stateTracking.get(key)!.versions.push({
        index: i,
        version: state.version
      })
    }
  }
  
  // Marquer versions obsolètes
  const obsolete = new Set<number>()
  for (const [_, state] of stateTracking) {
    if (state.versions.length > 1) {
      // Garder seulement la dernière version
      const latest = state.versions[state.versions.length - 1]
      for (const v of state.versions) {
        if (v.index !== latest.index) {
          obsolete.add(v.index)
        }
      }
    }
  }
  
  // Supprimer obsolètes
  let tokensSaved = 0
  const processed = messages.filter((msg, i) => {
    if (obsolete.has(i)) {
      tokensSaved += this.estimateTokens(msg)
      return false
    }
    return true
  })
  
  return { messages: processed, tokensSaved }
}

private extractStateInfo(message: ApiMessage): StateInfo | null {
  // Détecter patterns d'état:
  // - Fichiers en cours d'édition
  // - Résultats de recherche
  // - États temporaires
  
  if (this.isToolResult(message, 'write_to_file')) {
    const path = this.extractFilePath(message)
    return {
      entityId: `file:${path}`,
      version: message.timestamp || 'unknown'
    }
  }
  
  return null
}
```

#### 3.2.4 Cache de Références

**Optimisation**: Maintenir un cache des références pour éviter recalculs.

```typescript
class ReferenceCache {
  private cache = new Map<string, {
    targetIndex: number
    referenceText: string
    tokenCount: number
  }>()
  
  getOrCreate(
    key: string,
    creator: () => { targetIndex: number, referenceText: string }
  ): { targetIndex: number, referenceText: string, tokenCount: number } {
    if (!this.cache.has(key)) {
      const ref = creator()
      this.cache.set(key, {
        ...ref,
        tokenCount: this.estimateTokens(ref.referenceText)
      })
    }
    return this.cache.get(key)!
  }
  
  clear(): void {
    this.cache.clear()
  }
}
```

### 3.3 Implémentation Complète

```typescript
class LosslessCondensationProvider implements ICondensationProvider {
  readonly id = 'lossless'
  readonly name = 'Lossless Optimization'
  readonly description = 'Zero information loss via deduplication and references'
  readonly version = '1.0.0'
  
  private referenceCache = new ReferenceCache()
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: true,
      supportsLossy: false,
      supportsLLMSummarization: false,
      supportsParallelProcessing: true,
      supportsMultiPass: false,
      supportsFallback: true,
      estimatedSpeed: 'fast'
    }
  }
  
  getConfigSchema(): ConfigSchema {
    return {
      type: 'object',
      properties: {
        deduplicateFileReads: {
          type: 'boolean',
          default: true,
          description: 'Replace duplicate file reads with references'
        },
        consolidateToolResults: {
          type: 'boolean',
          default: true,
          description: 'Merge identical tool results'
        },
        removeObsoleteState: {
          type: 'boolean',
          default: true,
          description: 'Remove superseded intermediate states'
        },
        maintainReferenceCache: {
          type: 'boolean',
          default: true,
          description: 'Cache references for performance'
        }
      }
    }
  }
  
  async estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number> {
    return 0  // Gratuit
  }
  
  async estimateReduction(
    context: ConversationContext,
    config?: any
  ): Promise<TokenEstimate> {
    // Estimation basée sur patterns
    const fileReadCount = this.countFileReads(context.messages)
    const duplicateResults = this.estimateDuplicates(context.messages)
    
    const estimatedSavings = 
      (fileReadCount * 1500) +     // ~1500 tokens par file read dupliqué
      (duplicateResults * 500)      // ~500 tokens par result dupliqué
    
    return {
      estimatedReduction: Math.min(
        estimatedSavings,
        context.tokenCount * 0.4  // Max 40%
      ),
      confidence: 0.7
    }
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const startTokens = context.tokenCount
    let messages = [...context.messages]
    const operations: string[] = []
    let totalSaved = 0
    
    const config = options.config || {}
    
    // Phase 1: Déduplication des file reads
    if (config.deduplicateFileReads !== false) {
      const result = await this.deduplicateFileReads(messages)
      messages = result.messages
      totalSaved += result.tokensSaved
      operations.push('file_deduplication')
    }
    
    // Phase 2: Consolidation des résultats
    if (config.consolidateToolResults !== false) {
      const result = await this.consolidateToolResults(messages)
      messages = result.messages
      totalSaved += result.tokensSaved
      operations.push('result_consolidation')
    }
    
    // Phase 3: Suppression d'états obsolètes
    if (config.removeObsoleteState !== false) {
      const result = await this.removeObsoleteState(messages)
      messages = result.messages
      totalSaved += result.tokensSaved
      operations.push('obsolete_removal')
    }
    
    // Calculer tokens finaux
    const finalTokens = await this.countTotalTokens(messages)
    
    // Nettoyage cache si désactivé
    if (config.maintainReferenceCache === false) {
      this.referenceCache.clear()
    }
    
    return {
      messages,
      stats: {
        originalTokens: startTokens,
        finalTokens,
        reductionPercent: ((startTokens - finalTokens) / startTokens) * 100,
        cost: 0,
        operationsPerformed: operations
      }
    }
  }
}
```

### 3.4 Cas d'Usage

#### Cas 1: Développement avec Lecture de Fichiers Fréquente

```
Contexte: 100 messages, 50K tokens
- 20 lectures du même fichier main.ts (2K tokens chacune)
- Contenu identique ou très similaire

Résultat Lossless:
- 19 références créées (19 × 50 = 950 tokens)
- 1 lecture complète gardée (2K tokens)
- Économie: 38K tokens (76%)
- Tokens finaux: 14K tokens (72% reduction totale)
```

#### Cas 2: Débogage avec Erreurs Répétées

```
Contexte: 150 messages, 80K tokens
- Même erreur apparaît 15 fois
- Chaque erreur: 500 tokens

Résultat Lossless:
- 14 références créées
- 1 erreur complète gardée
- Économie: 7K tokens (9%)
- Tokens finaux: 73K tokens
```

#### Cas 3: Édition Itérative de Fichiers

```
Contexte: 80 messages, 60K tokens
- Fichier édité 10 fois (versions intermédiaires)
- Chaque version: 3K tokens

Résultat Lossless (removeObsoleteState):
- 9 versions intermédiaires supprimées
- 1 version finale gardée
- Économie: 27K tokens (45%)
- Tokens finaux: 33K tokens
```

---

## 4. Truncation Provider

### 4.1 Description et Règles

Le **Truncation Provider** effectue une réduction **mécanique et déterministe** basée sur des règles simples de troncature.

**Principe**: Appliquer des seuils de lignes/caractères pour réduire rapidement le contenu sans analyse sémantique.

**Caractéristiques**:
- Très rapide (<100ms)
- Gratuit (calcul local)
- Perte d'information contrôlée
- Déterministe et reproductible

**Use Case**: Besoin de réduction rapide, budget API limité, ou première passe avant LLM.

### 4.2 Règles de Truncation

#### Zones de Traitement

```
┌─────────────────────────────────────────────────────────┐
│                      Messages                            │
├─────────────────────────────────────────────────────────┤
│ [First] → Always preserved                              │
│                                                          │
│ [Old Zone] → Candidates for truncation                  │
│   - Age-based selection                                 │
│   - Preserve user/assistant text (configurable)         │
│   - Truncate/suppress tool content                      │
│                                                          │
│ [Recent (N)] → Always preserved intact                  │
└─────────────────────────────────────────────────────────┘
```

#### Règles par Type de Contenu

```typescript
interface TruncationRules {
  // Sélection
  preserveRecentCount: number       // N messages récents intacts
  
  // Messages texte
  preserveUserMessages: boolean     // Toujours garder user text
  preserveAssistantText: boolean    // Toujours garder assistant text
  
  // Tool results
  toolResults: {
    mode: 'suppress' | 'truncate'
    maxLines?: number               // Si truncate
    maxChars?: number               // Alternative
    addEllipsis: boolean           // Indicateur de troncature
  }
  
  // Tool parameters
  toolParameters: {
    mode: 'suppress' | 'truncate' | 'keep'
    maxChars?: number               // Si truncate
    addEllipsis: boolean
  }
  
  // Seuils d'activation
  thresholds: {
    minTokensForTruncation: number  // Truncate si > seuil
  }
}
```

### 4.3 Configuration et Exemples

#### Configuration par Défaut

```typescript
const DEFAULT_TRUNCATION_CONFIG: TruncationRules = {
  preserveRecentCount: 5,
  
  preserveUserMessages: true,
  preserveAssistantText: true,
  
  toolResults: {
    mode: 'truncate',
    maxLines: 5,
    addEllipsis: true
  },
  
  toolParameters: {
    mode: 'truncate',
    maxChars: 100,
    addEllipsis: true
  },
  
  thresholds: {
    minTokensForTruncation: 100
  }
}
```

#### Exemple: Mode Suppress

```typescript
const aggressiveConfig: TruncationRules = {
  preserveRecentCount: 3,
  
  preserveUserMessages: true,
  preserveAssistantText: true,
  
  toolResults: {
    mode: 'suppress',  // Supprimer entièrement
    addEllipsis: false
  },
  
  toolParameters: {
    mode: 'suppress',
    addEllipsis: false
  },
  
  thresholds: {
    minTokensForTruncation: 50
  }
}

// Résultat:
// Old zone: [User text preserved] [Assistant text preserved]
//           [Tool results → suppressed] [Tool params → suppressed]
```

#### Exemple: Mode Truncate Équilibré

```typescript
const balancedConfig: TruncationRules = {
  preserveRecentCount: 7,
  
  preserveUserMessages: true,
  preserveAssistantText: true,
  
  toolResults: {
    mode: 'truncate',
    maxLines: 10,        // Plus généreux
    addEllipsis: true
  },
  
  toolParameters: {
    mode: 'truncate',
    maxChars: 200,       // Plus généreux
    addEllipsis: true
  },
  
  thresholds: {
    minTokensForTruncation: 200
  }
}
```

### 4.4 Implémentation

```typescript
class TruncationCondensationProvider implements ICondensationProvider {
  readonly id = 'truncation'
  readonly name = 'Mechanical Truncation'
  readonly description = 'Fast deterministic truncation/suppression'
  readonly version = '1.0.0'
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: false,
      supportsLossy: true,
      supportsLLMSummarization: false,
      supportsParallelProcessing: false,
      supportsMultiPass: false,
      supportsFallback: false,
      estimatedSpeed: 'fast'
    }
  }
  
  getConfigSchema(): ConfigSchema {
    return {
      type: 'object',
      properties: {
        preserveRecentCount: {
          type: 'number',
          default: 5,
          min: 1,
          max: 20
        },
        truncationMode: {
          type: 'string',
          enum: ['suppress', 'truncate'],
          default: 'truncate'
        },
        maxToolResultLines: {
          type: 'number',
          default: 5,
          min: 1,
          max: 50
        },
        maxToolParamChars: {
          type: 'number',
          default: 100,
          min: 50,
          max: 500
        },
        preserveUserMessages: {
          type: 'boolean',
          default: true
        },
        preserveAssistantText: {
          type: 'boolean',
          default: true
        }
      }
    }
  }
  
  async estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number> {
    return 0  // Gratuit
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const config = this.normalizeConfig(options.config)
    const messages = context.messages
    const startTokens = context.tokenCount
    
    // Diviser en zones
    const first = messages[0]
    const recent = messages.slice(-config.preserveRecentCount)
    const oldZone = messages.slice(1, -config.preserveRecentCount)
    
    // Traiter old zone
    const processed = oldZone.map(msg => 
      this.processMessage(msg, config)
    )
    
    // Recomposer
    const finalMessages = [first, ...processed, ...recent]
    const finalTokens = await this.countTotalTokens(finalMessages)
    
    return {
      messages: finalMessages,
      stats: {
        originalTokens: startTokens,
        finalTokens,
        reductionPercent: ((startTokens - finalTokens) / startTokens) * 100,
        cost: 0,
        operationsPerformed: ['mechanical_truncation']
      }
    }
  }
  
  private processMessage(
    message: ApiMessage,
    config: TruncationRules
  ): ApiMessage {
    // Préserver user/assistant text
    if (config.preserveUserMessages && 
        message.role === 'user' && 
        !this.hasToolContent(message)) {
      return message
    }
    
    if (config.preserveAssistantText && 
        message.role === 'assistant' && 
        !this.hasToolContent(message)) {
      return message
    }
    
    // Traiter tool content
    if (typeof message.content === 'string') {
      return message
    }
    
    const processedContent = message.content.map(block => {
      if (block.type === 'tool_result') {
        return this.processToolResult(block, config)
      }
      if (block.type === 'tool_use') {
        return this.processToolUse(block, config)
      }
      return block
    })
    
    return {
      ...message,
      content: processedContent
    }
  }
  
  private processToolResult(
    block: ToolResultBlock,
    config: TruncationRules
  ): ContentBlock {
    const rules = config.toolResults
    
    if (rules.mode === 'suppress') {
      return {
        type: 'text',
        text: '[Tool result suppressed for context reduction]'
      }
    }
    
    // Mode truncate
    const content = this.extractBlockContent(block)
    const lines = content.split('\n')
    
    if (lines.length <= rules.maxLines!) {
      return block  // Pas besoin de truncate
    }
    
    const truncated = lines.slice(0, rules.maxLines!).join('\n')
    const ellipsis = rules.addEllipsis 
      ? `\n... (${lines.length - rules.maxLines!} more lines)` 
      : ''
    
    return {
      ...block,
      content: truncated + ellipsis
    }
  }
  
  private processToolUse(
    block: ToolUseBlock,
    config: TruncationRules
  ): ContentBlock {
    const rules = config.toolParameters
    
    if (rules.mode === 'suppress') {
      return {
        type: 'text',
        text: `[Tool call: ${block.name} (parameters suppressed)]`
      }
    }
    
    if (rules.mode === 'keep') {
      return block
    }
    
    // Mode truncate
    const inputStr = JSON.stringify(block.input, null, 2)
    
    if (inputStr.length <= rules.maxChars!) {
      return block
    }
    
    const truncated = inputStr.substring(0, rules.maxChars!)
    const ellipsis = rules.addEllipsis ? '...' : ''
    
    return {
      ...block,
      input: truncated + ellipsis
    }
  }
  
  private normalizeConfig(config: any): TruncationRules {
    return {
      preserveRecentCount: config?.preserveRecentCount || 5,
      preserveUserMessages: config?.preserveUserMessages !== false,
      preserveAssistantText: config?.preserveAssistantText !== false,
      toolResults: {
        mode: config?.truncationMode || 'truncate',
        maxLines: config?.maxToolResultLines || 5,
        addEllipsis: true
      },
      toolParameters: {
        mode: config?.truncationMode || 'truncate',
        maxChars: config?.maxToolParamChars || 100,
        addEllipsis: true
      },
      thresholds: {
        minTokensForTruncation: 100
      }
    }
  }
}
```

### 4.5 Cas d'Usage

#### Cas 1: Réduction Ultra-Rapide

```
Contexte: 200 messages, 100K tokens
Configuration: Aggressive suppress

Résultat:
- Temps: <50ms
- Réduction: 85% (85K tokens supprimés)
- Tokens finaux: 15K
- Coût: $0
```

#### Cas 2: Prétraitement pour LLM

```
Pipeline:
1. Truncation Provider (reduce 60%)
2. Native Provider (reduce remaining 30%)

Avantage:
- Réduction rapide initiale (gratuite)
- LLM sur contexte déjà réduit (coût optimisé)
```

#### Cas 3: Budget API Zéro

```
Cas d'usage: Projet sans budget API
Solution: Truncation seul

Compromis:
- Perte d'information significative
- Mais conversation reste fonctionnelle
- Coût: $0 (aucun appel API)
```

---

## 5. Smart Provider - Architecture Pass-Based

### 5.1 Vue d'Ensemble

Le **Smart Provider** est le provider le plus sophistiqué, basé sur une architecture **pass-based modulaire** où la condensation est configurée comme une séquence de passes exécutées avec des conditions et des opérations fines.

**Innovation Clé**: Au lieu de phases fixes (lossless, lossy, LLM), on a des **passes configurables** qui peuvent être enchaînées, chacune avec:
- Stratégie de sélection
- Mode de traitement (batch ou individual)
- Opérations par type de contenu
- Conditions d'exécution

**Philosophie**:

```
Lossless Prelude (optional)
    ↓
Pass 1: [config] → execute if [condition]
    ↓
Pass 2: [config] → execute if [condition]
    ↓
...
    ↓
Pass P: [config] → execute if [condition]
```

### 5.2 Modèle de Contenu à 3 Niveaux

**Insight Fondamental**: Chaque message décompose en 3 types de contenu qui peuvent être traités indépendamment:

```typescript
interface DecomposedMessage {
  messageText: string | null      // User/assistant natural language
  toolParameters: any[] | null    // Tool call inputs
  toolResults: any[] | null       // Tool execution outputs
}
```

**Exemple de Décomposition**:

```
Message Original:
{
  role: "user",
  content: [
    { type: "text", text: "Let's read that file" },
    { type: "tool_result", tool_use_id: "123", content: "..." }
  ]
}

Après Décomposition:
{
  messageText: "Let's read that file",
  toolParameters: null,
  toolResults: [{
    tool_use_id: "123",
    content: "..."
  }]
}
```

### 5.3 Les 4 Opérations

Chaque type de contenu peut subir l'une de 4 opérations:

#### 5.3.1 KEEP - Préserver Intact

```typescript
operation: 'keep'
params: {}

// Exemple
messageText: "User question here" → "User question here" (unchanged)
```

**Use Case**: Contenu récent, information critique, messages de contexte.

#### 5.3.2 SUPPRESS - Supprimer Entièrement

```typescript
operation: 'suppress'
params: {}

// Exemple
toolResults: [{content: "500 lines of output"}] 
→ 
{content: "[Tool result suppressed]"}
```

**Use Case**: Contenu redondant, ancien, ou non-critique. Maximum de réduction.

#### 5.3.3 TRUNCATE - Réduire Mécaniquement

```typescript
operation: 'truncate'
params: {
  truncate: {
    maxChars?: number
    maxLines?: number
    addEllipsis?: boolean
  }
}

// Exemple
toolResults: "Line 1\nLine 2\n...\nLine 50"
→ (maxLines: 5)
"Line 1\nLine 2\nLine 3\nLine 4\nLine 5\n... (45 more lines)"
```

**Use Case**: Compromis rapide entre préservation et réduction. Gratuit, déterministe.

#### 5.3.4 SUMMARIZE - Réduire via LLM

```typescript
operation: 'summarize'
params: {
  summarize: {
    apiProfile?: string        // Which API to use
    maxTokens?: number         // Max summary length
    customPrompt?: string      // Custom instruction
  }
}

// Exemple
toolResults: {content: "500 lines of detailed log"}
→ (via LLM)
"Error occurred in module X due to Y. Solution attempted: Z"
```

**Use Case**: Meilleure qualité, préservation sémantique. Coûteux mais intelligent.

### 5.4 Configuration des Passes

#### 5.4.1 Structure d'une Passe

```typescript
interface PassConfig {
  // Identification
  id: string
  name: string
  description?: string
  
  // Sélection des messages
  selection: SelectionStrategy
  
  // Mode de traitement
  mode: 'batch' | 'individual'
  
  // Configuration selon le mode
  batchConfig?: BatchModeConfig
  individualConfig?: IndividualModeConfig
  
  // Condition d'exécution
  execution: ExecutionCondition
}
```

#### 5.4.2 Stratégies de Sélection

```typescript
interface SelectionStrategy {
  type: 'preserve_recent' | 'preserve_percent' | 'custom'
  
  // Pour preserve_recent
  keepRecentCount?: number    // Ex: garder 5 derniers
  
  // Pour preserve_percent
  keepPercentage?: number     // Ex: garder 50%
  
  // Pour custom
  customSelector?: (messages: ApiMessage[]) => ApiMessage[]
}

// Exemples
const recentSelection: SelectionStrategy = {
  type: 'preserve_recent',
  keepRecentCount: 5
}
// → Traite tous les messages sauf les 5 derniers

const percentSelection: SelectionStrategy = {
  type: 'preserve_percent',
  keepPercentage: 30
}
// → Traite 70% des messages les plus anciens
```

#### 5.4.3 Modes: Batch vs Individual

##### Batch Mode

**Concept**: Traiter tous les messages sélectionnés comme un bloc unique (comme Native Provider).

```typescript
interface BatchModeConfig {
  operation: 'keep' | 'summarize'
  
  summarizationConfig?: {
    apiProfile?: string       // Ex: 'gpt-4o-mini'
    customPrompt?: string
    keepFirst: number         // Messages à préserver au début
    keepLast: number          // Messages à préserver à la fin
  }
}

// Exemple
const batchPass: PassConfig = {
  id: 'batch-summarize',
  name: 'Batch LLM Summary',
  selection: { type: 'preserve_recent', keepRecentCount: 10 },
  mode: 'batch',
  batchConfig: {
    operation: 'summarize',
    summarizationConfig: {
      apiProfile: 'gpt-4o-mini',
      keepFirst: 1,
      keepLast: 5
    }
  },
  execution: { type: 'always' }
}

// Résultat:
// [First] [Summary of middle 30-40 messages] [Last 10]
```

##### Individual Mode

**Concept**: Traiter chaque message indépendamment avec contrôle fin par type de contenu.

```typescript
interface IndividualModeConfig {
  // Opérations par défaut
  defaults: ContentTypeOperations
  
  // Overrides per-message (optionnel)
  overrides?: {
    messageIndex: number
    operations: Partial<ContentTypeOperations>
  }[]
}

interface ContentTypeOperations {
  messageText: ContentOperation
  toolParameters: ContentOperation
  toolResults: ContentOperation
}

// Exemple
const individualPass: PassConfig = {
  id: 'individual-truncate',
  name: 'Fine-Grained Truncation',
  selection: { type: 'preserve_recent', keepRecentCount: 5 },
  mode: 'individual',
  individualConfig: {
    defaults: {
      messageText: { operation: 'keep' },
      toolParameters: { 
        operation: 'truncate',
        params: { truncate: { maxChars: 100 } }
      },
      toolResults: { 
        operation: 'truncate',
        params: { truncate: { maxLines: 5 } }
      }
    }
  },
  execution: { type: 'always' }
}

// Résultat par message:
// - Message text preserved
// - Tool params truncated to 100 chars
// - Tool results truncated to 5 lines
```

#### 5.4.4 Conditions d'Exécution

```typescript
interface ExecutionCondition {
  type: 'always' | 'conditional'
  
  condition?: {
    tokenThreshold: number    // Execute if currentTokens > threshold
    // Autres conditions possibles
  }
}

// Exemple: Always (Systematic Multi-Pass)
const alwaysPass: PassConfig = {
  // ...
  execution: { type: 'always' }
}
// → Execute à chaque fois, systématiquement

// Exemple: Conditional (Fallback Pattern)
const fallbackPass
: PassConfig = {
  // ...
  execution: {
    type: 'conditional',
    condition: { tokenThreshold: 50000 }
  }
}
// → Execute seulement si contexte > 50K tokens
```

#### 5.4.5 Ordre et Séquençage

Les passes sont exécutées **séquentiellement** dans l'ordre de configuration:

```typescript
const config: SmartProviderConfig = {
  losslessPrelude: { enabled: true },
  passes: [
    pass1,  // Execute first
    pass2,  // Then this
    pass3   // Finally this (if needed)
  ]
}

// Flux d'exécution:
// 1. Lossless prelude (if enabled)
// 2. Check tokens → still over target?
// 3. Execute pass1 (if condition met)
// 4. Check tokens → still over target?
// 5. Execute pass2 (if condition met)
// 6. Check tokens → still over target?
// 7. Execute pass3 (if condition met)
// 8. Return result
```

**Early Exit**: Si le target est atteint après une passe, les suivantes ne sont pas exécutées.

### 5.5 Exemples de Configurations Smart

#### 5.5.1 Configuration Conservative

**Objectif**: Réduction maximale de qualité, coût acceptable.

```typescript
const conservativeConfig: SmartProviderConfig = {
  losslessPrelude: {
    enabled: true,
    operations: {
      deduplicateFileReads: true,
      consolidateToolResults: true,
      removeObsoleteState: true
    }
  },
  
  passes: [
    {
      id: 'pass-1-quality',
      name: 'LLM Summarization of Old Content',
      selection: {
        type: 'preserve_recent',
        keepRecentCount: 10
      },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'keep' },
          toolResults: {
            operation: 'summarize',
            params: {
              summarize: {
                apiProfile: 'claude-haiku',  // Fast & cheap
                maxTokens: 150
              }
            }
          }
        }
      },
      execution: { type: 'always' }
    },
    
    {
      id: 'pass-2-fallback',
      name: 'Batch Summary Fallback',
      selection: {
        type: 'preserve_percent',
        keepPercentage: 40
      },
      mode: 'batch',
      batchConfig: {
        operation: 'summarize',
        summarizationConfig: {
          apiProfile: 'gpt-4o-mini',
          keepFirst: 1,
          keepLast: 8
        }
      },
      execution: {
        type: 'conditional',
        condition: { tokenThreshold: 40000 }
      }
    }
  ]
}

// Résultat Attendu:
// - Réduction: 60-70%
// - Coût: $0.02-0.05
// - Qualité: Élevée
// - Temps: 3-8s
```

#### 5.5.2 Configuration Balanced

**Objectif**: Équilibre coût/qualité/vitesse.

```typescript
const balancedConfig: SmartProviderConfig = {
  losslessPrelude: { enabled: true, operations: { /* all true */ } },
  
  passes: [
    // Pass 1: Quick mechanical reduction
    {
      id: 'mechanical',
      name: 'Mechanical Truncation',
      selection: { type: 'preserve_recent', keepRecentCount: 5 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: {
            operation: 'truncate',
            params: { truncate: { maxChars: 150 } }
          },
          toolResults: {
            operation: 'truncate',
            params: { truncate: { maxLines: 8 } }
          }
        }
      },
      execution: { type: 'always' }
    },
    
    // Pass 2: LLM only if still needed
    {
      id: 'llm-selective',
      name: 'Selective LLM Summary',
      selection: { type: 'preserve_recent', keepRecentCount: 10 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'keep' },
          toolResults: {
            operation: 'summarize',
            params: {
              summarize: {
                apiProfile: 'gpt-4o-mini',
                maxTokens: 100
              }
            }
          }
        }
      },
      execution: {
        type: 'conditional',
        condition: { tokenThreshold: 45000 }
      }
    },
    
    // Pass 3: Aggressive fallback
    {
      id: 'aggressive-fallback',
      name: 'Aggressive Suppression',
      selection: { type: 'preserve_recent', keepRecentCount: 15 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'suppress' },
          toolResults: { operation: 'suppress' }
        }
      },
      execution: {
        type: 'conditional',
        condition: { tokenThreshold: 35000 }
      }
    }
  ]
}

// Résultat Attendu:
// - Réduction: 70-80%
// - Coût: $0.005-0.02
// - Qualité: Moyenne
// - Temps: 1-4s
```

#### 5.5.3 Configuration Aggressive

**Objectif**: Réduction maximale, coût minimal.

```typescript
const aggressiveConfig: SmartProviderConfig = {
  losslessPrelude: { enabled: true, operations: { /* all true */ } },
  
  passes: [
    // Pass 1: Suppress old content
    {
      id: 'suppress-ancient',
      name: 'Suppress Very Old',
      selection: { type: 'preserve_recent', keepRecentCount: 30 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'suppress' },
          toolResults: { operation: 'suppress' }
        }
      },
      execution: { type: 'always' }
    },
    
    // Pass 2: Truncate middle
    {
      id: 'truncate-middle',
      name: 'Truncate Middle Zone',
      selection: { type: 'preserve_recent', keepRecentCount: 10 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: {
            operation: 'truncate',
            params: { truncate: { maxChars: 80 } }
          },
          toolResults: {
            operation: 'truncate',
            params: { truncate: { maxLines: 3 } }
          }
        }
      },
      execution: { type: 'always' }
    },
    
    // Pass 3: Emergency LLM (rare)
    {
      id: 'emergency-llm',
      name: 'Emergency Batch Summary',
      selection: { type: 'preserve_percent', keepPercentage: 20 },
      mode: 'batch',
      batchConfig: {
        operation: 'summarize',
        summarizationConfig: {
          apiProfile: 'gpt-4o-mini',
          keepFirst: 1,
          keepLast: 5
        }
      },
      execution: {
        type: 'conditional',
        condition: { tokenThreshold: 30000 }
      }
    }
  ]
}

// Résultat Attendu:
// - Réduction: 85-95%
// - Coût: $0-0.01
// - Qualité: Faible
// - Temps: <500ms
```

#### 5.5.4 Configuration Custom - Multi-Zone

**Objectif**: Traitement différencié par zone d'âge.

```typescript
const multiZoneConfig: SmartProviderConfig = {
  losslessPrelude: { enabled: true, operations: { /* all true */ } },
  
  passes: [
    // Zone 1: Ancient (50+)
    {
      id: 'zone-ancient',
      name: 'Ancient Messages - Suppress',
      selection: { type: 'preserve_recent', keepRecentCount: 50 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'suppress' },
          toolResults: { operation: 'suppress' }
        }
      },
      execution: { type: 'always' }
    },
    
    // Zone 2: Old (30-50)
    {
      id: 'zone-old',
      name: 'Old Messages - Truncate',
      selection: { type: 'preserve_recent', keepRecentCount: 30 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: {
            operation: 'truncate',
            params: { truncate: { maxChars: 120 } }
          },
          toolResults: {
            operation: 'truncate',
            params: { truncate: { maxLines: 6 } }
          }
        }
      },
      execution: { type: 'always' }
    },
    
    // Zone 3: Medium (10-30)
    {
      id: 'zone-medium',
      name: 'Medium Messages - Light Truncate',
      selection: { type: 'preserve_recent', keepRecentCount: 10 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'keep' },
          toolResults: {
            operation: 'truncate',
            params: { truncate: { maxLines: 15 } }
          }
        }
      },
      execution: { type: 'always' }
    },
    
    // Zone 4: Recent (0-10) - Handled by preserve
    // No pass needed, preserved by selection strategy
  ]
}

// Résultat: Dégradation progressive selon âge
```

### 5.6 Décomposition et Recomposition

#### 5.6.1 Algorithme de Décomposition

```typescript
private decomposeMessage(message: ApiMessage): DecomposedMessage {
  const result: DecomposedMessage = {
    messageText: null,
    toolParameters: null,
    toolResults: null
  }
  
  // Simple string content
  if (typeof message.content === 'string') {
    result.messageText = message.content
    return result
  }
  
  // Complex array content
  if (Array.isArray(message.content)) {
    const textBlocks: string[] = []
    const toolUseBlocks: any[] = []
    const toolResultBlocks: any[] = []
    
    for (const block of message.content) {
      switch (block.type) {
        case 'text':
          textBlocks.push(block.text)
          break
          
        case 'tool_use':
          toolUseBlocks.push({
            id: block.id,
            name: block.name,
            input: block.input
          })
          break
          
        case 'tool_result':
          toolResultBlocks.push({
            tool_use_id: block.tool_use_id,
            content: block.content,
            is_error: block.is_error
          })
          break
      }
    }
    
    // Consolider les résultats
    if (textBlocks.length > 0) {
      result.messageText = textBlocks.join('\n\n')
    }
    if (toolUseBlocks.length > 0) {
      result.toolParameters = toolUseBlocks
    }
    if (toolResultBlocks.length > 0) {
      result.toolResults = toolResultBlocks
    }
  }
  
  return result
}
```

#### 5.6.2 Traitement Indépendant

Chaque type de contenu est traité indépendamment:

```typescript
async processMessage(
  message: ApiMessage,
  operations: ContentTypeOperations,
  options: CondensationOptions
): Promise<{ message: ApiMessage, cost: number }> {
  // 1. Décomposer
  const decomposed = this.decomposeMessage(message)
  
  let totalCost = 0
  
  // 2. Traiter message text
  const processedText = await this.processContent(
    decomposed.messageText,
    operations.messageText,
    'text',
    options
  )
  totalCost += processedText.cost
  
  // 3. Traiter tool parameters
  const processedParams = await this.processContent(
    decomposed.toolParameters,
    operations.toolParameters,
    'params',
    options
  )
  totalCost += processedParams.cost
  
  // 4. Traiter tool results
  const processedResults = await this.processContent(
    decomposed.toolResults,
    operations.toolResults,
    'results',
    options
  )
  totalCost += processedResults.cost
  
  // 5. Recomposer
  const recomposed = this.recomposeMessage(
    message,
    processedText.content,
    processedParams.content,
    processedResults.content
  )
  
  return { message: recomposed, cost: totalCost }
}
```

#### 5.6.3 Recomposition Finale

```typescript
private recomposeMessage(
  original: ApiMessage,
  messageText: string | null,
  toolParameters: any[] | null,
  toolResults: any[] | null
): ApiMessage {
  // Si tout est null, retourner message vide
  if (!messageText && !toolParameters && !toolResults) {
    return {
      ...original,
      content: ''
    }
  }
  
  // Si seulement du texte, format simple
  if (messageText && !toolParameters && !toolResults) {
    return {
      ...original,
      content: messageText
    }
  }
  
  // Format complexe avec blocks
  const content: any[] = []
  
  if (messageText) {
    content.push({ type: 'text', text: messageText })
  }
  
  if (toolParameters) {
    content.push(...toolParameters.map(p => ({
      type: 'tool_use',
      id: p.id,
      name: p.name,
      input: p.input
    })))
  }
  
  if (toolResults) {
    content.push(...toolResults.map(r => ({
      type: 'tool_result',
      tool_use_id: r.tool_use_id,
      content: r.content,
      is_error: r.is_error
    })))
  }
  
  return {
    ...original,
    content
  }
}
```

### 5.7 UI Components

#### 5.7.1 PassConfigurationPanel

```typescript
const PassConfigurationPanel: React.FC<{
  config: SmartProviderConfig
  onChange: (config: SmartProviderConfig) => void
}> = ({ config, onChange }) => {
  const [selectedPassId, setSelectedPassId] = useState<string | null>(null)
  const [previewMode, setPreviewMode] = useState(false)
  
  return (
    <div className="pass-configuration-panel">
      {/* Header */}
      <div className="panel-header">
        <h2>Smart Provider Configuration</h2>
        <div className="actions">
          <Button 
            variant="secondary"
            onClick={() => setPreviewMode(!previewMode)}
          >
            {previewMode ? 'Edit' : 'Preview'}
          </Button>
          <Button
            variant="primary"
            onClick={handleSaveConfig}
          >
            Save Configuration
          </Button>
        </div>
      </div>
      
      {previewMode ? (
        <ConfigPreview config={config} />
      ) : (
        <>
          {/* Lossless Prelude */}
          <Section title="Lossless Prelude (Optional)" collapsible>
            <Checkbox
              label="Enable Lossless Optimizations"
              checked={config.losslessPrelude?.enabled}
              onChange={(v) => onChange({
                ...config,
                losslessPrelude: {
                  ...config.losslessPrelude,
                  enabled: v
                }
              })}
            />
            
            {config.losslessPrelude?.enabled && (
              <div className="lossless-options">
                <Checkbox
                  label="Deduplicate File Reads"
                  checked={config.losslessPrelude.operations.deduplicateFileReads}
                  onChange={(v) => onChange({
                    ...config,
                    losslessPrelude: {
                      ...config.losslessPrelude,
                      operations: {
                        ...config.losslessPrelude.operations,
                        deduplicateFileReads: v
                      }
                    }
                  })}
                />
                <Checkbox
                  label="Consolidate Tool Results"
                  checked={config.losslessPrelude.operations.consolidateToolResults}
                  onChange={/* similar */}
                />
                <Checkbox
                  label="Remove Obsolete State"
                  checked={config.losslessPrelude.operations.removeObsoleteState}
                  onChange={/* similar */}
                />
              </div>
            )}
          </Section>
          
          {/* Pass List */}
          <Section title="Condensation Passes">
            <PassListView
              passes={config.passes}
              selectedPassId={selectedPassId}
              onSelectPass={setSelectedPassId}
              onAddPass={handleAddPass}
              onDeletePass={handleDeletePass}
              onReorderPasses={handleReorderPasses}
            />
          </Section>
          
          {/* Pass Editor */}
          {selectedPassId && (
            <Section title="Pass Configuration">
              <PassEditor
                pass={config.passes.find(p => p.id === selectedPassId)!}
                onChange={handlePassChange}
              />
            </Section>
          )}
          
          {/* Presets */}
          <Section title="Configuration Presets" collapsible>
            <div className="presets">
              <Button onClick={() => loadPreset('conservative')}>
                Conservative (Quality)
              </Button>
              <Button onClick={() => loadPreset('balanced')}>
                Balanced
              </Button>
              <Button onClick={() => loadPreset('aggressive')}>
                Aggressive (Speed/Cost)
              </Button>
              <Button onClick={() => loadPreset('custom')}>
                Custom Multi-Zone
              </Button>
            </div>
          </Section>
        </>
      )}
    </div>
  )
}
```

#### 5.7.2 ContentTypeSelector

```typescript
const ContentTypeSelector: React.FC<{
  contentType: 'messageText' | 'toolParameters' | 'toolResults'
  operation: ContentOperation
  onChange: (operation: ContentOperation) => void
}> = ({ contentType, operation, onChange }) => {
  // Opérations permises selon le type
  const allowedOperations = {
    messageText: ['keep', 'truncate', 'summarize'],
    toolParameters: ['keep', 'suppress', 'truncate'],
    toolResults: ['keep', 'suppress', 'truncate', 'summarize']
  }[contentType]
  
  return (
    <div className="content-type-selector">
      <h4>{formatContentTypeName(contentType)}</h4>
      
      {/* Operation selector */}
      <RadioGroup
        value={operation.operation}
        onChange={(v) => onChange({ ...operation, operation: v })}
      >
        {allowedOperations.map(op => (
          <RadioOption
            key={op}
            value={op}
            label={formatOperationName(op)}
          >
            {getOperationDescription(op)}
          </RadioOption>
        ))}
      </RadioGroup>
      
      {/* Parameters selon l'opération */}
      {operation.operation === 'truncate' && (
        <TruncateParams
          params={operation.params?.truncate || {}}
          onChange={(p) => onChange({
            ...operation,
            params: { ...operation.params, truncate: p }
          })}
        />
      )}
      
      {operation.operation === 'summarize' && (
        <SummarizeParams
          params={operation.params?.summarize || {}}
          onChange={(p) => onChange({
            ...operation,
            params: { ...operation.params, summarize: p }
          })}
        />
      )}
    </div>
  )
}
```

#### 5.7.3 OperationSelector

```typescript
const OperationSelector: React.FC<{
  operation: string
  params: OperationParams | undefined
  allowedOperations: string[]
  onChange: (operation: string, params?: OperationParams) => void
}> = ({ operation, params, allowedOperations, onChange }) => {
  return (
    <div className="operation-selector">
      {/* Main operation dropdown */}
      <Select
        label="Operation"
        value={operation}
        options={allowedOperations.map(op => ({
          value: op,
          label: formatOperationName(op),
          icon: getOperationIcon(op)
        }))}
        onChange={(v) => onChange(v, params)}
      />
      
      {/* Operation badge with info */}
      <OperationBadge operation={operation}>
        {getOperationBadgeInfo(operation)}
      </OperationBadge>
      
      {/* Quick actions */}
      <div className="quick-actions">
        <Button
          size="small"
          variant="ghost"
          onClick={() => onChange('keep')}
        >
          Reset to Keep
        </Button>
      </div>
    </div>
  )
}

function getOperationIcon(operation: string): string {
  return {
    keep: '✓',
    suppress: '✗',
    truncate: '✂',
    summarize: '⚡'
  }[operation] || '?'
}

function getOperationBadgeInfo(operation: string): {
  cost: string
  speed: string
  quality: string
} {
  return {
    keep: { cost: '$0', speed: 'Instant', quality: '100%' },
    suppress: { cost: '$0', speed: 'Instant', quality: '0%' },
    truncate: { cost: '$0', speed: 'Fast', quality: '30-50%' },
    summarize: { cost: '$0.001-0.01', speed: 'Slow', quality: '70-90%' }
  }[operation] || { cost: '?', speed: '?', quality: '?' }
}
```

#### 5.7.4 PreviewPane

```typescript
const PreviewPane: React.FC<{
  config: SmartProviderConfig
  context: ConversationContext
}> = ({ config, context }) => {
  const [preview, setPreview] = useState<PreviewResult | null>(null)
  const [loading, setLoading] = useState(false)
  
  const generatePreview = async () => {
    setLoading(true)
    try {
      const result = await estimateCondensationResult(config, context)
      setPreview(result)
    } finally {
      setLoading(false)
    }
  }
  
  return (
    <div className="preview-pane">
      <div className="preview-header">
        <h3>Preview</h3>
        <Button
          onClick={generatePreview}
          disabled={loading}
        >
          {loading ? 'Generating...' : 'Generate Preview'}
        </Button>
      </div>
      
      {preview && (
        <div className="preview-content">
          {/* Statistics */}
          <div className="preview-stats">
            <StatCard
              label="Original Tokens"
              value={preview.originalTokens}
            />
            <StatCard
              label="Estimated Final"
              value={preview.estimatedTokens}
            />
            <StatCard
              label="Reduction"
              value={`${preview.reductionPercent}%`}
              variant="success"
            />
            <StatCard
              label="Estimated Cost"
              value={`$${preview.estimatedCost.toFixed(4)}`}
              variant={preview.estimatedCost > 0.05 ? 'warning' : 'info'}
            />
          </div>
          
          {/* Pass Breakdown */}
          <div className="pass-breakdown">
            <h4>Pass Execution Plan</h4>
            {preview.passResults.map((pass, i) => (
              <PassPreviewCard
                key={i}
                pass={pass}
                index={i}
              />
            ))}
          </div>
          
          {/* Sample Messages */}
          <div className="sample-messages">
            <h4>Sample Result (First 5 Messages)</h4>
            {preview.sampleMessages.map((msg, i) => (
              <MessagePreview
                key={i}
                message={msg}
                showDiff={true}
              />
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
```

---

## 6. Matrice de Comparaison

### 6.1 Tableau Comparatif Complet

| Caractéristique | Native | Lossless | Truncation | Smart |
|----------------|--------|----------|------------|-------|
| **Performance** |
| Vitesse | Moyen (2-5s) | Rapide (200-500ms) | Très Rapide (<100ms) | Variable (100ms-8s) |
| Complexité Calcul | Élevée (LLM) | Faible (local) | Très Faible (local) | Variable |
| Parallélisation | ❌ | ✅ | ❌ | ✅ (individual mode) |
| **Efficacité** |
| Réduction Tokens | 40-60% | 20-40% | 80-90% | 50-90% |
| Perte Information | Moyenne | Aucune | Élevée | Configurable |
| Déterminisme | ❌ (LLM) | ✅ | ✅ | Partiel |
| Reproductibilité | Faible | Élevée | Élevée | Moyenne |
| **Coût** |
| Coût par Call | ~$0.001-0.075 | $0 | $0 | $0-0.05 |
| Optimisable | ✅ (profils) | N/A | N/A | ✅ (profils + config) |
| Budget Zero | ❌ | ✅ | ✅ | ✅ (config dépendante) |
| **Configurabilité** |
| Complexité Config | Faible | Faible | Moyenne | Très Élevée |
| Profils API | ✅ | ❌ | ❌ | ✅ |
| Multi-Pass | ❌ | ❌ | ❌ | ✅ |
| Fine-Grained Control | ❌ | ❌ | Partiel | ✅ |
| **Fonctionnalités** |
| Lossless | ❌ | ✅ | ❌ | ✅ (optional) |
| LLM Summarization | ✅ | ❌ | ❌ | ✅ (optional) |
| Batch Mode | ✅ | ❌ | ❌ | ✅ |
| Individual Mode | ❌ | ✅ | ✅ | ✅ |
| Fallback Strategy | ❌ | ✅ (to Native) | ❌ | ✅ (multi-level) |
| **Use Cases** |
| Optimal Pour | Utilisateurs standard | Qualité maximale | Vitesse/Budget | Power users |
| Cas d'Usage | Default, simple | Zero-loss requis | Réduction rapide | Custom workflows |
| Évolutivité | Limitée | Limitée | Moyenne | Élevée |

### 6.2 Graphiques Comparatifs

#### Performance vs Qualité

```
Qualité de Préservation (%)
100 │                    Lossless
    │                       ●
 90 │
 80 │            Smart (quality preset)
    │               ●
 70 │
 60 │     Native
    │        ●
 50 │
 40 │                     Smart (aggressive)
    │                         ●
 30 │
 20 │  Truncation
    │     ●
 10 │
  0 └─────────────────────────────────────→
    0    20   40   60   80   100   120
              Réduction Tokens (%)
```

#### Coût vs Réduction

```
Coût ($)
0.10 │
     │
0.08 │                    Native (sans profil)
     │                         ●
0.06 │
     │
0.04 │              Smart (quality)
     │                 ●
0.02 │      Native (profil optimisé)
     │           ●
0.00 │  ●────────●──────────────●
     │  │        │              │
     └──┴────────┴──────────────┴─────────→
        0       40             80        100
        Lossless  Truncation    Réduction (%)
        Smart(aggressive)
```

### 6.3 Cas d'Usage Recommandés

#### Par Scénario

| Scénario | Provider Recommandé | Raison |
|----------|-------------------|--------|
| **Conversation standard** | Native | Simple, efficace, éprouvé |
| **Budget API limité** | Truncation ou Smart (aggressive) | Zero/low cost |
| **Qualité critique** | Lossless → Smart (conservative) | Pipeline qualité |
| **Longue conversation** | Smart (multi-zone) | Dégradation progressive |
| **Développement local** | Truncation | Rapide, reproductible |
| **Production critique** | Smart (balanced + fallback) | Robuste, adaptatif |
| **Prototypage/Tests** | Native | Déjà configuré |
| **Compliance/Audit** | Lossless | Zero loss garanti |

#### Par Contrainte

| Contrainte | Solution |
|------------|----------|
| **Latence < 100ms** | Truncation ou Lossless |
| **Coût < $0.001** | Truncation + Lossless prelude |
| **Réduction > 80%** | Smart (aggressive) ou Truncation |
| **Zero information loss** | Lossless uniquement |
| **Qualité > 80%** | Smart (conservative) |
| **Multi-tenant** | Smart (per-tenant config) |

---

## 7. Guide de Sélection

### 7.1 Arbre de Décision

```
START: Quelle est votre priorité principale?
│
├─ Simplicité / Default
│  └─> Native Provider
│     ✓ Configuration minimale
│     ✓ Marche out-of-the-box
│     ✓ Performances acceptables
│
├─ Zero Information Loss
│  └─> Lossless Provider
│     ✓ Garantie de préservation
│     ✓ Gratuit
│     ⚠ Réduction limitée (20-40%)
│
├─ Vitesse Maximum
│  └─> Truncation Provider
│     ✓ <100ms
│     ✓ Gratuit
│     ⚠ Perte d'information significative
│
├─ Coût Minimum
│  │
│  ├─ Réduction modeste OK
│  │  └─> Lossless Provider
│  │
│  └─ Réduction importante nécessaire
│     └─> Truncation Provider
│
├─ Qualité Maximum
│  │
│  ├─ Coût acceptable
│  │  └─> Smart Provider (conservative preset)
│  │     ✓ LLM summarization
│  │     ✓ Multi-pass
│  │     ✓ Fallback strategy
│  │
│  └─ Coût limité
│     └─> Pipeline: Lossless → Truncation → Native
│
└─ Contrôle Maximum / Custom
   └─> Smart Provider (custom config)
      ✓ Pass-based architecture
      ✓ Fine-grained control
      ✓ Multi-zone processing
      ⚠ Configuration complexe
```

### 7.2 Questionnaire de Sélection

#### Question 1: Budget API

```
Quel est votre budget API par condensation?

A. Illimité ou >$0.05
   → Native ou Smart (quality)

B. $0.01 - $0.05
   → Native (profil optimisé) ou Smart (balanced)

C. $0 - $0.01
   → Smart (cost preset) ou Truncation

D. $0 strict
   → Lossless ou Truncation
```

#### Question 2: Latence Acceptable

```
Quelle latence maximale acceptez-vous?

A. <100ms (temps réel)
   → Truncation obligatoire

B. <500ms (interactive)
   → Lossless ou Truncation

C. <2s (acceptable)
   → Native ou Smart (mechanical passes)

D. <10s (batch)
   → Native ou Smart (with LLM)

E. >10s (background)
   → Smart (quality preset)
```

#### Question 3: Qualité Requise

```
Quelle perte d'information acceptez-vous?

A. 0% (aucune perte)
   → Lossless uniquement

B. <10% (critique)
   → Smart (conservative) ou Lossless+Native

C. <30% (importante)
   → Native ou Smart (balanced)

D. <50% (acceptable)
   → Smart (aggressive) ou Truncation

E. >50% (peu importante)
   → Truncation
```

#### Question 4: Complexité de Configuration

```
Quel niveau de configuration souhaitez-vous?

A. Aucune (default)
   → Native

B. Minimale (presets)
   → Smart (use presets)

C. Moyenne (quelques paramètres)
   → Native (profils) ou Truncation

D. Avancée (custom)
   → Smart (custom config)

E. Maximum (per-message control)
   → Smart (individual mode + overrides)
```

### 7.3 Recommandations par Profil Utilisateur

#### Développeur Solo

```yaml
profile: solo_developer
recommendation: Native Provider
rationale:
  - Configuration minimale
  - Performan acceptable pour usage personnel
  - Coût négligeable (<$1/mois)
  
alternative: Truncation (dev local, reproductibilité)
```

#### Équipe Startup

```yaml
profile: startup_team
recommendation: Native avec Profil Optimisé
config:
  condensingApiConfigId: gpt-4o-mini-profile
  autoCondenseContextPercent: 80
rationale:
  - Balance coût/qualité
  - Simple à maintenir
  - Économie ~90% vs default
  
alternative: Smart (balanced preset) si besoin customization
```

#### Entreprise / Production

```yaml
profile: enterprise_production
recommendation: Smart Provider (custom multi-zone)
config:
  losslessPrelude: enabled
  passes:
    - mechanical truncation (always)
    - conditional LLM (if > threshold)
    - aggressive fallback (if still over)
rationale:
  - Robustesse (multi-level fallback)
  - Observabilité (metrics per pass)
  - Contrôle coûts (conditional execution)
  - Qualité adaptative
  
monitoring:
  - Cost per condensation
  - Latency p95
  - Reduction efficiency
  - Failure rate
```

#### Recherche / Compliance

```yaml
profile: research_compliance
recommendation: Lossless Provider
rationale:
  - Zero information loss garanti
  - Audit trail complet
  - Reproductibilité parfaite
  - Gratuit
  
note: Combiner avec archivage complet si réduction insuffisante
```

---

## 8. Patterns d'Utilisation

### 8.1 Pattern: Pipeline Séquentiel

**Concept**: Combiner plusieurs providers en séquence.

```typescript
async function pipelineCondensation(
  context: ConversationContext,
  targetTokens: number
): Promise<CondensationResult> {
  let current = context
  const operations: string[] = []
  let totalCost = 0
  
  // Stage 1: Lossless (gratuit, sans perte)
  const lossless = new LosslessCondensationProvider()
  const stage1 = await lossless.condense(current, { targetTokens })
  current = { ...current, messages: stage1.messages, tokenCount: stage1.stats.finalTokens }
  operations.push(...stage1.stats.operationsPerformed)
  
  // Check if done
  if (current.tokenCount <= targetTokens) {
    return { ...stage1, stats: { ...stage1.stats, operationsPerformed: operations } }
  }
  
  // Stage 2: Truncation (rapide, perte acceptable)
  const truncation = new TruncationCondensationProvider()
  const stage2 = await truncation.condense(current, { targetTokens })
  current = { ...current, messages: stage2.messages, tokenCount: stage2.stats.finalTokens }
  operations.push(...stage2.stats.operationsPerformed)
  
  // Check if done
  if (current.tokenCount <= targetTokens) {
    return { ...stage2, stats: { ...stage2.stats, operationsPerformed: operations, cost: totalCost } }
  }
  
  // Stage 3: Native LLM (coûteux, qualité)
  const native = new NativeCondensationProvider()
  const stage3 = await native.condense(current, { targetTokens })
  totalCost += stage3.stats.cost
  operations.push(...stage3.stats.operationsPerformed)
  
  return {
    ...stage3,
    stats: {
      ...stage3.stats,
      operationsPerformed: operations,
      cost: totalCost
    }
  }
}

// Avantages:
// - Réduction progressive (gratuit d'abord)
// - Coût optimisé (LLM sur contexte déjà réduit)
// - Fallback naturel (si stage échoue, continue)
```

### 8.2 Pattern: Adaptive Threshold

**Concept**: Ajuster dynamiquement la stratégie selon le contexte.

```typescript
class AdaptiveCondensationStrategy {
  async condense(
    context: ConversationContext,
    targetTokens: number
  ): Promise<CondensationResult> {
    const ratio = context.tokenCount / targetTokens
    
    // Choisir provider selon ratio
    if (ratio < 1.2) {
      // Proche du target → lossless suffit
      return new LosslessCondensationProvider().condense(context, { targetTokens })
    }
    
    if (ratio < 2.0) {
      // Modéré → truncation
      return new TruncationCondensationProvider().condense(context, { targetTokens })
    }
    
    if (ratio < 3.0) {
      // Important → native
      return new NativeCondensationProvider().condense(context, { targetTokens })
    }
    
    // Très important → smart aggressive
    const smart = new SmartCondensationProvider()
    return smart.condense(context, {
      targetTokens,
      config: aggressivePreset
    })
  }
}
```

### 8.3 Pattern: Cost-Aware Selection

**Concept**: Sélection basée sur le budget disponible.

```typescript
class CostAwareCondensation {
  private remainingBudget: number
  
  async condenseWithBudget(
    context: ConversationContext,
    targetTokens: number,
    maxCost: number
  ): Promise<CondensationResult> {
    // Estimer coûts
    const nativeCost = await new NativeCondensationProvider()
      .estimateCost(context)
    const smartCost = await new SmartCondensationProvider()
      .estimateCost(context, balancedPreset)
    
    // Sélection selon budget
    if (maxCost >= nativeCost) {
      // Budget OK pour native
      return new NativeCondensationProvider().condense(context, { targetTokens })
    }
    
    if (maxCost >= smartCost) {
      // Budget OK pour smart balanced
      return new SmartCondensationProvider().condense(context, {
        targetTokens,
        config: balancedPreset
      })
    }
    
    // Budget insuffisant → gratuit
    console.warn(`Budget ${maxCost} insufficient, using free providers`)
    
    // Pipeline lossless → truncation
    return pipelineCondensation(context, targetTokens)
  }
}
```

### 8.4 Pattern: Quality-First with Fallback

**Concept**: Prioriser la qualité, fallback sur coût.

```typescript
class QualityFirstCondensation {
  async condense(
    context: ConversationContext,
    targetTokens: number
  ): Promise<CondensationResult> {
    try {
      // Essayer Smart conservative (meilleure qualité)
      const smart = new SmartCondensationProvider()
      const result = await smart.condense(context, {
        targetTokens,
        config: conservativePreset
      })
      
      // Vérifier si target atteint
      if (result.stats.finalTokens <= targetTokens) {
        return result
      }
      
      console.warn('Smart provider insufficient, trying native')
      
      // Fallback Native
      return new NativeCondensationProvider().condense(
        { ...context, messages: result.messages, tokenCount: result.stats.finalTokens },
        { targetTokens }
      )
      
    } catch (error) {
      console.error('Quality providers failed, emergency truncation', error)
      
      // Emergency fallback
      return new TruncationCondensationProvider().condense(context, {
        targetTokens,
        config: { truncationMode: 'suppress' }  // Aggressive
      })
    }
  }
}
```

### 8.5 Pattern: Per-User Configuration

**Concept**: Configuration personnalisée par utilisateur.

```typescript
interface UserCondensationPreferences {
  userId: string
  preferredProvider: string
  maxCostPerCondensation: number
  qualityThreshold: number
  customConfig?: any
}

class UserAwareCondensation {
  private preferences: Map<string, UserCondensationPreferences>
  
  async condenseForUser(
    userId: string,
    context: ConversationContext,
    targetTokens: number
  ): Promise<CondensationResult> {
    const prefs = this.preferences.get(userId) || this.getDefaultPreferences()
    
    // Provider selon préférence
    const provider = this.getProvider(prefs.preferredProvider)
    
    // Config selon préférence
    const config = prefs.customConfig || this.getDefaultConfig(prefs)
    
    // Vérifier budget
    const estimatedCost = await provider.estimateCost(context, config)
    if (estimatedCost > prefs.maxCostPerCondensation) {
      console.warn(`Cost ${estimatedCost} exceeds user budget ${prefs.maxCostPerCondensation}`)
      // Downgrade vers provider moins cher
      return this.condenseWithBudget(context, targetTokens, prefs.maxCostPerCondensation)
    }
    
    return provider.condense(context, { targetTokens, config })
  }
  
  private getDefaultConfig(prefs: UserCondensationPreferences): any {
    // Config basée sur qualityThreshold
    if (prefs.qualityThreshold > 0.8) {
      return conservativePreset
    } else if (prefs.qualityThreshold > 0.5) {
      return balancedPreset
    } else {
      return aggressivePreset
    }
  }
}
```

### 8.6 Pattern: A/B Testing

**Concept**: Comparer plusieurs stratégies en production.

```typescript
class ABTestingCondensation {
  async condenseWithTracking(
    context: ConversationContext,
    targetTokens: number,
    userId: string
  ): Promise<CondensationResult> {
    // Déterminer variant (A ou B)
    const variant = this.getVariantForUser(userId)
    
    let result: CondensationResult
    
    if (variant === 'A') {
      // Variant A: Native
      result = await new NativeCondensationProvider().condense(context, { targetTokens })
    } else {
      // Variant B: Smart balanced
      result = await new SmartCondensationProvider().condense(context, {
        targetTokens,
        config: balancedPreset
      })
    }
    
    // Tracker métriques
    await this.trackMetrics({
      userId,
      variant,
      originalTokens: context.tokenCount,
      finalTokens: result.stats.finalTokens,
      cost: result.stats.cost,
      reductionPercent: result.stats.reductionPercent
    })
    
    return result
  }
  
  private getVariantForUser(userId: string): 'A' | 'B' {
    // Consistent hashing pour assignment stable
    const hash = this.hashUserId(userId)
    return (hash % 2) === 0 ? 'A' : 'B'
  }
}
```

### 8.7 Pattern: Progressive Enhancement

**Concept**: Améliorer progressivement la qualité si budget disponible.

```typescript
class ProgressiveEnhancementCondensation {
  async condense(
    context: ConversationContext,
    targetTokens: number,
    availableBudget: number
  ): Promise<CondensationResult> {
    let result: CondensationResult
    let spentBudget = 0
    
    // Level 1: Gratuit (lossless + truncation)
    result = await this.freeTierCondensation(context, targetTokens)
    
    if (result.stats.finalTokens <= targetTokens) {
      return result
    }
    
    // Level 2: Low-cost LLM si budget disponible
    if (availableBudget > 0.01) {
      const enhanced = await this.enhanceWithCheapLLM(
        { ...context, messages: result.messages },
        targetTokens
      )
      spentBudget = enhanced.stats.cost
      result = enhanced
      
      if (result.stats.finalTokens <= targetTokens) {
        return result
      }
    }
    
    // Level 3: Premium LLM si encore budget
    if (availableBudget - spentBudget > 0.05) {
      const premium = await this.enhanceWithPremiumLLM(
        { ...context, messages: result.messages },
        targetTokens
      )
      result = premium
    }
    
    return result
  }
  
  private async freeTierCondensation(
    context: ConversationContext,
    targetTokens: number
  ): Promise<CondensationResult> {
    return pipelineCondensation(context, targetTokens)
  }
  
  private async enhanceWithCheapLLM(
    context: ConversationContext,
    targetTokens: number
  ): Promise<CondensationResult> {
    const smart = new SmartCondensationProvider()
    return smart.condense(context, {
      targetTokens,
      config: {
        passes: [{
          // ... cheap LLM config
        }]
      }
    })
  }
  
  private async enhanceWithPremiumLLM(
    context: ConversationContext,
    targetTokens: number
  ): Promise<CondensationResult> {
    return new NativeCondensationProvider().condense(context, { targetTokens })
  }
}
```

---

## Conclusion

### Points Clés

1. **4 Providers Complémentaires**:
   - Native: Default, simple, éprouvé
   - Lossless: Zero-loss, gratuit, réduction modeste
   - Truncation: Ultra-rapide, gratuit, perte contrôlée
   - Smart: Ultra-configurable, pass-based, adaptatif

2. **Architecture Pass-Based**:
   - Modularité maximale
   - Configuration séquentielle
   - Conditions d'exécution flexibles
   - Opérations fines par type de contenu

3. **Profils API**:
   - Optimisation coût via handlers dédiés
   - Seuils personnalisés par profil
   - Prompts personnalisables
   - Économie ~90%+ possible

4. **Patterns d'Utilisation**:
   - Pipeline séquentiel
   - Adaptive threshold
   - Cost-aware selection
   - Quality-first with fallback
   - Per-user configuration

### Recommandations d'Implémentation

1. **Phase 1**: Native Provider (wrapper existant)
2. **Phase 2**: Lossless + Truncation (quick wins)
3. **Phase 3**: Smart Provider core (pass architecture)
4. **Phase 4**: UI + Presets (user experience)
5. **Phase 5**: Monitoring + Optimization (production)

### Métriques de Succès

- **Adoption**: >60% utilisateurs actifs
- **Performance**: Latence médiane <2s
- **Coût**: Réduction moyenne >80% (avec profils)
- **Qualité**: Satisfaction >85%
- **Flexibilité**: Support 100+ configurations custom

---

**Version**: 2.0 - Consolidated  
**Statut**: Production Design - Référence Complète  
**Lignes**: ~3000  
**Dernière Mise à Jour**: 2025-10-02