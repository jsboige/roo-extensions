# Guide consolidé de la gestion des tâches Roo

**Auteur:** Roo
**Date:** 29 août 2025
**Statut:** Version 1.0

## 1. Introduction

Ce document synthétise les informations critiques relatives à l'architecture de persistance des tâches de l'extension Roo. Il a pour but de servir de référence unique pour toute opération de maintenance, de sauvegarde ou de restauration impliquant l'état des tâches.

## 2. Architecture de persistance

La gestion des tâches Roo repose sur une architecture à deux niveaux :

### 2.1. Fichiers de tâches individuels

-   **Description:** Chaque tâche est stockée dans un répertoire unique contenant son historique et ses métadonnées.
-   **Emplacement:** `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks`

### 2.2. Index global de l'historique (`taskHistory`)

-   **Description:** Pour des raisons de performance, un index centralisé (`taskHistory`) est maintenu pour afficher rapidement la liste des tâches. Cet index est la source de vérité pour l'interface utilisateur.
-   **Emplacement:** Base de données SQLite `state.vscdb` de VS Code.

## 3. Emplacement et manipulation du fichier `state.vscdb`

### 3.1. Chemin d'accès complet

Le fichier `state.vscdb` est le composant le plus critique pour la gestion de l'état des tâches. Son emplacement exact est :

**`C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\state.vscdb`**

**Note:** Le chemin d'accès peut varier en fonction du nom d'utilisateur. Il est recommandé d'utiliser des variables d'environnement (`%APPDATA%`) pour construire ce chemin de manière dynamique.

### 3.2. Bonnes pratiques de manipulation

-   **Sauvegarde:** Avant toute opération de maintenance susceptible d'affecter l'état des tâches, il est impératif de créer une sauvegarde horodatée du fichier `state.vscdb`.
-   **Manipulation:** Toute modification directe de la base de données `state.vscdb` doit être effectuée avec une extrême prudence, en utilisant des outils appropriés (par exemple, des scripts SQLite) et après avoir effectué une sauvegarde.
-   **Synchronisation:** Lors de la modification de l'association d'une tâche à un workspace, il est crucial de mettre à jour à la fois le fichier `task_metadata.json` de la tâche et l'index `taskHistory` dans `state.vscdb` pour éviter les désynchronisations.

## 4. Stratégies de restauration

### 4.1. Structure de la base de données

La base de données `state.vscdb` est une base de données SQLite3 qui contient une table principale, généralement nommée `ItemTable`. Cette table stocke des paires clé-valeur. La clé la plus importante pour Roo est `rooveterinaryinc.roo-cline.taskHistory`, qui contient l'index de l'historique des tâches sous forme de chaîne JSON.

### 4.2. Restauration du fichier `state.vscdb`

La méthode la plus simple pour restaurer l'historique des tâches consiste à remplacer le fichier `state.vscdb` existant par une version sauvegardée. Cette opération doit être effectuée lorsque VS Code est complètement fermé.

### 4.2. Reconstruction de l'index par script

En l'absence de sauvegarde, il est possible de reconstruire l'index `taskHistory` en parcourant les fichiers de tâches individuels et en réinsérant les métadonnées dans la base de données `state.vscdb`. Cette opération est plus complexe et doit être réservée aux situations où la restauration d'une sauvegarde n'est pas possible.

## 5. Scripts de maintenance

### 5.1. Script de sauvegarde (`backup-state-db.ps1`)

Un script PowerShell a été créé pour automatiser la sauvegarde de la base de données `state.vscdb`.

-   **Emplacement:** `scripts/repair/backup-state-db.ps1`
-   **Utilisation:**
    ```powershell
    powershell -ExecutionPolicy Bypass -File scripts/repair/backup-state-db.ps1
    ```
-   **Fonctionnement:** Le script installe le module PowerShell pour SQLite (`PSSQLite`), se connecte à la base de données `state.vscdb`, et en crée une copie de sauvegarde horodatée dans le même répertoire.