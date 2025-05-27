# Fichiers de sauvegarde

Ce dossier contient des sauvegardes automatiques créées par les différents scripts de déploiement et de correction d'encodage.

## Types de fichiers

Les fichiers de sauvegarde sont généralement créés avec les extensions suivantes :
- `.bak` - Sauvegarde standard
- `.backup` - Sauvegarde complète
- `.backup-complete` - Sauvegarde avant correction complète d'encodage

## Utilisation

Ces fichiers de sauvegarde peuvent être utilisés pour restaurer des versions précédentes en cas de problème avec les versions modifiées. Pour restaurer une sauvegarde :

1. Identifiez le fichier de sauvegarde correspondant au fichier que vous souhaitez restaurer
2. Copiez le fichier de sauvegarde vers l'emplacement d'origine
3. Renommez-le pour supprimer l'extension de sauvegarde

Exemple :
```powershell
Copy-Item "backups\model-configs.json.bak" -Destination "..\model-configs.json" -Force
```

## Gestion des sauvegardes

Les scripts créent automatiquement des sauvegardes avant d'effectuer des modifications. Cependant, ces fichiers peuvent s'accumuler avec le temps. Vous pouvez nettoyer périodiquement ce dossier en supprimant les sauvegardes anciennes dont vous n'avez plus besoin.

Pour supprimer toutes les sauvegardes de plus de 30 jours :
```powershell
Get-ChildItem -Path "backups" -Filter "*.bak" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force
```

## Remarques

- Les sauvegardes sont créées automatiquement par les scripts de correction d'encodage et de déploiement
- Chaque sauvegarde conserve l'état exact du fichier avant modification
- Il est recommandé de conserver au moins une version de sauvegarde fonctionnelle