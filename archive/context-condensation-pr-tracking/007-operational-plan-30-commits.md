# Plan Opérationnel - 30 Commits Context Condensation Provider System

**Version**: 1.0  
**Date**: 2025-10-02  
**Status**: Opérationnel - Prêt à l'exécution  
**Auteur**: Architecture Team (Roo Architect Mode)

---

## 📋 Table des Matières

1. [Principes Directeurs](#principes-directeurs)
2. [Architecture Globale](#architecture-globale)
3. [Les 30 Commits Détaillés](#les-30-commits-détaillés)
4. [Checkpoints de Validation](#checkpoints-de-validation)
5. [Stratégie de Test](#stratégie-de-test)
6. [Documentation Continue](#documentation-continue)
7. [Métriques de Succès](#métriques-de-succès)
8. [Risques et Mitigations](#risques-et-mitigations)
9. [Timeline Réaliste](#timeline-réaliste)

---

## Principes Directeurs

### 1. **Provider Pattern dès le début** 🏗️

**Pas d'approche "in-place"** : L'architecture provider est introduite immédiatement au Commit 1-2. Le Native Provider wrappera le système existant sans le modifier, garantissant :
- Zero breaking changes
- Architecture extensible dès le départ
- Tests de non-régression depuis le début

**Rationale** : Éviter le travail de refactoring ultérieur et les risques de régression. L'extraction ultérieure serait coûteuse et risquée.

### 2. **Progressivité rigoureuse** 📈

Chaque commit apporte de la **valeur testable et déployable** :
- Commit atomique : une fonctionnalité, un test, une validation
- Aucun commit "WIP" ou incomplet
- Backward compatibility à chaque étape
- Déploiement possible à tout moment via roo-code-customization

### 3. **Checkpoints SDDD** 🔍

**Validation sémantique régulière** tous les 2-3 commits :
- Recherche sémantique du code nouvellement créé
- Vérification de découvrabilité des concepts
- Documentation de suivi mise à jour
- Grounding pour la suite du travail

**Format checkpoint** :
```markdown
### Checkpoint N (Après Commit X)
**Recherche SDDD** : "query sémantique"
**Docs attendus** : Liste des fichiers/concepts à retrouver
**Validation** : Critères de succès
**Déploiement** : Build + test environnement isolé
```

### 4. **Déploiements incrémentaux** 🚀

Via **roo-code-customization** pour rollback immédiat :
- Build VSIX à chaque checkpoint
- Test en environnement isolé
- Validation utilisateurs pilotes
- Rollback plan toujours prêt

### 5. **Tests exhaustifs** ✅

- **TDD** quand applicable
- **>90% coverage** sur nouveau code
- Tests unitaires + intégration + end-to-end
- Performance benchmarks à chaque checkpoint

### 6. **Multi-passes préparé** 🎯

Architecture permet ajout facile en Phase 4 :
- Smart Provider introduit en Commit 18-25
- Système simple au départ : **2-3 presets**
- Extension facile vers configuration avancée plus tard

---

## Architecture Globale

### Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                    src/core/sliding-window/index.ts             │
│                    truncateConversationIfNeeded()               │
│                    Ligne 145-165 : POINT D'INTÉGRATION UNIQUE   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              CondensationProviderManager                        │
│  - Sélection provider basée sur configuration                  │
│  - Gestion des seuils et profils API                           │
│  - Orchestration appels + fallback sur erreur                  │
│  - Métriques et coûts                                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│            ICondensationProvider (Interface)                    │
│  - condense(context, options): Promise<Result>                  │
│  - estimateCost(context, options): number                       │
│  - estimateReduction(context): number                           │
│  - getCapabilities(): Capabilities                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┬───────────────────┐
         ▼               ▼               ▼                   ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Native     │ │   Lossless   │ │  Truncation  │ │    Smart     │
│   Provider   │ │   Provider   │ │   Provider   │ │   Provider   │
│              │ │              │ │              │ │              │
│ Wrap actuel  │ │ Déduplication│ │ Sliding      │ │ Multi-passes │
│ LLM-based    │ │ gratuite     │ │ Window rapide│ │ intelligent  │
│              │ │              │ │              │ │              │
│ Cost: $$     │ │ Cost: FREE   │ │ Cost: FREE   │ │ Cost: $$     │
│ Speed: Slow  │ │ Speed: Fast  │ │ Speed: Fast  │ │ Speed: Slow  │
│ Quality: High│ │ Quality: High│ │ Quality: Low │ │ Quality: Very│
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

### Composants Clés

#### 1. **CondensationProviderManager** (Chef d'orchestre)

**Responsabilités** :
- Sélection du provider actif selon configuration utilisateur
- Gestion des seuils de condensation par profil API
- Fallback automatique sur erreur (Native → Lossless → Truncation)
- Tracking des métriques (coûts, performances, taux de succès)
- Intégration transparente avec système existant

**Fichier** : `src/core/condense/provider-manager.ts`

#### 2. **ICondensationProvider** (Interface commune)

**Contrat** :
```typescript
interface ICondensationProvider {
  readonly id: string
  readonly name: string
  readonly description: string
  
  condense(context: CondensationContext, options: CondensationOptions): Promise<CondensationResult>
  estimateCost(context: CondensationContext, options: CondensationOptions): number
  estimateReduction(context: CondensationContext): number
  getCapabilities(): ProviderCapabilities
  validateOptions(options: CondensationOptions): ValidationResult
}
```

**Fichier** : `src/core/condense/types.ts`

#### 3. **Native Provider** (Wrap du système actuel)

Encapsule `summarizeConversation()` existante **sans modification** :
- Comportement identique à l'actuel
- Tests de non-régression garantis
- Backward compatibility 100%
- Foundation pour autres providers

**Fichier** : `src/core/condense/providers/native-provider.ts`

#### 4. **Lossless Provider** (Déduplication)

Optimisation **gratuite et rapide** :
- Déduplication de fichiers lus multiples fois
- Consolidation de tool results identiques
- **20-40% réduction tokens sans perte**
- Aucun appel LLM = gratuit + rapide

**Fichier** : `src/core/condense/providers/lossless-provider.ts`

#### 5. **Truncation Provider** (Sliding Window)

Alternative **rapide et gratuite** au LLM :
- Suppression chronologique simple (sliding window)
- Utile quand budget serré ou latence critique
- Wrap de `truncateConversation()` existante
- Fallback de dernier recours

**Fichier** : `src/core/condense/providers/truncation-provider.ts`

#### 6. **Smart Provider** (Multi-passes)

Système **intelligent mais simple** :
- Architecture pass-based extensible
- **MVP : 2-3 presets prédéfinis** ("Quality", "Balanced", "Aggressive")
- Pas de UI complexe au départ
- Extension vers configuration avancée plus tard
- Phase lossless + phase lossy

**Fichier** : `src/core/condense/providers/smart-provider.ts`

### Points d'Intégration

#### Point d'Intégration Unique : `sliding-window/index.ts`

**Ligne 145-165** (fonction `truncateConversationIfNeeded`) :

```typescript
// AVANT (actuel)
if (autoCondenseContext) {
  const contextPercent = (100 * prevContextTokens) / contextWindow
  if (contextPercent >= effectiveThreshold || prevContextTokens > allowedTokens) {
    const result = await summarizeConversation(...)
    if (result.error) {
      error = result.error
      cost = result.cost
    } else {
      return { ...result, prevContextTokens }
    }
  }
}

// APRÈS (avec provider system)
if (autoCondenseContext) {
  const contextPercent = (100 * prevContextTokens) / contextWindow
  if (contextPercent >= effectiveThreshold || prevContextTokens > allowedTokens) {
    // Nouvelle intégration via manager
    const result = await condensationManager.condenseIfNeeded({
      messages,
      prevContextTokens,
      contextWindow,
      apiHandler,
      systemPrompt,
      taskId,
      customCondensingPrompt,
      condensingApiHandler,
      profileThresholds,
      currentProfileId
    })
    if (result.error) {
      error = result.error
      cost = result.cost
    } else {
      return { ...result, prevContextTokens }
    }
  }
}
```

**Changements minimaux** :
- Une seule ligne modifiée : appel au manager au lieu de `summarizeConversation`
- Aucun changement de signature
- Aucun changement de comportement par défaut (Native provider)

#### Configuration Settings

**Nouveau setting** : `condensationProvider`

```typescript
// src/shared/ExtensionMessage.ts
type ExtensionSettings = {
  // ... existant ...
  condensationProvider?: "native" | "lossless" | "truncation" | "smart"
  condensationSmartPreset?: "quality" | "balanced" | "aggressive" // Phase 4
}
```

**UI Setting** : `webview-ui/src/components/settings/ContextManagementSettings.tsx`

```tsx
<select 
  value={condensationProvider ?? "native"}
  onChange={e => setCachedStateField("condensationProvider", e.target.value)}
>
  <option value="native">Native (Current behavior)</option>
  <option value="lossless">Lossless (Fast, Free, 20-40% reduction)</option>
  <option value="truncation">Truncation (Fast, Free, Simple)</option>
  <option value="smart">Smart (Intelligent, Configurable)</option>
</select>
```

---

## Les 30 Commits Détaillés

### BLOC 1 : Foundation + Native Provider (Commits 1-8)

**Objectif** : Établir l'architecture provider et wrapper le système actuel sans modification.

---

#### **Commit 1 : Core Types & Interfaces**

**Fichiers créés** :
- `src/core/condense/types.ts` (150 lignes)
- `src/core/condense/__tests__/types.test.ts` (100 lignes)

**Contenu** :

```typescript
// types.ts - Structure complète

/**
 * Context information passed to condensation providers
 */
export interface CondensationContext {
  messages: ApiMessage[]
  prevContextTokens: number
  contextWindow: number
  systemPrompt: string
  taskId: string
}

/**
 * Configuration options for condensation
 */
export interface CondensationOptions {
  apiHandler: ApiHandler
  autoCondenseContextPercent: number
  customCondensingPrompt?: string
  condensingApiHandler?: ApiHandler
  profileThresholds: Record<string, number>
  currentProfileId: string
  allowedTokens: number
}

/**
 * Result returned by condensation providers
 */
export interface CondensationResult {
  messages: ApiMessage[]
  summary: string
  cost: number
  newContextTokens?: number
  error?: string
  prevContextTokens: number
}

/**
 * Metrics tracked by providers
 */
export interface ProviderMetrics {
  callCount: number
  successCount: number
  errorCount: number
  totalCost: number
  totalTokensReduced: number
  averageReductionPercent: number
  averageLatencyMs: number
}

/**
 * Provider capabilities declaration
 */
export interface ProviderCapabilities {
  supportsLLM: boolean
  supportsLossless: boolean
  supportsTruncation: boolean
  supportsMultiPass: boolean
  isFree: boolean
  estimatedSpeed: "fast" | "medium" | "slow"
}

/**
 * Base interface for all condensation providers
 */
export interface ICondensationProvider {
  readonly id: string
  readonly name: string
  readonly description: string
  
  condense(
    context: CondensationContext,
    options: CondensationOptions
  ): Promise<CondensationResult>
  
  estimateCost(
    context: CondensationContext,
    options: CondensationOptions
  ): number
  
  estimateReduction(context: CondensationContext): number
  
  getCapabilities(): ProviderCapabilities
  
  validateOptions(options: CondensationOptions): ValidationResult
}

/**
 * Validation result for options
 */
export interface ValidationResult {
  valid: boolean
  errors: string[]
}
```

**Tests** (`__tests__/types.test.ts`) :
```typescript
describe("CondensationTypes", () => {
  describe("CondensationContext", () => {
    it("should accept valid context", () => {
      const context: CondensationContext = {
        messages: [],
        prevContextTokens: 1000,
        contextWindow: 200000,
        systemPrompt: "test",
        taskId: "task-123"
      }
      expect(context).toBeDefined()
    })
  })
  
  describe("CondensationOptions", () => {
    it("should accept valid options", () => {
      const options: CondensationOptions = {
        apiHandler: mockApiHandler,
        autoCondenseContextPercent: 75,
        profileThresholds: {},
        currentProfileId: "default",
        allowedTokens: 180000
      }
      expect(options).toBeDefined()
    })
  })
  
  // Tests pour chaque interface...
})
```

**Checkpoint SDDD** : Recherche `"condensation provider interface types architecture"`

**Taille estimée** : 150 lignes code + 100 lignes tests = **250 lignes**

**Dépendances** : Aucune

**Validation** :
- [ ] Types compilent sans erreur
- [ ] Tests unitaires passent (100% coverage sur types)
- [ ] Recherche sémantique retrouve les interfaces

---

#### **Commit 2 : Base Provider Abstract Class**

**Fichiers créés** :
- `src/core/condense/base-provider.ts` (200 lignes)
- `src/core/condense/__tests__/base-provider.test.ts` (150 lignes)

**Contenu** :

```typescript
// base-provider.ts

import { ICondensationProvider, CondensationContext, CondensationOptions, 
         CondensationResult, ProviderCapabilities, ValidationResult, 
         ProviderMetrics } from "./types"

/**
 * Abstract base class for condensation providers.
 * Provides common functionality like metrics tracking, cost estimation,
 * and error handling.
 */
export abstract class BaseCondensationProvider implements ICondensationProvider {
  protected metrics: ProviderMetrics = {
    callCount: 0,
    successCount: 0,
    errorCount: 0,
    totalCost: 0,
    totalTokensReduced: 0,
    averageReductionPercent: 0,
    averageLatencyMs: 0
  }
  
  abstract readonly id: string
  abstract readonly name: string
  abstract readonly description: string
  
  /**
   * Main condensation method - must be implemented by subclasses
   */
  abstract condense(
    context: CondensationContext,
    options: CondensationOptions
  ): Promise<CondensationResult>
  
  /**
   * Estimate cost of condensation - can be overridden
   */
  estimateCost(
    context: CondensationContext,
    options: CondensationOptions
  ): number {
    // Default: no cost estimation
    return 0
  }
  
  /**
   * Estimate token reduction percentage
   */
  estimateReduction(context: CondensationContext): number {
    // Default: conservative 20% estimate
    return 0.2
  }
  
  /**
   * Get provider capabilities
   */
  abstract getCapabilities(): ProviderCapabilities
  
  /**
   * Validate options before condensation
   */
  validateOptions(options: CondensationOptions): ValidationResult {
    const errors: string[] = []
    
    if (!options.apiHandler) {
      errors.push("apiHandler is required")
    }
    
    if (options.autoCondenseContextPercent < 5 || 
        options.autoCondenseContextPercent > 100) {
      errors.push("autoCondenseContextPercent must be between 5 and 100")
    }
    
    if (options.allowedTokens <= 0) {
      errors.push("allowedTokens must be positive")
    }
    
    return {
      valid: errors.length === 0,
      errors
    }
  }
  
  /**
   * Track metrics for a condensation call
   */
  protected trackMetrics(
    startTime: number,
    result: CondensationResult,
    context: CondensationContext
  ): void {
    this.metrics.callCount++
    
    if (result.error) {
      this.metrics.errorCount++
    } else {
      this.metrics.successCount++
      this.metrics.totalCost += result.cost
      
      const tokensReduced = context.prevContextTokens - (result.newContextTokens ?? 0)
      this.metrics.totalTokensReduced += tokensReduced
      
      const reductionPercent = (tokensReduced / context.prevContextTokens) * 100
      this.metrics.averageReductionPercent = 
        (this.metrics.averageReductionPercent * (this.metrics.successCount - 1) + reductionPercent) 
        / this.metrics.successCount
    }
    
    const latency = Date.now() - startTime
    this.metrics.averageLatencyMs = 
      (this.metrics.averageLatencyMs * (this.metrics.callCount - 1) + latency) 
      / this.metrics.callCount
  }
  
  /**
   * Get current metrics
   */
  getMetrics(): ProviderMetrics {
    return { ...this.metrics }
  }
  
  /**
   * Reset metrics
   */
  resetMetrics(): void {
    this.metrics = {
      callCount: 0,
      successCount: 0,
      errorCount: 0,
      totalCost: 0,
      totalTokensReduced: 0,
      averageReductionPercent: 0,
      averageLatencyMs: 0
    }
  }
  
  /**
   * Log condensation attempt
   */
  protected logCondensation(
    context: CondensationContext,
    result: CondensationResult
  ): void {
    console.log(`[${this.name}] Condensation`, {
      taskId: context.taskId,
      before: context.prevContextTokens,
      after: result.newContextTokens,
      reduction: result.newContextTokens 
        ? ((1 - result.newContextTokens / context.prevContextTokens) * 100).toFixed(1) + '%'
        : 'N/A',
      cost: result.cost.toFixed(4),
      error: result.error
    })
  }
}
```

**Tests** (`__tests__/base-provider.test.ts`) :
```typescript
// Test implementation of BaseCondensationProvider
class TestProvider extends BaseCondensationProvider {
  readonly id = "test"
  readonly name = "Test Provider"
  readonly description = "Test implementation"
  
  async condense(
    context: CondensationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    return {
      messages: context.messages,
      summary: "",
      cost: 0,
      prevContextTokens: context.prevContextTokens
    }
  }
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLLM: false,
      supportsLossless: false,
      supportsTruncation: false,
      supportsMultiPass: false,
      isFree: true,
      estimatedSpeed: "fast"
    }
  }
}

describe("BaseCondensationProvider", () => {
  let provider: TestProvider
  
  beforeEach(() => {
    provider = new TestProvider()
  })
  
  describe("validateOptions", () => {
    it("should validate correct options", () => {
      const result = provider.validateOptions({
        apiHandler: mockApiHandler,
        autoCondenseContextPercent: 75,
        profileThresholds: {},
        currentProfileId: "default",
        allowedTokens: 100000
      })
      expect(result.valid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })
    
    it("should reject missing apiHandler", () => {
      const result = provider.validateOptions({
        apiHandler: null as any,
        autoCondenseContextPercent: 75,
        profileThresholds: {},
        currentProfileId: "default",
        allowedTokens: 100000
      })
      expect(result.valid).toBe(false)
      expect(result.errors).toContain("apiHandler is required")
    })
    
    it("should reject invalid threshold", () => {
      const result = provider.validateOptions({
        apiHandler: mockApiHandler,
        autoCondenseContextPercent: 150, // Invalid
        profileThresholds: {},
        currentProfileId: "default",
        allowedTokens: 100000
      })
      expect(result.valid).toBe(false)
      expect(result.errors.length).toBeGreaterThan(0)
    })
  })
  
  describe("metrics tracking", () => {
    it("should track successful condensation", async () => {
      const context: CondensationContext = {
        messages: [],
        prevContextTokens: 10000,
        contextWindow: 200000,
        systemPrompt: "test",
        taskId: "task-123"
      }
      
      await provider.condense(context, validOptions)
      
      const metrics = provider.getMetrics()
      expect(metrics.callCount).toBe(1)
      expect(metrics.successCount).toBe(1)
    })
    
    it("should calculate average reduction", async () => {
      // Test multiple calls and average calculation
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"base provider abstract class condensation metrics"`

**Taille estimée** : 200 lignes code + 150 lignes tests = **350 lignes**

**Dépendances** : Commit 1

**Validation** :
- [ ] BaseCondensationProvider compile
- [ ] Tests unitaires passent (>90% coverage)
- [ ] Métriques trackées correctement
- [ ] Validation options fonctionne

---

#### **Commit 3 : Native Provider Implementation**

**Fichiers créés** :
- `src/core/condense/providers/native-provider.ts` (180 lignes)
- `src/core/condense/providers/__tests__/native-provider.test.ts` (200 lignes)

**Contenu** :

```typescript
// providers/native-provider.ts

import { BaseCondensationProvider } from "../base-provider"
import { summarizeConversation } from "../index"
import { CondensationContext, CondensationOptions, CondensationResult, 
         ProviderCapabilities } from "../types"

/**
 * Native Provider - Wraps the existing LLM-based summarization system.
 * 
 * This provider preserves the current behavior exactly, ensuring backward
 * compatibility. It uses the summarizeConversation function without modification.
 * 
 * Characteristics:
 * - Uses LLM calls (Anthropic or custom API handler)
 * - High quality summaries
 * - Relatively slow (~5-10s per call)
 * - Costs $0.05-0.10 per condensation (depending on model)
 * - Preserves semantic meaning and conversation flow
 */
export class NativeCondensationProvider extends BaseCondensationProvider {
  readonly id = "native"
  readonly name = "Native (LLM-based)"
  readonly description = "High-quality LLM-based summarization (current behavior)"
  
  /**
   * Condense conversation using LLM summarization
   */
  async condense(
    context: CondensationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const startTime = Date.now()
    
    // Validate options
    const validation = this.validateOptions(options)
    if (!validation.valid) {
      return {
        messages: context.messages,
        summary: "",
        cost: 0,
        prevContextTokens: context.prevContextTokens,
        error: `Validation failed: ${validation.errors.join(", ")}`
      }
    }
    
    try {
      // Call existing summarizeConversation function without modification
      const result = await summarizeConversation(
        context.messages,
        options.apiHandler,
        context.systemPrompt,
        context.taskId,
        context.prevContextTokens,
        true, // automatic trigger
        options.customCondensingPrompt,
        options.condensingApiHandler
      )
      
      // Convert to CondensationResult format
      const condensationResult: CondensationResult = {
        messages: result.messages,
        summary: result.summary,
        cost: result.cost,
        newContextTokens: result.newContextTokens,
        error: result.error,
        prevContextTokens: context.prevContextTokens
      }
      
      // Track metrics
      this.trackMetrics(startTime, condensationResult, context)
      this.logCondensation(context, condensationResult)
      
      return condensationResult
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      const condensationResult: CondensationResult = {
        messages: context.messages,
        summary: "",
        cost: 0,
        prevContextTokens: context.prevContextTokens,
        error: `Native provider error: ${errorMessage}`
      }
      
      this.trackMetrics(startTime, condensationResult, context)
      
      return condensationResult
    }
  }
  
  /**
   * Estimate cost based on typical LLM pricing
   */
  estimateCost(
    context: CondensationContext,
    options: CondensationOptions
  ): number {
    // Rough estimation: $3 per 1M input tokens, $15 per 1M output tokens
    // Typical condensation: 10k input → 1k output
    const inputCost = (context.prevContextTokens / 1_000_000) * 3
    const outputCost = (1000 / 1_000_000) * 15 // Assume ~1k output
    return inputCost + outputCost
  }
  
  /**
   * Estimate reduction based on historical data
   */
  estimateReduction(context: CondensationContext): number {
    // Native provider typically reduces by 40-60%
    return 0.5
  }
  
  /**
   * Get provider capabilities
   */
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLLM: true,
      supportsLossless: false,
      supportsTruncation: false,
      supportsMultiPass: false,
      isFree: false,
      estimatedSpeed: "slow"
    }
  }
}
```

**Tests** (`providers/__tests__/native-provider.test.ts`) :
```typescript
describe("NativeCondensationProvider", () => {
  let provider: NativeCondensationProvider
  let mockApiHandler: jest.Mocked<ApiHandler>
  
  beforeEach(() => {
    provider = new NativeCondensationProvider()
    mockApiHandler = createMockApiHandler()
  })
  
  describe("condense", () => {
    it("should call summarizeConversation with correct parameters", async () => {
      const context: CondensationContext = {
        messages: createMockMessages(10),
        prevContextTokens: 10000,
        contextWindow: 200000,
        systemPrompt: "You are a helpful assistant",
        taskId: "task-123"
      }
      
      const options: CondensationOptions = {
        apiHandler: mockApiHandler,
        autoCondenseContextPercent: 75,
        profileThresholds: {},
        currentProfileId: "default",
        allowedTokens: 180000
      }
      
      const result = await provider.condense(context, options)
      
      expect(result.error).toBeUndefined()
      expect(result.messages.length).toBeLessThan(context.messages.length)
      expect(result.cost).toBeGreaterThan(0)
    })
    
    it("should preserve behavior identical to current system", async () => {
      // Test against current summarizeConversation output
      const directResult = await summarizeConversation(...)
      const providerResult = await provider.condense(...)
      
      expect(providerResult.messages).toEqual(directResult.messages)
      expect(providerResult.summary).toEqual(directResult.summary)
      expect(providerResult.cost).toEqual(directResult.cost)
    })
    
    it("should handle errors gracefully", async () => {
      mockApiHandler.createMessage.mockImplementation(() => {
        throw new Error("API error")
      })
      
      const result = await provider.condense(context, options)
      
      expect(result.error).toContain("Native provider error")
      expect(result.messages).toEqual(context.messages) // Unchanged on error
    })
    
    it("should track metrics correctly", async () => {
      await provider.condense(context, options)
      
      const metrics = provider.getMetrics()
      expect(metrics.callCount).toBe(1)
      expect(metrics.successCount).toBe(1)
      expect(metrics.totalCost).toBeGreaterThan(0)
    })
  })
  
  describe("estimateCost", () => {
    it("should provide reasonable cost estimate", () => {
      const cost = provider.estimateCost(context, options)
      expect(cost).toBeGreaterThan(0)
      expect(cost).toBeLessThan(1) // Should be less than $1
    })
  })
  
  describe("getCapabilities", () => {
    it("should return correct capabilities", () => {
      const caps = provider.getCapabilities()
      expect(caps.supportsLLM).toBe(true)
      expect(caps.isFree).toBe(false)
      expect(caps.estimatedSpeed).toBe("slow")
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"native provider llm summarization wrapper backward compatibility"`

**Taille estimée** : 180 lignes code + 200 lignes tests = **380 lignes**

**Dépendances** : Commits 1-2

**Validation** :
- [ ] Native Provider compile et wrap summarizeConversation
- [ ] Tests de backward compatibility passent
- [ ] Comportement identique au système actuel vérifié
- [ ] Aucune régression dans tests existants

---

#### **Commit 4 : Provider Manager Core**

**Fichiers créés** :
- `src/core/condense/provider-manager.ts` (250 lignes)
- `src/core/condense/__tests__/provider-manager.test.ts` (200 lignes)

**Contenu** :

```typescript
// provider-manager.ts

import { ICondensationProvider, CondensationContext, CondensationOptions, 
         CondensationResult } from "./types"
import { NativeCondensationProvider } from "./providers/native-provider"

/**
 * CondensationProviderManager orchestrates condensation across multiple providers.
 * 
 * Responsibilities:
 * - Provider selection based on configuration
 * - Threshold management per API profile
 * - Fallback strategy on provider failure
 * - Metrics aggregation across providers
 */
export class CondensationProviderManager {
  private providers: Map<string, ICondensationProvider> = new Map()
  private activeProviderId: string = "native"
  
  constructor() {
    // Register Native provider by default
    this.registerProvider(new NativeCondensationProvider())
  }
  
  /**
   * Register a new provider
   */
  registerProvider(provider: ICondensationProvider): void {
    this.providers.set(provider.id, provider)
  }
  
  /**
   * Set the active provider
   */
  setActiveProvider(providerId: string): void {
    if (!this.providers.has(providerId)) {
      throw new Error(`Provider "${providerId}" not registered`)
    }
    this.activeProviderId = providerId
  }
  
  /**
   * Get the active provider
   */
  getActiveProvider(): ICondensationProvider {
    const provider = this.providers.get(this.activeProviderId)
    if (!provider) {
      throw new Error(`Active provider "${this.activeProviderId}" not found`)
    }
    return provider
  }
  
  /**
   * Get all registered providers
   */
  getAllProviders(): ICondensationProvider[] {
    return Array.from(this.providers.values())
  }
  
  /**
   * Main condensation orchestration method
   */
  async condenseIfNeeded(
    context: CondensationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const provider = this.getActiveProvider()
    
    // Validate options
    const validation = provider.validateOptions(options)
    if (!validation.valid) {
      return {
        messages: context.messages,
        summary: "",
        cost: 0,
        prevContextTokens: context.prevContextTokens,
        error: `Validation failed: ${validation.errors.join(", ")}`
      }
    }
    
    try {
      // Execute condensation with active provider
      const result = await provider.condense(context, options)
      
      // If provider failed, attempt fallback
      if (result.error) {
        return await this.handleProviderFailure(context, options, result.error)
      }
      
      return result
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      return await this.handleProviderFailure(
        context, 
        options, 
        `Provider exception: ${errorMessage}`
      )
    }
  }
  
  /**
   * Handle provider failure with fallback strategy
   */
  private async handleProviderFailure(
    context: CondensationContext,
    options: CondensationOptions,
    errorMessage: string
  ): Promise<CondensationResult> {
    console.error(`[CondensationManager] Provider failure: ${errorMessage}`)
    
    // For now, just return error result
    // Later commits will add fallback to other providers
    return {
      messages: context.messages,
      summary: "",
      cost: 0,
      prevContextTokens: context.prevContextTokens,
      error: errorMessage
    }
  }
  
  /**
   * Calculate effective threshold considering profile-specific overrides
   */
  calculateEffectiveThreshold(
    options: CondensationOptions
  ): number {
    const { profileThresholds, currentProfileId, autoCondenseContextPercent } = options
    
    const profileThreshold = profileThresholds[currentProfileId]
    
    // -1 means inherit from global setting
    if (profileThreshold === -1 || profileThreshold === undefined) {
      return autoCondenseContextPercent
    }
    
    // Validate threshold is in valid range
    if (profileThreshold >= 5 && profileThreshold <= 100) {
      return profileThreshold
    }
    
    // Invalid, fall back to global
    console.warn(
      `Invalid profile threshold ${profileThreshold} for profile "${currentProfileId}". ` +
      `Using global default of ${autoCondenseContextPercent}%`
    )
    return autoCondenseContextPercent
  }
  
  /**
   * Estimate cost of condensation with active provider
   */
  estimateCost(
    context: CondensationContext,
    options: CondensationOptions
  ): number {
    const provider = this.getActiveProvider()
    return provider.estimateCost(context, options)
  }
  
  /**
   * Get aggregated metrics across all providers
   */
  getAggregatedMetrics() {
    const metrics: Record<string, any> = {}
    
    for (const [id, provider] of this.providers.entries()) {
      if ('getMetrics' in provider) {
        metrics[id] = (provider as any).getMetrics()
      }
    }
    
    return metrics
  }
}

// Singleton instance
export const condensationManager = new CondensationProviderManager()
```

**Tests** (`__tests__/provider-manager.test.ts`) :
```typescript
describe("CondensationProviderManager", () => {
  let manager: CondensationProviderManager
  
  beforeEach(() => {
    manager = new CondensationProviderManager()
  })
  
  describe("provider registration", () => {
    it("should register native provider by default", () => {
      const providers = manager.getAllProviders()
      expect(providers).toHaveLength(1)
      expect(providers[0].id).toBe("native")
    })
    
    it("should register new providers", () => {
      const mockProvider = createMockProvider("test")
      manager.registerProvider(mockProvider)
      
      const providers = manager.getAllProviders()
      expect(providers).toHaveLength(2)
    })
  })
  
  describe("provider selection", () => {
    it("should set and get active provider", () => {
      const mockProvider = createMockProvider("test")
      manager.registerProvider(mockProvider)
      
      manager.setActiveProvider("test")
      const active = manager.getActiveProvider()
      expect(active.id).toBe("test")
    })
    
    it("should throw on invalid provider", () => {
      expect(() => manager.setActiveProvider("invalid"))
        .toThrow('Provider "invalid" not registered')
    })
  })
  
  describe("condenseIfNeeded", () => {
    it("should condense with active provider", async () => {
      const result = await manager.condenseIfNeeded(context, options)
      expect(result.error).toBeUndefined()
    })
    
    it("should handle provider errors", async () => {
      const failingProvider = createFailingProvider()
      manager.registerProvider(failingProvider)
      manager.setActiveProvider("failing")
      
      const result = await manager.condenseIfNeeded(context, options)
      expect(result.error).toBeDefined()
    })
  })
  
  describe("threshold calculation", () => {
    it("should use global threshold by default", () => {
      const threshold = manager.calculateEffectiveThreshold({
        ...options,
        autoCondenseContextPercent: 75,
        profileThresholds: {}
      })
      expect(threshold).toBe(75)
    })
    
    it("should use profile threshold when set", () => {
      const threshold = manager.calculateEffectiveThreshold({
        ...options,
        autoCondenseContextPercent: 75,
        profileThresholds: { "custom": 85 },
        currentProfileId: "custom"
      })
      expect(threshold).toBe(85)
    })
    
    it("should inherit when profile threshold is -1", () => {
      const threshold = manager.calculateEffectiveThreshold({
        ...options,
        autoCondenseContextPercent: 75,
        profileThresholds: { "custom": -1 },
        currentProfileId: "custom"
      })
      expect(threshold).toBe(75)
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"provider manager orchestration threshold fallback strategy"`

**Taille estimée** : 250 lignes code + 200 lignes tests = **450 lignes**

**Dépendances** : Commits 1-3

**Validation** :
- [ ] Manager orchestre correctement les providers
- [ ] Sélection et enregistrement fonctionnent
- [ ] Calcul de threshold par profil correct
- [ ] Tests de fallback préparés (implémentation commit 8)

---

#### **Commit 5 : Integration in sliding-window**

**Fichiers modifiés** :
- `src/core/sliding-window/index.ts` (modification ~15 lignes, ligne 145-165)
- `src/core/sliding-window/__tests__/sliding-window.spec.ts` (ajout 50 lignes tests)

**Contenu** :

```typescript
// sliding-window/index.ts - Modification minimale

import { condensationManager } from "../condense/provider-manager"

// ... code existant ...

export async function truncateConversationIfNeeded({
  // ... params existants ...
}: TruncateOptions): Promise<TruncateResponse> {
  let error: string | undefined
  let cost = 0
  
  // ... code token calculation existant (lignes 106-143) ...
  
  if (autoCondenseContext) {
    const contextPercent = (100 * prevContextTokens) / contextWindow
    if (contextPercent >= effectiveThreshold || prevContextTokens > allowedTokens) {
      // ✅ NOUVELLE INTÉGRATION : Via manager au lieu d'appel direct
      const condensationContext = {
        messages,
        prevContextTokens,
        contextWindow,
        systemPrompt,
        taskId
      }
      
      const condensationOptions = {
        apiHandler,
        autoCondenseContextPercent,
        customCondensingPrompt,
        condensingApiHandler,
        profileThresholds,
        currentProfileId,
        allowedTokens
      }
      
      const result = await condensationManager.condenseIfNeeded(
        condensationContext,
        condensationOptions
      )
      
      if (result.error) {
        error = result.error
        cost = result.cost
      } else {
        return { ...result, prevContextTokens }
      }
    }
  }
  
  // ... reste du code fallback sliding window identique (lignes 167-175) ...
}
```

**Tests** (`sliding-window/__tests__/sliding-window.spec.ts` - ajouts) :
```typescript
describe("truncateConversationIfNeeded - Provider Integration", () => {
  it("should use condensation manager when autoCondenseContext is true", async () => {
    const spy = vitest.spyOn(condensationManager, 'condenseIfNeeded')
    
    await truncateConversationIfNeeded({
      messages,
      totalTokens: 150000,
      contextWindow: 200000,
      apiHandler: mockApiHandler,
      autoCondenseContext: true,
      autoCondenseContextPercent: 75,
      systemPrompt: "test",
      taskId: "task-123",
      profileThresholds: {},
      currentProfileId: "default"
    })
    
    expect(spy).toHaveBeenCalledTimes(1)
  })
  
  it("should preserve backward compatibility with current behavior", async () => {
    // Test that native provider produces identical results to old system
    const oldResult = await truncateConversationOld(...)
    const newResult = await truncateConversationIfNeeded(...)
    
    expect(newResult.messages).toEqual(oldResult.messages)
    expect(newResult.cost).toEqual(oldResult.cost)
  })
  
  it("should handle condensation errors gracefully", async () => {
    // Inject failing provider to test error handling
    vitest.spyOn(condensationManager, 'condenseIfNeeded')
      .mockResolvedValue({
        messages,
        summary: "",
        cost: 0,
        prevContextTokens: 150000,
        error: "Test error"
      })
    
    const result = await truncateConversationIfNeeded(...)
    expect(result.error).toBe("Test error")
  })
})
```

**Checkpoint SDDD** : Recherche `"sliding window integration condensation manager provider system"`

**Taille estimée** : 15 lignes modifiées + 50 lignes tests = **65 lignes**

**Dépendances** : Commits 1-4

**Validation** :
- [ ] Intégration compile sans erreur
- [ ] Tests de backward compatibility passent
- [ ] Aucune régression dans tests sliding-window existants
- [ ] Condensation fonctionne via manager

---

#### **Commit 6 : Settings Integration**

**Fichiers modifiés** :
- `src/shared/ExtensionMessage.ts` (ajout type setting)
- `src/core/webview/ClineProvider.ts` (ajout state management)
- `src/core/webview/webviewMessageHandler.ts` (ajout handler)

**Fichiers créés** :
- Tests associés

**Contenu** :

```typescript
// shared/ExtensionMessage.ts - Ajout setting

export type ExtensionSettings = {
  // ... settings existants ...
  condensationProvider?: "native" | "lossless" | "truncation" | "smart"
}

// core/webview/ClineProvider.ts - State management

async postStateToWebview() {
  // ... code existant ...
  condensationProvider: getGlobalState("condensationProvider") ?? "native",
  // ...
}

// core/webview/webviewMessageHandler.ts - Handler

case "condensationProvider":
  await updateGlobalState("condensationProvider", message.value)
  
  // Update active provider in manager
  condensationManager.setActiveProvider(message.value)
  
  await provider.postStateToWebview()
  break
```

**Tests** :
```typescript
describe("Condensation Provider Settings", () => {
  it("should save provider selection", async () => {
    await messageHandler({ 
      type: "condensationProvider", 
      value: "native" 
    })
    
    expect(updateGlobalState).toHaveBeenCalledWith("condensationProvider", "native")
  })
  
  it("should update manager active provider", async () => {
    const spy = vitest.spyOn(condensationManager, 'setActiveProvider')
    
    await messageHandler({ 
      type: "condensationProvider", 
      value: "lossless" 
    })
    
    expect(spy).toHaveBeenCalledWith("lossless")
  })
})
```

**Checkpoint SDDD** : Recherche `"condensation provider settings state management webview"`

**Taille estimée** : 40 lignes code + 50 lignes tests = **90 lignes**

**Dépendances** : Commits 1-5

**Validation** :
- [ ] Setting condensationProvider ajouté
- [ ] State management fonctionne
- [ ] Manager mis à jour lors du changement
- [ ] Tests passent

---

#### **Commit 7 : UI Settings Component**

**Fichiers modifiés** :
- `webview-ui/src/components/settings/ContextManagementSettings.tsx` (ajout select)
- `webview-ui/src/i18n/locales/en/settings.json` (ajout traductions)
- `webview-ui/src/i18n/locales/fr/settings.json` (ajout traductions)

**Fichiers créés** :
- `webview-ui/src/components/settings/__tests__/CondensationProviderSelect.spec.tsx`

**Contenu** :

```tsx
// ContextManagementSettings.tsx - Ajout

<div className="mb-4">
  <label className="block font-medium mb-2">
    {t("settings:contextManagement.condensationProvider.label")}
  </label>
  <select
    value={condensationProvider ?? "native"}
    onChange={e => setCachedStateField("condensationProvider", e.target.value)}
    className="w-full p-2 border rounded"
  >
    <option value="native">
      {t("settings:contextManagement.condensationProvider.options.native")}
    </option>
    <option value="lossless">
      {t("settings:contextManagement.condensationProvider.options.lossless")}
    </option>
    <option value="truncation">
      {t("settings:contextManagement.condensationProvider.options.truncation")}
    </option>
    <option value="smart">
      {t("settings:contextManagement.condensationProvider.options.smart")}
    </option>
  </select>
  <p className="text-sm text-vscode-descriptionForeground mt-1">
    {t("settings:contextManagement.condensationProvider.description")}
  </p>
</div>
```

**Traductions** (`locales/en/settings.json`) :
```json
{
  "contextManagement": {
    "condensationProvider": {
      "label": "Condensation Strategy",
      "description": "Choose how to reduce context when it grows too large",
      "options": {
        "native": "Native (LLM-based, high quality, slow)",
        "lossless": "Lossless (Fast, free, 20-40% reduction)",
        "truncation": "Truncation (Fast, free, simple)",
        "smart": "Smart (Intelligent, configurable)"
      }
    }
  }
}
```

**Tests** :
```typescript
describe("CondensationProviderSelect", () => {
  it("should render provider options", () => {
    render(<ContextManagementSettings {...props} />)
    
    expect(screen.getByText(/Native/)).toBeInTheDocument()
    expect(screen.getByText(/Lossless/)).toBeInTheDocument()
  })
  
  it("should change provider on selection", () => {
    const mockSetCachedStateField = vitest.fn()
    render(<ContextManagementSettings 
      {...props}
      setCachedStateField={mockSetCachedStateField}
    />)
    
    const select = screen.getByRole("combobox")
    fireEvent.change(select, { target: { value: "lossless" } })
    
    expect(mockSetCachedStateField).toHaveBeenCalledWith(
      "condensationProvider", 
      "lossless"
    )
  })
})
```

**Checkpoint SDDD** : Recherche `"condensation provider ui settings select component translation"`

**Taille estimée** : 60 lignes code + 40 lignes tests = **100 lignes**

**Dépendances** : Commits 1-6

**Validation** :
- [ ] UI select affiché correctement
- [ ] Traductions en/fr présentes
- [ ] Changement de provider fonctionne
- [ ] Tests UI passent

---

#### **Commit 8 : Fallback Strategy Implementation**

**Fichiers modifiés** :
- `src/core/condense/provider-manager.ts` (ajout fallback logic)
- `src/core/condense/__tests__/provider-manager.test.ts` (tests fallback)

**Contenu** :

```typescript
// provider-manager.ts - Enhanced fallback

/**
 * Handle provider failure with intelligent fallback strategy
 */
private async handleProviderFailure(
  context: CondensationContext,
  options: CondensationOptions,
  errorMessage: string
): Promise<CondensationResult> {
  console.error(`[CondensationManager] Provider ${this.activeProviderId} failed: ${errorMessage}`)
  
  // Fallback chain: Current → Native → Lossless → Truncation
  const fallbackChain = this.determineFallbackChain()
  
  for (const providerId of fallbackChain) {
    if (providerId === this.activeProviderId) {
      continue // Skip the one that just failed
    }
    
    const provider = this.providers.get(providerId)
    if (!provider) {
      continue
    }
    
    console.log(`[CondensationManager] Attempting fallback to ${providerId}`)
    
    try {
      const result = await provider.condense(context, options)
      
      if (!result.error) {
        console.log(`[CondensationManager] Fallback to ${providerId} succeeded`)
        return result
      }
    } catch (err) {
      console.error(`[CondensationManager] Fallback to ${providerId} also failed`)
      continue
    }
  }
  
  // All fallbacks failed, return original error
  return {
    messages: context.messages,
    summary: "",
    cost: 0,
    prevContextTokens: context.prevContextTokens,
    error: `All providers failed. Original error: ${errorMessage}`
  }
}

/**
 * Determine fallback chain based on current provider
 */
private determineFallbackChain(): string[] {
  // Smart fallback logic:
  // - Smart → Native → Lossless → Truncation
  // - Native → Lossless → Truncation
  // - Lossless → Truncation
  // - Truncation → (no fallback)
  
  const chain: string[] = []
  
  switch (this.activeProviderId) {
    case "smart":
      chain.push("native", "lossless", "truncation")
      break
    case "native":
      chain.push("lossless", "truncation")
      break
    case "lossless":
      chain.push("truncation")
      break
    case "truncation":
      // No fallback for truncation
      break
  }
  
  return chain
}
```

**Tests** :
```typescript
describe("Provider Fallback Strategy", () => {
  it("should fallback from native to lossless on error", async () => {
    // Make native fail
    const nativeProvider = manager.getActiveProvider()
    vitest.spyOn(nativeProvider, 'condense').mockResolvedValue({
      ...mockResult,
      error: "Native failed"
    })
    
    // Register lossless
    const losslessProvider = createMockProvider("lossless")
    manager.registerProvider(losslessProvider)
    
    const result = await manager.condenseIfNeeded(context, options)
    
    // Should succeed with lossless
    expect(result.error).toBeUndefined()
    expect(losslessProvider.condense).toHaveBeenCalled()
  })
  
  it("should try full fallback chain", async () => {
    // All providers fail except truncation
  })
})
```

**Checkpoint SDDD** : Recherche `"provider manager fallback strategy error handling chain"`

**Taille estimée** : 80 lignes code + 100 lignes tests = **180 lignes**

**Dépendances** : Commits 1-7

**Validation** :
- [ ] Fallback logic implémentée
- [ ] Chaîne de fallback correcte
- [ ] Tests de scénarios d'erreur passent
- [ ] Logs appropriés en cas de fallback

---

### 🎯 **Checkpoint 1 : Foundation + Native Provider Validé** (Après Commit 8)

#### Tests Requis
- [ ] Tous les tests unitaires passent (>90% coverage)
- [ ] Native provider = comportement exact système actuel
- [ ] Aucune régression dans tests existants
- [ ] Performance : <10ms overhead vs système actuel
- [ ] Fallback strategy fonctionne correctement

#### SDDD Validation
**Recherche** : `"condensation provider architecture foundation native implementation"`

**Documents attendus** :
1. `types.ts` - Interfaces de base découvrables
2. `base-provider.ts` - Classe abstraite et métriques
3. `native-provider.ts` - Implémentation wrapper
4. `provider-manager.ts` - Orchestration et fallback

**Critères de découvrabilité** :
- Recherche "provider interface" → trouve ICondensationProvider
- Recherche "native provider" → trouve NativeCondensationProvider
- Recherche "manager orchestration" → trouve CondensationProviderManager

#### Déploiement via roo-code-customization
1. **Build VSIX** avec foundation + native provider
2. **Test en environnement isolé** :
   - Installer VSIX sur instance VS Code propre
   - Vérifier condensation fonctionne identique
   - Vérifier UI settings affiché
   - Tester changement de provider (seul "native" disponible)
3. **Rollback plan ready** : Garder version précédente installée

#### Métriques de Succès
- Build time : <2 minutes
- Extension size : +50KB max
- Startup time : pas d'impact
- Condensation latency : identique à avant (±5%)

#### Documentation
- **ADR** : "ADR-001: Provider Pattern for Context Condensation"
- **API Docs** : JSDoc complet sur tous les exports publics
- **User Guide** : Section "Condensation Providers" ajoutée

---

### BLOC 2 : Lossless Provider (Commits 9-13)

**Objectif** : Implémenter l'optimisation lossless (déduplication) gratuite et rapide.

---

#### **Commit 9 : File Deduplication Logic**

**Fichiers créés** :
- `src/core/condense/lossless/file-deduplication.ts` (150 lignes)
- `src/core/condense/lossless/__tests__/file-deduplication.test.ts` (120 lignes)

**Contenu** :

```typescript
// lossless/file-deduplication.ts

import { ApiMessage } from "../../task-persistence/apiMessages"
import Anthropic from "@anthropic-ai/sdk"

/**
 * Result of file deduplication analysis
 */
export interface FileDeduplicationResult {
  duplicateCount: number
  uniqueFiles: Set<string>
  tokensBeforeDedup: number
  tokensAfterDedup: number
  reductionPercent: number
}

/**
 * Identifies duplicate file content blocks in conversation messages
 */
export class FileDeduplicator {
  /**
   * Analyze messages for duplicate file content
   */
  analyzeDuplicates(messages: ApiMessage[]): FileDeduplicationResult {
    const fileContentMap = new Map<string, {
      hash: string
      content: string
      tokenEstimate: number
      occurrences: number
    }>()
    
    let tokensBeforeDedup = 0
    
    for (const message of messages) {
      if (typeof message.content === "string") {
        continue
      }
      
      for (const block of message.content) {
        if (block.type === "text") {
          const fileContent = this.extractFileContent(block.text)
          
          if (fileContent) {
            const hash = this.hashContent(fileContent.content)
            
            if (fileContentMap.has(hash)) {
              const entry = fileContentMap.get(hash)!
              entry.occurrences++
            } else {
              fileContentMap.set(hash, {
                hash,
                content: fileContent.content,
                tokenEstimate: this.estimateTokens(fileContent.content),
                occurrences: 1
              })
            }
            
            tokensBeforeDedup += this.estimateTokens(fileContent.content)
          }
        }
      }
    }
    
    // Calculate tokens after dedup (
keep first occurrence, others reference it)
    let tokensAfterDedup = 0
    const uniqueFiles = new Set<string>()
    
    for (const [hash, entry] of fileContentMap.entries()) {
      uniqueFiles.add(hash)
      // Keep one full copy, others become references
      tokensAfterDedup += entry.tokenEstimate
      
      // References cost ~10 tokens each
      if (entry.occurrences > 1) {
        tokensAfterDedup += (entry.occurrences - 1) * 10
      }
    }
    
    const reductionPercent = tokensBeforeDedup > 0
      ? ((tokensBeforeDedup - tokensAfterDedup) / tokensBeforeDedup) * 100
      : 0
    
    return {
      duplicateCount: Array.from(fileContentMap.values())
        .filter(e => e.occurrences > 1).length,
      uniqueFiles,
      tokensBeforeDedup,
      tokensAfterDedup,
      reductionPercent
    }
  }
  
  /**
   * Extract file content from read_file tool result
   */
  private extractFileContent(text: string): { path: string, content: string } | null {
    // Pattern: <read_file>...</read_file> or similar
    const filePattern = /File: (.+?)\n(.+?)(?=\n\n|$)/s
    const match = text.match(filePattern)
    
    if (match) {
      return {
        path: match[1].trim(),
        content: match[2]
      }
    }
    
    return null
  }
  
  /**
   * Simple content hashing
   */
  private hashContent(content: string): string {
    // Simple hash for duplicate detection
    let hash = 0
    for (let i = 0; i < content.length; i++) {
      hash = ((hash << 5) - hash) + content.charCodeAt(i)
      hash = hash & hash
    }
    return hash.toString(36)
  }
  
  /**
   * Rough token estimation (4 chars ≈ 1 token)
   */
  private estimateTokens(content: string): number {
    return Math.ceil(content.length / 4)
  }
  
  /**
   * Apply deduplication to messages
   */
  applyDeduplication(messages: ApiMessage[]): ApiMessage[] {
    const fileContentMap = new Map<string, string>()
    const deduplicatedMessages: ApiMessage[] = []
    
    for (const message of messages) {
      if (typeof message.content === "string") {
        deduplicatedMessages.push(message)
        continue
      }
      
      const deduplicatedBlocks: Anthropic.Messages.ContentBlockParam[] = []
      
      for (const block of message.content) {
        if (block.type === "text") {
          const fileContent = this.extractFileContent(block.text)
          
          if (fileContent) {
            const hash = this.hashContent(fileContent.content)
            
            if (fileContentMap.has(hash)) {
              // Replace with reference
              deduplicatedBlocks.push({
                type: "text",
                text: `[File: ${fileContent.path} - Content identical to previous occurrence, see ${fileContentMap.get(hash)}]`
              })
            } else {
              // Keep first occurrence
              fileContentMap.set(hash, fileContent.path)
              deduplicatedBlocks.push(block)
            }
          } else {
            deduplicatedBlocks.push(block)
          }
        } else {
          deduplicatedBlocks.push(block)
        }
      }
      
      deduplicatedMessages.push({
        ...message,
        content: deduplicatedBlocks
      })
    }
    
    return deduplicatedMessages
  }
}
```

**Tests** :
```typescript
describe("FileDeduplicator", () => {
  let deduplicator: FileDeduplicator
  
  beforeEach(() => {
    deduplicator = new FileDeduplicator()
  })
  
  describe("analyzeDuplicates", () => {
    it("should detect duplicate file content", () => {
      const messages = createMessagesWithDuplicateFiles()
      const result = deduplicator.analyzeDuplicates(messages)
      
      expect(result.duplicateCount).toBeGreaterThan(0)
      expect(result.reductionPercent).toBeGreaterThan(0)
    })
    
    it("should calculate correct reduction percentage", () => {
      const messages = createMessagesWithDuplicateFiles()
      const result = deduplicator.analyzeDuplicates(messages)
      
      expect(result.reductionPercent).toBeGreaterThan(20)
      expect(result.reductionPercent).toBeLessThan(100)
    })
  })
  
  describe("applyDeduplication", () => {
    it("should replace duplicate files with references", () => {
      const messages = createMessagesWithDuplicateFiles()
      const deduplicated = deduplicator.applyDeduplication(messages)
      
      // Check that duplicates are replaced
      const duplicateRefs = deduplicated
        .flatMap(m => typeof m.content === 'string' ? [] : m.content)
        .filter(b => b.type === 'text' && b.text.includes('Content identical'))
      
      expect(duplicateRefs.length).toBeGreaterThan(0)
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"file deduplication lossless content hash duplicate detection"`

**Taille estimée** : 150 lignes code + 120 lignes tests = **270 lignes**

**Dépendances** : Commits 1-8

**Validation** :
- [ ] Détection de duplicatas fonctionne
- [ ] Calcul de réduction correct
- [ ] Application de déduplication préserve sémantique
- [ ] Tests passent avec couverture >90%

---

#### **Commit 10 : Tool Result Consolidation**

**Fichiers créés** :
- `src/core/condense/lossless/tool-consolidation.ts` (130 lignes)
- `src/core/condense/lossless/__tests__/tool-consolidation.test.ts` (100 lignes)

**Contenu** :

```typescript
// lossless/tool-consolidation.ts

import { ApiMessage } from "../../task-persistence/apiMessages"
import Anthropic from "@anthropic-ai/sdk"

/**
 * Consolidates redundant tool results (e.g., multiple list_files of same directory)
 */
export class ToolResultConsolidator {
  /**
   * Identify consolidation opportunities
   */
  analyzeToolResults(messages: ApiMessage[]): {
    consolidatable: number
    estimatedReduction: number
  } {
    const toolCalls = this.extractToolCalls(messages)
    const duplicateTools = this.findDuplicateToolCalls(toolCalls)
    
    const consolidatable = duplicateTools.size
    const estimatedReduction = consolidatable * 0.15 // ~15% reduction per duplicate
    
    return { consolidatable, estimatedReduction }
  }
  
  /**
   * Extract all tool calls from messages
   */
  private extractToolCalls(messages: ApiMessage[]): Array<{
    messageIndex: number
    tool: string
    params: any
    result: string
  }> {
    const toolCalls: Array<any> = []
    
    for (let i = 0; i < messages.length; i++) {
      const message = messages[i]
      
      if (typeof message.content === "string") continue
      
      for (const block of message.content) {
        if (block.type === "tool_use") {
          toolCalls.push({
            messageIndex: i,
            tool: block.name,
            params: block.input,
            result: this.findToolResult(messages, i, block.id)
          })
        }
      }
    }
    
    return toolCalls
  }
  
  /**
   * Find tool result for a given tool call
   */
  private findToolResult(
    messages: ApiMessage[],
    fromIndex: number,
    toolId: string
  ): string {
    for (let i = fromIndex + 1; i < messages.length; i++) {
      const message = messages[i]
      if (typeof message.content === "string") continue
      
      for (const block of message.content) {
        if (block.type === "tool_result" && block.tool_use_id === toolId) {
          return typeof block.content === "string" 
            ? block.content 
            : JSON.stringify(block.content)
        }
      }
    }
    return ""
  }
  
  /**
   * Find duplicate tool calls (same tool + params)
   */
  private findDuplicateToolCalls(toolCalls: Array<any>): Map<string, number[]> {
    const duplicates = new Map<string, number[]>()
    
    for (let i = 0; i < toolCalls.length; i++) {
      const key = this.toolCallKey(toolCalls[i])
      
      if (!duplicates.has(key)) {
        duplicates.set(key, [])
      }
      duplicates.get(key)!.push(i)
    }
    
    // Keep only actual duplicates (>1 occurrence)
    for (const [key, indices] of duplicates.entries()) {
      if (indices.length <= 1) {
        duplicates.delete(key)
      }
    }
    
    return duplicates
  }
  
  /**
   * Generate key for tool call deduplication
   */
  private toolCallKey(toolCall: any): string {
    return `${toolCall.tool}:${JSON.stringify(toolCall.params)}`
  }
  
  /**
   * Apply consolidation to messages
   */
  applyConsolidation(messages: ApiMessage[]): ApiMessage[] {
    const toolCalls = this.extractToolCalls(messages)
    const duplicates = this.findDuplicateToolCalls(toolCalls)
    const indicesToSkip = new Set<number>()
    
    // Mark duplicate tool results to skip (keep first occurrence)
    for (const [key, indices] of duplicates.entries()) {
      for (let i = 1; i < indices.length; i++) {
        indicesToSkip.add(indices[i])
      }
    }
    
    // Filter out duplicate tool results
    const consolidated = messages.map((message, msgIndex) => {
      if (typeof message.content === "string") {
        return message
      }
      
      const filteredBlocks = message.content.filter((block, blockIndex) => {
        if (block.type === "tool_result") {
          const toolCallIndex = this.findToolCallIndex(
            toolCalls,
            msgIndex,
            block.tool_use_id
          )
          return !indicesToSkip.has(toolCallIndex)
        }
        return true
      })
      
      return {
        ...message,
        content: filteredBlocks
      }
    })
    
    return consolidated
  }
  
  private findToolCallIndex(
    toolCalls: Array<any>,
    messageIndex: number,
    toolId: string
  ): number {
    return toolCalls.findIndex(
      tc => tc.messageIndex === messageIndex && tc.toolId === toolId
    )
  }
}
```

**Tests** :
```typescript
describe("ToolResultConsolidator", () => {
  let consolidator: ToolResultConsolidator
  
  beforeEach(() => {
    consolidator = new ToolResultConsolidator()
  })
  
  describe("analyzeToolResults", () => {
    it("should identify consolidation opportunities", () => {
      const messages = createMessagesWithDuplicateToolCalls()
      const analysis = consolidator.analyzeToolResults(messages)
      
      expect(analysis.consolidatable).toBeGreaterThan(0)
      expect(analysis.estimatedReduction).toBeGreaterThan(0)
    })
  })
  
  describe("applyConsolidation", () => {
    it("should remove duplicate tool results", () => {
      const messages = createMessagesWithDuplicateToolCalls()
      const consolidated = consolidator.applyConsolidation(messages)
      
      const toolResultCount = (msgs: ApiMessage[]) => 
        msgs.flatMap(m => typeof m.content === 'string' ? [] : m.content)
          .filter(b => b.type === 'tool_result').length
      
      expect(toolResultCount(consolidated)).toBeLessThan(toolResultCount(messages))
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"tool result consolidation lossless duplicate detection"`

**Taille estimée** : 130 lignes code + 100 lignes tests = **230 lignes**

**Dépendances** : Commits 1-9

**Validation** :
- [ ] Consolidation de tool results fonctionne
- [ ] Détection de duplicatas correcte
- [ ] Première occurrence préservée
- [ ] Tests passent

---

#### **Commit 11 : Lossless Provider Implementation**

**Fichiers créés** :
- `src/core/condense/providers/lossless-provider.ts` (200 lignes)
- `src/core/condense/providers/__tests__/lossless-provider.test.ts` (180 lignes)

**Contenu** :

```typescript
// providers/lossless-provider.ts

import { BaseCondensationProvider } from "../base-provider"
import { FileDeduplicator } from "../lossless/file-deduplication"
import { ToolResultConsolidator } from "../lossless/tool-consolidation"
import { CondensationContext, CondensationOptions, CondensationResult,
         ProviderCapabilities } from "../types"

/**
 * Lossless Provider - Zero-cost optimization through deduplication.
 * 
 * This provider reduces context size without any information loss by:
 * 1. Deduplicating file content read multiple times
 * 2. Consolidating redundant tool results
 * 
 * Characteristics:
 * - No LLM calls (completely free)
 * - Very fast (<100ms typically)
 * - 20-40% token reduction in typical scenarios
 * - Zero information loss
 * - Can be combined with other providers
 */
export class LosslessCondensationProvider extends BaseCondensationProvider {
  readonly id = "lossless"
  readonly name = "Lossless (Deduplication)"
  readonly description = "Fast, free optimization through deduplication (no information loss)"
  
  private fileDeduplicator = new FileDeduplicator()
  private toolConsolidator = new ToolResultConsolidator()
  
  /**
   * Apply lossless optimizations
   */
  async condense(
    context: CondensationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const startTime = Date.now()
    
    try {
      // 1. Analyze potential optimizations
      const fileAnalysis = this.fileDeduplicator.analyzeDuplicates(context.messages)
      const toolAnalysis = this.toolConsolidator.analyzeToolResults(context.messages)
      
      // 2. Apply deduplication
      let optimizedMessages = this.fileDeduplicator.applyDeduplication(context.messages)
      
      // 3. Apply tool consolidation
      optimizedMessages = this.toolConsolidator.applyConsolidation(optimizedMessages)
      
      // 4. Count tokens in optimized messages
      const newContextTokens = await this.countTokens(
        optimizedMessages,
        options.apiHandler
      )
      
      // 5. Calculate actual reduction
      const tokensReduced = context.prevContextTokens - newContextTokens
      const reductionPercent = (tokensReduced / context.prevContextTokens) * 100
      
      const result: CondensationResult = {
        messages: optimizedMessages,
        summary: this.generateSummary(fileAnalysis, toolAnalysis, reductionPercent),
        cost: 0, // Completely free!
        newContextTokens,
        prevContextTokens: context.prevContextTokens
      }
      
      this.trackMetrics(startTime, result, context)
      this.logCondensation(context, result)
      
      return result
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      const result: CondensationResult = {
        messages: context.messages,
        summary: "",
        cost: 0,
        prevContextTokens: context.prevContextTokens,
        error: `Lossless provider error: ${errorMessage}`
      }
      
      this.trackMetrics(startTime, result, context)
      return result
    }
  }
  
  /**
   * Generate summary of optimizations applied
   */
  private generateSummary(
    fileAnalysis: any,
    toolAnalysis: any,
    reductionPercent: number
  ): string {
    return `Lossless optimization applied:
- Deduplicated ${fileAnalysis.duplicateCount} duplicate files
- Consolidated ${toolAnalysis.consolidatable} tool results
- Total reduction: ${reductionPercent.toFixed(1)}%
- Zero information loss`
  }
  
  /**
   * Count tokens in messages
   */
  private async countTokens(
    messages: ApiMessage[],
    apiHandler: ApiHandler
  ): Promise<number> {
    const blocks = messages.flatMap(m =>
      typeof m.content === "string"
        ? [{ type: "text" as const, text: m.content }]
        : m.content
    )
    return await apiHandler.countTokens(blocks)
  }
  
  /**
   * Lossless is free
   */
  estimateCost(
    context: CondensationContext,
    options: CondensationOptions
  ): number {
    return 0
  }
  
  /**
   * Estimate reduction based on analysis
   */
  estimateReduction(context: CondensationContext): number {
    const fileAnalysis = this.fileDeduplicator.analyzeDuplicates(context.messages)
    const toolAnalysis = this.toolConsolidator.analyzeToolResults(context.messages)
    
    // Combine estimated reductions
    const fileReduction = fileAnalysis.reductionPercent / 100
    const toolReduction = toolAnalysis.estimatedReduction
    
    return Math.min(fileReduction + toolReduction, 0.5) // Cap at 50%
  }
  
  /**
   * Get capabilities
   */
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLLM: false,
      supportsLossless: true,
      supportsTruncation: false,
      supportsMultiPass: false,
      isFree: true,
      estimatedSpeed: "fast"
    }
  }
}
```

**Tests** :
```typescript
describe("LosslessCondensationProvider", () => {
  let provider: LosslessCondensationProvider
  
  beforeEach(() => {
    provider = new LosslessCondensationProvider()
  })
  
  describe("condense", () => {
    it("should reduce tokens without information loss", async () => {
      const context = createContextWithDuplicates()
      const result = await provider.condense(context, options)
      
      expect(result.error).toBeUndefined()
      expect(result.newContextTokens).toBeLessThan(context.prevContextTokens)
      expect(result.cost).toBe(0) // Free!
    })
    
    it("should achieve 20-40% reduction on typical conversations", async () => {
      const context = createTypicalContext()
      const result = await provider.condense(context, options)
      
      const reduction = (1 - result.newContextTokens! / context.prevContextTokens) * 100
      expect(reduction).toBeGreaterThan(20)
      expect(reduction).toBeLessThan(50)
    })
    
    it("should be very fast (<100ms)", async () => {
      const startTime = Date.now()
      await provider.condense(context, options)
      const duration = Date.now() - startTime
      
      expect(duration).toBeLessThan(100)
    })
  })
  
  describe("capabilities", () => {
    it("should report free and fast", () => {
      const caps = provider.getCapabilities()
      expect(caps.isFree).toBe(true)
      expect(caps.estimatedSpeed).toBe("fast")
      expect(caps.supportsLossless).toBe(true)
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"lossless provider deduplication free fast optimization"`

**Taille estimée** : 200 lignes code + 180 lignes tests = **380 lignes**

**Dépendances** : Commits 1-10

**Validation** :
- [ ] Lossless provider fonctionne
- [ ] Réduction de 20-40% atteinte
- [ ] Coût = $0, latence <100ms
- [ ] Aucune perte d'information
- [ ] Tests passent

---

#### **Commit 12 : Lossless Provider Registration**

**Fichiers modifiés** :
- `src/core/condense/provider-manager.ts` (ajout registration)
- `src/core/condense/__tests__/provider-manager.test.ts` (tests)

**Contenu** :

```typescript
// provider-manager.ts - Register lossless

import { LosslessCondensationProvider } from "./providers/lossless-provider"

constructor() {
  // Register providers
  this.registerProvider(new NativeCondensationProvider())
  this.registerProvider(new LosslessCondensationProvider())
}
```

**Tests** :
```typescript
it("should have lossless provider registered", () => {
  const providers = manager.getAllProviders()
  expect(providers.find(p => p.id === "lossless")).toBeDefined()
})

it("should switch to lossless provider", () => {
  manager.setActiveProvider("lossless")
  const active = manager.getActiveProvider()
  expect(active.id).toBe("lossless")
})
```

**Checkpoint SDDD** : Recherche `"lossless provider registration manager available"`

**Taille estimée** : 10 lignes code + 20 lignes tests = **30 lignes**

**Dépendances** : Commits 1-11

**Validation** :
- [ ] Lossless enregistré au démarrage
- [ ] Sélection lossless dans UI fonctionne
- [ ] Tests passent

---

#### **Commit 13 : Lossless Performance Benchmarks**

**Fichiers créés** :
- `src/core/condense/__tests__/lossless-benchmarks.test.ts` (100 lignes)

**Contenu** :

```typescript
// __tests__/lossless-benchmarks.test.ts

describe("Lossless Provider Benchmarks", () => {
  describe("performance", () => {
    it("should process 10K tokens in <50ms", async () => {
      const context = createContext(10_000)
      const startTime = performance.now()
      
      await losslessProvider.condense(context, options)
      
      const duration = performance.now() - startTime
      expect(duration).toBeLessThan(50)
    })
    
    it("should process 50K tokens in <100ms", async () => {
      const context = createContext(50_000)
      const startTime = performance.now()
      
      await losslessProvider.condense(context, options)
      
      const duration = performance.now() - startTime
      expect(duration).toBeLessThan(100)
    })
  })
  
  describe("reduction quality", () => {
    it("should achieve >20% on conversations with file rereads", async () => {
      const context = createContextWithFileRereads()
      const result = await losslessProvider.condense(context, options)
      
      const reduction = (1 - result.newContextTokens! / context.prevContextTokens) * 100
      expect(reduction).toBeGreaterThan(20)
    })
    
    it("should achieve >30% on conversations with duplicate tool calls", async () => {
      const context = createContextWithDuplicateTools()
      const result = await losslessProvider.condense(context, options)
      
      const reduction = (1 - result.newContextTokens! / context.prevContextTokens) * 100
      expect(reduction).toBeGreaterThan(30)
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"lossless performance benchmarks reduction quality metrics"`

**Taille estimée** : 100 lignes tests

**Dépendances** : Commits 1-12

**Validation** :
- [ ] Benchmarks de performance passent
- [ ] Réduction quality validée
- [ ] Métriques documentées

---

### 🎯 **Checkpoint 2 : Lossless Provider Opérationnel** (Après Commit 13)

#### Tests Requis
- [ ] Lossless provider fonctionne en standalone
- [ ] Réduction 20-40% atteinte sur cas réels
- [ ] Performance <100ms validée
- [ ] Coût = $0 vérifié
- [ ] Aucune perte d'information confirmée
- [ ] Integration avec manager testée

#### SDDD Validation
**Recherche** : `"lossless provider deduplication file consolidation tool results free fast"`

**Documents attendus** :
1. `file-deduplication.ts` - Logique de déduplication de fichiers
2. `tool-consolidation.ts` - Consolidation de tool results
3. `lossless-provider.ts` - Provider lossless complet

#### Déploiement via roo-code-customization
1. Build VSIX avec Native + Lossless
2. Test utilisateurs :
   - Conversations avec beaucoup de relectures de fichiers
   - Vérifier réduction sans perte
   - Comparer vitesse vs Native
3. Métriques attendues :
   - Lossless 20-50x plus rapide que Native
   - Réduction 20-40% sur conversations typiques
   - $0 coût

#### Documentation
- **ADR-002** : "Lossless Optimization Strategy"
- **User Guide** : Section "Lossless Provider Benefits"

---

### BLOC 3 : Truncation Provider (Commits 14-17)

**Objectif** : Alternative rapide et gratuite (sliding window)

---

#### **Commit 14 : Truncation Provider Implementation**

**Fichiers créés** :
- `src/core/condense/providers/truncation-provider.ts` (150 lignes)
- `src/core/condense/providers/__tests__/truncation-provider.test.ts` (120 lignes)

**Contenu** :

```typescript
// providers/truncation-provider.ts

import { BaseCondensationProvider } from "../base-provider"
import { truncateConversation } from "../../sliding-window"
import { CondensationContext, CondensationOptions, CondensationResult,
         ProviderCapabilities } from "../types"

/**
 * Truncation Provider - Simple sliding window truncation.
 * 
 * Wraps the existing truncateConversation function, providing a simple
 * chronological truncation when:
 * - Budget is very tight
 * - Speed is critical
 * - Semantic meaning is less important
 * 
 * Characteristics:
 * - No LLM calls (completely free)
 * - Extremely fast (<10ms)
 * - Simple chronological removal
 * - Information loss (older messages removed)
 * - Last resort fallback
 */
export class TruncationCondensationProvider extends BaseCondensationProvider {
  readonly id = "truncation"
  readonly name = "Truncation (Sliding Window)"
  readonly description = "Fast, free, simple chronological truncation"
  
  async condense(
    context: CondensationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const startTime = Date.now()
    
    try {
      // Use existing truncation logic
      const truncatedMessages = truncateConversation(
        context.messages,
        0.5, // Remove 50% of messages (excluding first)
        context.taskId
      )
      
      // Count tokens
      const newContextTokens = await this.countTokens(
        truncatedMessages,
        options.apiHandler
      )
      
      const result: CondensationResult = {
        messages: truncatedMessages,
        summary: `Truncated conversation: removed ${
          context.messages.length - truncatedMessages.length
        } messages (chronological)`,
        cost: 0,
        newContextTokens,
        prevContextTokens: context.prevContextTokens
      }
      
      this.trackMetrics(startTime, result, context)
      this.logCondensation(context, result)
      
      return result
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      return {
        messages: context.messages,
        summary: "",
        cost: 0,
        prevContextTokens: context.prevContextTokens,
        error: `Truncation provider error: ${errorMessage}`
      }
    }
  }
  
  private async countTokens(
    messages: ApiMessage[],
    apiHandler: ApiHandler
  ): Promise<number> {
    const blocks = messages.flatMap(m =>
      typeof m.content === "string"
        ? [{ type: "text" as const, text: m.content }]
        : m.content
    )
    return await apiHandler.countTokens(blocks)
  }
  
  estimateCost(): number {
    return 0
  }
  
  estimateReduction(): number {
    return 0.5 // Removes ~50% of messages
  }
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLLM: false,
      supportsLossless: false,
      supportsTruncation: true,
      supportsMultiPass: false,
      isFree: true,
      estimatedSpeed: "fast"
    }
  }
}
```

**Tests** :
```typescript
describe("TruncationCondensationProvider", () => {
  it("should remove ~50% of messages", async () => {
    const result = await provider.condense(context, options)
    
    const removalPercent = (1 - result.messages.length / context.messages.length) * 100
    expect(removalPercent).toBeGreaterThan(40)
    expect(removalPercent).toBeLessThan(60)
  })
  
  it("should be extremely fast (<10ms)", async () => {
    const startTime = performance.now()
    await provider.condense(context, options)
    const duration = performance.now() - startTime
    
    expect(duration).toBeLessThan(10)
  })
  
  it("should preserve first message", async () => {
    const result = await provider.condense(context, options)
    expect(result.messages[0]).toEqual(context.messages[0])
  })
})
```

**Checkpoint SDDD** : Recherche `"truncation provider sliding window fast free simple"`

**Taille estimée** : 150 lignes code + 120 lignes tests = **270 lignes**

**Dépendances** : Commits 1-13

**Validation** :
- [ ] Truncation provider fonctionne
- [ ] Wrap de truncateConversation correct
- [ ] Latence <10ms
- [ ] Tests passent

---

#### **Commit 15 : Truncation Provider Registration**

**Fichiers modifiés** :
- `src/core/condense/provider-manager.ts`
- Tests

**Contenu** : Registration identique aux providers précédents

**Checkpoint SDDD** : Recherche `"truncation provider registered available selection"`

**Taille estimée** : 10 lignes code + 20 lignes tests = **30 lignes**

**Validation** :
- [ ] Truncation disponible dans UI
- [ ] Sélection fonctionne

---

#### **Commit 16 : Enhanced Fallback Chain**

**Fichiers modifiés** :
- `src/core/condense/provider-manager.ts` (amélioration fallback)

**Contenu** :

```typescript
// Mise à jour fallback chain avec truncation

private determineFallbackChain(): string[] {
  const chain: string[] = []
  
  switch (this.activeProviderId) {
    case "smart":
      chain.push("native", "lossless", "truncation")
      break
    case "native":
      chain.push("lossless", "truncation")
      break
    case "lossless":
      chain.push("truncation") // Truncation as last resort
      break
    case "truncation":
      // No fallback - truncation always works
      break
  }
  
  return chain
}
```

**Checkpoint SDDD** : Recherche `"enhanced fallback chain truncation last resort"`

**Taille estimée** : 20 lignes code + 40 lignes tests = **60 lignes**

**Validation** :
- [ ] Fallback jusqu'à truncation fonctionne
- [ ] Truncation comme dernier recours
- [ ] Tests de fallback complets passent

---

#### **Commit 17 : Truncation Documentation & UI**

**Fichiers modifiés** :
- UI descriptions
- Traductions
- Documentation inline

**Taille estimée** : 30 lignes

**Validation** :
- [ ] UI montre truncation comme option
- [ ] Description claire des trade-offs

---

### 🎯 **Checkpoint 3 : Truncation Provider Disponible** (Après Commit 17)

#### Tests Requis
- [ ] Truncation provider fonctionne
- [ ] Fallback chain complète testée
- [ ] Performance <10ms validée
- [ ] UI montre 3 providers : native, lossless, truncation

#### SDDD Validation
**Recherche** : `"truncation provider sliding window fallback last resort free fast"`

#### Déploiement
Build VSIX avec 3 providers, test fallback automatique

---

### BLOC 4 : Smart Provider (Commits 18-25)

**Objectif** : Provider intelligent multi-passes avec presets simples

---

#### **Commit 18 : Pass System Types**

**Fichiers créés** :
- `src/core/condense/smart/pass-types.ts` (120 lignes)
- `src/core/condense/smart/__tests__/pass-types.test.ts` (80 lignes)

**Contenu** :

```typescript
// smart/pass-types.ts

/**
 * Content types that can be processed in passes
 */
export enum ContentType {
  MESSAGE_TEXT = "message_text",
  TOOL_PARAMS = "tool_params",
  TOOL_RESULTS = "tool_results"
}

/**
 * Operations that can be applied to content
 */
export enum PassOperation {
  KEEP = "keep",           // Keep as-is
  SUPPRESS = "suppress",   // Remove completely
  TRUNCATE = "truncate",   // Shorten (prefix + suffix)
  SUMMARIZE = "summarize"  // LLM summarization
}

/**
 * Configuration for a single pass
 */
export interface PassConfig {
  name: string
  description: string
  contentTypes: ContentType[]
  operation: PassOperation
  options: PassOptions
}

/**
 * Options for pass operations
 */
export interface PassOptions {
  // For truncate operation
  maxLength?: number
  keepPrefix?: number
  keepSuffix?: number
  
  // For summarize operation
  customPrompt?: string
  targetReduction?: number
  
  // Execution conditions
  executeIf?: (context: any) => boolean
}

/**
 * Preset configurations for Smart Provider
 */
export interface SmartPreset {
  id: string
  name: string
  description: string
  passes: PassConfig[]
}

/**
 * Predefined presets
 */
export const SMART_PRESETS: Record<string, SmartPreset> = {
  quality: {
    id: "quality",
    name: "Quality (Minimal Loss)",
    description: "Prioritize information preservation",
    passes: [
      {
        name: "Lossless Phase",
        description: "Deduplication without loss",
        contentTypes: [ContentType.MESSAGE_TEXT, ContentType.TOOL_RESULTS],
        operation: PassOperation.KEEP, // Will use lossless provider
        options: {}
      },
      {
        name: "Selective Summarization",
        description: "Summarize only tool results",
        contentTypes: [ContentType.TOOL_RESULTS],
        operation: PassOperation.SUMMARIZE,
        options: {
          customPrompt: "Summarize tool output concisely",
          targetReduction: 0.3
        }
      }
    ]
  },
  
  balanced: {
    id: "balanced",
    name: "Balanced (Moderate Reduction)",
    description: "Balance quality and token reduction",
    passes: [
      {
        name: "Lossless Phase",
        description: "Deduplication",
        contentTypes: [ContentType.MESSAGE_TEXT, ContentType.TOOL_RESULTS],
        operation: PassOperation.KEEP,
        options: {}
      },
      {
        name: "Truncate Tool Results",
        description: "Shorten long tool outputs",
        contentTypes: [ContentType.TOOL_RESULTS],
        operation: PassOperation.TRUNCATE,
        options: {
          maxLength: 1000,
          keepPrefix: 300,
          keepSuffix: 200
        }
      },
      {
        name: "Summarize Old Messages",
        description: "Summarize messages >10 turns old",
        contentTypes: [ContentType.MESSAGE_TEXT],
        operation: PassOperation.SUMMARIZE,
        options: {
          targetReduction: 0.5,
          executeIf: (ctx) => ctx.messageAge > 10
        }
      }
    ]
  },
  
  aggressive: {
    id: "aggressive",
    name: "Aggressive (Maximum Reduction)",
    description: "Maximize token reduction",
    passes: [
      {
        name: "Suppress Tool Params",
        description: "Remove redundant tool parameters",
        contentTypes: [ContentType.TOOL_PARAMS],
        operation: PassOperation.SUPPRESS,
        options: {}
      },
      {
        name: "Truncate Tool Results",
        description: "Aggressively shorten outputs",
        contentTypes: [ContentType.TOOL_RESULTS],
        operation: PassOperation.TRUNCATE,
        options: {
          maxLength: 500,
          keepPrefix: 200,
          keepSuffix: 100
        }
      },
      {
        name: "Summarize All Messages",
        description: "Summarize most conversation",
        contentTypes: [ContentType.MESSAGE_TEXT],
        operation: PassOperation.SUMMARIZE,
        options: {
          targetReduction: 0.7
        }
      }
    ]
  }
}
```

**Tests** :
```typescript
describe("Smart Presets", () => {
  it("should have 3 predefined presets", () => {
    expect(Object.keys(SMART_PRESETS)).toHaveLength(3)
  })
  
  it("quality preset should have lossless + selective summarization", () => {
    const preset = SMART_PRESETS.quality
    expect(preset.passes).toHaveLength(2)
    expect(preset.passes[0].operation).toBe(PassOperation.KEEP)
  })
  
  it("aggressive preset should maximize reduction", () => {
    const preset = SMART_PRESETS.aggressive
    expect(preset.passes.some(p => p.operation === PassOperation.SUPPRESS)).toBe(true)
  })
})
```

**Checkpoint SDDD** : Recherche `"smart provider pass system types presets configuration"`

**Taille estimée** : 120 lignes code + 80 lignes tests = **200 lignes**

**Dépendances** : Commits 1-17

**Validation** :
- [ ] Types de pass définis
- [ ] 3 presets créés (quality, balanced, aggressive)
- [ ] Structure extensible pour ajout de passes
- [ ] Tests passent

---

#### **Commit 19 : Content Type Model**

**Fichiers créés** :
- `src/core/condense/smart/content-model.ts` (150 lignes)
- Tests

**Contenu** :

```typescript
// smart/content-model.ts

import { ApiMessage } from "../../task-persistence/apiMessages"
import { ContentType } from "./pass-types"

/**
 * Classified content block
 */
export interface ClassifiedContent {
  type: ContentType
  messageIndex: number
  blockIndex: number
  content: any
  estimatedTokens: number
  metadata: {
    toolName?: string
    isOld?: boolean
    age?: number
  }
}

/**
 * Decomposes messages into typed content blocks
 */
export class ContentClassifier {
  /**
   * Classify all content in messages
   */
  classify(messages: ApiMessage[]): ClassifiedContent[] {
    const classified: ClassifiedContent[] = []
    
    for (let msgIdx = 0; msgIdx < messages.length; msgIdx++) {
      const message = messages[msgIdx]
      
      if (typeof message.content === "string") {
        classified.push({
          type: ContentType.MESSAGE_TEXT,
          messageIndex: msgIdx,
          blockIndex: 0,
          content: message.content,
          estimatedTokens: this.estimateTokens(message.content),
          metadata: {
            age: messages.length - msgIdx
          }
        })
      } else {
        for (let blockIdx = 0; blockIdx < message.content.length; blockIdx++) {
          const block = message.content[blockIdx]
          
          if (block.type === "text") {
            classified.push({
              type: ContentType.MESSAGE_TEXT,
              messageIndex: msgIdx,
              blockIndex: blockIdx,
              content: block.text,
              estimatedTokens: this.estimateTokens(block.text),
              metadata: {
                age: messages.length - msgIdx
              }
            })
          } else if (block.type === "tool_use") {
            classified.push({
              type: ContentType.TOOL_PARAMS,
              messageIndex: msgIdx,
              blockIndex: blockIdx,
              content: block.input,
              estimatedTokens: this.estimateTokens(JSON.stringify(block.input)),
              metadata: {
                toolName: block.name
              }
            })
          } else if (block.type === "tool_result") {
            const resultContent = typeof block.content === "string"
              ? block.content
              : JSON.stringify(block.content)
            
            classified.push({
              type: ContentType.TOOL_RESULTS,
              messageIndex: msgIdx,
              blockIndex: blockIdx,
              content: resultContent,
              estimatedTokens: this.estimateTokens(resultContent),
              metadata: {
                toolName: "unknown" // Could lookup from tool_use
              }
            })
          }
        }
      }
    }
    
    return classified
  }
  
  /**
   * Rebuild messages from classified content
   */
  rebuild(classified: ClassifiedContent[], originalMessages: ApiMessage[]): ApiMessage[] {
    // Group by message index
    const byMessage = new Map<number, ClassifiedContent[]>()
    
    for (const item of classified) {
      if (!byMessage.has(item.messageIndex)) {
        byMessage.set(item.messageIndex, [])
      }
      byMessage.get(item.messageIndex)!.push(item)
    }
    
    // Rebuild messages
    const rebuilt: ApiMessage[] = []
    
    for (let idx = 0; idx < originalMessages.length; idx++) {
      const original = originalMessages[idx]
      const items = byMessage.get(idx)
      
      if (!items || items.length === 0) {
        // Message was completely removed
        continue
      }
      
      if (items.length === 1 && items[0].type === ContentType.MESSAGE_TEXT) {
        // Simple text message
        rebuilt.push({
          ...original,
          content: items[0].content
        })
      } else {
        // Complex message with blocks
        const blocks = items.map(item => {
          if (item.type === ContentType.MESSAGE_TEXT) {
            return { type: "text" as const, text: item.content }
          } else if (item.type === ContentType.TOOL_PARAMS) {
            return { 
              type: "tool_use" as const, 
              id: crypto.randomUUID(),
              name: item.metadata.toolName!,
              input: item.content
            }
          } else {
            return {
              type: "tool_result" as const,
              tool_use_id: crypto.randomUUID(),
              content: item.content
            }
          }
        })
        
        rebuilt.push({
          ...original,
          content: blocks
        })
      }
    }
    
    return rebuilt
  }
  
  private estimateTokens(text: string): number {
    return Math.ceil(text.length / 4)
  }
}
```

**Checkpoint SDDD** : Recherche `"content classifier decomposition message text tool params results"`

**Taille estimée** : 150 lignes code + 100 lignes tests = **250 lignes**

**Validation** :
- [ ] Classification des 3 types de contenu
- [ ] Reconstruction correcte des messages
- [ ] Tests de round-trip passent

---

#### **Commit 20 : Pass Executor Engine**

**Fichiers créés** :
- `src/core/condense/smart/pass-executor.ts` (200 lignes)
- Tests (150 lignes)

**Contenu** :

```typescript
// smart/pass-executor.ts

import { PassConfig, PassOperation, ContentType } from "./pass-types"
import { ClassifiedContent } from "./content-model"

/**
 * Executes pass operations on classified content
 */
export class PassExecutor {
  /**
   * Execute a single pass
   */
  async executePass(
    pass: PassConfig,
    content: ClassifiedContent[],
    context: any
  ): Promise<ClassifiedContent[]> {
    // Filter content matching this pass's types
    const matching = content.filter(c => 
      pass.contentTypes.includes(c.type)
    )
    
    const nonMatching = content.filter(c =>
      !pass.contentTypes.includes(c.type)
    )
    
    // Apply operation
    let processed: ClassifiedContent[]
    
    switch (pass.operation) {
      case PassOperation.KEEP:
        processed = matching
        break
      
      case PassOperation.SUPPRESS:
        processed = [] // Remove all matching
        break
      
      case PassOperation.TRUNCATE:
        processed = this.applyTruncation(matching, pass.options)
        break
      
      case PassOperation.SUMMARIZE:
        processed = await this.applySummarization(matching, pass.options, context)
        break
      
      default:
        processed = matching
    }
    
    // Merge back with non-matching content
    return [...nonMatching, ...processed].sort((a, b) =>
      a.messageIndex === b.messageIndex
        ? a.blockIndex - b.blockIndex
        : a.messageIndex - b.messageIndex
    )
  }
  
  /**
   * Apply truncation to content
   */
  private applyTruncation(
    content: ClassifiedContent[],
    options: any
  ): ClassifiedContent[] {
    const { maxLength, keepPrefix, keepSuffix } = options
    
    return content.map(item => {
      const text = String(item.content)
      
      if (text.length <= maxLength) {
        return item
      }
      
      const prefix = text.substring(0, keepPrefix)
      const suffix = text.substring(text.length - keepSuffix)
      const truncated = `${prefix}\n... [truncated ${text.length - maxLength} chars] ...\n${suffix}`
      
      return {
        ...item,
        content: truncated,
        estimatedTokens: Math.ceil(truncated.length / 4)
      }
    })
  }
  
  /**
   * Apply LLM summarization
   */
  private async applySummarization(
    content: ClassifiedContent[],
    options: any,
    context: any
  ): Promise<ClassifiedContent[]> {
    // For MVP: simple truncation as placeholder
    // Real LLM summarization in later phase
    return this.applyTruncation(content, {
      maxLength: 1000,
      keepPrefix: 300,
      keepSuffix: 200
    })
  }
}
```

**Checkpoint SDDD** : Recherche `"pass executor engine operations truncate summarize keep suppress"`

**Taille estimée** : 200 lignes code + 150 lignes tests = **350 lignes**

**Validation** :
- [ ] Exécution des 4 opérations
- [ ] Truncation fonctionne correctement
- [ ] Summarization (placeholder pour MVP)
- [ ] Tests passent

---

#### **Commit 21 : Smart Provider Core**

**Fichiers créés** :
- `src/core/condense/providers/smart-provider.ts` (250 lignes)
- Tests (200 lignes)

**Contenu** :

```typescript
// providers/smart-provider.ts

import { BaseCondensationProvider } from "../base-provider"
import { ContentClassifier } from "../smart/content-model"
import { PassExecutor } from "../smart/pass-executor"
import { SMART_PRESETS } from "../smart/pass-types"
import { CondensationContext, CondensationOptions, CondensationResult,
         ProviderCapabilities } from "../types"

/**
 * Smart Provider - Multi-pass intelligent condensation.
 * 
 * Uses a pass-based architecture to apply different operations to
 * different content types. Supports presets for easy configuration.
 * 
 * MVP Implementation:
 * - 3 presets: quality, balanced, aggressive
 * - Simple UI: dropdown selection
 * - Extensible for future advanced configuration
 */
export class SmartCondensationProvider extends BaseCondensationProvider {
  readonly id = "smart"
  readonly name = "Smart (Multi-pass)"
  readonly description = "Intelligent multi-pass condensation with presets"
  
  private classifier = new ContentClassifier()
  private executor = new PassExecutor()
  private activePreset: string = "balanced"
  
  /**
   * Set active preset
   */
  setPreset(presetId: string): void {
    if (!SMART_PRESETS[presetId]) {
      throw new Error(`Unknown preset: ${presetId}`)
    }
    this.activePreset = presetId
  }
  
  /**
   * Multi-pass condensation
   */
  async condense(
    context: CondensationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const startTime = Date.now()
    
    try {
      const preset = SMART_PRESETS[this.activePreset]
      
      // 1. Classify content
      let classified = this.classifier.classify(context.messages)
      
      // 2. Execute passes sequentially
      for (const pass of preset.passes) {
        classified = await this.executor.executePass(
          pass,
          classified,
          {
            context,
            options
          }
        )
      }
      
      // 3. Rebuild messages
      const condensedMessages = this.classifier.rebuild(
        classified,
        context.messages
      )
      
      // 4. Count tokens
      const newContextTokens = await this.countTokens(
        condensedMessages,
        options.apiHandler
      )
      
      const result: CondensationResult = {
        messages: condensedMessages,
        summary: `Smart condensation (${preset.name}): ${preset.passes.length} passes applied`,
        cost: 0, // MVP: no LLM calls yet
        newContextTokens,
        prevContextTokens: context.prevContextTokens
      }
      
      this.trackMetrics(startTime, result, context)
      this.logCondensation(context, result)
      
      return result
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      return {
        messages: context.messages,
        summary: "",
        cost: 0,
        prevContextTokens: context.prevContextTokens,
        error: `Smart provider error: ${errorMessage}`
      }
    }
  }
  
  private async countTokens(
    messages: ApiMessage[],
    apiHandler: ApiHandler
  ): Promise<number> {
    const blocks = messages.flatMap(m =>
      typeof m.content === "string"
        ? [{ type: "text" as const, text: m.content }]
        : m.content
    )
    return await apiHandler.countTokens(blocks)
  }
  
  estimateCost(): number {
    // MVP: no LLM, free
    return 0
  }
  
  estimateReduction(): number {
    const preset = SMART_PRESETS[this.activePreset]
    // Rough estimate based on preset
    return preset.id === "aggressive" ? 0.6 : preset.id === "quality" ? 0.3 : 0.45
  }
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLLM: true,
      supportsLossless: true,
      supportsTruncation: true,
      supportsMultiPass: true,
      isFree: true, // MVP version is free
      estimatedSpeed: "medium"
    }
  }
}
```

**Tests** :
```typescript
describe("SmartCondensationProvider", () => {
  describe("presets", () => {
    it("should support 3 presets", () => {
      provider.setPreset("quality")
      provider.setPreset("balanced")
      provider.setPreset("aggressive")
      // No errors
    })
    
    it("should reject invalid preset", () => {
      expect(() => provider.setPreset("invalid"))
        .toThrow("Unknown preset")
    })
  })
  
  describe("condensation", () => {
    it("should execute all passes in preset", async () => {
      provider.setPreset("balanced")
      const result = await provider.condense(context, options)
      
      expect(result.error).toBeUndefined()
      expect(result.newContextTokens).toBeLessThan(context.prevContextTokens)
    })
    
    it("aggressive should reduce more than quality", async () => {
      const contextClone1 = { ...context }
      const contextClone2 = { ...context }
      
      provider.setPreset("quality")
      const qualityResult = await provider.condense(contextClone1, options)
      
      provider.setPreset("aggressive")
      const aggressiveResult = await provider.condense(contextClone2, options)
      
      expect(aggressiveResult.newContextTokens!)
        .toBeLessThan(qualityResult.newContextTokens!)
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"smart provider multi-pass preset quality balanced aggressive"`

**Taille estimée** : 250 lignes code + 200 lignes tests = **450 lignes**

**Validation** :
- [ ] Smart provider fonctionne
- [ ] 3 presets opérationnels
- [ ] Multi-passes s'exécutent séquentiellement
- [ ] Tests passent

---

#### **Commit 22 : Smart Provider Registration**

**Fichiers modifiés** :
- `src/core/condense/provider-manager.ts`

**Contenu** : Registration standard

**Taille estimée** : 10 lignes + 20 tests = **30 lignes**

---

#### **Commit 23 : Smart Preset UI Selection**

**Fichiers modifiés** :
- `webview-ui/src/components/settings/ContextManagementSettings.tsx`
- `src/shared/ExtensionMessage.ts`

**Contenu** :

```tsx
{condensationProvider === "smart" && (
  <div className="ml-4 mt-2">
    <label className="block font-medium mb-2">
      Smart Preset
    </label>
    <select
      value={condensationSmartPreset ?? "balanced"}
      onChange={e => setCachedStateField("condensationSmartPreset", e.target.value)}
      className="w-full p-2 border rounded"
    >
      <option value="quality">Quality (Minimal Loss)</option>
      <option value="balanced">Balanced (Moderate)</option>
      <option value="aggressive">Aggressive (Max Reduction)</option>
    </select>
  </div>
)}
```

**Checkpoint SDDD** : Recherche `"smart preset ui selection quality balanced aggressive dropdown"`

**Taille estimée** : 40 lignes code + 50 lignes tests = **90 lignes**

**Validation** :
- [ ] UI montre preset selector quand smart sélectionné
- [ ] Changement de preset fonctionne
- [ ] Tests UI passent

---

#### **Commit 24 : Lossless Integration in Smart**

**Fichiers modifiés** :
- `src/core/condense/providers/smart-provider.ts`

**Contenu** :

```typescript
// Dans executePass, pour operation KEEP :
case PassOperation.KEEP:
  // Use lossless provider for this pass
  if (pass.name === "Lossless Phase") {
    const losslessProvider = new LosslessCondensationProvider()
    const tempMessages = this.classifier.rebuild(matching, context.messages)
    
    const losslessResult = await losslessProvider.condense(
      {
        ...context,
        messages: tempMessages
      },
      options
    )
    
    if (!losslessResult.error) {
      // Re-classify after lossless
      processed = this.classifier.classify(losslessResult.messages)
    } else {
      processed = matching
    }
  } else {
    processed = matching
  }
  break
```

**Checkpoint SDDD** : Recherche `"smart provider lossless integration pass reuse composition"`

**Taille estimée** : 30 lignes code + 40 lignes tests = **70 lignes**

**Validation** :
- [ ] Smart peut réutiliser lossless
- [ ] Composition de providers fonctionne
- [ ] Tests d'intégration passent

---

#### **Commit 25 : Smart Provider Performance Tests**

**Fichiers créés** :
- `src/core/condense/__tests__/smart-benchmarks.test.ts`

**Contenu** :

```typescript
describe("Smart Provider Benchmarks", () => {
  it("should outperform native on reduction", async () => {
    const nativeProvider = new NativeCondensationProvider()
    const smartProvider = new SmartCondensationProvider()
    smartProvider.setPreset("balanced")
    
    const nativeResult = await nativeProvider.condense(context, options)
    const smartResult = await smartProvider.condense(context, options)
    
    expect(smartResult.newContextTokens!).toBeLessThan(nativeResult.newContextTokens!)
  })
  
  it("should be faster than native (MVP without LLM)", async () => {
    const startNative = performance.now()
    await nativeProvider.condense(context, options)
    const nativeTime = performance.now() - startNative
    
    const startSmart = performance.now()
    await smartProvider.condense(context, options)
    const smartTime = performance.now() - startSmart
    
    expect(smartTime).toBeLessThan(nativeTime)
  })
})
```

**Checkpoint SDDD** : Recherche `"smart provider performance benchmarks comparison native lossless"`

**Taille estimée** : 100 lignes tests

**Validation** :
- [ ] Smart plus efficace que native
- [ ] Performance acceptable
- [ ] Presets produisent réductions différentes

---

### 🎯 **Checkpoint 4 : Smart Provider Multi-Passes** (Après Commit 25)

#### Tests Requis
- [ ] Smart provider fonctionne avec 3 presets
- [ ] Multi-passes s'exécutent correctement
- [ ] Réduction supérieure à native
- [ ] MVP sans LLM fonctionne (gratuit)
- [ ] UI preset selection opérationnelle
- [ ] Composition avec lossless testée

#### SDDD Validation
**Recherche** : `"smart provider multi-pass preset architecture quality balanced aggressive"`

**Documents attendus** :
1. `pass-types.ts` - Système de passes et presets
2. `content-model.ts` - Classification de contenu
3. `pass-executor.ts` - Moteur d'exécution
4. `smart-provider.ts` - Provider complet

#### Déploiement
Build VSIX avec 4 providers, test des 3 presets smart

#### Documentation
- **ADR-003** : "Smart Provider Pass-Based Architecture"
- **User Guide** : "Choosing the Right Provider and Preset"

---

### BLOC 5 : UI & Polish (Commits 26-30)

**Objectif** : Finalisation UI, documentation, tests end-to-end

---

#### **Commit 26 : Provider Comparison UI**

**Fichiers créés** :
- `webview-ui/src/components/settings/ProviderComparison.tsx`

**Contenu** : Tableau comparatif des providers (coût, vitesse, qualité, cas d'usage)

**Taille estimée** : 80 lignes + 40 tests = **120 lignes**

---

#### **Commit 27 : Condensation Metrics Dashboard**

**Fichiers créés** :
- `webview-ui/src/components/chat/CondensationMetrics.tsx`

**Contenu** : Affichage des métriques de condensation (réduction%, coût total, nb appels)

**Taille estim
ée** : 100 lignes + 60 tests = **160 lignes**

---

#### **Commit 28 : End-to-End Integration Tests**

**Fichiers créés** :
- `src/core/condense/__tests__/e2e-integration.test.ts` (200 lignes)

**Contenu** :

```typescript
describe("Context Condensation E2E", () => {
  describe("full workflow", () => {
    it("should condense context when threshold reached", async () => {
      // Simulate full conversation flow
      const messages = createLongConversation(150_000) // Over threshold
      
      const result = await truncateConversationIfNeeded({
        messages,
        totalTokens: 140_000,
        contextWindow: 200_000,
        apiHandler: mockApiHandler,
        autoCondenseContext: true,
        autoCondenseContextPercent: 75,
        systemPrompt: "test",
        taskId: "e2e-test",
        profileThresholds: {},
        currentProfileId: "default"
      })
      
      expect(result.messages.length).toBeLessThan(messages.length)
      expect(result.prevContextTokens).toBeLessThan(140_000)
    })
    
    it("should respect provider selection", async () => {
      condensationManager.setActiveProvider("lossless")
      
      const result = await truncateConversationIfNeeded(...)
      
      // Verify lossless was used (cost = 0, fast)
      expect(result.cost).toBe(0)
    })
    
    it("should fallback on provider failure", async () => {
      // Make active provider fail
      condensationManager.setActiveProvider("native")
      vitest.spyOn(NativeCondensationProvider.prototype, 'condense')
        .mockRejectedValue(new Error("LLM error"))
      
      const result = await truncateConversationIfNeeded(...)
      
      // Should fallback to lossless or truncation
      expect(result.error).toBeUndefined()
      expect(result.messages.length).toBeLessThan(messages.length)
    })
  })
  
  describe("profile thresholds", () => {
    it("should use profile-specific threshold", async () => {
      const result = await truncateConversationIfNeeded({
        ...options,
        autoCondenseContextPercent: 75, // Global
        profileThresholds: { "custom": 85 }, // Override
        currentProfileId: "custom"
      })
      
      // Should trigger at 85% not 75%
    })
  })
  
  describe("backward compatibility", () => {
    it("should behave identically to old system with native provider", async () => {
      condensationManager.setActiveProvider("native")
      
      const oldBehavior = await summarizeConversationOld(...)
      const newBehavior = await truncateConversationIfNeeded(...)
      
      expect(newBehavior.messages).toEqual(oldBehavior.messages)
      expect(newBehavior.cost).toBeCloseTo(oldBehavior.cost, 2)
    })
  })
})
```

**Checkpoint SDDD** : Recherche `"end-to-end integration tests full workflow provider fallback"`

**Taille estimée** : 200 lignes tests

**Validation** :
- [ ] Tests E2E passent
- [ ] Workflow complet testé
- [ ] Backward compatibility vérifié
- [ ] Tous les scenarios couverts

---

#### **Commit 29 : Complete Documentation**

**Fichiers créés/modifiés** :
- `docs/context-condensation-providers.md` (nouveau guide utilisateur)
- Mise à jour JSDoc sur toutes les interfaces publiques
- README updates

**Contenu** :

```markdown
# Context Condensation Providers

## Overview

Roo-Code offers 4 condensation strategies to manage context window efficiently...

## Providers

### Native (LLM-based)
**Best for**: High-quality preservation of conversation flow
**Cost**: $0.05-0.10 per condensation
**Speed**: Slow (5-10s)
**Reduction**: 40-60%

### Lossless (Deduplication)
**Best for**: Free optimization, no information loss
**Cost**: Free
**Speed**: Fast (<100ms)
**Reduction**: 20-40%

### Truncation (Sliding Window)
**Best for**: Budget-constrained, speed-critical scenarios
**Cost**: Free
**Speed**: Very fast (<10ms)
**Reduction**: ~50%

### Smart (Multi-pass)
**Best for**: Intelligent, customizable condensation
**Cost**: Variable (MVP: Free)
**Speed**: Medium
**Reduction**: 30-70% (depends on preset)

#### Smart Presets

- **Quality**: Minimal information loss
- **Balanced**: Moderate reduction
- **Aggressive**: Maximum token reduction

## Choosing a Provider

...flow chart or decision tree...

## Configuration

...screenshots and examples...

## Troubleshooting

...common issues and solutions...
```

**Checkpoint SDDD** : Recherche `"condensation providers documentation user guide configuration"`

**Taille estimée** : 300 lignes documentation

**Validation** :
- [ ] Documentation complète
- [ ] Exemples clairs
- [ ] Troubleshooting section
- [ ] JSDoc sur tous exports publics

---

#### **Commit 30 : Final Polish & CHANGELOG**

**Fichiers modifiés** :
- `CHANGELOG.md` - Ajout entrée complète
- `README.md` - Mention du système de providers
- Cleanup code comments
- Final linting pass

**Contenu CHANGELOG** :

```markdown
## [Unreleased]

### Added

#### Context Condensation Provider System 🎯

A new flexible provider-based architecture for context condensation, offering multiple strategies:

- **Native Provider**: High-quality LLM-based summarization (current behavior preserved)
- **Lossless Provider**: Free, fast deduplication optimization (20-40% reduction, no information loss)
- **Truncation Provider**: Simple sliding window for budget-constrained scenarios
- **Smart Provider**: Multi-pass intelligent condensation with presets (Quality, Balanced, Aggressive)

**Key Features**:
- Backward compatible: default behavior unchanged
- Zero-cost optimization option (Lossless)
- Automatic fallback on provider failure
- Per-profile threshold configuration
- Extensible architecture for future providers

**Benefits**:
- Reduce API costs by using Lossless provider
- Faster condensation with free providers
- More control over condensation strategy
- Better preservation of important context

**UI Changes**:
- New "Condensation Strategy" setting in Context Management
- Provider comparison table
- Condensation metrics dashboard
- Smart preset selection

See `docs/context-condensation-providers.md` for complete guide.

### Changed

- Condensation logic refactored into provider pattern
- Enhanced fallback strategy for robustness

### Fixed

- Context condensation now respects per-profile thresholds correctly
```

**Checkpoint SDDD** : Recherche `"context condensation provider system release changelog features"`

**Taille estimée** : 50 lignes

**Validation** :
- [ ] CHANGELOG complet et clair
- [ ] Code cleanup fait
- [ ] Linting passe
- [ ] Prêt pour release

---

### 🎯 **Checkpoint 5 : Système Complet** (Après Commit 30)

#### Tests Requis - Full Suite
- [ ] **Tous les tests unitaires passent** (>90% coverage)
- [ ] **Tests d'intégration passent**
- [ ] **Tests E2E passent**
- [ ] **Tests de performance passent**
- [ ] **Tests de backward compatibility passent**
- [ ] **Aucune régression** dans tests existants

#### Validation Fonctionnelle Complète
- [ ] 4 providers fonctionnent : native, lossless, truncation, smart
- [ ] 3 presets smart opérationnels : quality, balanced, aggressive
- [ ] UI settings complète et fonctionnelle
- [ ] Fallback chain robuste testée
- [ ] Profile thresholds respectés
- [ ] Métriques trackées correctement

#### SDDD Validation Finale
**Recherche globale** : `"context condensation provider system architecture implementation complete"`

**Tous les documents attendus découvrables** :
1. Core types et interfaces
2. Base provider et métriques
3. Native provider (backward compat)
4. Provider manager (orchestration)
5. Lossless provider (dedup)
6. Truncation provider (sliding window)
7. Smart provider (multi-pass)
8. Pass system et presets
9. Content classifier
10. Pass executor
11. Integration avec sliding-window
12. UI settings et composants

#### Déploiement Production
1. **Build VSIX final**
2. **Test exhaustif** :
   - Installation sur VS Code propre
   - Test des 4 providers
   - Test des presets smart
   - Vérification backward compatibility
   - Test de fallback
   - Vérification métriques
3. **Validation utilisateurs pilotes**
4. **Monitoring** :
   - Error rates par provider
   - Performance metrics
   - Adoption rates
   - Cost savings (lossless usage)

#### Métriques de Succès Finales

| Métrique | Cible | Validation |
|----------|-------|------------|
| **Tests Coverage** | >90% | ✅ Coverage report |
| **Build Time** | <3 min | ✅ CI logs |
| **Extension Size** | +150KB max | ✅ VSIX size |
| **Startup Impact** | <50ms | ✅ Performance profiling |
| **Native Performance** | Identique | ✅ Benchmarks |
| **Lossless Reduction** | 20-40% | ✅ E2E tests |
| **Lossless Speed** | <100ms | ✅ Benchmarks |
| **Truncation Speed** | <10ms | ✅ Benchmarks |
| **Backward Compat** | 100% | ✅ Regression tests |

#### Documentation Complète
- [x] **ADR-001** : Provider Pattern Architecture
- [x] **ADR-002** : Lossless Optimization Strategy
- [x] **ADR-003** : Smart Provider Pass-Based Design
- [x] **User Guide** : Complete provider documentation
- [x] **API Docs** : JSDoc on all public interfaces
- [x] **CHANGELOG** : Detailed release notes
- [x] **Troubleshooting Guide** : Common issues and solutions

---

## Stratégie de Test

### Tests par Commit

Chaque commit doit inclure :
- **Tests unitaires** pour nouveau code (>90% coverage)
- **Tests d'intégration** si applicable
- **Tests de non-régression** pour code existant touché
- **Performance tests** pour code critique (providers)

### Tests par Checkpoint

À chaque checkpoint SDDD :
- **End-to-end tests** du système complet jusqu'ici
- **Backward compatibility tests** exhaustifs
- **Performance benchmarks** comparatifs
- **User acceptance tests** via roo-code-customization

### Tests Finaux (Checkpoint 5)

- **Full regression suite** sur système existant
- **Cross-provider compatibility tests**
- **Stress tests** (conversations très longues)
- **Edge case tests** (fichiers énormes, erreurs réseau, etc.)
- **Security tests** (injection, sanitization)

---

## Documentation Continue

### Par Bloc de Commits

Après chaque bloc (8, 13, 17, 25, 30), créer :

1. **ADR (Architecture Decision Record)**
   - Décision architecturale prise
   - Context et motivations
   - Alternatives considérées
   - Conséquences

2. **API Documentation**
   - JSDoc complet sur interfaces publiques
   - Exemples d'utilisation
   - Types et paramètres documentés

3. **User Guide Updates**
   - Nouvelles fonctionnalités expliquées
   - Screenshots et exemples
   - Best practices

### Documentation Finale

1. **Complete User Guide** :
   - Vue d'ensemble du système
   - Guide de choix de provider
   - Configuration avancée
   - Troubleshooting

2. **Developer Guide** :
   - Architecture overview
   - Creating custom providers
   - Extending pass system
   - Contributing guidelines

3. **Migration Guide** :
   - Changements depuis version précédente
   - Breaking changes (aucun normalement)
   - Nouvelles options disponibles

---

## Métriques de Succès

### Par Provider

| Provider | Métrique | Cible | Mesure |
|----------|----------|-------|--------|
| **Native** | Backward compat | 100% | Tests régression |
| | Latency | 5-10s | Benchmarks |
| | Cost | $0.05-0.10 | Telemetry |
| | Reduction | 40-60% | E2E tests |
| **Lossless** | Reduction | 20-40% | E2E tests |
| | Latency | <100ms | Benchmarks |
| | Cost | $0 | Telemetry |
| | Info loss | 0% | Validation tests |
| **Truncation** | Reduction | ~50% | E2E tests |
| | Latency | <10ms | Benchmarks |
| | Cost | $0 | Telemetry |
| **Smart** | Reduction (Balanced) | 40-50% | E2E tests |
| | Latency (MVP) | <200ms | Benchmarks |
| | Cost (MVP) | $0 | Telemetry |

### Système Global

| Métrique | Cible | Validation |
|----------|-------|------------|
| **Code Coverage** | >90% | Jest coverage report |
| **Build Success** | 100% | CI/CD logs |
| **Performance** | No regression | Benchmarks comparison |
| **Extension Size** | <200KB increase | VSIX analysis |
| **Startup Time** | <50ms impact | Performance profiling |
| **Error Rate** | <1% | Telemetry monitoring |
| **Adoption Rate** | >30% switch from native | Usage analytics |
| **Cost Savings** | >50% with lossless | Cost tracking |

---

## Risques et Mitigations

### Risques Identifiés

#### R-1 : Régression Backward Compatibility 🔴 **CRITICAL**

**Probabilité** : 30%  
**Impact** : Breaking changes, rollback nécessaire  
**Mitigation** :
- Tests exhaustifs de backward compatibility à chaque commit
- Native provider = wrapper strict sans modification
- Tests de non-régression automatiques en CI
- Validation manuelle avant chaque checkpoint
- Rollback plan prêt à chaque déploiement

#### R-2 : Performance Dégradée avec Provider System 🟡 **MEDIUM**

**Probabilité** : 20%  
**Impact** : Latence accrue, UX impactée  
**Mitigation** :
- Benchmarks de performance à chaque checkpoint
- Provider manager optimisé (minimal overhead)
- Caching des providers instanciés
- Lazy loading si nécessaire
- Performance budgets définis

#### R-3 : Complexité Smart Provider 🟡 **MEDIUM**

**Probabilité** : 40%  
**Impact** : Timeline dépassée, bugs  
**Mitigation** :
- MVP simplifié : 3 presets prédéfinis seulement
- Pas de UI complexe de configuration
- Tests unitaires exhaustifs par pass
- Validation progressive par preset
- Extension vers configuration avancée repoussée

#### R-4 : Adoption Utilisateur Faible 🟢 **LOW**

**Probabilité** : 30%  
**Impact** : ROI limité sur développement  
**Mitigation** :
- Documentation claire des bénéfices
- Provider comparison table dans UI
- Defaults intelligents (native par défaut)
- Metrics dashboard visible
- Tutorial/onboarding pour nouveaux providers

#### R-5 : Edge Cases Non Couverts 🟢 **LOW**

**Probabilité** : 40%  
**Impact** : Bugs en production  
**Mitigation** :
- Tests de stress (conversations très longues)
- Tests de edge cases explicites
- Error handling robuste partout
- Fallback chain garantit toujours résultat
- Monitoring et alerting en production

---

## Timeline Réaliste

### Par Bloc

| Bloc | Commits | Estimation | Buffer | Total |
|------|---------|------------|--------|-------|
| **Bloc 1** | 1-8 | 80h (2 sem) | +20h | **100h (2.5 sem)** |
| **Bloc 2** | 9-13 | 60h (1.5 sem) | +15h | **75h (2 sem)** |
| **Bloc 3** | 14-17 | 40h (1 sem) | +10h | **50h (1.25 sem)** |
| **Bloc 4** | 18-25 | 120h (3 sem) | +30h | **150h (3.75 sem)** |
| **Bloc 5** | 26-30 | 60h (1.5 sem) | +15h | **75h (2 sem)** |
| **TOTAL** | **30** | **360h (9 sem)** | **+90h** | **450h (11-12 sem)** |

### Timeline Détaillée

**Semaine 1-2.5** : Bloc 1 - Foundation + Native Provider
- Commits 1-8
- Checkpoint 1
- Déploiement via roo-code-customization

**Semaine 3-4** : Bloc 2 - Lossless Provider
- Commits 9-13
- Checkpoint 2
- Déploiement et validation utilisateurs

**Semaine 5** : Bloc 3 - Truncation Provider
- Commits 14-17
- Checkpoint 3
- Tests fallback chain

**Semaine 6-9.5** : Bloc 4 - Smart Provider
- Commits 18-25
- Checkpoint 4
- Provider le plus complexe, temps conséquent

**Semaine 10-11.5** : Bloc 5 - UI & Polish
- Commits 26-30
- Checkpoint 5
- Documentation finale
- Tests E2E complets

**Semaine 12** : Buffer & Stabilisation
- Correction bugs trouvés en E2E
- Performance tuning
- Documentation polish
- Préparation release

### Jalons Critiques

- **J+20** (Fin semaine 3) : Foundation stable + Native + Lossless
- **J+35** (Fin semaine 5) : 3 providers opérationnels
- **J+65** (Fin semaine 10) : 4 providers + Smart presets
- **J+80** (Fin semaine 12) : Release candidate prêt

---

## Rapport pour Orchestrateur

### Partie 1 : Synthèse du Plan

#### Vue d'Ensemble des 30 Commits

Le plan opérationnel décompose l'implémentation du Context Condensation Provider System en **5 blocs progressifs** :

1. **Bloc 1 (Commits 1-8)** : Foundation + Native Provider
   - Architecture provider de base
   - Wrapper du système actuel sans modification
   - Garantit backward compatibility 100%

2. **Bloc 2 (Commits 9-13)** : Lossless Provider
   - Optimisation gratuite par déduplication
   - 20-40% réduction sans perte d'information
   - <100ms latence

3. **Bloc 3 (Commits 14-17)** : Truncation Provider
   - Alternative sliding window simple
   - Gratuit, <10ms, dernier recours
   - Fallback chain complète

4. **Bloc 4 (Commits 18-25)** : Smart Provider
   - Architecture multi-passes
   - 3 presets : Quality, Balanced, Aggressive
   - Extensible pour configuration avancée future

5. **Bloc 5 (Commits 26-30)** : UI & Polish
   - Interface utilisateur complète
   - Documentation finale
   - Tests E2E et release

#### Rationale des Choix Architecturaux

**1. Provider Pattern dès le début** ✅

**Justification technique** :
- Évite refactoring coûteux ultérieur
- Architecture extensible immédiate
- Backward compatibility par design (Native Provider = wrapper)
- Tests de non-régression dès Commit 1
- Zéro coût technique de dette

**Alternatives rejetées** :
- ❌ **Approche "in-place" puis extraction** : Risque de régression élevé, refactoring difficile, dette technique
- ❌ **Modification directe de `summarizeConversation`** : Breaking changes, tests complexes, non-extensible

**2. Multi-passes gérable avec presets simples** ✅

**Estimation réaliste de complexité** :

Le document 006 critique la complexité combinatoire (48N configurations). Notre approche MVP la résout :

| Aspect | Document 004 (Critique) | Notre Plan MVP |
|--------|-------------------------|----------------|
| **Configurations** | 48N possibles | 3 presets fixes |
| **UI** | Configuration complexe | Simple dropdown |
| **Passes** | N configurables | 2-3 passes prédéfinies |
| **Content types** | 3 types × 4 ops × N | 3 presets testés |
| **Testing** | Explosion combinatoire | Tests linéaires (3 presets) |
| **Timeline** | 3-4 semaines | 3.75 semaines (gérable) |

**Complexité maîtrisée** :
- MVP : 3 presets × 2-3 passes = **6-9 configurations à tester** (gérable)
- Extension future : UI avancée en Phase 5 (hors scope MVP)
- Architecture extensible : ajout de presets facile

**3. Progressivité maintenue avec checkpoints** ✅

**5 Checkpoints SDDD rigoureux** :
1. Après Commit 8 : Foundation validée
2. Après Commit 13 : Lossless opérationnel
3. Après Commit 17 : 3 providers disponibles
4. Après Commit 25 : Smart provider complet
5. Après Commit 30 : Système final

**Chaque checkpoint** :
- Recherche sémantique de validation
- Tests exhaustifs
- Déploiement via roo-code-customization
- Rollback plan prêt
- Documentation à jour

**4. Troncature est importante** ✅

**Justification performance et coûts** :

| Provider | Latency | Cost | Use Case |
|----------|---------|------|----------|
| Native | 5-10s | $0.05-0.10 | Quality important |
| Lossless | <100ms | $0 | Free optimization |
| **Truncation** | **<10ms** | **$0** | **Speed critical** |
| Smart | Variable | Variable | Configurable |

**Cas d'usage truncation** :
- Budget très serré (étudiants, hobby projects)
- Latence critique (real-time collaboration)
- **Fallback de dernier recours** (robustesse)
- Tests de performance

Sans truncation : système vulnérable si Native et Lossless échouent.

#### Timeline Estimée Réaliste

**Total : 450h (11-12 semaines)** avec buffer de 90h inclus

Comparaison avec document 006 :
- Document 006 suggérait : 8-10 semaines sans Smart Provider
- Notre plan : 11-12 semaines **avec Smart Provider MVP**
- Buffer : 20% (best practice)

**Breakdown** :
- Foundation (2.5 sem) : Robuste, tests exhaustifs
- Lossless (2 sem) : Logique dedup + consolidation
- Truncation (1.25 sem) : Simple mais testé
- Smart (3.75 sem) : Complexe mais MVP simplifié
- Polish (2 sem) : UI, docs, E2E
- Buffer (1 sem) : Imprévus

#### Checkpoints de Validation SDDD

**Principe** : Validation sémantique tous les 2-3 commits

**Format systématique** :
```markdown
### Checkpoint N (Après Commit X)
**Recherche SDDD** : "query sémantique spécifique"
**Docs attendus** : [liste fichiers/concepts]
**Validation** : [critères de succès]
**Déploiement** : Build VSIX + test isolé + rollback plan
**Métriques** : [KPIs à atteindre]
**Documentation** : [ADR, guides mis à jour]
```

**Bénéfices** :
- Découvrabilité garantie du code créé
- Grounding régulier pour éviter dérive
- Documentation continue vs documentation finale massive
- Feedback rapide sur architecture

---

### Partie 2 : Différences avec Document 006

#### Pourquoi Provider Pattern dès le Début

**Critique du doc 006** : Suggérait approche "in-place" puis extraction

**Notre position** : Provider pattern immédiat

**Justification technique détaillée** :

1. **Coût de refactoring ultérieur** :
   ```
   Approche in-place puis extraction :
   - Phase 1 : Modifier summarizeConversation (2 sem)
   - Phase 2 : Tests régression (1 sem)
   - Phase 3 : Extraction en provider (2 sem)
   - Phase 4 : Tests compatibilité (1 sem)
   = 6 semaines + risque régression élevé
   
   Notre approche :
   - Commit 1-2 : Types + Base (3 jours)
   - Commit 3 : Native Provider wrapper (2 jours)
   - Commit 4-5 : Manager + Integration (3 jours)
   = 8 jours, zero régression par design
   ```

2. **Risque technique** :
   - Modification `summarizeConversation` : touche code critique, tests lourds
   - Wrapper dans Native Provider : isolation, tests ciblés, rollback facile

3. **Extensibilité** :
   - Provider pattern : ajout de providers trivial
   - In-place : ajout de stratégies = refactoring à chaque fois

4. **Tests** :
   - Provider : tests unitaires par provider, isolation
   - In-place : tests monolithiques, couplage fort

**Conclusion** : Provider pattern dès le début = **moins de risque, moins de temps, meilleure architecture**

#### Pourquoi Multi-Passes est Gérable

**Critique du doc 006** : "Explosion combinatoire des tests, 3-4 semaines pour Smart seul"

**Notre position** : MVP simplifié avec 3 presets rend multi-passes gérable

**Estimation réaliste de complexité** :

```
Complexité Document 004 (analysé par 006) :
- 3 content types × 4 operations × N passes × 2 modes × 2 conditions
= 48N configurations
+ UI complexe pour configurer
+ Tests combinatoires
= Impraticable en un PR

Notre MVP Smart Provider :
- 3 presets FIXES (quality, balanced, aggressive)
- Chaque preset : 2-3 passes prédéfinies
- Total : 3 presets à tester = 3 scénarios
+ Architecture extensible pour Phase 5 (hors MVP)
= Gérable en 3.75 semaines
```

**Breakdown Smart Provider (Commits 18-25)** :
- Commit 18 : Types de pass (1 jour)
- Commit 19 : Content model (1.5 jours)
- Commit 20 : Pass executor (2 jours)
- Commit 21 : Smart provider core (2 jours)
- Commit 22-23 : Registration + UI (1 jour)
- Commit 24 : Lossless integration (1 jour)
- Commit 25 : Tests performance (1 jour)
= **9.5 jours de dev** + buffer = 3.75 semaines (faisable)

**Phase 5 (future)** : Extension vers configuration avancée si valeur démontrée.

#### Comment la Progressivité est Maintenue

**Critique du doc 006** : Validait la progressivité mais sans provider pattern

**Notre approche** : Progressivité **ET** provider pattern

**Mécanismes de progressivité** :

1. **Checkpoints rigoureux tous les 2-3 commits** :
   - Recherche SDDD obligatoire
   - Tests exhaustifs
   - Déploiement via roo-code-customization
   - Rollback immédiat si problème

2. **Commits atomiques** :
   - Chaque commit = une fonctionnalité testable
   - Aucun commit "WIP" ou incomplet
   - Build passe à chaque commit
   - Tests verts à chaque commit

3. **Backward compatibility continue** :
   - Native provider = wrapper sans modification
   - Tests de non-régression à chaque commit
   - Default behavior = Native (identique actuel)
   - Aucun breaking change possible

4. **Déploiements incrémentaux** :
   - Checkpoint 1 : Foundation + Native seul
   - Checkpoint 2 : + Lossless
   - Checkpoint 3 : + Truncation
   - Checkpoint 4 : + Smart
   - Checkpoint 5 : Polish final

5. **Validation utilisateurs continues** :
   - Build VSIX à chaque checkpoint
   - Test sur environnement isolé
   - Feedback utilisateurs pilotes
   - Ajustements avant checkpoint suivant

#### Pourquoi Troncature est Importante

**Critique du doc 006** : "Usage limité, pas prioritaire"

**Notre position** : Troncature est essentielle

**Justification performance et coûts** :

1. **Cas d'usage réels** :
   ```
   Scénario 1 : Développeur sur budget serré
   - Native : $0.10 × 50 condensations/mois = $5/mois
   - Truncation : $0 × 50 = $0/mois
   Économie : 100%
   
   Scénario 2 : Latence critique (pair programming)
   - Native : 5-10s pause (UX perturbée)
   - Truncation : <10ms (imperceptible)
   Impact UX : Majeur
   
   Scénario 3 : Fallback robustesse
   - Native fail → Lossless fail → Truncation (toujours marche)
   - Sans Truncation : Fail complet = conversation bloquée
   ```

2. **Coût d'implémentation minimal** :
   - Commit 14 : Wrapper de `truncateConversation` existante (1 jour)
   - Commits 15-17 : Registration + tests (1.5 jours)
   - Total : **2.5 jours** pour garantir robustesse système

3. **Robustesse système** :
   - Fallback chain : Smart → Native → Lossless → Truncation
   - Sans Truncation : chain incomplète, vulnérable
   - Avec Truncation : toujours un fallback qui marche (gratuit, rapide)

4. **Philosophical alignment** :
   - Design principle : "Graceful degradation"
   - Toujours mieux que fail complet
   - User peut choisir explicitement si besoin

**Conclusion** : 2.5 jours d'effort pour robustesse critique = excellent ROI

---

### Partie 3 : Grounding pour Suite

#### Recherche Sémantique Recommandée

**Pour l'orchestrateur avant de lancer implémentation** :

```
Recherche 1 : "context condensation provider architecture system implementation"
→ Comprendre vision globale

Recherche 2 : "sliding window integration point truncateConversationIfNeeded"
→ Localiser point d'intégration exact

Recherche 3 : "native provider wrapper backward compatibility summarizeConversation"
→ Comprendre stratégie wrapper

Recherche 4 : "lossless deduplication file tool result consolidation free optimization"
→ Algorithmes dedup à implémenter

Recherche 5 : "smart provider multi-pass preset quality balanced aggressive"
→ Architecture Smart Provider MVP
```

#### Synthèse pour Orchestrateur

**Ce que l'orchestrateur doit retenir** :

1. **Architecture Globale** :
   ```
   sliding-window/index.ts (1 modif ligne 147)
     ↓
   CondensationProviderManager (orchestrateur)
     ↓
   4 Providers (Native, Lossless, Truncation, Smart)
   ```

2. **Provider Pattern** :
   - Interface `ICondensationProvider` : contrat commun
   - `BaseCondensationProvider` : logique commune (métriques, validation)
   - Chaque provider : implémentation spécifique

3. **Points Critiques** :
   - **Backward compatibility** : Native Provider = wrapper strict
   - **Tests** : >90% coverage obligatoire chaque commit
   - **SDDD** : Validation sémantique tous les 2-3 commits
   - **Déploiement** : roo-code-customization à chaque checkpoint

4. **Timeline** :
   - 11-12 semaines total
   - 5 checkpoints majeurs
   - Buffer 20% inclus
   - Prêt pour production fin semaine 12

5. **Risques Principaux** :
   - R-1 : Régression backward compatibility (mitigation : tests exhaustifs)
   - R-3 : Complexité Smart Provider (mitigation : MVP simplifié 3 presets)

#### Points d'Attention Critiques

**Pour l'implémentation** :

1. **Commit 3 (Native Provider)** : 🔴 **CRITIQUE**
   - Doit wrapper `summarizeConversation` SANS modification
   - Tests de backward compatibility exhaustifs
   - Si échoue : tout le système échoue

2. **Commit 5 (Integration)** : 🔴 **CRITIQUE**
   - Une seule ligne modifiée dans `sliding-window/index.ts`
   - Tests de non-régression sur TOUS les tests existants
   - Performance : overhead <10ms max

3. **Commits 9-11 (Lossless Logic)** : 🟡 **IMPORTANT**
   - Algorithmes de dedup corrects
   - Aucune perte d'information
   - Tests de round-trip (deduplicate → rebuild = identique sémantiquement)

4. **Commit 20 (Pass Executor)** : 🟡 **IMPORTANT**
   - Moteur d'exécution robuste
   - Gestion erreurs par pass
   - Tests unitaires exhaustifs

5. **Commits 26-30 (Polish)** : 🟢 **STANDARD**
   - Ne pas sous-estimer documentation
   - Tests E2E critiques pour validation finale
   - CHANGELOG clair et complet

#### Documentation Essentielle

**Pour chaque phase** :

- **Phase 1** : ADR-001 "Provider Pattern Architecture Decision"
- **Phase 2** : ADR-002 "Lossless Optimization Strategy"
- **Phase 3** : Documentation Truncation Provider
- **Phase 4** : ADR-003 "Smart Provider Pass-Based Design"
- **Phase 5** : Complete User Guide + Migration Guide

**Format ADR** :
```markdown
# ADR-XXX: Title

## Status
Accepted / Proposed / Deprecated

## Context
What is the issue that we're seeing?

## Decision
What is the change that we're proposing?

## Consequences
What becomes easier or more difficult?
```

---

## Conclusion

Ce plan opérationnel de 30 commits fournit une **roadmap complète et détaillée** pour implémenter le Context Condensation Provider System en tenant compte des critiques du document 006.

### Principes Clés Respectés

✅ **Provider pattern dès le début** - Architecture extensible immédiate  
✅ **Progressivité rigoureuse** - 5 checkpoints SDDD, déploiements incrémentaux  
✅ **Multi-passes gérable** - MVP avec 3 presets, extension future  
✅ **Troncature importante** - Robustesse, fallback, cas d'usage réels  
✅ **Tests exhaustifs** - >90% coverage, TDD, E2E complets  
✅ **Documentation continue** - ADR, guides, SDDD validation

### Timeline Réaliste

**11-12 semaines** avec buffer 20% inclus, jalons clairs, checkpoints validés.

### Prêt à l'Exécution

Chaque commit spécifié avec :
- Fichiers exacts à créer/modifier
- Contenu précis (interfaces, classes, fonctions)
- Tests associés et cas couverts
- Taille estimée (lignes)
- Dépendances
- Validation SDDD

**Aucun "TODO" ou "à définir"** - Plan complet et auto-suffisant.

### Prochain Step

**Recommandation pour orchestrateur** :

1. **Valider ce plan** avec utilisateur
2. **Créer milestone GitHub** avec les 30 commits
3. **Lancer Bloc 1** (Commits 1-8) en mode Code
4. **Checkpoint 1** après Commit 8
5. **Itérer** jusqu'à Checkpoint 5

🚀 **Prêt pour implémentation !**