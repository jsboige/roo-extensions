# ADR-001: Registry Pattern Over Plugin System

**Date**: 2025-10-02  
**Status**: ✅ Accepted  
**Deciders**: Architecture Team  
**Context**: Phase 1 - Context Condensation Provider System  

---

## Context and Problem Statement

We need a system to manage multiple condensation providers (Native, OpenAI, future providers). The question is: **How should providers be registered, discovered, and managed?**

Two main approaches were considered:
1. **Registry Pattern**: Central registry with explicit provider registration
2. **Plugin System**: Dynamic loading of providers from external modules/files

## Decision Drivers

### Technical Requirements
- ✅ **Extensibility**: Easy to add new providers
- ✅ **Type Safety**: Full TypeScript support
- ✅ **Performance**: Minimal overhead
- ✅ **Testability**: Easy to mock and test
- ✅ **Maintainability**: Clear ownership and lifecycle

### Product Requirements
- ✅ **Backward Compatibility**: Must work with existing code
- ✅ **User Experience**: Providers available immediately
- ✅ **Reliability**: No dynamic loading failures
- ✅ **Security**: No arbitrary code execution

## Considered Options

### Option 1: Registry Pattern ✅ CHOSEN

**Description**: Centralized `ProviderRegistry` singleton where providers are explicitly registered at initialization.

```typescript
// Registration at app startup
const registry = getProviderRegistry()
const nativeProvider = new NativeCondensationProvider()
registry.register(nativeProvider, { enabled: true, priority: 100 })
```

**Pros**:
- ✅ Full type safety (compile-time checking)
- ✅ No dynamic loading complexity
- ✅ Clear provider lifecycle
- ✅ Easy testing (explicit registration in tests)
- ✅ No security concerns
- ✅ Immediate availability (no loading delay)
- ✅ Simple mental model

**Cons**:
- ⚠️ Providers must be compiled with the app
- ⚠️ Cannot add providers without rebuilding
- ⚠️ All providers loaded even if unused (minimal impact)

### Option 2: Plugin System

**Description**: Dynamic loading of provider modules from filesystem or registry.

```typescript
// Dynamic loading at runtime
const pluginManager = getPluginManager()
await pluginManager.loadPlugin('path/to/openai-provider.js')
```

**Pros**:
- ✅ Providers can be added without rebuilding
- ✅ Third-party providers possible
- ✅ Lazy loading (load only when needed)

**Cons**:
- ❌ Loss of type safety (dynamic imports)
- ❌ Complex loading logic and error handling
- ❌ Security concerns (arbitrary code execution)
- ❌ Difficult to test (filesystem dependencies)
- ❌ Startup performance hit (async loading)
- ❌ Version compatibility issues
- ❌ Distribution and packaging complexity

## Decision Outcome

**Chosen Option**: **Registry Pattern** (Option 1)

### Rationale

1. **Type Safety is Critical**
   - VSCode extension development relies heavily on TypeScript
   - Dynamic loading breaks type checking
   - Compile-time errors > Runtime errors

2. **Simplicity Wins**
   - Registry pattern is simple and well-understood
   - No need for plugin infrastructure
   - Easier onboarding for contributors

3. **Security First**
   - No arbitrary code execution
   - All code reviewed and compiled together
   - No plugin sandboxing needed

4. **Performance**
   - Zero loading overhead
   - No async initialization delays
   - Predictable startup behavior

5. **Current Scope**
   - Phase 1 goal: Establish architecture
   - Plugin system can be added later if needed
   - YAGNI (You Aren't Gonna Need It) principle

### Implementation

```typescript
// src/core/condense/ProviderRegistry.ts
export class ProviderRegistry {
  private static instance: ProviderRegistry
  private providers: Map<string, ICondensationProvider> = new Map()
  private configs: Map<string, ProviderConfig> = new Map()

  private constructor() {}

  static getInstance(): ProviderRegistry {
    if (!ProviderRegistry.instance) {
      ProviderRegistry.instance = new ProviderRegistry()
    }
    return ProviderRegistry.instance
  }

  register(provider: ICondensationProvider, config?: Partial<ProviderConfig>): void {
    this.providers.set(provider.id, provider)
    this.configs.set(provider.id, { ...defaultConfig, ...config })
  }

  getProvider(providerId: string): ICondensationProvider | undefined {
    return this.providers.get(providerId)
  }

  // ... other methods
}
```

### Consequences

#### Positive

- ✅ **Type Safety**: Full TypeScript support maintained
- ✅ **Simplicity**: Clear and simple architecture
- ✅ **Performance**: No loading overhead
- ✅ **Security**: No arbitrary code execution
- ✅ **Testability**: Easy to test with explicit registration
- ✅ **Reliability**: No dynamic loading failures

#### Negative

- ⚠️ **Extensibility Limitation**: Cannot add providers without rebuilding
  - **Mitigation**: This is acceptable for Phase 1
  - **Future**: Can add plugin system in Phase 3 if needed

- ⚠️ **All Providers Loaded**: Even if unused
  - **Impact**: Minimal (providers are lightweight classes)
  - **Mitigation**: Lazy initialization within providers if needed

#### Neutral

- ℹ️ **Hybrid Approach Possible**: Can combine Registry + Plugin System later
  - Registry for built-in providers
  - Plugin system for third-party providers
  - Best of both worlds if needed

## Alternatives Considered

### Hybrid: Registry + Dynamic Loading

Registry for built-in providers, plugin system for third-party.

**Verdict**: Deferred to Phase 3. YAGNI for Phase 1.

### Service Locator Pattern

Similar to Registry but more generic.

**Verdict**: Rejected. Too generic, Registry is more specific and clear.

## Experience Report

### What Worked Well

- Registry pattern was easy to implement (< 100 lines)
- Testing was straightforward (clear/register in tests)
- Type safety maintained throughout
- No surprises or edge cases

### What Could Be Improved

- Could add validation on registration (duplicate IDs, etc.)
- Could add events for registration/unregistration (observability)

### Lessons Learned

- Simple solutions often beat complex ones
- Type safety is worth protecting
- YAGNI principle saves time and complexity

## Related Decisions

- [ADR-002: Singleton Pattern](./002-singleton-pattern-for-manager-and-registry.md)
- [ADR-004: Template Method Pattern](./004-template-method-pattern-in-base-provider.md)

## References

- [Martin Fowler - Registry Pattern](https://martinfowler.com/eaaCatalog/registry.html)
- [TypeScript Handbook - Module Resolution](https://www.typescriptlang.org/docs/handbook/module-resolution.html)
- [VSCode Extension API - Best Practices](https://code.visualstudio.com/api/references/extension-guidelines)

---

**Status**: Active  
**Last Updated**: 2025-10-02  
**Next Review**: Phase 2 Planning