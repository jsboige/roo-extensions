# Provider Architecture Design - Context Condensation System

**Version**: 2.0 - Consolidated  
**Date**: 2025-10-02  
**Status**: Design Specification  
**Consolidates**: Documents 003 (Provider Architecture) + 007 (Native System Deep Dive)

## Executive Summary

This document specifies the technical architecture for a provider-based context condensation system with **API profile integration**. The design introduces an abstraction layer that allows multiple condensation strategies to coexist, with clear separation between:

- **Manager**: Orchestration, profile management, threshold management, and fallback strategies
- **Provider**: Technical implementation of LLM-based condensation, token counting, and cost calculation

The architecture ensures backward compatibility, extensibility, and clear separation of concerns while enabling per-profile optimization for cost and behavior.

---

## 1. Architecture Overview

### 1.1 Design Philosophy

**Core Principles**:
1. **Strategy Pattern**: Encapsulate algorithms in interchangeable providers
2. **Open/Closed**: Open for extension (new providers), closed for modification (core)
3. **Dependency Inversion**: Depend on abstractions (interface), not concretions
4. **Single Responsibility**: Manager handles orchestration, Provider handles implementation
5. **Backward Compatibility**: Existing behavior preserved exactly

### 1.2 High-Level Architecture with API Profiles

```
┌───────────────────────────────────────────────────────────────┐
│                         Task.ts                               │
│     (Orchestrates condensation via ProviderManager)           │
└────────────────────┬──────────────────────────────────────────┘
                     │
                     ▼
┌───────────────────────────────────────────────────────────────┐
│              CondensationProviderManager                      │
│  - Manages API profiles and thresholds                        │
│  - Selects provider based on configuration                    │
│  - Determines effective threshold per profile                 │
│  - Handles provider failures and fallbacks                    │
│  - Tracks costs and metrics                                   │
└────────────────────┬──────────────────────────────────────────┘
                     │
                     ▼
┌───────────────────────────────────────────────────────────────┐
│           ICondensationProvider (Interface)                   │
│  - condense(context, config)                                  │
│  - estimateCost(context, config): dynamic per profile         │
│  - estimateReduction(context)                                 │
│  - getCapabilities()                                          │
└────────────────────┬──────────────────────────────────────────┘
                     │
         ┌───────────┴────────────┐
         ▼                        ▼
┌──────────────────┐     ┌──────────────────┐
│ NativeProvider   │     │  SmartProvider   │
│  (Current logic) │     │  (Improved)      │
│                  │     │                  │
│ Uses profiles:   │     │ Uses profiles:   │
│ - API handler    │     │ - API handler    │
│ - Custom prompt  │     │ - Custom prompt  │
│ - Cost calc      │     │ - 2-phase logic  │
└──────────────────┘     └─────────┬────────┘
                                   │
                         ┌─────────┴─────────┐
                         ▼                   ▼
               ┌────────────────┐  ┌────────────────┐
               │ LosslessPhase  │  │  LossyPhase    │
               └────────────────┘  └────────────────┘
```

### 1.3 Responsibility Separation

#### 🔵 Manager Responsibilities (Orchestration)

```typescript
CondensationProviderManager {
  // ✅ API Profile Management
  - getEffectiveConfig(profileId): CondensationConfig
  - setProfileThreshold(profileId, threshold)
  - getProfileApiHandler(profileId): ApiHandler
  
  // ✅ Threshold Determination
  - shouldCondense(tokens, contextWindow, profileId): boolean
  - calculateEffectiveThreshold(profileId): number
  
  // ✅ Orchestration
  - condenseIfNeeded(context, options): Promise<Result>
  - selectProvider(config): ICondensationProvider
  
  // ✅ Fallback Strategy
  - handleProviderFailure(error): Result
  - truncationFallback(messages): Result
  
  // ✅ Metrics & Tracking
  - trackCost(cost, profileId)
  - getMetrics(): AggregatedMetrics
}
```

#### 🟢 Provider Responsibilities (Technical)

```typescript
ICondensationProvider {
  // ✅ LLM Operations
  - condense(context, config): Promise<Result>
  - selectHandler(config): ApiHandler
  - selectPrompt(config): string
  - streamLLMResponse(handler, prompt, messages)
  
  // ✅ Token Management
  - countTokens(content, handler): Promise<number>
  - estimateReduction(context): Promise<TokenEstimate>
  
  // ✅ Cost Calculation
  - calculateCost(usage, modelInfo, isAnthropic): number
  - estimateCost(context, config): Promise<CostEstimate>
  
  // ✅ Capabilities
  - getCapabilities(): ProviderCapabilities
  - validateOptions(options): ValidationResult
}
```

