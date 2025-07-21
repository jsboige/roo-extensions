# Roo Extensions

## À propos du projet

Roo Extensions est un projet visant à enrichir les fonctionnalités de Roo, un assistant de développement intelligent pour VS Code. Ce dépôt centralise des modes personnalisés, des configurations optimisées et des serveurs MCP (Model Context Protocol) pour décupler les capacités de l'assistant.

## Comment démarrer

### Prérequis

- Roo installé et configuré dans VS Code.
- Accès à des modèles de langage comme Claude 3.5 Sonnet ou Qwen 3.

### Installation

1.  **Clonez le dépôt :**
    ```bash
    git clone https://github.com/votre-utilisateur/roo-extensions.git
    cd roo-extensions
    ```

2.  **Lancez le script de déploiement des paramètres :**
    Ce script gère la mise à jour des submodules et le déploiement des configurations essentielles (serveurs MCP, etc.).
    ```powershell
    # Exécutez ce script depuis la racine du projet
    ./roo-config/settings/deploy-settings.ps1
    ```
    Pour des déploiements plus spécifiques (comme les modes), consultez la documentation dans `roo-config/README.md`.

3.  **Redémarrez Roo** pour que les nouveaux modes soient pris en compte.

## Structure du projet

Le dépôt est organisé de la manière suivante pour séparer clairement les différentes responsabilités :
```
roo-extensions/
├── docs/               # Documentation générale, guides et rapports.
├── mcps/               # Serveurs MCP (interne, externe, forké).
├── modules/            # Modules de fonctionnalités autonomes.
├── roo-config/         # Scripts de configuration, déploiement et maintenance de Roo.
├── roo-modes/          # Définitions des modes personnalisés (architectures 2 et 5 niveaux).
├── tests/              # Scripts et rapports de tests automatisés.
└── README.md           # Ce fichier.
```

## Concepts clés

### Architectures des Modes

-   **Architecture à 2 niveaux (Simple/Complexe) :** L'approche **recommandée**. Les modes basculent dynamiquement entre `simple` et `complexe` selon la nature de la tâche. Simple et efficace.
-   **Architecture à 5 niveaux (n5) :** Une approche expérimentale pour une granularité plus fine des coûts en fonction de la complexité (MICRO, MINI, MEDIUM, LARGE, ORACLE).

### Serveurs MCP (Model Context Protocol)

Les MCPs sont des services qui étendent les capacités de Roo. Ils sont classés en trois catégories :
-   **`internal`** : Développés spécifiquement pour ce projet (ex: `quickfiles`, `jinavigator`).
-   **`external`** : MCPs tiers intégrés (ex: `searxng`, `git`, `filesystem`).
-   **`forked`** : Versions modifiées de MCPs open-source.

Pour une liste détaillée, consultez le `mcps/README.md`.

## Points d'entrée de la Documentation

Pour approfondir votre connaissance du projet, voici quelques points d'entrée essentiels :
-   **Modes et Architectures** : `roo-modes/README.md`
-   **Configuration et Déploiement** : `roo-config/README.md`
-   **Serveurs MCP** : `mcps/README.md`
-   **Guides détaillés** : `docs/`

## Contribution

Les contributions sont les bienvenues. Veuillez forker le dépôt, créer une branche pour vos modifications et soumettre une Pull Request.

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.