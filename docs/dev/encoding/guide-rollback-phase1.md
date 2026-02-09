# Guide de Rollback - Phase 1 : Corrections d'Encodage

**Date**: 2025-11-26
**Version**: 1.0
**Statut**: Validé

## 🎯 Objectif
Ce document détaille les procédures de restauration (rollback) pour l'ensemble des composants modifiés durant la Phase 1 du projet de standardisation de l'encodage. Il permet de revenir à un état stable en cas de régression critique.

## 📋 Vue d'Ensemble des Procédures

| Composant | ID Rollback | Méthode | Impact | Temps Estimé |
|-----------|-------------|---------|--------|--------------|
| **Système (Registre)** | SYS-BACKUP-002 | Script PowerShell | Critique (Reboot) | 5 min |
| **Environnement** | SYS-BACKUP-003 | Script PowerShell | Majeur (Session) | 2 min |
| **PowerShell Profiles** | ROO-BACKUP-002 | Restauration Fichier | Mineur | 1 min |
| **VSCode Terminal** | VSC-BACKUP-001 | Restauration JSON | Mineur | 1 min |

## 🛠️ Procédures Détaillées

### 1. Restauration Système (Registre & Environnement)

Cette procédure restaure les pages de code Windows (ACP/OEMCP) et les variables d'environnement système.

**Script de Rollback** :
```powershell
# Restauration des clés de registre
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "ACP" -Value "1252"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "OEMCP" -Value "850"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "MACCP" -Value "10000"

# Restauration de la console
Remove-ItemProperty -Path "HKCU:\Console" -Name "CodePage" -ErrorAction SilentlyContinue
```

**Validation Post-Rollback** :
- Redémarrer la machine.
- Vérifier `chcp` dans CMD (doit retourner 850 ou 1252, pas 65001).

### 2. Restauration Profils PowerShell

Cette procédure restaure les fichiers de profil PowerShell originaux.

**Emplacements** :
- PowerShell 5.1 : `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
- PowerShell 7+ : `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

**Commande de Restauration** :
```powershell
# Exemple pour PowerShell 7
$profilePath = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
$backupPath = "$profilePath.bak"

if (Test-Path $backupPath) {
    Copy-Item -Path $backupPath -Destination $profilePath -Force
    Write-Host "Profil restauré depuis $backupPath"
}
```

### 3. Restauration VSCode

Cette procédure annule les modifications dans `settings.json` concernant le terminal et l'encodage.

**Fichier Cible** : `%APPDATA%\Code\User\settings.json`

**Paramètres à Retirer/Modifier** :
```json
{
    "files.encoding": "utf8", // Remettre à la valeur précédente si différent
    "terminal.integrated.defaultProfile.windows": "PowerShell",
    "terminal.integrated.profiles.windows": {
        "PowerShell": {
            "source": "PowerShell",
            "args": [] // Retirer "-NoExit", "-Command", "chcp 65001" si présents
        }
    }
}
```

## 🚨 Procédure d'Urgence (Rollback Total)

En cas d'instabilité majeure du système, exécuter le script de nettoyage complet :

1. Ouvrir PowerShell en tant qu'Administrateur.
2. Exécuter :
   ```powershell
   # Désactivation de l'option Beta UTF-8 (si activée via intl.cpl)
   # Note: Nécessite une intervention manuelle via intl.cpl si le script échoue
   
   # Nettoyage des variables d'environnement ajoutées
   [Environment]::SetEnvironmentVariable("PYTHONIOENCODING", $null, "Machine")
   [Environment]::SetEnvironmentVariable("NODE_OPTIONS", $null, "Machine")
   [Environment]::SetEnvironmentVariable("JAVA_TOOL_OPTIONS", $null, "Machine")
   ```
3. Redémarrer immédiatement.

## 📞 Support

Pour toute assistance durant une procédure de rollback, contacter l'équipe Architecture (Roo Architect).