---

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
   * @param config - Configuration including API profile settings
   * @returns Promise resolving to the condensation result
   * @throws CondensationError if condensation fails unrecoverably
   */
  condense(
    context: ConversationContext,
    config: CondensationConfig
  ): Promise<CondensationResult>
  
  /**
   * Estimate the cost of condensation for given context and config.
   * This is profile-aware and returns different costs based on the API handler.
   * 
   * @param context - The conversation context to analyze
   * @param config - Configuration with specific API profile
   * @returns Promise resolving to estimated cost metrics
   */
  estimateCost(
    context: ConversationContext,
    config: CondensationConfig
  ): Promise<CostEstimate>
  
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
   * @param config - Configuration to validate
   * @returns Validation result with errors if any
   */
  validateConfig(
    config: CondensationConfig
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
  
  /** Default API handler (fallback) */
  apiHandler: ApiHandler
}

/**
 * Configuration for condensation operation with API profile support
 */
export interface CondensationConfig {
  /** Default API handler (fallback) */
  apiHandler: ApiHandler
  
  /** Profile-specific API handler for condensation */
  condensingApiHandler?: ApiHandler
  
  /** Default system prompt (fallback) */
  systemPrompt: string
  
  /** Profile-specific custom prompt */
  customPrompt?: string
  
  /** Current token count before condensation */
  prevContextTokens: number
  
  /** Task identifier for telemetry */
  taskId: string
  
  /** Whether this is automatic (vs manual) trigger */
  isAutomatic: boolean
  
  /** API profile identifier (for metrics and tracking) */
  profileId?: string
  
  /** Target reduction percentage (0-100) */
  targetReductionPercent?: number
  
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
  
  /** API profile used for condensation */
  profileUsed?: string
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
 * Estimated cost for condensation operation
 */
export interface CostEstimate {
  /** Estimated input tokens */
  estimatedInputTokens: number
  
  /** Estimated output tokens */
  estimatedOutputTokens: number
  
  /** Estimated cache creation tokens (if applicable) */
  estimatedCacheCreationTokens?: number
  
  /** Estimated cache read tokens (if applicable) */
  estimatedCacheReadTokens?: number
  
  /** Total estimated cost in USD */
  estimatedCost: number
  
  /** Model information used for estimation */
  modelInfo: ModelInfo
  
  /** Confidence level (0-1) */
  confidence: number
  
  /** Breakdown by component */
  breakdown?: {
    baseInputCost: number
    outputCost: number
    cacheWriteCost?: number
    cacheReadCost?: number
  }
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
  
