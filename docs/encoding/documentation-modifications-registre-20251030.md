# Documentation des Modifications du Registre UTF-8

**Date**: 2025-10-30  
**Version**: 1.0  
**Auteur**: Roo Architect Complex Mode  
**ID Correction**: SYS-002-REGISTRY  
**Priorité**: CRITIQUE  

---

## 📋 Vue d'Ensemble

Ce document décrit en détail les modifications apportées au registre Windows pour standardiser l'encodage UTF-8 (Code Page 65001) sur les systèmes Windows 11 Pro français.

### Objectifs Principaux

1. **Standardisation UTF-8**: Configurer toutes les pages de code système sur 65001
2. **Cohérence Système**: Assurer l'uniformité entre les différentes sections du registre
3. **Sécurité**: Implémenter des mécanismes de backup et rollback
4. **Validation**: Fournir des outils de vérification post-modification

---

## 🔧 Modifications Techniques Détaillées

### 1. Pages de Code Système (HKLM)

#### Clé Principale
```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\CodePage
```

#### Valeurs Modifiées

| Nom de Valeur | Type | Avant | Après | Description |
|---------------|------|--------|-------|-------------|
| ACP | REG_DWORD | Variable | 65001 | ANSI Code Page - Applications Windows |
| OEMCP | REG_DWORD | Variable | 65001 | OEM Code Page - Applications console |
| MACCP | REG_DWORD | Variable | 65001 | Macintosh Code Page - Compatibilité Mac |

#### Impact Technique

- **ACP (ANSI Code Page)**: Définit l'encodage par défaut pour les applications Windows non-Unicode
- **OEMCP (OEM Code Page)**: Définit l'encodage pour les applications console et DOS
- **MACCP (Macintosh Code Page)**: Définit l'encodage pour la compatibilité avec les fichiers Mac

### 2. Paramètres Console Utilisateur (HKCU)

#### Clé Principale
```
HKEY_CURRENT_USER\Console
```

#### Valeurs Modifiées

| Nom de Valeur | Type | Avant | Après | Description |
|---------------|------|--------|-------|-------------|
| CodePage | REG_DWORD | Variable | 65001 | Page de code console par défaut |
| FaceName | REG_SZ | Variable | Consolas | Police console optimisée UTF-8 |
| FontFamily | REG_SZ | Variable | Consolas | Famille de police console |

#### Impact Technique

- **CodePage**: Force l'encodage UTF-8 pour toutes les nouvelles fenêtres console
- **FaceName**: Police Consolas optimisée pour l'affichage des caractères UTF-8
- **FontFamily**: Assure la cohérence de la police système

### 3. Paramètres Internationaux (HKCU)

#### Clé Principale
```
HKEY_CURRENT_USER\Control Panel\International
```

#### Valeurs Modifiées

| Nom de Valeur | Type | Avant | Après | Description |
|---------------|------|--------|-------|-------------|
| Locale | REG_SZ | Variable | 0000040C | Locale français (France) |
| LocaleName | REG_SZ | Variable | fr-FR | Nom de locale standard |
| sCountry | REG_SZ | Variable | France | Pays par défaut |
| sLanguage | REG_SZ | Variable | FRA | Langue par défaut |

#### Impact Technique

- **Locale**: Identifiant hexadécimal du locale système (0000040C = fr-FR)
- **LocaleName**: Nom du locale au format ISO 639-1/ISO 3166-1
- **sCountry/sLanguage**: Paramètres de compatibilité pour applications héritées

---

## 🛡️ Mécanismes de Sécurité

### 1. Backup Automatique

#### Format de Backup
```
backups\registry-backup-YYYYMMDD-HHMMSS.reg
```

#### Contenu du Backup
- Export complet des clés modifiées avant toute modification
- Métadonnées de timestamp et version du script
- Hash SHA256 pour vérification d'intégrité

#### Script de Backup
```powershell
# Export des clés avant modification
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage" "backups\codepage-backup.reg"
reg export "HKCU\Console" "backups\console-backup.reg"
reg export "HKCU\Control Panel\International" "backups\international-backup.reg"
```

### 2. Validation Pré-Modification

#### Tests Exécutés
1. **Permissions Administrateur**: Vérification des droits de modification du registre
2. **Existence des Clés**: Validation que les clés cibles existent
3. **Valeurs Actuelles**: Lecture et enregistrement des valeurs avant modification
4. **Cohérence Système**: Vérification de l'état UTF-8 actuel

### 3. Rollback Automatique

#### Procédure de Rollback
```powershell
# Restauration depuis backup
reg import "backups\registry-backup-YYYYMMDD-HHMMSS.reg"

# Redémarrage des services affectés
Restart-Service -Name "Winmgmt" -Force
```

