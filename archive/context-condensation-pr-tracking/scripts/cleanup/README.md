# Scripts de Nettoyage - Phase SDDD 10

Ce répertoire contient une suite de scripts PowerShell pour nettoyer et organiser les fichiers temporaires créés pendant les phases de développement et de réparation du projet roo-code.

## 🚀 Phase SDDD 10: Réorganisation des scripts dans l'espace de suivi approprié

### 📋 Scripts disponibles

1. **01-backup-before-cleanup-2025-10-24.ps1** - Sauvegarde des fichiers temporaires avant nettoyage
2. **02-cleanup-vitest-configs-2025-10-24.ps1** - Nettoyage des configurations Vitest temporaires
3. **03-cleanup-test-files-2025-10-24.ps1** - Nettoyage des fichiers de test temporaires
4. **04-cleanup-diagnostic-files-2025-10-24.ps1** - Nettoyage des fichiers de diagnostic temporaires
5. **05-validate-cleanup-2025-10-24.ps1** - Validation du nettoyage effectué

## 🔄 Processus d'utilisation

### Étape 1: Sauvegarde avant nettoyage
```powershell
.\scripts\cleanup\01-backup-before-cleanup-2025-10-24.ps1
```

**Actions effectuées :**
- sauvegarde de toutes les configurations Vitest temporaires
- sauvegarde des fichiers setup temporaires
- sauvegarde des fichiers de test temporaires
- sauvegarde des fichiers de diagnostic
- création d'un inventaire détaillé des fichiers sauvegardés

### Étape 2: Nettoyage des configurations Vitest
```powershell
.\scripts\cleanup\02-cleanup-vitest-configs-2025-10-24.ps1
```

**Actions effectuées :**
- suppression des fichiers de configuration Vitest temporaires
- conservation uniquement des configurations valides
- nettoyage des fichiers setup temporaires

### Étape 3: Nettoyage des fichiers de test
```powershell
.\scripts\cleanup\03-cleanup-test-files-2025-10-24.ps1
```

**Actions effectuées :**
- suppression des fichiers de test temporaires
- conservation des tests officiels du projet
- nettoyage des fichiers de diagnostic temporaires

### Étape 4: Nettoyage des fichiers de diagnostic
```powershell
.\scripts\cleanup\04-cleanup-diagnostic-files-2025-10-24.ps1
```

**Actions effectuées :**
- suppression des fichiers de sortie de diagnostic
- nettoyage des logs temporaires
- suppression des fichiers de débogage temporaires

### Étape 5: Validation du nettoyage
```powershell
.\scripts\cleanup\05-validate-cleanup-2025-10-24.ps1
```

**Validations effectuées :**
- vérification que les fichiers temporaires ont été supprimés
- confirmation que les fichiers essentiels sont préservés
- génération d'un rapport de nettoyage

## 🛠️ Exécution complète

Pour exécuter la séquence complète de nettoyage :

```powershell
# Exécuter dans l'ordre
.\scripts\cleanup\01-backup-before-cleanup-2025-10-24.ps1
.\scripts\cleanup\02-cleanup-vitest-configs-2025-10-24.ps1
.\scripts\cleanup\03-cleanup-test-files-2025-10-24.ps1
.\scripts\cleanup\04-cleanup-diagnostic-files-2025-10-24.ps1
.\scripts\cleanup\05-validate-cleanup-2025-10-24.ps1
```

## 📊 Rapport de validation

Chaque script génère un rapport coloré dans la console :
- 🔴 **Rouge** : Erreurs critiques
- 🟡 **Jaune** : Avertissements
- 🟢 **Vert** : Succès
- 🔵 **Bleu** : Informations
- 🟣 **Violet** : Résumé

## ⚠️ Prérequis

- PowerShell 5.1 ou supérieur
- Accès en lecture/écriture aux répertoires du projet
- Espace disque suffisant pour les sauvegardes temporaires

## 🔧 Dépannage

### Si les scripts ne s'exécutent pas
```powershell
# Autoriser l'exécution des scripts PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Si la sauvegarde échoue
- Vérifiez l'espace disque disponible
- Vérifiez les permissions d'écriture
- Exécutez avec des privilèges administrateurs si nécessaire

### Si des fichiers essentiels sont supprimés
- Les fichiers sont sauvegardés dans `.backup-temp/cleanup-backup-[timestamp]`
- Restaurez manuellement depuis cette sauvegarde
- Consultez le fichier `backup-inventory.json` pour l'inventaire

## 📝 Notes SDDD

Ces scripts ont été créés selon la méthodologie SDDD (Semantic Documentation Driven Design) :
- Recherche sémantique initiale : `"organisation scripts workspace suivi pnpm repair cleanup SDDD"`
- Scripts numérotés et horodatés pour la traçabilité
- Documentation complète pour la reproductibilité
- Sauvegarde systématique avant toute opération de nettoyage

## 🔄 Maintenance

Pour mettre à jour ces scripts :
1. Analyser les nouveaux besoins de nettoyage
2. Effectuer une recherche sémantique pour les meilleures pratiques
3. Mettre à jour les scripts avec de nouveaux horodatages
4. Tester la séquence complète
5. Mettre à jour cette documentation

---

**Créé le :** 2025-10-24 10:07  
**Version SDDD :** Phase 10  
**Objectif :** Réorganisation des scripts dans l'espace de suivi approprié