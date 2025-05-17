# Scripts de correction d'encodage

Ce dossier contient des scripts PowerShell pour corriger les problèmes d'encodage dans les fichiers JSON des modes Roo.

## Problématique

Les fichiers JSON contenant des caractères accentués ou des emojis peuvent être mal encodés lors du transfert ou de la manipulation, ce qui les rend invalides et empêche leur chargement correct dans Visual Studio Code.

## Scripts disponibles

### Scripts principaux

- **`fix-encoding-simple.ps1`** - Correction simple des problèmes d'encodage les plus courants
- **`fix-encoding-complete.ps1`** - Correction complète des caractères mal encodés et des emojis
- **`fix-encoding-final.ps1`** - Version finale et optimisée de la correction d'encodage

### Scripts spécialisés

- **`fix-encoding-advanced.ps1`** - Correction avancée avec plus d'options et de paramètres
- **`fix-encoding-direct.ps1`** - Correction directe des caractères problématiques sans conversion intermédiaire
- **`fix-encoding-regex.ps1`** - Correction utilisant des expressions régulières pour des cas complexes
- **`fix-encoding.ps1`** - Script générique de correction d'encodage
- **`fix-source-encoding.ps1`** - Correction de l'encodage des fichiers source

## Utilisation recommandée

Pour une correction standard des problèmes d'encodage :

```powershell
.\fix-encoding-complete.ps1
```

Pour une correction avancée avec plus d'options :

```powershell
.\fix-encoding-advanced.ps1 -FilePath "chemin\vers\fichier.json" -CreateBackup $true
```

## Fonctionnement

Ces scripts fonctionnent en :
1. Créant une sauvegarde du fichier original
2. Détectant et remplaçant les séquences de caractères mal encodés
3. Réenregistrant le fichier en UTF-8 sans BOM
4. Vérifiant que le JSON résultant est valide

## Remarques

- Tous les scripts créent automatiquement une sauvegarde avant modification
- Les scripts vérifient la validité du JSON après correction
- Pour les cas complexes, utilisez `fix-encoding-advanced.ps1` ou `fix-encoding-regex.ps1`