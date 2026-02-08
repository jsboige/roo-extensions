# Context Condensation System - PR Description

## Overview

This PR introduces a modular context condensation system with four providers to intelligently reduce long conversation size while preserving essential information for assistant interaction consistency:

- **Native Provider**: Original condensation method using Anthropic API
- **Lossless Provider**: Pre-condensation optimizations with message consolidation
- **Truncation Provider**: Simple size-based message reduction
- **Smart Provider**: Conditional multi-pass architecture with content-type thresholds

## Key Features

### Provider Architecture
- Modular provider system with easy extension
- Configurable condensation strategy configurations
- Transparent integration with existing message system

### Smart Provider Implementation
The Smart Provider implements a conditional multi-pass architecture:

- **Pass 1**: Lossless prelude (message consolidation, tool deduplication)
- **Pass 2**: Selective suppression (old tools, large results)
- **Pass 3**: Smart summarization (tool results, parameters)
- **Pass 4**: Message-level thresholds (content-type specific processing)

### Configuration System

### Global Parameters
- Default provider: `BALANCED`
- Automatic activation threshold: configurable

### Preset Configurations
- **CONSERVATIVE**: Quality-first with high thresholds
- **BALANCED**: Moderate approach with content-type awareness
- **AGGRESSIVE**: Maximum reduction with low thresholds

### Hierarchical Thresholds (Phase 7)
- Global thresholds: trigger/stop/minGain tokens
- Provider-specific overrides supported
- Profile-based thresholds (% of context window)

## Performance Metrics & Monitoring

### Metrics Collection
- Processing time measurement
- Token reduction tracking
- Cost estimation
- Provider-specific performance data

### Real-time Monitoring
- Provider selection in settings
- Real-time condensation preview
- Visual reduction indicators

## Configuration

### Thresholds
- Configurable conversation size limits (triggerTokens/stopTokens)
- Provider-specific threshold overrides
- Message-level content-type thresholds

## Migration

### Compatibility
- Backward compatibility with existing configurations
- Automatic migration of old settings
- Compatibility mode for transitions
- Automatic new version detection
- Transparent configuration migration
- User preference preservation

## Testing

### Test Coverage
- Unit tests for each provider
- Integration tests for multi-pass architecture
- Load tests with long conversations
- Edge cases (token thresholds)
- Performance with different presets

## Implementation Details

### Core Components
- `CondensationManager`: Central orchestration with hierarchical thresholds
- `BaseCondensationProvider`: Common interface and validation
- Provider-specific implementations with optimized algorithms
- Performance metrics collection throughout the pipeline

### Provider Algorithms
- **Native**: Direct Anthropic API integration with conversation summarization
- **Lossless**: Message consolidation and tool deduplication
- **Truncation**: Size-based reduction with configurable limits
- **Smart**: Multi-pass processing with conditional logic

### Configuration Management
- Type-safe configuration with validation
- Hierarchical threshold system (global → provider → profile)
- Migration system for backward compatibility
- Real-time configuration updates

### Performance Optimization
- Token estimation for accurate processing
- Efficient message transformation
- Memory-conscious processing for large conversations