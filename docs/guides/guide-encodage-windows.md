# Guide d'encodage pour les fichiers de configuration Roo sur Windows

## Introduction

Ce guide explique les problèmes d'encodage courants rencontrés lors du déploiement des modes Roo sur Windows et fournit des conseils pratiques pour les éviter. Il est particulièrement utile pour les développeurs travaillant avec des fichiers contenant des caractères accentués et des emojis.

## Comprendre les problèmes d'encodage

### Qu'est-ce que l'encodage de caractères?

L'encodage de caractères est la méthode utilisée pour représenter les caractères textuels en données binaires. Différents encodages utilisent différentes méthodes pour représenter les caractères, ce qui peut causer des problèmes de compatibilité.

### Problèmes courants sur Windows

1. **Double encodage**: Un texte déjà encodé en UTF-8 est ré-encodé, transformant par exemple "é" en "Ã©"
2. **BOM (Byte Order Mark)**: Marqueur invisible au début des fichiers UTF-8 qui peut causer des problèmes avec certaines applications
3. **Conversion ANSI/UTF-8**: Windows utilise traditionnellement des encodages ANSI (comme Windows-1252) qui ne gèrent pas correctement les caractères internationaux
4. **Emojis mal encodés**: Les emojis nécessitent un support Unicode complet et sont souvent mal gérés

## Types d'encodage

| Encodage | Description | Avantages | Inconvénients |
|----------|-------------|-----------|---------------|
| **UTF-8 sans BOM** | Unicode, longueur variable (1-4 octets) | Support complet des caractères internationaux, compact pour texte latin | Aucun marqueur d'identification |
| **UTF-8 avec BOM** | UTF-8 avec marqueur d'identification | Facilement identifiable comme UTF-8 | Incompatible avec certains parseurs JSON |
| **UTF-16** | Unicode, 2 ou 4 octets par caractère | Gestion efficace des scripts non-latins | Taille de fichier doublée pour texte latin |
| **ANSI/Windows-1252** | Encodage 8-bit spécifique à Windows | Compatible avec les anciens systèmes | Support limité des caractères internationaux |

## Signes de problèmes d'encodage

Voici comment reconnaître les problèmes d'encodage dans vos fichiers:

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

## Bonnes pratiques pour éviter les problèmes d'encodage

### Configuration des éditeurs de texte

#### Visual Studio Code

1. Définir l'encodage par défaut:
   - Ouvrir les paramètres (Ctrl+,)
   - Rechercher "files.encoding"
   - Définir sur "utf8"
   - Rechercher "files.autoGuessEncoding"
   - Activer cette option

2. Vérifier l'encodage actuel:
   - Regarder dans la barre d'état en bas à droite
   - Cliquer sur l'indication d'encodage pour le modifier

#### Notepad++

1. Définir l'encodage par défaut:
   - Menu "Paramètres" > "Préférences" > "Nouveau document"
   - Sélectionner "UTF-8 sans BOM"

2. Convertir un fichier existant:
   - Menu "Encodage" > "Convertir en UTF-8 sans BOM"

### Configuration de Git

Pour éviter les problèmes d'encodage avec Git:

```bash
# Configurer Git pour utiliser UTF-8
git config --global core.autocrlf input
git config --global core.safecrlf warn
git config --global i18n.commitencoding utf-8
git config --global i18n.logoutputencoding utf-8
```

Ajouter un fichier `.gitattributes` à la racine du projet:

```
# Définir l'encodage par défaut pour tous les fichiers texte
* text=auto eol=lf encoding=utf-8

# Définir explicitement les fichiers JSON
*.json text eol=lf encoding=utf-8
```

### Manipulation des fichiers JSON

1. **Validation**: Toujours valider vos fichiers JSON avec un validateur (comme [JSONLint](https://jsonlint.com/))
2. **Éviter l'édition manuelle**: Utiliser des bibliothèques pour manipuler le JSON programmatiquement
3. **Sérialisation/Désérialisation**: En PowerShell, utiliser `ConvertTo-Json` et `ConvertFrom-Json` avec l'encodage approprié

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

## Outils de diagnostic et correction

### Vérification de l'encodage

```powershell
# Vérifier l'encodage d'un fichier
$bytes = [System.IO.File]::ReadAllBytes("fichier.json")
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "UTF-8 avec BOM"
} else {
    Write-Host "UTF-8 sans BOM ou autre encodage"
}
```

### Conversion d'encodage

```powershell
# Convertir un fichier en UTF-8 sans BOM
$content = [System.IO.File]::ReadAllText("fichier.json", [System.Text.Encoding]::Default)
[System.IO.File]::WriteAllText("fichier.json", $content, [System.Text.UTF8Encoding]::new($false))
```

### Scripts de correction

Le projet inclut plusieurs scripts pour corriger les problèmes d'encodage:

- `fix-encoding-complete.ps1`: Correction complète des caractères mal encodés
- `fix-encoding-final.ps1`: Correction avancée avec expressions régulières
- `check-deployed-encoding.ps1`: Vérification de l'encodage des fichiers déployés

## Résolution des problèmes courants

| Problème | Symptôme | Solution |
|----------|----------|----------|
| JSON invalide | Erreur lors du chargement des modes | Valider le JSON avec un outil comme JSONLint |
| Caractères accentués corrompus | "é" apparaît comme "Ã©" | Utiliser `fix-encoding-complete.ps1` |
| Emojis mal affichés | Emojis remplacés par des caractères étranges | Utiliser `fix-encoding-final.ps1` |
| BOM causant des erreurs | Erreur de parsing JSON | Convertir en UTF-8 sans BOM |
| Encodage mixte | Certains caractères corrects, d'autres corrompus | Standardiser l'encodage de tous les fichiers |

## Workflow recommandé pour les fichiers de configuration

1. **Création**: Créer les fichiers avec un éditeur configuré pour UTF-8 sans BOM
2. **Validation**: Valider le JSON avant de le déployer
3. **Vérification**: Utiliser `check-deployed-encoding.ps1` pour vérifier l'encodage
4. **Correction**: Si nécessaire, utiliser `fix-encoding-complete.ps1` ou `fix-encoding-final.ps1`
5. **Déploiement**: Utiliser `deploy-modes-simple-complex.ps1` avec l'option `-Force`
6. **Test**: Vérifier que les modes s'affichent correctement dans VS Code

## Ressources additionnelles

- [The Absolute Minimum Every Software Developer Must Know About Unicode and Character Sets](https://www.joelonsoftware.com/2003/10/08/the-absolute-minimum-every-software-developer-absolutely-positively-must-know-about-unicode-and-character-sets-no-excuses/)
- [UTF-8 Everywhere Manifesto](https://utf8everywhere.org/)
- [Documentation Microsoft sur l'encodage de caractères](https://docs.microsoft.com/fr-fr/dotnet/api/system.text.encoding)
- [Rapport complet sur le déploiement des modes](../rapports/rapport-final-deploiement-modes-windows.md)

---

Ce guide a été créé pour aider les développeurs à comprendre et résoudre les problèmes d'encodage courants lors du déploiement des modes Roo sur Windows. Pour une assistance plus détaillée, consultez le rapport complet de déploiement ou utilisez le script de déploiement interactif `deploy-guide-interactif.ps1`.