# Proposition d'Architecture pour RUSH-SYNC

Ce document présente la nouvelle structure de répertoires proposée pour le projet RUSH-SYNC, conçue pour améliorer la clarté, la maintenabilité et l'isolation du projet.

## 1. Nom du Répertoire Racine

Le projet sera centralisé dans un répertoire racine unique nommé : `RooSync/`.

## 2. Arborescence Cible

Voici l'arborescence détaillée de la nouvelle structure :

```
RooSync/
├── .config/             # Configuration spécifique au projet (et non à l'environnement Roo)
│   ├── sync-config.json
│   └── sync-config.schema.json
├── .state/              # Fichiers d'état et rapports générés par l'application
│   ├── sync-report.md
│   └── sync-dashboard.json
├── docs/                # Documentation fonctionnelle et technique du projet
│   ├── architecture.md
│   └── guides/
├── src/                 # Code source de l'application
│   ├── modules/         # Modules PowerShell réutilisables
│   │   ├── Core.psm1
│   │   └── Actions.psm1
│   └── sync-manager.ps1 # Script principal d'orchestration
├── tests/               # Ensemble des tests (unitaires, intégration, etc.)
│   └── ...
├── .env                 # Variables d'environnement locales (non versionné)
├── .env.example         # Fichier d'exemple pour les variables d'environnement
├── .gitignore           # Fichiers et répertoires à ignorer par Git
└── README.md            # Documentation principale du projet : description, installation, usage
```

## 3. Justification des Choix de Conception

### 3.1. Centralisation et Isolation

La création d'un répertoire racine `RooSync/` a pour objectif principal de **centraliser** tous les artefacts du projet en un seul endroit. Cela met fin à la dispersion actuelle des fichiers et clarifie la frontière entre le projet et le reste de l'espace de travail.

### 3.2. Séparation des Responsabilités

La structure interne du répertoire `RooSync/` est organisée selon les standards de développement logiciel :

*   **`src/`** : Isole le code source de l'application, le séparant de la configuration, de la documentation et des tests.
*   **`.config/`** : Contient uniquement les fichiers de configuration nécessaires au fonctionnement de l'application RUSH-SYNC, indépendamment de l'environnement Roo.
*   **`.state/`** : Stocke les fichiers volatils générés par l'application, comme les rapports ou les états de synchronisation. Ce dossier a vocation à être ignoré par Git.
*   **`docs/`** : Centralise toute la documentation propre au projet.
*   **`tests/`** : Regroupe tous les fichiers de test, facilitant leur exécution et leur maintenance.

### 3.3. Dissociation de l'Environnement de Développement

Les fichiers et répertoires liés à l'environnement Roo (`roo-config/`, `mcps/`, etc.) sont **intentionnellement laissés en dehors** de l'arborescence `RooSync/`.

**Justification :**
*   **Portabilité :** Le projet `RooSync` devient agnostique de l'environnement de développement. Il pourrait être développé ou déployé sur une autre machine sans nécessiter l'intégralité de la configuration de Roo.
*   **Clarté :** La séparation évite toute confusion entre ce qui constitue l'application et ce qui constitue l'outillage pour la développer.
*   **Maintenance :** La mise à jour de l'environnement Roo peut se faire indépendamment de celle du projet RUSH-SYNC, et vice-versa.

Cette organisation garantit que le projet `RooSync` est un composant autonome et bien défini.