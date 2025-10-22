# feat(condense): provider-based context condensation architecture

## Summary

This PR introduces a pluggable Context Condensation Provider architecture to address stability issues with the existing condensation system. The implementation provides four specialized providers with configurable strategies and improved safeguards.

## Technical Implementation

### Architecture Overview

The system follows a clear separation of concerns:
- **`ICondensationProvider`**: Strategy contract defining validation, gain estimation, and condensation methods
- **`CondensationManager`**: Policy orchestration handling thresholds, triggers, and provider selection
- **`ProviderRegistry`**: Provider lifecycle management with enable/disable capabilities

### Four Implemented Providers

1. **Native**: Backward-compatible wrapper preserving existing behavior
2. **Lossless**: Deduplication-based reduction (40-60% reduction, $0 cost)
3. **Truncation**: Mechanical chronological truncation (70-85% reduction, <10ms)
4. **Smart**: Multi-pass LLM-based condensation with configurable presets

### Smart Provider Details

**Pass-based processing:**
- Pass 1: Quality-first LLM summarization
- Pass 2: Fallback truncation if budget exceeded
- Pass 3: Batch summarization of old messages

**Three presets:**
- Conservative: Minimal summarization (60-75% reduction)
- Balanced: Moderate summarization (75-85% reduction)  
- Aggressive: Maximum reduction (85-95% reduction)

### Safeguards and Stability

**Loop prevention:**
- Loop-guard with maximum 3 attempts per task
- Cooldown period before attempt counter reset
- No-op result when guard triggered

**Threshold management:**
- Hysteresis logic (trigger at 90%, stop at 70%)
- Gain estimation to skip unnecessary condensation
- Provider-specific maximum context limits

### UI Integration

**Settings panel features:**
- Provider selection dropdown
- Smart Provider preset cards with descriptions
- JSON editor for advanced configuration
- Real-time validation with error messages

## Testing and Validation

### Test Coverage
- Backend: 110+ tests (100% pass rate)
- UI: 45 tests (100% pass rate)
- Real-world fixtures: 7 large conversation scenarios

### Performance Benchmarks
- Lossless: 40-60% reduction, 0 API calls, <5ms
- Truncation: 70-85% reduction, 0 API calls, <10ms
- Smart Conservative: 60-75% reduction, ~$0.01-0.05
- Smart Balanced: 75-85% reduction, ~$0.05-0.15
- Smart Aggressive: 85-95% reduction, ~$0.15-0.30

## Implementation Details

### Files Changed
- Core logic: `src/core/condense/` (62 files)
- UI components: `webview-ui/src/components/settings/` (3 files)
- Tests: 32 files (Backend: 16, UI: 16)
- Documentation: 13 files

### Key Classes
- `ICondensationProvider`: Provider contract
- `BaseCondensationProvider`: Abstract base with validation
- `ProviderRegistry`: Singleton provider management
- `CondensationManager`: Policy orchestration
- Provider implementations: Native, Lossless, Truncation, Smart

## Related Issues

This implementation addresses patterns identified in:
- #8158: Condensation loops causing performance issues
- #4118: Inflexible thresholds per model/profile
- #5229: Profile context condense thresholds not working
- #4475: Context window size settings ignored for vLLM

Note: This implementation was developed independently to address these reported issues patterns.

## Limitations and Considerations

### Known Limitations
- React test environment requires workaround in webview-ui/package.json
- Token counting uses approximation method
- LLM-based condensation adds latency and cost

### Breaking Changes
None - Native provider ensures 100% backward compatibility.

### Migration Path
- Existing users: No action required (Native provider selected by default)
- New users: Can opt into other providers via settings
- Advanced users: Can customize Smart Provider via JSON editor

## Documentation

Comprehensive documentation available in:
- `src/core/condense/README.md`: Overview and quick start
- `src/core/condense/docs/ARCHITECTURE.md`: System architecture
- `src/core/condense/providers/smart/README.md`: Smart Provider details

## Pre-Merge Checklist

- [x] All tests passing (100% backend + UI)
- [x] ESLint clean
- [x] TypeScript strict mode enabled
- [x] Documentation complete
- [x] Backward compatible (Native provider preserves existing behavior)
- [x] No breaking changes
- [x] Rebased on latest main
- [x] Loop-guard implemented and tested
- [x] Provider limits enforced
- [x] UI manually tested