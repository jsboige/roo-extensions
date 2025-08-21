<#
.SYNOPSIS
    Met à jour en masse les configurations des "Modes" MCP dans les fichiers JSON.

.DESCRIPTION
    Ce script est un outil de refactorisation pour appliquer des changements structurels
    aux instructions (prompts) des modes. Il peut injecter ou mettre à jour des sections
    spécifiques dans les 'customInstructions' de chaque mode défini dans les fichiers JSON cibles.
    Il est conçu pour être robuste, avec une détection flexible des points d'insertion,
    la préservation de l'encodage des fichiers, et un mode de simulation.

.PARAMETER Path
    Un ou plusieurs chemins vers les fichiers de configuration JSON des modes à mettre à jour.

.PARAMETER Section
    La section de configuration à mettre à jour. Actuellement, seule "SubtaskCreationRules" est supportée.
    ValidateSet: "SubtaskCreationRules"

.PARAMETER DryRun
    Simule toutes les opérations. Analyse les fichiers et indique les modifications qui seraient
    faites sans écrire sur le disque.

.PARAMETER Force
    Exécute les modifications sans demander de confirmation après la simulation.

.EXAMPLE
    .\Update-ModeConfiguration.ps1 -Path ".\roo-modes\configs\standard-modes.json" -DryRun
    Description: Simule la mise à jour des règles de création de sous-tâches pour un fichier spécifique.

.EXAMPLE
    $files = Get-ChildItem ".\roo-config\modes" -Filter "*.json"
    .\Update-ModeConfiguration.ps1 -Path $files -Force
    Description: Met à jour tous les fichiers JSON dans le répertoire de configuration des modes, sans confirmation.

.NOTES
    Auteur: Roo (IA) - consolidé le 20/08/2025
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string[]]$Path,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("SubtaskCreationRules")]
    [string]$Section,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

#region Fonctions de support
function Create-Backup($FilePath) {
    if ($DryRun) { return }
    $backupPath = "$FilePath.backup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $FilePath -Destination $backupPath -Force
    Write-Host "Sauvegarde créée: $backupPath" -ForegroundColor Green
}

function Get-SubtaskCreationRules($Family) {
    $commonRules = @"
/* CREATION DE SOUS-TACHES */
// Règles strictes pour la création de sous-tâches. NON-NÉGOCIABLE.
REGLES DE CREATION DE SOUS-TACHES:
"@
    if ($Family -eq 'simple') {
        return $commonRules + @"
1. RESTRICTION: Creer UNIQUEMENT des sous-tâches avec des modes "simple". INTERDICTION d'utiliser des modes "complex".
2. MODES AUTORISES: "code-simple", "debug-simple", "architect-simple", "ask-simple", "orchestrator-simple".
3. ESCALADE: Si un mode "complex" est nécessaire, ESCALADER la tâche principale au lieu de créer une sous-tâche. Format: "[ESCALADE REQUISE POUR SOUS-TACHE] Raison...".
"@
    } else { # complex
        return $commonRules + @"
1. RESTRICTION: Creer UNIQUEMENT des sous-tâches avec des modes "complex". INTERDICTION d'utiliser des modes "simple".
2. MODES AUTORISES: "code-complex", "debug-complex", "architect-complex", "ask-complex", "orchestrator-complex", "manager".
3. DESESCALADE: Si un mode "simple" suffit, SUGGERER une désescalade de la tâche principale. Format: "[DESESCALADE SUGGEREE POUR SOUS-TACHE] Raison...".
"@
    }
}

function Find-InsertionPoint($Content, $Family) {
    if ($Content -match [regex]::Escape("/* CREATION DE SOUS-TACHES */")) {
        Write-Host "  - La section existe déjà." -ForegroundColor Yellow
        return $null
    }

    $insertionPoints = @(
        @{ Pattern = '\[SIGNALER_ESCALADE_INTERNE\]'; Priority = 1 },
        @{ Pattern = '\[ISSU D''ESCALADE INTERNE\]'; Priority = 1 },
        @{ Pattern = '\/\* MECANISME D''ESCALADE PAR APPROFONDISSEMENT \*\/'; Priority = 2 }
    )

    foreach ($point in ($insertionPoints | Sort-Object -Property Priority)) {
        if ($Content -match $point.Pattern) {
            $match = [regex]::Match($Content, $point.Pattern)
            if ($point.Priority -eq 2) { # Insert before this match
                return $match.Index
            } else { # Insert after this match
                return $match.Index + $match.Length
            }
        }
    }
    return -1 # Not found
}
#endregion

process {
    foreach ($file in $Path) {
        if (-not (Test-Path $file)) {
            Write-Host "Fichier introuvable: $file" -ForegroundColor Red
            continue
        }

        Write-Host "`n--- Traitement de $file ---" -ForegroundColor Cyan
        
        try {
            $originalContent = Get-Content -Path $file -Raw
            $jsonObj = $originalContent | ConvertFrom-Json
            $modificationsCount = 0

            foreach ($mode in $jsonObj.customModes) {
                $family = ""
                if ($mode.slug -match "-simple$") { $family = "simple" }
                elseif ($mode.slug -match "-complex$" -or $mode.slug -eq "manager") { $family = "complex" }
                else { continue }

                $insertionPoint = Find-InsertionPoint -Content $mode.customInstructions -Family $family
                if ($insertionPoint -ne $null -and $insertionPoint -ge 0) {
                    Write-Host "  - Mise à jour nécessaire pour le mode '$($mode.slug)'." -ForegroundColor Yellow
                    $modificationsCount++
                    
                    if (-not $DryRun) {
                        $sectionText = Get-SubtaskCreationRules -Family $family
                        $prompt = $mode.customInstructions
                        $newPrompt = $prompt.Insert($insertionPoint, "`n`n$sectionText`n`n")
                        $mode.customInstructions = $newPrompt
                    }
                }
            }

            if ($modificationsCount -gt 0) {
                if ($DryRun) {
                    Write-Host "[SIMULATION] $modificationsCount mode(s) serai(en)t mis à jour dans ce fichier." -ForegroundColor Magenta
                } else {
                    Create-Backup -FilePath $file
                    $jsonOptions = [System.Text.Json.JsonSerializerOptions]::new()
                    $jsonOptions.WriteIndented = $true
                    $jsonOptions.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
                    $newJson = [System.Text.Json.JsonSerializer]::Serialize($jsonObj, $jsonOptions)
                    
                    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                    [System.IO.File]::WriteAllText($file, $newJson, $utf8NoBom)
                    Write-Host "Fichier mis à jour avec succès ($modificationsCount modes modifiés)." -ForegroundColor Green
                }
            } else {
                Write-Host "Le fichier est déjà à jour."
            }
        } catch {
            Write-Host "ERREUR lors du traitement de $file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}