# Configuration des modes personnalisés Roo

Ce répertoire contient les configurations des modes personnalisés Roo et les outils pour les déployer.

## Structure des fichiers

- `modes/` : Répertoire contenant les différentes configurations de modes
  - `standard-modes.json` : Configuration standard des modes personnalisés
  - Vous pouvez ajouter d'autres configurations selon vos besoins

- `deploy-modes.ps1` : Script PowerShell pour déployer les configurations de modes

## Mécanisme de configuration de Roo

Roo peut utiliser deux types de configurations pour les modes personnalisés :

1. **Configuration globale** : Appliquée à toutes les instances de VS Code
   - Fichier : `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json`
   - Avantage : Les modes sont disponibles dans tous les projets
   - Inconvénient : Nécessite une mise à jour manuelle si le dépôt est mis à jour

2. **Configuration locale** : Appliquée uniquement au projet courant
   - Fichier : `.roomodes` à la racine du projet
   - Avantage : Spécifique au projet, suit les mises à jour du dépôt
   - Inconvénient : Nécessite un déploiement dans chaque projet

## Utilisation du script de déploiement

Le script `deploy-modes.ps1` permet de déployer une configuration de modes soit globalement, soit localement.

### Syntaxe

```powershell
.\deploy-modes.ps1 [-ConfigFile <chemin>] [-DeploymentType <global|local>] [-Force]
```

### Paramètres

- `-ConfigFile` : Chemin du fichier de configuration à déployer (relatif au répertoire `roo-modes/`)
  - Par défaut : `modes/standard-modes.json`

- `-DeploymentType` : Type de déploiement
  - `global` : Déploie la configuration globalement (pour toutes les instances de VS Code)
  - `local` : Déploie la configuration localement (uniquement pour ce projet)
  - Par défaut : `global`

- `-Force` : Force le remplacement du fichier de destination sans demander de confirmation

### Exemples

1. Déployer la configuration standard globalement :
   ```powershell
   .\roo-modes\deploy-modes.ps1
   ```

2. Déployer la configuration standard localement :
   ```powershell
   .\roo-modes\deploy-modes.ps1 -DeploymentType local
   ```

3. Déployer une configuration personnalisée globalement :
   ```powershell
   .\roo-modes\deploy-modes.ps1 -ConfigFile modes/ma-config.json
   ```

4. Déployer une configuration personnalisée localement sans confirmation :
   ```powershell
   .\roo-modes\deploy-modes.ps1 -ConfigFile modes/ma-config.json -DeploymentType local -Force
   ```

## Création de configurations personnalisées

Vous pouvez créer vos propres configurations de modes en copiant et modifiant le fichier `modes/standard-modes.json`. Par exemple :

1. Créez un nouveau fichier dans le répertoire `modes/` :
   ```powershell
   Copy-Item -Path "roo-modes/modes/standard-modes.json" -Destination "roo-modes/modes/ma-config.json"
   ```

2. Modifiez le fichier selon vos besoins.

3. Déployez la configuration comme décrit ci-dessus.

## Relation avec roo-settings

Le répertoire `roo-modes` se concentre uniquement sur la configuration des modes personnalisés, tandis que le répertoire `roo-settings` gère les configurations générales de Roo. Les deux sont complémentaires :

- **roo-modes** : Définit les modes personnalisés, leurs propriétés et comportements
- **roo-settings** : Définit les paramètres globaux et les associations entre modes et profils d'API

Pour une configuration complète de Roo, vous devrez généralement déployer à la fois :
1. Une configuration de modes (via `roo-modes/deploy-modes.ps1`)
2. Une configuration générale (via `roo-settings/deploy-settings.ps1`)

Pour plus d'informations sur les configurations générales, consultez la [documentation de roo-settings](../roo-settings/README.md).

## Recommandations

- Pour un environnement de développement personnel, utilisez le déploiement global pour avoir les modes disponibles dans tous vos projets.
- Pour un projet partagé, utilisez le déploiement local pour que chaque développeur ait la même configuration.
- Commitez vos configurations personnalisées dans le répertoire `modes/` pour les partager avec l'équipe.
- Après chaque déploiement, redémarrez Visual Studio Code pour appliquer les changements.