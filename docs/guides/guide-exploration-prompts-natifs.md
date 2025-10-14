# Guide d'exploration des prompts natifs de Roo

Ce guide a été créé pour faciliter l'exploration et la compréhension des prompts natifs de Roo. Il fournit des instructions détaillées sur comment accéder aux fichiers sources, comprendre leur structure, et extraire les informations pertinentes.

## Table des matières

1. [Accès aux sources des prompts natifs](#1-accès-aux-sources-des-prompts-natifs)
2. [Structure des fichiers clés](#2-structure-des-fichiers-clés)
3. [Extraction des informations importantes](#3-extraction-des-informations-importantes)
4. [Utilisation des URLs raw pour accéder au contenu](#4-utilisation-des-urls-raw-pour-accéder-au-contenu)
5. [Outils recommandés](#5-outils-recommandés)

## 1. Accès aux sources des prompts natifs

### Via GitHub

Le moyen le plus direct d'accéder aux prompts natifs de Roo est via le dépôt GitHub officiel :

```
https://github.com/RooVetGit/Roo-Code
```

Les fichiers les plus importants pour comprendre les prompts natifs se trouvent dans les répertoires suivants :

- `src/core/prompts/` : Contient les fichiers principaux des prompts système
- `src/core/prompts/sections/` : Contient les différentes sections des prompts
- `src/shared/modes.ts` : Définit la structure des modes et leurs propriétés
- `src/schemas/index.ts` : Contient les schémas Zod qui définissent les types de données

### Via clone local

Pour un accès plus facile et une exploration plus approfondie, vous pouvez cloner le dépôt localement :

```bash
git clone https://github.com/RooVetGit/Roo-Code.git roo-code-source
cd roo-code-source
```

## 2. Structure des fichiers clés

### `src/shared/modes.ts`

Ce fichier définit la structure des modes natifs et contient :

- La définition des modes natifs (`modes`)
- Les types et interfaces pour les modes (`ModeConfig`, `Mode`, etc.)
- Les fonctions utilitaires pour manipuler les modes (`getModeBySlug`, `getAllModes`, etc.)
- La définition du champ `whenToUse` et son utilisation

### `src/schemas/index.ts`

Ce fichier contient les schémas Zod qui définissent les types de données utilisés dans Roo, notamment :

- `modeConfigSchema` : Définit la structure d'un mode
- `promptComponentSchema` : Définit les composants d'un prompt
- `customModePromptsSchema` : Définit la structure des prompts personnalisés

### `src/core/prompts/system.ts`

Ce fichier est responsable de la génération des prompts système et contient :

- La fonction `generatePrompt` qui assemble les différentes sections du prompt
- La fonction `SYSTEM_PROMPT` qui est le point d'entrée pour générer un prompt système complet

### `src/core/prompts/sections/modes.ts`

Ce fichier génère la section MODES du prompt système et contient :

- La fonction `getModesSection` qui génère la liste des modes disponibles
- La logique pour utiliser le champ `whenToUse` comme description du mode

## 3. Extraction des informations importantes

Pour extraire efficacement les informations des prompts natifs, concentrez-vous sur :

### Le champ `whenToUse`

Le champ `whenToUse` est défini dans `src/schemas/index.ts` comme un champ optionnel de type string dans `modeConfigSchema` et `promptComponentSchema`. Il est utilisé dans `src/core/prompts/sections/modes.ts` pour générer la description des modes dans la section MODES du prompt système.

```typescript
// Dans src/core/prompts/sections/modes.ts
if(mode.whenToUse && mode.whenToUse.trim() !== "") {
  // Use whenToUse as the primary description
  description = mode.whenToUse.replace(/\n/g, "\n ")
} else {
  // Fallback to the first sentence of roleDefinition
  description = mode.roleDefinition.split(".")[0]
}
```

### Les sections du prompt système

Les sections du prompt système sont définies dans `src/core/prompts/sections/` et incluent :

- `capabilities.ts` : Définit les capacités du mode
- `rules.ts` : Définit les règles à suivre
- `objective.ts` : Définit l'objectif du mode
- `system-info.ts` : Fournit des informations sur le système
- `tool-use.ts` et `tool-use-guidelines.ts` : Définissent comment utiliser les outils
- `mcp-servers.ts` : Définit comment utiliser les serveurs MCP
- `modes.ts` : Liste les modes disponibles

### Les optimisations récentes

Les optimisations récentes des prompts système peuvent être identifiées en examinant :

- Les mécanismes d'escalade et de désescalade dans les instructions personnalisées
- La gestion des tokens et les seuils définis
- L'intégration des MCPs et les instructions associées
- Les métriques de complexité utilisées pour évaluer les tâches

## 4. Utilisation des URLs raw pour accéder au contenu

Pour accéder directement au contenu brut des fichiers sur GitHub, utilisez les URLs de type "raw" :

```
https://raw.githubusercontent.com/RooVetGit/Roo-Code/main/src/core/prompts/system.ts
```

Cette méthode est particulièrement utile lorsque vous utilisez des outils comme Jinavigator pour explorer le code source.

Exemples d'URLs raw pour les fichiers clés :

- `src/shared/modes.ts` : https://raw.githubusercontent.com/RooVetGit/Roo-Code/main/src/shared/modes.ts
- `src/schemas/index.ts` : https://raw.githubusercontent.com/RooVetGit/Roo-Code/main/src/schemas/index.ts
- `src/core/prompts/system.ts` : https://raw.githubusercontent.com/RooVetGit/Roo-Code/main/src/core/prompts/system.ts
- `src/core/prompts/sections/modes.ts` : https://raw.githubusercontent.com/RooVetGit/Roo-Code/main/src/core/prompts/sections/modes.ts

## 5. Outils recommandés

Pour explorer efficacement les prompts natifs de Roo, nous recommandons les outils suivants :

### Jinavigator MCP

Le MCP Jinavigator est particulièrement utile pour explorer le code source de Roo sur GitHub. Utilisez-le avec les URLs raw pour accéder directement au contenu des fichiers :

```xml
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>convert_web_to_markdown</tool_name>
<arguments>
{
  "url": "https://raw.githubusercontent.com/RooVetGit/Roo-Code/main/src/shared/modes.ts"
}
</arguments>
</use_mcp_tool>
```

### Quickfiles MCP

Le MCP Quickfiles est utile pour explorer et manipuler les fichiers locaux :

```xml
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["roo-modes/n5/configs/n5-modes-roo-compatible.json", "roo-config/settings/modes.json"],
  "show_line_numbers": true
}
</arguments>
</use_mcp_tool>
```

### VS Code avec extensions

VS Code avec les extensions suivantes facilite l'exploration du code source :

- **GitHub Pull Requests and Issues** : Pour explorer le dépôt GitHub directement depuis VS Code
- **GitLens** : Pour voir l'historique des modifications et les auteurs
- **JSON Tools** : Pour formater et valider les fichiers JSON
- **Markdown All in One** : Pour prévisualiser et éditer les fichiers Markdown

---

En suivant ce guide, vous pourrez explorer efficacement les prompts natifs de Roo, comprendre leur structure, et extraire les informations importantes pour améliorer vos modes personnalisés.