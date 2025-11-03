# feat(condense): provider-based context condensation architecture

## Summary

This PR implements a pluggable Context Condensation Provider architecture to address conversation context management challenges in Roo. The solution provides configurable strategies with qualitative context preservation as the primary design principle, offering users control over how their conversation history is processed while maintaining important grounding information.

## Problem Statement

Roo conversations grow indefinitely, causing several critical issues:
- API token limits and context loss in long conversations
- Existing solutions lack user control and predictable behavior
- Performance degradation with large conversation histories
- Community needs flexible strategies for different use cases
- Unreliable conversation grounding affecting AI performance

## Solution Architecture

### Provider System Design

The implementation follows a clean separation of concerns with a pluggable architecture:

- **`ICondensationProvider`**: Standardized interface defining validation, gain estimation, and condensation methods
- **`CondensationManager`**: Policy orchestration handling thresholds, triggers, and provider selection
- **`ProviderRegistry`**: Provider lifecycle management with enable/disable capabilities

### Four Implemented Providers

1. **Native**: LLM-based condensation using injected apiHandler for conversation summarization
2. **Lossless**: Content deduplication removing duplicate files and consolidating structured data
3. **Truncation**: Priority-based content removal with configurable truncation order
4. **Smart**: Meta-provider that delegates to other providers based on configuration

### Smart Provider: Meta-Provider Architecture

The Smart Provider functions as a meta-provider that delegates condensation tasks to other providers based on configuration. It does not implement its own condensation logic but orchestrates other providers through a delegation pattern.

**Design Philosophy**: Provider delegation and configuration-based selection

**Delegation Pattern**:
- **Provider Selection**: Chooses target provider based on configuration
- **Task Delegation**: Uses `delegateToProvider()` method to forward requests
- **Result Handling**: Returns results from delegated provider without modification

**Configuration-Based Behavior**:
- Provider selection through configuration object
- Three built-in presets: conservative, balanced, aggressive
- Presets provide qualitative strategies for different conversation patterns
- Custom configuration available for advanced users via JSON editor

**Built-in Presets**:

**Conservative Preset** - Maximum Context Preservation:
- Strategy: Preserve maximum conversation context and grounding
- Lossless prelude with all optimizations enabled
- Pass 1: Individual mode preserving all conversation messages, gently summarizing very old tool results only
- Pass 2: Context-aware fallback maintaining conversation flow
- Use case: Critical conversations requiring maximum context retention

**Balanced Preset** - Recommended for General Use:
- Strategy: Balance between preservation and reduction of non-essential content
- Lossless prelude with smart optimizations
- Pass 1: Preserve conversation, intelligently summarize old tool results
- Pass 2: Truncate large tool outputs if still needed
- Pass 3: Last resort batch summarization of very old messages
- Use case: General use with optimal balance of context vs reduction

**Aggressive Preset** - Maximum Reduction:
- Strategy: Aggressive reduction while preserving essential conversation context
- Lossless prelude with aggressive optimizations
- Pass 1: Suppress non-essential tool content from old messages
- Pass 2: Aggressive truncation of middle zone tool outputs
- Pass 3: Emergency batch summarization as last resort
- Use case: Long conversations where maximum reduction is required

### Safeguards and Stability

**Loop Prevention**:
- Loop-guard with maximum 3 attempts per task
- Cooldown period before attempt counter reset
- No-op result when guard triggered

**Threshold Management**:
- Hysteresis logic (trigger at 90%, stop at 70%)
- Gain estimation to skip unnecessary condensation
- Provider-specific maximum context limits

**Quality Assurance**:
- Comprehensive input validation
- Error handling with graceful degradation
- Telemetry and metrics collection

## User Interface Integration

### Settings Panel Features
- Provider selection dropdown with clear descriptions
- Smart Provider configuration with delegation options
- JSON editor for advanced configuration
- Real-time validation with error messages
- Intuitive configuration management

### User Experience
- Simple provider selection for most users
- Advanced JSON configuration for power users
- Clear visual feedback on settings changes
- Backward compatibility with existing configurations

## Testing and Validation

### Comprehensive Test Coverage
- **Unit Tests**: 1700+ lines with 100% coverage of core logic
- **Integration Tests**: 500+ lines on 7 real-world conversations
- **UI Tests**: Complete component validation with functional testing approach
- **Manual Testing**: All providers validated on real conversations
- **Performance Testing**: Metrics validation across different scenarios

### Quality Assurance Results
- All backend tests passing (100% pass rate)
- UI tests stabilized with functional testing approach
- Loop-guard functionality verified and tested
- Provider limits properly enforced
- Documentation validated against implementation

### Provider Implementation Characteristics

