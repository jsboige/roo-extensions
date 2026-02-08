
# Implementation Roadmap v2.0 - Context Condensation System

**Version**: 2.0 - Consolidated  
**Date**: 2025-10-02  
**Status**: Ready for Implementation  
**Estimated Duration**: 8-10 weeks (440 hours)

## Executive Summary

Cette roadmap détaille l'implémentation complète du système de condensation multi-provider avec:

- **4 Providers**: Native, Lossless, Truncation, Smart (pass-based)
- **Profils API**: Configuration avancée avec handlers dédiés pour optimisation des coûts
- **Seuils Dynamiques**: Configuration par profil avec héritage
- **Architecture Pass-Based**: Système modulaire ultra-configurable pour Smart Provider
- **Timeline Réaliste**: 8-10 semaines avec livrables incrémentaux

**Économies Attendues**: Jusqu'à 95% de réduction des coûts de condensation via profils optimisés.

---

## 1. Vue d'Ensemble de l'Architecture Finale

### 1.1 Les 4 Providers

```
┌─────────────────────────────────────────────────────────┐
│              CondensationProviderManager                 │
│  - Orchestration des providers                          │
│  - Gestion des profils API                              │
│  - Détermination des seuils dynamiques                  │
│  - Stratégies de fallback                               │
└────────────────┬────────────────────────────────────────┘
                 │
    ┌────────────┼────────────┬─────────────┐
    │            │            │             │
┌───▼───┐  ┌────▼────┐  ┌────▼────┐  ┌────▼──────┐
│Native │  │Lossless │  │Trunca-  │  │  Smart    │
│       │  │         │  │tion     │  │(Pass-Based)│
│Batch  │  │Zero-loss│  │Fast     │  │Multi-pass │
│LLM    │  │Free     │  │Free     │  │Configurable│
└───────┘  └─────────┘  └─────────┘  └───────────┘
```

**Native Provider**:
- Wrapper du système actuel
- Batch LLM summarization
- Support profils API
- Backward compatible

**Lossless Provider**:
- Déduplication file reads
- Consolidation tool results
- Suppression états obsolètes
- 20-40% reduction, gratuit

**Truncation Provider**:
- Troncature mécanique rapide
- Règles configurables
- 80-95% reduction, gratuit
- <100ms execution

**Smart Provider**:
- Architecture pass-based modulaire
- 3 niveaux de contenu (text, params, results)
- 4 opérations (keep, suppress, truncate, summarize)
- Passes configurables avec conditions
- Lossless prelude optionnel

### 1.2 Profils API et Seuils Dynamiques

**Architecture des Profils**:

```typescript
interface ApiProfileConfig {
  profileId: string
  provider: 'anthropic' | 'openai' | ...
  model: string
  inputPrice: number      // per 1M tokens
  outputPrice: number
  cacheWritesPrice?: number
  cacheReadsPrice?: number
  contextWindow: number
}

interface CondensationConfig {
  autoCondenseContext: boolean
  autoCondenseContextPercent: number  // Seuil global
  condensingApiConfigId?: string      // Profil pour condensation
  customCondensingPrompt?: string
  profileThresholds: Record<string, number>  // Par profil
}
```

**Seuils Dynamiques**:
- Seuil global (ex: 75%)
- Seuils par profil (ex: Claude=75%, GPT-mini=85%)
- Héritage explicite avec -1
- Validation 5-100%

**Exemple de Configuration**:

```typescript
{
  autoCondenseContextPercent: 80,  // Global
  condensingApiConfigId: 'gpt-4o-mini',  // Économique
  profileThresholds: {
    'claude-sonnet-4': 75,   // Plus agressif
    'gpt-4o': 85,            // Plus tolérant
    'gpt-4o-mini': -1,       // Hérite du global (80%)
  }
}
```

### 1.3 Architecture Pass-Based (Smart Provider)

**Modèle de Contenu à 3 Niveaux**:

```typescript
interface DecomposedMessage {
  messageText: string | null      // User/assistant dialogue
  toolParameters: any[] | null    // Tool call inputs
  toolResults: any[] | null       // Tool execution outputs
}
```

**4 Opérations**:
- `KEEP`: Préserver intact (0% reduction)
- `SUPPRESS`: Supprimer complètement (100% reduction)
- `TRUNCATE`: Réduction mécanique (80-95% reduction)
- `SUMMARIZE`: Réduction LLM (40-90% reduction, coûteux)

**Structure d'une Passe**:

```typescript
interface PassConfig {
  id: string
  name: string
  selection: SelectionStrategy     // Quels messages traiter
  mode: 'batch' | 'individual'     // Comment les traiter
  batchConfig?: BatchModeConfig
  individualConfig?: IndividualModeConfig
  execution: ExecutionCondition    // Quand exécuter
}
```

**Exemple de Configuration Multi-Pass**:

```typescript
{
  losslessPrelude: { enabled: true },
  passes: [
    // Pass 1: Truncate old tool results (always)
    {
      id: 'truncate-old',
      selection: { type: 'preserve_recent', keepRecentCount: 5 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'keep' },
          toolResults: { operation: 'truncate', params: { maxLines: 5 } }
        }
      },
      execution: { type: 'always' }
    },
    // Pass 2: Suppress very old (conditional)
    {
      id: 'suppress-ancient',
      selection: { type: 'preserve_recent', keepRecentCount: 20 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'suppress' },
          toolResults: { operation: 'suppress' }
        }
      },
      execution: { type: 'conditional', condition: { tokenThreshold: 50000 } }
    }
  ]
}
```

---

## 2. Prérequis et Préparation

### 2.1 Infrastructure Technique

**Requis Avant Phase 1**:

1. **TypeScript Environment**:
   - TypeScript 5.x configuré
   - Vitest pour tests
   - ESLint et Prettier

2. **Code Existant**:
   - Comprendre [`summarizeConversation()`](../../src/core/condense/index.ts) actuel
   - Analyser [`Task.ts`](../../src/task.ts) integration
   - Comprendre API handlers system

3. **Documentation**:
   - Lire [002-requirements-specification-v2.md](002-requirements-specification-v2.md)
   - Lire [003-provider-architecture-v2.md](003-provider-architecture-v2.md)
   - Lire [008-refined-pass-architecture.md](008-refined-pass-architecture.md)

### 2.2 Refactoring Nécessaire

