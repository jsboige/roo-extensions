# Requirements Specification - Improved Context Condensation System

**Date**: 2025-10-01  
**Version**: 1.0  
**Status**: Draft for Review

## Executive Summary

This document specifies the requirements for an improved context condensation system in roo-code based on the analysis of the current implementation and user-identified limitations. The improved system will introduce a provider architecture supporting both the current native strategy and a new smart condensation strategy with lossless optimization and content-type-aware lossy compression.

## 1. Problem Statement

### 1.1 Current Issues

The existing context condensation system has five critical limitations:

1. **Indiscriminate Batch Processing**: All message types condensed equally without regard to content type or importance
2. **Conversation Message Loss**: User/assistant dialogue gets summarized away, losing decision context
3. **No Content-Type Prioritization**: Tool results (largest) condensed same as conversation (most important)
4. **No Lossless Optimization**: Repeated file reads and redundant tool results stored multiple times
5. **Chronological Bias**: Only message position considered, not semantic importance

### 1.2 Impact on Users

**User Experience Problems**:
- Loss of conversation context after condensation
- Inability to trace decision-making rationale
- Repeated information consuming context unnecessarily
- Suboptimal token usage leading to more frequent condensation

**Technical Problems**:
- Inefficient context usage
- Higher API costs due to suboptimal condensation
- Difficulty continuing work after condensation
- No optimization before expensive LLM summarization

## 2. Goals and Objectives

### 2.1 Primary Goals

1. **Preserve Conversation Quality**: Maintain user/assistant dialogue with minimal loss
2. **Optimize Token Usage**: Achieve better compression through lossless optimization
3. **Content-Type Awareness**: Prioritize condensation by message type importance
4. **Backward Compatibility**: Existing behavior available as default option
5. **User Control**: Allow users to choose condensation strategy

### 2.2 Success Metrics

**Quantitative Metrics**:
- 30-50% reduction in token consumption before LLM summarization (lossless phase)
- 10-20% improvement in conversation message preservation rate
- <5% regression in overall condensation effectiveness
- Zero breaking changes to existing API

**Qualitative Metrics**:
- User-reported improvement in context continuity
- Reduced frequency of "lost context" reports
- Positive feedback on strategy selection options

### 2.3 Non-Goals

**Out of Scope**:
- Real-time streaming condensation
- Automatic strategy selection based on conversation type
- Cross-conversation context sharing
- Distributed condensation (splitting across multiple API calls)

**Future Considerations** (not in initial implementation):
- ML-based importance scoring
- User-specific condensation preferences
- Conversation-type detection and adaptation
- Multi-provider orchestration

## 3. Functional Requirements

### 3.1 Provider Architecture

#### FR-PA-001: Provider Interface
**Requirement**: Define a standard interface that all condensation providers must implement

**Specification**:
```typescript
interface ContextCondensationProvider {
  // Provider metadata
  name: string
  description: string
  version: string
  
  // Core functionality
  condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult>
  
  // Capabilities
  supportsLossless(): boolean
  supportsContentTypeAwareness(): boolean
  supportsCustomPrompts(): boolean
  
  // Token estimation
  estimateReduction(
    context: ConversationContext
  ): Promise<TokenEstimate>
}
```

**Acceptance Criteria**:
- [ ] Interface defined in TypeScript
- [ ] All methods documented with JSDoc
- [ ] Return types fully specified
- [ ] Error handling patterns defined

#### FR-PA-002: Native Provider
**Requirement**: Implement wrapper for current condensation logic as `NativeCondensationProvider`

**Specification**:
- Wraps existing `summarizeConversation()` function
- Maintains exact current behavior
- Default provider when no selection made
- Zero regression in existing functionality

**Acceptance Criteria**:
- [ ] All existing tests pass without modification
- [ ] Behavior identical to current implementation
- [ ] Configuration mapping preserved
- [ ] Telemetry events unchanged

#### FR-PA-003: Smart Provider
**Requirement**: Implement new `SmartCondensationProvider` with improved strategy

**Specification**:
- Implements two-phase condensation (lossless + lossy)
- Content-type aware processing
- Prioritized compression strategy
- Conversation message preservation

