# Plan d'Implémentation Technique : sync-manager.ps1

**Version :** 1.0  
**Date :** 29 juillet 2025  
**Basé sur :** [02-sync-manager-architecture.md](./02-sync-manager-architecture.md)

---

## Introduction

Ce document fournit une feuille de route technique détaillée pour le développement du `sync-manager.ps1`. Il décompose les exigences architecturales en une série de sous-tâches granulaires et ordonnancées, conçues pour être implémentées séquentiellement. Chaque tâche est définie avec ses objectifs, les fichiers concernés, la logique à implémenter, les commandes de validation, les critères de succès, et ses dépendances.

## Phase 1 : Initialisation et Configuration (Le Socle)

Cette phase établit les fondations du script : la structure des fichiers, le chargement de la configuration, et la journalisation.

### Tâche 1.1 : Création du Squelette du Projet

*   **Objectif :** Mettre en place la structure de répertoires et de fichiers définie dans l'architecture.
*   **Fichiers à créer/modifier :**
    *   `sync-manager.ps1` (fichier principal)
    *   `modules/` (répertoire)
    *   `modules/Core.psm1`
    *   `modules/Configuration.psm1`
    *   `modules/Logger.psm1`
    *   `modules/Utils.psm1`
    *   `config/` (répertoire)
    *   `config/sync-config.json` (version de base)
    *   `config/.env.example`
    *   `logs/` (répertoire, vide)
    *   `tests/` (répertoire)
    *   `tests/Pester.psd1`
*   **Logique à implémenter :**
    *   Dans `sync-manager.ps1` : Logique de base pour parser les arguments (`-Action`, etc.) et appeler le module `Core`.