**Avant l'implémentation, identifier**:

1. **Token Counting**:
   - Fonction de comptage centralisée
   - Support multi-provider (Anthropic vs OpenAI)
   - Gestion du cache

2. **Cost Calculation**:
   - Formules par provider
   - Support tokens cachés
   - Tracking des coûts

3. **Message Structure**:
   - Normalisation des formats
   - Gestion des content blocks
   - Métadonnées préservées

### 2.3 Tests et Métriques

**Infrastructure de Test**:

```typescript
// Tests unitaires par fonction
describe('FileReadDeduplication', () => {
  it('should deduplicate identical file reads', async () => {
    // Given: 3 reads of same file
    // When: deduplication applied
    // Then: 2 replaced by references
  })
})

// Tests d'intégration par provider
describe('LosslessProvider', () => {
  it('should achieve 30-50% reduction without loss', async () => {
    // Given: conversation with duplicates
    // When: lossless condensation
    // Then: tokens reduced, info preserved
  })
})

// Tests de performance
describe('Performance', () => {
  it('should condense 100K tokens in <6s', async () => {
    // Benchmark critical path
  })
})
```

**Métriques à Suivre**:
- Token reduction %
- Execution time
- Cost per condensation
- User message preservation rate
- Information loss score

### 2.4 Infrastructure de Monitoring

**Telemetry Events**:

```typescript
interface CondensationTelemetryEvent {
  provider: string
  originalTokens: number
  finalTokens: number
  reductionPercent: number
  cost: number
  executionTime: number
  operations: string[]
  error?: string
}
```

**Logging**:
```typescript
// Structured logging for debugging
logger.info('Condensation started', {
  provider: 'smart',
  context: { tokens, messages: count }
})

logger.debug('Pass executed', {
  passId: 'truncate-old',
  reduction: '25%',
  time: '120ms'
})
```

---

## 3. Phase 1: Fondations (Semaine 1-2) - ~80h

### Objectif
Établir l'architecture provider avec profils API et seuils dynamiques.

### 3.1 Tâches Détaillées

#### 3.1.1 Interfaces et Types (2 jours / 16h)

**Fichier**: `src/core/condense/types.ts`

```typescript
// Provider Interface
export interface ICondensationProvider {
  readonly id: string
  readonly name: string
  readonly description: string
  readonly version: string
  
  getCapabilities(): ProviderCapabilities
  getConfigSchema(): ConfigSchema
  validateConfig(config: any): ValidationResult
  
  condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult>
  
  estimateReduction(context: ConversationContext): Promise<TokenEstimate>
  estimateCost(context: ConversationContext, config?: any): Promise<number>
}

// Context and Configuration
export interface ConversationContext {
  messages: ApiMessage[]
  systemPrompt: string
  taskId: string
  contextWindow: number
  maxTokens: number
  totalTokens: number
  apiHandler: ApiHandler
}

export interface CondensationConfig {
  apiHandler: ApiHandler
  condensingApiHandler?: ApiHandler  // Profile-specific
  systemPrompt: string
  customPrompt?: string
  prevContextTokens: number
  taskId: string
  isAutomatic: boolean
  profileId?: string
  targetReductionPercent?: number
  providerConfig?: Record<string, any>
}

// Profile Management
export interface ApiProfile {
  id: string
  name: string
  provider: string
  model: string
  inputPrice: number
  outputPrice: number
  cacheWritesPrice?: number
  cacheReadsPrice?: number
  contextWindow: number
  maxOutputTokens: number
  supportsPromptCache: boolean
}

// Result Types
export interface CondensationResult {
  messages: ApiMessage[]
  summary: string
  cost: number
  newContextTokens?: number
  prevContextTokens: number
  error?: string
  metrics?: CondensationMetrics
  profileUsed?: string
}

export interface CondensationMetrics {
  lossless?: LosslessMetrics
  lossy?: LossyMetrics
  totalTokensSaved: number
  reductionPercent: number
  phasesExecuted: string[]
  timeElapsed: number
}
```

**Tests**:
```typescript
describe('Type Definitions', () => {
  it('should have valid provider interface', () => {
    // Validate interface completeness
  })
  
  it('should have valid config types', () => {
    // Validate configuration structure
  })
})
```

**Checklist**:
- [ ] Tous les types définis
- [ ] Documentation JSDoc complète
- [ ] Validation TypeScript stricte
- [ ] Tests de type compilent

#### 3.1.2 CondensationProviderManager (3 jours / 24h)

**Fichier**: `src/core/condense/manager.ts`

```typescript
export class CondensationProviderManager {
  private providers: Map<string, ICondensationProvider>
  private apiProfiles: Map<string, ApiProfile>
  private globalThreshold: number = 75
  private profileThresholds: Map<string, number>
  
  constructor() {
    this.providers = new Map()
    this.apiProfiles = new Map()
    this.profileThresholds = new Map()
    this.registerDefaultProviders()
  }
  
  // Profile Management
  registerApiProfile(profile: ApiProfile): void
  setProfileThreshold(profileId: string, threshold: number): void
  getEffectiveThreshold(profileId?: string): number
  
  // Configuration
  getEffectiveConfig(
    context: ConversationContext,
    options: ConfigOptions
  ): CondensationConfig
  
  // Decision Logic
  shouldCondense(
    tokens: number,
    contextWindow: number,
    maxTokens: number,
    profileId?: string
  ): boolean
  
  // Orchestration
  async condenseIfNeeded(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult>
  
  // Provider Management
  registerProvider(provider: ICondensationProvider): void
  getProvider(id: string): ICondensationProvider | undefined
  setDefaultProvider(id: string): void
  
  // Fallback
  private truncationFallback(context: ConversationContext): CondensationResult
  private trackCondensation(result: CondensationResult, profileId?: string): void
}
```

**Implémentation Clé - Seuil Effectif**:

```typescript
getEffectiveThreshold(profileId?: string): number {
  if (!profileId) {
    return this.globalThreshold
  }
  
  const profileThreshold = this.profileThresholds.get(profileId)
  
  if (profileThreshold === undefined) {
    // Pas de personnalisation → global
    return this.globalThreshold
  }
  
  if (profileThreshold === -1) {
    // Héritage explicite → global
    return this.globalThreshold
  }
  
  if (profileThreshold >= MIN_CONDENSE_THRESHOLD && 
      profileThreshold <= MAX_CONDENSE_THRESHOLD) {
    // Valide → utiliser
    return profileThreshold
  }
  
  // Invalide → warning + global
  console.warn(
    `Invalid threshold ${profileThreshold} for profile ${profileId}, ` +
    `using global ${this.globalThreshold}%`
  )
  return this.globalThreshold
}
```

