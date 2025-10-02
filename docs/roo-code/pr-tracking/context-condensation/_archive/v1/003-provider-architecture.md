# Provider Architecture Design - Context Condensation System

**Date**: 2025-10-01  
**Version**: 1.0  
**Status**: Design Specification

## Executive Summary

This document specifies the technical architecture for a provider-based context condensation system. The design introduces an abstraction layer that allows multiple condensation strategies to coexist, with the current implementation wrapped as a provider alongside new improved providers. The architecture ensures backward compatibility, extensibility, and clear separation of concerns.

## 1. Architecture Overview

### 1.1 Design Philosophy

**Core Principles**:
1. **Strategy Pattern**: Encapsulate algorithms in interchangeable providers
2. **Open/Closed**: Open for extension (new providers), closed for modification (core)
3. **Dependency Inversion**: Depend on abstractions (interface), not concretions
4. **Single Responsibility**: Each provider handles one strategy
5. **Backward Compatibility**: Existing behavior preserved exactly

### 1.2 High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Task.ts                              │
│  (Orchestrates condensation via ProviderManager)        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│            CondensationProviderManager                  │
│  - Selects provider based on configuration              │
│  - Manages provider lifecycle                           │
│  - Handles provider failures and fallbacks              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│         ICondensationProvider (Interface)               │
│  - condense()                                           │
│  - estimateReduction()                                  │
│  - getCapabilities()                                    │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│ NativeProvider   │    │  SmartProvider   │
│  (Current logic) │    │  (Improved)      │
└──────────────────┘    └─────────┬────────┘
                                  │
                        ┌─────────┴─────────┐
                        ▼                   ▼
              ┌────────────────┐  ┌────────────────┐
              │ LosslessPhase  │  │  LossyPhase    │
              └────────────────┘  └────────────────┘
```

### 1.3 Module Organization

```
src/core/condense/
├── index.ts                    # Public exports
├── types.ts                    # Shared types and interfaces
├── manager.ts                  # ProviderManager implementation
│
├── providers/
│   ├── base.ts                 # ICondensationProvider interface
│   ├── native.ts               # NativeCondensationProvider
│   └── smart/
│       ├── index.ts            # SmartCondensationProvider
│       ├── lossless.ts         # Lossless phase implementation
│       └── lossy.ts            # Lossy phase implementation
│
├── strategies/
│   ├── deduplication.ts        # File read deduplication
│   ├── consolidation.ts        # Tool result consolidation
│   ├── references.ts           # Reference system
│   ├── classification.ts       # Message type classification
│   ├── prioritization.ts       # Content-type prioritization
│   └── tree-scoring.ts         # Importance scoring (future)
│
├── utils/
│   ├── token-counter.ts        # Token counting utilities
│   ├── message-analyzer.ts     # Message analysis
│   └── validators.ts           # Result validation
│
└── __tests__/
    ├── providers/
    ├── strategies/
    └── integration/
```

## 2. Core Interfaces

### 2.1 ICondensationProvider Interface

```typescript
/**
 * Base interface that all condensation providers must implement.
 * Providers encapsulate different strategies for reducing conversation context
 * while preserving semantic meaning and conversation continuity.
 */
export interface ICondensationProvider {
  /** Unique identifier for this provider */
  readonly id: string
  
  /** Human-readable name */
  readonly name: string
  
  /** Description of the provider's strategy */
  readonly description: string
  
  /** Semantic version */
  readonly version: string
  
  /**
   * Condense the conversation context according to this provider's strategy.
   * 
   * @param context - The conversation context to condense
   * @param options - Configuration options for condensation
   * @returns Promise resolving to the condensation result
   * @throws CondensationError if condensation fails unrecoverably
   */
  condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult>
  
  /**
   * Estimate the token reduction this provider can achieve without
   * actually performing condensation. Useful for showing estimates to users.
   * 
   * @param context - The conversation context to analyze
   * @returns Promise resolving to estimated reduction metrics
   */
  estimateReduction(
    context: ConversationContext
  ): Promise<TokenEstimate>
  
  /**
   * Get the capabilities supported by this provider.
   * Allows UI to adapt based on provider features.
   * 
   * @returns Object describing provider capabilities
   */
  getCapabilities(): ProviderCapabilities
  
