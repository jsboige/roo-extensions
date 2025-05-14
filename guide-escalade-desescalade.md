# Guide d'utilisation des mécanismes d'escalade et désescalade

Ce guide explique comment utiliser efficacement les mécanismes d'escalade et de désescalade dans les modes simples et complexes de Roo.

## Table des matières

1. [Introduction](#introduction)
2. [Niveaux de complexité](#niveaux-de-complexité)
3. [Mécanisme d'escalade](#mécanisme-descalade)
   - [Escalade externe](#escalade-externe)
   - [Escalade interne](#escalade-interne)
   - [Critères d'escalade](#critères-descalade)
4. [Mécanisme de désescalade](#mécanisme-de-désescalade)
   - [Critères de désescalade](#critères-de-désescalade)
   - [Processus d'évaluation continue](#processus-dévaluation-continue)
5. [Gestion des tokens](#gestion-des-tokens)
6. [Exemples pratiques](#exemples-pratiques)
   - [Exemple d'escalade externe](#exemple-descalade-externe)
   - [Exemple d'escalade interne](#exemple-descalade-interne)
   - [Exemple de désescalade](#exemple-de-désescalade)
7. [Bonnes pratiques](#bonnes-pratiques)

## Introduction

Les mécanismes d'escalade et de désescalade permettent d'adapter dynamiquement le niveau de complexité des agents Roo en fonction des besoins de la tâche. Ces mécanismes garantissent que:

- Les tâches complexes sont traitées par des agents disposant des capacités nécessaires
- Les tâches simples sont traitées par des agents plus légers et plus rapides
- Les ressources (tokens, temps de calcul) sont utilisées de manière optimale

## Niveaux de complexité

Le système actuel définit deux niveaux de complexité:

1. **SIMPLE (niveau 1)**: Pour les tâches simples, isolées, bien définies
   - Modèle: Claude 3.5 Sonnet
   - Optimisé pour: modifications mineures, bugs simples, documentation basique

2. **COMPLEX (niveau 2)**: Pour les tâches complexes, interdépendantes, nécessitant une analyse approfondie
   - Modèle: Claude 3.7 Sonnet
   - Optimisé pour: refactorisations majeures, optimisations, conception d'architecture

> **Note**: Le système est conçu pour être extensible à n-niveaux de complexité à l'avenir.

## Mécanisme d'escalade

L'escalade permet de passer d'un mode simple à un mode complexe lorsqu'une tâche dépasse les capacités du mode simple.

### Escalade externe

L'escalade externe consiste à terminer la tâche dans le mode simple et à recommander à l'utilisateur de passer au mode complexe correspondant.

**Format standardisé**:
```
[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]
```

### Escalade interne

L'escalade interne permet de traiter une tâche complexe sans changer de mode. Elle doit être utilisée uniquement dans les cas suivants:

1. La tâche est majoritairement simple mais contient des éléments complexes isolés
2. L'utilisateur a explicitement demandé de ne pas changer de mode
3. La tâche est à la limite entre simple et complexe mais l'agent est confiant de pouvoir la résoudre

**Format standardisé au début de la réponse**:
```
[ESCALADE INTERNE] Cette tâche est traitée en mode avancé car : [RAISON SPÉCIFIQUE]
```

**Format standardisé à la fin de la réponse**:
```
[SIGNALER_ESCALADE_INTERNE]
```

### Critères d'escalade

Une tâche doit être escaladée si elle correspond à l'un des critères suivants:

- Nécessite des modifications de plus de 50 lignes de code
- Implique des refactorisations majeures
- Nécessite une conception d'architecture
- Implique des optimisations de performance
- Nécessite une analyse approfondie
- Implique plusieurs systèmes ou composants interdépendants
- Nécessite une compréhension approfondie de l'architecture globale

## Mécanisme de désescalade

La désescalade permet de passer d'un mode complexe à un mode simple lorsqu'une tâche s'avère plus simple que prévu.

**Format standardisé**:
```
[DÉSESCALADE SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : [RAISON]
```

### Critères de désescalade

Une tâche est considérée comme simple si elle remplit TOUS les critères suivants:

- Nécessite des modifications de moins de 50 lignes de code
- Concerne des fonctionnalités isolées sans impact sur d'autres systèmes
- Suit des patterns standards bien documentés
- Ne nécessite pas d'optimisations complexes
- Ne requiert pas d'analyse approfondie de l'architecture existante

### Processus d'évaluation continue

Le processus d'évaluation continue de la complexité comprend les étapes suivantes:

1. Évaluer la complexité initiale de la tâche dès sa réception
2. Réévaluer la complexité après chaque étape majeure de résolution
3. Si à un moment la tâche devient suffisamment simple, suggérer la désescalade
4. Si une sous-tâche spécifique est simple mais le contexte global reste complexe, continuer en mode complexe

## Gestion des tokens

Les mécanismes d'escalade et de désescalade incluent également une gestion des tokens pour optimiser les ressources:

- Si la conversation dépasse 50 000 tokens en mode simple:
  ```
  [LIMITE DE TOKENS] Cette conversation a dépassé 50 000 tokens. Je recommande de passer en mode complexe pour continuer.
  ```

- Si la conversation dépasse 100 000 tokens (tous modes):
  ```
  [LIMITE DE TOKENS CRITIQUE] Cette conversation a dépassé 100 000 tokens. Je recommande de passer en mode orchestration pour diviser la tâche en sous-tâches.
  ```

## Exemples pratiques

### Exemple d'escalade externe

**Tâche**: "Refactoriser le système d'authentification pour utiliser JWT et améliorer la sécurité"

**Réponse du mode simple**:
```
[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : elle implique une refactorisation majeure du système d'authentification, nécessite une compréhension approfondie des mécanismes de sécurité JWT et impacte plusieurs composants du système.
```

### Exemple d'escalade interne

**Tâche**: "Corriger un bug dans la fonction de validation des formulaires"

**Analyse**: Le bug semble simple mais après examen, il s'avère qu'il implique des interactions complexes entre le système de validation et le système de gestion d'état.

**Réponse du mode simple**:
```
[ESCALADE INTERNE] Cette tâche est traitée en mode avancé car : le bug implique des interactions subtiles entre le système de validation et le système de gestion d'état

[Analyse et solution détaillée...]

[SIGNALER_ESCALADE_INTERNE]
```

### Exemple de désescalade

**Tâche initiale**: "Optimiser les performances du système de recherche"

**Évolution**: Après analyse, il s'avère que le problème est simplement un index manquant dans la base de données.

**Réponse du mode complexe**:
```
[DÉSESCALADE SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : le problème identifié est simplement un index manquant dans la base de données, ce qui ne nécessite pas d'analyse approfondie ou de refactorisation complexe

[Solution détaillée...]
```

## Bonnes pratiques

1. **Évaluation précoce**: Évaluez la complexité de la tâche dès le début pour éviter de perdre du temps sur des tâches qui nécessitent une escalade.

2. **Transparence**: Expliquez clairement à l'utilisateur pourquoi une escalade ou une désescalade est suggérée.

3. **Contextualisation**: Adaptez les critères d'escalade et de désescalade au contexte spécifique de chaque mode (Code, Debug, Architect, Ask).

4. **Réévaluation continue**: Ne considérez pas la complexité comme figée; réévaluez-la à chaque étape importante.

5. **Respect des préférences utilisateur**: Si l'utilisateur préfère rester dans un mode simple malgré la complexité, utilisez l'escalade interne plutôt que d'insister sur une escalade externe.

6. **Documentation**: Documentez les décisions d'escalade et de désescalade pour améliorer les futurs processus.

7. **Optimisation des ressources**: Utilisez la gestion des tokens pour éviter d'épuiser les ressources disponibles.