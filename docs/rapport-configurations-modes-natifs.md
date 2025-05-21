# Rapport sur les dernières configurations de modes natifs de Roo

## Introduction

Ce rapport présente les résultats de notre analyse des dernières configurations de modes natifs de Roo, avec un focus particulier sur le champ additionnel `whenToUse` et les optimisations de prompt système récentes. Cette analyse a été réalisée en examinant le code source du dépôt officiel de Roo et les configurations disponibles dans notre dépôt local.

## 1. Le champ `whenToUse`

### 1.1 Définition et utilisation

Le champ `whenToUse` est un champ optionnel de type string défini dans les schémas `modeConfigSchema` et `promptComponentSchema` du code source de Roo. Ce champ est utilisé pour définir quand utiliser chaque mode, et est affiché à l'utilisateur dans l'interface de Roo pour l'aider à choisir le mode approprié pour sa tâche.

Dans le fichier `src/core/prompts/sections/modes.ts`, nous avons découvert comment ce champ est utilisé :

```typescript
if(mode.whenToUse && mode.whenToUse.trim() !== "") {
  // Use whenToUse as the primary description, indenting subsequent lines for readability
  description = mode.whenToUse.replace(/\n/g, "\n ")
} else {
  // Fallback to the first sentence of roleDefinition if whenToUse is not available
  description = mode.roleDefinition.split(".")[0]
}
```

Ce code montre que :
1. Si le champ `whenToUse` est défini et non vide, il est utilisé comme description principale du mode dans l'interface utilisateur
2. Sinon, le système utilise la première phrase de la définition du rôle (`roleDefinition`) comme fallback

### 1.2 Importance dans la sélection des modes

Le champ `whenToUse` joue un rôle crucial dans l'expérience utilisateur de Roo, car il guide l'utilisateur dans le choix du mode le plus approprié pour sa tâche. Une description claire et précise de quand utiliser chaque mode permet à l'utilisateur de faire un choix éclairé et d'obtenir les meilleurs résultats possibles.

## 2. Optimisations récentes des prompts système

Notre analyse a identifié plusieurs optimisations majeures dans les prompts système natifs de Roo :

### 2.1 Structuration en sections

Les prompts système sont désormais organisés en sections clairement définies :
- CAPABILITIES
- RULES
- OBJECTIVE
- MODES
- SYSTEM INFORMATION
- etc.

Cette structuration améliore la lisibilité et la maintenance des prompts, et permet une meilleure organisation des instructions.

### 2.2 Mécanismes d'escalade et de désescalade

Les prompts système incluent maintenant des mécanismes sophistiqués d'escalade et de désescalade qui permettent de passer d'un niveau de complexité à un autre en fonction des besoins. Ces mécanismes sont particulièrement visibles dans les configurations des modes n5, qui définissent des critères précis pour l'escalade et la désescalade.

Exemple de mécanisme d'escalade (extrait du mode code-micro) :
```
MÉCANISME D'ESCALADE:

IMPORTANT: Vous DEVEZ escalader toute tâche qui correspond aux critères suivants:
- Tâches nécessitant des modifications de plus de 10 lignes de code
- Tâches impliquant des fonctions avec des dépendances
- Tâches nécessitant une compréhension du contexte global
- Tâches impliquant des optimisations
- Tâches nécessitant une analyse
```

### 2.3 Intégration des MCPs

Les prompts système intègrent désormais un support amélioré pour les Model Context Protocol servers (MCPs) qui étendent les capacités de Roo. Les instructions spécifiques sur l'utilisation des MCPs sont incluses dans les prompts, avec des recommandations sur quand et comment les utiliser.

Exemple d'instructions pour l'utilisation des MCPs :
```
/* UTILISATION OPTIMISÉE DES MCPs */
// Privilégier l'utilisation des MCPs pour les opérations simples
// Pour les manipulations de fichiers, utiliser le MCP quickfiles
// Pour l'extraction d'informations web, utiliser le MCP jinavigator
// Pour les recherches web, utiliser le MCP searxng
// Pour les commandes système, utiliser le MCP win-cli
```

### 2.4 Gestion des tokens

Les prompts système incluent des mécanismes avancés pour gérer efficacement les limites de tokens et optimiser les conversations longues. Ces mécanismes définissent des seuils d'avertissement et critiques, et fournissent des instructions sur les actions à prendre lorsque ces seuils sont atteints.

Exemple de gestion des tokens :
```
/* GESTION DES TOKENS */
// Seuils spécifiques au niveau
// - Seuil d'avertissement: 45000 tokens
// - Seuil critique: 50000 tokens

GESTION DES TOKENS:
- Si la conversation approche 45000 tokens, suggérer l'escalade
- Si la conversation dépasse 50000 tokens, utiliser l'outil `switch_mode` pour escalader
```

### 2.5 Métriques de complexité

Les prompts système incluent désormais des métriques de complexité qui aident à déterminer le niveau de complexité d'une tâche et à choisir le mode approprié. Ces métriques incluent le nombre de lignes de code, la taille de la conversation, le contexte requis, et le temps de réflexion.

Exemple de métriques de complexité :
```
/* MÉTRIQUES DE COMPLEXITÉ */
// - Lignes de code: 50-200
// - Taille de conversation: 10-15 messages, 25000-50000 tokens
// - Contexte requis: Modéré
// - Temps de réflexion: Moyen
```

## 3. Recommandations pour les modes simple/complex et n5

Sur la base de notre analyse, nous recommandons les modifications suivantes pour les modes simple/complex et n5 :

### 3.1 Ajout du champ `whenToUse` à tous les modes

Nous recommandons d'ajouter le champ `whenToUse` à tous les modes simple/complex et n5 pour améliorer l'expérience utilisateur et faciliter la sélection du mode approprié. Voici des exemples de valeurs pour ce champ :

