# Script d'analyse des chemins codés en dur
# Fichier : c:/myia-web1/Tools/roo-extensions/analyze-hardcoded-paths.ps1
# Version: 1.0
# Date: 2025-05-28
# Description: Analyse tous les chemins absolus codés en dur dans le système

param(
    [switch]$Verbose = $false,
    [switch]$ExportReport = $true
)

# Configuration
$AnalysisReport = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    CurrentWorkingDirectory = Get-Location
    TotalFilesScanned = 0
    FilesWithHardcodedPaths = 0
    HardcodedPathPatterns = @()
    DetailedFindings = @()
    Recommendations = @()
    Summary = @{}
}

# Patterns de chemins absolus à rechercher
$HardcodedPathPatterns = @(
    @{ Pattern = "d:/roo-extensions"; Description = "Ancien chemin principal" },
    @{ Pattern = "c:/dev/roo-extensions"; Description = "Ancien chemin de développement" },
    @{ Pattern = "c:/myia-web1/Tools/roo-extensions"; Description = "Chemin actuel (aussi problématique)" },
    @{ Pattern = "[A-Za-z]:\\[^\\s]*roo-extensions"; Description = "Tout chemin absolu contenant roo-extensions"; IsRegex = $true },
    @{ Pattern = "\\\\[^\\s]*roo-extensions"; Description = "Chemins UNC contenant roo-extensions"; IsRegex = $true },
    @{ Pattern = "\$RepoPath\s*=\s*`"[^`"]*`""; Description = "Variables de chemin codées en dur"; IsRegex = $true },
    @{ Pattern = "repository_path.*:.*`"[^`"]*`""; Description = "Chemins dans JSON"; IsRegex = $true }
)

function Write-AnalysisLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "CRITICAL" { "Magenta" }
            default { "White" }
        }
    )
}

function Analyze-FileContent {
    param(
        [string]$FilePath,
        [array]$Patterns
    )
    
    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $content) {
            return @()
        }
        
        $findings = @()
        $lineNumber = 0
        $lines = $content -split "`n"
        
        foreach ($line in $lines) {
            $lineNumber++
            
            foreach ($patternInfo in $Patterns) {
                $pattern = $patternInfo.Pattern
                $description = $patternInfo.Description
                $isRegex = $patternInfo.IsRegex -eq $true
                
                $matches = @()
                if ($isRegex) {
                    $matches = [regex]::Matches($line, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                } else {
                    if ($line -match [regex]::Escape($pattern)) {
                        $matches = @(@{ Value = $pattern; Index = $line.IndexOf($pattern) })
                    }
                }
                
                foreach ($match in $matches) {
                    $findings += @{
                        LineNumber = $lineNumber
                        LineContent = $line.Trim()
                        MatchedText = $match.Value
                        PatternDescription = $description
                        Context = Get-LineContext -Lines $lines -LineNumber $lineNumber -ContextSize 2
                    }
                }
            }
        }
        
        return $findings
    } catch {
        Write-AnalysisLog "Erreur lors de l'analyse de $FilePath : $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Get-LineContext {
    param(
        [array]$Lines,
        [int]$LineNumber,
        [int]$ContextSize = 2
    )
    
    $start = [Math]::Max(0, $LineNumber - $ContextSize - 1)
    $end = [Math]::Min($Lines.Count - 1, $LineNumber + $ContextSize - 1)
    
    $context = @()
    for ($i = $start; $i -le $end; $i++) {
        $marker = if ($i -eq ($LineNumber - 1)) { ">>> " } else { "    " }
        $context += "$marker$($i + 1): $($Lines[$i])"
    }
    
    return $context -join "`n"
}

function Get-FileType {
    param([string]$FilePath)
    
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    switch ($extension) {
        ".ps1" { return "PowerShell Script" }
        ".json" { return "JSON Configuration" }
        ".md" { return "Markdown Documentation" }
        ".txt" { return "Text File" }
        ".log" { return "Log File" }
        ".bat" { return "Batch Script" }
        ".cmd" { return "Command Script" }
        default { return "Other ($extension)" }
    }
}

function Analyze-PathUsagePatterns {
    param([array]$AllFindings)
    
    $patterns = @{}
    $fileTypes = @{}
    $pathTypes = @{}
    
    foreach ($finding in $AllFindings) {
        # Analyser les types de fichiers
        $fileType = Get-FileType $finding.FilePath
        if ($fileTypes.ContainsKey($fileType)) {
            $fileTypes[$fileType]++
        } else {
            $fileTypes[$fileType] = 1
        }
        
        # Analyser les types de chemins
        $pathType = $finding.PatternDescription
        if ($pathTypes.ContainsKey($pathType)) {
            $pathTypes[$pathType]++
        } else {
            $pathTypes[$pathType] = 1
        }
        
        # Analyser les patterns d'usage
        $usage = Determine-PathUsage $finding.LineContent
        if ($patterns.ContainsKey($usage)) {
            $patterns[$usage]++
        } else {
            $patterns[$usage] = 1
        }
    }
    
    return @{
        UsagePatterns = $patterns
        FileTypes = $fileTypes
        PathTypes = $pathTypes
    }
}

