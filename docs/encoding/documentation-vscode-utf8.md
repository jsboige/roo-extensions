# Documentation : Configuration VSCode pour UTF-8

**Date**: 2025-11-26
**Version**: 1.0
**Statut**: Validé

## 1. Vue d'ensemble

Cette documentation détaille la configuration standardisée de Visual Studio Code pour garantir un support UTF-8 complet et cohérent au sein de l'écosystème Roo Extensions. Cette configuration s'inscrit dans l'architecture unifiée d'encodage (Niveau 3).

## 2. Configuration Appliquée

La configuration suivante a été appliquée au fichier `.vscode/settings.json` (niveau workspace) ou `settings.json` (niveau utilisateur).

### 2.1 Encodage des Fichiers

```json
{
    "files.encoding": "utf8",
    "files.autoGuessEncoding": false,
    "files.eol": "\n"
}
```

*   **`files.encoding`: "utf8"** : Force l'encodage UTF-8 pour tous les fichiers par défaut.
*   **`files.autoGuessEncoding`: false** : Désactive la détection automatique qui peut parfois identifier incorrectement des fichiers UTF-8 sans BOM comme étant en ANSI/Windows-1252.
*   **`files.eol`: "\n"** : Standardise les fins de ligne sur LF (Line Feed) pour une compatibilité cross-platform optimale.

### 2.2 Terminal Intégré

```json
{
    "terminal.integrated.defaultProfile.windows": "PowerShell UTF-8",
    "terminal.integrated.profiles.windows": {
        "PowerShell UTF-8": {
            "source": "PowerShell",
            "args": [
                "-NoExit",
                "-Command",
                "chcp 65001"
            ],
            "icon": "terminal-powershell"
        }
    },
    "terminal.integrated.inheritEnv": true
}
```

*   **`terminal.integrated.defaultProfile.windows`** : Définit le profil "PowerShell UTF-8" comme profil par défaut.
*   **`PowerShell UTF-8`** : Crée un profil spécifique qui exécute `chcp 65001` au démarrage pour basculer la page de code de la console en UTF-8.
*   **`terminal.integrated.inheritEnv`: true** : Assure que le terminal hérite des variables d'environnement système (notamment celles configurées par `Set-StandardizedEnvironment.ps1`).

## 3. Validation

Un script de validation automatisé est disponible pour vérifier la conformité de la configuration.

**Script**: `scripts/encoding/Validate-VSCodeConfig.ps1`

**Utilisation**:
```powershell
.\scripts\encoding\Validate-VSCodeConfig.ps1
```

**Critères de validation**:
1.  `files.encoding` doit être "utf8".
2.  `files.autoGuessEncoding` doit être `false`.
3.  `files.eol` doit être `\n`.
4.  Le profil par défaut doit être "PowerShell UTF-8".
5.  Le profil "PowerShell UTF-8" doit exister et contenir l'argument `chcp 65001`.

## 4. Dépannage

Si des caractères s'affichent mal dans le terminal intégré :
1.  Vérifiez que le profil actif est bien "PowerShell UTF-8".
2.  Exécutez `[Console]::OutputEncoding` dans le terminal pour vérifier que l'encodage est bien UTF-8 (CodePage 65001).
3.  Vérifiez que la police du terminal supporte les caractères affichés (recommandé : Cascadia Code).

Si des fichiers s'ouvrent avec le mauvais encodage :
1.  Vérifiez la barre d'état en bas à droite de VSCode.
2.  Cliquez sur l'encodage et sélectionnez "Reopen with Encoding" -> "UTF-8".
3.  Assurez-vous que le fichier ne contient pas de caractères invalides pour UTF-8.