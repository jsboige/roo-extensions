# Refined Pass-Based Architecture - Final Design

**Date**: 2025-10-02  
**Version**: 4.0 (Final Refined Architecture)  
**Status**: Production Design

## Executive Summary

This document presents the **final refined architecture** based on user feedback and deep analysis of the native system. The key innovation is a **modular pass-based system** where condensation is configured as a sequence of passes, each with fine-grained control over content types and operations.

## 1. Core Architecture Principles

### 1.1 Pass-Based Philosophy

**Key Insight**: Instead of fixed phases (lossless, lossy, LLM, fallback), we have **configurable passes** that can be chained with execution conditions.

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

### 1.2 Three-Level Content Model

**Every message decomposes into 3 content types**:

1. **Message Text** (user or assistant natural language)
2. **Tool Parameters** (input to tool calls)
3. **Tool Results** (output from tool execution)

**Each content type** can be processed with **4 operations**:
- `KEEP` - Preserve unchanged
- `SUPPRESS` - Remove entirely
- `TRUNCATE` - Reduce to summary (mechanical)
- `SUMMARIZE` - Reduce via LLM (semantic)

### 1.3 Execution Model

**Two modes per pass**:
- **Batch Mode**: Process all selected messages as a single block (like native provider)
- **Individual Mode**: Process each message/content independently

**Two execution conditions**:
- **Always**: Execute sequentially (systematic multi-pass refinement)
- **Conditional**: Execute only if `currentTokens > targetThreshold` (fallback pattern)

## 2. Provider Architecture Revision

### 2.1 Updated Interface

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
  
  // UI Integration
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
  
  // UPDATED: Cost is now dynamic based on config
  estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number>
}

interface ProviderCapabilities {
  supportsLossless: boolean
  supportsBatchMode: boolean
  supportsIndividualMode: boolean
  supportsMultiPass: boolean
  supportsLLMSummarization: boolean
  estimatedSpeed: 'fast' | 'medium' | 'slow'
  // Cost is now computed, not static
}
```

### 2.2 Native Provider - Refined Responsibility

Based on 007-native-system-deep-dive.md analysis:

**Native Provider handles**:
- API handler selection (conversation vs Roo profile)
- Profile-aware cost calculation
- LLM streaming and token counting
- Batch summarization (existing implementation)

**Manager handles**:
- Profile configuration
- Threshold determination
- Trigger decision (`shouldCondense`)
- Pass orchestration

```typescript
class NativeCondensationProvider implements ICondensationProvider {
  readonly id = 'native'
  readonly name = 'Native Condensation'
  
  // Profile-aware configuration
  private profileConfig: {
    condensingApiConfigId?: string
    customCondensingPrompt?: string
    profileThresholds?: ProfileThresholds
  }
  
  async estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number> {
    // Use profile configuration to determine handler
    const apiHandler = this.selectApiHandler(config)
    
    // Calculate cost based on handler's pricing
    return calculateCost({
      inputTokens: context.tokenCount,
      outputTokens: /* estimate */,
      provider: apiHandler.getModelInfo().provider,
      model: apiHandler.getModelInfo().model,
      useCache: apiHandler.getModelInfo().supportsPromptCache
    })
  }
  
  private selectApiHandler(config: any): ApiHandler {
    // Logic from 007 analysis
    if (config?.condensingApiConfigId) {
      const specificHandler = /* get handler */
      if (specificHandler) return specificHandler
    }
    // Fallback to conversation handler
    return this.conversationApiHandler
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const apiHandler = this.selectApiHandler(options.config)
    
    // Delegate to existing summarizeConversation
    // (batch mode, keeps first/last N, summarizes middle)
    const result = await summarizeConversation(
      context.messages,
      options.targetTokens,
      apiHandler,
      options.config?.customCondensingPrompt
    )
    
    return {
      messages: result,
      stats: {
        originalTokens: context.tokenCount,
        finalTokens: await countTokens(result, apiHandler),
        cost: /* actual cost from streaming */,
        operationsPerformed: ['batch_llm_summarization']
      }
    }
  }
}
```

## 3. Pass-Based Configuration Model

### 3.1 Complete Configuration Structure

```typescript
interface SmartProviderConfig {
  // Optional lossless prelude
  losslessPrelude?: {
    enabled: boolean
    operations: {
      deduplicateFileReads: boolean
      consolidateToolResults: boolean
      removeObsoleteState: boolean
    }
  }
  
