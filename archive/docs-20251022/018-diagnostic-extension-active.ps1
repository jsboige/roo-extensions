# DIAGNOSTIC CRITIQUE - Identifier l'Extension Reellement Utilisee par VSCode
# ===========================================================================

Write-Host "`n========================================"
Write-Host "DIAGNOSTIC EXTENSION ROO-CLINE ACTIVE"
Write-Host "========================================`n"

$results = @{
    InstalledExtensions = @()
    DevMode = $null
    LogsAnalysis = @()
    ActiveExtension = $null
}

# ===========================================================================
# 1. LISTER TOUTES LES INSTANCES DE L'EXTENSION
# ===========================================================================
Write-Host "`n1. RECHERCHE DE TOUTES LES INSTANCES INSTALLEES" -ForegroundColor Yellow
Write-Host "---------------------------------------------------"

$extensionPaths = @(
    @{
        Name = "VSCode Standard"
        Path = "$env:USERPROFILE\.vscode\extensions"
    },
    @{
        Name = "VSCode Insiders"
        Path = "$env:USERPROFILE\.vscode-insiders\extensions"
    },
    @{
        Name = "VSCode OSS"
        Path = "$env:USERPROFILE\.vscode-oss\extensions"
    }
)

foreach ($location in $extensionPaths) {
    Write-Host "`nRecherche dans: $($location.Name)" -ForegroundColor Cyan
    Write-Host "   Chemin: $($location.Path)"
    
    if (Test-Path $location.Path) {
        $extensions = Get-ChildItem $location.Path -Filter "rooveterinaryinc.roo-cline-*" -Directory -ErrorAction SilentlyContinue
        
        if ($extensions) {
            foreach ($ext in $extensions) {
                Write-Host "   [OK] Trouve: $($ext.Name)" -ForegroundColor Green
                Write-Host "      Derniere modification: $($ext.LastWriteTime)"
                
                # Verifier package.json
                $packageJsonPath = Join-Path $ext.FullName "package.json"
                if (Test-Path $packageJsonPath) {
                    $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
                    Write-Host "      Version: $($packageJson.version)"
                }
                
                # Verifier le composant
                $indexHtmlPath = Join-Path $ext.FullName "dist\webview-ui\build\index.html"
                $indexHtmlExists = Test-Path $indexHtmlPath
                $indexStatus = if ($indexHtmlExists) { "[OK] Present" } else { "[ERREUR] ABSENT" }
                $indexColor = if ($indexHtmlExists) { "Green" } else { "Red" }
                Write-Host "      index.html: $indexStatus" -ForegroundColor $indexColor
                
                $results.InstalledExtensions += @{
                    Location = $location.Name
                    Path = $ext.FullName
                    Name = $ext.Name
                    LastModified = $ext.LastWriteTime
                    Version = if ($packageJson) { $packageJson.version } else { "Unknown" }
                    HasIndexHtml = $indexHtmlExists
                }
            }
        } else {
            Write-Host "   [INFO] Aucune extension trouvee"
        }
    } else {
        Write-Host "   [WARN] Repertoire non trouve"
    }
}

# ===========================================================================
# 2. VERIFIER LE MODE DEVELOPPEMENT
# ===========================================================================
Write-Host "`n`n2. VERIFICATION MODE DEVELOPPEMENT" -ForegroundColor Yellow
Write-Host "--------------------------------------"

$devExtensionPath = "C:\dev\roo-code\src"
$devPackageJsonPath = Join-Path $devExtensionPath "package.json"

if (Test-Path $devPackageJsonPath) {
    Write-Host "`n[ALERTE] EXTENSION EN MODE DEV DETECTEE!" -ForegroundColor Red
    
    $packageJson = Get-Content $devPackageJsonPath | ConvertFrom-Json
    Write-Host "   Chemin: $devExtensionPath"
    Write-Host "   Version: $($packageJson.version)"
    Write-Host "   Nom: $($packageJson.name)"
    
    # Verifier le composant
    $devIndexHtmlPath = "C:\dev\roo-code\webview-ui\build\index.html"
    $devIndexHtmlExists = Test-Path $devIndexHtmlPath
    $devIndexStatus = if ($devIndexHtmlExists) { "[OK] Present" } else { "[ERREUR] ABSENT" }
    $devIndexColor = if ($devIndexHtmlExists) { "Green" } else { "Red" }
    Write-Host "   index.html: $devIndexStatus" -ForegroundColor $devIndexColor
    
    $results.DevMode = @{
        Path = $devExtensionPath
        Version = $packageJson.version
        HasIndexHtml = $devIndexHtmlExists
    }
} else {
    Write-Host "`n[INFO] Pas d'extension en mode dev detectee"
}

