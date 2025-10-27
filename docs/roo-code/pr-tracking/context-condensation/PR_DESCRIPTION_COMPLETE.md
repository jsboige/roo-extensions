# Pull Request: Context Condensation - Smart Provider Implementation

## Summary

This PR introduces a modular context condensation system with four providers to intelligently reduce long conversation size while preserving essential information for assistant interaction consistency:

- **Native Provider**: Direct integration with Claude Code API
- **Lossless Provider**: Lossless optimizations (deduplication, consolidation)
- **Truncation Provider**: Mechanical reduction by thresholds
- **Smart Provider**: Multi-pass pipeline with conditional thresholds

The system enables controlled context reduction while maintaining relevance of preserved information.

## Technical Architecture

### Modular Interface

The system uses an `ICondensationProvider` interface that enables:

- Customizable condensation strategy configurations
- Easy extension with new providers
- Automatic configuration validation
- Transparent integration with existing message system

### Smart Provider: Multi-Pass Architecture

The Smart Provider implements a conditional multi-pass architecture:

#### Optional Lossless Prelude
- Deduplication of identical file reads
- Consolidation of similar tool results
- Removal of obsolete states
- Executed before any reduction pass

#### Conditional Pass Pipeline
Each pass is configured with:
- **Selection Strategy**: `preserve_recent` or `preserve_percent`
- **Execution Mode**: `individual` (message by message) or `batch` (group)
- **Granular Operations**: `keep`, `suppress`, `truncate`, `summarize`
- **Conditional Thresholds**: execution based on current token count

#### Content Type Architecture
Each message is processed according to three content types:
- **messageText**: User/assistant conversation text
- **toolParameters**: Tool call parameters
- **toolResults**: Results returned by tools

## Configuration Presets

### CONSERVATIVE
**Goal**: Maximum context preservation for critical conversations

**Architecture**: 2 conditional passes
- **Pass 1**: Individual mode - Conversation preservation
  - Preserves all conversation messages
  - Summarizes only very old tool results (>4000 tokens)
  - Execution threshold: always
  
- **Pass 2**: Batch mode - Fallback if context too large
  - Preserves 15 most recent messages
  - Summarizes older messages
  - Conditional threshold: 60K tokens

### BALANCED
**Goal**: Balance between preservation and reduction for general usage

**Architecture**: 3 conditional passes
- **Pass 1**: Individual mode - Intelligent preservation
  - Preserves 12 recent messages
  - Summarizes tool results (>2000 tokens)
  - Execution threshold: always

- **Pass 2**: Individual mode - Selective truncation
  - Preserves 8 recent messages
  - Truncates parameters (>1000 tokens) and results (>1500 tokens)
  - Conditional threshold: 50K tokens

- **Pass 3**: Batch mode - Last resort
  - Preserves 10 recent messages
  - Summarizes older messages
  - Conditional threshold: 40K tokens

### AGGRESSIVE
**Goal**: Aggressive reduction for very long conversations

**Architecture**: 3 passes with aggressive execution
- **Pass 1**: Individual mode - Selective suppression
  - Preserves 25 recent messages
  - Suppresses old parameters (>200 tokens) and results (>300 tokens)
  - Execution threshold: always

- **Pass 2**: Individual mode - Median zone truncation
  - Preserves 8 recent messages
  - Aggressively truncates parameters (>300 tokens) and results (>400 tokens)
  - Execution threshold: always

- **Pass 3**: Batch mode - Emergency fallback
  - Preserves 6 recent messages
  - Summarizes very old messages
  - Conditional threshold: 35K tokens

## Available Operations

### Keep
Preserves content without modification

### Suppress
Completely removes content (used for non-essential data)

### Truncate
Reduces content with limits:
- `maxChars`: Maximum number of characters
- `maxLines`: Maximum number of lines

### Summarize
Generates LLM summary with:
- `maxTokens`: Maximum summary size
- `keepFirst/keepLast`: Messages to preserve in batch summary

## Configuration

### Global Parameters
- Default provider: `BALANCED`
- Automatic activation threshold: configurable
- Debug mode: available for development

### Per-Message Parameters
- Individual thresholds by content type
- Customizable preservation strategies
- Conditional execution mode

## Testing

### Test Coverage
- Unit tests for each provider
- Integration tests for multi-pass architecture
- Load tests with long conversations
- Regression tests to ensure context preservation

### Test Scenarios
- Conversations with 1000+ messages
- Mixed content (text, tools, files)
- Edge cases (token thresholds)
- Performance with different presets

## Integration

### User Interface
- Provider selection in settings
- Real-time condensation preview
- Visual reduction indicators
- Preview mode for validation

### API
- Transparent integration with `ApiMessage[]`
- Progress callbacks for long operations
- Robust error handling
- Extended metadata support

## Security and Validation

### Configuration Validation
- Automatic threshold verification
- Invalid configuration detection
- Fallback to safe configuration

### Data Preservation
- Guaranteed preservation of critical messages
- Automatic backup before condensation
- Recovery mode in case of errors

## Performance

### Optimizations
- Parallel execution of independent passes
- Condensation result caching
- Optimized memory allocation
- Streaming support for large conversations

### Limits
- Maximum conversation size: configurable
- Processing time: proportional to size
- Memory usage: optimized for long conversations

## Documentation

### Technical Documentation
- Detailed provider architecture
- Preset configuration guide
- Complete API reference
- Usage examples

### User Documentation
- Installation and configuration guide
- Best practices for each preset
- FAQ and troubleshooting
- Recommended use cases

## Migration

### Compatibility
- Backward compatibility with existing configurations
- Automatic migration of old settings
- Compatibility mode for transitions

### Updates
- Automatic new version detection
- Transparent configuration migration
- User preference preservation