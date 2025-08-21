# =================================================================================================
#
#   ██████╗ ██╗   ██╗███╗   ██╗     ██████╗ ██╗ █████╗  ██████╗ ███╗   ██╗ ██████╗ ████████╗██╗ ██████╗ ██╗
#  ██╔═══██╗██║   ██║████╗  ██║    ██╔═══██╗██║██╔══██╗██╔═══██╗████╗  ██║██╔════╝ ╚══██╔══╝██║██╔═══██╗██║
#  ██║   ██║██║   ██║██╔██╗ ██║    ██║   ██║██║███████║██║   ██║██╔██╗ ██║██║         ██║   ██║██║   ██║██║
#  ██║   ██║██║   ██║██║╚██╗██║    ██║   ██║██║██╔══██║██║   ██║██║╚██╗██║██║         ██║   ██║██║   ██║╚═╝
#  ╚██████╔╝╚██████╔╝██║ ╚████║    ╚██████╔╝██║██║  ██║╚██████╔╝██║ ╚████║╚██████╗    ██║   ██║╚██████╔╝██╗
#   ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝     ╚═════╝ ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝    ╚═╝   ╚═╝ ╚═════╝ ╚═╝
#
#   SCRIPT DE DIAGNOSTIC TECHNIQUE UNIFIÉ
#
#   Ce script consolide les fonctionnalités de diagnostic technique pour :
#   1. Analyser l'encodage des fichiers (avec/sans BOM, UTF-16, etc.).
#   2. Détecter des problèmes d'encodage spécifiques (double encodage, caractères erronés).
#   3. Valider la syntaxe des fichiers JSON.
#   4. Vérifier la présence des fichiers de configuration MCP critiques.
#   5. Proposer une correction automatique pour les problèmes les plus courants.
#
# =================================================================================================

param(
    [Parameter(Mandatory = $false, HelpMessage = "Chemin du répertoire ou du fichier à analyser.")]
    [string]$Path = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Inclut tous les sous-répertoires dans l'analyse.")]
    [switch]$Recursive,

    [Parameter(Mandatory = $false, HelpMessage = "Modèles de nom de fichier à inclure dans l'analyse.")]
    [string[]]$FilePatterns = @("*.json", "*.md"),

    [Parameter(Mandatory = $false, HelpMessage = "Active la vérification spécifique des fichiers de configuration MCP.")]
    [switch]$CheckMCP,

    [Parameter(Mandatory = $false, HelpMessage = "Tente de corriger automatiquement les problèmes d'encodage détectés.")]
    [switch]$Fix,

    [Parameter(Mandatory = $false, HelpMessage = "Affiche des informations détaillées pour chaque fichier analysé.")]
    [switch]$Detailed
)

# =================================================================================================
#   FONCTIONS DE DIAGNOSTIC
# =================================================================================================

