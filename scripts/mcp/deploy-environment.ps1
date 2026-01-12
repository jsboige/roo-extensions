# =============================================================================
# Script de déploiement pour l'environnement MCP de référence (V2 - Simplifié)
#
# Auteur: Roo
# Date: 21/07/2025
#
# Description:
# Version corrigée et simplifiée. Ce script assure la compilation des
# serveurs TypeScript et génère une configuration mcp_settings.json propre
# avec des commandes directes, sans wrappers de journalisation.
# =============================================================================

# CORRECTION SDDD v1.3: Ajout Set-StrictMode pour la robustesse PowerShell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- 1. Initialisation ---
Write-Host "=== Étape 1/4: Initialisation ==="
$ProjectRoot = $PSScriptRoot
$ConfigSource = Join-Path $ProjectRoot "mcp_settings.json"
$ConfigDestinationDir = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$targetSettingsFile = Join-Path $ConfigDestinationDir "mcp_settings.json"

Write-Host "  - Racine du projet: $ProjectRoot"
Write-Host "  - Destination de la configuration: $targetSettingsFile"
Write-Host ""

# --- 2. Build des MCPs internes ---
Write-Host "=== Étape 2/4: Installation des dépendances et build des MCPs TypeScript ==="
$config = Get-Content -Path $ConfigSource -Raw | ConvertFrom-Json

foreach ($mcpName in $config.mcpServers.PSObject.Properties.Name) {
    $mcp = $config.mcpServers.$mcpName
    
    # On ne traite que les serveurs internes qui ont un placeholder de chemin
    if ($mcp.args -join ' ' -match '\$\{mcp_paths:([a-zA-Z0-9_-]+)\}') {
        $mcpPathKey = $matches[1]
        $mcpFullPath = Join-Path $ProjectRoot "mcps/internal/servers/$mcpPathKey"
        
        if (Test-Path (Join-Path $mcpFullPath "package.json")) {
            Write-Host "Traitement du MCP interne: '$mcpName'..."
            
            try {
                Push-Location $mcpFullPath
                
                # CORRECTION SDDD v1.3: Ajout de timeout sur npm install (5 minutes)
                Write-Host "  - Installation des dépendances (npm install)..."
                $installJob = Start-Job -ScriptBlock { npm install }
                $installJob | Wait-Job -Timeout 300 | Out-Null
                if ($installJob.State -ne 'Completed') {
                    Write-Error "  [ERREUR] Timeout lors de l'installation des dépendances pour '$mcpName' (5min)."
                    Remove-Job -Job $installJob -Force -ErrorAction SilentlyContinue
                    Pop-Location
                    continue
                }
                $installOutput = Receive-Job -Job $installJob
                Remove-Job -Job $installJob -Force -ErrorAction SilentlyContinue
                
                if (Test-Path (Join-Path $mcpFullPath "tsconfig.json")) {
                    # CORRECTION SDDD v1.3: Ajout de timeout sur npx tsc (5 minutes)
                    Write-Host "  - Compilation TypeScript (npx tsc)..."
                    $tscJob = Start-Job -ScriptBlock { npx tsc }
                    $tscJob | Wait-Job -Timeout 300 | Out-Null
                    if ($tscJob.State -ne 'Completed') {
                        Write-Error "  [ERREUR] Timeout lors de la compilation TypeScript pour '$mcpName' (5min)."
                        Remove-Job -Job $tscJob -Force -ErrorAction SilentlyContinue
                        Pop-Location
                        continue
                    }
                    $tscOutput = Receive-Job -Job $tscJob
                    Remove-Job -Job $tscJob -Force -ErrorAction SilentlyContinue
                }
                
                Write-Host "  [OK] MCP '$mcpName' traité avec succès." -ForegroundColor Green
            } catch {
                Write-Error "  [ERREUR] Le traitement du MCP '$mcpName' a échoué: $($_.Exception.Message)"
            } finally {
                Pop-Location
            }
        }
    }
}
Write-Host ""

# --- 3. Génération de la configuration finale ---
Write-Host "=== Étape 3/4: Génération du fichier de configuration final ==="

# Recharger la configuration pour avoir un objet propre
$finalConfig = Get-Content -Path $ConfigSource -Raw | ConvertFrom-Json

