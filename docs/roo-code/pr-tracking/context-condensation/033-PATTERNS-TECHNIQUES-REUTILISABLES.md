# 📚 Patterns Techniques Réutilisables - Extension Roo

**Version**: v3.28.17+  
**Méthodologie**: SDDD (Semantic Documentation Driven Design)  
**Date**: 2025-10-19

---

## 🎯 Objectif

Documenter les patterns techniques identifiés lors de la résolution des bugs pour les rendre réutilisables dans les futures interventions sur l'extension VSCode Roo.

---

## 🏗️ Pattern #1: Frontend-Backend Synchronisation

### 📋 Contexte

Les race conditions entre les actions utilisateur et les réponses backend peuvent causer des désynchronisations de l'UI.

### ✅ Solution: Optimistic UI avec Temporal Guard

```typescript
// État local avec timestamp de changement
const [defaultProviderId, setDefaultProviderId] = useState<string>("native")
const lastLocalChangeRef = useRef<number>(0)

// Handler utilisateur avec timestamp
const handleDefaultProviderChange = (providerId: string) => {
    // 1. Marquer le changement local
    lastLocalChangeRef.current = Date.now()
    
    // 2. Update UI immédiatement (optimistic)
    setDefaultProviderId(providerId)
    
    // 3. Notifier backend
    vscode.postMessage({
        type: "setDefaultCondensationProvider",
        providerId,
    })
}

// Message handler avec guard temporel
useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
        const message = event.data
        
        if (message.type === "condensationProviders") {
            // Ignorer les messages backend trop récents (race condition)
            const timeSinceLocalChange = Date.now() - lastLocalChangeRef.current
            const IGNORE_BACKEND_DURATION_MS = 500
            
            if (timeSinceLocalChange < IGNORE_BACKEND_DURATION_MS) {
                console.log("Ignoring backend message - recent local change")
                return
            }
            
            // Accepter les messages backend légitimes
            setDefaultProviderId(message.defaultProviderId || "native")
        }
    }
    
    window.addEventListener("message", handleMessage)
    return () => window.removeEventListener("message", handleMessage)
}, [])
```

### 🎯 Avantages

- ✅ **Réactivité**: UI répond immédiatement aux actions utilisateur
- ✅ **Robustesse**: Évite les overwrites backend
- ✅ **Simplicité**: Logique facile à comprendre et maintenir
- ✅ **Flexibilité**: Ajustable selon les besoins de timing

### ⚠️ Limitations

- ⚠️ **Timing arbitraire**: 500ms peut ne pas convenir à tous les cas
- ⚠️ **Race condition possible**: Si le backend est très lent
- ⚠️ **Complexité**: Nécessite une gestion minutieuse des timestamps

### 🔄 Variations

#### Variation A: Version Tracking (Plus robuste)

```typescript
const [localVersion, setLocalVersion] = useState<number>(0)

const handleChange = (providerId: string) => {
    const newVersion = localVersion + 1
    setLocalVersion(newVersion)
    setDefaultProviderId(providerId)
    
    vscode.postMessage({
        type: "setDefaultCondensationProvider",
        providerId,
        version: newVersion,
    })
}

// Backend renvoie la version dans ses messages
if (message.version >= localVersion) {
    setDefaultProviderId(message.providerId)
    setLocalVersion(message.version)
}
```

#### Variation B: No Echo Backend (Plus simple)

```typescript
// Backend ne renvoie PAS de confirmation immédiate
// Le frontend fait confiance à son update optimistique

const handleChange = (providerId: string) => {
    setDefaultProviderId(providerId)  // Update UI
    
    vscode.postMessage({
        type: "setDefaultCondensationProvider",
        providerId,
        noEcho: true,  // Demander au backend de ne pas répondre
    })
}
```

---

## 🔄 Pattern #2: Stale Closure Prevention

### 📋 Contexte

Les `useEffect` avec dépendances vides capturent les valeurs initiales des states/props, créant des "stale closures" où le handler voit des valeurs obsolètes.

### ✅ Solution: useRef Pattern

