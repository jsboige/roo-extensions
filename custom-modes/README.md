# Architecture des Modes Personnalisés Roo

Ce projet vise à concevoir une architecture optimisée pour les modes personnalisés Roo qui améliore l'efficacité tout en optimisant les coûts sans perdre en qualité.

## Contexte

Actuellement, tous les agents Roo (orchestrator, code, debug, architect, ask) utilisent Claude Sonnet, un modèle performant mais coûteux. L'objectif est d'utiliser des modèles locaux ou moins coûteux pour certaines tâches ou sous-tâches, tout en conservant Claude Sonnet pour les tâches complexes nécessitant ses capacités avancées.

## Architecture à Deux Niveaux (Simple/Complexe)

L'architecture à deux niveaux dédouble chaque profil d'agent en versions "simple" et "complexe" pour optimiser les coûts tout en maintenant la qualité des résultats.

### Modes Simples

Les modes simples sont conçus pour traiter des tâches basiques et bien définies :

- Utilisent des modèles moins coûteux (Claude 3.5 Sonnet)
- Se concentrent sur des tâches spécifiques et isolées
- Ont des instructions optimisées pour réduire la consommation de tokens
- Incluent un mécanisme d'escalade pour les tâches dépassant leurs capacités

### Modes Complexes

Les modes complexes sont conçus pour traiter des tâches avancées et complexes :

- Utilisent des modèles plus puissants (Claude 3.7 Sonnet)
- Peuvent gérer des tâches nécessitant une compréhension approfondie
- Ont accès à plus de contexte et de capacités
- Peuvent décomposer des tâches complexes en sous-tâches

### Mécanisme d'Escalade

Le mécanisme d'escalade permet aux modes simples de transférer une tâche à leur équivalent complexe lorsqu'ils détectent qu'elle dépasse leurs capacités :

1. L'agent simple analyse la demande selon des critères de complexité
2. S'il détecte que la tâche est trop complexe, il signale le besoin d'escalade
3. L'utilisateur peut alors basculer vers le mode complexe correspondant
4. L'agent complexe reprend la tâche avec le contexte déjà établi

Format de signalement d'escalade :
```
[ESCALADE REQUISE] Cette tâche nécessite la version complexe de l'agent car : [RAISON]
```

## Exemples de Tâches par Niveau de Complexité

### Agent Code
- **Simple** : Modifications < 50 lignes, bugs simples, formatage
- **Complexe** : Refactoring majeur, conception d'architecture, optimisation

### Agent Debug
- **Simple** : Erreurs de syntaxe, bugs évidents, problèmes isolés
- **Complexe** : Bugs concurrents, problèmes de performance, bugs système

### Agent Architect
- **Simple** : Documentation simple, diagrammes basiques, améliorations mineures
- **Complexe** : Conception système, migration complexe, optimisation d'architecture

### Agent Ask
- **Simple** : Questions factuelles, explications basiques, résumés concis
- **Complexe** : Analyses approfondies, comparaisons détaillées, synthèses complexes

### Agent Orchestrator
- **Simple** : Décomposition de tâches simples, délégation basique
- **Complexe** : Coordination de tâches interdépendantes, stratégies avancées

## Structure de la Documentation

Pour plus d'informations sur l'architecture et l'implémentation des modes personnalisés, consultez les documents suivants :

- [Structure Technique](./docs/structure-technique/README.md) - Détails techniques sur la structure des modes personnalisés
- [Architecture](./docs/architecture/) - Conception architecturale des modes personnalisés
- [Critères de Décision](./docs/criteres-decision/) - Critères pour le routage des tâches
- [Optimisation](./docs/optimisation/) - Recommandations pour l'optimisation des prompts
- [Implémentation](./docs/implementation/) - Stratégie d'implémentation progressive
- [Utilisation MCP Win-CLI](./docs/utilisation-mcp-win-cli.md) - Guide d'utilisation du MCP Win-CLI dans les modes personnalisés

## Intégration avec les MCP Servers

Les modes personnalisés peuvent tirer parti des serveurs MCP (Model Context Protocol) pour étendre leurs capacités. Ces serveurs fournissent des outils et des ressources supplémentaires qui peuvent être utilisés par les agents Roo.

### MCP Win-CLI

Le serveur MCP Win-CLI est particulièrement utile pour les modes personnalisés, car il permet d'exécuter des commandes dans différents shells Windows et d'accéder à des ressources système. Pour plus d'informations sur son utilisation dans les modes personnalisés, consultez le [guide d'utilisation du MCP Win-CLI](./docs/utilisation-mcp-win-cli.md).

## Ressources Additionnelles

- [Templates](./templates/) - Modèles pour créer de nouveaux modes personnalisés
- [Examples](./examples/) - Exemples de modes personnalisés
- [Documentation MCP Win-CLI](../external-mcps/win-cli/) - Documentation complète du serveur MCP Win-CLI