**Implémentation Clé - Décision de Condensation**:

```typescript
shouldCondense(
  tokens: number,
  contextWindow: number,
  maxTokens: number,
  profileId?: string
): boolean {
  const effectiveThreshold = this.getEffectiveThreshold(profileId)
  
  // Calculer tokens autorisés avec buffer de sécurité
  const reservedTokens = maxTokens || ANTHROPIC_DEFAULT_MAX_TOKENS
  const allowedTokens = contextWindow * (1 - TOKEN_BUFFER_PERCENTAGE) 
                       - reservedTokens
  
  // Calculer pourcentage du contexte
  const contextPercent = (100 * tokens) / contextWindow
  
  // Déclencher si:
  // 1. Pourcentage >= seuil effectif OU
  // 2. Tokens absolus > tokens autorisés
  return contextPercent >= effectiveThreshold || tokens > allowedTokens
}
```

**Tests**:

```typescript
describe('CondensationProviderManager', () => {
  describe('Profile Threshold Management', () => {
    it('should use global threshold when no profile threshold set', () => {
      const manager = new CondensationProviderManager()
      expect(manager.getEffectiveThreshold('unknown-profile')).toBe(75)
    })
    
    it('should use profile-specific threshold', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test-profile', 80)
      expect(manager.getEffectiveThreshold('test-profile')).toBe(80)
    })
    
    it('should inherit global with -1', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test-profile', -1)
      expect(manager.getEffectiveThreshold('test-profile')).toBe(75)
    })
    
    it('should validate threshold range', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test-profile', 150)  // Invalid
      expect(manager.getEffectiveThreshold('test-profile')).toBe(75)
    })
  })
  
  describe('Condensation Decision', () => {
    it('should condense when percentage exceeds threshold', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test', 70)
      
      // 75% > 70%
      expect(manager.shouldCondense(75000, 100000, 8000, 'test')).toBe(true)
    })
    
    it('should condense when absolute tokens exceed allowed', () => {
      const manager = new CondensationProviderManager()
      
      // 85K > (100K * 0.9 - 8K = 82K)
      expect(manager.shouldCondense(85000, 100000, 8000)).toBe(true)
    })
    
    it('should not condense below thresholds', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test', 80)
      
      // 70% < 80% and 70K < 82K
      expect(manager.shouldCondense(70000, 100000, 8000, 'test')).toBe(false)
    })
  })
  
  describe('Provider Orchestration', () => {
    it('should select correct provider', async () => {
      const manager = new CondensationProviderManager()
      const result = await manager.condenseIfNeeded(context, {
        providerId: 'native',
        isAutomatic: true
      })
      expect(result.error).toBeUndefined()
    })
    
    it('should fall back on provider failure', async () => {
      const manager = new CondensationProviderManager()
      // Test fallback mechanism
    })
  })
})
```

**Checklist**:
- [ ] Manager complet implémenté
- [ ] Profils API gérés
- [ ] Seuils dynamiques fonctionnels
- [ ] Décision de condensation correcte
- [ ] Fallback stratégies testées
- [ ] Tests unitaires passent (>90% coverage)

#### 3.1.3 Configuration Settings (2 jours / 16h)

**Fichier**: `package.json` (VSCode settings)

```json
{
  "roo-code.condensation.provider": {
    "type": "string",
    "enum": ["native", "lossless", "truncation", "smart"],
    "default": "native",
    "description": "Context condensation provider to use"
  },
  "roo-code.condensation.autoCondenseContext": {
    "type": "boolean",
    "default": true
  },
  "roo-code.condensation.autoCondenseContextPercent": {
    "type": "number",
    "default": 75,
    "minimum": 5,
    "maximum": 100,
    "description": "Global threshold for auto-condensation (%)"
  },
  "roo-code.condensation.condensingApiConfigId": {
    "type": "string",
    "description": "API configuration ID for condensation operations"
  },
  "roo-code.condensation.customCondensingPrompt": {
    "type": "string",
    "description": "Custom prompt for summarization"
  },
  "roo-code.condensation.profileThresholds": {
    "type": "object",
    "additionalProperties": {
      "type": "number"
    },
    "default": {},
    "description": "Per-profile condensation thresholds (-1 to inherit)"
  }
}
```

**Settings UI Component** (basic):

```typescript
// webview-ui/src/components/settings/CondensationSettings.tsx
export const CondensationSettings: React.FC = () => {
  const [provider, setProvider] = useState('native')
  const [globalThreshold, setGlobalThreshold] = useState(75)
  const [profileThresholds, setProfileThresholds] = useState<Record<string, number>>({})
  
  return (
    <div className="condensation-settings">
      <Section title="Context Condensation">
        <Select
          label="Provider"
          value={provider}
          options={[
            { value: 'native', label: 'Native (Current)' },
            { value: 'lossless', label: 'Lossless (Coming Soon)' },
            { value: 'truncation', label: 'Truncation (Coming Soon)' },
            { value: 'smart', label: 'Smart (Coming Soon)' }
          ]}
          onChange={setProvider}
        />
        
        <NumberInput
          label="Global Threshold (%)"
          value={globalThreshold}
          min={5}
          max={100}
          onChange={setGlobalThreshold}
          help="Trigger condensation when context reaches this percentage"
        />
        
        {/* Profile-specific thresholds - advanced section */}
      </Section>
    </div>
  )
}
```

**Checklist**:
- [ ] Settings schema défini
- [ ] Settings persistés correctement
- [ ] UI basique fonctionnelle
- [ ] Migration des settings existants
- [ ] Tests d'intégration settings

#### 3.1.4 Task.ts Integration (2 jours / 16h)

**Modifications dans** `src/task.ts`:

```typescript
import { CondensationProviderManager } from './core/condense/manager'

export class Task {
  private condensationManager: CondensationProviderManager
  
  constructor(...) {
    // ... existing initialization ...
    this.condensationManager = new CondensationProviderManager()
    this.initializeCondensationProfiles()
  }
  
  private initializeCondensationProfiles(): void {
    // Charger configuration des profils
    const settings = vscode.workspace.getConfiguration('roo-code.condensation')
    
    // Charger seuils par profil
    const profileThresholds = settings.get<Record<string, number>>(
      'profileThresholds',
      {}
    )
    
    Object.entries(profileThresholds).forEach(([profileId, threshold]) => {
      this.condensationManager.setProfileThreshold(profileId, threshold)
    })
  }
  
  private async handleContextCondensation(): Promise<void> {
    // Obtenir configuration actuelle
    const settings = vscode.workspace.getConfiguration('roo-code.condensation')
    const currentProfileId = this.api.getInfo().id
    const condensingApiConfigId = settings.get<string>('condensingApiConfigId')
    const customPrompt = settings.get<string>('customCondensingPrompt')
    
    // Préparer contexte
    const context: ConversationContext = {
      messages: this.apiConversationHistory,
      systemPrompt: await this.getSystemPrompt(),
      taskId: this.taskId,
      contextWindow: this.api.getInfo().contextWindow,
      maxTokens: this.api.getInfo().maxTokens,
      totalTokens: this.contextTokens || 0,
      apiHandler: this.api
    }
    
    try {
      // Condensation via manager
      const result = await this.condensationManager.condenseIfNeeded(
        context,
        {
          profileId: currentProfileId,
          condensingApiConfigId,
          customPrompt,
          isAutomatic: true,
          providerId: settings.get('provider', 'native')
        }
      )
      
      // Gérer résultat
      if (result.error) {
        await this.say('condense_context_error', result.error)
      } else if (result.summary) {
        this.apiConversationHistory = result.messages
        this.contextTokens = result.newContextTokens
        
        await this.say('condense_context', undefined, undefined, false,
          undefined, undefined, { isNonInteractive: true }, {
            summary: result.summary,
            cost: result.cost,
            newContextTokens: result.newContextTokens,
            prevContextTokens: result.prevContextTokens,
            metrics: result.metrics,
            profileUsed: result.profileUsed
          }
        )
      }
    } catch (error) {
      console.error('Condensation failed:', error)
      await this.say('condense_context_error', String(error))
    }
  }
}
```

**Tests d'Intégration**:

```typescript
describe('Task.ts Integration', () => {
  it('should condense via manager when threshold exceeded', async () => {
    const task = new Task(/* ... */)
    
    // Simulate context growth
    await task.handleContextCondensation()
    
    // Verify condensation occurred
    expect(task.apiConversationHistory.length).toBeLessThan(originalLength)
  })
  
  it('should use profile-specific threshold', async () => {
    // Configure profile threshold
    const settings = vscode.workspace.getConfiguration('roo-code.condensation')
    await settings.update('profileThresholds', {
      'claude-sonnet-4': 70
    })
    
    const task = new Task(/* with claude-sonnet-4 */)
    
    // Verify threshold applied
  })
  
  it('should fall back gracefully on failure', async () => {
    // Test fallback mechanism
  })
})
```

**Checklist**:
- [ ] Task.ts intégration complète
- [ ] Backward compatibility vérifiée
- [ ] Tests existants passent
- [ ] Nouveaux tests d'intégration passent
- [ ] Telemetry events émis

#### 3.1.5 Documentation (1 jour / 8h)

**Créer**:

1. **Architecture Overview** (`docs/condensation-architecture.md`)
2. **Provider Guide** (`docs/provider-guide.md`)
3. **Configuration Guide** (`docs/configuration-guide.md`)
4. **API Documentation** (JSDoc complet)

**Checklist**:
- [ ] Documentation architecture complète
- [ ] Guide développeur écrit
- [ ] Exemples de code fournis
- [ ] Diagrammes à jour

### 3.2 Livrables Phase 1

**Code**:
- ✅ `src/core/condense/types.ts` - Types et interfaces
- ✅ `src/core/condense/manager.ts` - Manager avec profils
- ✅ `src/task.ts` - Intégration mise à jour
- ✅ Settings schema et UI basique

**Tests**:
- ✅ >90% coverage sur manager
- ✅ Tests d'intégration Task.ts
- ✅ Tous les tests existants passent

**Documentation**:
- ✅ Architecture documentée
- ✅ API documentée
- ✅ Guide de configuration

### 3.3 Critères de Succès Phase 1

- [ ] Tous les tests passent (100%)
- [ ] Aucune régression fonctionnelle
- [ ] Architecture validée en code review
- [ ] Documentation approuvée
- [ ] Profils API fonctionnels
- [ ] Seuils dynamiques testés
- [ ] Performance équivalente à l'existant

---

## 4. Phase 2: Native Provider (Semaine 2-3) - ~40h

### Objectif
Encapsuler le système actuel dans un provider avec support complet des profils API.

### 4.1 Tâches Détaillées

#### 4.1.1 NativeCondensationProvider (3 jours / 24h)

**Fichier**: `src/core/condense/providers/native.ts`

