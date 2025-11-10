# Scripts de Réparation d'Environnement pnpm

Ce répertoire contient une suite de scripts PowerShell pour réparer et valider l'environnement pnpm du projet, en particulier pour les tests React avec Vitest.

## 🚀 Phase SDDD 6: Plan d'action alternatif - Réparer l'environnement pnpm

### 📋 Scripts disponibles

1. **01-cleanup-pnpm-environment-2025-10-24.ps1** - Nettoyage complet de l'environnement
2. **02-reinstall-dependencies-2025-10-24.ps1** - Réinstallation propre des dépendances
3. **03-validate-environment-2025-10-24.ps1** - Validation de l'environnement configuré
4. **04-test-react-functionality-2025-10-24.ps1** - Test des fonctionnalités React

## 🔄 Processus d'utilisation

### Étape 1: Nettoyage complet
```powershell
.\scripts\pnpm-repair\01-cleanup-pnpm-environment-2025-10-24.ps1
```

**Actions effectuées :**
- suppression de tous les répertoires `node_modules`
- suppression du fichier `pnpm-lock.yaml`
- nettoyage des caches de build (`.turbo`, `dist`, `out`)
- vidage du cache pnpm global (`pnpm store prune`)

### Étape 2: Réinstallation des dépendances
```powershell
.\scripts\pnpm-repair\02-reinstall-dependencies-2025-10-24.ps1
```

**Actions effectuées :**
- installation des dépendances avec `pnpm install --prefer-frozen-lockfile`
- mécanisme de retry en cas d'échec
- vérification post-installation

### Étape 3: Validation de l'environnement
```powershell
.\scripts\pnpm-repair\03-validate-environment-2025-10-24.ps1
```

**Validations effectuées :**
- vérification des versions de Node.js et pnpm
- confirmation des fichiers critiques présents
- validation des dépendances React
- vérification des configurations Vitest

### Étape 4: Test des fonctionnalités React
```powershell
.\scripts\pnpm-repair\04-test-react-functionality-2025-10-24.ps1
```

**Tests effectués :**
- création et exécution de tests React temporaires
- test des composants React simples
- test des hooks React (`useState`, `useEffect`)
- test des Context Providers
- nettoyage automatique des fichiers temporaires

## 🛠️ Exécution complète

Pour exécuter la séquence complète de réparation :

```powershell
# Exécuter dans l'ordre
.\scripts\pnpm-repair\01-cleanup-pnpm-environment-2025-10-24.ps1
.\scripts\pnpm-repair\02-reinstall-dependencies-2025-10-24.ps1
.\scripts\pnpm-repair\03-validate-environment-2025-10-24.ps1
.\scripts\pnpm-repair\04-test-react-functionality-2025-10-24.ps1
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
- pnpm installé globalement
- Accès administrateur (pour certaines opérations de nettoyage)

## 🔧 Dépannage

### Si les scripts ne s'exécutent pas
```powershell
# Autoriser l'exécution des scripts PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Si pnpm n'est pas reconnu
```powershell
# Installer pnpm globalement
npm install -g pnpm
```

### Si les tests React échouent
Vérifiez que :
- Node.js est en version 18 ou supérieure
- Les dépendances React sont correctement installées
- La configuration Vitest est valide

## 📝 Notes SDDD

Ces scripts ont été créés selon la méthodologie SDDD (Semantic Documentation Driven Design) :
- Recherche sémantique initiale : `"pnpm environment cleanup repair React tests configuration best practices"`
- Recherche sémantique de validation : `"scripts pnpm cleanup repair environment React tests"`
- Scripts numérotés et horodatés pour la traçabilité
- Documentation complète pour la reproductibilité

## 🔄 Maintenance

Pour mettre à jour ces scripts :
1. Analyser les nouveaux besoins du projet
2. Effectuer une recherche sémantique pour les meilleures pratiques
3. Mettre à jour les scripts avec de nouveaux horodatages
4. Tester la séquence complète
5. Mettre à jour cette documentation

---

**Créé le :** 2025-10-24 01:45  
**Version SDDD :** Phase 6  
**Objectif :** Réparation complète de l'environnement pnpm pour les tests React