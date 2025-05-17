# Guide d'Import et Export de Configuration Roo

Ce guide détaille les étapes pour exporter la configuration de Roo depuis une machine et l'importer sur une autre, permettant ainsi d'harmoniser l'expérience Roo entre différents environnements.

## Localisation des fichiers de configuration

Les fichiers de configuration de Roo sont généralement stockés dans les emplacements suivants :

- **Windows** : `%APPDATA%\roo\`
- **macOS** : `~/Library/Application Support/roo/`
- **Linux** : `~/.config/roo/`

Les fichiers principaux à synchroniser sont :
- `config.json` - Configuration principale
- `modes.json` - Configuration des modes
- `tools.json` - Configuration des outils
- `servers.json` - Configuration des serveurs MCP

## Exportation de la configuration

### Méthode 1 : Via l'interface Roo

1. Ouvrez Roo dans VS Code
2. Cliquez sur l'icône de menu (⋮) dans l'interface Roo
3. Sélectionnez "Export Configuration"
4. Choisissez un emplacement pour sauvegarder le fichier de configuration
5. Cliquez sur "Exporter"

### Méthode 2 : Manuellement

1. Naviguez vers le dossier de configuration Roo (voir emplacements ci-dessus)
2. Copiez les fichiers `config.json`, `modes.json`, `tools.json` et `servers.json`
3. Sauvegardez-les dans un emplacement accessible depuis vos autres machines (par exemple, un dossier synchronisé via Google Drive, Dropbox, etc.)

## Importation de la configuration

### Méthode 1 : Via l'interface Roo

1. Ouvrez Roo dans VS Code sur la machine cible
2. Cliquez sur l'icône de menu (⋮) dans l'interface Roo
3. Sélectionnez "Import Configuration"
4. Naviguez vers l'emplacement où vous avez sauvegardé le fichier de configuration
5. Sélectionnez le fichier et cliquez sur "Importer"
6. Redémarrez VS Code pour appliquer les changements

### Méthode 2 : Manuellement

1. Naviguez vers le dossier de configuration Roo sur la machine cible
2. Sauvegardez les fichiers existants (par précaution)
3. Remplacez les fichiers par ceux que vous avez exportés
4. Redémarrez VS Code pour appliquer les changements

## Script d'automatisation

Pour faciliter ce processus, vous pouvez utiliser le script suivant qui automatise l'export et l'import de la configuration.

### Script PowerShell (Windows)

```powershell
# Chemin vers le dossier de configuration Roo
$rooConfigPath = "$env:APPDATA\roo"
# Chemin vers le dossier de sauvegarde (à adapter selon vos besoins)
$backupPath = "D:\roo-extensions\roo-config\backup"