function Write-ColorOutput {
    param([string]$Message, [ConsoleColor]$ForegroundColor = "White")
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Test-FileEncoding {
    param([string]$FilePath)
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { return "UTF-8-BOM" }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { return "UTF-16-BE" }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { return "UTF-16-LE" }
    
    # Heuristique simple pour UTF-8
    try {
        [System.Text.Encoding]::UTF8.GetString($bytes)
        return "UTF-8"
    } catch {
        return "Indéterminé (probablement non-UTF-8)"
    }
}

function Test-JsonSyntax {
    param([string]$FilePath)
    try {
        Get-Content -Path $FilePath -Raw | ConvertFrom-Json | Out-Null
        return [pscustomobject]@{ IsValid = $true; Error = $null }
    } catch {
        return [pscustomobject]@{ IsValid = $false; Error = $_.Exception.Message }
    }
}

function Find-EncodingAnomalies {
    param([string]$Content)
    $anomalies = [System.Collections.Generic.List[string]]::new()
    if ($Content -match "Ã©|Ã¨|Ã |Ã§|Ãª") { $anomalies.Add("Double encodage UTF-8 (ex: 'Ã©' au lieu de 'é')") }
    if ($Content -match "ï¿½") { $anomalies.Add("Caractère de remplacement 'ï¿½' (perte d'information)") }
    if ($Content -match "ð\S\S\S") { $anomalies.Add("Possible problème d'encodage d'emoji") }
    return $anomalies
}

# =================================================================================================
#   EXÉCUTION PRINCIPALE
# =================================================================================================

Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "       Diagnostic Technique Unifié des Fichiers" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

$filesToAnalyze = @()
$projectRoot = (Get-Item $Path).parent.parent.FullName

# --- Phase 1: Collecte des fichiers ---
if ($CheckMCP) {
    Write-ColorOutput "\nMode de vérification MCP activé." "Magenta"
    $mcpFiles = @("roo-config/settings/servers.json", "roo-config/modes/modes.json")
    foreach($mcpFile in $mcpFiles) {
        $fullPath = Join-Path -Path $projectRoot -ChildPath $mcpFile
        if(Test-Path $fullPath) {
            $filesToAnalyze += Get-Item $fullPath
        } else {
            Write-ColorOutput "FICHIER MANQUANT: Le fichier MCP '$fullPath' n'a pas été trouvé." "Red"
        }
    }
} else {
     if (Test-Path -Path $Path -PathType Container) {
        $getParams = @{ Path = $Path; File = $true; Include = $FilePatterns }
        if ($Recursive) { $getParams.Recurse = $true }
        $filesToAnalyze = Get-ChildItem @getParams
     } else {
        $filesToAnalyze = Get-Item $Path
     }
}

Write-ColorOutput "Analyse de $($filesToAnalyze.Count) fichier(s)...`n" "Yellow"

# --- Phase 2: Analyse de chaque fichier ---
$issuesFound = $false
foreach($file in $filesToAnalyze) {
    $fileReport = @{ Path = $file.FullName; Encoding = ""; JsonIsValid = $true; Anomalies = @() }
    $hasIssue = $false

    # 1. Diagnostic de l'encodage
    $fileReport.Encoding = Test-FileEncoding -FilePath $file.FullName
    if ($fileReport.Encoding -ne "UTF-8") {
        $hasIssue = $true
    }

    $fileContent = Get-Content -Path $file.FullName -Raw

    # 2. Diagnostic des anomalies de contenu
    $fileReport.Anomalies = Find-EncodingAnomalies -Content $fileContent
    if ($fileReport.Anomalies.Count -gt 0) {
        $hasIssue = $true
    }

    # 3. Diagnostic JSON (si applicable)
    if ($file.Extension -eq ".json") {
        $jsonResult = Test-JsonSyntax -FilePath $file.FullName
        $fileReport.JsonIsValid = $jsonResult.IsValid
        if (-not $jsonResult.IsValid) {
            $hasIssue = $true
            $fileReport.Anomalies.Add("JSON Invalide: $($jsonResult.Error)")
        }
    }

    # --- Affichage du rapport pour le fichier ---
    if ($hasIssue) {
        $issuesFound = $true
        Write-ColorOutput "----------------------------------------------------------" "Red"
        Write-ColorOutput "Problèmes détectés dans: $($file.Name)" "Red"
        Write-ColorOutput "  Chemin complet: $($file.FullName)"
        Write-ColorOutput "  Encodage détecté: $($fileReport.Encoding)" -ForegroundColor (if ($fileReport.Encoding -eq "UTF-8") {"Green"} else {"Yellow"})
        if (-not $fileReport.JsonIsValid) {Write-ColorOutput "  Syntaxe JSON: INVALIDE" "Red"}

        if ($fileReport.Anomalies.Count -gt 0) {
            Write-ColorOutput "  Anomalies de contenu:" "Yellow"
            $fileReport.Anomalies | ForEach-Object { Write-ColorOutput "    - $_" "Yellow" }
        }
        
        # --- Logique de correction ---
        if ($Fix -and ($fileReport.Encoding -ne "UTF-8" -or ($fileReport.Anomalies | Where-Object {$_ -like "*Double encodage*"}))) {
            Write-ColorOutput "  ACTION: Tentative de correction automatique..." "Magenta"
            try {
                $backupPath = "$($file.FullName).bak"
                Copy-Item -Path $file.FullName -Destination $backupPath -Force
                Write-ColorOutput "    - Sauvegarde créée: $backupPath" "Gray"

                $correctedContent = $fileContent -replace "Ã©", "é" -replace "Ã¨", "è" -replace "Ã§", "ç" -replace "Ã ", "à"
                # ... ajouter d'autres remplacements si nécessaire ...
                
                [System.IO.File]::WriteAllText($file.FullName, $correctedContent, ([System.Text.UTF8Encoding]::new($false)))
                 Write-ColorOutput "    - Fichier ré-encodé en UTF-8 (sans BOM) et anomalies corrigées." "Green"
            } catch {
                 Write-ColorOutput "    - ERREUR lors de la correction: $($_.Exception.Message)" "Red"
            }
        }

    } elseif ($Detailed) {
         Write-ColorOutput "----------------------------------------------------------" "Green"
         Write-ColorOutput "Aucun problème détecté dans: $($file.Name)" "Green"
         Write-ColorOutput "  Encodage: $($fileReport.Encoding)"
    }
}

# =================================================================================================
#   RÉSUMÉ FINAL
# =================================================================================================

Write-ColorOutput "`n==========================================================" "Cyan"
Write-ColorOutput "                 RÉSUMÉ DU DIAGNOSTIC" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

if (-not $issuesFound) {
    Write-ColorOutput "Aucun problème technique détecté dans les fichiers analysés." "Green"
} else {
    Write-ColorOutput "Des problèmes ont été détectés. Veuillez vérifier les logs ci-dessus." "Yellow"
    if (-not $Fix) {
        Write-ColorOutput "Astuce: Relancez ce script avec le paramètre -Fix pour tenter une correction automatique." "Magenta"
    }
}