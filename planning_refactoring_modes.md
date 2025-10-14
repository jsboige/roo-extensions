# Plan de Refactoring de la Configuration des Modes Roo

## 1. Contexte et Objectifs

L'objectif de ce refactoring est de réorganiser la structure de configuration des modes Roo pour refléter clairement les trois catégories de modes définies par l'utilisateur : Natifs, "n2" (anciennement simple/complex), et "n5" (architecture à 5 niveaux de granularité). Cette réorganisation vise à améliorer la clarté, la maintenabilité et la cohérence des configurations.

## 2. Proposition de Nouvelle Structure de Dossiers et Fichiers

```
d:/roo-extensions/
├── roo-config/
│   └── settings/
│       ├── modes-base.json         // Définitions de base (slug, nom, desc, etc.) pour Natifs et n2
│       ├── servers.json
│       └── settings.json
└── roo-modes/
    ├── configs/
    │   ├── native/
    │   │   └── native-custom-instructions.json  // CustomInstructions pour les modes Natifs
    │   ├── n2/
    │   │   ├── n2-custom-instructions.json      // CustomInstructions pour tous les modes n2
    │   │   └── n2-family-definitions.json     // FamilyDefinitions et Transitions pour n2
    │   └── n5/
    │       ├── n5-custom-instructions.json      // Agrégation des CustomInstructions pour tous les modes n5 (similaire à l'actuel n5-modes-roo-compatible.json)
    │       ├── n5-family-definitions.json     // FamilyDefinitions et Transitions pour n5
    │       ├── levels/                        // Configurations spécifiques par niveau n5
    │       │   ├── micro-level-config.json
    │       │   ├── mini-level-config.json
    │       │   ├── medium-level-config.json
    │       │   ├── large-level-config.json
    │       │   └── oracle-level-config.json
    │       └── (autres fichiers de config n5 spécifiques si nécessaire, ex: custom-n5-modes.json s'il a un rôle distinct)
    ├── custom/
    ├── docs/
    ├── examples/
    └── README.md
```

**Justification de la structure proposée :**

*   **`roo-config/settings/modes-base.json`**: Centralise les définitions fondamentales (slug, nom, description, allowedFilePatterns, defaultModel, tools) pour les modes Natifs et "n2". Cela simplifie la gestion des paramètres de base. Les `customInstructions` et les définitions de famille sont séparées pour une meilleure modularité.
*   **`roo-modes/configs/native/`**: Dossier dédié aux configurations spécifiques des modes Natifs, principalement leurs `customInstructions`.
*   **`roo-modes/configs/n2/`**: Dossier dédié pour la famille "n2".
    *   `n2-custom-instructions.json`: Regroupe toutes les `customInstructions` pour les modes de la famille "n2" (par exemple, `code-n2-simple`, `code-n2-complex`).
    *   `n2-family-definitions.json`: Contient les `familyDefinitions` (par exemple, "n2-simple", "n2-complex") et les `allowedFamilyTransitions` pour cette famille.
*   **`roo-modes/configs/n5/`**: Structure clarifiée pour la famille "n5".
    *   `n5-custom-instructions.json`: Maintient l'agrégation des `customInstructions` pour tous les modes "n5", similaire au rôle de l'actuel `n5-modes-roo-compatible.json`.
    *   `n5-family-definitions.json`: Contient les `familyDefinitions` (par exemple, "n5") et les `allowedFamilyTransitions` pour cette famille.
    *   `roo-modes/configs/n5/levels/`: Nouveau sous-dossier pour héberger les configurations spécifiques à chaque niveau de complexité "n5" (micro, mini, etc.), contenant les `complexityLevel` et potentiellement des `customInstructions` spécifiques au niveau si elles ne sont pas déjà dans `n5-custom-instructions.json`.

## 3. Fichiers à Renommer ou à Déplacer

**Fichiers à déplacer et potentiellement renommer/fusionner :**

1.  **`roo-config/settings/modes.json`**
    *   Déplacer vers : `roo-config/settings/modes-base.json`
    *   Action : Extraire les `customInstructions` et `familyDefinitions` vers les nouveaux fichiers dédiés.
2.  **`roo-modes/configs/standard-modes.json`**
    *   Actions :
        *   Les `customInstructions` des modes Natifs vers `roo-modes/configs/native/native-custom-instructions.json`.
        *   Les `customInstructions` des modes "simple"/"complex" (futurs "n2") vers `roo-modes/configs/n2/n2-custom-instructions.json`.
        *   Les `familyDefinitions` et `allowedFamilyTransitions` pour "simple"/"complex" vers `roo-modes/configs/n2/n2-family-definitions.json`.
        *   Ce fichier source sera ensuite supprimé ou archivé.
