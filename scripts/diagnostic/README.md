# Scripts de Diagnostic

Ce dossier contient des outils pour effectuer des diagnostics techniques sur l'environnement et la configuration de l'application Roo.

## Contexte de la Refactorisation

Auparavant, ce dossier contenait un mélange de scripts de diagnostic technique et de validation fonctionnelle. Pour clarifier les responsabilités, les scripts ont été réorganisés :

-   Les outils de **diagnostic technique** (vérification de l'environnement, des chemins, des dépendances, etc.) ont été consolidés dans `run-diagnostic.ps1`.
-   Les scripts de **validation métier** (ex: "est-ce que la configuration des Modes est logique ?", "est-ce que le déploiement a réussi fonctionnellement ?") ont été déplacés dans le nouveau répertoire `../validation`.

## Script Principal

### `run-diagnostic.ps1`

C'est le point d'entrée unique pour le diagnostic technique. Il exécute une série de vérifications pour s'assurer que l'environnement est sain et que les configurations sont structurellement correctes.

#### Fonctionnalités

*   **Vérifications Multiples :** Exécute une suite de tests, incluant la vérification des chemins d'accès, la validité de l'encodage des fichiers de configuration, et la structure des fichiers JSON.
*   **Rapports Clairs :** Génère un rapport indiquant les succès et les échecs, aidant l'utilisateur à identifier rapidement les problèmes.
*   **Extensibilité :** Conçu pour pouvoir ajouter facilement de nouvelles routines de diagnostic.

#### Utilisation

Pour lancer une analyse complète de l'environnement :

```powershell
.\run-diagnostic.ps1
```

Pour cibler le diagnostic sur un aspect spécifique (si le script le supporte via des paramètres) :
```powershell
.\run-diagnostic.ps1 -Check "Encoding"