```typescript
// ❌ ANTI-PATTERN - Stale closure
useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
        // Cette fonction capture defaultProviderId au moment de la création
        // Elle ne voit JAMAIS les mises à jour ultérieures!
        console.log(defaultProviderId)  // Valeur obsolète
    }
    
    window.addEventListener("message", handleMessage)
    return () => window.removeEventListener("message", handleMessage)
}, [])  // Dépendances vides = closure créée une seule fois

// ✅ PATTERN CORRECT - Ref synchronisé
const [defaultProviderId, setDefaultProviderId] = useState<string>("native")
const defaultProviderIdRef = useRef<string>("native")

// Synchroniser le ref avec le state
useEffect(() => {
    defaultProviderIdRef.current = defaultProviderId
}, [defaultProviderId])

// Utiliser le ref dans le handler (pas de stale closure)
useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
        // Ref est mutable et accessible dans la closure
        console.log(defaultProviderIdRef.current)  // Valeur actuelle!
    }
    
    window.addEventListener("message", handleMessage)
    return () => window.removeEventListener("message", handleMessage)
}, [])  // Dépendances vides OK car ref est mutable
```

### 🎯 Avantages

- ✅ **Accès actuel**: Le ref donne toujours la valeur actuelle
- ✅ **Performance**: Pas de re-création de handlers
- ✅ **Simplicité**: Logique facile à suivre
- ✅ **Compatibilité**: Fonctionne avec tous les types de valeurs

### ⚠️ Limitations

- ⚠️ **Complexité**: Nécessite une synchronisation explicite
- ⚠️ **Verbosité**: Code plus long que la version naïve
- ⚠️ **Erreur possible**: Oublier de synchroniser le ref

### 🔄 Variations

#### Variation A: useCallback Pattern

```typescript
const handleMessage = useCallback((event: MessageEvent) => {
    // useCallback recrée la fonction quand les dépendances changent
    console.log(defaultProviderId)  // Capture la valeur actuelle
}, [defaultProviderId])  // Dépendance explicite

useEffect(() => {
    window.addEventListener("message", handleMessage)
    return () => window.removeEventListener("message", handleMessage)
}, [handleMessage])  // Re-register quand le handler change
```

#### Variation B: Custom Hook Pattern

```typescript
function useSyncedRef<T>(value: T): React.MutableRefObject<T> {
    const ref = useRef(value)
    useEffect(() => {
        ref.current = value
    }, [value])
    return ref
}

// Utilisation
const defaultProviderIdRef = useSyncedRef(defaultProviderId)
```

---

## 🎨 Pattern #3: Web Components dans React

### 📋 Contexte

Les web components (comme VSCodeRadio) ont leur propre état interne qui peut entrer en conflit avec le state React.

### ✅ Solution: Single Source of Control

```typescript
// ❌ ANTI-PATTERN - Double contrôle
<VSCodeRadioGroup value={defaultProviderId}>
    <VSCodeRadio 
        value="smart"
        checked={defaultProviderId === "smart"}  // Conflit!
        onChange={handler} />

// ✅ PATTERN CORRECT - Contrôle unique via groupe
<VSCodeRadioGroup value={defaultProviderId}>
    <VSCodeRadio 
        value="smart"
        onChange={handler} />  // Pas de checked explicite

// ✅ ALTERNATIVE - Contrôle individuel explicite
<VSCodeRadioGroup>
    <VSCodeRadio 
        value="smart"
        checked={defaultProviderId === "smart"}
        onChange={handler} />  // Groupe sans value
```

### 🎯 Avantages

- ✅ **Prévisibilité**: Une seule source de vérité
- ✅ **Stabilité**: Pas de conflits internes
- ✅ **Performance**: Moins de re-renders
- ✅ **Debug**: Plus facile à diagnostiquer

### ⚠️ Limitations

- ⚠️ **Connaissance requise**: Il faut comprendre le fonctionnement du web component
- ⚠️ **Documentation**: Peut nécessiter de lire la doc du composant
- ⚠️ **Compatibilité**: Certains web components ont des exigences spécifiques

### 🔄 Variations

#### Variation A: Ref Control Pattern

