# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "=== ANALYSE COMPLÈTE DE LA STRUCTURE ROO-STATE-MANAGER ===" -ForegroundColor Cyan

cd mcps/internal/servers/roo-state-manager

Write-Host "`n=== 1. Structure des dossiers principaux ===" -ForegroundColor Yellow
Get-ChildItem -Path . | Where-Object { $_.PSIsContainer } | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "Dossier: $($_.Name) ($([math]::Round($size, 2)) MB)"
}

Write-Host "`n=== 2. Fichiers de configuration ===" -ForegroundColor Yellow
$configFiles = @("package.json", "tsconfig.json", ".env", ".env.example", "README.md", "*.md")
foreach ($pattern in $configFiles) {
    $files = Get-ChildItem -Path . -Filter $pattern -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        Write-Host "Fichier: $($file.Name) ($(Get-Item $file.FullName).Length bytes)"
    }
}

Write-Host "`n=== 3. Fichiers source TypeScript ===" -ForegroundColor Yellow
$tsFiles = Get-ChildItem -Path "src" -Filter "*.ts" -Recurse -ErrorAction SilentlyContinue
if ($tsFiles) {
    foreach ($file in $tsFiles) {
        $lines = (Get-Content $file.FullName | Measure-Object -Line).Lines
        Write-Host "Source: $($file.Name) ($lines lignes)"
    }
} else {
    Write-Host "Aucun fichier TypeScript trouvé dans src/"
}

Write-Host "`n=== 4. Recherche de patterns liés à la messagerie ===" -ForegroundColor Yellow
$messagingKeywords = @("messaging", "message", "agent", "communication", "inter-agent", "websocket", "ws", "socket")
$foundPatterns = @()

foreach ($keyword in $messagingKeywords) {
    # Chercher dans les fichiers source
    $tsFiles = Get-ChildItem -Path "src" -Filter "*.ts" -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $tsFiles) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match [regex]::Escape($keyword)) {
                $foundPatterns += "Fichier $($file.Name) contient: $keyword"
            }
        } catch {
            # Ignorer les erreurs de lecture
        }
    }
    
    # Chercher dans les fichiers de config
    $configFiles = Get-ChildItem -Path . -Filter "*.json" -ErrorAction SilentlyContinue
    foreach ($file in $configFiles) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match [regex]::Escape($keyword)) {
                $foundPatterns += "Config $($file.Name) contient: $keyword"
            }
        } catch {
            # Ignorer les erreurs de lecture
        }
    }
}

if ($foundPatterns.Count -gt 0) {
    Write-Host "Patterns de messagerie trouves:"
    $foundPatterns | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "Aucun pattern de messagerie trouve"
}

Write-Host "`n=== 5. Variables d'environnement utilisees ===" -ForegroundColor Yellow
$envVars = @()
$tsFiles = Get-ChildItem -Path "src" -Filter "*.ts" -Recurse -ErrorAction SilentlyContinue
foreach ($file in $tsFiles) {
    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        $matches = [regex]::Matches($content, 'process\.env\.(\w+)')
        foreach ($match in $matches) {
            $envVars += $match.Groups[1].Value
        }
    } catch {
        # Ignorer les erreurs de lecture
    }
}

if ($envVars.Count -gt 0) {
    $envVars = $envVars | Sort-Object -Unique
    Write-Host "Variables d'environnement:"
    $envVars | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "Aucune variable d'environnement trouvee"
}

Write-Host "`n=== 6. Analyse du package.json ===" -ForegroundColor Yellow
if (Test-Path "package.json") {
    try {
        $pkg = Get-Content "package.json" | ConvertFrom-Json
        Write-Host "Nom: $($pkg.name)"
        Write-Host "Version: $($pkg.version)"
        Write-Host "Description: $($pkg.description)"
        
        if ($pkg.dependencies) {
            Write-Host "`nDependencies principales:"
            $pkg.dependencies.PSObject.Properties | Where-Object { $_.Name -match "ws|mcp|agent|message" } | ForEach-Object {
                Write-Host "  - $($_.Name): $($_.Value)"
            }
        }
        
        if ($pkg.scripts) {
            Write-Host "`nScripts disponibles:"
            $pkg.scripts.PSObject.Properties | ForEach-Object {
                Write-Host "  - $($_.Name): $($_.Value)"
            }
        }
    } catch {
        Write-Host "Erreur de lecture du package.json"
    }
}

Write-Host "`n=== 7. État du dossier node_modules ===" -ForegroundColor Yellow
if (Test-Path "node_modules") {
    try {
        $moduleCount = (Get-ChildItem "node_modules" -Directory | Measure-Object).Count
        $size = (Get-ChildItem "node_modules" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "node_modules present: $moduleCount modules ($([math]::Round($size, 2)) MB)"
        
        # Vérifier s'il y a une récursion anormale
        $deepPaths = Get-ChildItem "node_modules" -Recurse -ErrorAction SilentlyContinue | Where-Object { 
            $_.FullName -match "node_modules.*node_modules.*node_modules" 
        } | Select-Object -First 5
        
        if ($deepPaths) {
            Write-Host "ATTENTION: Profondeur de node_modules anormale detectee"
            $deepPaths | ForEach-Object { Write-Host "  - $($_.FullName)" }
        }
    } catch {
        Write-Host "Erreur d'analyse de node_modules"
    }
} else {
    Write-Host "node_modules absent"
}

Write-Host "`n=== 8. État du dossier dist ===" -ForegroundColor Yellow
if (Test-Path "dist") {
    try {
        $distFiles = Get-ChildItem "dist" -Recurse -File
        Write-Host "dist present: $($distFiles.Count) fichiers"
        $distFiles | ForEach-Object { 
            $size = [math]::Round($_.Length / 1KB, 2)
            Write-Host "  - $($_.Name) ($size KB)" 
        }
    } catch {
        Write-Host "Erreur d'analyse de dist"
    }
} else {
    Write-Host "dist absent (non compile)"
}

Write-Host "`n=== Analyse terminee ===" -ForegroundColor Green