  // Core pass-based configuration
  passes: PassConfig[]
}

interface PassConfig {
  // Identification
  id: string
  name: string
  description?: string
  
  // Selection strategy
  selection: SelectionStrategy
  
  // Processing mode
  mode: 'batch' | 'individual'
  
  // Batch mode configuration
  batchConfig?: BatchModeConfig
  
  // Individual mode configuration
  individualConfig?: IndividualModeConfig
  
  // Execution condition
  execution: ExecutionCondition
}

// Selection Strategy
interface SelectionStrategy {
  type: 'preserve_recent' | 'preserve_percent' | 'custom'
  
  // For preserve_recent
  keepRecentCount?: number
  
  // For preserve_percent
  keepPercentage?: number
  
  // For custom (allow override)
  customSelector?: (messages: ApiMessage[]) => ApiMessage[]
}

// Batch Mode (like native)
interface BatchModeConfig {
  operation: 'keep' | 'summarize'
  
  // If summarize
  summarizationConfig?: {
    apiProfile?: string  // Use specific profile
    customPrompt?: string
    keepFirst: number    // Like native N_MESSAGES_TO_KEEP
    keepLast: number
  }
}

// Individual Mode (per-message processing)
interface IndividualModeConfig {
  // Default operations for each content type
  defaults: ContentTypeOperations
  
  // Per-message overrides (optional)
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

interface ContentOperation {
  operation: 'keep' | 'suppress' | 'truncate' | 'summarize'
  
  // Operation-specific parameters
  params?: OperationParams
}

// Operation Parameters (hierarchical defaults)
interface OperationParams {
  // For truncate
  truncate?: {
    maxChars?: number
    maxLines?: number
    addEllipsis?: boolean
  }
  
  // For summarize
  summarize?: {
    apiProfile?: string
    maxTokens?: number
    customPrompt?: string
  }
}

// Execution Condition
interface ExecutionCondition {
  type: 'always' | 'conditional'
  
  // For conditional
  condition?: {
    tokenThreshold: number  // Execute if current > threshold
    // Could add other conditions later
  }
}
```

### 3.2 Example Configurations

#### Example 1: Simple Progressive Truncation

```typescript
const simpleConfig: SmartProviderConfig = {
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
      id: 'pass-1',
      name: 'Aggressive Tool Result Truncation',
      selection: {
        type: 'preserve_recent',
        keepRecentCount: 5
      },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'keep' },
          toolResults: { 
            operation: 'truncate',
            params: { truncate: { maxLines: 5 } }
          }
        }
      },
      execution: {
        type: 'always'  // Always run
      }
    },
    
    {
      id: 'pass-2',
      name: 'Fallback: Suppress Old Results',
      selection: {
        type: 'preserve_recent',
        keepRecentCount: 10
      },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'keep' },
          toolResults: { operation: 'suppress' }
        }
      },
      execution: {
        type: 'conditional',
        condition: { tokenThreshold: 50000 }  // Only if still > 50k
      }
    }
  ]
}
```

#### Example 2: Multi-Pass with LLM Summarization

```typescript
const advancedConfig: SmartProviderConfig = {
  losslessPrelude: { enabled: true, /* ... */ },
  
  passes: [
    // Pass 1: Keep only recent, truncate rest
    {
      id: 'pass-1',
      name: 'Mechanical Truncation',
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
    },
    
    // Pass 2: If still too large, summarize with LLM
    {
      id: 'pass-2',
      name: 'LLM Summarization',
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
                apiProfile: 'gpt-4o-mini',  // Cheap model
                maxTokens: 100
              }
            }
          }
        }
      },
      execution: {
        type: 'conditional',
        condition: { tokenThreshold: 40000 }
      }
    },
    
    // Pass 3: Last resort - batch summarization
    {
      id: 'pass-3',
      name: 'Batch Summarization Fallback',
      selection: { type: 'preserve_percent', keepPercentage: 50 },
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
```

#### Example 3: Systematic Multi-Zone Refinement

```typescript
const systematicConfig: SmartProviderConfig = {
  losslessPrelude: { enabled: true, /* ... */ },
  
  passes: [
    // Zone 1: Very old messages (keep minimal)
    {
      id: 'zone-1',
      name: 'Ancient History - Suppress Results',
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
    
    // Zone 2: Old messages (truncate results)
    {
      id: 'zone-2',
      name: 'Old Context - Truncate',
      selection: { type: 'preserve_recent', keepRecentCount: 30 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { 
            operation: 'truncate',
            params: { truncate: { maxChars: 200 } }
          },
          toolResults: { 
            operation: 'truncate',
            params: { truncate: { maxLines: 10 } }
          }
        }
      },
      execution: { type: 'always' }
    },
    
    // Zone 3: Recent messages (keep mostly intact)
    {
      id: 'zone-3',
      name: 'Recent Context - Preserve',
      selection: { type: 'preserve_recent', keepRecentCount: 10 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'keep' },
          toolResults: { operation: 'keep' }
        }
      },
      execution: { type: 'always' }
    }
  ]
}
```

## 4. Smart Provider Implementation

### 4.1 Core Architecture

```typescript
class SmartCondensationProvider implements ICondensationProvider {
  readonly id = 'smart'
  readonly name = 'Smart Multi-Pass Condensation'
  
