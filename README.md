# Roo Extensions

## Table des matières

1. [À propos du projet](#à-propos-du-projet)
2. [Fonctionnalités principales](#fonctionnalités-principales)
3. [Architectures disponibles](#architectures-disponibles)
   - [Architecture à 2 niveaux (Simple/Complexe)](#architecture-à-2-niveaux-simplecomplex)
   - [Architecture à 5 niveaux (n5)](#architecture-à-5-niveaux-n5)
4. [Prérequis](#prérequis)
5. [Installation](#installation)
6. [Utilisation](#utilisation)
7. [Structure du projet](#structure-du-projet)
8. [Modes disponibles](#modes-disponibles)
9. [Profils et modèles supportés](#profils-et-modèles-supportés)
10. [MCPs disponibles](#mcps-disponibles)
11. [Démo d'initiation à Roo](#démo-dinitiation-à-roo)
12. [Documentation](#documentation)
13. [Contribution](#contribution)
14. [Note sur l'encodage des fichiers](#note-sur-lencodage-des-fichiers)
15. [Migration vers le système de profils](#migration-vers-le-système-de-profils)
16. [Licence](#licence)

## À propos du projet

Roo Extensions est un projet qui étend les capacités de Roo, un assistant de développement intelligent pour VS Code. Ce dépôt contient des extensions pour Roo, notamment des modes personnalisés optimisés pour différents modèles de langage via un système de profils, ainsi que des serveurs MCP (Model Context Protocol) pour étendre les fonctionnalités de base.

### Qu'est-ce que Roo ?

Roo est une extension VS Code qui fonctionne comme un agent de codage autonome alimenté par l'IA. Elle permet aux utilisateurs de communiquer en langage naturel, de lire et écrire des fichiers, d'exécuter des commandes dans le terminal, d'automatiser des actions de navigateur, et de s'intégrer avec des API/modèles d'IA.

## Fonctionnalités principales

- **Modes personnalisés** : Configurations spécifiques qui définissent le comportement, les capacités et les limitations d'un agent Roo.
- **Système de profils** : Permet de configurer facilement quels modèles utiliser pour chaque niveau de complexité.
- **Serveurs MCP** : Étendent les capacités de Roo avec des fonctionnalités supplémentaires.
- **Outils de configuration** : Scripts pour déployer les modes Roo et résoudre les problèmes d'encodage.
- **Tests automatisés** : Validation des fonctionnalités et des performances.
- **Démo d'initiation** : Exemples structurés pour faciliter l'apprentissage de Roo.

## Architectures disponibles

Le projet propose deux architectures principales pour les modes Roo :

### Architecture à 2 niveaux (Simple/Complex)

Cette architecture, actuellement en production, organise les modes en deux catégories distinctes :

1. **Modes Simples** : Pour les tâches courantes et de complexité modérée
   - Modèle envisagé : Qwen 3 32B
   - Optimisé pour un équilibre entre performance et coût

2. **Modes Complexes** : Pour les tâches avancées nécessitant plus de puissance
   - Modèles : Claude 3.7 Sonnet et équivalents
   - Optimisé pour les tâches complexes et les projets de grande envergure

Cette architecture est pleinement fonctionnelle et constitue **la solution recommandée pour le déploiement**. Les configurations sont gérées dans le répertoire `roo-modes/optimized` et déployées via les scripts du répertoire `roo-config/settings`.

### Architecture à 5 niveaux (n5)

L'architecture à 5 niveaux (n5) est une approche expérimentale qui organise les profils d'agent Roo en cinq niveaux de complexité : MICRO, MINI, MEDIUM, LARGE et ORACLE. Cette architecture est conçue pour optimiser les coûts d'utilisation en adaptant le modèle utilisé à la complexité de la tâche.

Les configurations pour cette architecture sont disponibles dans le répertoire `roo-modes/n5/configs`, mais cette approche reste en phase de test et n'est pas recommandée pour un déploiement en production.

## Prérequis

- Roo installé et configuré
- Accès aux modèles Claude (3 Haiku, 3.5 Sonnet, 3.7 Sonnet, 3.7 Opus) ou Qwen 3

## Installation

1. Clonez ce dépôt :
   ```bash
   git clone https://github.com/votre-utilisateur/roo-extensions.git
   ```

2. Déployez les modes avec le script approprié :
   ```bash
   # Pour l'architecture à 2 niveaux (recommandée)
   cd roo-config
   ./deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType global
   
   # Pour l'architecture à 2 niveaux avec le profil Qwen 3
   cd roo-config
   ./deploy-profile-modes.ps1 -ProfileName "qwen" -DeploymentType global
   
   # Pour l'architecture à 5 niveaux (expérimentale, non recommandée)
   cd roo-config
   ./deploy-profile-modes.ps1 -ProfileName "n5" -DeploymentType global
   ```

3. Redémarrez Roo pour appliquer les nouveaux modes.

## Utilisation

Les modes personnalisés apparaîtront dans l'interface de Roo et peuvent être sélectionnés comme n'importe quel autre mode.

### Architecture à 2 niveaux (recommandée)

- Pour les tâches courantes et de complexité modérée, sélectionnez un mode Simple
- Pour les tâches avancées nécessitant plus de puissance, sélectionnez un mode Complex

### Architecture à 5 niveaux (expérimentale)

Si vous avez déployé l'architecture expérimentale à 5 niveaux :

- Pour les tâches très simples, sélectionnez un mode MICRO
- Pour les tâches simples, sélectionnez un mode MINI
- Pour les tâches standard, sélectionnez un mode MEDIUM
- Pour les tâches complexes, sélectionnez un mode LARGE
- Pour les tâches très complexes, sélectionnez un mode ORACLE
- L'Orchestrateur peut également router automatiquement les tâches vers le mode approprié

## Structure du projet

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

- [**roo-modes/README.md**](roo-modes/README.md) : Documentation des modes personnalisés, incluant les architectures disponibles, les types de modes, et les mécanismes d'escalade et de désescalade.

- [**roo-modes/n5/tests/README.md**](roo-modes/n5/tests/README.md) : Documentation complète des tests de l'architecture d'orchestration à 5 niveaux, incluant les mécanismes d'escalade et de désescalade, les objectifs des tests, leur structure et fonctionnement, ainsi que des instructions pour exécuter et interpréter les résultats des tests.

- [**tests/README.md**](tests/README.md) : Documentation des tests du projet, incluant les tests de structure MCP, les tests des serveurs MCP spécifiques, les tests d'encodage, et les tests d'escalade et désescalade.

- [**mcps/README.md**](mcps/README.md) : Documentation des serveurs MCP, incluant l'organisation, la configuration et les liens vers la documentation spécifique de chaque serveur.

- [**roo-code/README.md**](roo-code/README.md) : Documentation du sous-module roo-code, incluant la structure du projet, les composants principaux, les flux de travail et interactions, et les dépendances et technologies.

- [**roo-config/README.md**](roo-config/README.md) : Documentation améliorée de la configuration Roo, centralisant toutes les informations sur les paramètres, modes et fonctionnalités avancées. Inclut des instructions détaillées pour l'utilisation des scripts de déploiement et les bonnes pratiques pour modifier les configurations.

- [**roo-config/README-profile-modes.md**](roo-config/README-profile-modes.md) : Documentation du système de profils pour les modes personnalisés, expliquant comment créer, gérer et déployer des configurations de modes basées sur des profils.

- [**tests/escalation/rapport-tests-escalade.md**](tests/escalation/rapport-tests-escalade.md) : Rapport d'analyse des tests d'escalade, incluant les résultats des tests et les recommandations.

Consultez ces fichiers pour obtenir des informations détaillées sur les différents aspects du projet.

## Modes disponibles

### Architecture à 2 niveaux (recommandée)

L'architecture actuellement déployée comprend deux types de modes :
- **Modes Simples** : Pour les tâches courantes et de complexité modérée
- **Modes Complexes** : Pour les tâches avancées nécessitant plus de puissance

### Architecture à 5 niveaux (expérimentale)

Le tableau ci-dessous présente les capacités théoriques des différents niveaux de l'architecture expérimentale à 5 niveaux :

| Type | MICRO | MINI | MEDIUM | LARGE | ORACLE |
|------|-------|------|--------|-------|--------|
| Code | Modifications minimes | Bugs simples | Développement de fonctionnalités | Refactoring majeur | Conception de systèmes |
| Debug | Erreurs simples | Bugs isolés | Problèmes modérés | Bugs complexes | Problèmes systémiques |
| Architect | Suggestions rapides | Conseils simples | Conception de modules | Architecture de systèmes | Conception distribuée |
| Ask | Réponses courtes | Questions factuelles | Explications techniques | Analyses détaillées | Synthèses complexes |
| Orchestrator | Tâches unitaires | Délégation simple | Coordination standard | Coordination avancée | Orchestration complexe |

## Profils et modèles supportés

Le système utilise des profils pour définir quels modèles de langage utiliser pour chaque mode. Voici les profils disponibles par défaut:

### Profil "standard" (architecture à 2 niveaux)
- Modes simples: Qwen 3 32B
- Modes complexes: Claude 3.7 Sonnet

### Profil "n5" (architecture à 5 niveaux - expérimental)
Les modèles suivants sont envisagés pour cette architecture mais restent à tester :
- **ORACLE** : Claude Sonnet 3.7, Gemini 2.5 Pro, Chat GPT 4.1
- **LARGE** : Qwen 3 235B-A22B, Gemini 2.5 Flash, ChatGPT-4o-mini
- **MEDIUM** : Qwen 32B
- **SMALL** : Qwen 8B
- **MICRO** : Qwen 1.5B

Pour créer ou modifier des profils, utilisez le script `create-profile.ps1`. Pour plus d'informations, consultez la documentation dans `docs/guide-utilisation-profils-modes.md`.

## MCPs disponibles

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

Pour plus d'informations sur l'utilisation des MCPs, consultez les répertoires `mcps/internal/` et `mcps/external/` ainsi que le document `mcps/README.md`.

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

Pour résoudre les problèmes d'encodage, vous pouvez utiliser les scripts disponibles dans le répertoire `roo-config/encoding-scripts/`. Pour plus d'informations, consultez la [documentation des scripts d'encodage](roo-config/encoding-scripts/README.md).

## Migration vers le système de profils

Si vous utilisez encore l'ancienne architecture (association directe des modes aux modèles), vous pouvez migrer vers le nouveau système basé sur les profils en utilisant le script `migrate-to-profiles.ps1` :

```powershell
# Migrer une configuration existante vers un profil
.\migrate-to-profiles.ps1 -ConfigFile "roo-modes/configs/standard-modes.json" -OutputProfileName "migré"
```

Ce script analysera votre configuration existante, extraira les modèles utilisés par chaque mode, créera un nouveau profil avec ces informations et sauvegardera l'ancienne configuration.

## Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.