**Acceptance Criteria**:
- [ ] Lossless phase reduces tokens 30-50%
- [ ] Lossy phase maintains quality
- [ ] Conversation messages preserved better than native
- [ ] No context growth in validation

#### FR-PA-004: Provider Selection
**Requirement**: Allow users to select condensation provider via settings

**Specification**:
- Dropdown in settings UI
- Providers: "Native (default)" and "Smart (improved)"
- Per-workspace or global setting
- Runtime provider switching supported

**Acceptance Criteria**:
- [ ] Setting persisted correctly
- [ ] UI reflects current selection
- [ ] Provider switch takes effect immediately
- [ ] Migration path from old settings

### 3.2 Lossless Condensation Phase

#### FR-LC-001: File Read Deduplication
**Requirement**: Detect and deduplicate repeated file read operations

**Specification**:
```
Detection:
- Identify tool_result messages from read_file tool
- Extract file path from tool call parameters
- Compare content hashes

Deduplication:
- Keep first occurrence with full content
- Replace subsequent reads with reference
- Format: "⟨ File content already provided above ⟩"
- Preserve metadata (line numbers, excerpts if different)

Token Savings:
- Typical file: 500-2000 tokens
- Typical read count: 2-4 times
- Expected savings: 1000-6000 tokens per file
```

**Acceptance Criteria**:
- [ ] Detects repeated exact file reads
- [ ] Creates reference to first occurrence
- [ ] Preserves line number differences
- [ ] Handles partial file reads (excerpts)

#### FR-LC-002: Tool Result Consolidation
**Requirement**: Consolidate similar or redundant tool results

**Specification**:
```
Consolidation Rules:
1. List operations: Merge if same directory, combine entries
2. Search operations: Merge if same pattern, combine results
3. Execute command: Keep latest output if multiple runs
4. Multiple small similar results: Group and summarize count

Format:
"⟨ Consolidated N operations: <summary> ⟩"

Preservation:
- Always keep different results
- Always keep error results separate
- Preserve chronological order in summary
```

**Acceptance Criteria**:
- [ ] Identifies consolidatable results
- [ ] Preserves semantic differences
- [ ] Clear indication of consolidation
- [ ] Reversible if needed (metadata preserved)

#### FR-LC-003: Reference System
**Requirement**: Implement pointer system for repeated content

**Specification**:
```typescript
interface ContentReference {
  type: 'file' | 'tool_result' | 'output'
  originalIndex: number  // Message index of original
  path?: string          // For file references
  operation?: string     // For tool references
  hash: string          // Content hash for verification
}

Format in messages:
"⟨ Reference: See message #{index} for {description} ⟩"

Benefits:
- Lightweight representation
- Preserves traceability
- Enables future reconstruction
```

**Acceptance Criteria**:
- [ ] References created correctly
- [ ] Original content identifiable
- [ ] Hash validation works
- [ ] UI can optionally expand references

#### FR-LC-004: Validation After Lossless
**Requirement**: Measure and report token savings from lossless phase

**Specification**:
```
Metrics to Track:
- Original token count
- Post-lossless token count
- Number of deduplications
- Number of consolidations
- Number of references created

Validation:
- Ensure no semantic loss
- Verify references are valid
- Confirm hash matches
- Check no information lost
```

**Acceptance Criteria**:
- [ ] Token reduction measured accurately
- [ ] Validation catches errors
- [ ] Metrics logged for telemetry
- [ ] Rollback if validation fails

### 3.3 Lossy Condensation Phase

#### FR-LS-001: Content-Type Classification
**Requirement**: Classify messages by type for prioritized condensation

**Specification**:
```typescript
enum MessageType {
  USER_MESSAGE,        // User questions/requests
  ASSISTANT_MESSAGE,   // Assistant responses/reasoning
  ASSISTANT_THINKING,  // Extended reasoning blocks
  TOOL_CALL,          // Tool invocation parameters
  TOOL_RESULT,        // Tool execution results
  SYSTEM_MESSAGE      // System prompts/summaries
}

Priority for Condensation:
1. TOOL_RESULT (largest, most compressible)
2. TOOL_CALL (verbose parameters, can summarize)
3. ASSISTANT_THINKING (reasoning, can condense)
4. ASSISTANT_MESSAGE (responses, preserve key points)
5. USER_MESSAGE (preserve most, minimal condensation)
```

