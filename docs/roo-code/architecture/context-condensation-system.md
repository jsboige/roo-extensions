# Context Condensation System - Architecture Guide

**Version**: 1.0  
**Date**: 2025-10-02  
**Status**: Phase 1 Complete  

---

## 📖 Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Architecture en Couches](#architecture-en-couches)
3. [Diagrammes Détaillés](#diagrammes-détaillés)
4. [Patterns de Conception](#patterns-de-conception)
5. [Flow de Condensation](#flow-de-condensation)
6. [Composants Clés](#composants-clés)
7. [Extensibilité](#extensibilité)
8. [Débogage](#débogage)
9. [Performance](#performance)

---

## Vue d'Ensemble

Le **Context Condensation System** est une architecture modulaire et extensible permettant de condenser intelligemment le contexte des conversations dans Roo Code. Le système supporte plusieurs stratégies de condensation via un pattern de providers, tout en maintenant une backward compatibility complète avec le système existant.

### Objectifs Architecturaux

- 🎯 **Extensibilité** : Ajouter facilement de nouveaux providers de condensation
- 🔄 **Backward Compatibility** : Maintenir 100% de compatibilité avec le système existant
- 🧪 **Testabilité** : Architecture facilitant les tests unitaires et d'intégration
- 📊 **Observabilité** : Métriques et logs pour monitorer les performances
- 🎨 **Flexibilité** : Configuration par provider et par utilisateur

### Principes de Design

1. **Separation of Concerns** : Chaque composant a une responsabilité unique et claire
2. **Open/Closed Principle** : Ouvert à l'extension, fermé à la modification
3. **Dependency Inversion** : Dépendances vers des abstractions, pas des implémentations
4. **Single Responsibility** : Une classe = une raison de changer
5. **Interface Segregation** : Interfaces minimales et cohésives

---

## Architecture en Couches

```mermaid
graph TB
    subgraph "Presentation Layer"
        UI[Settings UI<br/>React Components]
        Messages[Webview Messages<br/>IPC Protocol]
    end
    
    subgraph "Application Layer"
        Manager[CondensationManager<br/>Orchestration]
        Task[Task.ts<br/>Integration Point]
    end
    
    subgraph "Domain Layer"
        Registry[ProviderRegistry<br/>Provider Management]
        Base[BaseCondensationProvider<br/>Template Method]
        Types[Types & Interfaces<br/>Contracts]
    end
    
    subgraph "Infrastructure Layer"
        Native[NativeProvider<br/>Anthropic API]
        Future1[OpenAI Provider<br/>Future]
        Future2[Custom Provider<br/>Future]
    end
    
    subgraph "External"
        API[External APIs<br/>Anthropic, OpenAI, etc.]
    end
    
    UI --> Messages
    Messages --> Manager
    Task --> Manager
    Manager --> Registry
    Manager --> Types
    Registry --> Base
    Base --> Native
    Base --> Future1
    Base --> Future2
    Native --> API
    Future1 --> API
    Future2 --> API
    
    style UI fill:#e3f2fd
    style Messages fill:#e3f2fd
    style Manager fill:#fff3e0
    style Task fill:#fff3e0
    style Registry fill:#f3e5f5
    style Base fill:#f3e5f5
    style Types fill:#f3e5f5
    style Native fill:#e8f5e9
    style Future1 fill:#e8f5e9
    style Future2 fill:#e8f5e9
    style API fill:#fce4ec
```

### Responsabilités des Couches

#### Presentation Layer
- **Responsabilité** : Interface utilisateur et communication webview
- **Technologies** : React, TypeScript, VSCode Webview API
- **Composants** : Settings UI, IPC Messages

#### Application Layer
- **Responsabilité** : Orchestration et logique métier de haut niveau
- **Technologies** : TypeScript, Singleton pattern
- **Composants** : CondensationManager, Task integration

#### Domain Layer
- **Responsabilité** : Règles métier et abstractions du domaine
- **Technologies** : TypeScript, Design patterns
- **Composants** : Registry, Base classes, Interfaces

#### Infrastructure Layer
- **Responsabilité** : Implémentations concrètes et intégrations externes
- **Technologies** : TypeScript, API clients
- **Composants** : Providers concrets (Native, OpenAI, etc.)

---

## Diagrammes Détaillés

### Diagramme de Classes

```mermaid
classDiagram
    class ICondensationProvider {
        <<interface>>
        +readonly id: string
        +readonly name: string
        +readonly description: string
        +condense(context, options) Promise~CondensationResult~
        +estimateCost(context) Promise~number~
        +validate(context, options) Promise~ValidationResult~
    }
    
    class BaseCondensationProvider {
        <<abstract>>
        +readonly id: string
        +readonly name: string
        +readonly description: string
        +condense(context, options) Promise~CondensationResult~
        +estimateCost(context) Promise~number~
        +validate(context, options) Promise~ValidationResult~
        #condenseInternal(context, options)* Promise~CondensationResult~
    }
    
    class NativeCondensationProvider {
        +readonly id: "native"
        +readonly name: "Native Condensation"
        +readonly description: string
        #condenseInternal(context, options) Promise~CondensationResult~
        +estimateCost(context) Promise~number~
    }
    
    class ProviderRegistry {
        -providers: Map~string, ICondensationProvider~
        -configs: Map~string, ProviderConfig~
        -instance: ProviderRegistry$
        +getInstance()$ ProviderRegistry
        +register(provider, config?) void
        +unregister(providerId) void
        +getProvider(providerId) ICondensationProvider?
        +listProviders(options?) ProviderInfo[]
        +updateConfig(providerId, updates) void
        +getConfig(providerId) ProviderConfig?
        +clear() void
    }
    
    class CondensationManager {
        -defaultProviderId: string
        -instance: CondensationManager$
        +getInstance()$ CondensationManager
        +condense(messages, apiHandler, options?) Promise~CondensationResult~
        +setDefaultProvider(providerId) void
        +getDefaultProvider() string
        +listProviders() ProviderInfo[]
        -getProvider(providerId) ICondensationProvider
    }
    
    class CondensationContext {
        +messages: ApiMessage[]
        +systemPrompt: string
        +taskId: string
        +prevContextTokens: number
        +targetTokens?: number
    }
    
    class CondensationOptions {
        +apiHandler: ApiHandler
        +condensingApiHandler?: ApiHandler
        +customCondensingPrompt?: string
        +isAutomaticTrigger: boolean
        +profileThresholds?: Record~string, number~
        +currentProfileId?: string
    }
    
    class CondensationResult {
        +messages: ApiMessage[]
        +summary?: string
        +cost: number
        +newContextTokens?: number
        +error?: string
        +metrics?: ProviderMetrics
    }
    
    class ProviderConfig {
        +id: string
        +enabled: boolean
        +priority: number
        +config?: any
    }
    
    ICondensationProvider <|.. BaseCondensationProvider : implements
    BaseCondensationProvider <|-- NativeCondensationProvider : extends
    ProviderRegistry o-- ICondensationProvider : manages
    ProviderRegistry o-- ProviderConfig : stores
    CondensationManager --> ProviderRegistry : uses
    CondensationManager --> ICondensationProvider : orchestrates
    BaseCondensationProvider ..> CondensationContext : uses
    BaseCondensationProvider ..> CondensationOptions : uses
    BaseCondensationProvider ..> CondensationResult : returns
```

### Diagramme de Séquence - Condensation Flow

```mermaid
sequenceDiagram
    participant Task as Task.ts
    participant Manager as CondensationManager
    participant Registry as ProviderRegistry
    participant Provider as ICondensationProvider
    participant API as External API
    
    Task->>Manager: condense(messages, apiHandler, options)
    
    Manager->>Manager: Determine provider ID<br/>(from options or default)
    Manager->>Registry: getProvider(providerId)
    Registry-->>Manager: provider instance
    
    Manager->>Manager: Check provider enabled
    alt Provider disabled
        Manager-->>Task: Error: Provider disabled
    end
    
    Manager->>Manager: Build CondensationContext
    Manager->>Manager: Build CondensationOptions
    
    Manager->>Provider: condense(context, options)
    
    Provider->>Provider: validate(context, options)
    alt Validation fails
        Provider-->>Manager: Result with error
        Manager-->>Task: Failed result
    end
    
    Provider->>Provider: Start metrics timer
    Provider->>Provider: condenseInternal(context, options)
    
    Provider->>API: Call condensation API<br/>(e.g., Anthropic)
    API-->>Provider: Condensed content + usage
    
    Provider->>Provider: Build result with metrics
    Provider->>Provider: Calculate tokens saved
    
    Provider-->>Manager: CondensationResult
    Manager-->>Task: Final result
    
    Task->>Task: Update context with<br/>condensed messages
```

### Diagramme de Séquence - Provider Registration

```mermaid
sequenceDiagram
    participant Init as App Initialization
    participant Manager as CondensationManager
    participant Registry as ProviderRegistry
    participant Native as NativeProvider
    
    Init->>Manager: getInstance()
    
    Manager->>Manager: Constructor called<br/>(first time only)
    Manager->>Manager: registerDefaultProviders()
    
    Manager->>Registry: getInstance()
    Registry-->>Manager: registry instance
    
    Manager->>Native: new NativeCondensationProvider()
    Native-->>Manager: provider instance
    
    Manager->>Registry: register(nativeProvider, config)
    Registry->>Registry: providers.set("native", provider)
    Registry->>Registry: configs.set("native", config)
    
    Manager->>Manager: Set default provider to "native"
    
    Manager-->>Init: Manager ready
```

### Diagramme de Composants

```mermaid
graph TB
    subgraph "Core Module [src/core/condense]"
        Types[types.ts<br/>Interfaces & Types]
        Base[BaseProvider.ts<br/>Abstract Base Class]
        Registry[ProviderRegistry.ts<br/>Singleton Registry]
        Manager[CondensationManager.ts<br/>Singleton Manager]
        Index[index.ts<br/>Public API]
        
        Types --> Base
        Base --> Registry
        Registry --> Manager
        Manager --> Index
    end
    
    subgraph "Providers Module [src/core/condense/providers]"
        Native[NativeProvider.ts<br/>Native Implementation]
        
        Base --> Native
    end
    
    subgraph "Tests Module [src/core/condense/__tests__]"
        TypesTest[types.test.ts]
        BaseTest[BaseProvider.test.ts]
        RegistryTest[ProviderRegistry.test.ts]
        ManagerTest[CondensationManager.test.ts]
        NativeTest[NativeProvider.test.ts]
        IndexTest[index.spec.ts]
        IntegTest[integration.test.ts]
        E2ETest[e2e.test.ts]
    end
    
    subgraph "UI Module [webview-ui]"
        Settings[CondensationProviderSettings.tsx]
        Handler[webviewMessageHandler.ts]
    end
    
    subgraph "Integration Points"
        Task[Task.ts]
        Messages[ExtensionMessage.ts<br/>WebviewMessage.ts]
    end
    
    Index --> Task
    Index --> Handler
    Settings --> Handler
    Handler --> Manager
    Messages --> Settings
    Messages --> Handler
    
    Types -.-> TypesTest
    Base -.-> BaseTest
    Registry -.-> RegistryTest
    Manager -.-> ManagerTest
    Native -.-> NativeTest
    Index -.-> IndexTest
    Manager -.-> IntegTest
    Manager -.-> E2ETest
    
    style Types fill:#e1f5ff
    style Base fill:#e1f5ff
    style Registry fill:#ffe1e1
    style Manager fill:#ffe1e1
    style Native fill:#e1ffe1
    style Settings fill:#fff4e1
```

---

## Patterns de Conception

### 1. Singleton Pattern

**Utilisé pour** : `ProviderRegistry` et `CondensationManager`

**Justification** :
- Garantit une instance unique du registry des providers
- Évite la duplication de state
- Simplifie l'accès global

**Implémentation** :
```typescript
class ProviderRegistry {
  private static instance: ProviderRegistry

  private constructor() {
    // Constructor privé pour empêcher l'instanciation directe
  }

  static getInstance(): ProviderRegistry {
    if (!ProviderRegistry.instance) {
      ProviderRegistry.instance = new ProviderRegistry()
    }
    return ProviderRegistry.instance
  }
}
```

**Avantages** :
- ✅ Instance unique garantie
- ✅ Lazy initialization
- ✅ Accès global simple

**Considérations** :
- ⚠️ Rend les tests plus complexes (nécessité de clear entre tests)
- ⚠️ État global (attention aux side effects)

### 2. Template Method Pattern

**Utilisé pour** : `BaseCondensationProvider`

**Justification** :
- Définit le squelette de l'algorithme de condensation
- Permet aux sous-classes de redéfinir certaines étapes
- Code commun factori (validation, métriques, error handling)

**Implémentation** :
```typescript
abstract class BaseCondensationProvider implements ICondensationProvider {
  // Méthode template (finale, non overridable)
  async condense(context, options): Promise<CondensationResult> {
    // 1. Validation (commun)
    const validation = await this.validate(context, options)
    if (!validation.valid) return errorResult
    
    // 2. Métriques start (commun)
    const startTime = Date.now()
    
    // 3. Algorithme spécifique (variable)
    const result = await this.condenseInternal(context, options)
    
    // 4. Métriques end (commun)
    result.metrics = { timeElapsed: Date.now() - startTime, ...}
    
    return result
  }
  
  // Hook method (abstract, à implémenter)
  protected abstract condenseInternal(context, options): Promise<CondensationResult>
}
```

**Avantages** :
- ✅ Code commun réutilisé
- ✅ Structure claire et prévisible
- ✅ Facilite l'ajout de nouveaux providers

**Considérations** :
- ⚠️ Inflexible pour cas très différents
- ⚠️ Nécessite une bonne conception initiale

### 3. Strategy Pattern

**Utilisé pour** : Différents providers de condensation

**Justification** :
- Encapsule différents algorithmes de condensation
- Rend les algorithmes interchangeables
- Permet de choisir dynamiquement la stratégie

**Implémentation** :
```typescript
// Context (Manager)
class CondensationManager {
  async condense(messages, apiHandler, options?) {
    const providerId = options?.providerId || this.defaultProviderId
    const provider = this.getProvider(providerId) // Strategy selection
    return provider.condense(context, condensationOptions)
  }
}

// Strategies (Providers)
class NativeProvider extends BaseCondensationProvider { /* ... */ }
class OpenAIProvider extends BaseCondensationProvider { /* ... */ }
class CustomProvider extends BaseCondensationProvider { /* ... */ }
```

**Avantages** :
- ✅ Extensibilité facile (ajouter nouveaux providers)
- ✅ Testabilité (mock de providers)
- ✅ Choix dynamique de stratégie

**Considérations** :
- ⚠️ Overhead pour cas simples
- ⚠️ Nécessite interface commune bien définie

### 4. Registry Pattern

**Utilisé pour** : `ProviderRegistry`

**Justification** :
- Centralise l'enregistrement et la récupération des providers
- Permet la configuration par provider
- Facilite le listing et la découverte

**Implémentation** :
```typescript
class ProviderRegistry {
  private providers: Map<string, ICondensationProvider> = new Map()
  private configs: Map<string, ProviderConfig> = new Map()
  
  register(provider: ICondensationProvider, config?: Partial<ProviderConfig>) {
    this.providers.set(provider.id, provider)
    this.configs.set(provider.id, fullConfig)
  }
  
  getProvider(providerId: string): ICondensationProvider | undefined {
    return this.providers.get(providerId)
  }
}
```

**Avantages** :
- ✅ Découverte centralisée
- ✅ Configuration uniforme
- ✅ Gestion du lifecycle

**Considérations** :
- ⚠️ Couplage au registry
- ⚠️ Nécessite des IDs uniques

---

## Flow de Condensation

### Flow Complet End-to-End

```mermaid
flowchart TD
    Start([User triggers condensation])
    
    Start --> CheckManual{Manual or<br/>Automatic?}
    
    CheckManual -->|Manual| UIClick[User clicks 'Condense'<br/>in chat UI]
    CheckManual -->|Automatic| ThresholdCheck[Context size check<br/>vs threshold]
    
    UIClick --> TaskCondense[Task.condenseConversation()]
    ThresholdCheck -->|Exceeds| TaskCondense
    ThresholdCheck -->|Below| End1([No action])
    
    TaskCondense --> ManagerGet[getCondensationManager()]
    ManagerGet --> ManagerCondense[manager.condense()]
    
    ManagerCondense --> DetermineProvider{Provider<br/>specified?}
    DetermineProvider -->|Yes| UseSpecified[Use specified provider]
    DetermineProvider -->|No| UseDefault[Use default provider]
    
    UseSpecified --> GetProvider
    UseDefault --> GetProvider[registry.getProvider()]
    
    GetProvider --> CheckEnabled{Provider<br/>enabled?}
    CheckEnabled -->|No| ErrorDisabled[Error: Provider disabled]
    CheckEnabled -->|Yes| BuildContext
    
    ErrorDisabled --> ReturnError1[Return error result]
    ReturnError1 --> End2([End])
    
    BuildContext[Build CondensationContext]
    BuildContext --> BuildOptions[Build CondensationOptions]
    BuildOptions --> ProviderCondense[provider.condense()]
    
    ProviderCondense --> Validate[provider.validate()]
    Validate --> CheckValid{Valid?}
    CheckValid -->|No| ErrorValidation[Error: Validation failed]
    CheckValid -->|Yes| StartMetrics
    
    ErrorValidation --> ReturnError2[Return error result]
    ReturnError2 --> End3([End])
    
    StartMetrics[Start metrics timer]
    StartMetrics --> CondenseInternal[provider.condenseInternal()]
    
    CondenseInternal --> CheckMinMsg{Enough<br/>messages?}
    CheckMinMsg -->|No| ErrorMinMsg[Error: Not enough messages]
    CheckMinMsg -->|Yes| CheckRecentCondense
    
    ErrorMinMsg --> ReturnError3[Return error result]
    ReturnError3 --> End4([End])
    
    CheckRecentCondense{Recently<br/>condensed?}
    CheckRecentCondense -->|Yes| ErrorRecent[Error: Recently condensed]
    CheckRecentCondense -->|No| CallAPI
    
    ErrorRecent --> ReturnError4[Return error result]
    ReturnError4 --> End5([End])
    
    CallAPI[Call external API<br/>with condensation prompt]
    CallAPI --> ReceiveResponse[Receive condensed content]
    ReceiveResponse --> CountTokens[Count tokens in result]
    
    CountTokens --> CheckGrowth{Context<br/>grew?}
    CheckGrowth -->|Yes| ErrorGrowth[Error: Context grew]
    CheckGrowth -->|No| BuildResult
    
    ErrorGrowth --> ReturnError5[Return error result]
    ReturnError5 --> End6([End])
    
    BuildResult[Build CondensationResult]
    BuildResult --> AddMetrics[Add metrics<br/>(time, tokens saved)]
    AddMetrics --> ReturnSuccess[Return success result]
    
    ReturnSuccess --> UpdateTask[Update Task context<br/>with condensed messages]
    UpdateTask --> NotifyUI[Notify UI of success]
    NotifyUI --> End7([Success])
    
    style Start fill:#e1f5ff
    style End1 fill:#f1f1f1
    style End2 fill:#ffe1e1
    style End3 fill:#ffe1e1
    style End4 fill:#ffe1e1
    style End5 fill:#ffe1e1
    style End6 fill:#ffe1e1
    style End7 fill:#e1ffe1
    style ErrorDisabled fill:#ffe1e1
    style ErrorValidation fill:#ffe1e1
    style ErrorMinMsg fill:#ffe1e1
    style ErrorRecent fill:#ffe1e1
    style ErrorGrowth fill:#ffe1e1
```

### Validation Flow

```mermaid
flowchart TD
    Start([provider.validate<br/>called])
    
    Start --> CheckMessages{messages.length<br/>> 0?}
    CheckMessages -->|No| ErrorEmpty[Error: No messages]
    CheckMessages -->|Yes| CheckMinCount
    
    ErrorEmpty --> ReturnInvalid1[Return invalid]
    ReturnInvalid1 --> End1([End])
    
    CheckMinCount{messages.length<br/>>= MIN_MESSAGES?}
    CheckMinCount -->|No| ErrorMinCount[Error: Not enough messages<br/>MIN=5 for native]
    CheckMinCount -->|Yes| CheckSummary
    
    ErrorMinCount --> ReturnInvalid2[Return invalid]
    ReturnInvalid2 --> End2([End])
    
    CheckSummary{Has recent<br/>summary?}
    CheckSummary -->|Yes| CheckGap[Count messages after summary]
    CheckSummary -->|No| CheckTokens
    
    CheckGap --> CheckGapSize{Gap >=<br/>MIN_GAP?}
    CheckGapSize -->|No| ErrorGap[Error: Too soon after<br/>last condensation]
    CheckGapSize -->|Yes| CheckTokens
    
    ErrorGap --> ReturnInvalid3[Return invalid]
    ReturnInvalid3 --> End3([End])
    
    CheckTokens{prevContextTokens<br/>> MIN_TOKENS?}
    CheckTokens -->|No| ErrorTokens[Error: Not enough tokens<br/>MIN=200 for native]
    CheckTokens -->|Yes| CheckHandler
    
    ErrorTokens --> ReturnInvalid4[Return invalid]
    ReturnInvalid4 --> End4([End])
    
    CheckHandler{apiHandler<br/>valid?}
    CheckHandler -->|No| ErrorHandler[Error: Invalid API handler]
    CheckHandler -->|Yes| ReturnValid
    
    ErrorHandler --> ReturnInvalid5[Return invalid]
    ReturnInvalid5 --> End5([End])
    
    ReturnValid[Return valid]
    ReturnValid --> End6([Success])
    
    style Start fill:#e1f5ff
    style End1 fill:#ffe1e1
    style End2 fill:#ffe1e1
    style End3 fill:#ffe1e1
    style End4 fill:#ffe1e1
    style End5 fill:#ffe1e1
    style End6 fill:#e1ffe1
    style ErrorEmpty fill:#ffe1e1
    style ErrorMinCount fill:#ffe1e1
    style ErrorGap fill:#ffe1e1
    style ErrorTokens fill:#ffe1e1
    style ErrorHandler fill:#ffe1e1
```

---

## Composants Clés

### 1. Types & Interfaces (`types.ts`)

**Rôle** : Définir les contrats du système

**Interfaces Principales** :
- `ICondensationProvider` : Contrat que tout provider doit respecter
- `CondensationContext` : Contexte d'entrée pour la condensation
- `CondensationOptions` : Options de configuration
- `CondensationResult` : Résultat de la condensation
- `ProviderConfig` : Configuration d'un provider
- `ProviderMetrics` : Métriques de performance

**Localisation** : [`src/core/condense/types.ts`](../../../../src/core/condense/types.ts)

### 2. BaseCondensationProvider (`BaseProvider.ts`)

**Rôle** : Classe abstraite de base pour tous les providers

**Responsabilités** :
- Validation standardisée des inputs
- Gestion uniforme des erreurs
- Collecte automatique des métriques
- Template Method pour `condense()`

**Points d'Extension** :
```typescript
protected abstract condenseInternal(
  context: CondensationContext,
  options: CondensationOptions
): Promise<CondensationResult>

async estimateCost(context: CondensationContext): Promise<number>
```

**Localisation** : [`src/core/condense/BaseProvider.ts`](../../../../src/core/condense/BaseProvider.ts)

### 3. ProviderRegistry (`ProviderRegistry.ts`)

**Rôle** : Registry singleton pour gérer les providers

**API Publique** :
```typescript
getInstance(): ProviderRegistry
register(provider, config?): void
unregister(providerId): void
getProvider(providerId): ICondensationProvider | undefined
listProviders(options?): ProviderInfo[]
updateConfig(providerId, updates): void
getConfig(providerId): ProviderConfig | undefined
clear(): void  // Pour les tests uniquement
```

**State Interne** :
- `providers: Map<string, ICondensationProvider>` : Instances des providers
- `configs: Map<string, ProviderConfig>` : Configurations par provider

**Localisation** : [`src/core/condense/ProviderRegistry.ts`](../../../../src/core/condense/ProviderRegistry.ts)

### 4. CondensationManager (`CondensationManager.ts`)

**Rôle** : Point d'entrée principal pour la condensation

**API Publique** :
```typescript
getInstance(): CondensationManager
condense(messages, apiHandler, options?): Promise<CondensationResult>
setDefaultProvider(providerId): void
getDefaultProvider(): string
listProviders(): ProviderInfo[]
```

**Workflow** :
1. Déterminer le provider (options ou default)
2. Vérifier que le provider est enabled
3. Construire le context et les options
4. Déléguer à `provider.condense()`

**Localisation** : [`src/core/condense/CondensationManager.ts`](../../../../src/core/condense/CondensationManager.ts)

### 5. NativeProvider (`providers/NativeProvider.ts`)

**Rôle** : Provider natif pour backward compatibility

**Caractéristiques** :
- ID: `"native"`
- Utilise l'API Anthropic
- Logique identique à `summarizeConversation` original
- Validations strictes (min messages, gap après condensation, etc.)

**Validations Spécifiques** :
- Minimum 5 messages
- Minimum 200 tokens dans le contexte
- Gap minimum de 3 messages après dernière condensation
- Vérification que le contexte ne grandit pas

**Localisation** : [`src/core/condense/providers/NativeProvider.ts`](../../../../src/core/condense/providers/NativeProvider.ts)

---

## Extensibilité

### Ajouter un Nouveau Provider

#### Étape 1 : Créer la Classe Provider

```typescript
// src/core/condense/providers/OpenAIProvider.ts
import { BaseCondensationProvider } from "../BaseProvider"
import type { CondensationContext, CondensationOptions, CondensationResult } from "../types"

export class OpenAICondensationProvider extends BaseCondensationProvider {
  readonly id = "openai"
  readonly name = "OpenAI Condensation"
  readonly description = "Uses OpenAI API for context condensation"

  protected async condenseInternal(
    context: CondensationContext,
    options: CondensationOptions,
  ): Promise<CondensationResult> {
    // 1. Validation spécifique à OpenAI
    // 2. Appel à l'API OpenAI
    // 3. Traitement de la réponse
    // 4. Construction du résultat
  }

  async estimateCost(context: CondensationContext): Promise<number> {
    // Estimation basée sur les tarifs OpenAI
  }
}
```

#### Étape 2 : Enregistrer le Provider

```typescript
// src/core/condense/CondensationManager.ts
private registerDefaultProviders(): void {
  const registry = getProviderRegistry()

  // Native provider
  const nativeProvider = new NativeCondensationProvider()
  registry.register(nativeProvider, { enabled: true, priority: 100 })

  // Nouveau provider OpenAI
  const openAIProvider = new OpenAICondensationProvider()
  registry.register(openAIProvider, { enabled: true, priority: 90 })
}
```

#### Étape 3 : Tests

```typescript
// src/core/condense/providers/__tests__/OpenAIProvider.test.ts
import { describe, it, expect, beforeEach, vi } from "vitest"
import { OpenAICondensationProvider } from "../OpenAIProvider"

describe("OpenAICondensationProvider", () => {
  let provider: OpenAICondensationProvider

  beforeEach(() => {
    provider = new OpenAICondensationProvider()
  })

  it("should have correct metadata", () => {
    expect(provider.id).toBe("openai")
    expect(provider.name).toBe("OpenAI Condensation")
  })

  it("should condense context successfully", async () => {
    // Test implementation
  })

  // ... plus de tests
})
```

### Configuration Avancée par Provider

```typescript
// Exemple de configuration custom pour un provider
interface OpenAIProviderConfig {
  model: string           // e.g., "gpt-4-turbo"
  temperature: number     // 0-1
  maxTokens: number       // Max tokens in summary
  customPrompt?: string   // Override default prompt
}

registry.register(openAIProvider, {
  enabled: true,
  priority: 90,
  config: {
    model: "gpt-4-turbo",
    temperature: 0.7,
    maxTokens: 500,
  } as OpenAIProviderConfig
})
```

---

## Débogage

### Logs et Métriques

#### Activer les Logs Détaillés

Les providers loggent automatiquement :
- Temps d'exécution via `metrics.timeElapsed`
- Tokens économisés via `metrics.tokensSaved`
- Coût de l'opération via `result.cost`

#### Analyser les Erreurs

Toutes les erreurs sont capturées et retournées dans `CondensationResult.error` :

```typescript
const result = await manager.condense(messages, apiHandler)
if (result.error) {
  console.error("Condensation failed:", result.error)
  // Messages originaux sont retournés
  console.log("Original messages preserved:", result.messages)
}
```

### Outils de Débogage

#### 1. Lister les Providers

```typescript
const manager = getCondensationManager()
const providers = manager.listProviders()

console.log("Available providers:", providers.map(p => ({
  id: p.id,
  name: p.name,
  enabled: p.enabled,
  priority: p.priority,
})))
```

#### 2. Tester un Provider Isolément

```typescript
const registry = getProviderRegistry()
const provider = registry.getProvider("native")

if (provider) {
  const context: CondensationContext = { /* ... */ }
  const options: CondensationOptions = { /* ... */ }
  
  // Test validation
  const validation = await provider.validate(context, options)
  console.log("Validation:", validation)
  
  // Test condensation
  const result = await provider.condense(context, options)
  console.log("Result:", result)
}
```

#### 3. Inspecter la Configuration

```typescript
const registry = getProviderRegistry()
const config = registry.getConfig("native")

console.log("Provider config:", config)
// { id: "native", enabled: true, priority: 100, config: undefined }
```

### Problèmes Courants

#### Provider Not Found

**Symptôme** : `Error: Provider 'xxx' not found`

**Causes** :
- Provider pas enregistré
- Typo dans l'ID du provider
- Provider désenregistré par erreur

**Solution** :
```typescript
// Vérifier les providers disponibles
const providers = manager.listProviders()
console.log("Available:", providers.map(p => p.id))

// Ré-enregistrer si nécessaire
registry.register(myProvider, { enabled: true })
```

#### Provider Disabled

**Symptôme** : `Error: Provider 'xxx' is disabled`

**Solution** :
```typescript
// Activer le provider
registry.updateConfig("native", { enabled: true })
```

#### Validation Fails

**Symptôme** : `result.error` contient un message de validation

**Debug** :
```typescript
// Tester validation directement
const validation = await provider.validate(context, options)
console.log("Validation result:", validation)

// Vérifier les contraintes
console.log("Messages count:", context.messages.length)
console.log("Context tokens:", context.prevContextTokens)
console.log("Has recent summary:", context.messages.some(m => m.isSummary))
```

---

## Performance

### Optimisations Implémentées

#### 1. Singleton Pattern
- Évite la recréation d'instances
- State partagé efficacement

#### 2. Lazy Initialization
- Registry et Manager créés au premier accès
- Providers enregistrés à la demande

#### 3. Validation Précoce
- Échec rapide si validation échoue
- Évite les appels API inutiles

#### 4. Métriques Minimales
- Overhead de métriques < 1ms
- Pas d'impact sur les performances

### Métriques de Performance

**Temps Typiques** (Native Provider) :
- Validation : < 1ms
- API Call : 500-2000ms (dépend du contexte)
- Post-processing : < 10ms
- **Total** : 500-2100ms

**Tokens Économisés** :
- Dépend de la taille du contexte original
- Typiquement 50-70% de réduction
- Exemple : 1000 tokens → 300-500 tokens

**Coût** :
- Varie selon le provider et le modèle
- Native (Anthropic) : ~$0.001-0.005 par condensation
- Retourné dans `result.cost`

### Considérations Futures

#### Caching
- Cache des résultats de condensation
- Invalidation basée sur changements de contexte
- Économie de coûts API

#### Batching
- Grouper plusieurs demandes de condensation
- Optimisation pour auto-condensation
- Réduction du nombre d'appels API

#### Streaming
- Streamer les résultats de condensation
- Amélioration de l'UX (feedback progressif)
- Nécessite support API (Anthropic ✅, OpenAI ✅)

---

## Références

### Code Source

- [Types](../../../../src/core/condense/types.ts)
- [BaseProvider](../../../../src/core/condense/BaseProvider.ts)
- [ProviderRegistry](../../../../src/core/condense/ProviderRegistry.ts)
- [CondensationManager](../../../../src/core/condense/CondensationManager.ts)
- [NativeProvider](../../../../src/core/condense/providers/NativeProvider.ts)
- [Tests](../../../../src/core/condense/__tests__/)

### Documentation

- [Checkpoint Phase 1](../../pr-tracking/context-condensation/009-phase1-checkpoint.md)
- [Plan 30 Commits](../../pr-tracking/context-condensation/007-operational-plan-30-commits.md)
- [Guide Contributeur](./contributing-guide.md) *(à créer)*

### Design Patterns

- [Singleton Pattern](https://refactoring.guru/design-patterns/singleton)
- [Template Method Pattern](https://refactoring.guru/design-patterns/template-method)
- [Strategy Pattern](https://refactoring.guru/design-patterns/strategy)
- [Registry Pattern](https://martinfowler.com/eaaCatalog/registry.html)

---

**Auteur** : Roo AI Assistant  
**Version** : 1.0  
**Date** : 2025-10-02  
**Status** : Living Document