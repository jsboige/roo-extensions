# Roo Extensions

Ce dépôt contient des extensions pour Roo, notamment des modes personnalisés optimisés pour différents modèles de langage via un système de profils.

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

Cette approche permet d'optimiser les coûts d'utilisation tout en maintenant la qualité des résultats. Grâce au système de profils, il est possible de configurer facilement quels modèles utiliser pour chaque niveau de complexité.

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
   # Pour l'architecture à 5 niveaux avec le profil Claude standard
   cd roo-config
   ./deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType global
   
   # Pour l'architecture à 5 niveaux avec le profil n5
   cd roo-config
   ./deploy-profile-modes.ps1 -ProfileName "n5" -DeploymentType global
   
   # Pour l'architecture à 5 niveaux avec le profil Qwen 3
   cd roo-config
   ./deploy-profile-modes.ps1 -ProfileName "qwen" -DeploymentType global
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

> **Note**: Le dépôt a été récemment réorganisé pour améliorer la maintenabilité et la cohérence de la structure. Cette section reflète la nouvelle organisation du dépôt.

```
roo-extensions/
├── docs/                           # Documentation générale du projet
│   ├── architecture/               # Documentation sur l'architecture
│   ├── guides/                     # Guides d'utilisation
│   ├── rapports/                   # Rapports d'analyse et de synthèse
│   └── tests/                      # Documentation des tests
│
├── modules/                        # Modules autonomes
│   ├── form-validator/             # Module de validation de formulaire
│   └── [autres modules futurs]
│
├── mcps/                           # Serveurs MCP (Model Context Protocol)
│   ├── internal/                   # MCPs développés en interne (sous-module jsboige-mcp-servers)
│   │   ├── quickfiles/             # MCP pour opérations sur fichiers multiples
│   │   ├── jinavigator/            # MCP pour conversion web vers Markdown
│   │   └── jupyter/                # MCP pour notebooks Jupyter
│   ├── external/                   # MCPs externes
│   │   ├── searxng/                # MCP pour recherche web
│   │   ├── win-cli/                # MCP pour exécution de commandes Windows
│   │   ├── filesystem/             # MCP pour opérations sur le système de fichiers
│   │   ├── git/                    # MCP pour opérations Git
│   │   └── github/                 # MCP pour API GitHub
│   ├── monitoring/                 # Système de surveillance des MCPs
│   └── scripts/                    # Scripts liés aux MCPs
│
├── roo-code/                       # Code source principal de Roo
│   ├── assets/
│   ├── docs/
│   └── src/
│
├── roo-config/                     # Configuration de Roo
│   ├── backups/                    # Sauvegardes des configurations
│   ├── config-templates/           # Modèles de configuration
│   ├── diagnostic-scripts/         # Scripts de diagnostic
│   ├── modes/                      # Configurations des modes
│   ├── qwen3-profiles/             # Profils pour Qwen3
│   ├── scheduler/                  # Configuration du planificateur
│   └── settings/                   # Paramètres généraux
│
├── roo-modes/                      # Modes personnalisés
│   ├── docs/                       # Documentation des modes
│   ├── examples/                   # Exemples de configurations
│   ├── n5/                         # Architecture à 5 niveaux
│   │   ├── configs/
│   │   ├── docs/
│   │   └── tests/
│   └── optimized/                  # Modes optimisés
│
├── scripts/                        # Scripts utilitaires
│   ├── deployment/                 # Scripts de déploiement
│   ├── maintenance/                # Scripts de maintenance
│   └── migration/                  # Scripts de migration
│
├── tests/                          # Tests du projet
│   ├── data/                       # Données de test
│   ├── escalation/                 # Tests d'escalade
│   ├── mcp/                        # Tests des MCPs
│   ├── results/                    # Résultats des tests
│   └── scripts/                    # Scripts de test
│
└── archive/                        # Contenu archivé
    └── legacy/                     # Ancien code conservé pour référence
```

## Documentation

Le projet dispose d'une documentation détaillée répartie dans plusieurs fichiers README spécialisés :

- [**roo-modes/n5/tests/README.md**](roo-modes/n5/tests/README.md) : Documentation complète des tests de l'architecture d'orchestration à 5 niveaux, incluant les mécanismes d'escalade et de désescalade, les objectifs des tests, leur structure et fonctionnement, ainsi que des instructions pour exécuter et interpréter les résultats des tests.