function Determine-PathUsage {
    param([string]$LineContent)
    
    if ($LineContent -match '\$\w+\s*=') { return "Variable Assignment" }
    if ($LineContent -match 'repository_path|repo_path') { return "Repository Configuration" }
    if ($LineContent -match 'Set-Location|cd\s+') { return "Directory Navigation" }
    if ($LineContent -match 'Test-Path|Join-Path') { return "Path Operations" }
    if ($LineContent -match 'Copy-Item|Move-Item') { return "File Operations" }
    if ($LineContent -match 'Get-ChildItem|Get-Content') { return "File Access" }
    if ($LineContent -match '"[^"]*":\s*"') { return "JSON Configuration" }
    if ($LineContent -match '#.*Fichier\s*:') { return "File Header Comment" }
    
    return "Other Usage"
}

function Generate-Recommendations {
    param([array]$AllFindings, [hashtable]$Analysis)
    
    $recommendations = @()
    
    # Recommandations générales
    $recommendations += @{
        Priority = "HIGH"
        Category = "Architecture"
        Title = "Remplacer les chemins absolus par des chemins relatifs"
        Description = "Utiliser `$PSScriptRoot pour détecter automatiquement le répertoire du script"
        Impact = "Rend le système portable entre différents environnements"
        Files = ($AllFindings | Where-Object { $_.LineContent -match '\$\w+\s*=' } | Select-Object -ExpandProperty FilePath -Unique)
    }
    
    $recommendations += @{
        Priority = "HIGH"
        Category = "Configuration"
        Title = "Refactoriser les fichiers de configuration JSON"
        Description = "Supprimer repository_path des configurations ou le rendre dynamique"
        Impact = "Élimine la dépendance aux chemins codés en dur"
        Files = ($AllFindings | Where-Object { $_.LineContent -match 'repository_path' } | Select-Object -ExpandProperty FilePath -Unique)
    }
    
    $recommendations += @{
        Priority = "MEDIUM"
        Category = "Documentation"
        Title = "Mettre à jour la documentation"
        Description = "Remplacer les exemples de chemins absolus par des chemins relatifs"
        Impact = "Évite la confusion pour les nouveaux utilisateurs"
        Files = ($AllFindings | Where-Object { (Get-FileType $_.FilePath) -eq "Markdown Documentation" } | Select-Object -ExpandProperty FilePath -Unique)
    }
    
    $recommendations += @{
        Priority = "LOW"
        Category = "Maintenance"
        Title = "Nettoyer les commentaires d'en-tête"
        Description = "Utiliser des chemins relatifs dans les commentaires de fichiers"
        Impact = "Cohérence et maintenance"
        Files = ($AllFindings | Where-Object { $_.LineContent -match '#.*Fichier\s*:' } | Select-Object -ExpandProperty FilePath -Unique)
    }
    
    return $recommendations
}

# Début de l'analyse
Write-AnalysisLog "=== DÉBUT DE L'ANALYSE DES CHEMINS CODÉS EN DUR ===" "INFO"
Write-AnalysisLog "Répertoire de travail actuel: $(Get-Location)" "INFO"

# Rechercher tous les fichiers à analyser
$filesToAnalyze = @()
$fileExtensions = @("*.ps1", "*.json", "*.md", "*.txt", "*.bat", "*.cmd")

foreach ($extension in $fileExtensions) {
    $files = Get-ChildItem -Path "." -Filter $extension -Recurse -File | Where-Object { 
        $_.FullName -notmatch "\\\.git\\" -and 
        $_.FullName -notmatch "\\node_modules\\" -and
        $_.Name -ne "analyze-hardcoded-paths.ps1" -and
        $_.Name -ne "migrate-paths.ps1"
    }
    $filesToAnalyze += $files
}

Write-AnalysisLog "Trouvé $($filesToAnalyze.Count) fichiers à analyser" "INFO"
$AnalysisReport.TotalFilesScanned = $filesToAnalyze.Count

# Analyser chaque fichier
$allFindings = @()
foreach ($file in $filesToAnalyze) {
    if ($Verbose) {
        Write-AnalysisLog "Analyse: $($file.FullName.Substring((Get-Location).Path.Length + 1))" "INFO"
    }
    
    $findings = Analyze-FileContent -FilePath $file.FullName -Patterns $HardcodedPathPatterns
    
    if ($findings.Count -gt 0) {
        $AnalysisReport.FilesWithHardcodedPaths++
        
        foreach ($finding in $findings) {
            $finding.FilePath = $file.FullName.Substring((Get-Location).Path.Length + 1)
            $finding.FileType = Get-FileType $file.FullName
            $allFindings += $finding
        }
        
        Write-AnalysisLog "Trouvé $($findings.Count) occurrences dans $($file.Name)" "WARNING"
    }
}

# Analyser les patterns d'usage
$usageAnalysis = Analyze-PathUsagePatterns -AllFindings $allFindings

# Générer les recommandations
$recommendations = Generate-Recommendations -AllFindings $allFindings -Analysis $usageAnalysis