#### Pour les modes simple/complex :

```json
{
  "slug": "code-simple",
  "name": "💻 Code Simple",
  "whenToUse": "Utilisez ce mode pour des modifications mineures de code (moins de 50 lignes), des corrections de bugs simples, du formatage de code, de la documentation, et l'implémentation de fonctionnalités basiques. Idéal pour les tâches isolées qui ne nécessitent pas une compréhension approfondie de l'architecture globale.",
  "roleDefinition": "You are Roo Code (version simple), specialized in minor code modifications, simple bug fixes, code formatting and documentation, and basic feature implementation.",
  // autres champs...
}
```

```json
{
  "slug": "code-complex",
  "name": "💻 Code Complex",
  "whenToUse": "Utilisez ce mode pour des modifications majeures de code, des refactorisations, des optimisations de performance, la conception de systèmes, et l'implémentation de fonctionnalités complexes. Idéal pour les tâches qui nécessitent une compréhension approfondie de l'architecture globale et des interactions entre composants.",
  "roleDefinition": "You are Roo, a highly skilled software engineer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices.",
  // autres champs...
}
```

#### Pour les modes n5 :

```json
{
  "slug": "code-micro",
  "name": "💻 Code Micro",
  "whenToUse": "Utilisez ce mode pour des modifications très mineures de code (moins de 10 lignes), des corrections de bugs évidents, du formatage de code, et de la documentation très basique. Idéal pour les tâches très isolées et simples qui ne nécessitent pas de contexte.",
  "roleDefinition": "You are Roo Code (version micro), specialized in very minor code modifications, simple bug fixes, code formatting and documentation.",
  // autres champs...
}
```

```json
{
  "slug": "code-mini",
  "name": "💻 Code Mini",
  "whenToUse": "Utilisez ce mode pour des modifications mineures de code (10-50 lignes), des corrections de bugs simples, du formatage de code, de la documentation, et l'implémentation de fonctionnalités basiques. Idéal pour les tâches isolées qui nécessitent un contexte limité.",
  "roleDefinition": "You are Roo Code (version mini), specialized in minor code modifications, simple bug fixes, code formatting and documentation, and basic feature implementation.",
  // autres champs...
}
```

```json
{
  "slug": "code-medium",
  "name": "💻 Code Medium",
  "whenToUse": "Utilisez ce mode pour des modifications modérées de code (50-200 lignes), des corrections de bugs modérés, l'implémentation de fonctionnalités, des optimisations basiques, et des refactorisations limitées. Idéal pour les tâches qui nécessitent un contexte modéré et une compréhension des interactions entre composants.",
  "roleDefinition": "You are Roo Code (version medium), specialized in moderate code modifications, bug fixes, feature implementation, and basic optimizations.",
  // autres champs...
}
```

```json
{
  "slug": "code-large",
  "name": "💻 Code Large",
  "whenToUse": "Utilisez ce mode pour des modifications majeures de code (plus de 200 lignes), des refactorisations majeures, des optimisations de performance, la conception de systèmes, et l'intégration de composants. Idéal pour les tâches qui nécessitent un contexte étendu et une compréhension approfondie de l'architecture.",
  "roleDefinition": "You are Roo Code (version large), specialized in major code modifications, complex bug fixes, feature implementation, and advanced optimizations.",
  // autres champs...
}
```

```json
{
  "slug": "code-oracle",
  "name": "💻 Code Oracle",
  "whenToUse": "Utilisez ce mode pour la conception de systèmes entiers, les architectures distribuées complexes, les optimisations de niveau entreprise, la recherche avancée, et les problèmes nécessitant une expertise pointue. Idéal pour les tâches les plus complexes qui nécessitent un contexte global et une réflexion approfondie.",
  "roleDefinition": "You are Roo Code (version oracle), specialized in system-level design, highly complex optimizations, advanced research, and expert-level problem solving.",
  // autres champs...
}
```

### 3.2 Intégration des optimisations de prompt système

Nous recommandons d'intégrer les optimisations de prompt système identifiées dans les modes simple/complex et n5 :

1. **Structuration en sections** : Organiser les prompts en sections clairement définies
2. **Mécanismes d'escalade et de désescalade** : Définir des critères précis pour l'escalade et la désescalade
3. **Intégration des MCPs** : Inclure des instructions spécifiques sur l'utilisation des MCPs
4. **Gestion des tokens** : Définir des seuils d'avertissement et critiques, et des actions à prendre
5. **Métriques de complexité** : Inclure des métriques pour aider à déterminer le niveau de complexité d'une tâche

## 4. Conclusion

Notre analyse des dernières configurations de modes natifs de Roo a révélé plusieurs optimisations importantes dans les prompts système, notamment la structuration en sections, les mécanismes d'escalade et de désescalade, l'intégration des MCPs, la gestion des tokens, et les métriques de complexité.

Nous avons également identifié le champ `whenToUse` comme un élément clé pour améliorer l'expérience utilisateur et faciliter la sélection du mode approprié. Nous recommandons d'ajouter ce champ à tous les modes simple/complex et n5, avec des descriptions claires et précises de quand utiliser chaque mode.

En intégrant ces optimisations et en ajoutant le champ `whenToUse`, nous pouvons améliorer significativement l'efficacité et l'utilisabilité de nos modes personnalisés.

## 5. Prochaines étapes

1. Mettre à jour les configurations des modes simple/complex et n5 avec le champ `whenToUse`
2. Intégrer les optimisations de prompt système identifiées
3. Tester les modes mis à jour pour vérifier leur efficacité
4. Déployer les modes mis à jour sur les environnements de production
5. Mettre à jour la documentation pour refléter les changements