# Conception du Script de Déploiement : deploy-fix.ps1

## 1. Objectif

Ce document détaille la conception d'un script PowerShell (`deploy-fix.ps1`) destiné à automatiser le déploiement de modifications ("hot-swap") d'une extension VSCode et à permettre une restauration rapide (`rollback`) de la version originale pour faciliter les tests.

## 2. Spécifications Générales

*   **Nom du Script :** `deploy-fix.ps1`
*   **Emplacement :** Le script sera situé à la racine du workspace : `c:/dev/roo-extensions/`.

## 3. Chemins Clés (Variables)

Le script utilisera les variables suivantes pour définir les chemins critiques :

*   `$sourceDir`: Le répertoire contenant les modifications à déployer.
    *   **Valeur :** `c:/dev/roo-extensions/roo-code/dist`
*   `$targetDir`: Le répertoire de destination où l'extension est installée.
    *   **Valeur :** `C:/Users/jsboi/.vscode/extensions/rooveterinaryinc.roo-cline-3.25.6/dist/`
*   `$backupDir`: Le nom du répertoire de sauvegarde de la version originale de l'extension.
    *   **Valeur :** `C:/Users/jsboi/.vscode/extensions/rooveterinaryinc.roo-cline-3.25.6/dist_backup/`

## 4. Paramètres du Script

Le script acceptera un seul paramètre obligatoire :

*   **`-Action`** `[string]` (Obligatoire)
    *   Définit l'opération à effectuer.
    *   **Valeurs possibles :**
        *   `Deploy` : Déploie les modifications.
        *   `Rollback` : Restaure la version originale.

## 5. Logique de Fonctionnement

### Action : Deploy

La logique suivante sera exécutée lorsque `-Action Deploy` est spécifié :

1.  **Vérification de la sauvegarde :** Le script vérifie si le répertoire `$backupDir` existe.
2.  **Création de la sauvegarde :** Si `$backupDir` n'existe pas, le script renomme `$targetDir` en `$backupDir`. Cela garantit que la version originale est sauvegardée avant toute modification.
3.  **Préparation de la destination :** Le script crée un nouveau répertoire `$targetDir` vide.
4.  **Copie des fichiers :** Le contenu complet de `$sourceDir` est copié récursivement dans `$targetDir`.
5.  **Confirmation :** Un message de succès est affiché, confirmant que le déploiement est terminé.

### Action : Rollback

La logique suivante sera exécutée lorsque `-Action Rollback` est spécifié :

1.  **Vérification de la sauvegarde :** Le script vérifie si le répertoire `$backupDir` existe. Si ce n'est pas le cas, il affiche un message d'erreur clair (ex: "Aucune sauvegarde trouvée. Impossible de restaurer.") et s'arrête.
2.  **Suppression des modifications :** Le répertoire `$targetDir` (contenant les fichiers du `Deploy`) est supprimé.
3.  **Restauration :** Le répertoire `$backupDir` est renommé en `$targetDir`, restaurant ainsi l'extension à son état d'origine.
4.  **Confirmation :** Un message de succès est affiché pour confirmer que la restauration est terminée.

## 6. Gestion d'Erreurs

Des vérifications de base seront implémentées pour assurer la robustesse du script :
*   Valider que le paramètre `-Action` a une des valeurs autorisées (`Deploy` ou `Rollback`).
*   Avant la copie, vérifier que le chemin source (`$sourceDir`) existe.
*   Avant toute opération, vérifier l'existence des chemins pertinents.
*   Utiliser des blocs `try/catch` pour les opérations sur le système de fichiers (Copy-Item, Rename-Item, Remove-Item) afin de capturer et d'afficher les erreurs inattendues (ex: problèmes de permissions, fichiers en cours d'utilisation).