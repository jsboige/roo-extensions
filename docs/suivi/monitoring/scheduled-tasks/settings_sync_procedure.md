# Documentation de la tâche planifiée : `review_and_sync_repository_settings`

Ce document décrit la tâche planifiée `review_and_sync_repository_settings`, son objectif, ses prérequis, les étapes d'exécution manuelle, la gestion des journaux et les options de personnalisation.

## 1. Objectif de la tâche

La tâche `review_and_sync_repository_settings` est conçue pour automatiser la vérification et la synchronisation des paramètres de configuration des dépôts. Son objectif principal est d'assurer la cohérence des paramètres à travers tous les dépôts gérés, en identifiant les divergences et en appliquant les configurations standardisées. Cela permet de maintenir un environnement de développement et de déploiement uniforme et sécurisé.

## 2. Prérequis

Pour exécuter cette tâche, les prérequis suivants sont nécessaires :

- **Environnement d'exécution** : Un environnement compatible avec les scripts PowerShell (Windows) ou Bash (Linux/macOS) si des scripts multiplateformes sont utilisés.
- **Accès aux dépôts** : Un jeton d'accès personnel (PAT) ou une clé SSH configurée avec les permissions nécessaires pour lire et modifier les paramètres des dépôts cibles (par exemple, sur GitHub, GitLab, Azure DevOps). Ce jeton doit être stocké de manière sécurisée (par exemple, dans un gestionnaire de secrets).
- **Outils de gestion de version** : Git doit être installé et configuré sur la machine où la tâche est exécutée.
- **Dépendances spécifiques** : Si le script utilise des modules PowerShell ou des bibliothèques Python/Node.js, ceux-ci doivent être installés (par exemple, `posh-git` pour PowerShell, `PyGithub` pour Python).

## 3. Étapes d'exécution manuelles

Bien que cette tâche soit planifiée, il est possible de l'exécuter manuellement pour des tests, des validations ou des synchronisations urgentes.

1. **Préparation de l'environnement** :
   - Assurez-vous que tous les prérequis listés ci-dessus sont satisfaits.
   - Naviguez vers le répertoire des scripts de la tâche : `scheduled-tasks/scripts/`.

2. **Exécution du script (exemple PowerShell)** :
   - Ouvrez une console PowerShell.
   - Exécutez le script principal de la tâche (le nom du script est un exemple et peut varier) :

     ```powershell
     .\sync-repository-settings.ps1 -ManualRun $true
     ```

     (Le paramètre `-ManualRun $true` est un exemple pour indiquer une exécution manuelle, permettant au script de demander une validation avant d'appliquer les changements).

3. **Validation manuelle** :
   - Après l'exécution, le script devrait générer un rapport des divergences détectées et des actions proposées.
   - Examinez attentivement ce rapport. Si le script est configuré pour le faire, il peut vous demander une confirmation avant d'appliquer les modifications.
   - Confirmez ou annulez les modifications selon les besoins.

## 4. Journalisation

La tâche `review_and_sync_repository_settings` enregistre toutes ses opérations et les résultats dans un fichier journal dédié.

- **Emplacement du journal** : Les journaux sont stockés dans :
  `scheduled-tasks/logs/settings_sync_log.json`

- **Interprétation des journaux** : Le fichier `settings_sync_log.json` est au format JSON et contient des entrées horodatées. Chaque entrée inclut généralement :
  - `timestamp` : Horodatage de l'événement.
  - `level` : Niveau de gravité (par exemple, `INFO`, `WARNING`, `ERROR`).
  - `message` : Description de l'action ou de l'événement.
  - `repository` : Nom du dépôt concerné.
  - `details` : Informations supplémentaires, telles que les paramètres modifiés, les erreurs rencontrées, ou les résultats de la comparaison.

  Pour interpréter les journaux, vous pouvez utiliser un éditeur de texte compatible JSON ou un outil de visualisation de journaux. Les entrées avec le niveau `ERROR` ou `WARNING` nécessitent une attention particulière.

## 5. Personnalisation/Configuration

La tâche `review_and_sync_repository_settings` est conçue pour être configurable afin de s'adapter à différents environnements et besoins.

- **Fichier de configuration principal** : Les paramètres de la tâche sont généralement définis dans un fichier de configuration séparé, par exemple :
  `scheduled-tasks/config/settings_sync_config.json` (ce fichier n'existe pas encore et devrait être créé).

- **Paramètres configurables (exemples)** :
  - `repositories_to_monitor` : Une liste des dépôts à inclure ou à exclure de la synchronisation.
  - `standard_settings_template` : Un chemin vers un fichier (par exemple, JSON ou YAML) définissant les paramètres de dépôt souhaités (branches par défaut, règles de protection, intégrations, etc.).
  - `external_sources` : URLs ou chemins vers des sources externes de configuration (par exemple, un service centralisé de gestion des paramètres).
  - `dry_run_mode` : Un paramètre booléen pour exécuter la tâche sans appliquer de modifications, utile pour la validation.
  - `notification_recipients` : Adresses e-mail ou canaux de notification pour les alertes (par exemple, en cas de divergences critiques ou d'erreurs).
  - `sync_interval` : La fréquence de synchronisation (si non gérée par le planificateur de tâches du système d'exploitation).

Ces configurations permettent d'adapter le comportement de la tâche sans modifier le code source du script.

---

*Document migré depuis `scheduled-tasks/docs/` le 2026-01-22*