**Native Provider**
- Implementation: LLM-based condensation using injected apiHandler
- API Usage: Makes API calls through apiHandler.createMessage()
- Cost: Incurs API costs based on LLM usage
- Context Strategy: Conversation summarization via LLM

**Lossless Provider**
- Implementation: Content deduplication and structured data consolidation
- API Usage: No API calls (local processing)
- Cost: $0 (no API calls)
- Context Strategy: Removes duplicate files, consolidates tool calls and file reads

**Truncation Provider**
- Implementation: Priority-based content removal with configurable order
- API Usage: No API calls (local processing)
- Cost: $0 (no API calls)
- Context Strategy: Removes content based on priority (images first, then tool responses, etc.)

**Smart Provider**
- Implementation: Meta-provider with delegation pattern
- API Usage: Depends on delegated provider
- Cost: Depends on delegated provider
- Context Strategy: Delegates to configured provider

## Implementation Details

### Files Changed
- **Core logic**: `src/core/condense/` (62 files)
- **UI components**: `webview-ui/src/components/settings/` (3 files)
- **Tests**: 32 files (Backend: 16, UI: 16)
- **Documentation**: 13 files

### Key Classes and Components
- `ICondensationProvider`: Provider contract interface
- `BaseCondensationProvider`: Abstract base with validation
- `ProviderRegistry`: Singleton provider management
- `CondensationManager`: Policy orchestration
- Provider implementations: Native, Lossless, Truncation, Smart

## Benefits

### For Users
- **User Control**: Choose strategy matching your workflow and requirements
- **Context Preservation**: Important conversation grounding maintained
- **Predictable Behavior**: Consistent results with configurable options
- **Performance**: Fast processing with minimal overhead
- **Flexibility**: From zero-loss to configurable reduction options
- **Accessibility**: Simple provider selection with advanced options

### For the System
- **Stability**: Loop prevention and error handling
- **Maintainability**: Clean architecture with separation of concerns
- **Extensibility**: Easy to add new providers
- **Monitoring**: Comprehensive telemetry and metrics
- **Quality**: Extensive test coverage with real-world validation

## Community Issues Addressed

This implementation addresses patterns identified in community feedback:
- Context loss in long conversations affecting conversation continuity
- Lack of control over condensation strategy
- Unpredictable behavior with existing solutions
- Performance concerns with large conversations
- Need for configurable options for different use cases

Note: This implementation was developed independently to address these reported patterns, with a focus on improving conversation grounding reliability.

## Limitations and Considerations

### Known Limitations
- Token counting uses approximation method
- LLM-based condensation adds latency and cost
- Actual reduction varies significantly by conversation content
- React test environment requires functional testing approach

### Breaking Changes
None - Native provider ensures 100% backward compatibility.

### Migration Path
- **Existing users**: No action required (Native provider selected by default)
- **New users**: Can opt into other providers via settings
- **Advanced users**: Can customize Smart Provider via JSON editor

## Documentation

Comprehensive documentation available in:
- `src/core/condense/README.md`: Overview and quick start
- `src/core/condense/docs/ARCHITECTURE.md`: System architecture
- `src/core/condense/providers/smart/README.md`: Smart Provider delegation approach

## Pre-Merge Checklist

- [x] All tests passing (100% backend + functional UI tests)
- [x] ESLint clean with no violations
- [x] TypeScript strict mode enabled
- [x] Documentation complete and consistent
- [x] Backward compatible (Native provider preserves existing behavior)
- [x] No breaking changes
- [x] Loop-guard implemented and tested
- [x] Provider limits enforced
- [x] UI manually tested and validated
- [x] Qualitative approach implemented and documented
- [x] Quality audit completed with corrections applied

## Risk Assessment and Mitigation

### Low Risk Items
- **Performance impact**: Minimal overhead with efficient implementation
- **Memory usage**: Controlled through provider-specific limits
- **Compatibility**: 100% backward compatibility maintained

### Medium Risk Items
- **LLM dependency**: Mitigated with fallback strategies and cost controls
- **Test stability**: Addressed with functional testing approach
- **User adoption**: Mitigated with sensible defaults and gradual opt-in

### Mitigation Strategies
- Comprehensive monitoring and telemetry
- Graceful degradation on errors
- Clear documentation and user guidance
- Community feedback collection for provider configuration tuning

## Future Considerations

### Community Involvement
The Smart Provider presets will benefit from community feedback to fine-tune the qualitative strategies for different use cases and conversation patterns.

### Extensibility
The pluggable architecture enables easy addition of new providers and strategies as community needs evolve.

### Monitoring
Post-merge monitoring will help identify usage patterns and opportunities for improvement.

---

**Status**: Ready for merge with comprehensive testing, documentation, and quality assurance completed.