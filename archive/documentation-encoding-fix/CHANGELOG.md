# Changelog - Correction d'encodage UTF-8

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Versioning Sémantique](https://semver.org/lang/fr/).

## [1.0.0] - 2025-05-26

### Ajouté
- **Script de déploiement automatique** (`apply-encoding-fix.ps1`)
  - Déploiement complet de la configuration UTF-8
  - Sauvegarde automatique du profil existant
  - Configuration VSCode intégrée
  - Support des paramètres `-Force`, `-SkipBackup`, `-Verbose`
  
- **Script de validation post-déploiement** (`validate-deployment.ps1`)
  - Validation complète de la configuration
  - Tests d'affichage des caractères français
  - Génération de rapports de validation
  - Support des paramètres `-Detailed`, `-CreateReport`
  
- **Guide de déploiement complet** (`DEPLOYMENT-GUIDE.md`)
  - Instructions d'installation rapide et manuelle
  - Section de dépannage détaillée
  - FAQ et support
  - Procédures de désinstallation
  
- **Documentation de changelog** (`CHANGELOG.md`)
  - Historique des modifications
  - Versioning sémantique

### Modifié
- **Script de validation VSCode** (`validate-vscode-config.ps1`)
  - Correction de l'encodage UTF-8 du fichier
  - Amélioration de la lisibilité des tests
  - Ajout de tests supplémentaires pour les caractères spéciaux

### Corrigé
- **Problèmes d'encodage dans les scripts**
  - Re-encodage de tous les scripts en UTF-8 BOM
  - Correction des caractères corrompus
  - Standardisation de l'encodage des fichiers

- **Configuration du profil PowerShell**
  - Ajout de la configuration UTF-8 manquante
  - Configuration automatique de `$OutputEncoding`
  - Configuration de `[Console]::OutputEncoding` et `[Console]::InputEncoding`
  - Définition automatique de la code page 65001

- **Gestion des erreurs**
  - Amélioration de la robustesse des scripts
  - Gestion des cas d'erreur avec try-catch
  - Messages d'erreur plus informatifs

## [0.9.0] - 2025-05-26 (État initial)

### Existant avant finalisation
- **Scripts de base**
  - `backup-profile.ps1` - Sauvegarde du profil PowerShell
  - `fix-encoding-simple.ps1` - Correction d'encodage basique
  - `fix-encoding.ps1` - Script de correction principal
  - `restore-profile.ps1` - Restauration du profil
  - `run-encoding-fix.ps1` - Script d'orchestration
  - `test-basic.ps1` - Tests de validation basiques
  - `test-encoding-simple.ps1` - Tests d'encodage simples
  - `test-encoding.ps1` - Tests d'encodage complets
  - `test-simple.ps1` - Tests simples
  - `validate-vscode-config.ps1` - Validation VSCode (avec problèmes d'encodage)

- **Documentation existante**
  - `README.md` - Documentation principale
  - `README-Configuration-VSCode-UTF8.md` - Configuration VSCode
  - `RESUME-CONFIGURATION.md` - Résumé de configuration
  - `VALIDATION-REPORT.md` - Rapport de validation initial

- **Fichiers de test**
  - `test-caracteres-francais.txt` - Fichier de test des caractères
  - `test-simple.txt` - Fichier de test simple

### Problèmes identifiés (résolus en v1.0.0)
- ❌ **Configuration du profil PowerShell incomplète**
  - Manque de `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`
  - Manque de `$OutputEncoding = [System.Text.Encoding]::UTF8`
  - Manque de `chcp 65001 > $null`

- ❌ **Scripts avec erreurs d'encodage**
  - `validate-vscode-config.ps1` contenait des caractères corrompus
  - Problèmes de syntaxe dus à l'encodage incorrect

- ❌ **Absence de script de déploiement automatique**
  - Pas de solution "one-click" pour le déploiement
  - Configuration manuelle requise

- ❌ **Documentation de déploiement incomplète**
  - Pas de guide pour d'autres machines
  - Instructions de dépannage limitées

## Détails techniques

### Configuration UTF-8 complète

La solution v1.0.0 implémente une configuration UTF-8 complète :

```powershell
# Configuration d'encodage UTF-8 pour PowerShell
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null
```

### Configuration VSCode intégrée

```json
{
    "files.encoding": "utf8",
    "files.autoGuessEncoding": false,
    "terminal.integrated.defaultProfile.windows": "PowerShell UTF-8"
}
```

### Tests de validation

- ✅ Vérification de la code page (65001)
- ✅ Test des encodages PowerShell
- ✅ Affichage des caractères français
- ✅ Validation de la configuration VSCode
- ✅ Tests de lecture/écriture de fichiers UTF-8

## Migration depuis les versions antérieures

### De v0.9.0 vers v1.0.0

1. **Sauvegarde recommandée** :
   ```powershell
   .\backup-profile.ps1
   ```

2. **Déploiement de la nouvelle version** :
   ```powershell
   .\apply-encoding-fix.ps1 -Force
   ```

3. **Validation** :
   ```powershell
   .\validate-deployment.ps1 -CreateReport
   ```

### Compatibilité

- ✅ **Rétrocompatible** avec les configurations existantes
- ✅ **Préservation** des configurations Chocolatey et autres
- ✅ **Sauvegarde automatique** avant modification

## Roadmap future

### Version 1.1.0 (Planifiée)
- [ ] Support de PowerShell Core 7.x
- [ ] Configuration Windows Terminal
- [ ] Script de mise à jour automatique
- [ ] Interface graphique optionnelle

### Version 1.2.0 (Planifiée)
- [ ] Support multi-utilisateur
- [ ] Configuration centralisée
- [ ] Intégration avec Group Policy
- [ ] Monitoring de la configuration

## Notes de développement

### Environnement de test
- **OS** : Windows 11
- **PowerShell** : 5.1.26100.4061
- **VSCode** : Dernière version
- **Culture** : fr-FR

### Métriques de qualité
- **Scripts** : 100% encodés en UTF-8
- **Tests** : Validation automatisée complète
- **Documentation** : Guide complet avec FAQ
- **Robustesse** : Gestion d'erreurs et rollback

---

**Légende** :
- ✅ Fonctionnel et testé
- ⚠️ Fonctionnel avec limitations
- ❌ Problème identifié
- 🔄 En cours de développement
- 📋 Planifié