# Script pour corriger la configuration MCP dans Roo Code
# Corrige les variables %ROO_ROOT% non résolues et active win-cli

param(
    [Parameter(Mandatory=$false)]
    [string]$RooMcpSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json",

    [Parameter(Mandatory=$false)]
    [string]$RooRoot = "C:/dev/roo-extensions",

    [Parameter(Mandatory=$false)]
    [switch]$EnableWinCli = $true,

    [Parameter(Mandatory=$false)]
    [switch]$Backup = $true
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Correction des MCP settings Roo Code" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fichier cible: $RooMcpSettingsPath" -ForegroundColor Yellow
Write-Host "ROO_ROOT: $RooRoot" -ForegroundColor Yellow
Write-Host ""

# Vérifier que le fichier existe
if (-not (Test-Path $RooMcpSettingsPath)) {
    Write-Host "ERREUR: Le fichier $RooMcpSettingsPath n'existe pas." -ForegroundColor Red
    exit 1
}

# Backup si demandé
if ($Backup) {
    $backupPath = "$RooMcpSettingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $RooMcpSettingsPath $backupPath -Force
    Write-Host "✓ Backup créé: $backupPath" -ForegroundColor Green
    Write-Host ""
}

# Lire le fichier JSON
try {
    $jsonContent = Get-Content $RooMcpSettingsPath -Raw -Encoding UTF8
    $mcpSettings = ConvertFrom-Json $jsonContent
} catch {
    Write-Host "ERREUR: Impossible de lire le fichier JSON: $_" -ForegroundColor Red
    exit 1
}

$changes = @()

# Fix 1: roo-state-manager - Remplacer %ROO_ROOT% par le chemin absolu
if ($mcpSettings.mcpServers.'roo-state-manager') {
    $rsmConfig = $mcpSettings.mcpServers.'roo-state-manager'

    # Corriger args
    if ($rsmConfig.args -and $rsmConfig.args[0] -like '*%ROO_ROOT%*') {
        $oldArgs = $rsmConfig.args[0]
        $rsmConfig.args[0] = $rsmConfig.args[0] -replace '%ROO_ROOT%', $RooRoot
        Write-Host "[roo-state-manager] args corrigé:" -ForegroundColor Yellow
        Write-Host "  Ancien: $oldArgs" -ForegroundColor Red
        Write-Host "  Nouveau: $($rsmConfig.args[0])" -ForegroundColor Green
        $changes += "roo-state-manager args"
    }

    # Corriger watchPaths
    if ($rsmConfig.watchPaths -and $rsmConfig.watchPaths[0] -like '*%ROO_ROOT%*') {
        $oldWatch = $rsmConfig.watchPaths[0]
        $rsmConfig.watchPaths[0] = $rsmConfig.watchPaths[0] -replace '%ROO_ROOT%', $RooRoot
        Write-Host "[roo-state-manager] watchPaths corrigé:" -ForegroundColor Yellow
        Write-Host "  Ancien: $oldWatch" -ForegroundColor Red
        Write-Host "  Nouveau: $($rsmConfig.watchPaths[0])" -ForegroundColor Green
        $changes += "roo-state-manager watchPaths"
    }

    # Corriger options.cwd
    if ($rsmConfig.options -and $rsmConfig.options.cwd -like '*%ROO_ROOT%*') {
        $oldCwd = $rsmConfig.options.cwd
        $rsmConfig.options.cwd = $rsmConfig.options.cwd -replace '%ROO_ROOT%', $RooRoot
        Write-Host "[roo-state-manager] options.cwd corrigé:" -ForegroundColor Yellow
        Write-Host "  Ancien: $oldCwd" -ForegroundColor Red
        Write-Host "  Nouveau: $($rsmConfig.options.cwd)" -ForegroundColor Green
        $changes += "roo-state-manager options.cwd"
    }
}

# Fix 2: win-cli - Activer si demandé
if ($EnableWinCli -and $mcpSettings.mcpServers.'win-cli') {
    $winCliConfig = $mcpSettings.mcpServers.'win-cli'

    if ($winCliConfig.disabled -eq $true) {
        $winCliConfig.disabled = $false
        Write-Host "[win-cli] Activé (disabled: true → false)" -ForegroundColor Green
        $changes += "win-cli enabled"
    }

    # Corriger cwd si contient %ROO_ROOT%
    if ($winCliConfig.cwd -and $winCliConfig.cwd -like '*%ROO_ROOT%*') {
        $oldCwd = $winCliConfig.cwd
        $winCliConfig.cwd = $winCliConfig.cwd -replace '%ROO_ROOT%', $RooRoot
        Write-Host "[win-cli] cwd corrigé:" -ForegroundColor Yellow
        Write-Host "  Ancien: $oldCwd" -ForegroundColor Red
        Write-Host "  Nouveau: $($winCliConfig.cwd)" -ForegroundColor Green
        $changes += "win-cli cwd"
    }

    # Corriger options.cwd si existe
    if ($winCliConfig.options -and $winCliConfig.options.cwd -like '*%ROO_ROOT%*') {
        $oldCwd = $winCliConfig.options.cwd
        $winCliConfig.options.cwd = $winCliConfig.options.cwd -replace '%ROO_ROOT%', $RooRoot
        Write-Host "[win-cli] options.cwd corrigé:" -ForegroundColor Yellow
        Write-Host "  Ancien: $oldCwd" -ForegroundColor Red
        Write-Host "  Nouveau: $($winCliConfig.options.cwd)" -ForegroundColor Green
        $changes += "win-cli options.cwd"
    }
}

# Fix 3: markitdown - Vérifier le chemin Python
if ($mcpSettings.mcpServers.'markitdown') {
    $markitdownConfig = $mcpSettings.mcpServers.'markitdown'

    if ($markitdownConfig.args -and $markitdownConfig.args.Count -gt 1) {
        $pythonPath = $markitdownConfig.args[1]
        if (-not (Test-Path $pythonPath)) {
            Write-Host "[markitdown] AVERTISSEMENT: Chemin Python introuvable:" -ForegroundColor Yellow
            Write-Host "  $pythonPath" -ForegroundColor Red
            Write-Host "  Vous devrez peut-être désactiver markitdown ou installer Python." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Résumé des modifications: $($changes.Count) changements" -ForegroundColor Cyan
foreach ($change in $changes) {
    Write-Host "  - $change" -ForegroundColor Green
}
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Sauvegarder le fichier modifié
if ($changes.Count -gt 0) {
    try {
        # Convertir en JSON et sauvegarder avec encodage UTF-8
        $jsonOutput = ConvertTo-Json -InputObject $mcpSettings -Depth 100
        [System.IO.File]::WriteAllText($RooMcpSettingsPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))

        Write-Host "✓ Fichier sauvegardé avec succès" -ForegroundColor Green
        Write-Host ""
        Write-Host "IMPORTANT: Redémarrez Visual Studio Code pour appliquer les changements." -ForegroundColor Yellow
    } catch {
        Write-Host "ERREUR: Impossible de sauvegarder le fichier: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Aucune modification nécessaire." -ForegroundColor Gray
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