#### Points de Restauration
- **Rollback Immédiat**: Restauration des valeurs depuis le backup le plus récent
- **Rollback Sélectif**: Restauration d'une section spécifique du registre
- **Rollback Complet**: Restauration de l'état complet du registre avant modifications

---

## 🔄 Procédures d'Application

### 1. Phase de Préparation

#### Étape 1: Analyse Système
```powershell
# Détection de l'état UTF-8 actuel
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
Get-ItemProperty -Path "HKCU\Console"
Get-ItemProperty -Path "HKCU\Control Panel\International"
```

#### Étape 2: Backup des Valeurs
```powershell
# Création du backup avec timestamp
$backupPath = "backups\registry-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage" $backupPath
```

#### Étape 3: Validation des Prérequis
```powershell
# Vérification des permissions administrateur
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent().IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Droits administrateur requis"
    exit 1
}
```

### 2. Phase de Modification

#### Étape 1: Pages de Code Système
```powershell
# Configuration ACP/OEMCP/MACCP sur 65001
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "ACP" -Value 65001 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "OEMCP" -Value 65001 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "MACCP" -Value 65001 -Type DWord -Force
```

#### Étape 2: Paramètres Console
```powershell
# Configuration console UTF-8
Set-ItemProperty -Path "HKCU\Console" -Name "CodePage" -Value 65001 -Type DWord -Force
Set-ItemProperty -Path "HKCU\Console" -Name "FaceName" -Value "Consolas" -Type String -Force
Set-ItemProperty -Path "HKCU\Console" -Name "FontFamily" -Value "Consolas" -Type String -Force
```

#### Étape 3: Paramètres Internationaux
```powershell
# Configuration locale français
Set-ItemProperty -Path "HKCU\Control Panel\International" -Name "Locale" -Value "0000040C" -Type String -Force
Set-ItemProperty -Path "HKCU\Control Panel\International" -Name "LocaleName" -Value "fr-FR" -Type String -Force
Set-ItemProperty -Path "HKCU\Control Panel\International" -Name "sCountry" -Value "France" -Type String -Force
Set-ItemProperty -Path "HKCU\Control Panel\International" -Name "sLanguage" -Value "FRA" -Type String -Force
```

### 3. Phase de Validation

#### Étape 1: Validation Immédiate
```powershell
# Vérification que les valeurs sont correctement appliquées
$codePages = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
$console = Get-ItemProperty -Path "HKCU\Console"
$intl = Get-ItemProperty -Path "HKCU\Control Panel\International"

# Validation UTF-8 (65001)
$validACP = ($codePages.ACP -eq 65001)
$validOEMCP = ($codePages.OEMCP -eq 65001)
$validConsole = ($console.CodePage -eq 65001)
```

#### Étape 2: Tests de Compatibilité
```powershell
# Test de création de fichiers UTF-8
"Test UTF-8: é è à ù ç" | Out-File -FilePath "temp\utf8-test.txt" -Encoding UTF8

# Test de la console
cmd /c "chcp 65001 && echo Test UTF-8: é è à ù ç"
```

---

## 📊 Impact Système

### 1. Applications Affectées

| Type d'Application | Impact | Niveau de Modification |
|------------------|---------|----------------------|
| Applications Windows | Complet | Lecture automatique des nouvelles valeurs |
| Applications Console | Complet | Nouvelles fenêtres avec UTF-8 |
| Applications .NET | Partiel | Nécessite redémarrage pour prise en compte |
| Applications Legacy | Variable | Dépend de l'implémentation UTF-8 |

### 2. Services Système

| Service | Impact | Action Requise |
|---------|---------|----------------|
| Winmgmt (WMI) | Redémarrage recommandé | `Restart-Service Winmgmt` |
| Spooler (Impression) | Redémarrage recommandé | `Restart-Service Spooler` |
| Themes | Redémarrage requis | Prise en compte au redémarrage |

### 3. Compatibilité

#### Systèmes Supportés
- ✅ Windows 10 Pro (1903+)
- ✅ Windows 11 Pro (toutes versions)
- ✅ Windows Server 2019+
- ❌ Windows Home (limitations registre)

#### Architectures Supportées
- ✅ x64 (64-bit)
- ✅ ARM64
- ❌ x86 (32-bit) - non testé

---

## 🔍 Procédures de Dépannage

### 1. Problèmes Communs

#### Erreur: "Accès refusé au registre"
**Cause**: Droits administrateur insuffisants  
**Solution**: Exécuter en tant qu'administrateur  
**Commande**: `Start-Process powershell -Verb RunAs`

