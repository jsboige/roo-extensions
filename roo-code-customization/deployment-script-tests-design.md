# Conception des Tests Unitaires pour `deploy-fix.ps1`

Ce document décrit la conception de la suite de tests automatisés pour le script PowerShell `deploy-fix.ps1` en utilisant le framework Pester.

## 1. Architecture des Tests

### 1.1. Framework de Test

Nous utiliserons **Pester**, le framework de test de facto pour PowerShell, pour structurer, exécuter et valider nos tests.

### 1.2. Structure du Fichier de Test

Les tests seront contenus dans un unique fichier nommé `deploy-fix.Tests.ps1`. Ce fichier sera placé à la racine du projet ou dans un répertoire de tests dédié (ex: `/tests`). Il contiendra toutes les descriptions de contexte (`Describe`), les cas de test (`It`), et les blocs de préparation/nettoyage.

## 2. Environnement de Test Contrôlé

Pour garantir des tests fiables et reproductibles, nous devons opérer dans un environnement contrôlé et isolé. Nous ne testerons pas sur les vrais répertoires de développement ou d'extension, mais sur une structure de répertoires temporaires créée pour chaque session de test.

### 2.1. Stratégie de Mocking du Système de Fichiers

Nous utiliserons les blocs `BeforeAll` et `AfterAll` de Pester pour gérer le cycle de vie de notre environnement de test.

*   **`BeforeAll` :** Avant l'exécution de tous les tests, ce bloc sera responsable de :
    1.  Créer un répertoire de base temporaire, par exemple `temp_test`.
    2.  À l'intérieur de `temp_test`, créer la structure de répertoires simulée :
        *   `source` : Représente `$sourceDir`. Il contiendra des fichiers factices (ex: `file1.txt`, `file2.js`).
        *   `target` : Représente `$targetDir`. Initialement, il contiendra aussi des fichiers factices pour simuler une installation existante.
    3.  Créer des fichiers de contenu différent dans `source` et `target` pour pouvoir vérifier les opérations de copie.

*   **`AfterAll` :** Après l'exécution de tous les tests, ce bloc assurera le nettoyage complet en :
    1.  Supprimant le répertoire de base `temp_test` et tout son contenu.

*   **`BeforeEach` :** Pour certains contextes, un bloc `BeforeEach` pourra être utilisé pour réinitialiser l'état des répertoires `source` et `target` avant chaque test `It`, garantissant ainsi qu'un test ne soit pas influencé par le précédent.

### 2.2. Exemple de structure de code

```powershell
BeforeAll {
    # Création de l'environnement de test
    $testBasePath = Join-Path $PSScriptRoot "temp_test"
    $script:testSourceDir = Join-Path $testBasePath "source"
    $script:testTargetDir = Join-Path $testBasePath "target"
    $script:testBackupDir = Join-Path $testBasePath "target_backup" # Nom simulé pour le backup

    New-Item -Path $script:testSourceDir -ItemType Directory -Force
    New-Item -Path $script:testTargetDir -ItemType Directory -Force

    # Créer des fichiers de test
    "source_content_v1" | Out-File -FilePath (Join-Path $script:testSourceDir "file1.txt")
    "source_content_v1" | Out-File -FilePath (Join-Path $script:testSourceDir "file2.js")
    "original_content" | Out-File -FilePath (Join-Path $script:testTargetDir "file1.txt")
}

AfterAll {
    # Nettoyage
    Remove-Item -Path $testBasePath -Recurse -Force
}
```

## 3. Scénarios de Test et Assertions

Voici la liste des cas de test à implémenter, organisés par blocs `Describe` et `Context`.

### 3.1. Describe "Action: Deploy"

#### Contexte : Premier déploiement (pas de backup existant)

*   **`It` "doit créer un backup et copier les nouveaux fichiers"**
    *   **État Initial :**
        *   `temp_test/source` existe et contient des fichiers.
        *   `temp_test/target` existe et contient des fichiers.
        *   `temp_test/target_backup` n'existe pas.
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Deploy` (en surchargeant les variables de chemin pour pointer vers notre environnement de test).
    *   **Assertions (Résultat Attendu) :**
        *   `$script:testBackupDir | Should -Exist` : Le répertoire de backup a été créé.
        *   Le contenu de `target_backup` doit être identique à l'ancien contenu de `target`.
        *   `$script:testTargetDir | Should -Exist` : Le répertoire cible existe toujours.
        *   Le contenu de `target` doit être identique au contenu de `source`.

#### Contexte : Déploiement ultérieur (un backup existe déjà)

*   **`It` "doit mettre à jour les fichiers sans modifier le backup existant"**
    *   **État Initial :**
        *   `temp_test/source` contient des fichiers `v2`.
        *   `temp_test/target` contient des fichiers `v1`.
        *   `temp_test/target_backup` existe et contient les fichiers originaux.
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Deploy`.
    *   **Assertions :**
        *   Le timestamp de modification du répertoire `target_backup` ne doit pas avoir changé.
        *   Le contenu de `target` doit être identique au contenu de `source` (`v2`).
        *   Le contenu de `target_backup` doit rester inchangé (fichiers originaux).

#### Contexte : Erreur de chemin

*   **`It` "doit échouer proprement si le répertoire source n'existe pas"**
    *   **État Initial :** Le répertoire `temp_test/source` est supprimé.
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Deploy`.
    *   **Assertions :**
        *   `{ .\deploy-fix.ps1 -Action Deploy } | Should -Throw` : Le script doit lever une exception.
        *   On peut aussi vérifier le message d'erreur pour s'assurer qu'il est informatif.

### 3.2. Describe "Action: Rollback"

#### Contexte : Cas normal

*   **`It` "doit restaurer les fichiers depuis le backup"**
    *   **État Initial :**
        *   `temp_test/target` contient des fichiers modifiés.
        *   `temp_test/target_backup` existe et contient les fichiers originaux.
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Rollback`.
    *   **Assertions :**
        *   `$script:testBackupDir | Should -NotExist` : Le répertoire de backup a été renommé et n'existe plus sous son ancien nom.
        *   `$script:testTargetDir | Should -Exist` : Le répertoire `target` a été restauré.
        *   Le contenu de `target` doit être identique au contenu original du backup.

#### Contexte : Erreur de restauration

*   **`It` "doit échouer proprement si le répertoire de backup n'existe pas"**
    *   **État Initial :** Le répertoire `temp_test/target_backup` est supprimé.
    *   **Action :** Exécuter `.\deploy-fix.ps1 -Action Rollback`.
    *   **Assertions :**
        *   `{ .\deploy-fix.ps1 -Action Rollback } | Should -Throw` : Le script doit lever une exception claire.

## 4. Stratégie d'Exécution

Pour exécuter les tests, la commande suivante sera utilisée :

```powershell
Invoke-Pester -Path .\deploy-fix.Tests.ps1
```

Ce document de conception fournit un cahier des charges complet pour l'implémentation d'une suite de tests robuste pour le script `deploy-fix.ps1`.