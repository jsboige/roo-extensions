# Redirection

**ATTENTION** : Les fichiers liés aux modes dans ce répertoire sont obsolètes. Le contenu a été migré vers le nouveau répertoire `roo-modes`.

## Nouvelle structure

La nouvelle structure se trouve dans le répertoire `roo-modes` avec l'organisation suivante :

```
roo-modes/
├── README.md                   # Vue d'ensemble et introduction
├── docs/                       # Documentation conceptuelle
├── configs/                    # Configurations des modes
│   ├── standard-modes.json     # Configuration standard des modes (anciennement dans roo-config/modes/)
│   └── custom/                 # Configurations personnalisées
├── examples/                   # Exemples de configurations (anciennement dans roo-config/exemple-config/)
├── templates/                  # Modèles pour créer de nouveaux modes
├── scripts/                    # Scripts de déploiement et utilitaires
│   ├── deploy-modes.ps1        # Script de déploiement de base (anciennement dans roo-config/)
│   └── deploy-modes-enhanced.ps1 # Script de déploiement avancé (anciennement dans roo-config/)
└── tests/                      # Tests pour les modes personnalisés
```

Veuillez utiliser le nouveau répertoire pour toutes les opérations liées aux modes.