```typescript
export class NativeCondensationProvider implements ICondensationProvider {
  readonly id = 'native'
  readonly name = 'Native LLM Condensation'
  readonly description = 'Current batch summarization with API profile support'
  readonly version = '2.0.0'
  
  private conversationApiHandler: ApiHandler
  
  constructor(conversationHandler: ApiHandler) {
    this.conversationApiHandler = conversationHandler
  }
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: false,
      supportsBatchMode: true,
      supportsIndividualMode: false,
      supportsMultiPass: false,
      supportsLLMSummarization: true,
      estimatedSpeed: 'medium'
    }
  }
  
  async estimateCost(
    context: ConversationContext,
    config?: CondensationConfig
  ): Promise<number> {
    // Sélectionner handler (profil-aware)
    const apiHandler = this.selectApiHandler(config)
    const modelInfo = apiHandler.getInfo()
    
    // Estimer tokens input
    const messagesToSummarize = this.getMessagesSinceLastSummary(
      context.messages.slice(0, -N_MESSAGES_TO_KEEP)
    )
    
    const inputTokens = await this.countTokens(messagesToSummarize, apiHandler)
    
    // Estimer tokens output (typiquement 5-10% de l'input)
    const outputTokens = Math.floor(inputTokens * 0.07)
    
    // Calculer coût selon provider
    const isAnthropic = modelInfo.supportsPromptCache ?? false
    return this.calculateCost(
      inputTokens,
      outputTokens,
      0, 0,  // No cache for estimation
      modelInfo,
      isAnthropic
    )
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const startTime = Date.now()
    const startTokens = context.totalTokens
    
    // Sélectionner handler (profil-aware)
    const apiHandler = this.selectApiHandler(options.config)
    
    // Valider handler
    if (!this.validateHandler(apiHandler)) {
      return {
        messages: context.messages,
        summary: '',
        cost: 0,
        prevContextTokens: startTokens,
        error: 'No valid API handler available'
      }
    }
    
    // Sélectionner prompt (custom ou défaut)
    const prompt = this.selectPrompt(options.config)
    
    // Préparer messages pour summarization
    const keepCount = N_MESSAGES_TO_KEEP
    const messagesToSummarize = this.getMessagesSinceLastSummary(
      context.messages.slice(0, -keepCount)
    )
    
    if (messagesToSummarize.length <= 1) {
      return {
        messages: context.messages,
        summary: '',
        cost: 0,
        prevContextTokens: startTokens,
        error: 'Not enough messages to condense'
      }
    }
    
    // Vérifier si résumé récent existe
    const keepMessages = context.messages.slice(-keepCount)
    const recentSummaryExists = keepMessages.some(m => m.isSummary)
    
    if (recentSummaryExists) {
      return {
        messages: context.messages,
        summary: '',
        cost: 0,
        prevContextTokens: startTokens,
        error: 'Recently condensed, skipping'
      }
    }
    
    // Construire request messages
    const requestMessages = this.buildRequestMessages(
      messagesToSummarize,
      context.systemPrompt
    )
    
    // Stream LLM response
    const stream = apiHandler.createMessage(prompt, requestMessages)
    
    let summary = ''
    let cost = 0
    let outputTokens = 0
    
    for await (const chunk of stream) {
      if (chunk.type === 'text') {
        summary += chunk.text
      } else if (chunk.type === 'usage') {
        const modelInfo = apiHandler.getInfo()
        const isAnthropic = modelInfo.supportsPromptCache ?? false
        
        cost = this.calculateCost(
          chunk.inputTokens ?? 0,
          chunk.outputTokens ?? 0,
          chunk.cacheCreationInputTokens,
          chunk.cacheReadInputTokens,
          modelInfo,
          isAnthropic
        )
        outputTokens = chunk.outputTokens ?? 0
      }
    }
    
    // Construire résultat
    const firstMessage = context.messages[0]
    const summaryMessage: ApiMessage = {
      role: 'user',
      content: [{ type: 'text', text: summary }],
      isSummary: true
    }
    
    const newMessages = [firstMessage, summaryMessage, ...keepMessages]
    
    // Compter nouveaux tokens
    const contextBlocks = newMessages.flatMap(msg =>
      Array.isArray(msg.content) ? msg.content : [{ type: 'text', text: msg.content }]
    )
    const newContextTokens = outputTokens + await apiHandler.countTokens(contextBlocks)
    
    // Valider réduction
    if (newContextTokens >= startTokens) {
      return {
        messages: context.messages,
        summary: '',
        cost,
        prevContextTokens: startTokens,
        error: `Context grew during condensation: ${startTokens} → ${newContextTokens}`
      }
    }
    
    const timeElapsed = Date.now() - startTime
    
    return {
      messages: newMessages,
      summary,
      cost,
      newContextTokens,
      prevContextTokens: startTokens,
      profileUsed: options.config?.profileId,
      metrics: {
        totalTokensSaved: startTokens - newContextTokens,
        reductionPercent: ((startTokens - newContextTokens) / startTokens) * 100,
        phasesExecuted: ['batch_llm_summarization'],
        timeElapsed
      }
    }
  }
  
  // Helper Methods
  
  private selectApiHandler(config?: CondensationConfig): ApiHandler {
    // Priority: condensing handler > conversation handler
    if (config?.condensingApiHandler && 
        this.validateHandler(config.condensingApiHandler)) {
      return config.condensingApiHandler
    }
    
    if (this.validateHandler(this.conversationApiHandler)) {
      return this.conversationApiHandler
    }
    
    throw new Error('No valid API handler available')
  }
  
  private validateHandler(handler: any): boolean {
    return handler && typeof handler.createMessage === 'function'
  }
  
  private selectPrompt(config?: CondensationConfig): string {
    const DEFAULT_PROMPT = `
You are a conversation summarizer. Create a concise summary of the provided 
conversation that preserves all critical information: decisions made, problems 
solved, and pending issues. Focus on technical details and context.
    `.trim()
    
    return config?.customPrompt?.trim() || DEFAULT_PROMPT
  }
  
  private getMessagesSinceLastSummary(messages: ApiMessage[]): ApiMessage[] {
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isSummary) {
        return messages.slice(i + 1)
      }
    }
    return messages
  }
  
  private buildRequestMessages(
    messages: ApiMessage[],
    systemPrompt: string
  ): ApiMessage[] {
    let context = `System Context:\n${systemPrompt}\n\nConversation:\n\n`
    
    for (const msg of messages) {
      const content = Array.isArray(msg.content)
        ? msg.content.map(c => c.type === 'text' ? c.text : '').join('\n')
        : msg.content
      context += `${msg.role}: ${content}\n\n`
    }
    
    return [{
      role: 'user',
      content: [{ type: 'text', text: context }]
    }]
  }
  
  private calculateCost(
    inputTokens: number,
    outputTokens: number,
    cacheCreationTokens: number | undefined,
    cacheReadTokens: number | undefined,
    modelInfo: ModelInfo,
    isAnthropic: boolean
  ): number {
    if (isAnthropic) {
      return calculateApiCostAnthropic(
        modelInfo,
        inputTokens,
        outputTokens,
        cacheCreationTokens,
        cacheReadTokens
      )
    } else {
      return calculateApiCostOpenAI(
        modelInfo,
        inputTokens,
        outputTokens,
        cacheCreationTokens,
        cacheReadTokens
      )
    }
  }
  
  private async countTokens(
    messages: ApiMessage[],
    apiHandler: ApiHandler
  ): Promise<number> {
    const blocks = messages.flatMap(msg =>
      Array.isArray(msg.content) ? msg.content : [{ type: 'text', text: msg.content }]
    )
    return apiHandler.countTokens(blocks)
  }
}

const N_MESSAGES_TO_KEEP = 3
```