  private config: SmartProviderConfig
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    let messages = [...context.messages]
    const operations: string[] = []
    let totalCost = 0
    
    // Step 1: Optional lossless prelude
    if (this.config.losslessPrelude?.enabled) {
      const result = await this.runLosslessPrelude(messages)
      messages = result.messages
      operations.push(...result.operations)
      
      // Check if we're done
      const currentTokens = await countTokens(messages)
      if (currentTokens <= options.targetTokens) {
        return this.buildResult(messages, operations, context.tokenCount, totalCost)
      }
    }
    
    // Step 2: Execute passes sequentially
    for (const pass of this.config.passes) {
      // Check execution condition
      const shouldExecute = await this.shouldExecutePass(
        pass,
        messages,
        options.targetTokens
      )
      
      if (!shouldExecute) {
        operations.push(`skip_${pass.id}`)
        continue
      }
      
      // Execute pass
      const result = await this.executePass(pass, messages, options)
      messages = result.messages
      operations.push(`${pass.id}_completed`)
      totalCost += result.cost
      
      // Check if we're done
      const currentTokens = await countTokens(messages)
      if (currentTokens <= options.targetTokens) {
        break
      }
    }
    
    return this.buildResult(messages, operations, context.tokenCount, totalCost)
  }
  
  private async shouldExecutePass(
    pass: PassConfig,
    messages: ApiMessage[],
    targetTokens: number
  ): Promise<boolean> {
    if (pass.execution.type === 'always') {
      return true
    }
    
    // Conditional execution
    const currentTokens = await countTokens(messages)
    return currentTokens > pass.execution.condition!.tokenThreshold
  }
  
  private async executePass(
    pass: PassConfig,
    messages: ApiMessage[],
    options: CondensationOptions
  ): Promise<{ messages: ApiMessage[], cost: number }> {
    if (pass.mode === 'batch') {
      return this.executeBatchPass(pass, messages, options)
    } else {
      return this.executeIndividualPass(pass, messages, options)
    }
  }
  
  private async executeBatchPass(
    pass: PassConfig,
    messages: ApiMessage[],
    options: CondensationOptions
  ): Promise<{ messages: ApiMessage[], cost: number }> {
    // Select messages
    const selected = this.selectMessages(messages, pass.selection)
    
    if (pass.batchConfig!.operation === 'keep') {
      return { messages: selected, cost: 0 }
    }
    
    // Summarize batch (like native provider)
    const config = pass.batchConfig!.summarizationConfig!
    const apiHandler = this.getApiHandler(config.apiProfile)
    
    const summarized = await summarizeConversation(
      selected,
      options.targetTokens,
      apiHandler,
      config.customPrompt
    )
    
    // Calculate cost
    const cost = await this.calculateBatchCost(
      selected,
      summarized,
      apiHandler
    )
    
    return { messages: summarized, cost }
  }
  
  private async executeIndividualPass(
    pass: PassConfig,
    messages: ApiMessage[],
    options: CondensationOptions
  ): Promise<{ messages: ApiMessage[], cost: number }> {
    // Select messages
    const selected = this.selectMessages(messages, pass.selection)
    
    const config = pass.individualConfig!
    let totalCost = 0
    
    // Process each message individually
    const processed = await Promise.all(
      selected.map(async (msg, index) => {
        // Get operations for this message
        const ops = this.getOperationsForMessage(
          index,
          config
        )
        
        // Process message
        const result = await this.processMessage(msg, ops, options)
        totalCost += result.cost
        
        return result.message
      })
    )
    
    return { messages: processed, cost: totalCost }
  }
  
  private async processMessage(
    message: ApiMessage,
    operations: ContentTypeOperations,
    options: CondensationOptions
  ): Promise<{ message: ApiMessage, cost: number }> {
    // Decompose message into 3 content types
    const decomposed = this.decomposeMessage(message)
    
    let totalCost = 0
    
    // Process message text
    const processedText = await this.processContent(
      decomposed.messageText,
      operations.messageText,
      'text',
      options
    )
    totalCost += processedText.cost
    
    // Process tool parameters
    const processedParams = await this.processContent(
      decomposed.toolParameters,
      operations.toolParameters,
      'params',
      options
    )
    totalCost += processedParams.cost
    
    // Process tool results
    const processedResults = await this.processContent(
      decomposed.toolResults,
      operations.toolResults,
      'results',
      options
    )
    totalCost += processedResults.cost
    
    // Recompose message
    const recomposed = this.recomposeMessage(
      message,
      processedText.content,
      processedParams.content,
      processedResults.content
    )
    
    return { message: recomposed, cost: totalCost }
  }
  
  private async processContent(
    content: any,
    operation: ContentOperation,
    type: string,
    options: CondensationOptions
  ): Promise<{ content: any, cost: number }> {
    if (!content) {
      return { content: null, cost: 0 }
    }
    
    switch (operation.operation) {
      case 'keep':
        return { content, cost: 0 }
        
      case 'suppress':
        return { 
          content: this.createSuppressedMarker(type), 
          cost: 0 
        }
        
      case 'truncate':
        return {
          content: this.truncateContent(
            content,
            operation.params?.truncate || {}
          ),
          cost: 0
        }
        
      case 'summarize':
        return await this.summarizeContent(
          content,
          operation.params?.summarize || {},
          options
        )
    }
  }
  
  private async summarizeContent(
    content: any,
    params: any,
    options: CondensationOptions
  ): Promise<{ content: string, cost: number }> {
    const apiHandler = this.getApiHandler(params.apiProfile)
    
    const prompt = params.customPrompt || `Summarize concisely (max ${params.maxTokens || 100} tokens):\n\n${content}`
    
    // Small focused LLM call
    const stream = apiHandler.createMessage(
      prompt,
      [],
      { maxTokens: params.maxTokens || 100 }
    )
    
    let summary = ''
    for await (const chunk of stream) {
      if (chunk.type === 'text') {
        summary += chunk.text
      }
    }
    
    // Calculate cost
    const cost = await calculateCost({
      inputTokens: await countTokens([{ role: 'user', content: prompt }]),
      outputTokens: await countTokens([{ role: 'assistant', content: summary }]),
      provider: apiHandler.getModelInfo().provider,
      model: apiHandler.getModelInfo().model,
      useCache: false
    })
    
    return { content: summary, cost }
  }
  
  async estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number> {
    // Estimate cost for entire pass pipeline
    let estimatedCost = 0
    
    // Lossless prelude: free
    
    // For each pass
    for (const pass of (config || this.config).passes) {
      if (pass.mode === 'batch' && pass.batchConfig?.operation === 'summarize') {
        // Batch LLM cost
        const apiHandler = this.getApiHandler(pass.batchConfig.summarizationConfig?.apiProfile)
        estimatedCost += await this.estimateBatchCost(context, apiHandler)
      } else if (pass.mode === 'individual') {
        // Individual LLM cost (only for summarize operations)
        const summaryCount = this.countSummarizeOperations(pass.individualConfig!)
        if (summaryCount > 0) {
          const apiHandler = this.getApiHandler(/* default profile */)
          estimatedCost += summaryCount * 0.001  // Rough estimate per summary
        }
      }
    }
    
    return estimatedCost
  }
}
```

### 4.2 Message Decomposition

```typescript
interface DecomposedMessage {
  messageText: string | null      // User/assistant text
  toolParameters: any[] | null    // Tool call inputs
  toolResults: any[] | null       // Tool result outputs
}

