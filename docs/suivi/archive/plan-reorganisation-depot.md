# Plan de réorganisation du dépôt Roo Extensions

## 1. Analyse de la structure actuelle

### 1.1 Fichiers à la racine

J'ai identifié plusieurs fichiers à la racine qui devraient être déplacés dans des répertoires appropriés :

- **Module de validation de formulaire** : 5 fichiers liés (form-validator-client.js, form-validator-README.md, form-validator-test.js, form-validator.html, form-validator.js) qui constituent un module autonome
- **Documentation** : roo-code-documentation.md qui devrait être dans le répertoire roo-code ou docs
- **Scripts PowerShell** : plusieurs scripts (.ps1) qui devraient être organisés par fonction
- **Fichier d'instructions** : instructions-modification-prompts.md qui devrait être dans la documentation

### 1.2 Répertoires redondants ou mal classés

- **NVIDIA Corporation** : contient uniquement un sous-répertoire umdlogs qui semble être des logs système non liés directement au projet
- **configs** : contient uniquement un sous-répertoire escalation, ce qui crée une hiérarchie inutile
- **archive** : contient plusieurs sous-répertoires sans organisation claire
- **tests et test-results** : les données et résultats de tests sont dispersés dans plusieurs répertoires

### 1.3 Organisation des MCPs

Les MCPs sont actuellement divisés entre :
- **mcps/mcp-servers** : MCPs internes développés dans ce dépôt
- **mcps/external-mcps** : MCPs externes développés par d'autres équipes

Cette séparation est logique mais pourrait être améliorée.

### 1.4 Tests et résultats de tests

Les tests et leurs résultats sont dispersés dans plusieurs répertoires :
- **tests/** : tests généraux
- **test-data/** : données de test
- **test-results/** : résultats de tests généraux
- **roo-modes/n5/test-results/** : résultats spécifiques aux tests d'escalade/désescalade

## 2. Plan de réorganisation

Je propose la structure de répertoires suivante pour améliorer l'organisation du projet :

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
│   ├── internal/                   # MCPs développés dans ce dépôt
│   │   ├── quickfiles/
│   │   ├── jinavigator/
│   │   └── jupyter/
│   ├── external/                   # MCPs externes
│   │   ├── searxng/
│   │   ├── win-cli/
│   │   ├── filesystem/
│   │   ├── git/
│   │   └── github/
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
└── archive/                        # Contenu archivé (à nettoyer périodiquement)
    └── legacy/                     # Ancien code conservé pour référence
```

## 3. Liste des déplacements/renommages à effectuer

### 3.1 Fichiers à la racine

| Fichier actuel | Nouvelle destination |
|----------------|---------------------|
| form-validator-client.js | modules/form-validator/form-validator-client.js |
| form-validator-README.md | modules/form-validator/README.md |
| form-validator-test.js | modules/form-validator/tests/form-validator-test.js |
| form-validator.html | modules/form-validator/form-validator.html |
| form-validator.js | modules/form-validator/form-validator.js |
| roo-code-documentation.md | roo-code/docs/README.md |
| instructions-modification-prompts.md | docs/guides/instructions-modification-prompts.md |
| migrate-to-profiles.ps1 | scripts/migration/migrate-to-profiles.ps1 |
| update-mode-prompts-fixed.ps1 | scripts/maintenance/update-mode-prompts-fixed.ps1 |
| update-mode-prompts-v2.ps1 | scripts/maintenance/update-mode-prompts-v2.ps1 |
| update-mode-prompts.ps1 | scripts/maintenance/update-mode-prompts.ps1 |
| update-script-paths.ps1 | scripts/maintenance/update-script-paths.ps1 |
| organize-repo.ps1 | scripts/maintenance/organize-repo.ps1 |

### 3.2 Répertoires à réorganiser

| Répertoire actuel | Nouvelle destination |
|-------------------|---------------------|
| NVIDIA Corporation/ | À supprimer ou déplacer hors du dépôt |
| configs/escalation/ | roo-config/settings/escalation/ |
| test-data/ | tests/data/ |
| test-results/ | tests/results/ |
| roo-modes/n5/test-results/ | tests/results/n5/ |
| mcps/mcp-servers/ | mcps/internal/ |
| mcps/external-mcps/ | mcps/external/ |

## 4. Avantages de la nouvelle structure

1. **Meilleure séparation des préoccupations** : Chaque répertoire a un rôle clair et bien défini
2. **Organisation plus intuitive** : Les fichiers liés sont regroupés ensemble
3. **Réduction de la complexité** : Moins de fichiers à la racine et hiérarchie plus claire
4. **Facilité de maintenance** : Structure plus facile à comprendre pour les nouveaux contributeurs
5. **Évolutivité** : Structure qui peut facilement accueillir de nouveaux modules et fonctionnalités
6. **Cohérence** : Nommage cohérent des répertoires et des fichiers

## 5. Plan d'implémentation

1. **Créer les nouveaux répertoires** nécessaires
2. **Déplacer les fichiers** selon le plan de déplacement
3. **Mettre à jour les références** dans les fichiers pour refléter les nouveaux chemins
4. **Tester** que tout fonctionne correctement après la réorganisation
5. **Mettre à jour la documentation** pour refléter la nouvelle structure

## 6. Recommandations supplémentaires

1. **Nettoyer le répertoire archive** : Évaluer le contenu et soit l'intégrer dans la nouvelle structure, soit le supprimer s'il est obsolète
2. **Standardiser les READMEs** : S'assurer que chaque répertoire principal a un fichier README.md qui explique son contenu et son rôle
3. **Mettre à jour les scripts** : Adapter les scripts existants pour qu'ils fonctionnent avec la nouvelle structure
4. **Créer un .gitignore** : Pour exclure les fichiers temporaires et les logs (comme le répertoire NVIDIA Corporation)

Cette réorganisation permettra d'avoir une structure de projet plus claire, plus cohérente et plus facile à maintenir, tout en facilitant la compréhension du projet pour les nouveaux contributeurs.