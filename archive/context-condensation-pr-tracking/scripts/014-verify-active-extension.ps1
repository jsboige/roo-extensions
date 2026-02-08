# Script de diagnostic: Verification Extension Active vs Extension Deployee
# Objectif: Identifier quelle version de roo-cline est REELLEMENT active dans VSCode

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTIC: Extension Active vs Deployee" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. TOUTES les installations de l'extension
Write-Host "[1/5] Recherche de TOUTES les installations de roo-cline..." -ForegroundColor Yellow

$extensionPaths = @(
    "$env:USERPROFILE\.vscode\extensions",
    "$env:USERPROFILE\.vscode-insiders\extensions",
    "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\resources\app\extensions",
    "$env:USERPROFILE\AppData\Roaming\Code\User\extensions"
)

$allExtensions = @()
foreach ($path in $extensionPaths) {
    if (Test-Path $path) {
        $found = Get-ChildItem -Path $path -Directory -Filter "rooveterinaryinc.roo-cline-*" -ErrorAction SilentlyContinue
        if ($found) {
            $allExtensions += $found | ForEach-Object {
                [PSCustomObject]@{
                    Path = $_.FullName
                    Name = $_.Name
                    Version = ($_.Name -replace 'rooveterinaryinc\.roo-cline-', '')
                    LastModified = $_.LastWriteTime
                    HasWebviewBuild = Test-Path (Join-Path $_.FullName "webview-ui\build")
                    HasAssets = Test-Path (Join-Path $_.FullName "webview-ui\build\assets")
                }
            }
        }
    }
}

if ($allExtensions.Count -eq 0) {
    Write-Host "ERROR: AUCUNE extension roo-cline trouvee!" -ForegroundColor Red
    exit 1
}

Write-Host "`nOK: $($allExtensions.Count) installation(s) trouvee(s):`n" -ForegroundColor Green
$allExtensions | Sort-Object LastModified -Descending | ForEach-Object {
    Write-Host "  Version: $($_.Version)" -ForegroundColor White
    Write-Host "     Path: $($_.Path)" -ForegroundColor Gray
    Write-Host "     Modifie le: $($_.LastModified)" -ForegroundColor Gray
    Write-Host "     Build webview: $($_.HasWebviewBuild)" -ForegroundColor $(if ($_.HasWebviewBuild) { "Green" } else { "Red" })
    Write-Host "     Assets: $($_.HasAssets)" -ForegroundColor $(if ($_.HasAssets) { "Green" } else { "Red" })
    
    if ($_.HasAssets) {
        $assetsPath = Join-Path $_.Path "webview-ui\build\assets"
        $jsFiles = Get-ChildItem -Path $assetsPath -Filter "*.js" -ErrorAction SilentlyContinue
        $cssFiles = Get-ChildItem -Path $assetsPath -Filter "*.css" -ErrorAction SilentlyContinue
        Write-Host "     Fichiers: $($jsFiles.Count) JS, $($cssFiles.Count) CSS" -ForegroundColor Gray
        
        # Verifie la presence du composant CondensationProviderSettings
        $indexJs = Get-ChildItem -Path $assetsPath -Filter "index-*.js" | Select-Object -First 1
        if ($indexJs) {
            $content = Get-Content $indexJs.FullName -Raw
            $hasCondensation = $content -match "CondensationProviderSettings|condensationProvider"
            Write-Host "     Condensation detectee: $hasCondensation" -ForegroundColor $(if ($hasCondensation) { "Green" } else { "Yellow" })
        }
    }
    Write-Host ""
}

# 2. Version la plus recente (supposee deployee)
Write-Host "`n[2/5] Identification de la version la plus recente..." -ForegroundColor Yellow
$mostRecent = $allExtensions | Sort-Object LastModified -Descending | Select-Object -First 1
Write-Host "OK: Version la plus recente: $($mostRecent.Version)" -ForegroundColor Green
Write-Host "   Modifiee le: $($mostRecent.LastModified)" -ForegroundColor Gray
Write-Host "   Path: $($mostRecent.Path)`n" -ForegroundColor Gray

# 3. Extension actuellement active (via processus VSCode)
Write-Host "[3/5] Identification de l'extension ACTIVE..." -ForegroundColor Yellow

