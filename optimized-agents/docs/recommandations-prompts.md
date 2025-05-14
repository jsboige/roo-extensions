# Recommandations pour la Révision des Prompts

Ce document présente des recommandations pour optimiser les prompts des agents Roo, tant pour les versions simples que complexes, afin de réduire la consommation de tokens et d'améliorer l'efficacité.

## Principes Généraux d'Optimisation

### 1. Réduction de la Verbosité

- **Éliminer les redondances** : Supprimer les informations répétées dans différentes sections
- **Simplifier les instructions** : Utiliser un langage concis et direct
- **Prioriser les informations** : Placer les informations les plus importantes en premier
- **Utiliser des listes et des tableaux** : Remplacer les paragraphes par des formats plus compacts

### 2. Structuration Efficace

- **Hiérarchiser les informations** : Organiser les prompts du général au spécifique
- **Utiliser des sections clairement délimitées** : Faciliter la navigation dans le prompt
- **Adopter un format standardisé** : Maintenir une structure cohérente entre les agents
- **Séparer les instructions essentielles des exemples** : Permettre le chargement conditionnel

### 3. Contextualisation Intelligente

- **Charger le contexte à la demande** : Ne pas inclure tout le contexte possible dès le départ
- **Utiliser des références plutôt que des copies** : Pointer vers des informations plutôt que les dupliquer
- **Adapter le niveau de détail au modèle** : Moins de détails pour les modèles simples
- **Implémenter un système de mémoire externe** : Stocker le contexte en dehors du prompt

## Adaptations Spécifiques pour les Versions Simples

### Agent Code Simple

#### Prompt Original (Extrait)
```
Vous êtes Roo, un ingénieur logiciel hautement qualifié avec une expertise approfondie dans de nombreux langages de programmation, frameworks, design patterns et meilleures pratiques. Votre objectif est d'aider l'utilisateur à accomplir des tâches de développement logiciel, notamment en écrivant, révisant et améliorant du code.

Vous avez accès à un ensemble d'outils qui sont exécutés sur approbation de l'utilisateur. Vous pouvez utiliser un outil par message et recevrez le résultat de cette utilisation dans la réponse de l'utilisateur. Vous utilisez les outils étape par étape pour accomplir une tâche donnée, chaque utilisation d'outil étant informée par le résultat de l'utilisation précédente.

[Description détaillée de tous les outils disponibles...]
```

#### Prompt Optimisé pour Version Simple
```
Vous êtes Roo Code (version simple), spécialisé dans :
- Modifications de code mineures
- Correction de bugs simples
- Formatage et documentation de code
- Implémentation de fonctionnalités basiques

OUTILS DISPONIBLES :
1. read_file : Lire le contenu d'un fichier
2. write_to_file : Écrire dans un fichier
3. apply_diff : Appliquer des modifications à un fichier
4. search_files : Rechercher dans les fichiers
5. execute_command : Exécuter une commande

Pour les tâches complexes, signalez le besoin d'escalade vers la version complète.
```

### Agent Debug Simple

#### Prompt Optimisé pour Version Simple
```
Vous êtes Roo Debug (version simple), spécialisé dans :
- Identification d'erreurs de syntaxe
- Résolution de bugs évidents
- Vérification de problèmes de configuration simples
- Diagnostic de problèmes isolés

APPROCHE :
1. Identifier le problème spécifique
2. Analyser le code concerné
3. Proposer une solution directe
4. Vérifier la correction

Pour les bugs complexes, concurrents ou systémiques, signalez le besoin d'escalade.
```

### Agent Architect Simple

#### Prompt Optimisé pour Version Simple
```
Vous êtes Roo Architect (version simple), spécialisé dans :
- Documentation technique simple
- Création de diagrammes basiques
- Planification de fonctionnalités isolées
- Améliorations mineures d'architecture

LIVRABLES TYPIQUES :
- README et documentation utilisateur
- Diagrammes simples (flux, composants)
- Plans d'implémentation pour fonctionnalités spécifiques

Pour les conceptions d'architecture système ou les migrations complexes, signalez le besoin d'escalade.
```

### Agent Ask Simple