# ===========================================================================
# 3. ANALYSER LES LOGS VSCODE
# ===========================================================================
Write-Host "`n`n3. ANALYSE DES LOGS VSCODE" -ForegroundColor Yellow
Write-Host "------------------------------"

$logLocations = @(
    @{
        Name = "VSCode Standard"
        Path = "$env:APPDATA\Code\logs"
    },
    @{
        Name = "VSCode Insiders"
        Path = "$env:APPDATA\Code - Insiders\logs"
    }
)

foreach ($logLocation in $logLocations) {
    Write-Host "`nLogs $($logLocation.Name)" -ForegroundColor Cyan
    
    if (Test-Path $logLocation.Path) {
        $latestLog = Get-ChildItem $logLocation.Path -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($latestLog) {
            Write-Host "   Dossier: $($latestLog.Name)"
            Write-Host "   Date: $($latestLog.LastWriteTime)"
            
            # Chercher dans les logs
            $logFiles = Get-ChildItem "$($latestLog.FullName)" -Recurse -Filter "*.log" -ErrorAction SilentlyContinue
            
            $foundPaths = @()
            foreach ($logFile in $logFiles) {
                try {
                    $content = Get-Content $logFile.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content -match "rooveterinaryinc\.roo-cline") {
                        # Extraire les chemins
                        $matches = [regex]::Matches($content, "(?:file:///)?([A-Za-z]:[/\\][^`"'\s]+rooveterinaryinc\.roo-cline[^`"'\s]*)")
                        foreach ($match in $matches) {
                            $path = $match.Groups[1].Value -replace "/", "\"
                            if ($foundPaths -notcontains $path) {
                                $foundPaths += $path
                            }
                        }
                    }
                } catch {
                    # Ignorer les erreurs de lecture
                }
            }
            
            if ($foundPaths) {
                Write-Host "   [OK] Chemins trouves dans les logs:" -ForegroundColor Green
                foreach ($path in $foundPaths) {
                    Write-Host "      > $path" -ForegroundColor Yellow
                    $results.LogsAnalysis += @{
                        Location = $logLocation.Name
                        Path = $path
                    }
                }
            } else {
                Write-Host "   [INFO] Aucune reference trouvee"
            }
        }
    } else {
        Write-Host "   [WARN] Repertoire non trouve"
    }
}

# ===========================================================================
# 4. DETERMINER L'EXTENSION ACTIVE
# ===========================================================================
Write-Host "`n`n4. DETERMINATION DE L'EXTENSION ACTIVE" -ForegroundColor Yellow
Write-Host "-------------------------------------------"

if ($results.LogsAnalysis.Count -gt 0) {
    $logPath = $results.LogsAnalysis[0].Path
    Write-Host "`n[OK] Extension identifiee via logs:" -ForegroundColor Green
    Write-Host "   Chemin: $logPath"
    
    # Verifier si c'est le mode dev
    if ($logPath -like "*C:\dev\roo-code*" -or $logPath -like "*c:/dev/roo-code*") {
        Write-Host "   TYPE: MODE DEVELOPPEMENT" -ForegroundColor Red
        $results.ActiveExtension = @{
            Type = "Development"
            Path = "C:\dev\roo-code\src"
            Source = "Logs"
        }
    } else {
        Write-Host "   TYPE: EXTENSION INSTALLEE" -ForegroundColor Cyan
        $results.ActiveExtension = @{
            Type = "Installed"
            Path = $logPath
            Source = "Logs"
        }
    }
} elseif ($results.DevMode) {
    Write-Host "`n[WARN] Aucun log trouve, mais mode dev detecte"
    Write-Host "   Extension probablement en mode developpement"
    $results.ActiveExtension = @{
        Type = "Development (probable)"
        Path = $results.DevMode.Path
        Source = "Detection"
    }
} elseif ($results.InstalledExtensions.Count -gt 0) {
    $mostRecent = $results.InstalledExtensions | Sort-Object LastModified -Descending | Select-Object -First 1
    Write-Host "`n[WARN] Aucun log ni mode dev trouve"
    Write-Host "   Extension la plus recente:"
    Write-Host "   Chemin: $($mostRecent.Path)"
    Write-Host "   Modifiee: $($mostRecent.LastModified)"
    $results.ActiveExtension = @{
        Type = "Most Recent"
        Path = $mostRecent.Path
        Source = "Heuristic"
    }
} else {
    Write-Host "`n[ERREUR] AUCUNE EXTENSION TROUVEE!" -ForegroundColor Red
}

