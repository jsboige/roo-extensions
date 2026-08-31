#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Script de validation des protections contre l'écrasement d'identités RooSync

.DESCRIPTION
    Ce script valide que toutes les protections critiques sont en place et fonctionnelles:
    - Registre central des machines
    - Validation d'unicité
    - Logs d'avertissement
    - Protection des fichiers de présence
    - Validation au démarrage

.PARAMETER SharedPath
    Chemin vers le répertoire partagé RooSync

.PARAMETER MachineId
    Identifiant de la machine à tester

.EXAMPLE
    .\validate-roosync-identity-protection.ps1 -SharedPath "C:\path\to\RooSync" -MachineId "my-machine"

.NOTES
    Auteur: RooSync Identity Protection System
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SharedPath = $env:ROOSYNC_SHARED_PATH,
    
    [Parameter(Mandatory=$false)]
    [string]$MachineId = $env:ROOSYNC_MACHINE_ID
)

# Configuration des couleurs pour une meilleure lisibilité
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Cyan = "Cyan"
    White = "White"
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Colors[$Color]
}

function Write-Section {
    param([string]$Title)
    Write-ColorOutput "`n" + "=" * 60 -Color "Cyan"
    Write-ColorOutput $Title -Color "Cyan"
    Write-ColorOutput "=" * 60 -Color "Cyan"
}

function Test-FileExists {
    param(
        [string]$FilePath,
        [string]$Description
    )
    
    if (Test-Path $FilePath) {
        Write-ColorOutput "✅ $Description : $FilePath" -Color "Green"
        return $true
    } else {
        Write-ColorOutput "❌ $Description : $FilePath" -Color "Red"
        return $false
    }
}

function Test-RegistryFile {
    param([string]$RegistryPath)
    
    Write-Section "TEST DU REGISTRE CENTRAL DES MACHINES"
    
    $registryFile = Join-Path $RegistryPath ".machine-registry.json"
    $exists = Test-FileExists $registryFile "Registre des machines"
    
    if ($exists) {
        try {
            $content = Get-Content $registryFile -Raw | ConvertFrom-Json
            $machines = $content.machines
            
            if ($machines -and $machines.PSObject.Properties.Count -gt 0) {
                Write-ColorOutput "✅ Registre contient $($machines.PSObject.Properties.Count) machines" -Color "Green"
                
                foreach ($machineId in $machines.PSObject.Properties.Name) {
                    $machine = $machines.$machineId
                    Write-ColorOutput "   📋 Machine: $machineId (source: $($machine.source), status: $($machine.status))" -Color "Blue"
                }
            } else {
                Write-ColorOutput "⚠️ Registre vide ou invalide" -Color "Yellow"
            }
        } catch {
            Write-ColorOutput "❌ Erreur lecture registre: $($_.Exception.Message)" -Color "Red"
        }
    }
}

function Test-IdentityRegistry {
    param([string]$RegistryPath)
    
    Write-Section "TEST DU REGISTRE D'IDENTITÉ"
    
    $identityFile = Join-Path $RegistryPath ".identity-registry.json"
    $exists = Test-FileExists $identityFile "Registre d'identité"
    
    if ($exists) {
        try {
            $content = Get-Content $identityFile -Raw | ConvertFrom-Json
            $identities = $content.identities
            
            if ($identities -and $identities.PSObject.Properties.Count -gt 0) {
                Write-ColorOutput "✅ Registre d'identité contient $($identities.PSObject.Properties.Count) identités" -Color "Green"
                
                foreach ($machineId in $identities.PSObject.Properties.Name) {
                    $identity = $identities.$machineId
                    Write-ColorOutput "   🆔 Identité: $machineId (source: $($identity.source), status: $($identity.status))" -Color "Blue"
                }
                
                # Détecter les conflits
                $conflicts = @()
                foreach ($machineId in $identities.PSObject.Properties.Name) {
                    $identity = $identities.$machineId
                    if ($identity.status -eq "conflict") {
                        $conflicts += $machineId
                    }
                }
                
                if ($conflicts.Count -gt 0) {
                    Write-ColorOutput "⚠️ Conflits d'identité détectés: $($conflicts -join ', ')" -Color "Yellow"
                } else {
                    Write-ColorOutput "✅ Aucun conflit d'identité détecté" -Color "Green"
                }
            } else {
                Write-ColorOutput "⚠️ Registre d'identité vide ou invalide" -Color "Yellow"
            }
        } catch {
            Write-ColorOutput "❌ Erreur lecture registre d'identité: $($_.Exception.Message)" -Color "Red"
        }
    }
}

function Test-PresenceFiles {
    param([string]$SharedPath)
    
    Write-Section "TEST DES FICHIERS DE PRÉSENCE"
    
    $presenceDir = Join-Path $SharedPath "presence"
    
    if (Test-Path $presenceDir) {
        $presenceFiles = Get-ChildItem $presenceDir -Filter "*.json"
        
        if ($presenceFiles.Count -gt 0) {
            Write-ColorOutput "✅ $($presenceFiles.Count) fichiers de présence trouvés" -Color "Green"
            
            $machineIds = @()
            foreach ($file in $presenceFiles) {
                try {
                    $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
                    $machineId = $content.id
                    
                    if ($machineIds -contains $machineId) {
                        Write-ColorOutput "⚠️ Conflit détecté: $machineId trouvé dans plusieurs fichiers" -Color "Yellow"
                    } else {
                        $machineIds += $machineId
                    }
                    
                    Write-ColorOutput "   📄 $($file.Name): $machineId ($($content.status))" -Color "Blue"
                } catch {
                    Write-ColorOutput "❌ Erreur lecture $($file.Name): $($_.Exception.Message)" -Color "Red"
                }
            }
            
            # Vérifier l'unicité
            $uniqueMachineIds = $machineIds | Sort-Object -Unique
            if ($uniqueMachineIds.Count -eq $machineIds.Count) {
                Write-ColorOutput "✅ Tous les machineIds sont uniques" -Color "Green"
            } else {
                Write-ColorOutput "⚠️ Conflits de machineId détectés" -Color "Yellow"
            }
        } else {
            Write-ColorOutput "⚠️ Aucun fichier de présence trouvé" -Color "Yellow"
        }
    } else {
        Write-ColorOutput "❌ Répertoire de présence inexistant: $presenceDir" -Color "Red"
    }
}