  /**
   * Validate configuration options for this provider.
   * Called before condensation to catch configuration errors early.
   * 
   * @param options - Options to validate
   * @returns Validation result with errors if any
   */
  validateOptions(
    options: CondensationOptions
  ): ValidationResult
}
```

### 2.2 Supporting Types

```typescript
/**
 * Complete conversation context to be condensed
 */
export interface ConversationContext {
  /** Array of conversation messages */
  messages: ApiMessage[]
  
  /** System prompt (not condensed, but counted for tokens) */
  systemPrompt: string
  
  /** Task identifier for telemetry */
  taskId: string
  
  /** Model context window size */
  contextWindow: number
  
  /** Maximum tokens for model response */
  maxTokens: number
  
  /** Current token count (excluding last message) */
  totalTokens: number
  
  /** API handler for token counting and LLM calls */
  apiHandler: ApiHandler
}

/**
 * Configuration options for condensation operation
 */
export interface CondensationOptions {
  /** Whether this is automatic (vs manual) trigger */
  isAutomaticTrigger: boolean
  
  /** Target reduction percentage (0-100) */
  targetReductionPercent?: number
  
  /** Custom prompt for LLM summarization (lossy phase) */
  customPrompt?: string
  
  /** Specific API handler for condensation (can differ from main) */
  condensingApiHandler?: ApiHandler
  
  /** Provider-specific configuration */
  providerConfig?: Record<string, any>
}

/**
 * Result of a condensation operation
 */
export interface CondensationResult {
  /** Condensed messages array */
  messages: ApiMessage[]
  
  /** Summary text if generated (empty string if none) */
  summary: string
  
  /** Cost of the condensation operation */
  cost: number
  
  /** New context token count (undefined if unchanged) */
  newContextTokens?: number
  
  /** Original token count before condensation */
  prevContextTokens: number
  
  /** Error message if condensation failed (undefined on success) */
  error?: string
  
  /** Detailed metrics about the condensation */
  metrics?: CondensationMetrics
}

/**
 * Detailed metrics from condensation operation
 */
export interface CondensationMetrics {
  /** Metrics from lossless phase (if applicable) */
  lossless?: {
    filesDeduped: number
    resultsConsolidated: number
    referencesCreated: number
    tokensSaved: number
  }
  
  /** Metrics from lossy phase (if applicable) */
  lossy?: {
    messagesCondensed: number
    toolResultsCompressed: number
    toolCallsSimplified: number
    thinkingCondensed: number
    conversationPreserved: number
    tokensSaved: number
  }
  
  /** Overall metrics */
  totalTokensSaved: number
  reductionPercent: number
  phasesExecuted: string[]
  timeElapsed: number
}

/**
 * Estimated token reduction metrics
 */
export interface TokenEstimate {
  /** Current token count */
  currentTokens: number
  
  /** Estimated tokens after condensation */
  estimatedTokens: number
  
  /** Estimated reduction amount */
  estimatedReduction: number
  
  /** Estimated reduction percentage */
  estimatedPercent: number
  
  /** Confidence level (0-1) */
  confidence: number
  
  /** Breakdown by strategy (if available) */
  breakdown?: {
    lossless?: number
    lossy?: number
  }
}

/**
 * Provider capabilities descriptor
 */
export interface ProviderCapabilities {
  /** Supports lossless optimization phase */
  supportsLossless: boolean
  
  /** Supports content-type aware condensation */
  supportsContentTypeAwareness: boolean
  
  /** Supports custom prompts */
  supportsCustomPrompts: boolean
  
  /** Supports importance scoring */
  supportsImportanceScoring: boolean
  
  /** Supports incremental condensation */
  supportsIncremental: boolean
  
  /** Configuration options available */
  configurableOptions: string[]
}

/**
 * Validation result for configuration
 */
export interface ValidationResult {
  valid: boolean
  errors: ValidationError[]
  warnings: ValidationWarning[]
}

export interface ValidationError {
  field: string
  message: string
  code: string
}

export interface ValidationWarning {
  field: string
  message: string
  suggestion?: string
}
```

### 2.3 Message Type Classification

```typescript
/**
 * Classification of message types for prioritized condensation
 */
export enum MessageType {
  /** User question, request, or instruction */
  USER_MESSAGE = 'user_message',
  
  /** Assistant response or explanation */
  ASSISTANT_MESSAGE = 'assistant_message',
  
  /** Assistant extended reasoning (thinking blocks) */
  ASSISTANT_THINKING = 'assistant_thinking',
  