- [**tests/README.md**](tests/README.md) : Documentation des tests du projet, incluant les tests de structure MCP, les tests des serveurs MCP spécifiques, les tests d'encodage, et les tests d'escalade et désescalade.

- [**mcps/external/README.md**](mcps/external/README.md) : Documentation des MCPs externes, incluant les instructions d'installation, de configuration et d'utilisation, ainsi que la résolution des problèmes courants.

- [**modules/form-validator/README.md**](modules/form-validator/README.md) : Documentation du module de validation de formulaire, incluant les fonctionnalités, l'installation, l'utilisation et les formats supportés.

- [**roo-config/README.md**](roo-config/README.md) : Documentation améliorée de la configuration Roo, centralisant toutes les informations sur les paramètres, modes et fonctionnalités avancées. Inclut des instructions détaillées pour l'utilisation des scripts de déploiement et les bonnes pratiques pour modifier les configurations.

- [**roo-config/README-profile-modes.md**](roo-config/README-profile-modes.md) : Documentation du système de profils pour les modes personnalisés, expliquant comment créer, gérer et déployer des configurations de modes basées sur des profils.

- [**docs/guide-utilisation-profils-modes.md**](docs/guide-utilisation-profils-modes.md) : Guide complet sur l'utilisation des profils dans le système de modes personnalisés, incluant l'architecture, les avantages, des exemples d'utilisation et la migration depuis l'ancienne architecture.

- [**tests/escalation/rapport-tests-escalade.md**](tests/escalation/rapport-tests-escalade.md) : Rapport d'analyse des tests d'escalade, incluant les résultats des tests et les recommandations.

Consultez ces fichiers pour obtenir des informations détaillées sur les différents aspects du projet.

## Modes Disponibles

| Type | MICRO | MINI | MEDIUM | LARGE | ORACLE |
|------|-------|------|--------|-------|--------|
| Code | Modifications minimes | Bugs simples | Développement de fonctionnalités | Refactoring majeur | Conception de systèmes |
| Debug | Erreurs simples | Bugs isolés | Problèmes modérés | Bugs complexes | Problèmes systémiques |
| Architect | Suggestions rapides | Conseils simples | Conception de modules | Architecture de systèmes | Conception distribuée |
| Ask | Réponses courtes | Questions factuelles | Explications techniques | Analyses détaillées | Synthèses complexes |
| Orchestrator | Tâches unitaires | Délégation simple | Coordination standard | Coordination avancée | Orchestration complexe |

## Profils et Modèles Supportés

Le système utilise des profils pour définir quels modèles de langage utiliser pour chaque mode. Voici les profils disponibles par défaut:

### Profil "standard"
- Modèle par défaut: Claude 3.5 Sonnet
- Modes complexes: Claude 3.7 Sonnet

### Profil "n5" (architecture à 5 niveaux)
- **MICRO** : Claude 3 Haiku
- **MINI** : Claude 3.5 Sonnet
- **MEDIUM** : Claude 3.5 Sonnet
- **LARGE** : Claude 3.7 Sonnet
- **ORACLE** : Claude 3.7 Opus

### Profil "qwen" (modèles Qwen 3)
- Modèle par défaut: Qwen3-32B (local/qwq32b)
- Modes complexes: Claude 3.7 Sonnet

### Profil "local" (modèles locaux)
- Modèle par défaut: Llama 3 70B (local/llama-3-70b)
- Modes complexes: Claude 3.7 Sonnet

Pour créer ou modifier des profils, utilisez le script `create-profile.ps1`. Pour plus d'informations, consultez la documentation dans `docs/guide-utilisation-profils-modes.md`.

## MCPs Disponibles

Le projet intègre plusieurs serveurs MCP (Model Context Protocol) pour étendre les capacités de Roo :

### MCPs Internes (sous-module jsboige-mcp-servers)

Ces serveurs MCP sont développés en interne dans le cadre de ce projet et sont disponibles dans le répertoire `mcps/internal/` :

- **QuickFiles** : Permet des opérations avancées sur les fichiers
  - Lecture et écriture de fichiers multiples
  - Listage de répertoires avec options avancées
  - Recherche et remplacement dans les fichiers
  - Extraction de structure Markdown

- **JinaNavigator** : Permet la conversion de pages web en Markdown
  - Conversion de pages web en Markdown
  - Extraction de plans hiérarchiques
  - Accès aux ressources web via URI