**Tests Unitaires**:

```typescript
describe('NativeCondensationProvider', () => {
  let provider: NativeCondensationProvider
  let mockHandler: ApiHandler
  
  beforeEach(() => {
    mockHandler = createMockApiHandler()
    provider = new NativeCondensationProvider(mockHandler)
  })
  
  describe('Handler Selection', () => {
    it('should use condensing handler when available', async () => {
      const condensingHandler = createMockApiHandler('gpt-4o-mini')
      const config = {
        condensingApiHandler: condensingHandler,
        // ...
      }
      
      const result = await provider.condense(context, { config })
      
      // Verify condensing handler was used
    })
    
    it('should fall back to conversation handler', async () => {
      const config = {
        condensingApiHandler: null,
        // ...
      }
      
      const result = await provider.condense(context, { config })
      
      // Verify conversation handler was used
    })
  })
  
  describe('Cost Estimation', () => {
    it('should estimate cost with Anthropic handler', async () => {
      const anthropicHandler = createMockApiHandler('claude-sonnet-4')
      provider = new NativeCondensationProvider(anthropicHandler)
      
      const cost = await provider.estimateCost(context, config)
      
      expect(cost).toBeGreaterThan(0)
      expect(cost).toBeLessThan(0.1)  // Reasonable range
    })
    
    it('should estimate cost with OpenAI handler', async () => {
      const openaiHandler = createMockApiHandler('gpt-4o-mini')
      const config = { condensingApiHandler: openaiHandler }
      
      const cost = await provider.estimateCost(context, config)
      
      expect(cost).toBeGreaterThan(0)
      expect(cost).toBeLessThan(0.01)  // Cheaper model
    })
  })
  
  describe('Condensation', () => {
    it('should condense conversation successfully', async () => {
      const result = await provider.condense(context, options)
      
      expect(result.error).toBeUndefined()
      expect(result.newContextTokens).toBeLessThan(result.prevContextTokens)
      expect(result.summary).toBeTruthy()
      expect(result.cost).toBeGreaterThan(0)
    })
    
    it('should preserve first and last N messages', async () => {
      const result = await provider.condense(context, options)
      
      expect(result.messages[0]).toEqual(context.messages[0])
      expect(result.messages.slice(-3)).toEqual(context.messages.slice(-3))
    })
    
    it('should handle insufficient messages', async () => {
      const shortContext = { ...context, messages: [msg1, msg2] }
      const result = await provider.condense(shortContext, options)
      
      expect(result.error).toContain('Not enough messages')
    })
    
    it('should reject condensation that increases tokens', async () => {
      // Mock LLM to return very long summary
      mockHandler.createMessage = async function* () {
        yield { type: 'text', text: 'Very long summary...'.repeat(1000) }
      }
      
      const result = await provider.condense(context, options)
      
      expect(result.error).toContain('Context grew')
    })
  })
  
  describe('Backward Compatibility', () => {
    it('should match existing summarizeConversation behavior', async () => {
      // Compare with existing implementation
      const nativeResult = await provider.condense(context, options)
      const legacyResult = await summarizeConversation(/* ... */)
      
      expect(nativeResult.messages.length).toEqual(legacyResult.length)
      // More assertions...
    })
  })
})
```

**Checklist**:
- [ ] Provider complet implémenté
- [ ] Handler selection avec profils
- [ ] Cost estimation dynamique
- [ ] Backward compatibility 100%
- [ ] Tests unitaires >90% coverage
- [ ] Tests de compatibilité passent

#### 4.1.2 Enregistrement et Tests d'Intégration (1 jour / 8h)

**Dans Manager**:

```typescript
private registerDefaultProviders(): void {
  this.registerProvider(new NativeCondensationProvider(this.conversationApiHandler))
}
```

**Tests d'Intégration**:

```typescript
describe('Manager + Native Provider Integration', () => {
  it('should condense via native provider', async () => {
    const manager = new CondensationProviderManager()
    
    const result = await manager.condenseIfNeeded(context, {
      providerId: 'native',
      isAutomatic: true
    })
    
    expect(result.error).toBeUndefined()
    expect(result.newContextTokens).toBeLessThan(context.totalTokens)
  })
  
  it('should use profile-specific handler', async () => {
    const manager = new CondensationProviderManager()
    
    const result = await manager.condenseIfNeeded(context, {
      providerId: 'native',
      condensingApiConfigId: 'gpt-4o-mini',
      isAutomatic: true
    })
    
    expect(result.profileUsed).toBe('gpt-4o-mini')
    expect(result.cost).toBeLessThan(0.01)  // Cheap model
  })
})
```

**Checklist**:
- [ ] Provider enregistré comme défaut
- [ ] Tests d'intégration passent
- [ ] Telemetry events corrects

#### 4.1.3 Performance Benchmarks (1 jour / 8h)

**Créer Suite de Benchmarks**:

```typescript
// src/core/condense/__benchmarks__/native-provider.bench.ts

describe('Native Provider Benchmarks', () => {
  bench('condense 50 messages (~25K tokens)', async () => {
    const provider = new NativeCondensationProvider(mockHandler)
    await provider.condense(context50, options)
  })
  
  bench('condense 100 messages (~50K tokens)', async () => {
    const provider = new NativeCondensationProvider(mockHandler)
    await provider.condense(context100, options)
  })
  
  bench('condense 200 messages (~100K tokens)', async () => {
    const provider = new NativeCondensationProvider(mockHandler)
    await provider.condense(context200, options)
  })
})
```

**Critères de Performance**:
- 50 messages: <3s
- 100 messages: <5s
- 200 messages: <8s

**Checklist**:
- [ ] Benchmarks créés
- [ ] Performance validée
- [ ] Baseline établie pour comparaison

### 4.2 Livrables Phase 2

**Code**:
- ✅ `src/core/condense/providers/native.ts` - Provider complet
- ✅ Support profils API
- ✅ Calcul de coût dynamique
- ✅ Enregistrement dans manager

**Tests**:
- ✅ >90% coverage provider
- ✅ Tests d'intégration
- ✅ Tests de backward compatibility
- ✅ Benchmarks de performance

**Documentation**:
- ✅ Native provider documenté
- ✅ Profils API expliqués

### 4.3 Critères de Succès Phase 2

