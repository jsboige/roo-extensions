# Script PowerShell autonome pour le diff granulaire
# Phase 3B - Implémentation du diff granulaire

param(
    [string]$Source,
    [string]$Target,
    [string]$SourceLabel = "source",
    [string]$TargetLabel = "target",
    [string]$OutputPath = "",
    [string]$Format = "json",
    [switch]$DryRun = $false,
    [switch]$Verbose = $false,
    [hashtable]$Options = @{}
)

Write-Host "DEBUG: Source='$Source' Target='$Target'"

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fonctions utilitaires
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-CommandExists {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Get-ScriptDirectory {
    return Split-Path -Parent $PSCommandPath
}

function Serialize-Json {
    param([object]$Data)
    try {
        return Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $Data -Depth 20 -Compress
    }
    catch {
        Write-Log "Erreur lors de la conversion JSON: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Test-JsonFile {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) {
            throw "Le fichier n'existe pas: $Path"
        }
        
        $content = Get-Content $Path -Raw -Encoding UTF8
        $null = $content | ConvertFrom-Json
        return $true
    }
    catch {
        Write-Log "Le fichier n'est pas un JSON valide: $Path - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Load-JsonData {
    param([string]$JsonInput, [string]$Description)
    
    Write-Log "Chargement des données $Description..." "INFO"
    
    # Vérifier si c'est un fichier ou du JSON direct
    if (Test-Path -Path $JsonInput -PathType Leaf) {
        Write-Log "Fichier détecté pour $Description : $JsonInput" "INFO"
        if (-not (Test-JsonFile $JsonInput)) {
            throw "Le fichier $Description n'est pas un JSON valide: $JsonInput"
        }
        Write-Log "$Description chargé depuis le fichier: $JsonInput" "SUCCESS"
        # On valide juste que c'est du JSON valide
        if (-not (Test-JsonFile $JsonInput)) {
             throw "Le fichier $Description n'est pas un JSON valide: $JsonInput"
        }
        # On retourne un objet spécial pour indiquer que c'est un fichier
        return @{ _isPath = $true; path = (Resolve-Path $JsonInput).Path }
    }
    else {
        Write-Log "Fichier non trouvé pour $Description : $JsonInput (Test-Path a retourné false)" "WARN"
        try {
            $data = $JsonInput | ConvertFrom-Json
            Write-Log "$Description chargé depuis la chaîne JSON" "SUCCESS"
            return $data
        }
        catch {
            Write-Log "La chaîne JSON pour $Description n'est pas valide: $($_.Exception.Message)" "ERROR"
            throw
        }
    }
}

function Save-Report {
    param(
        [object]$Report,
        [string]$OutputPath,
        [string]$Format
    )
    
    if ($DryRun) {
        Write-Log "Mode DRY RUN - Le rapport ne sera pas sauvegardé" "WARN"
        return
    }
    
    try {
        # Créer le répertoire si nécessaire
        $directory = Split-Path -Parent $OutputPath
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        # Préparer le contenu selon le format
        $content = switch ($Format.ToLower()) {
            "json" { Serialize-Json $Report }
            "csv" { ConvertTo-Csv $Report }
            "html" { ConvertTo-Html $Report }
            default {
                Write-Log "Format non supporté: $Format. Utilisation du JSON par défaut." "WARN"
                Serialize-Json $Report
            }
        }
        
        # Écrire le fichier
        Set-Content -Path $OutputPath -Value $content -Encoding UTF8
        Write-Log "Rapport sauvegardé: $OutputPath ($Format)" "SUCCESS"
    }
    catch {
        Write-Log "Erreur lors de la sauvegarde du rapport: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function ConvertTo-Csv {
    param([object]$Report)
    
    $csv = @()
    $csv += "ID,Path,Type,Severity,Category,Description,OldValue,NewValue,ChangePercent,ArrayIndex"
    
    foreach ($diff in $Report.diffs) {
        $oldValue = if ($diff.oldValue) { "`"$($diff.oldValue | Serialize-Json)`"" } else { "" }
        $newValue = if ($diff.newValue) { "`"$($diff.newValue | Serialize-Json)`"" } else { "" }
        $changePercent = if ($diff.metadata.changePercent) { $diff.metadata.changePercent } else { "" }
        $arrayIndex = if ($diff.metadata.arrayIndex) { $diff.metadata.arrayIndex } else { "" }
        
        $csv += "`"$($diff.id)`",`"$($diff.path)`",`"$($diff.type)`",`"$($diff.severity)`",`"$($diff.category)`",`"$($diff.description)`",$oldValue,$newValue,$changePercent,$arrayIndex"
    }
    
    return $csv -join "`n"
}

function ConvertTo-Html {
    param([object]$Report)
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Rapport de Diff Granulaire - $($Report.reportId)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .diff-item { margin: 10px 0; padding: 10px; border-left: 4px solid #ccc; }
        .diff-critical { border-left-color: #d32f2f; }
        .diff-important { border-left-color: #f57c00; }
        .diff-warning { border-left-color: #fbc02d; }
        .diff-info { border-left-color: #1976d2; }
        .diff-path { font-family: monospace; background: #f0f0f0; padding: 2px 5px; }
        .diff-values { margin-top: 5px; }
        .old-value { background: #ffebee; }
        .new-value { background: #e8f5e8; }
        .performance { margin-top: 20px; font-size: 0.9em; color: #666; }
    </style>
</head>
<body>
    <h1>Rapport de Diff Granulaire</h1>
    <div class="summary">
        <h2>Résumé</h2>
        <p><strong>Total:</strong> $($Report.summary.total)</p>
        <p><strong>Temps d'exécution:</strong> $($Report.performance.executionTime)ms</p>
        <p><strong>Nœuds comparés:</strong> $($Report.performance.nodesCompared)</p>
        
        <h3>Par Type</h3>
        <ul>
            <li>Ajouté: $($Report.summary.byType.added)</li>
            <li>Supprimé: $($Report.summary.byType.removed)</li>
            <li>Modifié: $($Report.summary.byType.modified)</li>
            <li>Déplacé: $($Report.summary.byType.moved)</li>
            <li>Copié: $($Report.summary.byType.copied)</li>
        </ul>
        
        <h3>Par Sévérité</h3>
        <ul>
            <li>Critique: $($Report.summary.bySeverity.CRITICAL)</li>
            <li>Important: $($Report.summary.bySeverity.IMPORTANT)</li>
            <li>Avertissement: $($Report.summary.bySeverity.WARNING)</li>
            <li>Info: $($Report.summary.bySeverity.INFO)</li>
        </ul>
    </div>
    
    <h2>Différences</h2>
"@
    
    foreach ($diff in $Report.diffs) {
        $severityClass = "diff-$($diff.severity.ToLower())"
        $oldValue = if ($diff.oldValue) { "<div class='old-value'>Ancien: $($diff.oldValue | Serialize-Json)</div>" } else { "" }
        $newValue = if ($diff.newValue) { "<div class='new-value'>Nouveau: $($diff.newValue | Serialize-Json)</div>" } else { "" }
        
        $html += @"
    <div class="diff-item $severityClass">
        <div class="diff-path">$($diff.path)</div>
        <div><strong>Type:</strong> $($diff.type) | <strong>Sévérité:</strong> $($diff.severity)</div>
        <div><strong>Description:</strong> $($diff.description)</div>
        <div class="diff-values">
            $oldValue
            $newValue
        </div>
    </div>
"@
    }
    
    $html += @"
    <div class="performance">
        <p>Généré le $($Report.timestamp)</p>
        <p>Source: $($Report.sourceLabel) | Cible: $($Report.targetLabel)</p>
    </div>
</body>
</html>
"@
    
    return $html
}

# Fonction principale
function Main {
    try {
        Write-Log "Début du diff granulaire - Phase 3B" "SUCCESS"
        Write-Log "Source: $SourceLabel, Cible: $TargetLabel" "INFO"
        
        # Validation des prérequis
        Write-Log "Vérification des prérequis..." "INFO"
        
        if (-not (Test-CommandExists "node")) {
            throw "Prérequis manquant: Node.js n'est pas installé"
        }
        
        # Charger les données source et cible
        Write-Log "Chargement des données source et cible..." "INFO"
        $sourceData = Load-JsonData $Source "source"
        $targetData = Load-JsonData $Target "cible"
        
        # Préparer les options
        $diffOptions = @{
            includeUnchanged = $Options.includeUnchanged -eq $true
            ignoreWhitespace = $Options.ignoreWhitespace -ne $false
            ignoreCase = $Options.ignoreCase -eq $true
            arrayDiffMode = if ($Options.arrayDiffMode) { $Options.arrayDiffMode } else { "identity" }
            semanticAnalysis = $Options.semanticAnalysis -eq $true
            maxDepth = if ($Options.maxDepth) { [int]$Options.maxDepth } else { 50 }
        }
        
        if ($Verbose) {
            Write-Log "Options de diff: $(Serialize-Json $diffOptions)" "INFO"
        }
        # Créer le script Node.js pour le diff granulaire
        $scriptDir = Get-ScriptDirectory
        $nodeScript = Join-Path $scriptDir "granular-diff-runner.js"

        # Logique pour injecter les données dans JS
        $sourceInjection = if ($SourceData._isPath) {
            "const sourceData = JSON.parse(fs.readFileSync('$($SourceData.path.Replace('\', '\\'))', 'utf8'));"
        } else {
            "const sourceData = $($SourceData | Serialize-Json);"
        }

        $targetInjection = if ($TargetData._isPath) {
            "const targetData = JSON.parse(fs.readFileSync('$($TargetData.path.Replace('\', '\\'))', 'utf8'));"
        } else {
            "const targetData = $($TargetData | Serialize-Json);"
        }
        
        $scriptContent = @"
const { GranularDiffDetector } = require('../../mcps/internal/servers/roo-state-manager/build/services/GranularDiffDetector.js');
const fs = require('fs');

async function runGranularDiff() {
    try {
        // Charger les données
        $sourceInjection
        $targetInjection
        
        const options = $($diffOptions | Serialize-Json);
        // Créer le détecteur
        const detector = new GranularDiffDetector();
        
        // Effectuer la comparaison
        const report = await detector.compareGranular(
            sourceData,
            targetData,
            '$SourceLabel',
            '$TargetLabel',
            options
        );
        
        // Exporter le résultat
        console.log(JSON.stringify(report, null, 2));
        
    } catch (error) {
        console.error('Erreur:', error.message);
        process.exit(1);
    }
}

runGranularDiff();
"@
        
        # Écrire le script temporaire
        Set-Content -Path $nodeScript -Value $scriptContent -Encoding UTF8
        
        # Exécuter le script Node.js
        Write-Log "Exécution du diff granulaire..." "INFO"
        
        # Capture stdout uniquement pour le JSON, stderr ira dans le terminal (ou null)
        $nodeResult = node $nodeScript
        
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur lors de l'exécution du diff granulaire (ExitCode: $LASTEXITCODE)"
        }
        
        # Parser le résultat
        try {
            $report = $nodeResult | ConvertFrom-Json
            Write-Log "Diff granulaire terminé avec succès" "SUCCESS"
            Write-Log "Total différences: $($report.summary.total)" "INFO"
            Write-Log "Temps d'exécution: $($report.performance.executionTime)ms" "INFO"
            Write-Log "Nœuds comparés: $($report.performance.nodesCompared)" "INFO"
            
            # Sauvegarder le rapport si demandé
            if ($OutputPath) {
                Save-Report -Report $report -OutputPath $OutputPath -Format $Format
            }
            
            # Afficher le résumé
            Write-Host "`n=== RÉSUMÉ DU DIFF GRANULAIRE ===" -ForegroundColor Cyan
            Write-Host "Source: $SourceLabel" -ForegroundColor White
            Write-Host "Cible: $TargetLabel" -ForegroundColor White
            Write-Host "Total différences: $($report.summary.total)" -ForegroundColor White
            Write-Host "Temps d'exécution: $($report.performance.executionTime)ms" -ForegroundColor White
            Write-Host "Nœuds comparés: $($report.performance.nodesCompared)" -ForegroundColor White
            
            # Détails par sévérité
            Write-Host "`nDétails par sévérité:" -ForegroundColor Yellow
            Write-Host "  Critique: $($report.summary.bySeverity.CRITICAL)" -ForegroundColor Red
            Write-Host "  Important: $($report.summary.bySeverity.IMPORTANT)" -ForegroundColor Yellow
            Write-Host "  Avertissement: $($report.summary.bySeverity.WARNING)" -ForegroundColor Yellow
            Write-Host "  Info: $($report.summary.bySeverity.INFO)" -ForegroundColor Green
            
            if ($Verbose -and $report.diffs.Count -gt 0) {
                Write-Host "`nPremières différences (mode verbose):" -ForegroundColor Magenta
                for ($i = 0; $i -lt [Math]::Min(5, $report.diffs.Count); $i++) {
                    $diff = $report.diffs[$i]
                    Write-Host "  [$($diff.path)] $($diff.type) - $($diff.description)" -ForegroundColor White
                }
                
                if ($report.diffs.Count -gt 5) {
                    Write-Host "  ... et $($($report.diffs.Count - 5)) autres différences" -ForegroundColor Gray
                }
            }
            
            # Nettoyer le script temporaire
            Remove-Item $nodeScript -Force -ErrorAction SilentlyContinue
            
            Write-Log "Diff granulaire terminé avec succès" "SUCCESS"
        }
        catch {
            Write-Log "Erreur lors du parsing du résultat: $($_.Exception.Message)" "ERROR"
            Write-Log "Contenu reçu: $nodeResult" "DEBUG"
            throw
        }
    }
    catch {
        Write-Log "Erreur lors du diff granulaire: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
        exit 1
    }
}

# Point d'entrée principal
Main