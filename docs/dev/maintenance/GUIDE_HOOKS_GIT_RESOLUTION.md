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

## ✅ Solution appliquée (Mise à jour 2025-10-07)

### 1. Hook Shell Unix (Solution fonctionnelle)

Le fichier `.git/hooks/pre-commit` a été transformé en script shell compatible Git Bash :

```bash
#!/bin/bash
# Hook pre-commit pour Windows - Format Shell
# Appelle le script PowerShell pour vérifier l'encodage des fichiers

# Obtenir le répertoire du hook
HOOK_DIR="$(dirname "$0")"

# Exécuter le script PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOOK_DIR/pre-commit.ps1"

# Retourner le code d'erreur
exit $?
```

### 2. Corrections techniques appliquées

- **Format shell Unix** : Compatible avec Git Bash sur Windows (solution de contournement réussie)
- **Shebang bash** : `#!/bin/bash` reconnu par Git for Windows
- **Préservation du script original** : Script PowerShell `pre-commit.ps1` inchangé
- **Gestion correcte des codes de retour** : `$?` transmis à Git
- **Variables shell** : `HOOK_DIR` pour chemin robuste

### 3. Échecs précédents documentés

- **Wrapper batch** : `@echo off` + `powershell.exe` → Échec avec erreur "cannot spawn"
- **Script réparation initial** : Créait format batch non fonctionnel
- **Solution finale** : Format shell résout le problème d'exécution Git Bash

## 🛠️ Utilisation du script de réparation

Un script automatisé a été créé : [`scripts/maintenance/repair-git-hooks.ps1`](../../../scripts/maintenance/repair-git-hooks.ps1)

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