  /** Tool invocation with parameters */
  TOOL_CALL = 'tool_call',
  
  /** Tool execution result */
  TOOL_RESULT = 'tool_result',
  
  /** System message or previous summary */
  SYSTEM_MESSAGE = 'system_message',
  
  /** Unknown or unclassifiable */
  UNKNOWN = 'unknown'
}

/**
 * Classified message with metadata
 */
export interface ClassifiedMessage {
  /** Original message */
  message: ApiMessage
  
  /** Classified type */
  type: MessageType
  
  /** Size in tokens */
  tokenCount: number
  
  /** Importance score (0-1) */
  importance: number
  
  /** Whether this message has been referenced by later messages */
  isReferenced: boolean
  
  /** Indices of messages that reference this one */
  referencedBy: number[]
}
```

## 3. Provider Implementations

### 3.1 NativeCondensationProvider

```typescript
/**
 * Provider that wraps the existing condensation logic for backward compatibility.
 * Maintains exact behavior of current implementation.
 */
export class NativeCondensationProvider implements ICondensationProvider {
  readonly id = 'native'
  readonly name = 'Native (Current)'
  readonly description = 'Current condensation strategy using LLM summarization'
  readonly version = '1.0.0'
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    // Delegate to existing summarizeConversation function
    const result = await summarizeConversation(
      context.messages,
      options.condensingApiHandler || context.apiHandler,
      context.systemPrompt,
      context.taskId,
      context.totalTokens,
      options.isAutomaticTrigger,
      options.customPrompt,
      options.condensingApiHandler
    )
    
    // Map existing result to new interface
    return {
      messages: result.messages,
      summary: result.summary,
      cost: result.cost,
      newContextTokens: result.newContextTokens,
      prevContextTokens: context.totalTokens,
      error: result.error
    }
  }
  
  async estimateReduction(
    context: ConversationContext
  ): Promise<TokenEstimate> {
    // Estimate based on historical average: ~50-70% reduction
    const currentTokens = context.totalTokens
    const estimatedTokens = Math.floor(currentTokens * 0.4)
    
    return {
      currentTokens,
      estimatedTokens,
      estimatedReduction: currentTokens - estimatedTokens,
      estimatedPercent: 60,
      confidence: 0.7
    }
  }
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: false,
      supportsContentTypeAwareness: false,
      supportsCustomPrompts: true,
      supportsImportanceScoring: false,
      supportsIncremental: false,
      configurableOptions: ['customPrompt', 'condensingApiHandler']
    }
  }
  
  validateOptions(options: CondensationOptions): ValidationResult {
    const errors: ValidationError[] = []
    const warnings: ValidationWarning[] = []
    
    // Validate custom prompt if provided
    if (options.customPrompt && options.customPrompt.trim().length === 0) {
      warnings.push({
        field: 'customPrompt',
        message: 'Custom prompt is empty, will use default prompt'
      })
    }
    
    return { valid: errors.length === 0, errors, warnings }
  }
}
```

### 3.2 SmartCondensationProvider

```typescript
/**
 * Improved condensation provider with lossless optimization and
 * content-type aware lossy compression.
 */
export class SmartCondensationProvider implements ICondensationProvider {
  readonly id = 'smart'
  readonly name = 'Smart (Improved)'
  readonly description = 'Two-phase condensation with lossless optimization and prioritized compression'
  readonly version = '1.0.0'
  
  private losslessPhase: LosslessPhase
  private lossyPhase: LossyPhase
  
