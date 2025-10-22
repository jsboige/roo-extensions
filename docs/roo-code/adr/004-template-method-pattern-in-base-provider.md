# ADR-004: Template Method Pattern in Base Provider

**Date**: 2025-10-02  
**Status**: ✅ Accepted  
**Deciders**: Architecture Team  
**Context**: Phase 1 - Context Condensation Provider System  

---

## Context and Problem Statement

All condensation providers share common logic (validation, metrics, error handling) but differ in their condensation algorithms. **How should we structure the provider hierarchy to maximize code reuse while allowing flexibility?**

## Decision Drivers

- ✅ **DRY Principle**: Don't repeat validation/metrics logic
- ✅ **Extensibility**: Easy to add new providers
- ✅ **Consistency**: Uniform behavior across providers
- ✅ **Flexibility**: Providers can customize what they need
- ✅ **Type Safety**: Compile-time enforcement of contracts

## Considered Options

### Option 1: Template Method Pattern ✅ CHOSEN

**Description**: Abstract base class with template method defining the algorithm skeleton.

```typescript
abstract class BaseCondensationProvider implements ICondensationProvider {
  // Template method (final, unchangeable)
  async condense(context, options): Promise<CondensationResult> {
    // 1. Validation (common)
    const validation = await this.validate(context, options)
    if (!validation.valid) return { messages: context.messages, cost: 0, error: validation.error }
    
    // 2. Start metrics (common)
    const startTime = Date.now()
    
    try {
      // 3. Provider-specific logic (hook method)
      const result = await this.condenseInternal(context, options)
      
      // 4. Add metrics (common)
      result.metrics = {
        providerId: this.id,
        timeElapsed: Date.now() - startTime,
        tokensSaved: context.prevContextTokens - (result.newContextTokens || 0),
      }
      
      return result
    } catch (error) {
      // 5. Error handling (common)
      return {
        messages: context.messages,
        cost: 0,
        error: error instanceof Error ? error.message : String(error),
        metrics: { providerId: this.id, timeElapsed: Date.now() - startTime },
      }
    }
  }
  
  // Hook method (abstract, must be implemented)
  protected abstract condenseInternal(
    context: CondensationContext,
    options: CondensationOptions,
  ): Promise<CondensationResult>
  
  // Override point (default implementation provided)
  async validate(context, options): Promise<{ valid: boolean; error?: string }> {
    if (context.messages.length === 0) {
      return { valid: false, error: "No messages to condense" }
    }
    return { valid: true }
  }
}
```

**Concrete Implementation**:
```typescript
class NativeCondensationProvider extends BaseCondensationProvider {
  readonly id = "native"
  readonly name = "Native Condensation"
  readonly description = "..."
  
  // Implement hook method only
  protected async condenseInternal(context, options): Promise<CondensationResult> {
    // Provider-specific logic
    const summary = await this.callAnthropicAPI(context, options)
    return {
      messages: [{ role: "assistant", content: summary, isSummary: true }],
      summary,
      cost: 0.002,
      newContextTokens: 100,
    }
  }
  
  // Optionally override validation
  async validate(context, options): Promise<{ valid: boolean; error?: string }> {
    const baseValidation = await super.validate(context, options)
    if (!baseValidation.valid) return baseValidation
    
    if (context.messages.length < 5) {
      return { valid: false, error: "Native provider requires at least 5 messages" }
    }
    
    return { valid: true }
  }
  
  async estimateCost(context): Promise<number> {
    // Provider-specific cost estimation
    return context.prevContextTokens * 0.000002
  }
}
```

**Pros**:
- ✅ **Code Reuse**: Common logic in one place
- ✅ **Consistency**: All providers follow same workflow
- ✅ **Flexibility**: Providers customize only what they need
- ✅ **Type Safety**: Abstract method enforced at compile time
- ✅ **Clear Contract**: Interface + base class define expectations
- ✅ **Easy Testing**: Can test base class separately

**Cons**:
- ⚠️ **Inheritance**: Single inheritance limitation (TypeScript)
- ⚠️ **Rigidity**: Hard to change template method later

### Option 2: Composition Pattern

**Description**: Separate services injected into providers.

