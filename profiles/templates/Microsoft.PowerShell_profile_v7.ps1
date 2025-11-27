# Profil PowerShell 7+ (Core) Standardisé
# Généré par Roo Code - ID Correction: SYS-003-ENVIRONMENT
# Date: 2025-10-30

# --- Initialisation de l'Encodage ---
# Recherche du script d'initialisation dans les chemins standards
$candidatePaths = @(
    (Join-Path $PSScriptRoot "..\..\scripts\encoding\Initialize-EncodingManager.ps1"),
    "d:\roo-extensions\scripts\encoding\Initialize-EncodingManager.ps1",
    "$env:ROO_EXTENSIONS_ROOT\scripts\encoding\Initialize-EncodingManager.ps1",
    (Join-Path $HOME "roo-extensions\scripts\encoding\Initialize-EncodingManager.ps1")
)

$encodingScriptPath = $null
foreach ($path in $candidatePaths) {
    if ($path -and (Test-Path $path)) {
        $encodingScriptPath = $path
        break
    }
}

if ($encodingScriptPath) {
    . $encodingScriptPath
} else {
    Write-Warning "EncodingManager introuvable. L'encodage UTF-8 peut ne pas être configuré correctement."
}

# --- Configuration Personnalisée ---
# Ajoutez vos alias et fonctions personnalisés ci-dessous

# Alias utiles
Set-Alias -Name ll -Value Get-ChildItem -Option AllScope
Set-Alias -Name grep -Value Select-String -Option AllScope

# Fonction de prompt personnalisé (optionnel)
function prompt {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    $symbol = "⚡" # Symbole spécifique PS Core
    if ($principal.IsInRole($adminRole)) {
        $symbol = "🔥"
        Write-Host "[ADMIN] " -NoNewline -ForegroundColor Red
    }

    Write-Host "PS Core " -NoNewline -ForegroundColor Magenta
    Write-Host ($PWD.Path) -NoNewline -ForegroundColor Cyan
    return "$symbol "
}

# --- Chargement des Modules ---
# Import-Module -Name MyCustomModule -ErrorAction SilentlyContinue

# Activation de PSReadLine si disponible (standard dans PS 7)
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    try {
        Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
    } catch {
        Write-Verbose "PSReadLine configuration skipped (non-interactive or redirected console)"
    }
}