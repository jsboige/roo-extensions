# Roo Extensions

Ce dépôt contient des extensions pour Roo, notamment des modes personnalisés optimisés pour différents modèles de langage.

## Architecture à 5 Niveaux de Complexité (n5)

Le projet implémente une architecture innovante qui organise les profils d'agent Roo en cinq niveaux de complexité :

1. **MICRO** : Utilise des modèles légers pour les tâches très simples et rapides
   - Réponses courtes
   - Modifications minimes
   - Tâches très bien définies

2. **MINI** : Utilise des modèles économiques pour les tâches simples
   - Modifications de code mineures
   - Bugs simples
   - Documentation basique
   - Questions factuelles

3. **MEDIUM** : Utilise des modèles intermédiaires pour les tâches de complexité moyenne
   - Développement de fonctionnalités
   - Débogage standard
   - Documentation technique

4. **LARGE** : Utilise des modèles avancés pour les tâches complexes
   - Refactoring important
   - Conception de composants
   - Analyses détaillées

5. **ORACLE** : Utilise les modèles les plus puissants pour les tâches très complexes
   - Refactoring majeur
   - Conception d'architecture
   - Optimisation de performance
   - Analyses approfondies
   - Problèmes complexes

Cette approche permet d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats, en dirigeant chaque tâche vers le modèle le plus approprié selon sa complexité. L'architecture inclut également des mécanismes d'escalade et de désescalade pour passer d'un niveau à l'autre selon l'évolution de la complexité des tâches.

## Installation et Utilisation

### Prérequis

- Roo installé et configuré
- Accès aux modèles Claude (3 Haiku, 3.5 Sonnet, 3.7 Sonnet, 3.7 Opus) ou Qwen 3

### Installation

1. Clonez ce dépôt :
   ```bash
   git clone https://github.com/votre-utilisateur/roo-extensions.git
   ```

2. Déployez les modes avec le script approprié :
   ```bash
   # Pour l'architecture à 5 niveaux avec Claude
   cd roo-modes/n5/scripts
   ./deploy-n5-architecture.ps1
   
   # Pour l'architecture à 5 niveaux avec Qwen 3
   # (nécessite une configuration supplémentaire)
   ```

3. Redémarrez Roo pour appliquer les nouveaux modes.

### Utilisation

Les modes personnalisés apparaîtront dans l'interface de Roo et peuvent être sélectionnés comme n'importe quel autre mode.

- Pour les tâches très simples, sélectionnez un mode MICRO
- Pour les tâches simples, sélectionnez un mode MINI
- Pour les tâches standard, sélectionnez un mode MEDIUM
- Pour les tâches complexes, sélectionnez un mode LARGE
- Pour les tâches très complexes, sélectionnez un mode ORACLE
- L'Orchestrateur peut également router automatiquement les tâches vers le mode approprié

## Structure du Projet

- `.roomodes` : Configuration des modes personnalisés
- `roo-modes/` : Répertoire principal pour les modes personnalisés
  - `configs/` : Configurations des modes (architecture à 2 niveaux)
  - `docs/` : Documentation conceptuelle et guides
  - `examples/` : Exemples de configurations
  - `scripts/` : Scripts de déploiement
  - `tests/` : Tests pour les modes personnalisés
  - `n5/` : Implémentation de l'architecture à 5 niveaux de complexité
    - `configs/` : Configurations des modes pour chaque niveau
    - `scripts/` : Scripts de déploiement
    - `docs/` : Documentation et guides
    - `tests/` : Tests pour les mécanismes d'escalade et désescalade
  - `custom/` : Modes personnalisés spécifiques
  - `optimized/` : Modes optimisés pour différents modèles
- `roo-config/` : Configurations pour Roo
  - `modes/` : Configurations de modes standard
  - `settings/` : Paramètres généraux
  - `scheduler/` : Extensions et configurations pour Roo Scheduler
  - `qwen3-profiles/` : Profils optimisés pour les modèles Qwen 3
- `mcps/` : Configuration et documentation pour les MCPs externes
  - `searxng/` : MCP pour la recherche web
  - `win-cli/` : MCP pour les commandes Windows
  - `git/` : MCP pour les opérations Git
  - `github/` : MCP pour l'API GitHub
- `docs/` : Documentation générale du projet
  - Guides d'utilisation
  - Rapports de tests
  - Spécifications techniques
- `scripts/` : Scripts utilitaires pour le projet
  - Tests de scénarios
  - Utilitaires de déploiement
- `tests/` : Tests et scénarios de test
  - `mcp-structure/` : Tests pour la structure MCP
  - `mcp-win-cli/` : Tests pour le MCP Win-CLI
  - `scripts/` : Scripts de test
- `archive/` : Contenu obsolète ou archivé

## Modes Disponibles

| Mode | MICRO | MINI | MEDIUM | LARGE | ORACLE |
|------|-------|------|--------|-------|--------|
| Code | Modifications très simples | Modifications mineures | Développement standard | Refactoring important | Architecture complète |
| Debug | Erreurs évidentes | Bugs simples | Débogage standard | Bugs complexes | Problèmes système |
| Architect | Diagrammes simples | Documentation basique | Conception de composants | Conception système | Migrations complexes |
| Ask | Réponses courtes | Questions factuelles | Explications techniques | Analyses détaillées | Synthèses complexes |
| Orchestrator | Tâches unitaires | Délégation simple | Coordination standard | Coordination avancée | Orchestration complexe |

## Modèles Supportés

### Claude (par défaut)
- **MICRO** : Claude 3 Haiku
- **MINI** : Claude 3.5 Sonnet
- **MEDIUM** : Claude 3.5 Sonnet
- **LARGE** : Claude 3.7 Sonnet
- **ORACLE** : Claude 3.7 Opus

### Qwen 3 (configuration alternative)
- **MICRO** : Qwen3-0.6B
- **MINI** : Qwen3-4B
- **MEDIUM** : Qwen3-14B
- **LARGE** : Qwen3-32B ou Qwen3-30B-A3B (MoE)
- **ORACLE** : Qwen3-235B-A22B (MoE)

Pour utiliser les modèles Qwen 3, consultez la documentation dans `roo-config/qwen3-profiles/`.

## MCPs Externes Disponibles

Le projet intègre plusieurs serveurs MCP (Model Context Protocol) externes pour étendre les capacités de Roo :

- **SearXNG** : Permet d'effectuer des recherches web via différents moteurs de recherche
  - Recherche d'informations en ligne
  - Accès à des contenus web récents
  - Extraction d'informations de pages web

- **Win-CLI** : Permet d'exécuter des commandes dans différents shells Windows
  - Exécution de commandes PowerShell, CMD, Git Bash
  - Gestion des connexions SSH
  - Accès aux fonctionnalités système

- **Git** : Permet d'effectuer des opérations Git
  - Clone, commit, push, pull
  - Gestion des branches et des tags
  - Résolution de conflits

- **GitHub** : Permet d'interagir avec l'API GitHub
  - Gestion des issues et pull requests
  - Accès aux informations des dépôts
  - Gestion des workflows

Pour plus d'informations sur l'utilisation des MCPs, consultez le répertoire `mcps/` et le document `docs/guide-utilisation-mcps.md`.

## Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité
3. Soumettez une pull request

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.