```typescript
class ValidationService {
  validate(context, options) { /* ... */ }
}

class MetricsService {
  recordMetrics(providerId, result, startTime) { /* ... */ }
}

class CondensationProvider implements ICondensationProvider {
  constructor(
    private validator: ValidationService,
    private metrics: MetricsService,
  ) {}
  
  async condense(context, options) {
    await this.validator.validate(context, options)
    const result = await this.doCondense(context, options)
    this.metrics.recordMetrics(this.id, result, Date.now())
    return result
  }
}
```

**Pros**:
- ✅ Flexible composition
- ✅ Easy to mock services
- ✅ No inheritance

**Cons**:
- ❌ Complex: Multiple services to manage
- ❌ Boilerplate: Wiring everywhere
- ❌ Unclear: Less obvious workflow
- ❌ Overkill: Too much abstraction for this case

### Option 3: Mixins

**Description**: Use TypeScript mixins for shared behavior.

```typescript
function WithValidation<T extends Constructor>(Base: T) {
  return class extends Base {
    async validate(context, options) { /* ... */ }
  }
}

function WithMetrics<T extends Constructor>(Base: T) {
  return class extends Base {
    recordMetrics(...) { /* ... */ }
  }
}

class NativeProvider extends WithMetrics(WithValidation(BaseProvider)) {
  // ...
}
```

**Pros**:
- ✅ Multiple "inheritances"
- ✅ Flexible composition

**Cons**:
- ❌ Complex TypeScript types
- ❌ Hard to understand
- ❌ Debugging nightmare
- ❌ Poor IDE support

## Decision Outcome

**Chosen Option**: **Template Method Pattern** (Option 1)

### Rationale

1. **Perfect Fit for Use Case**
   - We have a clear algorithm with common steps
   - Variation is in one specific step (condensation logic)
   - All providers follow same workflow

2. **Simplicity**
   - Easy to understand: "inherit and implement `condenseInternal()`"
   - Clear contract: abstract method must be implemented
   - No complex setup or wiring

3. **Code Reuse Maximized**
   - Validation logic: once
   - Metrics collection: once
   - Error handling: once
   - Bug fixes benefit all providers

4. **Proven Pattern**
   - Well-known and understood
   - Documented extensively
   - Used successfully in many frameworks

### Implementation Details

#### Base Class Structure

```typescript
export abstract class BaseCondensationProvider implements ICondensationProvider {
  // Metadata (must be provided by subclass)
  abstract readonly id: string
  abstract readonly name: string
  abstract readonly description: string
  
  /**
   * Main condensation method - delegates to provider-specific implementation
   * This is the template method that orchestrates the workflow
   */
  async condense(
    context: CondensationContext,
    options: CondensationOptions,
  ): Promise<CondensationResult> {
    // Step 1: Validate
    const validation = await this.validate(context, options)
    if (!validation.valid) {
      return {
        messages: context.messages,
        cost: 0,
        error: validation.error,
      }
    }

    // Step 2: Start metrics
    const startTime = Date.now()

    // Step 3: Execute provider-specific logic
    try {
      const result = await this.condenseInternal(context, options)

      // Step 4: Augment with metrics
      const timeElapsed = Date.now() - startTime
      result.metrics = {
        providerId: this.id,
        timeElapsed,
        tokensSaved: context.prevContextTokens - (result.newContextTokens || 0),
        ...result.metrics, // Allow provider to add custom metrics
      }

      return result
    } catch (error) {
      // Step 5: Handle errors uniformly
      return {
        messages: context.messages, // Preserve original on error
        cost: 0,
        error: error instanceof Error ? error.message : String(error),
        metrics: {
          providerId: this.id,
          timeElapsed: Date.now() - startTime,
        },
      }
    }
  }

  /**
   * Provider-specific condensation implementation
   * Must be implemented by concrete providers
   * @internal
   */
  protected abstract condenseInternal(
    context: CondensationContext,
    options: CondensationOptions,
  ): Promise<CondensationResult>

  /**
   * Validate context and options
   * Default implementation, can be overridden
   */
  async validate(
    context: CondensationContext,
    options: CondensationOptions,
  ): Promise<{ valid: boolean; error?: string }> {
    // Base validation
    if (!context.messages || context.messages.length === 0) {
      return { valid: false, error: "No messages to condense" }
    }

    if (!options.apiHandler) {
      return { valid: false, error: "API handler is required" }
    }

    return { valid: true }
  }

  /**
   * Estimate cost of condensation
   * Must be implemented by concrete providers
   */
  abstract estimateCost(context: CondensationContext): Promise<number>
}
```

