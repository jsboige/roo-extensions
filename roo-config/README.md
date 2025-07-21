# Outils de configuration et déploiement pour Roo

## Table des matières

- [Outils de configuration et déploiement pour Roo](#outils-de-configuration-et-déploiement-pour-roo)
  - [Table des matières](#table-des-matières)
  - [Rôle dans le projet Roo Extensions](#rôle-dans-le-projet-roo-extensions)
  - [Principales fonctionnalités](#principales-fonctionnalités)
    - [Déploiement des modes](#déploiement-des-modes)
    - [Correction des problèmes d'encodage](#correction-des-problèmes-dencodage)
    - [Diagnostic et vérification](#diagnostic-et-vérification)
    - [Configuration des modèles](#configuration-des-modèles)
  - [Structure des outils](#structure-des-outils)
    - [Organisation des dossiers](#organisation-des-dossiers)
    - [Scripts de déploiement et maintenance](#scripts-de-déploiement-et-maintenance)
  - [Guide d'utilisation rapide](#guide-dutilisation-rapide)
    - [Workflow recommandé](#workflow-recommandé)
    - [Déploiement Manuel (Utilisateurs avancés)](#déploiement-manuel-utilisateurs-avancés)
    - [Cas d'utilisation courants](#cas-dutilisation-courants)
      - [Correction d'encodage pour plusieurs fichiers](#correction-dencodage-pour-plusieurs-fichiers)
      - [Sauvegarde et restauration des configurations](#sauvegarde-et-restauration-des-configurations)
      - [Correction d'encodage pour plusieurs fichiers](#correction-dencodage-pour-plusieurs-fichiers-1)
      - [Sauvegarde et restauration des configurations](#sauvegarde-et-restauration-des-configurations-1)
  - [Système de profils](#système-de-profils)
  - [Intégration avec les autres composants](#intégration-avec-les-autres-composants)
    - [Intégration avec roo-modes](#intégration-avec-roo-modes)
    - [Intégration avec les MCPs](#intégration-avec-les-mcps)
    - [Intégration avec le système de tests](#intégration-avec-le-système-de-tests)
  - [Documentation complète](#documentation-complète)
  - [Dépannage](#dépannage)
  - [Contribution](#contribution)
  - [Ressources supplémentaires](#ressources-supplémentaires)

## Rôle dans le projet Roo Extensions

Le composant `roo-config` est un élément central du projet Roo Extensions qui fournit :

1. **Outils de déploiement** : Scripts pour déployer les modes Roo sur différentes plateformes
2. **Outils de correction d'encodage** : Scripts pour résoudre les problèmes d'encodage courants
3. **Outils de diagnostic** : Scripts pour vérifier l'encodage et la validité des fichiers de configuration
4. **Modèles de configuration** : Fichiers de configuration de référence pour les modes, les modèles et les serveurs
5. **Workflow de maintenance** : Ensemble de scripts pour les tâches de maintenance
6. **Système de profils** : Mécanisme permettant de configurer facilement quels modèles utiliser pour chaque niveau de complexité

## Principales fonctionnalités

### Déploiement des modes

Les scripts de déploiement permettent d'installer les modes Roo de différentes manières :
- Déploiement global (pour toutes les instances de VS Code)
- Déploiement local (pour un projet spécifique)
- Déploiement avec correction automatique d'encodage
- Déploiement interactif guidé

Exemple de déploiement simple :
```powershell
.\deployment-scripts\simple-deploy.ps1
```

### Correction des problèmes d'encodage

Les scripts de correction d'encodage résolvent les problèmes courants avec les caractères accentués et les emojis dans les fichiers JSON :
- Détection automatique des problèmes d'encodage
- Correction des séquences de caractères mal encodés
- Réenregistrement des fichiers en UTF-8 sans BOM
- Vérification de la validité du JSON après correction

Exemple de correction d'encodage :
```powershell
.\encoding-scripts\fix-encoding-complete.ps1 -FilePath "chemin\vers\fichier.json"
```

### Diagnostic et vérification

Les scripts de diagnostic permettent de :
- Analyser l'encodage des fichiers JSON
- Détecter les problèmes d'encodage courants
- Vérifier la validité des fichiers JSON
- Vérifier le déploiement des modes

Exemple de diagnostic rapide :
```powershell
.\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json"
```

### Configuration des modèles

Les profils pour différents modèles de langage permettent d'optimiser les performances :
- Profils pour les modèles Qwen3 (0.6B à 235B)
- Paramètres optimaux pour chaque modèle
- Intégration avec l'architecture à 5 niveaux (N5)

## Structure des outils

### Organisation des dossiers

- **`encoding-scripts/`** - [Scripts de correction d'encodage](encoding-scripts/README.md) pour les caractères accentués et les emojis
- **`deployment-scripts/`** - [Scripts de déploiement des modes](deployment-scripts/README.md) (simples et complexes)
- **`diagnostic-scripts/`** - [Scripts de diagnostic et vérification](diagnostic-scripts/README.md) pour l'encodage et la validité des fichiers
- **`config-templates/`** - [Modèles de fichiers de configuration](config-templates/README.md) pour les modes, modèles et serveurs
- **`docs/`** - [Documentation supplémentaire](docs/README.md) et guides d'utilisation
- **`backups/`** - [Fichiers de sauvegarde](backups/README.md) créés automatiquement par les scripts
- **`modes/`** - Fichiers de modes standards
- **`qwen3-profiles/`** - [Profils optimisés](qwen3-profiles/README.md) pour le modèle Qwen3
- **`settings/`** - [Paramètres de configuration](settings/README.md) et scripts de déploiement associés
- **`scheduler/`** - Guides d'installation et de configuration du planificateur Roo

### Scripts de déploiement et maintenance

Le répertoire `roo-config` contient un ensemble de scripts spécialisés pour gérer la configuration de Roo. Il n'y a plus de script interactif unique ; à la place, vous utilisez directement les scripts correspondant à vos besoins.

## Guide d'utilisation rapide

### Workflow recommandé

Le déploiement s'effectue en utilisant les scripts dédiés dans l'ordre approprié.

1.  **Déployer les paramètres globaux (IMPORTANT) :**
    Ce script est le point d'entrée principal. Il initialise les submodules Git (essentiel pour les MCPs) et déploie les configurations de base comme `servers.json`.
    ```powershell
    # Exécuter depuis le répertoire roo-config
    .\settings\deploy-settings.ps1
    ```

2.  **Déployer les modes :**
    Une fois les bases en place, déployez les ensembles de modes dont vous avez besoin.
    ```powershell
    # Exemple pour déployer les modes simple et complexe standards
    .\deployment-scripts\deploy-modes-simple-complex.ps1
    ```
3.  **Vérifier le déploiement** :
    Utilisez les scripts de diagnostic pour vous assurer que tout est en ordre.
    ```powershell
    .\diagnostic-scripts\verify-deployed-modes.ps1
    ```

4.  **Redémarrer Visual Studio Code** et activer les modes.

### Déploiement Manuel (Utilisateurs avancés)

Si vous préférez un contrôle manuel, le déploiement s'effectue en deux temps :

1.  **Déployer les paramètres globaux :**
    ```powershell
    # Déploie le fichier settings.json principal
    .\settings\deploy-settings.ps1
    ```

2.  **Déployer les modes :**
    ```powershell
    # Déploie les modes simple et complexe standards
    .\deployment-scripts\deploy-modes-simple-complex.ps1
    ```
3.  **Vérifier le déploiement** :
    ```powershell
    .\diagnostic-scripts\verify-deployed-modes.ps1
    ```

4.  **Redémarrer Visual Studio Code** et activer les modes.

### Cas d'utilisation courants

#### Correction d'encodage pour plusieurs fichiers

```powershell
# Corriger l'encodage de tous les fichiers JSON dans un répertoire
.\encoding-scripts\fix-encoding-directory.ps1 -DirectoryPath "chemin\vers\repertoire" -FilePattern "*.json"
```

#### Sauvegarde et restauration des configurations

```powershell
# Créer une sauvegarde complète des configurations
.\backup-configurations.ps1 -BackupName "pre-modification"

# Restaurer une sauvegarde
.\restore-configuration.ps1 -BackupName "pre-modification"
```

#### Correction d'encodage pour plusieurs fichiers

```powershell
# Corriger l'encodage de tous les fichiers JSON dans un répertoire
.\encoding-scripts\fix-encoding-directory.ps1 -DirectoryPath "chemin\vers\repertoire" -FilePattern "*.json"
```

#### Sauvegarde et restauration des configurations

```powershell
# Créer une sauvegarde complète des configurations
.\backup-configurations.ps1 -BackupName "pre-modification"

# Restaurer une sauvegarde
.\restore-configuration.ps1 -BackupName "pre-modification"
```

## Système de profils

Le système de profils est une fonctionnalité clé qui permet de configurer facilement quels modèles de langage utiliser pour chaque mode. Les profils sont définis dans des fichiers JSON qui spécifient :

- Le modèle par défaut à utiliser pour les modes simples
- Le modèle à utiliser pour les modes complexes
- Les modèles spécifiques pour chaque niveau de l'architecture n5 (MICRO, MINI, MEDIUM, LARGE, ORACLE)

Le système de profils est géré en combinant les modèles de `config-templates/` avec les scripts de déploiement.

## Intégration avec les autres composants

### Intégration avec roo-modes

Les outils de déploiement de `roo-config` sont conçus pour déployer les modes personnalisés définis dans le répertoire [roo-modes](../roo-modes/README.md). Ils prennent en charge l'architecture à 5 niveaux (n5) et les autres modes personnalisés.

### Intégration avec les MCPs

Les fichiers de configuration dans `roo-config/settings/` incluent la configuration des serveurs MCP. Pour plus d'informations sur les MCPs, consultez le [README des MCPs](../mcps/README.md).

### Intégration avec le système de tests

Les outils de configuration sont utilisés par les scripts de test pour valider le bon fonctionnement des modes et des mécanismes d'escalade/désescalade. Pour plus d'informations sur les tests, consultez le [README des tests](../tests/README.md).

## Documentation complète

Pour une documentation complète sur les différents aspects du projet :

- [Guide d'import/export](docs/guide-import-export.md)
- [Guide d'installation du planificateur Roo](scheduler/Guide_Installation_Roo_Scheduler.md)
- [Guide d'édition des configurations du planificateur](scheduler/Guide_Edition_Directe_Configurations_Roo_Scheduler.md)
- [Documentation des modes Roo](../roo-modes/README.md)
- [Documentation des MCPs](../mcps/README.md)
- [Documentation générale du projet](../docs/README.md)
- [README des profils](README-profile-modes.md)

## Dépannage

Si vous rencontrez des problèmes lors du déploiement :

1. Vérifiez votre déploiement avec les scripts de diagnostic :
   ```powershell
   .\diagnostic-scripts\verify-deployed-modes.ps1
   ```

2. Exécutez le diagnostic rapide d'encodage :
   ```powershell
   .\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json"
   ```

3. Corrigez les problèmes d'encodage :
   ```powershell
   .\encoding-scripts\fix-encoding-complete.ps1 -FilePath "chemin\vers\fichier.json"
   ```

4. Forcez le déploiement avec correction d'encodage :
   ```powershell
   .\deployment-scripts\force-deploy-with-encoding-fix.ps1
   ```

5. Vérifiez le résultat :
   ```powershell
   .\diagnostic-scripts\verify-deployed-modes.ps1
   ```

Si les problèmes persistent, consultez la documentation complète pour des solutions plus avancées.

## Contribution

Ces outils sont en constante amélioration. Si vous rencontrez des problèmes non couverts ou si vous avez des suggestions d'amélioration, n'hésitez pas à contribuer ou à signaler les problèmes.

## Ressources supplémentaires

- [README principal du projet](../README.md)
- [Documentation des modes Roo](../roo-modes/README.md)
- [Documentation des MCPs](../mcps/README.md)
- [Documentation générale du projet](../docs/README.md)

---

Développé pour faciliter le déploiement des modes Roo sur Windows et résoudre les problèmes d'encodage courants.
