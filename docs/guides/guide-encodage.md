# Guide de gestion de l'encodage dans le projet roo-extensions

Ce document explique les problèmes d'encodage rencontrés dans le projet roo-extensions et comment les résoudre de manière durable.

## Problèmes identifiés

Plusieurs types de problèmes d'encodage ont été identifiés dans le projet :

1. **Double ou triple encodage UTF-8** : Caractères comme "é" apparaissant sous la forme "ÃƒÂ©" ou "ÃƒÆ'Ã‚Â©"
2. **Caractères de remplacement** : Caractères accentués remplacés par "ï¿½"
3. **Encodages incorrects** : Fichiers sauvegardés avec un encodage différent de UTF-8

Ces problèmes sont généralement causés par :

- L'ouverture et la sauvegarde de fichiers avec des encodages différents
- La conversion automatique des fins de ligne par Git (CRLF ↔ LF)
- L'absence de configuration explicite d'encodage dans VSCode
- L'utilisation de l'encodage par défaut du système (Windows-1252) au lieu de UTF-8

## Solution mise en place

Pour résoudre ces problèmes, nous avons mis en place les éléments suivants :

### 1. Configuration VSCode

Le fichier `.vscode/settings.json` a été mis à jour pour définir l'encodage par défaut à UTF-8 :

```json
{
    "files.encoding": "utf8",
    "files.autoGuessEncoding": true,
    "files.eol": "\n"
}
```

### 2. Configuration Git

Un fichier `.gitattributes` a été créé pour définir les attributs d'encodage pour Git :

```
* text=auto eol=lf
*.md text eol=lf
*.txt text eol=lf
*.json text eol=lf
# etc.
```

De plus, les paramètres Git suivants sont recommandés :

```bash
git config --global core.autocrlf input
git config --global core.safecrlf warn
git config --global core.quotepath false
git config --global gui.encoding utf-8
```

### 3. Scripts de correction

Deux scripts ont été créés pour diagnostiquer et corriger les problèmes d'encodage :

- `encoding-diagnostic.ps1` : Analyse les fichiers et détecte les problèmes d'encodage
- `fix-encoding-robust.ps1` : Corrige les problèmes d'encodage dans les fichiers

## Comment utiliser les scripts

### Diagnostic des problèmes d'encodage

Pour diagnostiquer les problèmes d'encodage dans un fichier ou un répertoire :

```powershell
.\encoding-diagnostic.ps1
```

Ce script analysera les fichiers problématiques connus et l'environnement pour identifier les problèmes d'encodage.

### Correction des problèmes d'encodage

Pour corriger les problèmes d'encodage dans un fichier spécifique :

```powershell
.\fix-encoding-robust.ps1 -Path "chemin/vers/fichier.md" -Backup
```

Pour corriger les problèmes d'encodage dans un répertoire (récursivement) :

```powershell
.\fix-encoding-robust.ps1 -Path "chemin/vers/repertoire" -Recursive -Backup
```

Options disponibles :
- `-Path` : Chemin du fichier ou du répertoire à traiter
- `-Recursive` : Traiter récursivement les sous-répertoires
- `-Force` : Forcer la correction même si aucun problème n'est détecté
- `-Backup` : Créer une sauvegarde des fichiers avant modification
- `-FilePatterns` : Motifs de fichiers à traiter (par défaut : "*.md", "*.txt", "*.json", etc.)

## Bonnes pratiques pour éviter les problèmes d'encodage

1. **Toujours utiliser UTF-8 sans BOM** pour tous les fichiers texte
2. **Configurer correctement votre éditeur** pour utiliser UTF-8 par défaut
3. **Utiliser des fins de ligne LF** (style Unix) pour tous les fichiers texte
4. **Éviter de mélanger les encodages** dans un même projet
5. **Vérifier l'encodage** avant de committer des fichiers

## Détection de l'encodage d'un fichier

Pour détecter l'encodage d'un fichier en PowerShell :

```powershell
[System.IO.File]::ReadAllBytes("chemin/vers/fichier.txt") | ForEach-Object { "{0:X2}" -f $_ } | Select-Object -First 10
```

Les premiers octets peuvent indiquer l'encodage :
- `EF BB BF` : UTF-8 avec BOM
- `FE FF` : UTF-16 BE
- `FF FE` : UTF-16 LE
- Absence de BOM : UTF-8 sans BOM ou autre encodage (Windows-1252, etc.)

## Ressources additionnelles

- [Documentation sur l'encodage des caractères](https://docs.microsoft.com/fr-fr/dotnet/api/system.text.encoding)
- [Guide Git sur les fins de ligne](https://docs.github.com/en/get-started/getting-started-with-git/configuring-git-to-handle-line-endings)
- [Configuration de l'encodage dans VSCode](https://code.visualstudio.com/docs/getstarted/settings)