# ===========================================================================
# 5. VERIFICATION DU COMPOSANT DANS L'EXTENSION ACTIVE
# ===========================================================================
if ($results.ActiveExtension) {
    Write-Host "`n`n5. VERIFICATION DU COMPOSANT DANS L'EXTENSION ACTIVE" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------"
    
    $activePath = $results.ActiveExtension.Path
    Write-Host "`nExtension active: $activePath" -ForegroundColor Cyan
    
    if ($results.ActiveExtension.Type -like "*Development*") {
        # Mode dev
        $indexHtmlPath = "C:\dev\roo-code\webview-ui\build\index.html"
        $distPath = "C:\dev\roo-code\dist"
    } else {
        # Extension installee
        $indexHtmlPath = Join-Path $activePath "dist\webview-ui\build\index.html"
        $distPath = Join-Path $activePath "dist"
    }
    
    Write-Host "`nVerification de index.html:" -ForegroundColor Cyan
    Write-Host "   Chemin: $indexHtmlPath"
    
    if (Test-Path $indexHtmlPath) {
        Write-Host "   [OK] PRESENT" -ForegroundColor Green
        $fileInfo = Get-Item $indexHtmlPath
        Write-Host "   Taille: $($fileInfo.Length) octets"
        Write-Host "   Modifie: $($fileInfo.LastWriteTime)"
        
        # Lire le contenu pour verifier
        $content = Get-Content $indexHtmlPath -Raw
        if ($content -match "root") {
            Write-Host "   [OK] Contenu valide detecte (div#root)" -ForegroundColor Green
        } else {
            Write-Host "   [WARN] Contenu suspect (pas de div#root)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   [ERREUR] ABSENT - C'EST LE PROBLEME!" -ForegroundColor Red
    }
    
    Write-Host "`nVerification du repertoire dist:" -ForegroundColor Cyan
    Write-Host "   Chemin: $distPath"
    
    if (Test-Path $distPath) {
        Write-Host "   [OK] PRESENT" -ForegroundColor Green
        
        # Lister le contenu
        Write-Host "   Contenu:"
        Get-ChildItem $distPath -Recurse -File | Select-Object -First 20 | ForEach-Object {
            $relativePath = $_.FullName.Replace($distPath, "").TrimStart("\")
            Write-Host "      > $relativePath"
        }
        $totalFiles = (Get-ChildItem $distPath -Recurse -File).Count
        if ($totalFiles -gt 20) {
            Write-Host "      ... et $($totalFiles - 20) autres fichiers"
        }
    } else {
        Write-Host "   [ERREUR] ABSENT" -ForegroundColor Red
    }
}

# ===========================================================================
# 6. RESUME FINAL
# ===========================================================================
Write-Host "`n`n======================================================="
Write-Host "RESUME DU DIAGNOSTIC"
Write-Host "=======================================================`n"

Write-Host "Extensions installees: $($results.InstalledExtensions.Count)"
foreach ($ext in $results.InstalledExtensions) {
    $indexStatus = if ($ext.HasIndexHtml) { "[OK]" } else { "[ERREUR]" }
    Write-Host "   * $($ext.Location): $($ext.Name)"
    Write-Host "     Version: $($ext.Version), index.html: $indexStatus"
}

if ($results.DevMode) {
    $devIndexStatus = if ($results.DevMode.HasIndexHtml) { "[OK]" } else { "[ERREUR]" }
    Write-Host "`nMode developpement: [OK] ACTIF" -ForegroundColor Red
    Write-Host "   Chemin: $($results.DevMode.Path)"
    Write-Host "   index.html: $devIndexStatus"
} else {
    Write-Host "`nMode developpement: [INFO] Non detecte"
}

if ($results.ActiveExtension) {
    Write-Host "`n[OK] EXTENSION ACTIVE IDENTIFIEE:" -ForegroundColor Green
    Write-Host "   Type: $($results.ActiveExtension.Type)" -ForegroundColor Yellow
    Write-Host "   Chemin: $($results.ActiveExtension.Path)" -ForegroundColor Yellow
    Write-Host "   Source: $($results.ActiveExtension.Source)" -ForegroundColor Yellow
} else {
    Write-Host "`n[ERREUR] IMPOSSIBLE DE DETERMINER L'EXTENSION ACTIVE" -ForegroundColor Red
}

Write-Host "`n=======================================================`n"

# Sauvegarder les resultats
$resultsJson = $results | ConvertTo-Json -Depth 10
$resultsPath = "docs\roo-code\pr-tracking\context-condensation\018-diagnostic-results.json"
$resultsJson | Out-File -FilePath $resultsPath -Encoding UTF8
Write-Host "Resultats sauvegardes dans: $resultsPath" -ForegroundColor Green