  constructor() {
    this.losslessPhase = new LosslessPhase()
    this.lossyPhase = new LossyPhase()
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const startTime = Date.now()
    const metrics: CondensationMetrics = {
      totalTokensSaved: 0,
      reductionPercent: 0,
      phasesExecuted: [],
      timeElapsed: 0
    }
    
    let currentMessages = context.messages
    let currentTokens = context.totalTokens
    
    // Phase 1: Lossless optimization (if enabled)
    if (this.shouldRunLossless(options)) {
      try {
        const losslessResult = await this.losslessPhase.optimize(
          currentMessages,
          context.apiHandler
        )
        
        currentMessages = losslessResult.messages
        currentTokens = losslessResult.tokenCount
        metrics.lossless = losslessResult.metrics
        metrics.phasesExecuted.push('lossless')
        
      } catch (error) {
        console.warn('Lossless phase failed, continuing to lossy:', error)
      }
    }
    
    // Check if we've achieved target reduction
    const currentReduction = 
      ((context.totalTokens - currentTokens) / context.totalTokens) * 100
    const targetReduction = options.targetReductionPercent || 50
    
    // Phase 2: Lossy compression (if needed)
    if (currentReduction < targetReduction) {
      try {
        const lossyResult = await this.lossyPhase.condense(
          currentMessages,
          context,
          {
            ...options,
            targetReduction: targetReduction - currentReduction
          }
        )
        
        currentMessages = lossyResult.messages
        currentTokens = lossyResult.tokenCount
        metrics.lossy = lossyResult.metrics
        metrics.phasesExecuted.push('lossy')
        
      } catch (error) {
        // If lossy fails, fall back to native provider
        console.error('Lossy phase failed, falling back to native:', error)
        const nativeProvider = new NativeCondensationProvider()
        return nativeProvider.condense(context, options)
      }
    }
    
    // Validate result
    if (currentTokens >= context.totalTokens) {
      return {
        messages: context.messages,
        summary: '',
        cost: 0,
        prevContextTokens: context.totalTokens,
        error: 'Context grew during condensation'
      }
    }
    
    // Calculate final metrics
    metrics.totalTokensSaved = context.totalTokens - currentTokens
    metrics.reductionPercent = 
      (metrics.totalTokensSaved / context.totalTokens) * 100
    metrics.timeElapsed = Date.now() - startTime
    
    return {
      messages: currentMessages,
      summary: this.generateSummaryText(metrics),
      cost: 0, // TODO: Track actual costs
      newContextTokens: currentTokens,
      prevContextTokens: context.totalTokens,
      metrics
    }
  }
  
  async estimateReduction(
    context: ConversationContext
  ): Promise<TokenEstimate> {
    // Estimate based on lossless + lossy phases
    const losslessEstimate = await this.losslessPhase.estimate(
      context.messages,
      context.apiHandler
    )
    
    const remainingTokens = context.totalTokens - losslessEstimate
    const lossyEstimate = remainingTokens * 0.5 // Assume 50% lossy reduction
    
    const totalReduction = losslessEstimate + lossyEstimate
    
    return {
      currentTokens: context.totalTokens,
      estimatedTokens: context.totalTokens - totalReduction,
      estimatedReduction: totalReduction,
      estimatedPercent: (totalReduction / context.totalTokens) * 100,
      confidence: 0.8,
      breakdown: {
        lossless: losslessEstimate,
        lossy: lossyEstimate
      }
    }
  }
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: true,
      supportsContentTypeAwareness: true,
      supportsCustomPrompts: true,
      supportsImportanceScoring: true,
      supportsIncremental: false,
      configurableOptions: [
        'enableLossless',
        'enableContentTypeAwareness',
        'targetReductionPercent',
        'preservationPriority',
        'customPrompt'
      ]
    }
  }
  
  validateOptions(options: CondensationOptions): ValidationResult {
    const errors: ValidationError[] = []
    const warnings: ValidationWarning[] = []
    
    // Validate target reduction
    if (options.targetReductionPercent !== undefined) {
      if (options.targetReductionPercent < 0 || 
          options.targetReductionPercent > 100) {
        errors.push({
          field: 'targetReductionPercent',
          message: 'Must be between 0 and 100',
          code: 'INVALID_RANGE'
        })
      }
    }
    
    return { valid: errors.length === 0, errors, warnings }
  }
  
  private shouldRunLossless(options: CondensationOptions): boolean {
    return options.providerConfig?.enableLossless !== false
  }
  
  private generateSummaryText(metrics: CondensationMetrics): string {
    const parts: string[] = []
    
    if (metrics.lossless) {
      parts.push(
        `Lossless: ${metrics.lossless.filesDeduped} files deduped, ` +
        `${metrics.lossless.resultsConsolidated} results consolidated ` +
        `(-${metrics.lossless.tokensSaved} tokens)`
      )
    }
    
    if (metrics.lossy) {
      parts.push(
        `Lossy: ${metrics.lossy.messagesCondensed} messages condensed ` +
        `(-${metrics.lossy.tokensSaved} tokens)`
      )
    }
    
    parts.push(
      `Total: ${metrics.reductionPercent.toFixed(1)}% reduction ` +
      `(${metrics.totalTokensSaved} tokens saved in ${(metrics.timeElapsed / 1000).toFixed(1)}s)`
    )
    
    return parts.join('\n')
  }
}
```

## 4. Provider Manager

### 4.1 CondensationProviderManager

```typescript
/**
 * Manages provider lifecycle, selection, and fallback logic.
 * Central orchestrator for condensation operations.
 */