```typescript
const radioRef = useRef<HTMLInputElement>(null)

// Contrôle direct via ref
useEffect(() => {
    if (radioRef.current) {
        radioRef.current.checked = defaultProviderId === "smart"
    }
}, [defaultProviderId])

<VSCodeRadio 
    ref={radioRef}
    value="smart"
    onChange={handler} />
```

#### Variation B: State Wrapper Pattern

```typescript
function ControlledVSCodeRadio({ value, checked, onChange, ...props }) {
    const internalRef = useRef<HTMLInputElement>(null)
    
    useEffect(() => {
        if (internalRef.current) {
            internalRef.current.checked = checked
        }
    }, [checked])
    
    return <VSCodeRadio ref={internalRef} value={value} onChange={onChange} {...props} />
}
```

---

## ⚙️ Pattern #4: PowerShell VSCode Automation

### 📋 Contexte

VSCode injecte automatiquement des arguments PowerShell dans les profiles d'automation, ce qui peut créer des conflits.

### ✅ Solution: Configuration Minimaliste

```json
// ❌ ANTI-PATTERN - Double argument
{
    "terminal.integrated.automationProfile.windows": {
        "path": "powershell.exe",
        "args": ["-Command"]  // VSCode ajoute déjà -Command!
    }
}

// ✅ PATTERN CORRECT - Laisser VSCode gérer
{
    "terminal.integrated.automationProfile.windows": {
        "path": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        // Pas de args - VSCode gère automatiquement
    }
}
```

### 🎯 Avantages

- ✅ **Simplicité**: Moins de configuration à maintenir
- ✅ **Compatibilité**: Fonctionne avec toutes les versions de VSCode
- ✅ **Robustesse**: Pas de conflits d'arguments
- ✅ **Maintenabilité**: Moins de points de défaillance

### ⚠️ Limitations

- ⚠️ **Moins de contrôle**: Pas de personnalisation des arguments
- ⚠️ **Dépendance**: On dépend du comportement par défaut de VSCode
- ⚠️ **Documentation**: Il faut connaître ce comportement

### 🔄 Variations

#### Variation A: Profile Spécifique

```json
{
    "terminal.integrated.profiles.windows": {
        "PowerShell": {
            "path": "powershell.exe",
            "icon": "terminal-powershell"
        }
    },
    "terminal.integrated.defaultProfile.windows": "PowerShell"
}
```

#### Variation B: Environment Variables

```json
{
    "terminal.integrated.env.windows": {
        "MY_VAR": "value"
    }
}
```

---

## 🎨 Pattern #5: CSS Responsive avec Tailwind

### 📋 Contexte

Les textes dans les boutons peuvent être tronqués si on ne gère pas correctement les espaces blancs.

### ✅ Solution: Whitespace Management

```typescript
// ❌ ANTI-PATTERN - Texte tronqué
<VSCodeButton className="w-full text-xs px-2 py-1">
    Show Advanced Config  {/* Peut devenir "Show Advanced Con..." */}
</VSCodeButton>

// ✅ PATTERN CORRECT - Whitespace explicite
<VSCodeButton className="w-full whitespace-nowrap text-xs px-2 py-1">
    Show Advanced Config  {/* Texte complet préservé */}
</VSCodeButton>
```

### 🎯 Avantages

- ✅ **Lisibilité**: Texte toujours complet
- ✅ **Professionnalisme**: Interface plus soignée
- ✅ **Accessibilité**: Meilleure expérience utilisateur
- ✅ **Simplicité**: Une seule classe CSS

### ⚠️ Limitations

- ⚠️ **Layout**: Peut nécessiter des ajustements de taille
- ⚠️ **Responsive**: Peut causer des overflow sur petits écrans
- ⚠️ **Testing**: Nécessite de tester différentes tailles

### 🔄 Variations

#### Variation A: Text Ellipsis

```typescript
<VSCodeButton className="w-full truncate text-xs px-2 py-1">
    Show Advanced Config  {/* "Show Advanced..." avec ... */}
</VSCodeButton>
```

#### Variation B: Responsive Text