*   **Commandes de validation :**
    *   `pwsh -c "tree /F"` (ou `ls -R` sur Linux/macOS) pour vérifier la structure.
    *   `./sync-manager.ps1 -Action Status` (doit retourner une erreur contrôlée car rien n'est encore implémenté).
*   **Critères de succès :**
    *   L'arborescence des fichiers et répertoires est conforme à l'architecture.
    *   Le script `sync-manager.ps1` s'exécute sans erreur de syntaxe.
*   **Dépendances :** Aucune.

### Tâche 1.2 : Développement du Module de Journalisation (Logger.psm1)

*   **Objectif :** Implémenter un système de logging structuré (console et fichier).
*   **Fichiers à modifier :**
    *   `modules/Logger.psm1`
*   **Fonctions à implémenter :**
    *   `Write-Log` : Fonction principale avec des paramètres pour le niveau (`INFO`, `WARN`, `ERROR`, `DEBUG`), le message, et un objet de contexte.
    *   `Initialize-Logger` : Configure les sorties (console, fichier) en se basant sur la configuration.
*   **Commandes de validation :**
    *   `Import-Module ./modules/Logger.psm1; Write-Log -Level INFO -Message "Test"`
*   **Critères de succès :**
    *   Un message de log formaté s'affiche dans la console.
    *   Un message de log au format JSON est écrit dans `logs/sync-manager.log`.
*   **Dépendances :** Tâche 1.1.

### Tâche 1.3 : Développement du Module de Configuration (Configuration.psm1)

*   **Objectif :** Charger, valider et fusionner les fichiers de configuration.
*   **Fichiers à modifier :**
    *   `modules/Configuration.psm1`
*   **Fonctions à implémenter :**
    *   `Get-SyncConfiguration` : Charge `sync-config.json`, le valide par rapport à son schéma, et fusionne les `machineOverrides`.
    *   `Resolve-EnvironmentVariables` : Charge les variables depuis `.env`.
    *   `Test-ConfigurationSchema` : Valide un objet de configuration par rapport au schéma JSON.
*   **Commandes de validation :**
    *   `Import-Module ./modules/Configuration.psm1; $config = Get-SyncConfiguration; $config | ConvertTo-Json`
*   **Critères de succès :**
    *   La configuration est chargée correctement.
    *   Une erreur est levée si `sync-config.json` est invalide.
    *   Les variables de `.env` sont accessibles via `$env:`.
*   **Dépendances :** Tâche 1.1.

## Phase 2 : Logique Métier Fondamentale

Cette phase se concentre sur l'implémentation des actions principales de synchronisation.

### Tâche 2.1 : Implémentation du Module Core et de l'Action `Status`

*   **Objectif :** Mettre en place le moteur principal et l'action `Status` pour vérifier l'état du dépôt.
*   **Fichiers à modifier :**
    *   `modules/Core.psm1`
    *   `modules/GitOperations.psm1`
*   **Fonctions à implémenter :**
    *   Dans `Core.psm1` : `Invoke-SyncOperation` qui gère le `switch` sur le paramètre `-Action`.
    *   Dans `GitOperations.psm1` : `Get-GitStatus` qui utilise `git status --porcelain -b` pour obtenir un état propre et machine-readable.
*   **Commandes de validation :**
    *   `./sync-manager.ps1 -Action Status`
*   **Critères de succès :**
    *   Le script affiche un résumé clair de l'état du dépôt Git (branche, fichiers modifiés, etc.).
*   **Dépendances :** Tâche 1.3.

### Tâche 2.2 : Implémentation de l'Action `Pull`

*   **Objectif :** Développer la logique de synchronisation descendante (`pull`).
*   **Fichiers à modifier :**
    *   `modules/Core.psm1`
    *   `modules/GitOperations.psm1`
*   **Fonctions à implémenter :**
    *   Dans `GitOperations.psm1` : `Invoke-GitPull` qui gère `git fetch`, `git merge` (ou `rebase`), et l'auto-stash si nécessaire.
*   **Commandes de validation :**
    *   `./sync-manager.ps1 -Action Pull`
    *   `./sync-manager.ps1 -Action Pull -DryRun` (doit simuler l'opération sans l'exécuter).
*   **Critères de succès :**
    *   Le dépôt local est correctement mis à jour avec les changements distants.
    *   Les modifications locales non-commitées sont mises de côté (`stash`) et ré-appliquées.
*   **Dépendances :** Tâche 2.1.

### Tâche 2.3 : Implémentation de l'Action `Push`

*   **Objectif :** Développer la logique de synchronisation montante (`push`).
*   **Fichiers à modifier :**
    *   `modules/Core.psm1`
    *   `modules/GitOperations.psm1`
*   **Fonctions à implémenter :**
    *   Dans `GitOperations.psm1` : `Invoke-GitPush` qui gère `git add`, `git commit` avec un message généré, et `git push`.
*   **Commandes de validation :**
    *   `./sync-manager.ps1 -Action Push`
*   **Critères de succès :**
    *   Les modifications locales sont commitées et poussées vers le dépôt distant.
    *   La commande échoue proprement si le push est rejeté (nécessite un pull).
*   **Dépendances :** Tâche 2.1.

## Phase 3 : Fonctionnalités Avancées

Cette phase ajoute la gestion des conflits et le système d'extensions.

### Tâche 3.1 : Développement du Module de Résolution de Conflits

*   **Objectif :** Créer la logique pour détecter et aider à résoudre les conflits de merge.
*   **Fichiers à créer/modifier :**
    *   `modules/ConflictResolver.psm1`
*   **Fonctions à implémenter :**
    *   `Get-ConflictAnalysis` : Analyse les fichiers en conflit.
    *   `Invoke-ConflictResolution` : Orchestre la résolution selon la stratégie (`interactive`, `acceptLocal`, etc.).
    *   `Show-InteractiveConflictResolver` : Affiche une interface guidée en console.
*   **Commandes de validation :**
    *   (Nécessite de créer manuellement une situation de conflit)
    *   `./sync-manager.ps1 -Action Pull` (doit déclencher l'interface de résolution).
*   **Critères de succès :**
    *   Les conflits sont détectés après un `pull`.
    *   L'interface interactive permet à l'utilisateur de choisir une stratégie de résolution.
*   **Dépendances :** Tâche 2.2.

### Tâche 3.2 : Implémentation du Système de Hooks

*   **Objectif :** Permettre l'exécution de scripts personnalisés à des points clés du processus.
*   **Fichiers à créer/modifier :**
    *   `modules/HookSystem.psm1`
    *   Créer des exemples dans `hooks/`
*   **Fonctions à implémenter :**
    *   `Invoke-SyncHook` : Exécute les scripts associés à un hook (`prePull`, `postPush`, etc.).
*   **Commandes de validation :**
    *   Configurer un hook `prePull` dans `sync-config.json` qui écrit dans un fichier.
    *   `./sync-manager.ps1 -Action Pull` et vérifier que le fichier a été créé.
*   **Critères de succès :**
    *   Les scripts de hooks sont exécutés au bon moment.
    *   Le processus de synchronisation peut être arrêté si un hook échoue (`continueOnError: false`).
*   **Dépendances :** Tâche 2.2, Tâche 2.3.

## Phase 4 : Finalisation et Intégration

Cette phase finalise le projet avec les tests, la gestion d'état et les rapports.

### Tâche 4.1 : Développement des Tests Pester

*   **Objectif :** Créer une suite de tests unitaires et d'intégration pour garantir la fiabilité.
*   **Fichiers à créer/modifier :**
    *   `tests/Configuration.tests.ps1`
    *   `tests/GitOperations.tests.ps1`
*   **Logique à implémenter :**
    *   Tests Pester pour `Get-SyncConfiguration` (avec mocks de fichiers).
    *   Tests Pester pour `Get-GitStatus` (en se basant sur un dépôt Git de test).
*   **Commandes de validation :**
    *   `Invoke-Pester -Path tests/`
*   **Critères de succès :**
    *   Les tests passent avec succès.
    *   La couverture de code pour les modules critiques est supérieure à 80%.
*   **Dépendances :** Tâches 1.3, 2.1.

### Tâche 4.2 : Implémentation du Gestionnaire d'État

*   **Objectif :** Mettre à jour les fichiers d'état (`sync-dashboard.json`) et de rapport (`sync-report.md`, `sync-roadmap.md`).
*   **Fichiers à créer/modifier :**
    *   `modules/StateManager.psm1`
*   **Fonctions à implémenter :**
    *   `Update-SyncState` : Met à jour la section de la machine actuelle dans `sync-dashboard.json`.
    *   `Export-SyncReport` : Génère un rapport Markdown à la fin d'une opération.
    *   `Create-RoadmapEntry` : Ajoute un bloc de décision dans `sync-roadmap.md`.
*   **Commandes de validation :**
    *   `./sync-manager.ps1 -Action Status`
    *   Vérifier que `sync-dashboard.json` et `sync-report.md` ont été créés/mis à jour.
*   **Critères de succès :**
    *   Les fichiers d'état reflètent le résultat de la dernière opération.
    *   Le rapport est lisible et contient les informations pertinentes.
*   **Dépendances :** Tâche 2.1.