export class CondensationProviderManager {
  private providers: Map<string, ICondensationProvider>
  private defaultProviderId: string = 'native'
  
  constructor() {
    this.providers = new Map()
    this.registerDefaultProviders()
  }
  
  /**
   * Register built-in providers
   */
  private registerDefaultProviders(): void {
    this.registerProvider(new NativeCondensationProvider())
    this.registerProvider(new SmartCondensationProvider())
  }
  
  /**
   * Register a new provider
   */
  registerProvider(provider: ICondensationProvider): void {
    if (this.providers.has(provider.id)) {
      console.warn(`Provider ${provider.id} already registered, replacing`)
    }
    this.providers.set(provider.id, provider)
  }
  
  /**
   * Get a provider by ID
   */
  getProvider(id: string): ICondensationProvider | undefined {
    return this.providers.get(id)
  }
  
  /**
   * Get all registered providers
   */
  getAllProviders(): ICondensationProvider[] {
    return Array.from(this.providers.values())
  }
  
  /**
   * Get the default provider
   */
  getDefaultProvider(): ICondensationProvider {
    const provider = this.providers.get(this.defaultProviderId)
    if (!provider) {
      throw new Error('Default provider not found')
    }
    return provider
  }
  
  /**
   * Set the default provider
   */
  setDefaultProvider(id: string): void {
    if (!this.providers.has(id)) {
      throw new Error(`Provider ${id} not registered`)
    }
    this.defaultProviderId = id
  }
  
  /**
   * Condense using specified or default provider with fallback
   */
  async condense(
    context: ConversationContext,
    options: CondensationOptions,
    providerId?: string
  ): Promise<CondensationResult> {
    // Select provider
    const id = providerId || this.defaultProviderId
    let provider = this.providers.get(id)
    
    if (!provider) {
      console.warn(`Provider ${id} not found, using default`)
      provider = this.getDefaultProvider()
    }
    
    // Validate options
    const validation = provider.validateOptions(options)
    if (!validation.valid) {
      console.error('Provider options validation failed:', validation.errors)
      throw new CondensationError(
        'Invalid configuration',
        'CONFIG_INVALID',
        validation.errors
      )
    }
    
    // Log warnings
    if (validation.warnings.length > 0) {
      validation.warnings.forEach(w => 
        console.warn(`Provider warning [${w.field}]: ${w.message}`)
      )
    }
    
    try {
      // Attempt condensation
      const result = await provider.condense(context, options)
      
      // Validate result
      if (result.error) {
        throw new CondensationError(
          result.error,
          'PROVIDER_ERROR'
        )
      }
      
      return result
      
    } catch (error) {
      console.error(`Provider ${id} failed:`, error)
      
      // Fallback to native if not already using it
      if (id !== 'native') {
        console.log('Falling back to native provider')
        const nativeProvider = this.providers.get('native')!
        return nativeProvider.condense(context, options)
      }
      
      // If native also fails, fall back to truncation
      console.log('Native provider failed, using truncation fallback')
      return this.truncationFallback(context)
    }
  }
  
  /**
   * Final fallback: simple truncation
   */
  private truncationFallback(
    context: ConversationContext
  ): CondensationResult {
    const truncated = truncateConversation(
      context.messages,
      0.5,
      context.taskId
    )
    
    return {
      messages: truncated,
      summary: '',
      cost: 0,
      prevContextTokens: context.totalTokens,
      error: 'Condensation failed, truncated 50% of messages'
    }
  }
}

/**
 * Custom error class for condensation failures
 */
export class CondensationError extends Error {
  constructor(
    message: string,
    public code: string,
    public details?: any
  ) {
    super(message)
    this.name = 'CondensationError'
  }
}
```

## 5. Integration Points

### 5.1 Task.ts Integration

```typescript
// In Task.ts

// Import provider manager
import { CondensationProviderManager } from './core/condense/manager'

export class Task {
  private condensationManager: CondensationProviderManager
  
  constructor(...) {
    // ... existing initialization ...
    this.condensationManager = new CondensationProviderManager()
  }
  