#### Extension Points

Providers can customize behavior at multiple levels:

1. **Required**: Implement `condenseInternal()`
2. **Optional**: Override `validate()` for provider-specific validation
3. **Optional**: Add custom metrics in result
4. **Required**: Implement `estimateCost()`

## Consequences

### Positive

- ✅ **Code Reuse**: 90%+ common code in base class
- ✅ **Consistency**: All providers behave uniformly
- ✅ **Maintainability**: Bug fixes in one place
- ✅ **Extensibility**: New providers just implement `condenseInternal()`
- ✅ **Type Safety**: Abstract method enforced
- ✅ **Testing**: Can test template separately from implementations

### Negative

- ⚠️ **Single Inheritance**: Can't extend another class
  - **Mitigation**: Not an issue in this context
  - **Alternative**: Use composition for unrelated functionality

- ⚠️ **Rigidity**: Hard to change template after deployment
  - **Mitigation**: Design carefully upfront
  - **Reality**: Template is stable (validation → execute → metrics)

### Neutral

- ℹ️ **Learning Curve**: Developers must understand pattern
  - Documentation and examples provided
  - Pattern is well-known

## Extension Points Documentation

### For Provider Authors

```typescript
/**
 * Example: Creating a new provider
 */
class MyCustomProvider extends BaseCondensationProvider {
  readonly id = "my-custom"
  readonly name = "My Custom Provider"
  readonly description = "Uses custom API for condensation"
  
  // Required: Implement condensation logic
  protected async condenseInternal(
    context: CondensationContext,
    options: CondensationOptions,
  ): Promise<CondensationResult> {
    // 1. Call your API
    const summary = await this.callMyAPI(context, options)
    
    // 2. Build result
    return {
      messages: [{ role: "assistant", content: summary, isSummary: true }],
      summary,
      cost: 0.001,
      newContextTokens: 50,
    }
  }
  
  // Optional: Custom validation
  async validate(context, options) {
    const baseValid = await super.validate(context, options)
    if (!baseValid.valid) return baseValid
    
    // Add custom checks
    if (context.messages.length < 10) {
      return { valid: false, error: "Need at least 10 messages" }
    }
    
    return { valid: true }
  }
  
  // Required: Cost estimation
  async estimateCost(context: CondensationContext): Promise<number> {
    return context.prevContextTokens * 0.000001
  }
}
```

## Testing Strategy

### Test Base Class Separately

```typescript
// Create test provider for testing base class
class TestProvider extends BaseCondensationProvider {
  readonly id = "test"
  readonly name = "Test Provider"
  readonly description = "For testing"
  
  protected async condenseInternal(context, options) {
    return {
      messages: context.messages.slice(0, 1),
      cost: 0.01,
      newContextTokens: 100,
    }
  }
  
  async estimateCost(context) {
    return 0.01
  }
}

describe("BaseCondensationProvider", () => {
  it("should add metrics to result", async () => {
    const provider = new TestProvider()
    const result = await provider.condense(mockContext, mockOptions)
    
    expect(result.metrics).toBeDefined()
    expect(result.metrics.providerId).toBe("test")
    expect(result.metrics.timeElapsed).toBeGreaterThan(0)
  })
  
  it("should handle errors gracefully", async () => {
    class ErrorProvider extends TestProvider {
      protected async condenseInternal() {
        throw new Error("Test error")
      }
    }
    
    const provider = new ErrorProvider()
    const result = await provider.condense(mockContext, mockOptions)
    
    expect(result.error).toBe("Test error")
    expect(result.messages).toEqual(mockContext.messages) // Original preserved
  })
})
```

## Related Decisions

- [ADR-001: Registry Pattern](./001-registry-pattern-over-plugin-system.md)
- [ADR-003: Backward Compatibility](./003-backward-compatibility-strategy.md)

## References

- [Gang of Four - Template Method Pattern](https://en.wikipedia.org/wiki/Template_method_pattern)
- [Refactoring Guru - Template Method](https://refactoring.guru/design-patterns/template-method)
- [TypeScript Handbook - Abstract Classes](https://www.typescriptlang.org/docs/handbook/2/classes.html#abstract-classes-and-members)

---

**Status**: Active  
**Last Updated**: 2025-10-02  
**Next Review**: Phase 2 Planning