# Compiler le rapport final
$AnalysisReport.DetailedFindings = $allFindings
$AnalysisReport.Recommendations = $recommendations
$AnalysisReport.Summary = @{
    TotalOccurrences = $allFindings.Count
    AffectedFiles = $AnalysisReport.FilesWithHardcodedPaths
    UsagePatterns = $usageAnalysis.UsagePatterns
    FileTypes = $usageAnalysis.FileTypes
    PathTypes = $usageAnalysis.PathTypes
    CriticalFiles = ($allFindings | Where-Object { $_.FileType -eq "PowerShell Script" -and $_.LineContent -match '\$\w+\s*=' } | Select-Object -ExpandProperty FilePath -Unique)
}

# Afficher le résumé
Write-AnalysisLog "=== RÉSUMÉ DE L'ANALYSE ===" "INFO"
Write-AnalysisLog "Fichiers analysés: $($AnalysisReport.TotalFilesScanned)" "INFO"
Write-AnalysisLog "Fichiers avec chemins codés en dur: $($AnalysisReport.FilesWithHardcodedPaths)" "WARNING"
Write-AnalysisLog "Total des occurrences: $($allFindings.Count)" "WARNING"

Write-AnalysisLog "`n=== TYPES DE FICHIERS AFFECTÉS ===" "INFO"
foreach ($fileType in $usageAnalysis.FileTypes.GetEnumerator()) {
    Write-AnalysisLog "  $($fileType.Key): $($fileType.Value) occurrences" "INFO"
}

Write-AnalysisLog "`n=== PATTERNS D'USAGE ===" "INFO"
foreach ($pattern in $usageAnalysis.UsagePatterns.GetEnumerator()) {
    Write-AnalysisLog "  $($pattern.Key): $($pattern.Value) occurrences" "INFO"
}

Write-AnalysisLog "`n=== RECOMMANDATIONS PRIORITAIRES ===" "CRITICAL"
foreach ($rec in ($recommendations | Where-Object { $_.Priority -eq "HIGH" })) {
    Write-AnalysisLog "  [$($rec.Priority)] $($rec.Title)" "CRITICAL"
    Write-AnalysisLog "    Impact: $($rec.Impact)" "INFO"
    Write-AnalysisLog "    Fichiers affectés: $($rec.Files.Count)" "INFO"
}

# Exporter le rapport
if ($ExportReport) {
    $reportFile = "hardcoded-paths-analysis-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $AnalysisReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
    Write-AnalysisLog "Rapport détaillé exporté: $reportFile" "SUCCESS"
    
    # Créer aussi un rapport lisible
    $readableReport = "hardcoded-paths-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    Generate-ReadableReport -Report $AnalysisReport -OutputPath $readableReport
    Write-AnalysisLog "Rapport lisible créé: $readableReport" "SUCCESS"
}

Write-AnalysisLog "=== FIN DE L'ANALYSE ===" "INFO"

function Generate-ReadableReport {
    param([hashtable]$Report, [string]$OutputPath)
    
    $markdown = @"
# Analyse des Chemins Codés en Dur - Rapport

**Date d'analyse:** $($Report.Timestamp)  
**Répertoire analysé:** $($Report.CurrentWorkingDirectory)

## Résumé Exécutif

- **Fichiers analysés:** $($Report.TotalFilesScanned)
- **Fichiers avec chemins codés en dur:** $($Report.FilesWithHardcodedPaths)
- **Total des occurrences:** $($Report.Summary.TotalOccurrences)

## Répartition par Type de Fichier

| Type de Fichier | Occurrences |
|-----------------|-------------|
"@

    foreach ($fileType in $Report.Summary.FileTypes.GetEnumerator()) {
        $markdown += "| $($fileType.Key) | $($fileType.Value) |`n"
    }

    $markdown += @"

## Patterns d'Usage Identifiés

| Pattern d'Usage | Occurrences |
|-----------------|-------------|
"@

    foreach ($pattern in $Report.Summary.UsagePatterns.GetEnumerator()) {
        $markdown += "| $($pattern.Key) | $($pattern.Value) |`n"
    }

    $markdown += @"

## Recommandations Prioritaires

"@

    foreach ($rec in $Report.Recommendations) {
        $markdown += @"
### [$($rec.Priority)] $($rec.Title)

**Catégorie:** $($rec.Category)  
**Description:** $($rec.Description)  
**Impact:** $($rec.Impact)  
**Fichiers affectés:** $($rec.Files.Count)

"@
    }

    $markdown += @"

## Fichiers Critiques Identifiés

Les fichiers suivants nécessitent une attention immédiate :

"@

    foreach ($file in $Report.Summary.CriticalFiles) {
        $markdown += "- `$file`n"
    }

    $markdown += @"

## Détails des Occurrences

"@

    $groupedFindings = $Report.DetailedFindings | Group-Object FilePath
    foreach ($group in $groupedFindings) {
        $markdown += @"

### $($group.Name)

"@
        foreach ($finding in $group.Group) {
            $markdown += @"
**Ligne $($finding.LineNumber):** $($finding.PatternDescription)  
```
$($finding.LineContent)
```

"@
        }
    }

    $markdown | Out-File -FilePath $OutputPath -Encoding UTF8
}