  /** Supports API profile selection */
  supportsApiProfiles: boolean
  
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

---

## 3. Provider Manager with API Profiles

### 3.1 CondensationProviderManager

```typescript
/**
 * Manages provider lifecycle, API profiles, threshold management,
 * and fallback logic. Central orchestrator for condensation operations.
 */
export class CondensationProviderManager {
  private providers: Map<string, ICondensationProvider>
  private defaultProviderId: string = 'native'
  
  // API Profile Management
  private apiProfiles: Map<string, ApiProfile>
  private globalThreshold: number = 75
  private profileThresholds: Map<string, number>
  
  constructor() {
    this.providers = new Map()
    this.apiProfiles = new Map()
    this.profileThresholds = new Map()
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
   * Register an API profile for condensation
   */
  registerApiProfile(profile: ApiProfile): void {
    this.apiProfiles.set(profile.id, profile)
  }
  
  /**
   * Set threshold for a specific API profile
   * @param profileId - API profile identifier
   * @param threshold - Threshold percentage (5-100) or -1 to inherit global
   */
  setProfileThreshold(profileId: string, threshold: number): void {
    if (threshold === -1) {
      // Inherit from global
      this.profileThresholds.delete(profileId)
    } else if (threshold >= MIN_CONDENSE_THRESHOLD && 
               threshold <= MAX_CONDENSE_THRESHOLD) {
      this.profileThresholds.set(profileId, threshold)
    } else {
      console.warn(
        `Invalid threshold ${threshold} for profile ${profileId}, ` +
        `must be between ${MIN_CONDENSE_THRESHOLD} and ${MAX_CONDENSE_THRESHOLD}`
      )
    }
  }
  
  /**
   * Get effective threshold for a profile (with inheritance)
   */
  getEffectiveThreshold(profileId?: string): number {
    if (!profileId) {
      return this.globalThreshold
    }
    
    const profileThreshold = this.profileThresholds.get(profileId)
    if (profileThreshold !== undefined) {
      return profileThreshold
    }
    
    // Inherit from global
    return this.globalThreshold
  }
  
  /**
   * Get effective condensation configuration for a profile
   */
  getEffectiveConfig(
    context: ConversationContext,
    options: {
      profileId?: string
      customPrompt?: string
      condensingApiConfigId?: string
      isAutomatic: boolean
    }
  ): CondensationConfig {
    const profile = options.profileId 
      ? this.apiProfiles.get(options.profileId)
      : undefined
    
    const condensingApiHandler = options.condensingApiConfigId
      ? this.getApiHandlerById(options.condensingApiConfigId)
      : undefined
    
    return {
      apiHandler: context.apiHandler,
      condensingApiHandler,
      systemPrompt: context.systemPrompt,
      customPrompt: options.customPrompt || profile?.customPrompt,
      prevContextTokens: context.totalTokens,
      taskId: context.taskId,
      isAutomatic: options.isAutomatic,
      profileId: options.profileId,
      targetReductionPercent: 50 // Default, can be overridden
    }
  }
  
  /**
   * Determine if condensation should be triggered
   */
  shouldCondense(
    tokens: number,
    contextWindow: number,
    maxTokens: number,
    profileId?: string
  ): boolean {
    const effectiveThreshold = this.getEffectiveThreshold(profileId)
    
    // Calculate allowed tokens with safety buffer
    const reservedTokens = maxTokens || ANTHROPIC_DEFAULT_MAX_TOKENS
    const allowedTokens = contextWindow * (1 - TOKEN_BUFFER_PERCENTAGE) - reservedTokens
    
    // Trigger if:
    // 1. Percentage >= effective threshold OR
    // 2. Absolute tokens > allowed tokens
    const contextPercent = (100 * tokens) / contextWindow
    return contextPercent >= effectiveThreshold || tokens > allowedTokens
  }
  
  /**
   * Condense using specified or default provider with profile support
   */
  async condenseIfNeeded(
    context: ConversationContext,
    options: {
      profileId?: string
      customPrompt?: string
      condensingApiConfigId?: string
      isAutomatic: boolean
      providerId?: string
    }
  ): Promise<CondensationResult> {
    // Check if condensation is needed
    if (!this.shouldCondense(
      context.totalTokens,
      context.contextWindow,
      context.maxTokens,
      options.profileId
    )) {
      return {
        messages: context.messages,
        summary: '',
        cost: 0,
        prevContextTokens: context.totalTokens,
        error: 'Condensation not needed'
      }
    }
    
    // Get effective configuration
    const config = this.getEffectiveConfig(context, options)
    
    // Select provider
    const providerId = options.providerId || this.defaultProviderId
    let provider = this.providers.get(providerId)
    
    if (!provider) {
      console.warn(`Provider ${providerId} not found, using default`)
      provider = this.getDefaultProvider()
    }
    
    // Validate configuration
    const validation = provider.validateConfig(config)
    if (!validation.valid) {
      console.error('Provider config validation failed:', validation.errors)
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
      const result = await provider.condense(context, config)
      
      // Validate result
      if (result.error) {
        throw new CondensationError(
          result.error,
          'PROVIDER_ERROR'
        )
      }
      
      // Track metrics
      this.trackCondensation(result, options.profileId)
      
      return result
      
    } catch (error) {
      console.error(`Provider ${providerId} failed:`, error)
      
      // Fallback to native if not already using it
      if (providerId !== 'native') {
        console.log('Falling back to native provider')
        const nativeProvider = this.providers.get('native')!
        return nativeProvider.condense(context, config)
      }
      
      // If native also fails, fall back to truncation
      console.log('Native provider failed, using truncation fallback')
      return this.truncationFallback(context)
    }
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
  
  /**
   * Track condensation metrics
   */
  private trackCondensation(result: CondensationResult, profileId?: string): void {
    // TODO: Implement telemetry tracking
    console.log(`Condensation completed for profile ${profileId}:`, {
      cost: result.cost,
      reduction: result.metrics?.reductionPercent,
      tokensSaved: result.metrics?.totalTokensSaved
    })
  }
  
  /**
   * Get API handler by configuration ID
   */
  private getApiHandlerById(configId: string): ApiHandler | undefined {
    // TODO: Integrate with API configuration system
    return undefined
  }
}

/**
 * API Profile definition
 */
export interface ApiProfile {
  id: string
  name: string
  apiConfigId: string
  customPrompt?: string
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

// Constants
export const MIN_CONDENSE_THRESHOLD = 5
export const MAX_CONDENSE_THRESHOLD = 100
export const TOKEN_BUFFER_PERCENTAGE = 0.1
export const ANTHROPIC_DEFAULT_MAX_TOKENS = 8192
export const N_MESSAGES_TO_KEEP = 3
```

---

## 4. Native Provider Implementation

### 4.1 NativeCondensationProvider with API Profiles

```typescript
/**
 * Provider that wraps the existing condensation logic for backward compatibility.
 * Maintains exact behavior of current implementation with full API profile support.
 */
export class NativeCondensationProvider implements ICondensationProvider {
  readonly id = 'native'
  readonly name = 'Native (Current)'
  readonly description = 'Current condensation strategy using LLM summarization with API profile support'
  readonly version = '2.0.0'
  
  async condense(
    context: ConversationContext,
    config: CondensationConfig
  ): Promise<CondensationResult> {
    // Select handler (profile-specific or default)
    const handler = this.selectHandler(config)
    
    // Validate handler
    if (!handler || typeof handler.createMessage !== 'function') {
      console.warn('Invalid handler, falling back to default')
      if (!config.apiHandler || typeof config.apiHandler.createMessage !== 'function') {
        return {
          messages: context.messages,
          summary: '',
          cost: 0,
          prevContextTokens: context.prevContextTokens,
          error: 'No valid API handler available'
        }
      }
    }
    
    // Select prompt (custom or default)
    const prompt = this.selectPrompt(config)
    
    // Prepare messages for summarization
    const messagesToSummarize = this.getMessagesSinceLastSummary(
      context.messages.slice(0, -N_MESSAGES_TO_KEEP)
    )
    
    if (messagesToSummarize.length <= 1) {
      return {
        messages: context.messages,
        summary: '',
        cost: 0,
        prevContextTokens: config.prevContextTokens,
        error: 'Not enough messages to condense'
      }
    }
    
    // Check for recent summary
    const keepMessages = context.messages.slice(-N_MESSAGES_TO_KEEP)
    const recentSummaryExists = keepMessages.some(msg => msg.isSummary)
    
    if (recentSummaryExists) {
      return {
        messages: context.messages,
        summary: '',
        cost: 0,
        prevContextTokens: config.prevContextTokens,
        error: 'Recently condensed, skipping'
      }
    }
    
    // Build request messages
    const requestMessages = this.buildRequestMessages(
      messagesToSummarize,
      config.systemPrompt
    )
    
    // Stream LLM response
    const stream = handler.createMessage(prompt, requestMessages)
    
    let summary = ''
    let cost = 0
    let outputTokens = 0
    
    for await (const chunk of stream) {
      if (chunk.type === 'text') {
        summary += chunk.text
      } else if (chunk.type === 'usage') {
        const modelInfo = handler.getInfo()
        const isAnthropic = modelInfo.supportsPromptCache ?? false
        
        cost = this.calculateCost(
          chunk,
          modelInfo,
          isAnthropic
        )
        outputTokens = chunk.outputTokens ?? 0
      }
    }
    
    // Build result messages
    const firstMessage = context.messages[0]
    const summaryMessage: ApiMessage = {
      role: 'user',
      content: [{ type: 'text', text: summary }],
      isSummary: true
    }
    
    const newMessages = [firstMessage, summaryMessage, ...keepMessages]
    
    // Count new context tokens
    const contextBlocks = newMessages.flatMap(msg => 
      Array.isArray(msg.content) ? msg.content : [msg.content]
    )
    const newContextTokens = outputTokens + 
      (await handler.countTokens(contextBlocks))
    
    // Validate reduction
    if (newContextTokens >= config.prevContextTokens) {
      return {
        messages: context.messages,
        summary: '',
        cost,
        prevContextTokens: config.prevContextTokens,
        error: 'Context grew during condensation'
      }
    }
    
    return {
      messages: newMessages,
      summary,
      cost,
      newContextTokens,
      prevContextTokens: config.prevContextTokens,
      profileUsed: config.profileId,
      metrics: {
        totalTokensSaved: config.prevContextTokens - newContextTokens,
        reductionPercent: ((config.prevContextTokens - newContextTokens) / config.prevContextTokens) * 100,
        phasesExecuted: ['lossy'],
        timeElapsed: 0
      }
    }
  }
  
  async estimateCost(
    context: ConversationContext,
    config: CondensationConfig
  ): Promise<CostEstimate> {
    const handler = this.selectHandler(config)
    const modelInfo = handler.getInfo()
    
    // Estimate input tokens (messages to summarize)
    const messagesToSummarize = this.getMessagesSinceLastSummary(
      context.messages.slice(0, -N_MESSAGES_TO_KEEP)
    )
    
    const contentBlocks = messagesToSummarize.flatMap(msg =>
      Array.isArray(msg.content) ? msg.content : [msg.content]
    )
    
    const estimatedInputTokens = await handler.countTokens(contentBlocks)
    
    // Estimate output tokens (typically 5-10% of input)
    const estimatedOutputTokens = Math.floor(estimatedInputTokens * 0.07)
    
    // Calculate cost
    const isAnthropic = modelInfo.supportsPromptCache ?? false
    const estimatedCost = this.calculateCostFromEstimate(
      estimatedInputTokens,
      estimatedOutputTokens,
      modelInfo,
      isAnthropic
    )
    
    return {
      estimatedInputTokens,
      estimatedOutputTokens,
      estimatedCost,
      modelInfo,
      confidence: 0.7,
      breakdown: {
        baseInputCost: ((modelInfo.inputPrice || 0) / 1_000_000) * estimatedInputTokens,
        outputCost: ((modelInfo.outputPrice || 0) / 1_000_000) * estimatedOutputTokens
      }
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
      supportsApiProfiles: true,
      configurableOptions: ['customPrompt', 'condensingApiHandler', 'profileId']
    }
  }
  
  validateConfig(config: CondensationConfig): ValidationResult {
    const errors: ValidationError[] = []
    const warnings: ValidationWarning[] = []
    
    // Validate custom prompt if provided
    if (config.customPrompt && config.customPrompt.trim().length === 0) {
      warnings.push({
        field: 'customPrompt',
        message: 'Custom prompt is empty, will use default prompt'
      })
    }
    
    // Validate handlers
    if (config.condensingApiHandler && 
        typeof config.condensingApiHandler.createMessage !== 'function') {
      errors.push({
        field: 'condensingApiHandler',
        message: 'Invalid API handler, missing createMessage method',
        code: 'INVALID_HANDLER'
      })
    }
    
    return { valid: errors.length === 0, errors, warnings }
  }
  
  /**
   * Select the appropriate API handler based on configuration
   */
  private selectHandler(config: CondensationConfig): ApiHandler {
    // Priority: profile-specific handler > default handler
    return config.condensingApiHandler || config.apiHandler
  }
  
  /**
   * Select the appropriate prompt based on configuration
   */
  private selectPrompt(config: CondensationConfig): string {
    // Priority: custom prompt > default prompt
    return config.customPrompt?.trim() || SUMMARY_PROMPT
  }
  
  /**
   * Get messages since last summary
   */
  private getMessagesSinceLastSummary(messages: ApiMessage[]): ApiMessage[] {
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isSummary) {
        return messages.slice(i + 1)
      }
    }
    return messages
  }
  
  /**
   * Build request messages for LLM
   */
  private buildRequestMessages(
    messages: ApiMessage[],
    systemPrompt: string
  ): ApiMessage[] {
    // Build context from messages
    let context = ''
    for (const msg of messages) {
      const content = Array.isArray(msg.content) 
        ? msg.content.map(c => c.type === 'text' ? c.text : '').join('\n')
        : msg.content
      context += `${msg.role}: ${content}\n\n`
    }
    
    return [{
      role: 'user',
      content: [{
        type: 'text',
        text: `${systemPrompt}\n\n${context}`
      }]
    }]
  }
  
  /**
   * Calculate cost based on usage and model info
   */
  private calculateCost(
    usage: any,
    modelInfo: ModelInfo,
    isAnthropic: boolean
  ): number {
    if (isAnthropic) {
      return calculateApiCostAnthropic(
        modelInfo,
        usage.inputTokens ?? 0,
        usage.outputTokens ?? 0,
        usage.cacheCreationInputTokens,
        usage.cacheReadInputTokens
      )
    } else {
      return calculateApiCostOpenAI(
        modelInfo,
        usage.inputTokens ?? 0,
        usage.outputTokens ?? 0,
        usage.cacheCreationInputTokens,
        usage.cacheReadInputTokens
      )
    }
  }
  
  /**
   * Calculate cost from estimates
   */
  private calculateCostFromEstimate(
    inputTokens: number,
    outputTokens: number,
    modelInfo: ModelInfo,
    isAnthropic: boolean
  ): number {
    if (isAnthropic) {
      return calculateApiCostAnthropic(
        modelInfo,
        inputTokens,
        outputTokens,
        0,
        0
      )
    } else {
      return calculateApiCostOpenAI(
        modelInfo,
        inputTokens,
        outputTokens,
        0,
        0
      )
    }
  }
}

/**
 * Default summary prompt
 */
const SUMMARY_PROMPT = `Summarize the conversation history concisely while preserving key context...`
```

---

## 5. Sequence Diagrams

### 5.1 Condensation Flow with API Profiles

```
Task              Manager                Provider           ApiHandler
 │                  │                       │                   │
 │ condenseIfNeeded │                       │                   │
 ├─────────────────>│                       │                   │
 │                  │ getEffectiveThreshold │                   │
 │                  ├────────────────────>  │                   │
 │                  │<────────threshold─────│                   │
 │                  │                       │                   │
 │                  │ shouldCondense()      │                   │
 │                  ├───────────────────>   │                   │
 │                  │<────────yes───────────│                   │
 │                  │                       │                   │
 │                  │ getEffectiveConfig()  │                   │
 │                  ├─ (profileId,          │                   │
 │                  │   condensingApiConfigId)                  │
 │                  │<───────config─────────│                   │
 │                  │                       │                   │
 │                  │ validateConfig()      │                   │
 │                  ├──────────────────────>│                   │
 │                  │<───────ok─────────────│                   │
 │                  │                       │                   │
 │                  │ estimateCost()        │                   │
 │                  ├──────────────────────>│                   │
 │                  │                       │ countTokens()     │
 │                  │                       ├──────────────────>│
 │                  │                       │<────tokens────────│
 │                  │<───costEstimate───────│                   │
 │                  │                       │                   │
 │                  │ condense()            │                   │
 │                  ├──────────────────────>│                   │
 │                  │                       │ selectHandler()   │
 │                  │                       ├──(profile-aware)  │
 │                  │                       │                   │
 │                  │                       │ createMessage()   │
 │                  │                       ├──────────────────>│
 │                  │                       │<────stream────────│
 │                  │                       │ calculateCost()   │
 │                  │<───────result─────────│                   │
 │                  │                       │                   │
 │                  │ trackCondensation()   │                   │
 │<────result───────│                       │                   │
```

### 5.2 Cost Comparison: Default vs Optimized Profile

```
Scenario 1: Default Profile (Claude Sonnet 4)
─────────────────────────────────────────────

Manager: getEffectiveConfig(profileId: "claude-sonnet")
    → apiHandler: Claude Sonnet 4 API
    → threshold: 75% (global)

Provider: estimateCost()
    → Input: 20,000 tokens × $3.00/1M = $0.060
    → Output: 1,400 tokens × $15.00/1M = $0.021
    → Total: $0.081

Provider: condense()
    → Uses Claude Sonnet 4
    → Cost: ~$0.075-0.085


Scenario 2: Optimized Profile (GPT-4o-mini)
─────────────────────────────────────────────

Manager: getEffectiveConfig(profileId: "gpt-4o-mini")
    → condensingApiHandler: GPT-4o-mini API
    → threshold: 80% (profile-specific)
    → customPrompt: "Concise summary..."

Provider: estimateCost()
    → Input: 20,000 tokens × $0.15/1M = $0.003
    → Output: 1,400 tokens × $0.60/1M = $0.0008
    → Total: $0.0038

Provider: condense()
    → Uses GPT-4o-mini
    → Cost: ~$0.003-0.005

Savings: 95.2% ($0.077 saved per condensation)
```

### 5.3 Threshold Determination Flow

```
Manager                   ProfileThresholds         Config
   │                            │                      │
   │ getEffectiveThreshold()    │                      │
   ├───────────────────────────>│                      │
   │                            │                      │
   │                profileThresholds.get(profileId)   │
   │<─────────────────────────  │                      │
   │                            │                      │
   ├── if undefined: use global threshold              │
   │                            │                      │
   ├── if -1: inherit global    │                      │
   │                            │                      │
   ├── if valid (5-100): use it │                      │
   │                            │                      │
   ├── if invalid: warn + global│                      │
   │                            │                      │
   │<──────effectiveThreshold───│                      │
   │                            │                      │
   │ shouldCondense(tokens, contextWindow, effectiveThreshold)
   ├────────────────────────────────────────────────> │
   │                                                   │
   │ contextPercent = (tokens / contextWindow) × 100  │
   │ allowedTokens = contextWindow × 0.9 - maxTokens  │
   │                                                   │
   │ if contextPercent >= threshold OR                │
   │    tokens > allowedTokens:                       │
   │     return true                                  │
   │<─────────────────────────────────────────────────│
```

---

## 6. Configuration Examples

### 6.1 Default Configuration (Backward Compatible)

```typescript
// No API profile customization
const manager = new CondensationProviderManager()

// Uses global threshold (75%)
// Uses current API handler
// Uses default summary prompt
// Expected cost: ~$0.02-0.04 per condensation

await manager.condenseIfNeeded(context, {
  isAutomatic: true
})
```

### 6.2 Cost-Optimized Profile

```typescript
// Configure optimized profile
const manager = new CondensationProviderManager()

manager.registerApiProfile({
  id: 'gpt-4o-mini',
  name: 'GPT-4o-mini (Cost Optimized)',
  apiConfigId: 'openai-gpt-4o-mini',
  customPrompt: 'Provide a concise summary focusing on key decisions.'
})

manager.setProfileThreshold('gpt-4o-mini', 80) // Less frequent condensation

// Use optimized profile
await manager.condenseIfNeeded(context, {
  profileId: 'gpt-4o-mini',
  condensingApiConfigId: 'openai-gpt-4o-mini',
  isAutomatic: true
})

// Expected cost: ~$0.003-0.005 per condensation (95% savings)
```

### 6.3 Custom Prompt per Profile

```typescript
// Business-specific profile
manager.registerApiProfile({
  id: 'business-context',
  name: 'Business Context Preservation',
  apiConfigId: 'claude-sonnet',
  customPrompt: `
Summarize this technical conversation while preserving:
1. Architectural decisions made
2. Technical problems solved
3. Outstanding issues
4. Business-specific context
  `.trim()
})

manager.setProfileThreshold('business-context', 70) // More aggressive

await manager.condenseIfNeeded(context, {
  profileId: 'business-context',
  condensingApiConfigId: 'claude-sonnet',
  customPrompt: manager.apiProfiles.get('business-context').customPrompt,
  isAutomatic: true
})
```

### 6.4 Profile Inheritance

```typescript
// Profile inherits global threshold
manager.setProfileThreshold('my-profile', -1) // Inherit

// Effective threshold will be global (75%)
const threshold = manager.getEffectiveThreshold('my-profile') // → 75

// Custom threshold for another profile
manager.setProfileThreshold('aggressive-profile', 60)
const aggressiveThreshold = manager.getEffectiveThreshold('aggressive-profile') // → 60
```

---

## 7. Integration Points

### 7.1 Task.ts Integration

```typescript
// In Task.ts

import { CondensationProviderManager } from './core/condense/manager'

export class Task {
  private condensationManager: CondensationProviderManager
  
  constructor(...) {
    // ... existing initialization ...
    this.condensationManager = new CondensationProviderManager()
    this.initializeCondensationProfiles()
  }
  
  private initializeCondensationProfiles(): void {
    // Load profiles from configuration
    const settings = vscode.workspace.getConfiguration('roo-code.condensation')
    
    // Register profiles
    const profiles = settings.get<ApiProfile[]>('profiles', [])
    profiles.forEach(profile => {
      this.condensationManager.registerApiProfile(profile)
    })
    
    // Set profile thresholds
    const thresholds = settings.get<Record<string, number>>('profileThresholds', {})
    Object.entries(thresholds).forEach(([profileId, threshold]) => {
      this.condensationManager.setProfileThreshold(profileId, threshold)
    })
  }
  
  private async handleCondensation(): Promise<void> {
    // Get current API configuration
    const currentProfileId = this.api.getInfo().id
    
    // Get settings
    const settings = vscode.workspace.getConfiguration('roo-code.condensation')
    const condensingApiConfigId = settings.get<string>('condensingApiConfigId')
    const customPrompt = settings.get<string>('customCondensingPrompt')
    
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
    
    try {
      // Perform condensation with profile support
      const result = await this.condensationManager.condenseIfNeeded(
        context,
        {
          profileId: currentProfileId,
          condensingApiConfigId,
          customPrompt,
          isAutomatic: true
        }
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

### 7.2 Settings Schema

```json
{
  "roo-code.condensation": {
    "provider": {
      "type": "string",
      "enum": ["native", "smart"],
      "default": "native",
      "description": "Condensation provider to use"
    },
    "autoCondenseContext": {
      "type": "boolean",
      "default": true,
      "description": "Enable automatic condensation"
    },
    "autoCondenseContextPercent": {
      "type": "number",
      "default": 75,
      "minimum": 5,
      "maximum": 100,
      "description": "Global threshold for triggering condensation (%)"
    },
    "condensingApiConfigId": {
      "type": "string",
      "description": "API configuration ID for condensation (optional)"
    },
    "customCondensingPrompt": {
      "type": "string",
      "description": "Custom prompt for summarization (optional)"
    },
    "profiles": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "name": { "type": "string" },
          "apiConfigId": { "type": "string" },
          "customPrompt": { "type": "string" }
        }
      },
      "default": [],
      "description": "API profiles for condensation"
    },
    "profileThresholds": {
      "type": "object",
      "additionalProperties": {
        "type": "number"
      },
      "default": {},
      "description": "Per-profile thresholds (-1 to inherit global)"
    }
  }
}
```

---

## 8. Testing Strategy

### 8.1 Unit Tests

```typescript
describe('CondensationProviderManager', () => {
  describe('API Profile Management', () => {
    it('should register API profile', () => {
      const manager = new CondensationProviderManager()
      manager.registerApiProfile({
        id: 'test-profile',
        name: 'Test Profile',
        apiConfigId: 'test-config'
      })
      // Verify profile registered
    })
    
    it('should set profile threshold', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test-profile', 80)
      expect(manager.getEffectiveThreshold('test-profile')).toBe(80)
    })
    
    it('should inherit global threshold when profile threshold is -1', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test-profile', -1)
      expect(manager.getEffectiveThreshold('test-profile')).toBe(75) // global default
    })
    
    it('should fallback to global for invalid threshold', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test-profile', 150) // invalid
      expect(manager.getEffectiveThreshold('test-profile')).toBe(75)
    })
  })
  
  describe('Configuration', () => {
    it('should get effective config with profile', () => {
      const manager = new CondensationProviderManager()
      const config = manager.getEffectiveConfig(context, {
        profileId: 'gpt-4o-mini',
        condensingApiConfigId: 'openai-config',
        isAutomatic: true
      })
      expect(config.profileId).toBe('gpt-4o-mini')
    })
  })
  
  describe('Condensation Decision', () => {
    it('should condense when threshold exceeded', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test-profile', 70)
      
      const shouldCondense = manager.shouldCondense(
        7500, // tokens
        10000, // context window
        1000, // max tokens
        'test-profile'
      )
      expect(shouldCondense).toBe(true) // 75% > 70%
    })
    
    it('should not condense below threshold', () => {
      const manager = new CondensationProviderManager()
      manager.setProfileThreshold('test-profile', 80)
      
      const shouldCondense = manager.shouldCondense(
        7000,
        10000,
        1000,
        'test-profile'
      )
      expect(shouldCondense).toBe(false) // 70% < 80%
    })
  })
})