- **Jupyter** : Permet l'interaction avec des notebooks Jupyter
  - Création, lecture et modification de notebooks
  - Exécution de cellules de code
  - Gestion des kernels

### MCPs Externes

Ces serveurs MCP sont développés par d'autres équipes et sont disponibles dans le répertoire `mcps/external/` :

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

- **Filesystem** : Permet des opérations sur le système de fichiers
  - Lecture et écriture de fichiers
  - Manipulation de répertoires
  - Recherche de fichiers

Pour plus d'informations sur l'utilisation des MCPs, consultez les répertoires `mcps/internal/` et `mcps/external/` ainsi que le document `docs/guide-utilisation-mcps.md`.

## Démo d'initiation à Roo

Le dépôt inclut une démo d'initiation complète à Roo, conçue pour faciliter la découverte et l'apprentissage des fonctionnalités de l'assistant intelligent. Cette démo structurée permet aux utilisateurs de tous niveaux d'explorer progressivement les capacités de Roo.

### Contenu de la démo

La démo est organisée en 5 répertoires thématiques :

1. **01-decouverte** : Introduction aux fonctionnalités de base
   - Premiers pas avec Roo
   - Utilisation des capacités de vision
   - Interaction conversationnelle

2. **02-orchestration-taches** : Gestion de projets et organisation de tâches
   - Planification de projets
   - Recherche web
   - Gestion de fichiers

3. **03-assistant-pro** : Utilisation de Roo dans un contexte professionnel
   - Analyse de données
   - Création de présentations
   - Communication professionnelle

4. **04-creation-contenu** : Création de documents, sites web et contenus multimédias
   - Création de sites web
   - Contenu pour réseaux sociaux
   - Documents et rapports

5. **05-projets-avances** : Cas d'usage avancés et intégrations complexes
   - Architecture de systèmes
   - Intégration d'outils
   - Développement avancé

### Démarrage rapide

1. Préparez les espaces de travail avec le script fourni :
   ```powershell
   # Depuis la racine du dépôt
   .\scripts\demo-scripts\prepare-workspaces.ps1
   ```

2. Naviguez vers une démo spécifique (ex: `demo-roo-code/01-decouverte/demo-1-conversation/workspace`)

3. Suivez les instructions du README.md de la démo

4. Pour nettoyer les espaces de travail après utilisation :
   ```powershell
   # Depuis la racine du dépôt
   .\scripts\demo-scripts\clean-workspaces.ps1
   ```

### Parcours recommandés

La démo propose des parcours adaptés à différents profils d'utilisateurs :

- **Pour les débutants** : Découverte progressive des fonctionnalités de base
- **Pour les professionnels** : Cas d'usage orientés productivité et analyse
- **Pour les créatifs** : Création de contenu et design

### Documentation détaillée

Pour une documentation complète sur l'utilisation de la démo, consultez :

- [Guide d'introduction à la démo](docs/guides/demo-guide.md) : Présentation détaillée de la structure et des parcours
- [Guide d'installation complet](docs/guides/installation-complete.md) : Instructions unifiées pour l'installation et la configuration

## Contribution

Les contributions sont les bienvenues ! Voici comment contribuer :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/amazing-feature`)
3. Committez vos changements (`git commit -m 'Add some amazing feature'`)
4. Poussez vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrez une Pull Request

## Note sur l'encodage des fichiers

**Attention** : Certains fichiers de configuration (notamment `.roomodes`, `new-roomodes.json` et `vscode-custom-modes.json`) présentent des problèmes d'encodage des caractères spéciaux. Si vous rencontrez des problèmes avec ces fichiers, vous devrez peut-être les recréer manuellement en utilisant un éditeur qui prend en charge l'encodage UTF-8 sans BOM.

## Migration vers le système de profils

Si vous utilisez encore l'ancienne architecture (association directe des modes aux modèles), vous pouvez migrer vers le nouveau système basé sur les profils en utilisant le script `migrate-to-profiles.ps1` :

```powershell
# Migrer une configuration existante vers un profil
.\migrate-to-profiles.ps1 -ConfigFile "roo-modes/configs/standard-modes.json" -OutputProfileName "migré"
```

Ce script analysera votre configuration existante, extraira les modèles utilisés par chaque mode, créera un nouveau profil avec ces informations et sauvegardera l'ancienne configuration.

## Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.