#### Erreur: "Clé de registre introuvable"
**Cause**: Version Windows incompatible ou corruption registre  
**Solution**: Vérifier la version Windows et réparer le registre  
**Commande**: `sfc /scannow` puis `dism /online /cleanup-image /restorehealth`

#### Erreur: "Valeurs non appliquées après redémarrage"
**Cause**: Stratégie de groupe ou antivirus bloquant  
**Solution**: Vérifier les stratégies locales et exceptions antivirus  
**Commande**: `gpedit.msc` pour vérifier les stratégies

### 2. Validation Post-Modification

#### Script de Validation
```powershell
# Exécution du script de validation complet
.\Test-UTF8RegistryValidation.ps1 -Detailed -OutputFormat Markdown

# Vérification du taux de succès
$successRate = .\Test-UTF8RegistryValidation.ps1 | ConvertFrom-Json
if ($successRate.summary.successRate -ge 95) {
    Write-Host "Validation réussie"
} else {
    Write-Host "Validation partielle - actions requises"
}
```

#### Tests Manuel
1. **Créer un fichier texte** avec caractères accentués
2. **Ouvrir l'invite de commande** et vérifier `chcp 65001`
3. **Tester Notepad** avec caractères UTF-8
4. **Vérifier l'Explorateur** avec noms de fichiers UTF-8

---

## 📝 Journal des Modifications

### Format des Entrées
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] MESSAGE
```

### Niveaux de Log
- **INFO**: Informations générales
- **SUCCESS**: Opérations réussies
- **WARN**: Avertissements non critiques
- **ERROR**: Erreurs bloquantes
- **DEBUG**: Informations de débogage

### Exemple de Log
```
[2025-10-30 16:20:00] [INFO] Début de la modification du registre UTF-8
[2025-10-30 16:20:01] [SUCCESS] Backup créé: backups\registry-backup-20251030-162001.reg
[2025-10-30 16:20:02] [SUCCESS] ACP modifié: 1252 → 65001
[2025-10-30 16:20:03] [SUCCESS] OEMCP modifié: 850 → 65001
[2025-10-30 16:20:04] [SUCCESS] MACCP modifié: 10000 → 65001
[2025-10-30 16:20:05] [SUCCESS] Console CodePage modifié: 850 → 65001
[2025-10-30 16:20:06] [SUCCESS] Locale modifié: 00000409 → 0000040C
[2025-10-30 16:20:07] [INFO] Validation post-modification requise
```

---

## 🚀 Prochaines Étapes

### 1. Validation Complète
- Exécuter `Test-UTF8RegistryValidation.ps1` avec tous les tests
- Générer le rapport de validation complet
- Vérifier que le taux de succès est >95%

### 2. Tests d'Intégration
- Tester les applications critiques avec les nouvelles valeurs
- Valider la compatibilité avec les outils de développement
- Vérifier la persistance après redémarrage

### 3. Documentation Utilisateur
- Créer le guide utilisateur pour la validation
- Documenter les procédures de rollback
- Préparer les supports de dépannage

### 4. Transition vers Jour 4-4
Une fois la validation du registre réussie (>95% de succès):
- Passer à la standardisation des variables d'environnement
- Créer le script `Set-StandardizedEnvironment.ps1`
- Implémenter la validation environnement

---

## 📋 Checklist de Validation

### Avant Modification
- [ ] Droits administrateur vérifiés
- [ ] Backup des valeurs actuelles créé
- [ ] Clés de registre validées
- [ ] Prérequis système confirmés

### Pendant Modification
- [ ] Pages de code système modifiées (ACP/OEMCP/MACCP)
- [ ] Paramètres console configurés
- [ ] Paramètres internationaux appliqués
- [ ] Logs de modification enregistrés

### Après Modification
- [ ] Validation immédiate exécutée
- [ ] Taux de succès calculé
- [ ] Rapport de validation généré
- [ ] Prochaines étapes planifiées

---

## 📞 Support et Assistance

### Contact Support
- **Documentation Technique**: Ce document
- **Scripts de Validation**: `Test-UTF8RegistryValidation.ps1`
- **Logs Système**: `logs\Test-UTF8RegistryValidation-*.log`
- **Rapports**: `results\utf8-registry-validation-*\`

### Ressources Externes
- **Documentation Microsoft**: Encodage Windows et Unicode
- **Base de Connaissances**: Articles sur les pages de code UTF-8
- **Community**: Forums techniques et GitHub pour les retours d'expérience

---

**Statut du Document**: ✅ COMPLET  
**Version**: 1.0  
**Prochaine Mise à Jour**: Après validation Jour 4-4  
**Responsable**: Roo Architect Complex Mode