  private async handleCondensation(): Promise<void> {
    // Get settings
    const settings = await getCondensationSettings()
    const providerId = settings.provider || 'native'
    
    // Prepare context
    const context: ConversationContext = {
      messages: this.apiConversationHistory,
      systemPrompt: await this.getSystemPrompt(),
      taskId: this.taskId,
      contextWindow: this.api.getInfo().contextWindow,
      maxTokens: this.api.getInfo().maxTokens,
      totalTokens: this.contextTokens || 0,
      apiHandler: this.api
    }
    
    // Prepare options
    const options: CondensationOptions = {
      isAutomaticTrigger: true,
      targetReductionPercent: settings.targetReductionPercent,
      customPrompt: settings.customPrompt,
      condensingApiHandler: settings.condensingApiHandler,
      providerConfig: settings.providerConfig
    }
    
    // Perform condensation
    const result = await this.condensationManager.condense(
      context,
      options,
      providerId
    )
    
    // Handle result
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
          metrics: result.metrics
        }
      )
    }
  }
}
```

### 5.2 Settings Integration

```typescript
// In settings management

export interface CondensationSettings {
  // Provider selection
  provider: 'native' | 'smart'
  
  // Common settings
  autoCondenseContext: boolean
  autoCondenseContextPercent: number
  targetReductionPercent: number
  
  // Native provider specific
  customCondensingPrompt?: string
  condensingApiHandler?: string
  
  // Smart provider specific
  providerConfig: {
    enableLossless: boolean
    enableContentTypeAwareness: boolean
    preservationPriority: MessageType[]
    maxReductionPerPhase: number
  }
}

// Get settings with defaults
export async function getCondensationSettings(): Promise<CondensationSettings> {
  const config = vscode.workspace.getConfiguration('roo-code.condensation')
  
  return {
    provider: config.get('provider', 'native'),
    autoCondenseContext: config.get('autoCondenseContext', true),
    autoCondenseContextPercent: config.get('autoCondenseContextPercent', 80),
    targetReductionPercent: config.get('targetReductionPercent', 50),
    customCondensingPrompt: config.get('customCondensingPrompt'),
    condensingApiHandler: config.get('condensingApiHandler'),
    providerConfig: {
      enableLossless: config.get('smart.enableLossless', true),
      enableContentTypeAwareness: config.get('smart.enableContentTypeAwareness', true),
      preservationPriority: config.get('smart.preservationPriority', [
        MessageType.USER_MESSAGE,
        MessageType.ASSISTANT_MESSAGE,
        MessageType.TOOL_RESULT,
        MessageType.TOOL_CALL
      ]),
      maxReductionPerPhase: config.get('smart.maxReductionPerPhase', 90)
    }
  }
}
```

### 5.3 UI Integration

```typescript
// In SettingsView component

