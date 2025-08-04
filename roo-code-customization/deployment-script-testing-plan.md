# Plan de Test pour le Script `deploy-fix.ps1`

## 1. Objectif

Ce document décrit les scénarios de test pour valider le fonctionnement, la fiabilité et la robustesse du script PowerShell `deploy-fix.ps1`. Les tests visent à s'assurer que les actions `Deploy` et `Rollback` se comportent comme attendu dans diverses conditions.

## 2. Prérequis

*   Un terminal PowerShell avec les droits d'administrateur.
*   Le script `deploy-fix.ps1` à la racine du projet.
*   Un répertoire source de test (ex: une copie de `c:/dev/roo-extensions/roo-code/dist` avec un fichier `VERSION_DEV.txt` pour l'identifier).
*   Une structure de destination simulée (un faux répertoire `rooveterinaryinc.roo-cline-3.25.6/dist` contenant un fichier `VERSION_ORIGINALE.txt`).

## 3. Scénarios de Test

### Scénario 1 : Cycle de vie nominal (Déploiement -> Rollback)

1.  **Test 1.1 : Premier déploiement**
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Deploy`.
    *   **Résultat attendu :**
        *   Le répertoire `dist` original est renommé en `dist_backup`.
        *   Un nouveau répertoire `dist` est créé.
        *   Le contenu du répertoire source (avec `VERSION_DEV.txt`) est copié dans le nouveau `dist`.
        *   Le message de succès du déploiement s'affiche.

2.  **Test 1.2 : Restaurer l'original**
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Rollback`.
    *   **Résultat attendu :**
        *   Le répertoire `dist` (contenant les modifs) est supprimé.
        *   Le répertoire `dist_backup` est renommé en `dist`.
        *   Le contenu du répertoire `dist` est maintenant celui de la version originale (avec `VERSION_ORIGINALE.txt`).
        *   Le message de succès de la restauration s'affiche.

### Scénario 2 : Exécutions multiples et idempotence

1.  **Test 2.1 : Déploiements successifs**
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Deploy` deux fois de suite.
    *   **Résultat attendu :**
        *   Le premier déploiement se déroule normalement.
        *   Le second déploiement s'exécute sans erreur, remplaçant le contenu du `dist` par lui-même. Il doit détecter que la sauvegarde existe déjà et ne pas essayer de la recréer.

2.  **Test 2.2 : Rollbacks successifs**
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Rollback` deux fois de suite.
    *   **Résultat attendu :**
        *   Le premier rollback se déroule normalement.
        *   La deuxième exécution du rollback échoue avec un message d'erreur clair indiquant que le répertoire `dist_backup` n'existe plus (car il a été renommé).

### Scénario 3 : Gestion des erreurs

1.  **Test 3.1 : Rollback sans déploiement préalable**
    *   **Condition :** Assurez-vous qu'aucun répertoire `dist_backup` n'existe.
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Rollback`.
    *   **Résultat attendu :** Le script s'arrête et affiche une erreur claire indiquant que la sauvegarde est introuvable.

2.  **Test 3.2 : Déploiement avec une source invalide**
    *   **Condition :** Renommer temporairement le répertoire source pour qu'il soit introuvable.
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Deploy`.
    *   **Résultat attendu :** Le script s'arrête et affiche une erreur claire indiquant que le répertoire source n'a pas été trouvé.

3.  **Test 3.3 : Tentative d'exécution sans droits d'administrateur**
    *   **Condition :** Ouvrir un terminal PowerShell standard (non-admin).
    *   **Action :** Essayer d'exécuter le script avec `Deploy` ou `Rollback`.
    *   **Résultat attendu :** Le script refuse de s'exécuter en affichant un message d'erreur lié à la directive `#Requires -RunAsAdministrator`.

## 4. Validation

Chaque test sera considéré comme réussi si le résultat observé correspond au résultat attendu et qu'aucun message d'erreur inattendu n'est généré.