# ADR-002: Singleton Pattern for Manager and Registry

**Date**: 2025-10-02  
**Status**: ✅ Accepted  
**Deciders**: Architecture Team  
**Context**: Phase 1 - Context Condensation Provider System  

---

## Context and Problem Statement

The `CondensationManager` and `ProviderRegistry` need to maintain consistent state across the application. **How should we ensure a single source of truth for provider registration and management?**

## Decision Drivers

- ✅ **Consistency**: Same state visible everywhere
- ✅ **Simplicity**: Easy access without dependency injection
- ✅ **Performance**: Avoid multiple instances
- ✅ **Testability**: Must be resettable for tests

## Considered Options

### Option 1: Singleton Pattern ✅ CHOSEN

**Implementation**:
```typescript
class ProviderRegistry {
  private static instance: ProviderRegistry

  private constructor() {
    // Private constructor prevents direct instantiation
  }

  static getInstance(): ProviderRegistry {
    if (!ProviderRegistry.instance) {
      ProviderRegistry.instance = new ProviderRegistry()
    }
    return ProviderRegistry.instance
  }

  // For testing only
  clear(): void {
    this.providers.clear()
    this.configs.clear()
  }
}

// Usage
const registry = ProviderRegistry.getInstance()
```

**Pros**:
- ✅ Guaranteed single instance
- ✅ Global access point
- ✅ Lazy initialization
- ✅ Simple to use
- ✅ Clear ownership

**Cons**:
- ⚠️ Global state (can complicate testing)
- ⚠️ Hidden dependencies
- ⚠️ Harder to mock

### Option 2: Dependency Injection

**Implementation**:
```typescript
class ProviderRegistry {
  // No singleton, just a regular class
}

// Pass registry everywhere
class CondensationManager {
  constructor(private registry: ProviderRegistry) {}
}

// Usage requires wiring
const registry = new ProviderRegistry()
const manager = new CondensationManager(registry)
```

**Pros**:
- ✅ Explicit dependencies
- ✅ Easy to mock in tests
- ✅ No global state

**Cons**:
- ❌ Complex wiring throughout app
- ❌ Boilerplate code everywhere
- ❌ Overkill for this use case

### Option 3: Module-Level Singleton

**Implementation**:
```typescript
// registry.ts
const registry = new ProviderRegistry()
export { registry }

// Usage
import { registry } from './registry'
```

**Pros**:
- ✅ Simple
- ✅ Single instance per module

**Cons**:
- ❌ Hard to reset for tests
- ❌ Can't lazy initialize
- ❌ Less control over instantiation

## Decision Outcome

**Chosen Option**: **Singleton Pattern** (Option 1)

### Rationale

1. **Appropriate for This Use Case**
   - Registry and Manager are truly application-wide singletons
   - No legitimate need for multiple instances
   - State must be consistent across app

2. **Simplicity**
   - No complex DI framework needed
   - Easy to use: `getProviderRegistry()`
   - Clear and intuitive

3. **Performance**
   - Lazy initialization (created on first use)
   - No overhead of DI container

4. **VSCode Extension Context**
   - Extensions are single-instance by nature
   - No multi-tenant concerns
   - Global state is acceptable

### Testing Strategy

The global state concern is addressed with a `clear()` method:

```typescript
describe("SomeTest", () => {
  beforeEach(() => {
    // Reset state before each test
    const registry = getProviderRegistry()
    registry.clear()
    
    // Re-register needed providers
    const nativeProvider = new NativeCondensationProvider()
    registry.register(nativeProvider, { enabled: true })
  })
})
```

### Implementation Details

```typescript
// Convenience function for cleaner syntax
export function getProviderRegistry(): ProviderRegistry {
  return ProviderRegistry.getInstance()
}

export function getCondensationManager(): CondensationManager {
  return CondensationManager.getInstance()
}

// Usage is clean and consistent
const manager = getCondensationManager()
const result = await manager.condense(messages, apiHandler)
```

## Consequences

### Positive

- ✅ **Simplicity**: Easy to use, no boilerplate
- ✅ **Consistency**: Single source of truth
- ✅ **Performance**: Lazy init, no overhead
- ✅ **Clarity**: Clear global access pattern

### Negative

- ⚠️ **Testing Complexity**: Requires explicit reset
  - **Mitigation**: `clear()` method provided
  - **Best Practice**: Always reset in `beforeEach()`

- ⚠️ **Hidden Dependencies**: Not visible in constructor
  - **Mitigation**: Well-documented usage pattern
  - **Impact**: Minimal in this context

### Neutral

- ℹ️ **Not a Pure Function Approach**: State exists
  - This is intentional and appropriate here

## Alternatives Considered

### Service Locator + DI Hybrid

Singleton registry, but DI for manager.

**Verdict**: Rejected. Inconsistent approach, adds complexity without benefit.

### Static Methods Only

No instances at all, everything static.

**Verdict**: Rejected. Harder to test, less flexible.

## Experience Report

### What Worked Well

- Singleton was easy to implement
- Testing with `clear()` works reliably
- No unexpected issues in practice
- Developer experience is good

### What Could Be Improved

- Could add warning if `clear()` called outside tests
- Could add better type inference for getInstance()

### Lessons Learned

- Singleton is fine for true application-wide state
- Testing concerns can be addressed with proper design
- Simple > Complex in this context

## Related Decisions

- [ADR-001: Registry Pattern](./001-registry-pattern-over-plugin-system.md)
- [ADR-003: Backward Compatibility Strategy](./003-backward-compatibility-strategy.md)

## References

- [Gang of Four - Singleton Pattern](https://en.wikipedia.org/wiki/Singleton_pattern)
- [Martin Fowler - Singleton](https://martinfowler.com/bliki/Singleton.html)
- [TypeScript Handbook - Classes](https://www.typescriptlang.org/docs/handbook/2/classes.html)

---

**Status**: Active  
**Last Updated**: 2025-10-02  
**Next Review**: Phase 2 Planning