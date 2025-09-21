# =================================================================================================
#
#   Script de Validation de la Configuration MCP
#
#   Ce script a pour unique but de valider la présence et l'intégrité de base des fichiers
#   de configuration essentiels aux serveurs "Model Context Protocol" (MCP).
#
#   Vérifications effectuées :
#   1. Existence des fichiers de configuration critiques (servers.json, modes.json).
#   2. Validité de la syntaxe JSON de ces fichiers.
#
# =================================================================================================

[CmdletBinding()]
param()

# =================================================================================================
#   FONCTIONS UTILITAIRES
# =================================================================================================

function Write-ColorOutput {
    param([string]$Message, [ConsoleColor]$ForegroundColor = "White")
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Test-JsonFile {
    param([string]$FilePath)
    $relativePAth = $FilePath -replace "$PSScriptRoot[\\/]"
    try {
        Get-Content -Path $FilePath -Raw | ConvertFrom-Json | Out-Null
        Write-ColorOutput "  [✓] Le fichier '$relativePAth' est un JSON valide." "Green"
        return $true
    }
    catch {
        Write-ColorOutput "  [✗] Le fichier '$relativePAth' contient un JSON INVALIDE." "Red"
        Write-ColorOutput "      Erreur: $($_.Exception.Message)" "Yellow"
        return $false
    }
}

# =================================================================================================
#   EXÉCUTION PRINCIPALE
# =================================================================================================

Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "     Validation de la Configuration MCP " "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

$projectRoot = (Get-Item $PSScriptRoot).parent.parent.FullName
$mcpFiles = @(
    "roo-config/settings/servers.json",
    "roo-config/modes/modes.json"
)
$allChecksPassed = $true

Write-ColorOutput "Vérification des fichiers de configuration critiques...`n" "Yellow"

foreach ($file in $mcpFiles) {
    $fullPath = Join-Path -Path $projectRoot -ChildPath $file
    
    Write-ColorOutput "Analyse de: $file"
    if (-not (Test-Path $fullPath)) {
        Write-ColorOutput "  [✗] FICHIER MANQUANT!" "Red"
        $allChecksPassed = $false
        continue
    } else {
        Write-ColorOutput "  [✓] Fichier trouvé." "Green"
    }

    if (-not (Test-JsonFile -FilePath $fullPath)) {
        $allChecksPassed = $false
    }
    Write-ColorOutput "" # Ligne vide pour l'espacement
}

# =================================================================================================
#   RÉSUMÉ FINAL
# =================================================================================================

Write-ColorOutput "==========================================================" "Cyan"
if ($allChecksPassed) {
    Write-ColorOutput "Validation réussie: La configuration MCP semble correcte." "Green"
    exit 0
} else {
    Write-ColorOutput "Validation échouée: Des problèmes ont été détectés dans la configuration MCP." "Red"
    exit 1
}