# Verifier les processus VSCode en cours
$vscodeProcesses = Get-Process -Name "Code" -ErrorAction SilentlyContinue
if ($vscodeProcesses) {
    $processCount = $vscodeProcesses.Count
    Write-Host "OK: VSCode est en cours d'execution - $processCount processus" -ForegroundColor Green
    
    # Lire les logs VSCode pour identifier l'extension active
    $logPaths = @(
        "$env:APPDATA\Code\logs",
        "$env:USERPROFILE\.vscode\extensions"
    )
    
    Write-Host "   Recherche dans les logs VSCode..." -ForegroundColor Gray
    
    # Chercher le fichier de log le plus recent
    $recentLog = $null
    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            $logs = Get-ChildItem -Path $logPath -Recurse -Filter "*.log" -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) } |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 5
            
            foreach ($log in $logs) {
                $content = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -and $content -match "rooveterinaryinc\.roo-cline") {
                    $recentLog = $log
                    break
                }
            }
        }
    }
    
    if ($recentLog) {
        Write-Host "   OK: Log trouve: $($recentLog.Name)" -ForegroundColor Green
        $content = Get-Content $recentLog.FullName -Raw
        
        # Extraire la version active
        if ($content -match "rooveterinaryinc\.roo-cline-(\d+\.\d+\.\d+)") {
            $activeVersion = $matches[1]
            Write-Host "   ACTIVE: Version detectee: $activeVersion" -ForegroundColor Cyan
            
            # Comparer avec la plus recente
            if ($activeVersion -eq $mostRecent.Version) {
                Write-Host "   OK MATCH: Version active = Version deployee!" -ForegroundColor Green
            } else {
                Write-Host "   WARNING MISMATCH: Version active ($activeVersion) != Version deployee ($($mostRecent.Version))" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "WARNING: VSCode n'est pas en cours d'execution" -ForegroundColor Yellow
}

# 4. Verifier le fichier extensions.json
Write-Host "`n[4/5] Verification du fichier extensions.json..." -ForegroundColor Yellow
$extensionsJson = "$env:USERPROFILE\.vscode\extensions\extensions.json"
if (Test-Path $extensionsJson) {
    Write-Host "OK: Fichier trouve" -ForegroundColor Green
    $jsonContent = Get-Content $extensionsJson -Raw | ConvertFrom-Json
    $rooExtensions = $jsonContent | Where-Object { $_.identifier.id -eq "rooveterinaryinc.roo-cline" }
    
    if ($rooExtensions) {
        Write-Host "   Version enregistree: $($rooExtensions.version)" -ForegroundColor Cyan
        Write-Host "   Location: $($rooExtensions.location.path)" -ForegroundColor Gray
    }
} else {
    Write-Host "WARNING: Fichier extensions.json non trouve" -ForegroundColor Yellow
}

# 5. Inspection detaillee des assets dans chaque version
Write-Host "`n[5/5] Inspection detaillee des assets..." -ForegroundColor Yellow

foreach ($ext in $allExtensions) {
    Write-Host "`n  Version $($ext.Version):" -ForegroundColor White
    
    $assetsPath = Join-Path $ext.Path "webview-ui\build\assets"
    if (Test-Path $assetsPath) {
        $allFiles = Get-ChildItem -Path $assetsPath -File
        Write-Host "     Total fichiers: $($allFiles.Count)" -ForegroundColor Gray
        
        # Liste les fichiers
        $allFiles | ForEach-Object {
            $sizeKB = [math]::Round($_.Length / 1KB, 0)
            $fileName = $_.Name
            $modTime = $_.LastWriteTime
            Write-Host "       - $fileName - $sizeKB KB - modifie: $modTime" -ForegroundColor DarkGray
        }
        
        # Verifie le contenu du index-*.js
        $indexJs = $allFiles | Where-Object { $_.Name -match "index-.*\.js" } | Select-Object -First 1
        if ($indexJs) {
            Write-Host "`n     Analyse du fichier principal: $($indexJs.Name)" -ForegroundColor Gray
            $content = Get-Content $indexJs.FullName -Raw
            
            $hasCondensation = $content -match "CondensationProviderSettings"
            $hasCondensationConfig = $content -match "condensationProvider"
            $hasOpenAI = $content -match "openai.*provider"
            $hasAnthropic = $content -match "anthropic.*provider"
            
            $status1 = if ($hasCondensation) { "OK" } else { "MISSING" }
            $status2 = if ($hasCondensationConfig) { "OK" } else { "MISSING" }
            $status3 = if ($hasOpenAI) { "OK" } else { "MISSING" }
            $status4 = if ($hasAnthropic) { "OK" } else { "MISSING" }
            
            Write-Host "       $status1 - CondensationProviderSettings" -ForegroundColor $(if ($hasCondensation) { "Green" } else { "Red" })
            Write-Host "       $status2 - condensationProvider config" -ForegroundColor $(if ($hasCondensationConfig) { "Green" } else { "Red" })
            Write-Host "       $status3 - OpenAI provider" -ForegroundColor $(if ($hasOpenAI) { "Green" } else { "Red" })
            Write-Host "       $status4 - Anthropic provider" -ForegroundColor $(if ($hasAnthropic) { "Green" } else { "Red" })
        }
    } else {
        Write-Host "     ERROR: Pas de dossier assets" -ForegroundColor Red
    }
}

# RESUME FINAL
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RESUME" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Statistiques:" -ForegroundColor White
Write-Host "   - Installations totales: $($allExtensions.Count)" -ForegroundColor Gray
Write-Host "   - Version la plus recente: $($mostRecent.Version)" -ForegroundColor Gray
Write-Host "   - Derniere modification: $($mostRecent.LastModified)" -ForegroundColor Gray

if ($mostRecent.HasAssets) {
    Write-Host "`nOK: La version la plus recente a des assets buildes" -ForegroundColor Green
} else {
    Write-Host "`nERROR: La version la plus recente n'a PAS d'assets buildes" -ForegroundColor Red
}

Write-Host "`nProchaines etapes recommandees:" -ForegroundColor Yellow
Write-Host "   1. Si MISMATCH detecte: Redemarrer VSCode completement" -ForegroundColor Gray
Write-Host "   2. Si pas d'assets: Rebuild avec npm run compile" -ForegroundColor Gray
Write-Host "   3. Si plusieurs versions: Supprimer les anciennes" -ForegroundColor Gray
Write-Host "   4. Verifier les logs VSCode pour les erreurs de chargement" -ForegroundColor Gray

Write-Host "`n========================================`n" -ForegroundColor Cyan