- [ ] 100% backward compatible
- [ ] Tous les tests existants passent
- [ ] Performance équivalente ou meilleure
- [ ] Profils API fonctionnels
- [ ] Coût calculé correctement
- [ ] Provider par défaut stable

---

## 5. Phase 3: Lossless Provider (Semaine 3-4) - ~60h

### Objectif
Implémenter optimisations sans perte d'information.

### 5.1 Tâches Détaillées

#### 5.1.1 File Read Deduplication (2 jours / 16h)

**Fichier**: `src/core/condense/providers/lossless/deduplication.ts`

```typescript
interface FileReadInfo {
  path: string
  content: string
  hash: string
  messageIndex: number
  tokens: number
}

export class FileReadDeduplicator {
  private fileReads = new Map<string, FileReadInfo>()
  
  async deduplicateFileReads(
    messages: ApiMessage[]
  ): Promise<{ messages: ApiMessage[], tokensSaved: number }> {
    // Pass 1: Identifier toutes les lectures de fichiers
    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i]
      if (this.isFileReadResult(msg)) {
        const fileInfo = await this.extractFileInfo(msg, i)
        
        // Garder seulement la plus récente
        const existing = this.fileReads.get(fileInfo.path)
        if (!existing || existing.messageIndex < i) {
          this.fileReads.set(fileInfo.path, fileInfo)
        }
      }
    }
    
    // Pass 2: Remplacer anciennes lectures par références
    let tokensSaved = 0
    const processed = messages.map((msg, i) => {
      if (this.isFileReadResult(msg)) {
        const path = this.extractFilePath(msg)
        const latest = this.fileReads.get(path)!
        
        if (i < latest.messageIndex) {
          // Ancienne lecture → créer référence
          tokensSaved += latest.tokens - this.estimateReferenceTokens()
          return this.createFileReference(path, latest.messageIndex)
        }
      }
      return msg
    })
    
    return { messages: processed, tokensSaved }
  }
  
  private isFileReadResult(message: ApiMessage): boolean {
    if (typeof message.content === 'string') return false
    
    return message.content.some(block =>
      block.type === 'tool_result' &&
      this.isFileReadTool(block)
    )
  }
  
  private isFileReadTool(block: any): boolean {
    // Check if tool_use_id corresponds to read_file
    // This requires tracking tool calls
    return true  // Simplified
  }
  
  private async extractFileInfo(
    message: ApiMessage,
    index: number
  ): Promise<FileReadInfo> {
    const path = this.extractFilePath(message)
    const content = this.extractContent(message)
    const hash = this.hashContent(content)
    const tokens = await this.countTokens(content)
    
    return { path, content, hash, messageIndex: index, tokens }
  }
  
  private extractFilePath(message: ApiMessage): string {
    // Extract from tool_result content
    // Format: "Reading file: /path/to/file.ts"
    const content = this.extractContent(message)
    const match = content.match(/Reading file: (.+)/)
    return match ? match[1] : 'unknown'
  }
  
  private extractContent(message: ApiMessage): string {
    if (typeof message.content === 'string') return message.content
    
    const toolResult = message.content.find(b => b.type === 'tool_result')
    return toolResult ? String(toolResult.content) : ''
  }
  
  private hashContent(content: string): string {
    return crypto.createHash('sha256')
      .update(content)
      .digest('hex')
      .substring(0, 16)
  }
  
  private createFileReference(
    path: string,
    targetIndex: number
  ): ApiMessage {
    return {
      role: 'user',
      content: [{
        type: 'tool_result',
        tool_use_id: 'dedup_ref',
        content: `[File Reference] Content of ${path} already provided in message #${targetIndex}`
      }]
    }
  }
  
  private estimateReferenceTokens(): number {
    return 50  // Typical reference size
  }
  
  private async countTokens(content: string): Promise<number> {
    // Use tokenizer
    return Math.ceil(content.length / 4)  // Rough estimate
  }
}
```

**Tests**:

```typescript
describe('FileReadDeduplicator', () => {
  it('should deduplicate identical file reads', async () => {
    const deduplicator = new FileReadDeduplicator()
    
    const messages = [
      createFileReadMessage('main.ts', 'content1', 0),
      createFileReadMessage('main.ts', 'content1', 5),
      createFileReadMessage('main.ts', 'content1', 10),
    ]
    
    const result = await deduplicator.deduplicateFileReads(messages)
    
    expect(result.messages[0]).toMatchObject({ role: 'user' })  // Reference
    expect(result.messages[1]).toMatchObject({ role: 'user' })  // Reference
    expect(result.messages[2].content).toContain('content1')    // Original
    expect(result.tokensSaved).toBeGreaterThan(0)
  })
  
  it('should keep different file versions separate', async () => {
    const messages = [
      createFileReadMessage('main.ts', 'version1', 0),
      createFileReadMessage('main.ts', 'version2', 5),
    ]
    
    const result = await deduplicator.deduplicateFileReads(messages)
    
    // Both should be kept as content differs
    expect(result.messages[0].content).toContain('version1')
    expect(result.messages[1].content).toContain('version2')
  })
})
```

**Checklist**:
- [ ] Deduplication implémentée
- [ ] Hash de contenu fonctionnel
- [ ] Références créées correctement
- [ ] Tests unitaires >90%
- [ ] Économie de tokens mesurée

#### 5.1.2 Tool Result Consolidation (2 jours / 16h)

**Fichier**: `src/core/condense/providers/lossless/consolidation.ts`

```typescript
interface ResultGroup {
  hash: string
  indices: number[]
  content: string
  tokens: number
}

export class ToolResultConsolidator {
  private resultGroups = new Map<string, ResultGroup>()
  