3.  **`roo-modes/configs/vscode-custom-modes.json`**
    *   Action : Analyser son contenu. S'il est redondant avec `standard-modes.json`, le supprimer après avoir migré toute information unique pertinente. S'il a un but spécifique pour VSCode qui doit être maintenu, évaluer comment l'intégrer dans la nouvelle structure (potentiellement en gardant un fichier spécifique pour VSCode si les `customInstructions` diffèrent significativement, ou en fusionnant). Pour ce plan, nous visons sa rationalisation/suppression.
4.  **`roo-modes/n5/configs/n5-modes-roo-compatible.json`**
    *   Déplacer/Renommer en : `roo-modes/configs/n5/n5-custom-instructions.json` (pour les `customInstructions` agrégées).
    *   Action : Extraire les `familyDefinitions` et `allowedFamilyTransitions` vers `roo-modes/configs/n5/n5-family-definitions.json`.
5.  **Fichiers de niveaux N5 (e.g., `micro-modes.json`, `mini-modes.json`, etc.) dans `roo-modes/n5/configs/`**
    *   Déplacer vers : `roo-modes/configs/n5/levels/` (par exemple, `micro-level-config.json`).
    *   Action : S'assurer qu'ils contiennent principalement les `complexityLevel` et que les `customInstructions` sont soit référencées depuis `n5-custom-instructions.json` soit incluses si elles sont très spécifiques au niveau et non génériques.
6.  **`roo-modes/n5/configs/custom-n5-modes.json`**
    *   Action : Évaluer son contenu. S'il s'agit de modes "n5" personnalisés supplémentaires, ils pourraient rester dans `roo-modes/configs/n5/` ou être intégrés dans `n5-custom-instructions.json` si cela a du sens.

**Nouveaux fichiers à créer :**

*   `roo-config/settings/modes-base.json` (par scission de `roo-config/settings/modes.json`)
*   `roo-modes/configs/native/native-custom-instructions.json`
*   `roo-modes/configs/n2/n2-custom-instructions.json`
*   `roo-modes/configs/n2/n2-family-definitions.json`
*   `roo-modes/configs/n5/n5-family-definitions.json`
*   Les fichiers dans `roo-modes/configs/n5/levels/` (par exemple, `micro-level-config.json`)

## 4. Modifications de Contenu à Prévoir

*   **Mise à jour des `slugs` pour la famille "n2" :**
    *   Les modes comme `code-simple` deviendront `code-n2-simple` (ou une nomenclature "n2" équivalente, par exemple `code-n2-1`, `code-n2-2` si on veut numéroter les niveaux de complexité n2).
    *   Cela impactera `roo-config/settings/modes-base.json` (pour les slugs de base) et tous les fichiers référençant ces slugs dans les `customInstructions` ou `familyDefinitions`.
*   **Mise à jour des `familyDefinitions` :**
    *   Dans `roo-modes/configs/n2/n2-family-definitions.json` :
        *   Définir les familles (par exemple, "n2-simple", "n2-complex" ou "n2-level1", "n2-level2").
        *   Lister les slugs des modes "n2" correspondants (par exemple, `code-n2-simple`, `debug-n2-simple`, etc.).
    *   Dans `roo-modes/configs/n5/n5-family-definitions.json` :
        *   S'assurer que la famille "n5" est correctement définie avec tous les slugs des modes "n5".
*   **Mise à jour des `allowedFamilyTransitions` :**
    *   Vérifier et mettre à jour ces sections dans `n2-family-definitions.json` et `n5-family-definitions.json` pour refléter les nouvelles familles et slugs.
*   **Mise à jour des références de chemin dans les scripts de chargement/parsing des modes :**
    *   Tout script qui charge ces fichiers JSON devra être mis à jour pour pointer vers les nouveaux emplacements et noms de fichiers.
*   **Consolidation des `customInstructions` :**
    *   S'assurer qu'il n'y a pas de duplication de `customInstructions` entre les anciens fichiers et les nouveaux.
    *   Pour les modes "n5", vérifier si les `customInstructions` dans les fichiers de niveau (par exemple, `micro-level-config.json`) sont vraiment spécifiques au niveau ou si elles peuvent être généralisées et centralisées dans `n5-custom-instructions.json`.

## 5. Scripts Potentiellement Impactés

*   **Scripts PowerShell dans `roo-config/scheduler/`** (par exemple, `deploy-complete-system.ps1`, `update-system.ps1`, `self-improvement.ps1`) : Ces scripts pourraient charger ou manipuler les fichiers de configuration des modes. Ils devront être vérifiés pour toute référence aux anciens chemins/noms de fichiers.
*   **Scripts de déploiement ou de test spécifiques aux modes** (par exemple, `roo-modes/n5/deploy-n5-micro-mini-modes.ps1`) : Même vérification que ci-dessus.
*   **Code interne de l'application Roo qui charge et interprète les configurations des modes** : Cette partie du code devra être adaptée pour lire la nouvelle structure de fichiers et interpréter correctement les configurations séparées (base, customInstructions, familyDefinitions, levelConfigs).
*   **Tout autre script personnalisé ou outil** qui pourrait interagir avec la configuration des modes (par exemple, des scripts de validation, de reporting, etc.). Il faudra faire une recherche globale dans le projet pour les anciens noms de fichiers.

