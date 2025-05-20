# Guide du Format des Références aux Modèles dans les Configurations Roo

## Introduction

Ce guide documente le format attendu pour les références aux modèles dans les différentes sections du fichier `model-configs.json` de Roo. Une compréhension claire de ces formats est essentielle pour éviter les erreurs de configuration et assurer le bon fonctionnement de Roo.

## Architecture et Implémentation dans le Code Source

L'architecture de Roo concernant la gestion des modèles est implémentée principalement dans les fichiers suivants:

- `roo-code/src/core/config/ProviderSettingsManager.ts`: Gère les profils de configuration d'API et leur association avec les modes
- `roo-code/src/shared/modes.ts`: Définit les modes disponibles dans Roo
- `roo-code/src/schemas/index.ts`: Définit les schémas de validation pour les configurations

Dans l'interface utilisateur de Roo, les modes sont associés à des profils (configurations d'API) plutôt qu'aux modèles OpenRouter directement. Cette association est gérée par la classe `ProviderSettingsManager` qui maintient une structure de données appelée `ProviderProfiles` contenant:

```typescript
export const providerProfilesSchema = z.object({
  currentApiConfigName: z.string(),
  apiConfigs: z.record(z.string(), providerSettingsWithIdSchema),
  modeApiConfigs: z.record(z.string(), z.string()).optional(),
  // ...
})
```

## Structure du Fichier model-configs.json

Le fichier `model-configs.json` est composé de trois sections principales qui interagissent entre elles:

1. **configurations**: Définit des ensembles de modèles pour différents modes
2. **apiConfigs**: Contient les configurations d'API pour chaque modèle (les "profils")
3. **modeApiConfigs**: Associe des modes spécifiques à des configurations d'API

## Format des Références dans la Section "configurations"

### Format attendu: `"fournisseur/modèle"`

Dans la section `configurations`, les références aux modèles doivent suivre le format `"fournisseur/modèle"`. Ce format permet d'identifier de manière unique un modèle spécifique d'un fournisseur particulier.

**Exemples:**
- `"anthropic/claude-3.7-sonnet"`
- `"qwen/qwen3-32b"`
- `"google/gemini-2.5-pro-exp-03-25"`
- `"deepseek/deepseek-r1"`

**Exemple de configuration:**
```json
"configurations": [
  {
    "name": "Configuration actuelle",
    "description": "Configuration avec Qwen 3 32B pour les modes simples et Claude 3.7 Sonnet pour les modes complexes",
    "modes": {
      "code-simple": "qwen/qwen3-32b",
      "code-complex": "anthropic/claude-3.7-sonnet"
    }
  }
]
```

Cette section est utilisée principalement pour définir des ensembles de modèles qui peuvent être sélectionnés dans l'interface utilisateur. Cependant, la résolution effective du modèle à utiliser pour un mode donné passe par les sections `apiConfigs` et `modeApiConfigs`.

## Format des Références dans la Section "apiConfigs" (Profils)

### Format attendu: Clés au format `"nom-du-modèle"`

Dans la section `apiConfigs`, les clés doivent être au format `"nom-du-modèle"` (sans le préfixe du fournisseur). Chaque configuration contient un identifiant unique (`id`) qui sera référencé dans la section `modeApiConfigs`.

Ces configurations sont ce que l'interface utilisateur de Roo appelle des "profils". Un profil contient tous les paramètres nécessaires pour communiquer avec un modèle spécifique via un fournisseur d'API.

**Exemples de clés:**
- `"claude-3.7-sonnet"`
- `"qwen3-32b"`
- `"gemini-2.5-pro"`
- `"deepseek-r1"`

**Exemple de configuration d'API (profil):**
```json
"apiConfigs": {
  "claude-3.7-sonnet": {
    "diffEnabled": true,
    "fuzzyMatchThreshold": 1,
    "modelTemperature": null,
    "openRouterApiKey": "sk-or-v1-xxxxxxxxxxxx",
    "openRouterModelId": "anthropic/claude-3.7-sonnet",
    "openRouterUseMiddleOutTransform": false,
    "apiProvider": "openrouter",
    "id": "gi7et2uwpwo"
  }
}
```

Dans le code source, ces configurations sont gérées par la classe `ProviderSettingsManager` qui les stocke de manière sécurisée et les expose via diverses méthodes comme `getProfile()`, `saveConfig()`, etc.

## Format des Références dans la Section "modeApiConfigs"

### Format attendu: Références aux IDs des configurations d'API

Dans la section `modeApiConfigs`, chaque mode est associé à l'ID d'une configuration d'API définie dans la section `apiConfigs`. Ces IDs sont des chaînes alphanumériques uniques générées par la méthode `generateId()` de la classe `ProviderSettingsManager`.

**Exemple:**
```json
"modeApiConfigs": {
  "code-simple": "rfjyvcdycv",
  "code-complex": "usl6gy8xkxg"
}
```

Dans cet exemple:
- `"code-simple"` utilise la configuration d'API avec l'ID `"rfjyvcdycv"`
- `"code-complex"` utilise la configuration d'API avec l'ID `"usl6gy8xkxg"`

Dans le code source, cette association est gérée par les méthodes `setModeConfig()` et `getModeConfigId()` de la classe `ProviderSettingsManager`:

```typescript
public async setModeConfig(mode: Mode, configId: string) {
  // ...
  providerProfiles.modeApiConfigs[mode] = configId
  // ...
}

public async getModeConfigId(mode: Mode) {
  // ...
  return modeApiConfigs?.[mode]
  // ...
}
```

## Flux Complet de Résolution d'un Modèle

Le processus de résolution d'un modèle pour un mode spécifique dans Roo suit plusieurs étapes:

1. **Sélection du mode**: L'utilisateur sélectionne un mode dans l'interface (par exemple, "code", "architect", etc.)

2. **Résolution de l'ID de configuration**: Roo consulte la section `modeApiConfigs` pour trouver l'ID de la configuration d'API associée à ce mode
   ```typescript
   // Dans ProviderSettingsManager.ts
   const configId = await this.getModeConfigId(mode);
   ```

3. **Récupération du profil**: Roo utilise cet ID pour récupérer le profil complet depuis la section `apiConfigs`
   ```typescript
   // Dans ProviderSettingsManager.ts
   const profile = await this.getProfile({ id: configId });
   ```

4. **Utilisation du modèle**: Roo utilise les paramètres du profil pour communiquer avec le modèle via l'API appropriée (OpenRouter, Anthropic, etc.)

Ce flux est illustré dans le diagramme suivant:

```
┌─────────┐      ┌───────────────┐      ┌──────────────┐      ┌────────────────┐
│  Mode   │──────▶ modeApiConfigs │──────▶   apiConfigs  │──────▶ Modèle OpenRouter│
│ (code)  │      │  (ID: xyz123) │      │ (Profil avec │      │(anthropic/claude)│
└─────────┘      └───────────────┘      │paramètres API)│      └────────────────┘
                                        └──────────────┘
```

## Différence entre Noms de Modèles, Profils et IDs

Il est important de comprendre la distinction entre les différentes références utilisées dans Roo:

1. **Noms de modèles** (format "fournisseur/modèle"):
   - Exemple: `"anthropic/claude-3.7-sonnet"`
   - Utilisés dans la section `configurations` et comme valeur de `openRouterModelId` dans les profils
   - Identifient de manière unique un modèle spécifique d'un fournisseur particulier

2. **Noms de profils** (format "nom-du-modèle"):
   - Exemple: `"claude-3.7-sonnet"`
   - Utilisés comme clés dans la section `apiConfigs`
   - Correspondent généralement au nom du modèle sans le préfixe du fournisseur

3. **IDs des configurations d'API**:
   - Exemple: `"gi7et2uwpwo"`
   - Chaînes alphanumériques uniques générées par Roo
   - Utilisés dans la section `modeApiConfigs` pour associer des modes à des profils

## Exemples Concrets avec Références au Code Source

### Exemple 1: Configuration pour le mode "code-simple"

1. Dans `configurations`, le mode `"code-simple"` est associé au modèle `"qwen/qwen3-32b"`.
2. Dans `modeApiConfigs`, le mode `"code-simple"` est associé à l'ID `"rfjyvcdycv"`.
3. Dans `apiConfigs`, l'ID `"rfjyvcdycv"` correspond à la configuration pour `"qwen3-32b"`.

Lorsque l'utilisateur sélectionne le mode "code-simple", Roo:
- Appelle `getModeConfigId("code-simple")` qui renvoie `"rfjyvcdycv"`
- Utilise cet ID pour récupérer le profil complet avec `getProfile({ id: "rfjyvcdycv" })`
- Utilise les paramètres de ce profil pour communiquer avec le modèle `"qwen/qwen3-32b"` via OpenRouter

### Exemple 2: Configuration pour le mode "code-complex"

1. Dans `configurations`, le mode `"code-complex"` est associé au modèle `"anthropic/claude-3.7-sonnet"`.
2. Dans `modeApiConfigs`, le mode `"code-complex"` est associé à l'ID `"usl6gy8xkxg"`.
3. Dans `apiConfigs`, l'ID `"usl6gy8xkxg"` correspond à la configuration pour `"default"` (qui utilise Claude 3.7 Sonnet).

## Bonnes Pratiques

1. **Cohérence des noms**: Assurez-vous que les noms de modèles dans `configurations` correspondent aux configurations d'API dans `apiConfigs`.

2. **Vérification des IDs**: Vérifiez que tous les IDs référencés dans `modeApiConfigs` existent bien dans `apiConfigs`.

3. **Format des références**: Respectez strictement le format `"fournisseur/modèle"` dans la section `configurations`.

4. **Nommage des clés**: Dans `apiConfigs`, utilisez des noms de clés qui correspondent au nom du modèle sans le préfixe du fournisseur.

5. **Documentation**: Documentez toute modification apportée au fichier `model-configs.json` pour faciliter le suivi des changements.

## Conclusion

Le respect des formats de référence aux modèles dans le fichier `model-configs.json` est crucial pour le bon fonctionnement de Roo. Ce guide sert de référence pour les futures modifications de ce fichier et aide à éviter les confusions sur le format attendu pour les références aux modèles.

En comprenant comment les modes sont associés aux profils, puis aux modèles OpenRouter, vous pourrez configurer Roo de manière plus efficace et éviter les erreurs de configuration.