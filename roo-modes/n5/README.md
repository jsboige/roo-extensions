# Architecture d'Orchestration à 5 Niveaux de Complexité

Ce répertoire contient l'implémentation de l'architecture d'orchestration à 5 niveaux de complexité pour les modes Roo.

## Présentation

L'architecture d'orchestration à 5 niveaux est une approche structurée pour gérer des tâches de complexité variable, en optimisant l'utilisation des ressources et en assurant une escalade/désescalade efficace entre les différents niveaux de complexité.

Les 5 niveaux de complexité sont :

1. **MICRO** - Pour les tâches très simples et rapides
2. **MINI** - Pour les tâches simples mais nécessitant un peu plus de contexte
3. **MEDIUM** - Pour les tâches de complexité moyenne
4. **LARGE** - Pour les tâches complexes nécessitant une analyse approfondie
5. **ORACLE** - Pour les tâches très complexes nécessitant une expertise avancée

## Structure du Répertoire

```
roo-modes/n5/
├── README.md                # Ce fichier
├── configs/                 # Configurations des modes pour chaque niveau
│   ├── micro-modes.json     # Configuration des modes de niveau MICRO
│   ├── mini-modes.json      # Configuration des modes de niveau MINI
│   ├── medium-modes.json    # Configuration des modes de niveau MEDIUM
│   ├── large-modes.json     # Configuration des modes de niveau LARGE
│   └── oracle-modes.json    # Configuration des modes de niveau ORACLE
├── scripts/                 # Scripts de déploiement et d'utilitaires
│   ├── deploy.ps1           # Script de déploiement principal
│   └── utils/               # Utilitaires divers
├── docs/                    # Documentation
│   ├── guide-utilisation.md # Guide d'utilisation
│   └── guide-migration.md   # Guide de migration depuis l'ancienne architecture
└── tests/                   # Tests pour valider l'architecture
    ├── test-escalade.js     # Tests des mécanismes d'escalade
    └── test-desescalade.js  # Tests des mécanismes de désescalade
```

## Principes Clés

### Mécanismes d'Escalade

L'architecture implémente trois types d'escalade :

1. **Escalade par branchement** (priorité haute) : Création de sous-tâches pour traiter des aspects spécifiques à un niveau supérieur
2. **Escalade par changement de mode** (priorité moyenne) : Passage à un mode de niveau supérieur pour toute la tâche
3. **Escalade par terminaison** (priorité basse) : Arrêt de la tâche actuelle pour reprise à un niveau supérieur

### Mécanismes de Désescalade

La désescalade est implémentée pour optimiser l'utilisation des ressources :

1. Évaluation continue de la complexité de la tâche
2. Suggestion de désescalade lorsque la tâche devient suffisamment simple
3. Passage à un niveau inférieur pour économiser des ressources

### Utilisation Optimisée des MCPs

Chaque niveau est configuré pour utiliser de manière optimale les MCPs disponibles :

- Priorité systématique aux MCPs par rapport aux outils standards
- Utilisation de MCPs spécifiques selon les besoins (quickfiles, jinavigator, searxng)

### Nettoyage des Fichiers Intermédiaires

Une attention particulière est portée au nettoyage des fichiers intermédiaires :

- Identification systématique des fichiers temporaires créés
- Suppression de ces fichiers à la fin de chaque tâche
- Documentation des fichiers conservés dans le rapport final

## Coexistence avec l'Architecture à 2 Niveaux

Cette nouvelle architecture à 5 niveaux coexiste harmonieusement avec l'architecture à 2 niveaux (Simple/Complexe) dans `roo-modes/`. Les deux systèmes peuvent fonctionner en parallèle, permettant une migration progressive.

La correspondance approximative entre les deux architectures est la suivante :
- **MICRO** : Niveau unique à l'architecture n5 (pas d'équivalent direct)
- **MINI** : Correspond partiellement aux modes "Simple"
- **MEDIUM** : Correspond partiellement aux modes "Simple"
- **LARGE** : Correspond partiellement aux modes "Complexe"
- **ORACLE** : Correspond partiellement aux modes "Complexe"

Pour plus de détails sur la migration depuis l'architecture à 2 niveaux, consultez le document `docs/guide-migration.md`.

## Déploiement

Pour déployer cette architecture, utilisez le script `scripts/deploy.ps1` :

```powershell
./scripts/deploy.ps1
```

## Tests

Pour exécuter les tests de validation :

```powershell
node tests/test-escalade.js
node tests/test-desescalade.js
```

## Documentation

Pour plus d'informations, consultez les documents dans le répertoire `docs/` :

- `guide-utilisation.md` - Guide d'utilisation détaillé de l'architecture à 5 niveaux
- `guide-migration.md` - Guide pour migrer depuis l'architecture à 2 niveaux
- `guide-migration-roo-compatible.md` - Guide pour assurer la compatibilité avec Roo standard

Des documents supplémentaires sur l'architecture à 5 niveaux sont également disponibles dans le répertoire principal `docs/` du projet, notamment :
- `docs/architecture-orchestration-5-niveaux.md` - Description détaillée de l'architecture
- `docs/specification-n-niveaux-complexite.md` - Spécifications techniques des niveaux de complexité
- `docs/guide-escalade-desescalade.md` - Guide sur les mécanismes d'escalade et de désescalade