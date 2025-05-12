# Roo Modes (Architecture à 2 Niveaux)

Ce répertoire contient tout ce qui concerne les modes personnalisés pour Roo dans l'architecture à 2 niveaux (Simple/Complexe).

> **Note** : Cette architecture coexiste avec la nouvelle architecture à 5 niveaux (n5) implémentée dans le répertoire `roo-modes-n5/`. Pour les nouveaux développements, il est recommandé d'utiliser l'architecture à 5 niveaux.

## Structure du répertoire

```
roo-modes/
├── README.md                   # Vue d'ensemble et introduction (ce fichier)
├── docs/                       # Documentation conceptuelle
│   ├── architecture/           # Conception architecturale
│   ├── criteres-decision/      # Critères de routage des tâches
│   ├── optimisation/           # Optimisation des prompts
│   └── implementation/         # Stratégie d'implémentation
├── configs/                    # Configurations des modes
│   ├── standard-modes.json     # Configuration standard des modes
│   └── custom/                 # Configurations personnalisées
├── examples/                   # Exemples de configurations
│   ├── config.json             # Exemple de configuration générale
│   ├── modes.json              # Exemple de configuration de modes
│   └── servers.json            # Exemple de configuration de serveurs
├── templates/                  # Modèles pour créer de nouveaux modes
├── scripts/                    # Scripts de déploiement et utilitaires
│   ├── deploy-modes.ps1        # Script de déploiement de base
│   └── deploy-modes-enhanced.ps1 # Script de déploiement avancé
└── tests/                      # Tests pour les modes personnalisés
```

## Utilisation

### Configuration des modes

Les modes sont configurés dans le fichier `configs/standard-modes.json`. Ce fichier contient la définition de tous les modes standard disponibles dans Roo, organisés selon l'architecture à 2 niveaux (Simple/Complexe).

### Relation avec l'architecture à 5 niveaux

Cette architecture à 2 niveaux peut être considérée comme une version simplifiée de l'architecture à 5 niveaux, où :
- Les modes "Simple" correspondent approximativement aux niveaux MINI et MEDIUM
- Les modes "Complexe" correspondent approximativement aux niveaux LARGE et ORACLE

Pour une granularité plus fine et une meilleure optimisation des ressources, consultez l'architecture à 5 niveaux dans le répertoire `roo-modes-n5/`.

### Déploiement des modes

Pour déployer les modes, utilisez les scripts dans le répertoire `scripts/` :

- `deploy-modes.ps1` : Script de déploiement de base
- `deploy-modes-enhanced.ps1` : Script de déploiement avancé avec des fonctionnalités supplémentaires

### Exemples

Des exemples de configuration sont disponibles dans le répertoire `examples/`.

## Documentation

La documentation conceptuelle est disponible dans le répertoire `docs/` :

- `architecture/` : Documentation sur la conception architecturale des modes
- `criteres-decision/` : Documentation sur les critères de routage des tâches
- `optimisation/` : Documentation sur l'optimisation des prompts
- `implementation/` : Documentation sur la stratégie d'implémentation

## Tests

Des tests pour les modes personnalisés sont disponibles dans le répertoire `tests/`.