describe('NativeCondensationProvider', () => {
  describe('Cost Estimation', () => {
    it('should estimate cost with profile-specific handler', async () => {
      const provider = new NativeCondensationProvider()
      const config = {
        apiHandler: claudeHandler,
        condensingApiHandler: gptMiniHandler,
        // ... other config
      }
      
      const estimate = await provider.estimateCost(context, config)
      
      expect(estimate.modelInfo.id).toBe('gpt-4o-mini')
      expect(estimate.estimatedCost).toBeLessThan(0.01)
    })
  })
  
  describe('Handler Selection', () => {
    it('should use profile-specific handler when provided', async () => {
      const provider = new NativeCondensationProvider()
      const config = {
        apiHandler: claudeHandler,
        condensingApiHandler: gptMiniHandler,
        // ... other config
      }
      
      const result = await provider.condense(context, config)
      expect(result.profileUsed).toBeDefined()
    })
    
    it('should fallback to default handler when profile handler invalid', async () => {
      const provider = new NativeCondensationProvider()
      const config = {
        apiHandler: claudeHandler,
        condensingApiHandler: null, // invalid
        // ... other config
      }
      
      const result = await provider.condense(context, config)
      expect(result.error).toBeUndefined()
    })
  })
})
```

### 8.2 Integration Tests

```typescript
describe('End-to-end Condensation with Profiles', () => {
  it('should condense using default profile', async () => {
    const manager = new CondensationProviderManager()
    const result = await manager.condenseIfNeeded(context, {
      isAutomatic: true
    })
    expect(result.error).toBeUndefined()
    expect(result.newContextTokens).toBeLessThan(context.totalTokens)
  })
  
  it('should condense using optimized profile', async () => {
    const manager = new CondensationProviderManager()
    
    manager.registerApiProfile({
      id: 'gpt-mini',
      name: 'GPT-4o-mini',
      apiConfigId: 'openai-mini'
    })
    
    const result = await manager.condenseIfNeeded(context, {
      profileId: 'gpt-mini',
      condensingApiConfigId: 'openai-mini',
      isAutomatic: true
    })
    
    expect(result.cost).toBeLessThan(0.01) // Should be cheap
    expect(result.profileUsed).toBe('gpt-mini')
  })
  
  it('should respect profile-specific threshold', async () => {
    const manager = new CondensationProviderManager()
    manager.setProfileThreshold('test-profile', 90) // High threshold
    
    // Context at 85% should not trigger
    const result = await manager.condenseIfNeeded(
      { ...context, totalTokens: 8500 }, // 85% of 10k
      {
        profileId: 'test-profile',
        isAutomatic: true
      }
    )
    
    expect(result.error).toContain('not needed')
  })
})
```

---

## 9. Migration & Rollout

### 9.1 Phase 1: Infrastructure (Week 1-2)

1. ✅ Create provider interfaces with `estimateCost()` support
2. ✅ Implement `CondensationProviderManager` with profile management
3. ✅ Add profile threshold configuration
4. ✅ Update Task.ts integration
5. ✅ Comprehensive testing

### 9.2 Phase 2: Native Provider (Week 2-3)

1. ✅ Implement `NativeCondensationProvider` with profile support
2. ✅ Ensure 100% backward compatibility
3. ✅ Add cost estimation per profile
4. ✅ Regression testing
5. ✅ Deploy as default

### 9.3 Phase 3: Smart Provider (Week 4-6)

1. 🔄 Implement `SmartCondensationProvider`
2. 🔄 Implement lossless phase
3. 🔄 Implement lossy phase with profile awareness
4. 🔄 Testing and validation
5. 🔄 Deploy as opt-in option

### 9.4 Phase 4: Optimization (Week 7-8)

1. 📝 Performance tuning
2. 📝 User feedback integration
3. 📝 Documentation and examples
4. 📝 Gradual rollout

---

## 10. Conclusion

### 10.1 Key Improvements in Version 2.0

| Feature | Version 1.0 | Version 2.0 |
|---------|-------------|-------------|
| **API Profiles** | ❌ None | ✅ Full support |
| **Dynamic Thresholds** | ❌ Global only | ✅ Per-profile with inheritance |
| **Cost Estimation** | ❌ Static | ✅ Dynamic per profile |
| **Handler Selection** | ❌ Single | ✅ Profile-aware with fallback |
| **Custom Prompts** | ⚠️ Global | ✅ Per-profile support |
| **Cost Optimization** | ❌ None | ✅ Up to 95% savings |

### 10.2 Benefits

**For Users**:
- 💰 **Cost Optimization**: Choose cheaper models for condensation (95% savings)
- 🎯 **Flexibility**: Different strategies per profile
- ⚙️ **Control**: Per-profile thresholds and prompts

**For Developers**:
- 🧩 **Maintainability**: Clear separation Manager/Provider
- 🧪 **Testability**: Mockable interfaces
- 📈 **Extensibility**: Easy to add new providers
- 🔄 **Backward Compatible**: Existing behavior preserved

### 10.3 Example Cost Comparison

```typescript
// Default Configuration (Claude Sonnet 4)
// Average condensation: $0.075
// 10 condensations/day × 30 days = 300/month
// Monthly cost: $22.50

// Optimized Configuration (GPT-4o-mini)
// Average condensation: $0.004
// 10 condensations/day × 30 days = 300/month
// Monthly cost: $1.20

// Savings: $21.30/month (95% reduction)
```

---

**Next Document**: `004-condensation-strategy.md` (Progressive Strategy with Content-Type Awareness)