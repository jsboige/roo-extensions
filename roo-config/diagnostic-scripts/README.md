# Scripts de diagnostic et vérification

Ce dossier contient des scripts PowerShell pour diagnostiquer et vérifier les problèmes d'encodage dans les fichiers JSON des modes Roo.

## Fonctionnalités

Ces scripts permettent de :
- Analyser l'encodage des fichiers JSON
- Détecter les problèmes d'encodage courants
- Vérifier la validité des fichiers JSON
- Proposer des solutions automatiques
- Vérifier le déploiement des modes

## Scripts disponibles

### Scripts de diagnostic

- **`diagnostic-rapide-encodage.ps1`** - Outil de diagnostic rapide avec correction automatique
- **`encoding-diagnostic.ps1`** - Diagnostic complet des problèmes d'encodage

### Scripts de vérification

- **`check-deployed-encoding.ps1`** - Vérifie l'encodage du fichier déployé
- **`verify-deployed-modes.ps1`** - Vérifie les modes déployés et leur encodage

## Utilisation recommandée

### Diagnostic rapide

Pour diagnostiquer rapidement les problèmes d'encodage dans un fichier :

```powershell
.\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json"
```

Pour diagnostiquer et corriger automatiquement les problèmes :

```powershell
.\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json" -Fix
```

### Vérification du déploiement

Pour vérifier que les modes ont été correctement déployés :

```powershell
.\verify-deployed-modes.ps1
```

## Paramètres communs

- **`FilePath`** : Chemin du fichier à analyser
- **`Fix`** : Active la correction automatique des problèmes détectés
- **`Verbose`** : Affiche des informations détaillées sur les problèmes détectés

## Problèmes détectés

Ces scripts peuvent détecter les problèmes suivants :
- Encodage UTF-8 avec BOM (non recommandé pour JSON)
- Caractères accentués mal encodés (é, è, à, ç, etc.)
- Emojis mal encodés (💻, 🪲, 🏗️, etc.)
- JSON invalide
- Problèmes de structure des modes

## Remarques

- Les scripts de diagnostic n'effectuent aucune modification sans votre accord
- L'option `-Fix` permet d'appliquer automatiquement les corrections recommandées
- Une sauvegarde est toujours créée avant d'appliquer des corrections