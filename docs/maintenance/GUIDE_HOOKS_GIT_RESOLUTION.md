# Guide de résolution des problèmes de hooks Git pre-commit

## 🚨 Problème identifié

Durant la mission SDDD finale, nous avons rencontré l'erreur récurrente :
```
error: cannot spawn .git/hooks/pre-commit: No such file or directory
```

## 🔍 Diagnostic effectué

### Causes identifiées :

1. **Incompatibilité shebang PowerShell** : Git sur Windows ne peut pas interpréter directement `#!/usr/bin/env pwsh`
2. **Problème d'encodage BOM UTF-8** : Le fichier contenait un Byte Order Mark qui empêchait l'exécution
3. **Permissions incorrectes** : Le fichier n'était pas reconnu comme exécutable par Git sur Windows
4. **Format non compatible** : Git Windows attend un format batch (.bat) ou un script shell compatible

### Structure identifiée :
- `.git/hooks/pre-commit` : Script PowerShell avec shebang (non fonctionnel)
- `.git/hooks/pre-commit.ps1` : Script PowerShell de validation d'encodage (fonctionnel)

## ✅ Solution appliquée

### 1. Création d'un wrapper batch

Le fichier `.git/hooks/pre-commit` a été transformé en wrapper batch :

```batch
@echo off
REM Hook pre-commit wrapper pour Windows  
REM Appelle le script PowerShell pour verifier l'encodage des fichiers

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pre-commit.ps1"
exit /b %ERRORLEVEL%
```

### 2. Corrections techniques appliquées

- **Suppression du BOM UTF-8** : Fichier recréé avec encodage ASCII
- **Format batch natif** : Compatible avec l'exécuteur de commandes Windows
- **Préservation du script original** : Sauvegardé dans `pre-commit.ps1`
- **Gestion correcte des codes de retour** : `%ERRORLEVEL%` transmis à Git

## 🛠️ Utilisation du script de réparation

Un script automatisé a été créé : [`scripts/maintenance/repair-git-hooks.ps1`](../../scripts/maintenance/repair-git-hooks.ps1)

### Exécution :

```powershell
# Réparation complète avec test
powershell -ExecutionPolicy Bypass -File "scripts/maintenance/repair-git-hooks.ps1"

# Mode diagnostic uniquement
powershell -ExecutionPolicy Bypass -File "scripts/maintenance/repair-git-hooks.ps1" -Test
```

### Fonctionnalités du script :

- **Diagnostic automatique** : Détection des problèmes d'encodage, permissions, format
- **Sauvegarde automatique** : Préservation du script PowerShell original
- **Test intégré** : Validation du fonctionnement après réparation
- **Gestion d'erreurs** : Messages explicites en cas d'échec

## 🧪 Validation effectuée

### Tests de fonctionnement :

1. **Commit normal** : ✅ Réussi sans `--no-verify`
2. **Validation d'encodage** : ✅ Script PowerShell s'exécute correctement
3. **Gestion des erreurs** : ✅ Codes de retour correctement transmis
4. **Compatibilité Windows** : ✅ Fonctionne avec Git for Windows

### Résultats :
- Fini l'utilisation systématique de `git commit --no-verify`
- Validation d'encodage opérationnelle
- Hook stable pour le développement futur

## 🔄 Prévention et maintenance

### Pour éviter la récurrence :

1. **Ne jamais éditer directement** `.git/hooks/pre-commit` - utiliser `pre-commit.ps1`
2. **En cas de problème** : Exécuter le script de réparation
3. **Nouveaux environnements** : Appliquer la réparation après clone du repo
4. **Formation équipe** : Sensibiliser aux spécificités Windows/Git

### Signaux d'alerte :

- Erreur `cannot spawn .git/hooks/pre-commit`
- Nécessité d'utiliser `--no-verify` systématiquement
- Hook qui ne s'exécute pas silencieusement

### Actions recommandées :

1. Exécuter `scripts/maintenance/repair-git-hooks.ps1`
2. Vérifier le contenu de `.git/hooks/pre-commit.ps1`
3. Tester avec un commit normal
4. Documenter tout changement dans les hooks

## 📋 Checklist de maintenance

- [ ] Hook pre-commit fonctionne sans `--no-verify`
- [ ] Script PowerShell d'encodage opérationnel  
- [ ] Pas de BOM UTF-8 dans les fichiers hooks
- [ ] Wrapper batch correctement configuré
- [ ] Tests de commit passent avec succès

## 📞 Support

En cas de problème persistant :

1. Consulter les logs de Git : `git config --global core.hookspath`
2. Vérifier les permissions : `Get-Item .git/hooks/pre-commit`
3. Diagnostiquer l'encodage : Script intégré dans `repair-git-hooks.ps1`
4. Réinitialiser complètement les hooks si nécessaire

---

**Créé le :** 2025-01-07  
**Dernière mise à jour :** 2025-01-07  
**Version :** 1.0  
**Statut :** ✅ Résolu et documenté