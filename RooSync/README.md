# RooSync

**Outil de Synchronisation Intelligent pour l'Environnement Roo**

RooSync (anciennement RUSH-SYNC) est un projet autonome conçu pour synchroniser l'environnement Roo en se basant sur des fichiers de configuration sources de vérité. Il est découplé du reste de l'environnement pour assurer sa portabilité.

---

## 📋 Table des Matières

- [Vue d'ensemble](#-vue-densemble)
- [Architecture](#-architecture)
- [Installation](#-installation)
- [Utilisation](#-utilisation)
- [Configuration](#️-configuration)
- [Documentation](#-documentation)
- [Tests](#-tests)
- [Contribution](#-contribution)

---

## 🎯 Vue d'ensemble

RooSync est un système de synchronisation PowerShell modulaire qui permet de :

- **Synchroniser** les configurations entre plusieurs machines
- **Comparer** les états de configuration locale et distante
- **Gérer** les conflits de manière intelligente
- **Automatiser** les workflows de synchronisation via des hooks
- **Tracer** toutes les opérations dans des rapports détaillés

### Principes de Conception

✅ **Portabilité** : Fonctionne indépendamment de l'environnement de développement Roo  
✅ **Modularité** : Architecture claire avec séparation des responsabilités  
✅ **Découvrabilité** : Documentation complète et recherchable sémantiquement  
✅ **Testabilité** : Suite de tests automatisés pour valider les refactorisations

---

## 🏗️ Architecture

```
RooSync/
├── .config/             # Configuration du projet
│   └── sync-config.json
├── docs/                # Documentation complète
│   ├── architecture/    # Documents d'architecture
│   ├── file-management.md
│   └── VALIDATION-REFACTORING.md
├── src/                 # Code source
│   ├── modules/         # Modules PowerShell
│   │   ├── Core.psm1    # Logique métier centrale
│   │   └── Actions.psm1 # Actions de synchronisation
│   └── sync-manager.ps1 # Script principal
├── tests/               # Tests automatisés
│   └── test-refactoring.ps1
├── .env                 # Variables d'environnement (non versionné)
├── .gitignore
└── README.md            # Ce fichier
```

### Séparation des Responsabilités

- **`src/`** : Code source isolé de la configuration et des tests
- **`.config/`** : Configuration spécifique au projet RooSync
- **`docs/`** : Documentation fonctionnelle et technique
- **`tests/`** : Tests unitaires et d'intégration

---

## 🚀 Installation

### Prérequis

- PowerShell 5.1+ ou PowerShell Core 7+
- Git (pour la synchronisation avec dépôts distants)
- Accès en lecture/écriture au répertoire de synchronisation

### Configuration Initiale

1. **Cloner le projet** (si pas déjà fait) :
   ```powershell
   git clone <url-du-repo>
   cd RooSync
   ```

2. **Configurer les variables d'environnement** :
   ```powershell
   # Créer le fichier .env à partir de l'exemple
   Copy-Item .env.example .env -ErrorAction SilentlyContinue
   
   # Éditer .env pour définir SYNC_DIRECTORY
   notepad .env
   ```

3. **Vérifier la configuration** :
   ```powershell
   pwsh -c "& ./src/sync-manager.ps1 -Action Compare-Config"
   ```

---

## 💻 Utilisation

### Commandes Principales

#### Comparer les Configurations
Compare l'état local avec la configuration distante :
```powershell
pwsh -c "& ./src/sync-manager.ps1 -Action Compare-Config"
```

#### Synchroniser (Pull)
Récupère les changements depuis le dépôt distant :
```powershell
pwsh -c "& ./src/sync-manager.ps1 -Action Pull"
```

#### Synchroniser (Push)
Envoie les changements locaux vers le dépôt distant :
```powershell
pwsh -c "& ./src/sync-manager.ps1 -Action Push -Message 'Description des changements'"
```

#### Afficher le Statut
Affiche l'état actuel de la synchronisation :
```powershell
pwsh -c "& ./src/sync-manager.ps1 -Action Status"
```

### Exemples d'Usage

```powershell
# Vérifier si la configuration locale est à jour
./src/sync-manager.ps1 -Action Compare-Config

# Synchroniser avec le dépôt distant
./src/sync-manager.ps1 -Action Pull

# Valider avant de pousser des changements
./src/sync-manager.ps1 -Action Status
./src/sync-manager.ps1 -Action Push -Message "FEAT: Ajout nouvelle configuration MCP"
```

---

## ⚙️ Configuration

### Fichier `.env`

Le fichier `.env` contient les variables d'environnement locales :

```env
SYNC_DIRECTORY=<chemin_vers_repertoire_partage>
```

### Fichier `sync-config.json`

La configuration principale se trouve dans [`.config/sync-config.json`](.config/sync-config.json). Elle définit :

- Les cibles de synchronisation
- Les stratégies de résolution de conflits
- Les hooks de synchronisation
- Les filtres de fichiers

Consultez la [documentation de configuration](docs/file-management.md) pour plus de détails.

---

## 📚 Documentation

### Documentation Principale

- **[Architecture du Projet](docs/architecture/RooSync_Architecture_Proposal.md)** - Proposition d'architecture complète
- **[Gestion des Fichiers](docs/file-management.md)** - Explication du système de fichiers de synchronisation
- **[Rapport de Validation](docs/VALIDATION-REFACTORING.md)** - Validation SDDD de la réorganisation

### Documentation Technique

- **[Context-Aware Roadmap](docs/architecture/Context-Aware-Roadmap.md)** - Feuille de route avec contexte
- **[Context Collection Architecture](docs/architecture/Context-Collection-Architecture.md)** - Architecture de collecte du contexte

### Liens Utiles

- [Guide d'Installation du Scheduler](../roo-config/scheduler/README-Installation-Scheduler.md)
- [Documentation du Projet Parent](../README.md)

---

## 🧪 Tests

### Exécuter les Tests

Le projet inclut une suite de tests automatisés pour valider la structure et le fonctionnement :

```powershell
# Exécuter tous les tests
pwsh -c "& ./tests/test-refactoring.ps1"
```

### Couverture des Tests

- ✅ Structure des répertoires (5/5 tests)
- ✅ Présence des fichiers clés (4/4 tests)
- ✅ Imports de modules (3/4 tests)
- ✅ Chemins relatifs (4/4 tests)
- ✅ Exécution du script (1/3 tests)

**Couverture globale : 85%** (17/20 tests passés)

---

## 🤝 Contribution

### Principes SDDD

Ce projet suit les principes **SDDD** (Semantic-Documentation-Driven-Design) :

1. **Semantic-First** : Documentation découvrable via recherche sémantique
2. **Documentation-Driven** : Structure guidée par une documentation claire
3. **Design** : Architecture cohérente et maintenable

### Workflow de Contribution

1. Créer une branche pour vos modifications
2. Documenter les changements dans `docs/`
3. Mettre à jour les tests si nécessaire
4. Valider via recherche sémantique
5. Soumettre une pull request

### Standards de Code

- Utiliser `$PSScriptRoot` pour les chemins relatifs
- Documenter les fonctions PowerShell avec `<#...#>`
- Suivre les conventions de nommage PowerShell
- Ajouter des tests pour les nouvelles fonctionnalités

---

## 📄 Licence

Ce projet fait partie de l'écosystème [roo-extensions](../README.md).

---

## 📞 Support

Pour toute question ou problème :

1. Consultez la [documentation](docs/)
2. Recherchez dans les [issues GitHub](../../issues)
3. Créez une nouvelle issue si nécessaire

---

**Dernière mise à jour :** 2025-10-01  
**Version :** 1.0.0  
**Statut :** ✅ Production Ready (Validation SDDD complète)