```typescript
<VSCodeButton className="w-full text-xs md:text-sm px-2 py-1">
    Show Advanced Config  {/* Texte plus grand sur desktop */}
</VSCodeButton>
```

---

## 🧪 Patterns de Test

### Pattern A: Test Race Condition

```typescript
it("should handle rapid provider changes", async () => {
    const { user } = setup()
    
    // Cliquer rapidement sur plusieurs providers
    await user.click(screen.getByLabelText("Smart Provider"))
    await user.click(screen.getByLabelText("Native Provider"))
    await user.click(screen.getByLabelText("Smart Provider"))
    
    // Vérifier que le dernier choix est respecté
    await waitFor(() => {
        expect(screen.getByLabelText("Smart Provider")).toBeChecked()
    })
})
```

### Pattern B: Test Stale Closure

```typescript
it("should access current state in event handlers", async () => {
    const { user } = setup()
    
    // Changer le state
    await user.click(screen.getByLabelText("Change State"))
    
    // Déclencher l'événement qui utilise le state
    fireEvent(window, new MessageEvent("message", {
        data: { type: "test" }
    }))
    
    // Vérifier que le handler voit la valeur actuelle
    expect(screen.getByTestId("current-state")).toHaveTextContent("new-value")
})
```

---

## 📚 Guidelines d'Application

### 🎯 Quand Utiliser Chaque Pattern

| Pattern | Contexte | Complexité | Priorité |
|---------|----------|------------|----------|
| **Frontend-Backend Sync** | Synchronisation état | Moyenne | Haute |
| **Stale Closure Prevention** | useEffect avec state | Moyenne | Haute |
| **Web Components Control** | Composants externes | Faible | Moyenne |
| **PowerShell Automation** | Configuration VSCode | Faible | Moyenne |
| **CSS Responsive** | UI/UX | Faible | Basse |

### 🔄 Séquence d'Implémentation

1. **Analyser le problème** : Identifier la cause racine
2. **Choisir le pattern** : Sélectionner la solution appropriée
3. **Implémenter minimale** : Version la plus simple d'abord
4. **Tester unitairement** : Valider le comportement
5. **Documenter** : Ajouter aux patterns réutilisables
6. **Itérer** : Améliorer si nécessaire

### ⚠️ Pièges à Éviter

- **Over-engineering** : Ne pas utiliser de pattern complexe pour un problème simple
- **Copy-paste** : Adapter le pattern au contexte spécifique
- **Documentation oubliée** : Toujours documenter l'application du pattern
- **Tests manquants** : Valider que le pattern résout bien le problème

---

## 🔗 Références

### Documentation React
- [useEffect Hook](https://react.dev/reference/react/useEffect)
- [useCallback Hook](https://react.dev/reference/react/useCallback)
- [useRef Hook](https://react.dev/reference/react/useRef)
- [Stale Closures](https://dmitripavlutin.com/react-hooks-stale-closures/)

### Documentation VSCode
- [Webview UI Toolkit](https://github.com/microsoft/vscode-webview-ui-toolkit)
- [Terminal Profiles](https://code.visualstudio.com/docs/terminal/profiles)

### Documentation Tailwind
- [Whitespace Control](https://tailwindcss.com/docs/whitespace)
- [Responsive Design](https://tailwindcss.com/docs/responsive-design)

---

## ✅ Conclusion

Ces patterns techniques ont été identifiés et validés lors de la résolution des bugs de l'extension Roo. Ils sont maintenant documentés pour être réutilisés dans les futures interventions, accélérant ainsi le développement et améliorant la qualité du code.

**Principes clés**:
- 🎯 **Simplicité d'abord** : Commencer par la solution la plus simple
- 🔄 **Itération continue** : Améliorer progressivement
- 📚 **Documentation systématique** : Partager les connaissances
- 🧪 **Tests rigoureux** : Valider chaque pattern

---

**Status**: ✅ PATTERNS VALIDÉS  
**Next Steps**: Appliquer ces patterns dans les futures interventions

---

*Documentation des patterns techniques réutilisables pour l'extension VSCode Roo*