# Fonction pour exporter la configuration
function Export-RooConfig {
    if (-not (Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force
    }
    
    Copy-Item -Path "$rooConfigPath\config.json" -Destination "$backupPath\config.json" -Force
    Copy-Item -Path "$rooConfigPath\modes.json" -Destination "$backupPath\modes.json" -Force
    Copy-Item -Path "$rooConfigPath\tools.json" -Destination "$backupPath\tools.json" -Force
    Copy-Item -Path "$rooConfigPath\servers.json" -Destination "$backupPath\servers.json" -Force
    
    Write-Host "Configuration Roo exportée avec succès vers $backupPath"
}

# Fonction pour importer la configuration
function Import-RooConfig {
    if (-not (Test-Path $backupPath)) {
        Write-Host "Aucune sauvegarde trouvée dans $backupPath"
        return
    }
    
    # Sauvegarde des fichiers actuels
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $tempBackupPath = "$rooConfigPath\backup_$timestamp"
    New-Item -ItemType Directory -Path $tempBackupPath -Force
    
    Copy-Item -Path "$rooConfigPath\config.json" -Destination "$tempBackupPath\config.json" -Force
    Copy-Item -Path "$rooConfigPath\modes.json" -Destination "$tempBackupPath\modes.json" -Force
    Copy-Item -Path "$rooConfigPath\tools.json" -Destination "$tempBackupPath\tools.json" -Force
    Copy-Item -Path "$rooConfigPath\servers.json" -Destination "$tempBackupPath\servers.json" -Force
    
    # Import des fichiers sauvegardés
    Copy-Item -Path "$backupPath\config.json" -Destination "$rooConfigPath\config.json" -Force
    Copy-Item -Path "$backupPath\modes.json" -Destination "$rooConfigPath\modes.json" -Force
    Copy-Item -Path "$backupPath\tools.json" -Destination "$rooConfigPath\tools.json" -Force
    Copy-Item -Path "$backupPath\servers.json" -Destination "$rooConfigPath\servers.json" -Force
    
    Write-Host "Configuration Roo importée avec succès depuis $backupPath"
    Write-Host "Une sauvegarde de votre configuration précédente a été créée dans $tempBackupPath"
}

# Utilisation:
# Pour exporter: Export-RooConfig
# Pour importer: Import-RooConfig
```

### Script Bash (macOS/Linux)

```bash
#!/bin/bash

# Chemin vers le dossier de configuration Roo
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    ROO_CONFIG_PATH="$HOME/Library/Application Support/roo"
else
    # Linux
    ROO_CONFIG_PATH="$HOME/.config/roo"
fi

# Chemin vers le dossier de sauvegarde (à adapter selon vos besoins)
BACKUP_PATH="$HOME/roo-config-backup"

# Fonction pour exporter la configuration
export_roo_config() {
    mkdir -p "$BACKUP_PATH"
    
    cp "$ROO_CONFIG_PATH/config.json" "$BACKUP_PATH/config.json"
    cp "$ROO_CONFIG_PATH/modes.json" "$BACKUP_PATH/modes.json"
    cp "$ROO_CONFIG_PATH/tools.json" "$BACKUP_PATH/tools.json"
    cp "$ROO_CONFIG_PATH/servers.json" "$BACKUP_PATH/servers.json"
    
    echo "Configuration Roo exportée avec succès vers $BACKUP_PATH"
}

# Fonction pour importer la configuration
import_roo_config() {
    if [ ! -d "$BACKUP_PATH" ]; then
        echo "Aucune sauvegarde trouvée dans $BACKUP_PATH"
        return 1
    fi
    
    # Sauvegarde des fichiers actuels
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    TEMP_BACKUP_PATH="$ROO_CONFIG_PATH/backup_$TIMESTAMP"
    mkdir -p "$TEMP_BACKUP_PATH"
    
    cp "$ROO_CONFIG_PATH/config.json" "$TEMP_BACKUP_PATH/config.json"
    cp "$ROO_CONFIG_PATH/modes.json" "$TEMP_BACKUP_PATH/modes.json"
    cp "$ROO_CONFIG_PATH/tools.json" "$TEMP_BACKUP_PATH/tools.json"
    cp "$ROO_CONFIG_PATH/servers.json" "$TEMP_BACKUP_PATH/servers.json"
    
    # Import des fichiers sauvegardés
    cp "$BACKUP_PATH/config.json" "$ROO_CONFIG_PATH/config.json"
    cp "$BACKUP_PATH/modes.json" "$ROO_CONFIG_PATH/modes.json"
    cp "$BACKUP_PATH/tools.json" "$ROO_CONFIG_PATH/tools.json"
    cp "$BACKUP_PATH/servers.json" "$ROO_CONFIG_PATH/servers.json"
    
    echo "Configuration Roo importée avec succès depuis $BACKUP_PATH"
    echo "Une sauvegarde de votre configuration précédente a été créée dans $TEMP_BACKUP_PATH"
}

# Utilisation:
# Pour exporter: ./script.sh export
# Pour importer: ./script.sh import

if [ "$1" == "export" ]; then
    export_roo_config
elif [ "$1" == "import" ]; then
    import_roo_config
else
    echo "Usage: $0 [export|import]"
    exit 1
fi
```

## Bonnes pratiques

1. **Sauvegardez régulièrement** : Exportez votre configuration après chaque modification importante
2. **Versionnez vos configurations** : Utilisez des noms de fichiers incluant des dates ou des numéros de version
3. **Testez après import** : Vérifiez que tout fonctionne correctement après avoir importé une configuration
4. **Documentez vos personnalisations** : Gardez une trace des modifications que vous apportez à votre configuration

## Résolution des problèmes

Si vous rencontrez des problèmes après avoir importé une configuration :

1. Vérifiez que les chemins vers les outils externes sont corrects pour la machine cible
2. Assurez-vous que tous les plugins et extensions nécessaires sont installés
3. Redémarrez VS Code complètement
4. Si nécessaire, restaurez la configuration précédente à partir de la sauvegarde

## Synchronisation automatique via un dépôt Git

Pour une solution plus avancée, vous pouvez utiliser un dépôt Git pour synchroniser vos configurations :

1. Créez un dépôt Git privé
2. Ajoutez vos fichiers de configuration
3. Sur chaque machine, clonez le dépôt
4. Utilisez des scripts pour copier les fichiers entre le dépôt et le dossier de configuration Roo
5. Utilisez des hooks Git pour automatiser la synchronisation

Cette méthode offre l'avantage de garder un historique complet de vos modifications de configuration.