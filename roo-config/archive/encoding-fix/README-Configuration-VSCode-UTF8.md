# Configuration VSCode pour l'encodage UTF-8

## Objectif
Ce guide configure VSCode pour utiliser l'encodage UTF-8 de manière cohérente et optimiser le fonctionnement avec l'extension Roo.

## Problèmes résolus
- Caractères français mal affichés dans le terminal VSCode
- Problèmes d'encodage avec l'extension Roo
- Incohérences entre l'encodage des fichiers et du terminal
- Mauvaise détection automatique de l'encodage

## Configuration appliquée

### 1. Paramètres utilisateur globaux
**Fichier :** `%APPDATA%\Code\User\settings.json`

Les paramètres suivants ont été ajoutés/modifiés :
```json
{
    "files.encoding": "utf8",
    "files.autoGuessEncoding": false,
    "files.defaultLanguage": "",
    "terminal.integrated.defaultProfile.windows": "Windows PowerShell",
    "terminal.integrated.profiles.windows": {
        "Windows PowerShell": {
            "path": "C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
            "args": ["-NoExit", "-Command", "chcp 65001"]
        }
    }
}
```

### 2. Paramètres workspace (projet)
**Fichier :** `.vscode/settings.json`

Configuration spécifique au projet pour forcer UTF-8 :
```json
{
    "files.encoding": "utf8",
    "files.autoGuessEncoding": false,
    "files.defaultLanguage": "",
    "terminal.integrated.defaultProfile.windows": "PowerShell",
    "terminal.integrated.profiles.windows": {
        "PowerShell": {
            "source": "PowerShell",
            "icon": "terminal-powershell",
            "args": ["-NoExit", "-Command", "chcp 65001"]
        },
        "Windows PowerShell": {
            "path": "C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
            "args": ["-NoExit", "-Command", "chcp 65001"]
        },
        "Command Prompt": {
            "path": [
                "${env:windir}\\Sysnative\\cmd.exe",
                "${env:windir}\\System32\\cmd.exe"
            ],
            "args": ["/k", "chcp 65001"],
            "icon": "terminal-cmd"
        }
    },
    "roo-cline.preferredLanguage": "French - Français",
    "roo-cline.encoding": "utf8",
    "editor.detectIndentation": true,
    "editor.insertSpaces": true,
    "editor.tabSize": 4,
    "files.eol": "\n",
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true
}
```

## Explication des paramètres

### Encodage des fichiers
- `"files.encoding": "utf8"` : Force l'encodage UTF-8 pour tous les fichiers
- `"files.autoGuessEncoding": false` : Désactive la détection automatique (source d'erreurs)
- `"files.defaultLanguage": ""` : Pas de langage par défaut (détection basée sur l'extension)

### Configuration du terminal
- `"terminal.integrated.defaultProfile.windows": "PowerShell"` : PowerShell par défaut
- `"args": ["-NoExit", "-Command", "chcp 65001"]` : Force la page de code UTF-8 (65001)

### Extension Roo
- `"roo-cline.preferredLanguage": "French - Français"` : Interface en français
- `"roo-cline.encoding": "utf8"` : Encodage UTF-8 pour Roo

### Formatage du code
- `"files.eol": "\n"` : Fins de ligne Unix (LF)
- `"files.trimTrailingWhitespace": true` : Supprime les espaces en fin de ligne
- `"files.insertFinalNewline": true` : Ajoute une ligne vide en fin de fichier

## Tests de validation

### 1. Test automatique
Exécutez le script PowerShell :
```powershell
.\test-encoding.ps1
```

### 2. Test manuel
1. Ouvrez le fichier `test-caracteres-francais.txt`
2. Vérifiez que tous les caractères s'affichent correctement
3. Ouvrez un terminal intégré VSCode
4. Tapez des caractères accentués : `echo "café hôtel naïf"`

### 3. Test de l'extension Roo
1. Lancez une session Roo
2. Demandez à Roo d'afficher du texte avec des accents
3. Vérifiez que les caractères français s'affichent correctement

## Vérifications à effectuer

### Terminal intégré
- [ ] La page de code affiche 65001 : `chcp`
- [ ] Les caractères français s'affichent : `echo "café"`
- [ ] PowerShell démarre avec UTF-8 automatiquement

### Fichiers
- [ ] Nouveaux fichiers créés en UTF-8
- [ ] Fichiers existants ouverts correctement
- [ ] Pas de caractères corrompus à l'ouverture

### Extension Roo
- [ ] Interface en français
- [ ] Réponses avec accents correctes
- [ ] Pas d'erreurs d'encodage dans les logs

## Reproduction sur d'autres machines

### Étapes
1. Copier le fichier `.vscode/settings.json` dans le projet
2. Modifier `%APPDATA%\Code\User\settings.json` avec les paramètres globaux
3. Redémarrer VSCode
4. Exécuter les tests de validation

### Fichiers à copier
- `.vscode/settings.json` (paramètres workspace)
- `test-encoding.ps1` (script de test)
- `test-caracteres-francais.txt` (fichier de test)

## Dépannage

### Problème : Caractères encore mal affichés
**Solution :** 
1. Redémarrer VSCode complètement
2. Vérifier que la page de code est 65001 : `chcp`
3. Forcer la réouverture du fichier avec UTF-8 : `Ctrl+Shift+P` > "Reopen with Encoding" > "UTF-8"

### Problème : Terminal ne démarre pas avec UTF-8
**Solution :**
1. Vérifier le chemin PowerShell dans la configuration
2. Tester manuellement : `powershell -NoExit -Command "chcp 65001"`

### Problème : Extension Roo ne fonctionne pas
**Solution :**
1. Vérifier les paramètres `roo-cline.*` dans settings.json
2. Redémarrer l'extension Roo
3. Vérifier les logs de l'extension

## Historique des modifications
- **2025-05-26** : Configuration initiale UTF-8 pour VSCode et extension Roo
- Résolution des problèmes d'encodage PowerShell
- Ajout des tests de validation

## Notes techniques
- Page de code 65001 = UTF-8 sous Windows
- PowerShell 5.1+ supporte UTF-8 nativement
- VSCode utilise UTF-8 par défaut mais peut être surchargé par la détection automatique
- L'extension Roo nécessite une configuration explicite de l'encodage