#Requires -Version 5.1
[CmdletBinding()]
param (
    [Switch]$Validate,
    [Switch]$Repair
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Output $logLine
}

function Test-JsonFile {
    param([string]$FilePath)
    try {
        Get-Content -Path $FilePath -Raw | ConvertFrom-Json | Out-Null
        return $true
    } catch {
        Write-Log -Level "ERROR" -Message "Fichier JSON invalide: $FilePath. Erreur: $($_.Exception.Message)"
        return $false
    }
}

function Test-Encoding {
    param([string]$FilePath)
    try {
        $encoding = (Get-FileEncoding -Path $FilePath).EncodingName
        if ($encoding -ne "UTF-8") {
             Write-Log -Level "WARNING" -Message "L'encodage du fichier $FilePath n'est pas UTF-8 (détecté: $encoding)."
            if ($Repair) {
                Write-Log -Level "INFO" -Message "Tentative de réparation de l'encodage pour $FilePath..."
                $content = Get-Content -Path $FilePath -Raw
                Set-Content -Path $FilePath -Value $content -Encoding UTF8 -NoNewline
                Write-Log -Level "SUCCESS" -Message "Encodage de $FilePath converti en UTF-8."
            }
        } else {
             Write-Log -Level "INFO" -Message "Encodage du fichier $FilePath est correct (UTF-8)."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Impossible de vérifier l'encodage pour $FilePath. Erreur: $($_.Exception.Message)"
    }
}

Write-Log "Début du diagnostic MCP..."

$serversFile = "roo-config/settings/servers.json"
$modesFile = "roo-config/modes/modes.json"
$filesToValidate = @($serversFile, $modesFile)

$allValid = $true

foreach ($file in $filesToValidate) {
    if (-not (Test-Path $file)) {
        Write-Log -Level "ERROR" -Message "Fichier de configuration MCP manquant: $file"
        $allValid = $false
        continue
    }

    Write-Log "Validation de la syntaxe JSON pour $file..."
    if (-not (Test-JsonFile -FilePath $file)) {
        $allValid = $false
    }

    Write-Log "Vérification de l'encodage pour $file..."
    Test-Encoding -FilePath $file
}

if ($Validate) {
    if ($allValid) {
        Write-Log -Level "SUCCESS" -Message "Diagnostic MCP terminé. Tous les fichiers de configuration de base sont valides."
    } else {
        Write-Log -Level "FAILURE" -Message "Diagnostic MCP terminé. Des problèmes ont été détectés."
        # Exit with a non-zero code to indicate failure
        exit 1
    }
}

Write-Log "Fin du diagnostic MCP."