**Acceptance Criteria**:
- [ ] All messages classified correctly
- [ ] Classification handles edge cases
- [ ] Priority order configurable
- [ ] Type detection is robust

#### FR-LS-002: Prioritized Compression Strategy
**Requirement**: Apply different compression strategies based on message type

**Specification**:
```
Phase 2.1: Tool Result Compression
- Summarize large tool results
- Keep error messages verbatim
- Preserve structure (file paths, line numbers)
- Target: 80-90% reduction

Phase 2.2: Tool Call Simplification
- Reduce verbose parameters
- Keep essential metadata
- Remove redundant options
- Target: 50-70% reduction

Phase 2.3: Reasoning Condensation
- Summarize thought process
- Keep final conclusions
- Preserve decision points
- Target: 40-60% reduction

Phase 2.4: Message Preservation
- Minimal user message condensation
- Preserve user intent verbatim
- Keep assistant key responses
- Target: 0-20% reduction
```

**Acceptance Criteria**:
- [ ] Each phase reduces target type effectively
- [ ] Quality maintained per type
- [ ] Phases applied in correct order
- [ ] Stop when target reduction achieved

#### FR-LS-003: Tree-Based Importance Scoring
**Requirement**: View conversation as tree and score importance

**Specification**:
```
Tree Structure:
- User intent → Assistant decision → Tool usage → Result
- Each node has importance score
- Critical path preservation

Importance Factors:
1. Distance from leaf nodes (recent = important)
2. Referenced by later messages (reused = important)
3. Decision points (choices = important)
4. Error handling (problems = important)
5. User corrections (feedback = important)

Scoring Algorithm:
- Start with base score by type
- Add recency bonus (exponential decay)
- Add reference count bonus
- Add decision point bonus
- Add error/correction bonus

Result: Preserve high-scoring nodes longer
```

**Acceptance Criteria**:
- [ ] Tree construction correct
- [ ] Scoring factors implemented
- [ ] Critical path identified
- [ ] Preservation respects scores

#### FR-LS-004: Conversation Message Preservation
**Requirement**: Preserve user/assistant dialogue with minimal loss

**Specification**:
```
Preservation Rules:
1. All user messages preserved verbatim
2. Assistant decisions preserved
3. Error explanations preserved
4. Clarification exchanges preserved
5. Only lengthy reasoning condensed

Never Condense:
- User questions
- User instructions
- User corrections
- Assistant acknowledgments of user input
- Final decisions/conclusions

May Condense:
- Extended reasoning (keep conclusion)
- Repetitive explanations
- Verbose descriptions (keep key points)
```

**Acceptance Criteria**:
- [ ] User messages 100% preserved
- [ ] Assistant decisions preserved
- [ ] Only verbose sections condensed
- [ ] Conversation flow maintained

### 3.4 Configuration and Settings

#### FR-CS-001: Provider Selection Setting
**Requirement**: Add setting to choose condensation provider

**Specification**:
```typescript
interface CondensationSettings {
  provider: 'native' | 'smart'
  
  // Native provider settings (existing)
  autoCondenseContext: boolean
  autoCondenseContextPercent: number
  customCondensingPrompt?: string
  condensingApiHandler?: string
  
  // Smart provider settings (new)
  enableLosslessPhase: boolean
  enableContentTypeAwareness: boolean
  preservationPriority: MessageType[]
  targetReductionPercent?: number
}
```

**UI**:
- Dropdown: "Context Condensation Strategy"
- Options: "Native (Current)", "Smart (Improved)"
- Description text explaining differences
- Section for strategy-specific settings

**Acceptance Criteria**:
- [ ] Setting persisted correctly
- [ ] Default is 'native' (backward compatible)
- [ ] Migration from old settings works
- [ ] UI reflects current choice

#### FR-CS-002: Smart Provider Configuration
**Requirement**: Provide configuration options for smart provider

**Specification**:
```
Settings:
1. Enable/disable lossless phase
2. Enable/disable content-type awareness
3. Preservation priority customization
4. Target reduction percentage
5. Maximum reduction per phase

Defaults:
- Lossless: Enabled
- Content-type awareness: Enabled
- Priority: Tool Results > Calls > Thinking > Messages
- Target: 50% reduction
- Max per phase: 90%
```