export function CondensationSettings() {
  const [provider, setProvider] = useState<'native' | 'smart'>('native')
  const [showAdvanced, setShowAdvanced] = useState(false)
  
  return (
    <div className="condensation-settings">
      <h3>Context Condensation</h3>
      
      {/* Provider Selection */}
      <div className="setting-row">
        <label>Condensation Strategy</label>
        <select value={provider} onChange={e => setProvider(e.target.value)}>
          <option value="native">Native (Current)</option>
          <option value="smart">Smart (Improved)</option>
        </select>
        <span className="description">
          {provider === 'native' 
            ? 'Current LLM-based summarization strategy'
            : 'Two-phase optimization with content-type awareness'}
        </span>
      </div>
      
      {/* Common Settings */}
      <div className="setting-row">
        <label>Auto-Condense Threshold</label>
        <input type="number" min="5" max="100" />
        <span className="description">
          Trigger condensation at this % of context window
        </span>
      </div>
      
      {/* Provider-Specific Settings */}
      {provider === 'smart' && (
        <div className="smart-settings">
          <div className="setting-row">
            <label>
              <input type="checkbox" checked />
              Enable Lossless Optimization
            </label>
            <span className="description">
              Deduplicate file reads and consolidate tool results
            </span>
          </div>
          
          <div className="setting-row">
            <label>
              <input type="checkbox" checked />
              Content-Type Awareness
            </label>
            <span className="description">
              Prioritize condensation by message type
            </span>
          </div>
          
          <button onClick={() => setShowAdvanced(!showAdvanced)}>
            {showAdvanced ? 'Hide' : 'Show'} Advanced Settings
          </button>
          
          {showAdvanced && (
            <div className="advanced-settings">
              {/* More settings */}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
```

## 6. Sequence Diagrams

### 6.1 Condensation Flow

```
User/Task                Manager              Provider              Phase
    │                       │                    │                    │
    ├─condense()───────────>│                    │                    │
    │                       ├─getProvider()      │                    │
    │                       ├─validateOptions()─>│                    │
    │                       │<─────────────────ok│                    │
    │                       │                    │                    │
    │                       ├─condense()────────>│                    │
    │                       │                    ├─optimize()────────>│
    │                       │                    │<─────────(lossless)│
    │                       │                    ├─condense()────────>│
    │                       │                    │<───────────(lossy)│
    │                       │                    ├─validate()         │
    │                       │<────────────result│                    │
    │                       │                    │                    │
    │<────────────result────│                    │                    │
```

### 6.2 Fallback Flow

```
User/Task                Manager              Provider            Fallback
    │                       │                    │                    │
    ├─condense()───────────>│                    │                    │
    │                       ├─condense()────────>│                    │
    │                       │                    ├─[error]            │
    │                       │<─────────────error│                    │
    │                       │                    │                    │
    │                       ├─try native────────>│                    │
    │                       │                    ├─[error]            │
    │                       │<─────────────error│                    │
    │                       │                                         │
    │                       ├─truncationFallback()──────────────────>│
    │                       │<────────────result──────────────────────│
    │<────────────result────│                                         │
```

## 7. Testing Strategy

### 7.1 Unit Tests

```typescript
describe('NativeCondensationProvider', () => {
  it('should wrap existing summarizeConversation logic', async () => {
    // Test wrapper behavior
  })
  
  it('should return correct capabilities', () => {
    // Test capabilities
  })
  
  it('should validate options correctly', () => {
    // Test validation
  })
})

describe('SmartCondensationProvider', () => {
  it('should run lossless phase when enabled', async () => {
    // Test lossless execution
  })
  
  it('should run lossy phase when needed', async () => {
    // Test lossy execution
  })
  
  it('should skip lossy if target reached in lossless', async () => {
    // Test early termination
  })
  
  it('should validate context did not grow', async () => {
    // Test validation
  })
})

describe('CondensationProviderManager', () => {
  it('should register providers correctly', () => {
    // Test registration
  })
  
  it('should select correct provider', () => {
    // Test selection
  })
  
  it('should fall back on provider failure', async () => {
    // Test fallback
  })
  
  it('should use truncation as final fallback', async () => {
    // Test final fallback
  })
})
```

### 7.2 Integration Tests

```typescript
describe('End-to-end condensation', () => {
  it('should condense using native provider', async () => {
    // Test full flow with native
  })
  
  it('should condense using smart provider', async () => {
    // Test full flow with smart
  })
  
  it('should preserve conversation messages', async () => {
    // Test preservation
  })
  
  it('should handle provider switching', async () => {
    // Test switching
  })
})
```

## 8. Migration Path

### 8.1 Phase 1: Infrastructure (Week 1-2)

1. Create provider interfaces and types
2. Implement ProviderManager
3. Add provider selection setting
4. Update Task.ts integration
5. Comprehensive testing

### 8.2 Phase 2: Native Provider (Week 2)

1. Implement NativeCondensationProvider wrapper
2. Ensure 100% backward compatibility
3. Regression testing
4. Deploy as default

### 8.3 Phase 3: Smart Provider (Week 3-5)

1. Implement lossless phase
2. Implement lossy phase
3. Testing and validation
4. Deploy as opt-in option

### 8.4 Phase 4: Optimization (Week 6-8)

1. Performance tuning
2. User feedback integration
3. Documentation
4. Gradual rollout

## 9. Rollout Strategy

### 9.1 Beta Testing

- Deploy with smart provider as opt-in
- Gather telemetry on effectiveness
- Collect user feedback
- Iterate based on data

### 9.2 General Availability

- Monitor adoption rates
- Analyze effectiveness metrics
- Consider making smart provider default
- Maintain native provider for compatibility

## 10. Success Metrics

**Adoption**:
- % users enabling smart provider
- Provider switching frequency
- Setting configuration patterns

**Effectiveness**:
- Average token reduction per provider
- Conversation preservation quality
- User satisfaction scores
- Support ticket volume

**Performance**:
- Condensation latency
- Memory usage
- Error rates
- Fallback frequency

---

**Next Document**: `004-condensation-strategy.md`