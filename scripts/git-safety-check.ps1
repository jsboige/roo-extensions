# Script de Sécurité Git - Prévention des Catastrophes
# Auteur: Agent Debug - Système de Réparation d'Urgence
# Date: 2025-11-03
# Version: 1.0

param(
    [Parameter(Mandatory=$true)]
    [string]$Operation = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

# Fonctions de sécurité
function Test-GitSafety {
    param([string]$TestOperation)
    
    Write-Host "🔍 TEST DE SÉCURITÉ: $TestOperation" -ForegroundColor Yellow
    
    # Vérifier le nombre de notifications
    $status = git status --porcelain
    $notificationCount = ($status | Measure-Object).Count
    
    Write-Host "   Notifications actuelles: $notificationCount" -ForegroundColor Cyan
    
    # Seuil d'alerte
    if ($notificationCount -gt 100) {
        Write-Host "   ⚠️  ALERTE: Nombre critique de notifications !" -ForegroundColor Red
        return $false
    }
    
    # Vérifier les répertoires critiques
    $criticalDirs = @("scripts/", "tests/", "mcps/", "roo-*/")
    foreach ($dir in $criticalDirs) {
        if (Test-Path $dir) {
            Write-Host "   ✅ $dir : Présent et intact" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $dir : MANQUANT ou CORROMPU" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

function Backup-BeforeOperation {
    param([string]$OperationDescription)
    
    Write-Host "💾 SAUVEGARDE AUTOMATIQUE AVANT: $OperationDescription" -ForegroundColor Blue
    
    $stashName = "safety-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git stash push -m "Sauvegarde sécurité: $OperationDescription" $stashName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Sauvegarde créée: $stashName" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Échec de sauvegarde" -ForegroundColor Red
    }
}

function Validate-DirectoryStructure {
    param([string]$TargetPath)
    
    Write-Host "🔍 VALIDATION DE STRUCTURE: $TargetPath" -ForegroundColor Yellow
    
    if (-not (Test-Path $TargetPath)) {
        Write-Host "   ❌ Répertoire cible inexistant" -ForegroundColor Red
        return $false
    }
    
    $expectedSubdirs = @("analysis", "archive", "audit", "cleanup", "demo-scripts", 
                         "deployment", "diagnostic", "docs", "encoding", "git", 
                         "install", "inventory", "maintenance", "messaging", 
                         "monitoring", "repair", "roosync", "setup", "stash-recovery", 
                         "testing", "utf8", "validation")
    
    $missingDirs = @()
    foreach ($subdir in $expectedSubdirs) {
        $fullPath = Join-Path $TargetPath $subdir
        if (-not (Test-Path $fullPath)) {
            $missingDirs += $subdir
        }
    }
    
    if ($missingDirs.Count -gt 0) {
        Write-Host "   ❌ Sous-répertoires manquants: $($missingDirs -join ', ')" -ForegroundColor Red
        return $false
    }
    
    Write-Host "   ✅ Structure validée" -ForegroundColor Green
    return $true
}

# Point d'entrée principal
switch ($Operation) {
    "check" {
        Write-Host "🚨 CONTRÔLE DE SÉCURITÉ GIT COMPLET" -ForegroundColor Red
        Write-Host ""
        
        $safetyResult = Test-GitSafety
        if (-not $safetyResult) {
            Write-Host "🚨 PROBLÈMES DE SÉCURITÉ DÉTECTÉS !" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "✅ SÉCURITÉ VALIDÉE - Opération autorisée" -ForegroundColor Green
    }
    
    "backup" {
        Backup-BeforeOperation "Sauvegarde générale de sécurité"
    }
    
    "validate-scripts" {
        Validate-DirectoryStructure "scripts/"
    }
    
    "validate-tests" {
        Validate-DirectoryStructure "tests/"
    }
    
    default {
        Write-Host "Usage: .\git-safety-check.ps1 -Operation <check|backup|validate-scripts|validate-tests>" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Opérations disponibles:" -ForegroundColor Cyan
        Write-Host "  check          - Contrôle complet de sécurité" -ForegroundColor White
        Write-Host "  backup         - Sauvegarde avant opération" -ForegroundColor White
        Write-Host "  validate-scripts - Validation structure scripts/" -ForegroundColor White
        Write-Host "  validate-tests   - Validation structure tests/" -ForegroundColor White
        exit 1
    }
}

Write-Host "🛡️  SCRIPT DE SÉCURITÉ GIT TERMINÉ" -ForegroundColor Green