private decomposeMessage(message: ApiMessage): DecomposedMessage {
  const result: DecomposedMessage = {
    messageText: null,
    toolParameters: null,
    toolResults: null
  }
  
  // Extract message text
  if (typeof message.content === 'string') {
    result.messageText = message.content
  } else if (Array.isArray(message.content)) {
    // Find text blocks
    const textBlocks = message.content.filter(b => b.type === 'text')
    if (textBlocks.length > 0) {
      result.messageText = textBlocks.map(b => b.text).join('\n')
    }
    
    // Find tool use blocks (parameters)
    const toolUseBlocks = message.content.filter(b => b.type === 'tool_use')
    if (toolUseBlocks.length > 0) {
      result.toolParameters = toolUseBlocks.map(b => ({
        id: b.id,
        name: b.name,
        input: b.input
      }))
    }
    
    // Find tool result blocks
    const toolResultBlocks = message.content.filter(b => b.type === 'tool_result')
    if (toolResultBlocks.length > 0) {
      result.toolResults = toolResultBlocks.map(b => ({
        tool_use_id: b.tool_use_id,
        content: b.content
      }))
    }
  }
  
  return result
}

private recomposeMessage(
  original: ApiMessage,
  messageText: string | null,
  toolParameters: any[] | null,
  toolResults: any[] | null
): ApiMessage {
  const content: any[] = []
  
  // Add text if present
  if (messageText) {
    content.push({ type: 'text', text: messageText })
  }
  
  // Add tool uses if present
  if (toolParameters) {
    content.push(...toolParameters.map(p => ({
      type: 'tool_use',
      id: p.id,
      name: p.name,
      input: p.input
    })))
  }
  
  // Add tool results if present
  if (toolResults) {
    content.push(...toolResults.map(r => ({
      type: 'tool_result',
      tool_use_id: r.tool_use_id,
      content: r.content
    })))
  }
  
  return {
    ...original,
    content: content.length === 1 && content[0].type === 'text'
      ? content[0].text
      : content
  }
}
```

## 5. UI Configuration - ListView Approach

### 5.1 Pass ListView Component

```typescript
const PassConfigurationView: React.FC<{
  config: SmartProviderConfig
  onChange: (config: SmartProviderConfig) => void
}> = ({ config, onChange }) => {
  const [selectedPass, setSelectedPass] = useState<string | null>(null)
  
  return (
    <div className="pass-configuration">
      {/* Lossless Prelude */}
      <Section title="Lossless Prelude (Optional)">
        <Checkbox
          label="Enable Lossless Optimizations"
          checked={config.losslessPrelude?.enabled}
          onChange={/* ... */}
        />
      </Section>
      
      {/* Pass List */}
      <Section title="Condensation Passes">
        <PassList
          passes={config.passes}
          selectedPass={selectedPass}
          onSelectPass={setSelectedPass}
          onAddPass={() => {
            const newPass = createDefaultPass(config.passes.length + 1)
            onChange({
              ...config,
              passes: [...config.passes, newPass]
            })
          }}
          onDeletePass={(id) => {
            onChange({
              ...config,
              passes: config.passes.filter(p => p.id !== id)
            })
          }}
          onReorderPasses={(newOrder) => {
            onChange({
              ...config,
              passes: newOrder
            })
          }}
        />
      </Section>
      
      {/* Pass Details Editor */}
      {selectedPass && (
        <Section title="Pass Configuration">
          <PassEditor
            pass={config.passes.find(p => p.id === selectedPass)!}
            onChange={(updatedPass) => {
              onChange({
                ...config,
                passes: config.passes.map(p =>
                  p.id === selectedPass ? updatedPass : p
                )
              })
            }}
          />
        </Section>
      )}
    </div>
  )
}
```

### 5.2 Pass List Component

```typescript
const PassList: React.FC<{
  passes: PassConfig[]
  selectedPass: string | null
  onSelectPass: (id: string) => void
  onAddPass: () => void
  onDeletePass: (id: string) => void
  onReorderPasses: (passes: PassConfig[]) => void
}> = ({ passes, selectedPass, onSelectPass, onAddPass, onDeletePass, onReorderPasses }) => {
  return (
    <div className="pass-list">
      <DragDropList
        items={passes}
        renderItem={(pass, index) => (
          <PassListItem
            key={pass.id}
            pass={pass}
            index={index}
            isSelected={pass.id === selectedPass}
            onClick={() => onSelectPass(pass.id)}
            onDelete={() => onDeletePass(pass.id)}
          />
        )}
        onReorder={onReorderPasses}
      />
      
      <Button onClick={onAddPass} variant="primary">
        + Add Pass
      </Button>
    </div>
  )
}