**Acceptance Criteria**:
- [ ] Settings validate correctly
- [ ] Invalid values rejected
- [ ] Defaults sensible
- [ ] Help text explains options

#### FR-CS-003: Profile-Specific Provider Settings
**Requirement**: Allow per-mode provider configuration

**Specification**:
```
Mode Overrides:
- Each mode can specify preferred provider
- Mode can override provider settings
- Global settings as fallback
- -1 value means inherit global

Example:
{
  "code": {
    "provider": "smart",
    "preservationPriority": ["USER_MESSAGE", "TOOL_RESULT"]
  },
  "architect": {
    "provider": "smart", 
    "targetReductionPercent": 60
  },
  "ask": {
    "provider": "native"  // Preserve current behavior
  }
}
```

**Acceptance Criteria**:
- [ ] Mode overrides work
- [ ] Inheritance works
- [ ] Validation per mode
- [ ] Migration path exists

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### NFR-P-001: Condensation Latency
**Requirement**: Total condensation time should not significantly increase

**Specification**:
- Lossless phase: <1 second (deterministic operations)
- Lossy phase: Same as current (LLM-dependent)
- Total overhead: <20% increase
- User perception: No noticeable delay

**Acceptance Criteria**:
- [ ] Lossless phase benchmarked
- [ ] Total time measured
- [ ] Comparison to current system
- [ ] Performance tests passing

#### NFR-P-002: Token Counting Performance
**Requirement**: Token counting must be efficient for large contexts

**Specification**:
- O(n) complexity maintained
- Caching for repeated counts
- Batch counting where possible
- No memory leaks

**Acceptance Criteria**:
- [ ] Complexity analysis done
- [ ] Caching implemented
- [ ] Memory profiling clean
- [ ] Large context tests pass

#### NFR-P-003: Memory Usage
**Requirement**: Memory usage must remain bounded

**Specification**:
- No more than 2x message size
- Reference system lightweight
- Cleanup after condensation
- No memory leaks

**Acceptance Criteria**:
- [ ] Memory profiling done
- [ ] Peak usage measured
- [ ] Cleanup verified
- [ ] Leak tests pass

### 4.2 Reliability Requirements

#### NFR-R-001: Backward Compatibility
**Requirement**: Existing functionality must not break

**Specification**:
- Native provider 100% compatible
- All existing tests pass
- Configuration migration automatic
- No breaking API changes

**Acceptance Criteria**:
- [ ] All existing tests pass
- [ ] Regression suite complete
- [ ] Migration tested
- [ ] API unchanged

#### NFR-R-002: Graceful Degradation
**Requirement**: System must handle failures gracefully

**Specification**:
```
Failure Scenarios:
1. Lossless phase fails → Skip to lossy
2. Lossy phase fails → Fall back to truncation
3. Provider errors → Fall back to native
4. Configuration errors → Use defaults

User Communication:
- Clear error messages
- Explanation of fallback
- No data loss
- Retry option
```

**Acceptance Criteria**:
- [ ] All failure paths tested
- [ ] Fallback behavior correct
- [ ] Error messages clear
- [ ] No data loss scenarios

#### NFR-R-003: Validation and Verification
**Requirement**: Condensation results must be validated

**Specification**:
```
Validation Checks:
1. Token count reduced (not increased)
2. No message loss (references valid)
3. Semantic coherence maintained
4. Format correctness

Verification:
- Pre/post token comparison
- Reference integrity check
- Conversation flow check
- Format validation
```

**Acceptance Criteria**:
- [ ] All checks implemented
- [ ] Validation catches errors
- [ ] Rollback on failure
- [ ] Metrics logged

### 4.3 Usability Requirements

#### NFR-U-001: Clear Documentation
**Requirement**: Users must understand provider options

**Specification**:
- In-UI help text
- Settings descriptions
- Strategy comparison
- Examples of each approach

**Acceptance Criteria**:
- [ ] Help text written
- [ ] Examples documented
- [ ] Comparison table provided
- [ ] User testing positive

#### NFR-U-002: Visual Feedback
**Requirement**: Users must see what happened during condensation

