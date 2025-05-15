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
   - Refactoring modéré
   - Analyse de code
   - Explications techniques

4. **LARGE** : Utilise des modèles avancés pour les tâches complexes
   - Architecture de systèmes
   - Refactoring majeur
   - Optimisation de performance
   - Analyses détaillées

5. **ORACLE** : Utilise les modèles les plus puissants pour les tâches très complexes
   - Conception de systèmes distribués
   - Optimisation avancée
   - Synthèse de recherche
   - Analyses multi-domaines

Cette approche permet d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats.

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

## Utilisation

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

## Documentation

Le projet dispose d'une documentation détaillée répartie dans plusieurs fichiers README spécialisés :

- [**roo-modes/n5/tests/README.md**](roo-modes/n5/tests/README.md) : Documentation complète des tests de l'architecture d'orchestration à 5 niveaux, incluant les mécanismes d'escalade et de désescalade, les objectifs des tests, leur structure et fonctionnement, ainsi que des instructions pour exécuter et interpréter les résultats des tests.

- [**roo-modes/scripts/README.md**](roo-modes/scripts/README.md) : Documentation des scripts de gestion des modes Roo, couvrant les scripts de déploiement, le système de verrouillage de famille, et les outils de validation et mise à jour des modes. Inclut des exemples d'utilisation et les bonnes pratiques.

- [**mcps/scripts/README.md**](mcps/scripts/README.md) : Documentation des scripts pour les serveurs MCP, détaillant les scripts de lancement, de test et d'installation pour les différents serveurs MCP (QuickFiles, JinaNavigator, Jupyter). Inclut des exemples d'utilisation et des conseils de dépannage.

- [**roo-config/README.md**](roo-config/README.md) : Documentation améliorée de la configuration Roo, centralisant toutes les informations sur les paramètres, modes et fonctionnalités avancées. Inclut des instructions détaillées pour l'utilisation des scripts de déploiement et les bonnes pratiques pour modifier les configurations.

Consultez ces fichiers pour obtenir des informations détaillées sur les différents aspects du projet.

## Modes Disponibles

| Type | MICRO | MINI | MEDIUM | LARGE | ORACLE |
|------|-------|------|--------|-------|--------|
| Code | Modifications minimes | Bugs simples | Développement de fonctionnalités | Refactoring majeur | Conception de systèmes |
| Debug | Erreurs simples | Bugs isolés | Problèmes modérés | Bugs complexes | Problèmes systémiques |
| Architect | Suggestions rapides | Conseils simples | Conception de modules | Architecture de systèmes | Conception distribuée |
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

- **SearXNG** : Permet d'effectuer des recherches web
  - Recherche multi-moteurs
  - Filtrage par date et type de contenu
  - Extraction de contenu web

- **Win-CLI** : Permet d'exécuter des commandes système
  - Exécution de commandes PowerShell, CMD et Git Bash
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

Les contributions sont les bienvenues ! Voici comment contribuer :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/amazing-feature`)
3. Committez vos changements (`git commit -m 'Add some amazing feature'`)
4. Poussez vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrez une Pull Request

## Note sur l'encodage des fichiers

**Attention** : Certains fichiers de configuration (notamment `.roomodes`, `new-roomodes.json` et `vscode-custom-modes.json`) présentent des problèmes d'encodage des caractères spéciaux. Si vous rencontrez des problèmes avec ces fichiers, vous devrez peut-être les recréer manuellement en utilisant un éditeur qui prend en charge l'encodage UTF-8 sans BOM.

## Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.