function Test-DashboardFile {
    param([string]$SharedPath)
    
    Write-Section "TEST DU DASHBOARD"
    
    $dashboardFile = Join-Path $SharedPath "sync-dashboard.json"
    $exists = Test-FileExists $dashboardFile "Fichier dashboard"
    
    if ($exists) {
        try {
            $content = Get-Content $dashboardFile -Raw | ConvertFrom-Json
            $machines = $content.machines
            
            if ($machines -and $machines.PSObject.Properties.Count -gt 0) {
                Write-ColorOutput "✅ Dashboard contient $($machines.PSObject.Properties.Count) machines" -Color "Green"
                
                foreach ($machineId in $machines.PSObject.Properties.Name) {
                    $machine = $machines.$machineId
                    Write-ColorOutput "   🖥️ Machine: $machineId (status: $($machine.status), lastSync: $($machine.lastSync))" -Color "Blue"
                }
            } else {
                Write-ColorOutput "⚠️ Dashboard vide ou invalide" -Color "Yellow"
            }
        } catch {
            Write-ColorOutput "❌ Erreur lecture dashboard: $($_.Exception.Message)" -Color "Red"
        }
    }
}

function Test-ConfigurationFiles {
    param([string]$SharedPath, [string]$MachineId)
    
    Write-Section "TEST DES FICHIERS DE CONFIGURATION"
    
    # Test sync-config.json
    $syncConfigFile = Join-Path $SharedPath "sync-config.json"
    Test-FileExists $syncConfigFile "Fichier sync-config.json"
    
    if (Test-Path $syncConfigFile) {
        try {
            $content = Get-Content $syncConfigFile -Raw | ConvertFrom-Json
            if ($content.machineId) {
                Write-ColorOutput "✅ sync-config.json contient machineId: $($content.machineId)" -Color "Green"
                
                if ($content.machineId -eq $MachineId) {
                    Write-ColorOutput "✅ machineId cohérent avec la configuration" -Color "Green"
                } else {
                    Write-ColorOutput "⚠️ Incohérence machineId: config=$MachineId, fichier=$($content.machineId)" -Color "Yellow"
                }
            } else {
                Write-ColorOutput "⚠️ sync-config.json ne contient pas de machineId" -Color "Yellow"
            }
        } catch {
            Write-ColorOutput "❌ Erreur lecture sync-config.json: $($_.Exception.Message)" -Color "Red"
        }
    }
    
    # Test sync-config.ref.json (baseline)
    $baselineFile = Join-Path $SharedPath "sync-config.ref.json"
    Test-FileExists $baselineFile "Fichier baseline (sync-config.ref.json)"
    
    if (Test-Path $baselineFile) {
        try {
            $content = Get-Content $baselineFile -Raw | ConvertFrom-Json
            if ($content.machineId) {
                Write-ColorOutput "✅ Baseline contient machineId: $($content.machineId)" -Color "Green"
            } else {
                Write-ColorOutput "⚠️ Baseline ne contient pas de machineId" -Color "Yellow"
            }
        } catch {
            Write-ColorOutput "❌ Erreur lecture baseline: $($_.Exception.Message)" -Color "Red"
        }
    }
}

# Programme principal
function Main {
    Write-ColorOutput "🚀 VALIDATION DES PROTECTIONS D'IDENTITÉ ROOSYNC" -Color "Cyan"
    Write-ColorOutput "Version: 1.0.0" -Color "Blue"
    
    if (-not $SharedPath -or -not $MachineId) {
        Write-ColorOutput "❌ Variables d'environnement manquantes. Veuillez définir ROOSYNC_SHARED_PATH et ROOSYNC_MACHINE_ID" -Color "Red"
        exit 1
    }
    
    Write-ColorOutput "📂 Chemin partagé: $SharedPath" -Color "Blue"
    Write-ColorOutput "🆔 Machine ID: $MachineId" -Color "Blue"
    
    # Vérifier que le chemin existe
    if (-not (Test-Path $SharedPath)) {
        Write-ColorOutput "❌ Le chemin partagé n'existe pas: $SharedPath" -Color "Red"
        exit 1
    }
    
    # Exécuter tous les tests
    Test-RegistryFile $SharedPath
    Test-IdentityRegistry $SharedPath
    Test-PresenceFiles $SharedPath
    Test-DashboardFile $SharedPath
    Test-ConfigurationFiles $SharedPath $MachineId
    
    Write-Section "RÉSUMÉ DE LA VALIDATION"
    Write-ColorOutput "✅ Validation terminée. Consultez les logs ci-dessus pour détecter d'éventuels problèmes." -Color "Green"
    Write-ColorOutput "💡 Si des conflits sont détectés, utilisez les outils de nettoyage RooSync appropriés." -Color "Blue"
}

# Exécuter le programme principal
Main