  async consolidateToolResults(
    messages: ApiMessage[]
  ): Promise<{ messages: ApiMessage[], tokensSaved: number }> {
    // Grouper résultats identiques
    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i]
      if (this.hasToolResult(msg)) {
        const hash = this.hashToolResult(msg)
        const content = this.extractContent(msg)
        const tokens = await this.countTokens(content)
        
        if (!this.resultGroups.has(hash)) {
          this.resultGroups.set(hash, {
            hash,
            indices: [],
            content,
            tokens
          })
        }
        
        this.resultGroups.get(hash)!.indices.push(i)
      }
    }
    
    // Consolider duplicatas
    let tokensSaved = 0
    const processed = messages.map((msg, i) => {
      if (this.hasToolResult(msg)) {
        const hash = this.hashToolResult(msg)
        const group = this.resultGroups.get(hash)!
        
        if (group.indices[0] === i) {
          // Première occurrence → garder avec note
          if (group.indices.length > 1) {
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
  
  private hasToolResult(message: ApiMessage): boolean {
    if (typeof message.content === 'string') return false
    return message.content.some(b => b.type === 'tool_result')
  }
  
  private hashToolResult(message: ApiMessage): string {
    const content = this.extractContent(message)
    return crypto.createHash('sha256')
      .update(content)
      .digest('hex')
      .substring(0, 16)
  }
  
  private extractContent(message: ApiMessage): string {
    if (typeof message.content === 'string') return message.content
    
    const toolResult = message.content.find(b => b.type === 'tool_result')
    return toolResult ? String(toolResult.content) : ''
  }
  
  private addDuplicationNote(
    message: ApiMessage,
    count: number
  ): ApiMessage {
    const content = typeof message.content === 'string'
      ? message.content
      : message.content.map(b => b.type === 'tool_result' ? b.content : '').join('')
    
    return {
      ...message,
      content: [
        {
          type: 'tool_result',
          tool_use_id: 'consolidated',
          content: `${content}\n\n[Note: This result appears ${count} times in the conversation]`
        }
      ]
    }
  }
  
  private createResultReference(targetIndex: number): ApiMessage {
    return {
      role: 'user',
      content: [{
        type: 'tool_result',
        tool_use_id: 'consolidated_ref',
        content: `[Result Reference] Same as message #${targetIndex}`
      }]
    }
  }
  
  private async countTokens(content: string): Promise<number> {
    return Math.ceil(content.length / 4)
  }
}
```

**Tests**:

```typescript
describe('ToolResultConsolidator', () => {
  it('should consolidate identical results', async () => {
    const consolidator = new ToolResultConsolidator()
    
    const messages = [
      createToolResultMessage('Error: file not found', 0),
      createToolResultMessage('Error: file not found', 3),
      createToolResultMessage('Error: file not found', 7),
    ]
    
    const result = await consolidator.consolidateToolResults(messages)
    
    expect(result.messages[0].content).toContain('appears 3 times')
    expect(result.messages[1].content).toContain('Reference')
    expect(result.messages[2].content).toContain('Reference')
    expect(result.tokensSaved).toBeGreaterThan(0)
  })
  
  it('should keep different results separate', async () => {
    const messages = [
      createToolResultMessage('Result A', 0),
      createToolResultMessage('Result B', 1),
    ]
    
    const result = await consolidator.consolidateToolResults(messages)
    
    expect(result.messages[0].content).toContain('Result A')
    expect(result.messages[1].content).toContain('Result B')
  })
})
```

**Checklist**:
- [ ] Consolidation implémentée
- [ ] Groupement par hash
- [ ] Notes de duplication ajoutées
- [ ] Tests unitaires >90%

#### 5.1.3 Obsolete State Removal (1 jour / 8h)

**Fichier**: `src/core/condense/providers/lossless/obsolete-state.ts`

```typescript
interface StateInfo {
  entityId: string
  version: string
  messageIndex: number
}

export class ObsoleteStateRemover {
  private stateTracking = new Map<string, StateInfo[]>()
  
  async removeObsoleteState(
    messages: ApiMessage[]
  ): Promise<{ messages: ApiMessage[], tokensSaved: number }> {
    // Identifier versions d'états
    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i]
      const state = this.extractStateInfo(msg)
      
      if (state) {
        const key = state.entityId
        if (!this.stateTracking.has(key)) {
          this.stateTracking.set(key, [])
        }
        this.stateTracking.get(key)!.push({
          ...state,
          messageIndex: i
        })
      }
    }
    
    // Marquer obsolètes
    const obsolete = new Set<number>()
    for (const [_, states] of this.stateTracking) {
      if (states.length > 1) {
        // Garder seulement la dernière
        const latest = states[states.length - 1]
        for (const s of states) {
          if (s.messageIndex !== latest.messageIndex) {
            obsolete.add(s.messageIndex)
          }
        }
      }
    }
    
    // Filtrer
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
    // - write_to_file → file state
    // - search_files → search results
    
    if (this.isToolResult(message, 'write_to_file')) {
      const path = this.extractFilePath(message)
      return {
        entityId: `file:${path}`,
        version: String(Date.now())
      }
    }
    
    return null
  }
  
  private isToolResult(message: ApiMessage, toolName: string): boolean {
    // Check tool_result for specific tool
    return false  // Simplified
  }
  
  private extractFilePath(message: ApiMessage): string {
    // Extract from content
    return 'unknown'
  }
  
  private estimateTokens(message: ApiMessage): number {
    const content = typeof message.content === 'string'
      ? message.content
      : JSON.stringify(message.content)
    return Math.ceil(content.length / 4)
  }
}
```

**Checklist**:
- [ ] Detection d'états implémentée
- [ ] Suppression d'obsolètes
- [ ] Tests unitaires

#### 5.1.4 LosslessCondensationProvider (2 jours / 16h)

**Fichier**: `src/core/condense/providers/lossless/index.ts`

```typescript
export class LosslessCondensationProvider implements ICondensationProvider {
  readonly id = 'lossless'
  readonly name = 'Lossless Optimization'
  readonly description = 'Zero information loss via deduplication and consolidation'
  readonly version = '1.0.0'
  

**Checklist Phase 3**:
- [ ] Deduplication implémentée
- [ ] Consolidation implémentée
- [ ] Obsolete removal implémenté
- [ ] Provider complet et testé
- [ ] 30-50% reduction atteinte
- [ ] <1s execution validée
- [ ] Zero information loss vérifié

---

*Note: Ce document continue dans la prochaine version avec les phases 4-7 et les sections complémentaires.*

---

**Document Status**: Version 2.0 - Consolidated  
**Prochaines Étapes**: 
1. Implémenter Phase 1 (Fondations)
2. Valider avec tests
3. Continuer avec Phase 2 (Native Provider)

**Liens Référence**:
- [Requirements v2](002-requirements-specification-v2.md)
- [Architecture v2](003-provider-architecture-v2.md)
- [All Providers](004-all-providers-and-strategies.md)
- [Pass Architecture](008-refined-pass-architecture.md)