**Specification**:
```
Feedback Elements:
- Phase indication (lossless/lossy)
- Token reduction metrics
- Preserved vs condensed breakdown
- Cost information
- Time elapsed

Format:
"Context condensed using Smart strategy:
 - Lossless phase: 8,500 → 5,200 tokens (-39%)
 - Lossy phase: 5,200 → 2,800 tokens (-46%)
 - Total reduction: 67% (saved $0.08)
 - Preserved: 12 user messages, 3 decisions
 - Time: 3.2 seconds"
```

**Acceptance Criteria**:
- [ ] All metrics displayed
- [ ] Format clear and readable
- [ ] Cost calculated correctly
- [ ] User feedback positive

#### NFR-U-003: Settings Discoverability
**Requirement**: Users must easily find and understand settings

**Specification**:
- Settings in logical location
- Grouped by provider
- Progressive disclosure (advanced collapsed)
- Tooltips for complex options

**Acceptance Criteria**:
- [ ] Settings location intuitive
- [ ] Grouping logical
- [ ] Tooltips helpful
- [ ] User testing successful

### 4.4 Maintainability Requirements

#### NFR-M-001: Code Organization
**Requirement**: Code must be well-organized and documented

**Specification**:
```
Directory Structure:
src/core/condense/
  ├── index.ts (exports)
  ├── types.ts (interfaces)
  ├── providers/
  │   ├── base.ts (interface)
  │   ├── native.ts (current)
  │   └── smart.ts (new)
  ├── lossless/
  │   ├── deduplication.ts
  │   ├── consolidation.ts
  │   └── references.ts
  ├── lossy/
  │   ├── classification.ts
  │   ├── prioritization.ts
  │   └── tree-scoring.ts
  └── __tests__/
```

**Acceptance Criteria**:
- [ ] Structure implemented
- [ ] Files organized logically
- [ ] Imports clean
- [ ] Tests co-located

#### NFR-M-002: Testing Coverage
**Requirement**: Comprehensive test coverage

**Specification**:
```
Test Categories:
1. Unit tests: Each function/class
2. Integration tests: Provider workflows
3. Regression tests: Current behavior
4. Performance tests: Benchmarking
5. Edge case tests: Boundary conditions

Coverage Target: >90%
```

**Acceptance Criteria**:
- [ ] Unit tests complete
- [ ] Integration tests pass
- [ ] Regression suite complete
- [ ] Coverage target met

#### NFR-M-003: Documentation
**Requirement**: Comprehensive code and user documentation

**Specification**:
```
Documentation:
1. JSDoc for all public APIs
2. README for each provider
3. Architecture decision records
4. User guide in docs
5. Migration guide

Maintenance:
- Update with code changes
- Examples kept current
- Version documentation
```

**Acceptance Criteria**:
- [ ] JSDoc complete
- [ ] READMEs written
- [ ] Architecture documented
- [ ] User guide complete

## 5. Constraints and Assumptions

### 5.1 Technical Constraints

**TC-1**: Must use TypeScript
- All code in TypeScript
- Type safety enforced
- No any types without justification

**TC-2**: Must integrate with existing API handler system
- Reuse `ApiHandler` interface
- Token counting via handlers
- LLM calls through handlers

**TC-3**: Must work with all supported LLM providers
- Anthropic, OpenAI, Bedrock, etc.
- No provider-specific logic
- Generic interface

### 5.2 Business Constraints

**BC-1**: Backward compatibility required
- No breaking changes
- Existing configurations work
- Migration automatic

**BC-2**: Cost-effective
- No excessive LLM calls
- Optimize token usage
- User control over costs

**BC-3**: Timeline
- Phase 1 (Provider architecture): 2 weeks
- Phase 2 (Lossless implementation): 2 weeks
- Phase 3 (Lossy improvements): 3 weeks
- Phase 4 (Testing and polish): 1 week
- Total: ~8 weeks

### 5.3 Assumptions

**A-1**: Message structure is consistent
- Tool calls have standard format
- Tool results identifiable
- User/assistant roles clear

**A-2**: Token counting is accurate
- API handler provides good estimates
- Counts are consistent
- Performance acceptable

**A-3**: LLM summarization quality sufficient
- Current quality acceptable baseline
- Improvements possible with better prompts
- No need for custom summarization model

## 6. Dependencies

### 6.1 Internal Dependencies

