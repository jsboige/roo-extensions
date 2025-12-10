# Politique de Stockage des Données et Séparation des Préoccupations

## 1. Principe Fondamental : "Code in Git, Data in Shared Drive"

Pour garantir la maintenabilité, la sécurité et la performance du dépôt `roo-extensions`, nous appliquons une séparation stricte entre le code source (et sa configuration) et les données opérationnelles.

**Règle d'Or :**
> Le dépôt Git ne doit contenir que ce qui est nécessaire pour *construire* et *exécuter* le logiciel. Les données générées, les états persistants volumineux et les informations sensibles doivent être stockés à l'extérieur.

## 2. Classification des Artefacts

### 2.1. Ce qui va dans Git (Code & Config)
*   **Code Source :** `.ts`, `.js`, `.py`, `.ps1`, etc.
*   **Documentation :** `.md`, diagrammes Mermaid.
*   **Configuration Statique :** Fichiers de configuration nécessaires au démarrage (ex: `roo-config/settings/modes.json`), modèles de configuration.
*   **Tests :** Code de test, petits fichiers de fixtures (taille < 1Mo).
*   **Scripts d'Infrastructure :** Scripts de déploiement, de migration, de maintenance.

### 2.2. Ce qui va dans le Stockage Partagé (Data)
*   **État Partagé (`.shared-state`) :**
    *   Inventaires machines (`inventory/`)
    *   Baselines de configuration (`baselines/`)
    *   Logs d'exécution centralisés
    *   Historique des synchronisations
*   **Données Volumineuses :**
    *   Exports de bases de données
    *   Gros fichiers de logs
    *   Artefacts binaires lourds
*   **Données Sensibles (si non gérées par un gestionnaire de secrets) :**
    *   Tokens d'accès (jamais en clair, même sur le drive si possible)
    *   Configurations spécifiques à l'environnement contenant des secrets

## 3. Implémentation Technique

### 3.1. Exclusion Git (`.gitignore`)
Le fichier `.gitignore` doit explicitement exclure les répertoires de données :
```gitignore
# État local et partagé
.state/
.shared-state/

# Logs et sorties
logs/
outputs/
reports/ (sauf rapports d'architecture/analyse validés)
```

### 3.2. Configuration RooSync
RooSync est configuré pour utiliser un chemin externe pour le stockage des données partagées.
*   **Variable d'environnement :** `ROOSYNC_SHARED_PATH` (ou configuration équivalente) pointe vers le dossier synchronisé (ex: Google Drive).
*   **Mécanisme de Fallback :** En l'absence de stockage externe configuré, un dossier local (exclu de git) peut être utilisé pour le développement, mais jamais commité.

## 4. Migration et Maintenance

*   **Migration :** Tout déplacement de données vers le stockage externe doit être accompagné d'un script de migration (`scripts/migrate-roosync-storage.ps1`) pour assurer la continuité.
*   **Vérification :** Les processus de CI/CD ou les hooks de pré-commit doivent idéalement vérifier qu'aucun fichier de données volumineux n'est ajouté au dépôt.

## 5. Exceptions

Les seules exceptions tolérées sont :
*   Fichiers de configuration par défaut nécessaires au bootstrap de l'application.
*   Petits jeux de données de test (fixtures) nécessaires aux tests unitaires.
*   Documentation générée (rapports d'analyse) qui a une valeur historique pour le projet (dans `docs/rapports/`).