const PassListItem: React.FC<{
  pass: PassConfig
  index: number
  isSelected: boolean
  onClick: () => void
  onDelete: () => void
}> = ({ pass, index, isSelected, onClick, onDelete }) => {
  return (
    <div 
      className={`pass-item ${isSelected ? 'selected' : ''}`}
      onClick={onClick}
    >
      <div className="pass-header">
        <DragHandle />
        <span className="pass-number">Pass {index + 1}</span>
        <span className="pass-name">{pass.name}</span>
        <IconButton icon="trash" onClick={onDelete} />
      </div>
      
      <div className="pass-summary">
        <Badge>{pass.mode}</Badge>
        <Badge variant="info">
          {pass.execution.type === 'always' ? 'Always' : 'Conditional'}
        </Badge>
        {pass.execution.type === 'conditional' && (
          <Badge variant="warning">
            If &gt; {pass.execution.condition?.tokenThreshold} tokens
          </Badge>
        )}
      </div>
    </div>
  )
}
```

### 5.3 Pass Editor Component

```typescript
const PassEditor: React.FC<{
  pass: PassConfig
  onChange: (pass: PassConfig) => void
}> = ({ pass, onChange }) => {
  return (
    <div className="pass-editor">
      {/* Basic Info */}
      <Subsection title="Basic Information">
        <TextInput
          label="Pass Name"
          value={pass.name}
          onChange={(v) => onChange({ ...pass, name: v })}
        />
        <TextArea
          label="Description (optional)"
          value={pass.description || ''}
          onChange={(v) => onChange({ ...pass, description: v })}
        />
      </Subsection>
      
      {/* Selection Strategy */}
      <Subsection title="Message Selection">
        <Select
          label="Selection Strategy"
          value={pass.selection.type}
          options={[
            { value: 'preserve_recent', label: 'Preserve Recent N Messages' },
            { value: 'preserve_percent', label: 'Preserve Percentage' },
            { value: 'custom', label: 'Custom Selector' }
          ]}
          onChange={(v) => onChange({
            ...pass,
            selection: { ...pass.selection, type: v }
          })}
        />
        
        {pass.selection.type === 'preserve_recent' && (
          <NumberInput
            label="Keep Recent Count"
            value={pass.selection.keepRecentCount || 5}
            min={1}
            max={100}
            onChange={(v) => onChange({
              ...pass,
              selection: { ...pass.selection, keepRecentCount: v }
            })}
          />
        )}
        
        {pass.selection.type === 'preserve_percent' && (
          <NumberInput
            label="Keep Percentage"
            value={pass.selection.keepPercentage || 50}
            min={1}
            max={100}
            suffix="%"
            onChange={(v) => onChange({
              ...pass,
              selection: { ...pass.selection, keepPercentage: v }
            })}
          />
        )}
      </Subsection>
      
      {/* Processing Mode */}
      <Subsection title="Processing Mode">
        <RadioGroup
          value={pass.mode}
          onChange={(v) => onChange({ ...pass, mode: v })}
        >
          <RadioOption value="batch" label="Batch Mode">
            Process all selected messages as a single block (like native)
          </RadioOption>
          <RadioOption value="individual" label="Individual Mode">
            Process each message independently with fine-grained control
          </RadioOption>
        </RadioGroup>
      </Subsection>
      
      {/* Mode-specific configuration */}
      {pass.mode === 'batch' ? (
        <BatchModeEditor
          config={pass.batchConfig!}
          onChange={(c) => onChange({ ...pass, batchConfig: c })}
        />
      ) : (
        <IndividualModeEditor
          config={pass.individualConfig!}
          onChange={(c) => onChange({ ...pass, individualConfig: c })}
        />
      )}
      
      {/* Execution Condition */}
      <Subsection title="Execution Condition">
        <RadioGroup
          value={pass.execution.type}
          onChange={(v) => onChange({
            ...pass,
            execution: { ...pass.execution, type: v }
          })}
        >
          <RadioOption value="always" label="Always Execute">
            Execute this pass every time (systematic multi-pass)
          </RadioOption>
          <RadioOption value="conditional" label="Conditional (Fallback)">
            Execute only if context still exceeds threshold
          </RadioOption>
        </RadioGroup>
        
        {pass.execution.type === 'conditional' && (
          <NumberInput
            label="Token Threshold"
            value={pass.execution.condition?.tokenThreshold || 50000}
            min={1000}
            max={200000}
            onChange={(v) => onChange({
              ...pass,
              execution: {
                type: 'conditional',
                condition: { tokenThreshold: v }
              }
            })}
          />
        )}
      </Subsection>
    </div>
  )
}
```

### 5.4 Individual Mode Editor

```typescript
const IndividualModeEditor: React.FC<{
  config: IndividualModeConfig
  onChange: (config: IndividualModeConfig) => void
}> = ({ config, onChange }) => {
  return (
    <div className="individual-mode-editor">
      <Subsection title="Default Operations">
        <p className="help-text">
          Configure how to process each content type by default.
          You can override per-message later.
        </p>
        
        {/* Message Text */}
        <ContentTypeOperationEditor
          label="Message Text (user/assistant)"
          operation={config.defaults.messageText}
          allowedOperations={['keep', 'truncate', 'summarize']}
          onChange={(op) => onChange({
            ...config,
            defaults: {
              ...config.defaults,
              messageText: op
            }
          })}
        />
        
        {/* Tool Parameters */}
        <ContentTypeOperationEditor
          label="Tool Parameters"
          operation={config.defaults.toolParameters}
          allowedOperations={['keep', 'suppress', 'truncate']}
          onChange={(op) => onChange({
            ...config,
            defaults: {
              ...config.defaults,
              toolParameters: op
            }
          })}
        />
        
        {/* Tool Results */}
        <ContentTypeOperationEditor
          label="Tool Results"
          operation={config.defaults.toolResults}
          allowedOperations={['keep', 'suppress', 'truncate', 'summarize']}
          onChange={(op) => onChange({
            ...config,
            defaults: {
              ...config.defaults,
              toolResults: op
            }
          })}
        />
      </Subsection>
      
      {/* Per-message overrides (advanced) */}
      <Collapsible title="Per-Message Overrides (Advanced)">
        <p className="help-text">
          Override operations for specific messages by index.
        </p>
        {/* List of overrides with ability to add/remove */}
      </Collapsible>
    </div>
  )
}