**ID-1**: API Handler System
- Token counting functionality
- Message creation
- Cost tracking

**ID-2**: Settings Management
- Configuration persistence
- Profile system
- UI integration

**ID-3**: Telemetry System
- Event tracking
- Metrics collection
- Performance monitoring

### 6.2 External Dependencies

**ED-1**: LLM Providers
- API availability
- Response latency
- Cost structure

**ED-2**: VSCode Extension API
- Settings persistence
- UI components
- Workspace management

## 7. Acceptance Criteria Summary

### 7.1 Must Have (MVP)

- [ ] Provider architecture implemented
- [ ] Native provider wraps existing logic
- [ ] Smart provider with lossless phase
- [ ] File read deduplication working
- [ ] Tool result consolidation working
- [ ] Reference system implemented
- [ ] Content-type classification working
- [ ] Prioritized compression phases
- [ ] Conversation preservation improved
- [ ] Settings UI for provider selection
- [ ] All existing tests passing
- [ ] Backward compatibility verified
- [ ] Performance acceptable
- [ ] Documentation complete

### 7.2 Should Have (Nice to Have)

- [ ] Tree-based importance scoring
- [ ] Advanced consolidation rules
- [ ] Detailed metrics display
- [ ] Profile-specific provider settings
- [ ] Visual diff of condensation
- [ ] Export/import condensation configs
- [ ] Telemetry dashboard

### 7.3 Could Have (Future)

- [ ] ML-based importance scoring
- [ ] Auto-strategy selection
- [ ] Cross-conversation optimization
- [ ] Real-time condensation
- [ ] Distributed condensation
- [ ] Custom provider plugins

## 8. Success Criteria

### 8.1 Technical Success

**Metrics**:
1. Token reduction: 30-50% improvement in lossless phase
2. Conversation preservation: >90% of user messages preserved
3. Performance: <20% overhead compared to current
4. Reliability: Zero data loss scenarios
5. Compatibility: All existing tests pass

### 8.2 User Success

**Metrics**:
1. User satisfaction: >80% prefer smart provider
2. Context continuity: Fewer "lost context" reports
3. Feature adoption: >30% users switch to smart provider
4. Documentation: >4/5 rating for clarity
5. Support tickets: <10% increase related to condensation

### 8.3 Business Success

**Metrics**:
1. Cost reduction: Average 15-25% lower token costs
2. User retention: No negative impact
3. Performance: No negative user experience reports
4. Maintenance: Development time within estimate
5. Quality: <5 critical bugs in first month

## 9. Risks and Mitigation

### 9.1 Technical Risks

**R-1**: Lossless phase may not achieve target reduction
- Mitigation: Have lossy phase as fallback
- Mitigation: Set realistic expectations
- Mitigation: Measure early and adjust

**R-2**: Reference system may be confusing
- Mitigation: Clear formatting and indication
- Mitigation: Optional expansion in UI
- Mitigation: User testing and feedback

**R-3**: Performance degradation
- Mitigation: Profiling and optimization
- Mitigation: Caching strategies
- Mitigation: Benchmark suite

### 9.2 User Experience Risks

**R-4**: Users may not understand new options
- Mitigation: Clear documentation
- Mitigation: Good defaults
- Mitigation: Help text in UI

**R-5**: Migration may cause confusion
- Mitigation: Automatic migration
- Mitigation: Clear changelog
- Mitigation: Migration guide

### 9.3 Business Risks

**R-6**: Timeline may slip
- Mitigation: Phased delivery
- Mitigation: MVP definition
- Mitigation: Regular checkpoints

**R-7**: User adoption may be low
- Mitigation: Smart provider as non-default initially
- Mitigation: Gather feedback
- Mitigation: Iterate based on usage

## 10. Next Steps

After requirements approval:

1. **Architecture Design** (Document 003)
   - Provider interface specification
   - Class diagrams
   - Sequence diagrams
   - Integration points

2. **Condensation Strategy** (Document 004)
   - Detailed algorithms
   - Pseudocode
   - Examples
   - Edge cases

3. **Implementation Roadmap** (Document 005)
   - Phased approach
   - Task breakdown
   - Testing strategy
   - Rollout plan

---

**Next Document**: `003-provider-architecture.md`