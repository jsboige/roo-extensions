# Script PowerShell pour mettre à jour les modes personnalisés avec les optimisations MCP
# Ce script remplace la section UTILISATION OPTIMISÉE DES MCPs dans les fichiers de configuration des modes

# Définition des chemins
$configsDir = Join-Path $PSScriptRoot "..\..\n5\configs"
$examplesDir = Join-Path $PSScriptRoot "..\examples"
$optimizationsDir = Join-Path $PSScriptRoot "..\docs\optimisation"

# Vérification des répertoires
if (-not (Test-Path $configsDir)) {
    Write-Error "Le répertoire des configurations n'existe pas: $configsDir"
    exit 1
}

if (-not (Test-Path $examplesDir)) {
    Write-Error "Le répertoire des exemples n'existe pas: $examplesDir"
    exit 1
}

if (-not (Test-Path $optimizationsDir)) {
    Write-Error "Le répertoire des optimisations n'existe pas: $optimizationsDir"
    exit 1
}

# Fonction pour extraire la section d'optimisation MCP d'un fichier
function Get-McpOptimizationSection {
    param (
        [string]$FilePath,
        [string]$Level
    )

    $content = Get-Content -Path $FilePath -Raw
    $pattern = "(?s)/\* UTILISATION OPTIMISÉE DES MCPs \*/.*?(?=/\* VERROUILLAGE DE FAMILLE \*/)"
    
    if ($content -match $pattern) {
        return $matches[0]
    }
    
    Write-Warning "Section d'optimisation MCP non trouvée dans $FilePath"
    return $null
}

# Fonction pour remplacer la section d'optimisation MCP dans un fichier
function Update-McpOptimizationSection {
    param (
        [string]$ConfigFile,
        [string]$OptimizationSection
    )

    $content = Get-Content -Path $ConfigFile -Raw
    $pattern = "(?s)/\* UTILISATION OPTIMISÉE DES MCPs \*/.*?(?=/\* VERROUILLAGE DE FAMILLE \*/)"
    
    if ($content -match $pattern) {
        $updatedContent = $content -replace $pattern, $OptimizationSection
        Set-Content -Path $ConfigFile -Value $updatedContent -NoNewline
        Write-Host "Section d'optimisation MCP mise à jour dans $ConfigFile"
        return $true
    }
    
    Write-Warning "Section d'optimisation MCP non trouvée dans $ConfigFile"
    return $false
}

# Extraction des sections optimisées depuis les exemples
$microOptimization = Get-McpOptimizationSection -FilePath (Join-Path $optimizationsDir "utilisation-optimisee-mcps.md") -Level "micro"
$miniOptimization = Get-McpOptimizationSection -FilePath (Join-Path $optimizationsDir "utilisation-optimisee-mcps.md") -Level "mini"
$mediumOptimization = Get-McpOptimizationSection -FilePath (Join-Path $optimizationsDir "utilisation-optimisee-mcps.md") -Level "medium"
$largeOptimization = Get-McpOptimizationSection -FilePath (Join-Path $examplesDir "n5-code-large-optimized.json") -Level "large"
$oracleOptimization = Get-McpOptimizationSection -FilePath (Join-Path $optimizationsDir "utilisation-optimisee-mcps.md") -Level "oracle"

# Mise à jour des fichiers de configuration
$configFiles = Get-ChildItem -Path $configsDir -Filter "*.json"
$updatedCount = 0
$totalCount = 0

foreach ($file in $configFiles) {
    $totalCount++
    $filePath = $file.FullName
    $fileContent = Get-Content -Path $filePath -Raw
    
    # Détermination du niveau du mode
    $level = ""
    if ($fileContent -match '"slug":\s*"n5-code-micro"') {
        $level = "micro"
        $optimization = $microOptimization
    }
    elseif ($fileContent -match '"slug":\s*"n5-code-mini"') {
        $level = "mini"
        $optimization = $miniOptimization
    }
    elseif ($fileContent -match '"slug":\s*"n5-code-medium"') {
        $level = "medium"
        $optimization = $mediumOptimization
    }
    elseif ($fileContent -match '"slug":\s*"n5-code-large"') {
        $level = "large"
        $optimization = $largeOptimization
    }
    elseif ($fileContent -match '"slug":\s*"n5-code-oracle"') {
        $level = "oracle"
        $optimization = $oracleOptimization
    }
    else {
        Write-Warning "Niveau non déterminé pour $filePath"
        continue
    }
    
    if ($optimization) {
        $success = Update-McpOptimizationSection -ConfigFile $filePath -OptimizationSection $optimization
        if ($success) {
            $updatedCount++
        }
    }
}

Write-Host "Mise à jour terminée: $updatedCount fichiers sur $totalCount ont été mis à jour."