# Itérer et modifier la configuration
foreach ($mcpName in $finalConfig.mcpServers.PSObject.Properties.Name) {
    $mcp = $finalConfig.mcpServers.$mcpName

    # Résoudre les placeholders de chemin pour les serveurs internes
    $argString = $mcp.args -join ' '
    if ($argString -match '\$\{mcp_paths:([a-zA-Z0-9_-]+)\}') {
        $mcpPathKey = $matches[1]
        $mcpFullPath = (Resolve-Path (Join-Path $ProjectRoot "mcps/internal/servers/$mcpPathKey")).Path.Replace('\', '/')
        
        $newArgs = @()
        foreach($arg in $mcp.args) {
            $newArgs += $arg.Replace('${mcp_paths:' + $mcpPathKey + '}', $mcpFullPath)
        }
        $mcp.args = $newArgs
        Write-Host "  - Chemin résolu pour '$mcpName'."
    }
    
    # --- Traitement modulaire des .env locaux ---
   $mcpDir = Join-Path $ProjectRoot "mcps/internal/servers/$($mcp.args -join ' ' | Select-String -Pattern '(?<=\$\{mcp_paths:)[a-zA-Z0-9_-]+' | %{$_.Matches.Value})"
   if($mcpPathKey){
        $mcpDir = Join-Path $ProjectRoot "mcps/internal/servers/$mcpPathKey"
   }
   $localEnvFile = Join-Path $mcpDir ".env"

   if (Test-Path $localEnvFile) {
       Write-Host "  - Fichier .env local trouvé pour '$mcpName'. Fusion des variables."
       # S'assurer que l'objet 'env' existe
       if (-not $mcp.PSObject.Properties.name.Contains('env')) {
           $mcp | Add-Member -MemberType NoteProperty -Name "env" -Value (New-Object -TypeName PSObject)
       }
       Get-Content $localEnvFile | ForEach-Object {
           $key, $value = $_.Split('=', 2)
           if ($key -and $value) {
               $trimmedKey = $key.Trim()
               $trimmedValue = $value.Trim().Trim('"')
               if ($mcp.env.PSObject.Properties.name.Contains($trimmedKey)) {
                   $mcp.env.$trimmedKey = $trimmedValue
               } else {
                   $mcp.env | Add-Member -MemberType NoteProperty -Name $trimmedKey -Value $trimmedValue
               }
           }
       }
   }

    # --- Correction spécifique pour github-projects ---
    if ($mcpName -eq "github-projects") {
        $mcp.transportType = "http"
        # Un MCP en mode http n'est pas lancé par Roo, donc on vide command/args
        if ($mcp.PSObject.Properties.Name.Contains('command')) {
           $mcp.command = $null
        }
        if ($mcp.PSObject.Properties.Name.Contains('args')) {
           $mcp.args = @()
        }
        Write-Host "  - Correction appliquée pour '$mcpName': transportType='http', commande et args purgés." -ForegroundColor Cyan
    }

    # Cas spécial: Filtrer les arguments de lecteur invalides pour 'filesystem'
    if ($mcpName -eq "filesystem") {
        $originalArgs = $mcp.args
        $validArgs = @()
        foreach ($arg in $originalArgs) {
            if ($arg -notmatch '^[a-zA-Z]:$' -or (Test-Path $arg)) {
                $validArgs += $arg
            } else {
                Write-Host "  - Argument de lecteur invalide ignoré pour filesystem: '$arg'" -ForegroundColor Yellow
            }
        }
        $mcp.args = $validArgs
    }
}
Write-Host ""

# --- 4. Écriture du fichier de configuration ---
Write-Host "=== Étape 4/4: Déploiement du fichier de configuration ==="
if (-not (Test-Path $ConfigDestinationDir)) {
    New-Item -ItemType Directory -Force -Path $ConfigDestinationDir | Out-Null
}

# Convertir l'objet final en JSON et remplacer les variables d'environnement
$envFile = Join-Path $ProjectRoot ".env"
$envVars = @{}
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $key, $value = $_.Split('=', 2)
        if ($key -and $value) {
            $envVars[$key.Trim()] = $value.Trim().Trim('"')
        }
    }
}

$jsonOutput = $finalConfig | ConvertTo-Json -Depth 10
foreach($key in $envVars.Keys) {
    $placeholder = '${env:' + $key + '}'
    if ($jsonOutput.Contains($placeholder)) {
        $jsonOutput = $jsonOutput.Replace($placeholder, $envVars[$key])
        Write-Host "  - Variable d'environnement '$key' substituée."
    }
}

# Écrire le fichier final sans BOM
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($targetSettingsFile, $jsonOutput, $utf8WithoutBom)

Write-Host ""
Write-Host "---------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Environnement MCP déployé avec succès (version simplifiée)." -ForegroundColor Cyan
Write-Host "---------------------------------------------------------" -ForegroundColor Cyan