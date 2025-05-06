# Roo Extensions

Ce dépôt contient des extensions pour Roo, notamment des modes personnalisés optimisés pour différents modèles de langage.

## Architecture à Deux Niveaux (Simple/Complexe)

Le projet implémente une architecture innovante qui dédouble chaque profil d'agent Roo en deux versions :

- **Version Simple** : Utilise des modèles moins coûteux (comme Claude 3.5 Sonnet) pour les tâches basiques
  - Modifications de code mineures
  - Bugs simples
  - Documentation basique
  - Questions factuelles
  - Tâches bien définies

- **Version Complexe** : Utilise des modèles plus avancés (comme Claude 3.7 Sonnet) pour les tâches nécessitant des capacités supérieures
  - Refactoring majeur
  - Conception d'architecture
  - Optimisation de performance
  - Analyses approfondies
  - Problèmes complexes

Cette approche permet d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats, en dirigeant chaque tâche vers le modèle le plus approprié selon sa complexité.

## Installation et Utilisation

### Prérequis

- Roo installé et configuré
- Accès aux modèles Claude 3.5 Sonnet et Claude 3.7 Sonnet

### Installation

1. Clonez ce dépôt :
   ```bash
   git clone https://github.com/votre-utilisateur/roo-extensions.git
   ```

2. Copiez le fichier `.roomodes` dans le répertoire approprié de votre installation Roo :
   ```bash
   cp .roomodes [chemin-vers-votre-dossier-roo-settings]
   ```

3. Redémarrez Roo pour appliquer les nouveaux modes.

### Utilisation

Les modes personnalisés apparaîtront dans l'interface de Roo et peuvent être sélectionnés comme n'importe quel autre mode.

- Pour les tâches simples, sélectionnez la version "Simple" du mode approprié
- Pour les tâches complexes, sélectionnez la version "Complexe"
- L'Orchestrateur peut également router automatiquement les tâches vers le mode approprié

## Structure du Projet

- `.roomodes` : Configuration des modes personnalisés
- `custom-modes/` : Documentation et ressources pour les modes personnalisés
- `optimized-agents/` : Architecture optimisée des agents Roo pour réduire les coûts
  - `docs/` : Documentation détaillée sur l'architecture
- `scheduler/` : Extensions et configurations pour Roo Scheduler
- `external-mcps/` : Serveurs MCP externes pour étendre les capacités de Roo
  - `git-mcp/` : Serveur MCP pour interagir avec Git
  - `github-mcp/` : Serveur MCP pour interagir avec GitHub
  - `searxng/` : Serveur MCP pour effectuer des recherches web
  - `win-cli/` : Serveur MCP pour interagir avec le système d'exploitation Windows

## MCP Servers Disponibles

| Serveur | Description | Fonctionnalités principales |
|---------|-------------|----------------------------|
| Git MCP | Interaction avec des dépôts Git locaux | Commit, push, pull, branch, status, diff, etc. |
| GitHub MCP | Interaction avec l'API GitHub | Gestion de dépôts, issues, pull requests, etc. |
| SearXNG | Recherche web via SearXNG | Recherche web, lecture de contenu d'URL |
| Win-CLI | Interaction avec Windows | Exécution de commandes, gestion SSH, etc. |

Pour utiliser ces serveurs MCP, assurez-vous qu'ils sont correctement configurés dans le fichier `mcp_settings.json` de Roo.

## Modes Disponibles

| Mode | Version Simple | Version Complexe |
|------|----------------|------------------|
| Code | Modifications mineures, bugs simples | Refactoring, architecture, optimisation |
| Debug | Erreurs de syntaxe, bugs évidents | Bugs concurrents, performance, problèmes système |
| Architect | Documentation simple, diagrammes basiques | Conception système, migrations complexes |
| Ask | Questions factuelles, explications basiques | Analyses approfondies, synthèses complexes |
| Orchestrator | Tâches simples, délégation basique | Tâches complexes, coordination avancée |

## Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité
3. Soumettez une pull request

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.