## 6. Étapes Recommandées pour le Refactoring (Séquence)

1.  **Préparation et Sauvegarde :**
    *   Créer une branche Git dédiée pour ce refactoring.
    *   Sauvegarder l'intégralité des répertoires `roo-config/` et `roo-modes/` avant de commencer.
2.  **Création de la Nouvelle Structure de Dossiers :**
    *   Créer les nouveaux dossiers : `roo-modes/configs/native/`, `roo-modes/configs/n2/`, `roo-modes/configs/n5/levels/`.
3.  **Migration des Configurations des Modes Natifs :**
    *   Copier le contenu pertinent de `roo-config/settings/modes.json` (définitions de base des modes natifs) vers le futur `roo-config/settings/modes-base.json`.
    *   Copier les `customInstructions` des modes natifs depuis `roo-modes/configs/standard-modes.json` vers `roo-modes/configs/native/native-custom-instructions.json`.
4.  **Migration des Configurations des Modes "n2" :**
    *   Décider de la nouvelle nomenclature des slugs "n2" (par exemple, `code-n2-simple` ou `code-n2-level1`).
    *   Mettre à jour les slugs dans la section correspondante de `roo-config/settings/modes-base.json` (copiée depuis l'ancien `roo-config/settings/modes.json`).
    *   Copier et adapter les `customInstructions` des modes "simple"/"complex" depuis `roo-modes/configs/standard-modes.json` vers `roo-modes/configs/n2/n2-custom-instructions.json`, en mettant à jour les références internes si nécessaire.
    *   Créer `roo-modes/configs/n2/n2-family-definitions.json` et y migrer/adapter les `familyDefinitions` et `allowedFamilyTransitions` depuis `roo-modes/configs/standard-modes.json` en utilisant les nouveaux slugs "n2".
5.  **Migration des Configurations des Modes "n5" :**
    *   Déplacer et renommer `roo-modes/n5/configs/n5-modes-roo-compatible.json` en `roo-modes/configs/n5/n5-custom-instructions.json`.
    *   Créer `roo-modes/configs/n5/n5-family-definitions.json` et y migrer les `familyDefinitions` et `allowedFamilyTransitions` depuis `n5-custom-instructions.json` (anciennement `n5-modes-roo-compatible.json`).
    *   Déplacer les fichiers de configuration de niveau (par exemple, `micro-modes.json`) de `roo-modes/n5/configs/` vers `roo-modes/configs/n5/levels/` et les renommer (par exemple, `micro-level-config.json`).
    *   Vérifier le contenu de ces fichiers de niveau pour s'assurer qu'ils se concentrent sur `complexityLevel` et que les `customInstructions` sont gérées de manière centralisée ou bien justifiées si spécifiques au niveau.
    *   Traiter `custom-n5-modes.json` : l'intégrer ou le conserver séparément en fonction de son rôle.
6.  **Nettoyage des Anciens Fichiers :**
    *   Supprimer (ou archiver) les anciens fichiers : `roo-config/settings/modes.json` (après scission), `roo-modes/configs/standard-modes.json`, `roo-modes/configs/vscode-custom-modes.json` (si jugé redondant/fusionné).
    *   Supprimer les fichiers de niveau N5 de leur ancien emplacement `roo-modes/n5/configs/`.
7.  **Mise à Jour du Code de Chargement des Modes :**
    *   Identifier et modifier le code de l'application Roo qui charge et interprète les configurations des modes pour qu'il utilise la nouvelle structure de fichiers et la logique de configuration éclatée.
8.  **Mise à Jour des Scripts Impactés :**
    *   Parcourir les scripts identifiés à l'étape 5 et mettre à jour toutes les références aux anciens chemins et noms de fichiers de configuration.
9.  **Tests Approfondis :**
    *   Tester le chargement de tous les modes (Natifs, n2, n5).
    *   Tester les transitions entre familles et entre niveaux de complexité.
    *   Tester les fonctionnalités spécifiques des modes qui dépendent des `customInstructions`.
    *   Exécuter tous les scripts impactés pour s'assurer de leur bon fonctionnement.
10. **Documentation :**
    *   Mettre à jour toute documentation interne qui décrit la structure de configuration des modes.
    *   Documenter la nouvelle structure dans le `README.md` principal de `roo-modes/` ou un document dédié.

Ce plan devrait fournir une base solide pour le refactoring.