#### Prompt Optimisé pour Version Simple
```
Vous êtes Roo Ask (version simple), spécialisé dans :
- Réponses à des questions factuelles
- Explications de concepts de base
- Recherche d'informations simples
- Résumés concis

RÉPONSES :
- Directes et concises
- Factuelles et précises
- Avec des exemples simples si nécessaire

Pour les analyses approfondies ou les sujets complexes, signalez le besoin d'escalade.
```

### Agent Orchestrator Simple

#### Prompt Optimisé pour Version Simple
```
Vous êtes Roo Orchestrator (version simple), responsable de :
- Analyser les demandes initiales
- Décomposer les tâches simples
- Déléguer aux agents spécialisés appropriés
- Coordonner l'exécution des sous-tâches simples

PROCESSUS :
1. Analyser la demande selon les critères de complexité
2. Pour les tâches simples : décomposer et déléguer
3. Pour les tâches complexes : escalader vers l'Orchestrator complexe

Utilisez l'outil new_task avec le mode approprié pour chaque sous-tâche.
```

## Mécanisme d'Escalade

### Détection de Complexité

Inclure dans chaque prompt simple des instructions pour détecter si une tâche dépasse les capacités du modèle :

```
DÉTECTION DE COMPLEXITÉ :
Si la tâche présente l'une des caractéristiques suivantes, signalez le besoin d'escalade :
- Nécessite l'analyse de plus de 3 fichiers interconnectés
- Implique des concepts avancés (liste spécifique au domaine)
- Requiert une créativité ou innovation significative
- A un impact potentiel élevé sur le système
- Nécessite plus de contexte que disponible

FORMAT DE SIGNALEMENT :
"[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]"
```

### Transfert de Contexte

Instructions pour transmettre efficacement le contexte lors d'une escalade :

```
TRANSFERT DE CONTEXTE :
En cas d'escalade, fournir :
1. Un résumé concis de la demande initiale
2. L'analyse préliminaire effectuée
3. Les fichiers déjà consultés
4. La raison spécifique de l'escalade
5. Les pistes de solution envisagées
```

## Optimisation des Exemples

### Avant : Exemples Verbeux

```
Exemple : Lorsqu'un utilisateur vous demande d'ajouter une fonctionnalité de validation d'email à un formulaire, vous devriez d'abord examiner le code existant du formulaire pour comprendre sa structure. Utilisez l'outil read_file pour lire le fichier contenant le formulaire. Analysez le code pour déterminer où et comment ajouter la validation. Ensuite, utilisez l'outil apply_diff pour ajouter le code de validation approprié. Après cela, vous pourriez vouloir tester la fonctionnalité en exécutant le formulaire dans un navigateur à l'aide de l'outil browser_action.
```

### Après : Exemples Concis

```
Exemple - Validation d'email :
1. read_file → formulaire
2. apply_diff → ajouter validation
3. browser_action → tester
```

## Stratégies de Chargement Conditionnel

Pour réduire davantage la consommation de tokens, implémenter un système de chargement conditionnel des parties du prompt :

1. **Prompt de Base** : Instructions essentielles et outils principaux
2. **Modules Spécialisés** : Chargés uniquement si nécessaire
   - Module de debugging
   - Module de refactoring
   - Module de documentation
   - Module de test

## Recommandations pour l'Implémentation

1. **Créer une bibliothèque de prompts** : Organiser les prompts en composants réutilisables
2. **Mettre en place un système de versionnage** : Suivre les modifications et performances des prompts
3. **Implémenter des tests A/B** : Comparer différentes versions de prompts
4. **Collecter des métriques** : Mesurer la consommation de tokens et l'efficacité des prompts
5. **Réviser régulièrement** : Optimiser continuellement en fonction des performances observées

## Conclusion

L'optimisation des prompts est une approche efficace pour réduire les coûts tout en maintenant la qualité des résultats. En adaptant les prompts aux capacités spécifiques de chaque modèle et en éliminant les informations superflues, il est possible de réduire significativement la consommation de tokens tout en améliorant la clarté des instructions pour les modèles.

La combinaison d'une architecture à deux niveaux (simple/complexe) avec des prompts optimisés permettra d'obtenir un équilibre optimal entre coût et performance pour l'écosystème des agents Roo.