const ContentTypeOperationEditor: React.FC<{
  label: string
  operation: ContentOperation
  allowedOperations: string[]
  onChange: (operation: ContentOperation) => void
}> = ({ label, operation, allowedOperations, onChange }) => {
  return (
    <div className="content-operation-editor">
      <h4>{label}</h4>
      
      <Select
        label="Operation"
        value={operation.operation}
        options={allowedOperations.map(op => ({
          value: op,
          label: op.charAt(0).toUpperCase() + op.slice(1)
        }))}
        onChange={(v) => onChange({ ...operation, operation: v })}
      />
      
      {/* Operation-specific parameters */}
      {operation.operation === 'truncate' && (
        <TruncateParamsEditor
          params={operation.params?.truncate || {}}
          onChange={(p) => onChange({
            ...operation,
            params: { ...operation.params, truncate: p }
          })}
        />
      )}
      
      {operation.operation === 'summarize' && (
        <SummarizeParamsEditor
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

const TruncateParamsEditor: React.FC<{
  params: any
  onChange: (params: any) => void
}> = ({ params, onChange }) => {
  return (
    <div className="truncate-params">
      <NumberInput
        label="Max Characters"
        value={params.maxChars || 500}
        onChange={(v) => onChange({ ...params, maxChars: v })}
      />
      <NumberInput
        label="Max Lines"
        value={params.maxLines || 10}
        onChange={(v) => onChange({ ...params, maxLines: v })}
      />
      <Checkbox
        label="Add Ellipsis (...)"
        checked={params.addEllipsis !== false}
        onChange={(v) => onChange({ ...params, addEllipsis: v })}
      />
    </div>
  )
}

const SummarizeParamsEditor: React.FC<{
  params: any
  onChange: (params: any) => void
}> = ({ params, onChange }) => {
  return (
    <div className="summarize-params">
      <Select
        label="API Profile"
        value={params.apiProfile || 'default'}
        options={[
          { value: 'default', label: 'Use Conversation Profile' },
          { value: 'gpt-4o-mini', label: 'GPT-4o Mini (Cheap)' },
          { value: 'claude-haiku', label: 'Claude Haiku (Fast)' },
          /* ... */
        ]}
        onChange={(v) => onChange({ ...params, apiProfile: v })}
      />
      <NumberInput
        label="Max Summary Tokens"
        value={params.maxTokens || 100}
        min={50}
        max={500}
        onChange={(v) => onChange({ ...params, maxTokens: v })}
      />
      <TextArea
        label="Custom Prompt (optional)"
        value={params.customPrompt || ''}
        placeholder="Leave empty for default summarization prompt"
        onChange={(v) => onChange({ ...params, customPrompt: v })}
      />
    </div>
  )
}
```

## 6. Configuration Examples & Presets

### 6.1 Preset: Speed Optimized

```typescript
const speedPreset: SmartProviderConfig = {
  losslessPrelude: { enabled: true, operations: { /* all true */ } },
  passes: [
    {
      id: 'speed-pass',
      name: 'Aggressive Truncation',
      selection: { type: 'preserve_recent', keepRecentCount: 5 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { 
            operation: 'suppress'  // Fastest
          },
          toolResults: { 
            operation: 'truncate',
            params: { truncate: { maxLines: 3 } }
          }
        }
      },
      execution: { type: 'always' }
    }
  ]
}
```

### 6.2 Preset: Quality Optimized

```typescript
const qualityPreset: SmartProviderConfig = {
  losslessPrelude: { enabled: true, operations: { /* all true */ } },
  passes: [
    {
      id: 'quality-pass',
      name: 'LLM Summarization',
      selection: { type: 'preserve_recent', keepRecentCount: 10 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'keep' },
          toolResults: { 
            operation: 'summarize',  // Best quality
            params: {
              summarize: {
                apiProfile: 'gpt-4o-mini',
                maxTokens: 150
              }
            }
          }
        }
      },
      execution: { type: 'always' }
    }
  ]
}
```

### 6.3 Preset: Cost Optimized

```typescript
const costPreset: SmartProviderConfig = {
  losslessPrelude: { enabled: true, operations: { /* all true */ } },
  passes: [
    // First pass: mechanical (free)
    {
      id: 'mechanical',
      name: 'Free Truncation',
      selection: { type: 'preserve_recent', keepRecentCount: 5 },
      mode: 'individual',
      individualConfig: {
        defaults: {
          messageText: { operation: 'keep' },
          toolParameters: { operation: 'suppress' },
          toolResults: { 
            operation: 'truncate',
            params: { truncate: { maxLines: 5 } }
          }
        }
      },
      execution: { type: 'always' }
    },
    // Second pass: cheap LLM only if needed
    {
      id: 'fallback-llm',
      name: 'Minimal LLM Fallback',
      selection: { type: 'preserve_percent', keepPercentage: 30 },
      mode: 'batch',
      batchConfig: {
        operation: 'summarize',
        summarizationConfig: {
          apiProfile: 'gpt-4o-mini',  // Cheapest
          keepFirst: 1,
          keepLast: 5
        }
      },
      execution: {
        type: 'conditional',
        condition: { tokenThreshold: 60000 }
      }
    }
  ]
}
```

## 7. Implementation Roadmap

### Week 1-2: Foundation
- Implement pass configuration model
- Update provider interface (dynamic cost)
- Basic pass executor

### Week 3-4: Core Operations
- Message decomposition/recomposition
- 4 operations (keep, suppress, truncate, summarize)
- Operation parameter system

### Week 5-6: UI Components
- PassList with drag & drop
- PassEditor with nested configuration
- ContentTypeOperationEditor

### Week 7-8: Polish & Testing
- Preset system
- Cost estimation
- Performance optimization
- User testing

## 8. Success Metrics

- **Flexibility**: Users can express any condensation strategy through passes
- **Performance**: Individual mode with truncate ~100ms, batch mode ~2-5s
- **Cost**: Predictable, configurable (free to ~$0.05 per condensation)
- **Quality**: Semantic information preserved per user priorities
- **Usability**: UI allows configuration without coding

---

**Final Architecture**: Pass-based, modular, with complete control over content types and operations. Native system properly encapsulated. Cost calculation dynamic. UI with ListView for passes.