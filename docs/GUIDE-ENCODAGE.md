# Guide complet sur les problèmes d'encodage dans le projet roo-extensions

## Table des matières

1. [Introduction](#introduction)
2. [Problèmes d'encodage courants](#problèmes-dencodage-courants)
3. [Outils de diagnostic et correction](#outils-de-diagnostic-et-correction)
4. [Paramètres du terminal et encodage](#paramètres-du-terminal-et-encodage)
5. [Bonnes pratiques](#bonnes-pratiques)
6. [Ressources additionnelles](#ressources-additionnelles)

## Introduction

Ce guide complet aborde les problèmes d'encodage rencontrés dans le projet roo-extensions et fournit des solutions pratiques pour les diagnostiquer et les corriger. Il est destiné à tous les développeurs travaillant sur le projet, quel que soit leur système d'exploitation.

L'encodage des caractères est la méthode utilisée pour représenter les caractères textuels en données binaires. Une gestion incorrecte de l'encodage peut entraîner l'affichage de caractères corrompus, des erreurs de parsing JSON, et d'autres problèmes qui affectent la qualité et la fonctionnalité du projet.

## Problèmes d'encodage courants

### Types de problèmes rencontrés

1. **Double ou triple encodage UTF-8**
   - Caractères accentués apparaissant sous forme corrompue (ex: "é" → "Ã©" ou "ÃƒÂ©")
   - Emojis mal affichés ou corrompus (ex: "💻" → "Ã°Å¸â€™Â»")

2. **Incompatibilité d'encodage**
   - Fichiers sauvegardés avec un encodage différent de UTF-8
   - Mélange d'encodages dans un même projet

3. **Problèmes liés au BOM (Byte Order Mark)**
   - Présence ou absence inappropriée du BOM causant des erreurs de parsing
   - Incompatibilité avec certains parseurs JSON

4. **Problèmes de fins de ligne**
   - Mélange de styles de fins de ligne (CRLF vs LF)
   - Conversion automatique par Git causant des problèmes d'encodage

### Tableau des caractères mal encodés courants

| Caractère correct | Apparence incorrecte | Problème |
|-------------------|----------------------|----------|
| é | Ã© | Double encodage UTF-8 |
| è | Ã¨ | Double encodage UTF-8 |
| à | Ã  | Double encodage UTF-8 |
| ç | Ã§ | Double encodage UTF-8 |
| É | Ã‰ | Double encodage UTF-8 |
| 💻 (emoji ordinateur) | Ã°Å¸â€™Â» | Emoji mal encodé |
| 🪲 (emoji insecte) | Ã°Å¸ÂªÂ² | Emoji mal encodé |
| 🏗️ (emoji construction) | Ã°Å¸Ââ€"Ã¯Â¸Â | Emoji mal encodé |
| ❓ (emoji point d'interrogation) | Ã¢Ââ€œ | Emoji mal encodé |
| 🪃 (emoji boomerang) | Ã°Å¸ÂªÆ' | Emoji mal encodé |
| 👨‍💼 (emoji manager) | Ã°Å¸â€˜Â¨Ã¢â‚¬ÂÃ°Å¸â€™Â¼ | Emoji mal encodé |

### Causes principales

- Ouverture et sauvegarde de fichiers avec des encodages différents
- Utilisation de l'encodage par défaut du système (Windows-1252) au lieu de UTF-8
- Copier-coller entre applications utilisant des encodages différents
- Configuration incorrecte des éditeurs de texte et des terminaux
- Conversion automatique des fins de ligne par Git (CRLF ↔ LF)

## Outils de diagnostic et correction

Le projet roo-extensions inclut plusieurs scripts pour diagnostiquer et corriger les problèmes d'encodage.

### Scripts de diagnostic

#### `diagnostic-rapide-encodage.ps1`

Ce script analyse rapidement un fichier JSON pour détecter les problèmes d'encodage courants.

**Fonctionnalités:**
- Détection de l'encodage du fichier (UTF-8 avec/sans BOM)
- Validation du JSON
- Détection des caractères accentués mal encodés
- Détection des emojis mal encodés
- Affichage d'exemples de problèmes avec contexte

**Utilisation:**
```powershell
# Analyse interactive
.\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1

# Analyse d'un fichier spécifique
.\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json"

# Analyse détaillée
.\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json" -Verbose

# Analyse et correction automatique
.\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json" -Fix
```

#### `encoding-diagnostic.ps1`

Ce script effectue une analyse plus approfondie des problèmes d'encodage dans l'ensemble du projet.

**Utilisation:**
```powershell
.\roo-config\diagnostic-scripts\encoding-diagnostic.ps1
```

#### `check-deployed-encoding.ps1`

Ce script vérifie l'encodage des fichiers déployés pour s'assurer qu'ils sont correctement encodés.

**Utilisation:**
```powershell
.\roo-config\diagnostic-scripts\check-deployed-encoding.ps1
```

### Scripts de correction

Le projet inclut plusieurs scripts pour corriger les problèmes d'encodage, chacun avec des fonctionnalités et des niveaux de complexité différents.

#### Scripts principaux

- **`fix-encoding-simple.ps1`** - Correction simple des problèmes d'encodage les plus courants
- **`fix-encoding-complete.ps1`** - Correction complète des caractères mal encodés et des emojis
- **`fix-encoding-final.ps1`** - Version finale et optimisée de la correction d'encodage

**Scripts consolidés (v3.0) :**
```powershell
# Configuration complète de l'environnement UTF-8
.\scripts\utf8\setup.ps1

# Diagnostic approfondi des problèmes d'encodage
.\scripts\utf8\diagnostic.ps1 -Verbose -ExportReport

# Réparation automatique des fichiers
.\scripts\utf8\repair.ps1 -All -Backup

# Réparations spécifiques
.\scripts\utf8\repair.ps1 -FixBOM -FixCRLF          # Corrections basiques
.\scripts\utf8\repair.ps1 -FixEncoding              # Caractères mal encodés
.\scripts\utf8\repair.ps1 -Path "fichier.json" -All # Fichier spécifique
```

> **⚠️ Note:** Les anciens scripts dans `roo-config\encoding-scripts\` ont été archivés dans `archive\old-encoding-scripts\` et remplacés par 3 scripts consolidés plus robustes.

### Fonctionnement des scripts de correction

Ces scripts fonctionnent généralement selon le processus suivant:

1. Création d'une sauvegarde du fichier original
2. Détection et remplacement des séquences de caractères mal encodés
3. Réenregistrement du fichier en UTF-8 sans BOM
4. Vérification que le JSON résultant est valide

### Vérification manuelle de l'encodage

Pour vérifier manuellement l'encodage d'un fichier en PowerShell:

```powershell
# Vérifier si un fichier a un BOM UTF-8
$bytes = [System.IO.File]::ReadAllBytes("chemin\vers\fichier.json")
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "UTF-8 avec BOM"
} else {
    Write-Host "UTF-8 sans BOM ou autre encodage"
}

# Afficher les premiers octets d'un fichier pour déterminer son encodage
[System.IO.File]::ReadAllBytes("chemin\vers\fichier.json") | ForEach-Object { "{0:X2}" -f $_ } | Select-Object -First 10
```

## Paramètres du terminal et encodage

La configuration du terminal est cruciale pour éviter les problèmes d'encodage, en particulier lors de l'exécution de scripts PowerShell qui manipulent des fichiers texte.

### Configuration de PowerShell

#### PowerShell 5.1 (Windows PowerShell)

Par défaut, Windows PowerShell utilise l'encodage Windows-1252 (ANSI), ce qui peut causer des problèmes avec les caractères Unicode. Pour configurer PowerShell pour une meilleure gestion de l'encodage:

1. **Définir l'encodage de sortie par défaut:**

   Créez ou modifiez votre profil PowerShell (`$PROFILE`) pour inclure:

   ```powershell
   # Définir l'encodage de sortie par défaut à UTF-8
   [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
   
   # Définir l'encodage d'entrée par défaut à UTF-8
   $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
   $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
   ```

2. **Vérifier les encodages actuels:**

   ```powershell
   # Afficher l'encodage de sortie actuel
   [Console]::OutputEncoding
   
   # Afficher l'encodage d'entrée actuel pour les cmdlets PowerShell
   $PSDefaultParameterValues
   ```

#### PowerShell 7+ (PowerShell Core)

PowerShell 7+ utilise UTF-8 par défaut, ce qui réduit les problèmes d'encodage. Cependant, il est toujours recommandé de vérifier et configurer explicitement:

```powershell
# Définir l'encodage par défaut pour les cmdlets
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
```

### Configuration de Windows Terminal

Windows Terminal peut être configuré pour utiliser UTF-8 par défaut:

1. Ouvrez les paramètres de Windows Terminal (Ctrl+,)
2. Accédez aux profils que vous utilisez
3. Dans la section "Apparence", assurez-vous que "Jeu de caractères" est défini sur "Unicode (UTF-8)"

### Configuration de la console Windows

Pour les anciennes consoles Windows (cmd.exe):

1. Exécutez la commande suivante pour utiliser UTF-8:
   ```
   chcp 65001
   ```

2. Pour rendre ce changement permanent, modifiez le registre:
   ```
   reg add HKCU\Console /v CodePage /t REG_DWORD /d 65001 /f
   ```

### Paramètres régionaux de Windows

Les paramètres régionaux de Windows peuvent également affecter l'encodage:

1. Ouvrez les "Paramètres Windows" > "Heure et langue" > "Région"
2. Cliquez sur "Paramètres administratifs de langue"
3. Dans l'onglet "Administratif", cliquez sur "Modifier les paramètres régionaux du système"
4. Cochez "Utiliser Unicode UTF-8 pour la prise en charge mondiale des langues"
5. Redémarrez votre ordinateur

## Bonnes pratiques

### Configuration des éditeurs de texte

#### Visual Studio Code

1. **Définir l'encodage par défaut:**
   - Ouvrir les paramètres (Ctrl+,)
   - Rechercher "files.encoding"
   - Définir sur "utf8"
   - Rechercher "files.autoGuessEncoding"
   - Activer cette option
   - Rechercher "files.eol"
   - Définir sur "\n" (LF)

2. **Créer un fichier `.vscode/settings.json` dans votre projet:**
   ```json
   {
       "files.encoding": "utf8",
       "files.autoGuessEncoding": true,
       "files.eol": "\n"
   }
   ```

3. **Vérifier l'encodage actuel:**
   - Regarder dans la barre d'état en bas à droite
   - Cliquer sur l'indication d'encodage pour le modifier

#### Notepad++

1. **Définir l'encodage par défaut:**
   - Menu "Paramètres" > "Préférences" > "Nouveau document"
   - Sélectionner "UTF-8 sans BOM"

2. **Convertir un fichier existant:**
   - Menu "Encodage" > "Convertir en UTF-8 sans BOM"

### Configuration de Git

Pour éviter les problèmes d'encodage avec Git:

1. **Configurer Git globalement:**
   ```bash
   git config --global core.autocrlf input
   git config --global core.safecrlf warn
   git config --global i18n.commitencoding utf-8
   git config --global i18n.logoutputencoding utf-8
   git config --global core.quotepath false
   git config --global gui.encoding utf-8
   ```

2. **Ajouter un fichier `.gitattributes` à la racine du projet:**
   ```
   # Définir l'encodage par défaut pour tous les fichiers texte
   * text=auto eol=lf encoding=utf-8
   
   # Définir explicitement les fichiers texte
   *.md text eol=lf encoding=utf-8
   *.txt text eol=lf encoding=utf-8
   *.json text eol=lf encoding=utf-8
   *.ps1 text eol=lf encoding=utf-8
   *.js text eol=lf encoding=utf-8
   *.ts text eol=lf encoding=utf-8
   *.html text eol=lf encoding=utf-8
   *.css text eol=lf encoding=utf-8
   ```

### Manipulation des fichiers JSON

1. **Validation:** Toujours valider vos fichiers JSON avec un validateur (comme [JSONLint](https://jsonlint.com/))

2. **Éviter l'édition manuelle:** Utiliser des bibliothèques pour manipuler le JSON programmatiquement

3. **Sérialisation/Désérialisation en PowerShell:**
   ```powershell
   # Lire un fichier JSON avec encodage UTF-8
   $jsonContent = Get-Content -Path "config.json" -Raw -Encoding UTF8
   $jsonObject = ConvertFrom-Json $jsonContent
   
   # Modifier l'objet JSON
   $jsonObject.property = "Nouvelle valeur avec caractères accentués éèàç"
   
   # Écrire le fichier JSON avec encodage UTF-8 sans BOM
   $jsonString = ConvertTo-Json $jsonObject -Depth 100
   [System.IO.File]::WriteAllText("config.json", $jsonString, [System.Text.UTF8Encoding]::new($false))
   ```

### Workflow recommandé pour les fichiers de configuration

1. **Création:** Créer les fichiers avec un éditeur configuré pour UTF-8 sans BOM
2. **Validation:** Valider le JSON avant de le déployer
3. **Vérification:** Utiliser `check-deployed-encoding.ps1` pour vérifier l'encodage
4. **Correction:** Si nécessaire, utiliser `fix-encoding-complete.ps1` ou `fix-encoding-final.ps1`
5. **Déploiement:** Utiliser `deploy-modes-simple-complex.ps1` avec l'option `-Force`
6. **Test:** Vérifier que les modes s'affichent correctement dans VS Code

### Résolution des problèmes courants

| Problème | Symptôme | Solution |
|----------|----------|----------|
| JSON invalide | Erreur lors du chargement des modes | Valider le JSON avec un outil comme JSONLint |
| Caractères accentués corrompus | "é" apparaît comme "Ã©" | Utiliser `fix-encoding-complete.ps1` |
| Emojis mal affichés | Emojis remplacés par des caractères étranges | Utiliser `fix-encoding-final.ps1` |
| BOM causant des erreurs | Erreur de parsing JSON | Convertir en UTF-8 sans BOM |
| Encodage mixte | Certains caractères corrects, d'autres corrompus | Standardiser l'encodage de tous les fichiers |

## Ressources additionnelles

- [The Absolute Minimum Every Software Developer Must Know About Unicode and Character Sets](https://www.joelonsoftware.com/2003/10/08/the-absolute-minimum-every-software-developer-absolutely-positively-must-know-about-unicode-and-character-sets-no-excuses/)
- [UTF-8 Everywhere Manifesto](https://utf8everywhere.org/)
- [Documentation Microsoft sur l'encodage de caractères](https://docs.microsoft.com/fr-fr/dotnet/api/system.text.encoding)
- [Guide Git sur les fins de ligne](https://docs.github.com/en/get-started/getting-started-with-git/configuring-git-to-handle-line-endings)
- [Configuration de l'encodage dans VSCode](https://code.visualstudio.com/docs/getstarted/settings)
- [Guide d'encodage pour Windows](guides/guide-encodage-windows.md) - Instructions spécifiques pour Windows
- [Guide d'encodage général](guides/guide-encodage.md) - Instructions générales pour tous les systèmes

---

Ce guide a été créé pour aider les développeurs à comprendre, diagnostiquer et résoudre les problèmes d'encodage dans le projet roo-extensions. Pour une assistance plus détaillée ou des cas spécifiques, consultez les scripts de diagnostic et de correction disponibles dans le projet.