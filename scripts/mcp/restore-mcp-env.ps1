<#
.SYNOPSIS
    Restaure le .env du MCP roo-state-manager depuis le backup LOCAL hors-git
    (bootstrap-safe, ZERO dependance GDrive).

.DESCRIPTION
    Remediation #2772 (incident web1 : .env supprime -> MCP DOWN 28h sans alarme).

    Ordre de restauration (aucune ne depend d'un .env present, donc bootstrap-safe) :
      1. %USERPROFILE%\.roo-state-manager\.env            (backup primaire)
      2. %USERPROFILE%\.roo-state-manager\.env.bak.<ts>   (snapshot le plus recent)
      3. ECHEC BRUYANT (exit 1) : aucun backup local -> vraie catastrophe (cas web1).
         GDrive n'est PAS tente ici : son chemin (ROOSYNC_SHARED_PATH) vit dans le
         .env manquant et differe par machine -> inutilisable en bootstrap.
         Action requise : re-propagation manuelle (message autodestructeur + PJ) ou
         copie manuelle depuis le blob GDrive offsite si le chemin est connu.

    Copie octet-pour-octet (Copy-Item) : secrets/cles jamais reserialises.
    Idempotent : si le .env cible existe deja et est non-vide, no-op sauf -Force.

.NOTES
    Appele par la garde pre-flight des spawn scripts quand le .env manque, ou
    manuellement. Retourne 0 si le .env est present (restaure ou deja la), 1 sinon.
#>
[CmdletBinding()]
param(
    # Ecraser le .env cible meme s'il est deja present et non-vide.
    [switch]$Force,

    # Verifier apres restauration que les vars dures requises sont presentes
    # (noms uniquement, jamais les valeurs).
    [switch]$VerifyVars
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    try {
        $top = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null | Out-String).Trim()
        if ($top) { return $top }
    } catch {}
    return (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
}

$repoRoot   = Resolve-RepoRoot
$envRelPath = 'mcps/internal/servers/roo-state-manager/.env'
$envPath    = Join-Path $repoRoot $envRelPath

# --- No-op si deja present et non-vide (sauf -Force) ---
if ((Test-Path -LiteralPath $envPath) -and ((Get-Item -LiteralPath $envPath).Length -gt 0) -and (-not $Force)) {
    Write-Host "[restore-mcp-env] .env deja present et non-vide -> no-op ($envPath)." -ForegroundColor DarkGray
    exit 0
}

$backupDir     = Join-Path $env:USERPROFILE '.roo-state-manager'
$primaryBackup = Join-Path $backupDir '.env'
$source        = $null

# 1. Backup primaire local hors-git.
if ((Test-Path -LiteralPath $primaryBackup) -and ((Get-Item -LiteralPath $primaryBackup).Length -gt 0)) {
    $source = $primaryBackup
} else {
    # 2. Snapshot rotatif le plus recent.
    if (Test-Path -LiteralPath $backupDir) {
        $snap = Get-ChildItem -LiteralPath $backupDir -Filter '.env.bak.*' -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 0 } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
        if ($snap) { $source = $snap.FullName }
    }
}

# 3. Echec bruyant : aucun backup local.
if (-not $source) {
    Write-Host "[restore-mcp-env] CRITICAL: aucun backup local hors-git trouve dans $backupDir." -ForegroundColor Red
    Write-Host "[restore-mcp-env] Le .env ne peut PAS etre restaure automatiquement (bootstrap impossible)." -ForegroundColor Red
    Write-Host "[restore-mcp-env] Action requise: re-propagation manuelle des secrets (message autodestructeur + PJ)" -ForegroundColor Red
    Write-Host "[restore-mcp-env]   ou copie manuelle depuis le blob GDrive offsite (chemin ROOSYNC_SHARED_PATH connu)." -ForegroundColor Red
    exit 1
}

# S'assurer que le repertoire cible existe (le submodule peut avoir ete partiellement nuke).
$envDir = Split-Path -Parent $envPath
if (-not (Test-Path -LiteralPath $envDir)) {
    New-Item -ItemType Directory -Path $envDir -Force | Out-Null
}

Copy-Item -LiteralPath $source -Destination $envPath -Force
Write-Host "[restore-mcp-env] OK .env restaure depuis $source" -ForegroundColor Green

# --- Verification optionnelle des vars dures (noms seulement) ---
if ($VerifyVars) {
    $required = @('ROOSYNC_SHARED_PATH', 'ROOSYNC_MACHINE_ID')
    $content  = Get-Content -LiteralPath $envPath
    $missing  = @()
    foreach ($var in $required) {
        if (-not ($content | Where-Object { $_ -match "^\s*$([regex]::Escape($var))\s*=\s*\S" })) {
            $missing += $var
        }
    }
    # Au moins une cle d'embeddings requise (EMBEDDING_API_KEY prefere, sinon OPENAI_API_KEY).
    $hasEmbKey = $content | Where-Object { $_ -match '^\s*(EMBEDDING_API_KEY|OPENAI_API_KEY)\s*=\s*\S' }
    if (-not $hasEmbKey) { $missing += 'EMBEDDING_API_KEY|OPENAI_API_KEY' }

    if ($missing.Count -gt 0) {
        Write-Host "[restore-mcp-env] WARN: .env restaure mais vars dures manquantes: $($missing -join ', ')" -ForegroundColor Yellow
        Write-Host "[restore-mcp-env] Le backup local est peut-etre incomplet/perime." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[restore-mcp-env] OK vars dures presentes." -ForegroundColor Green
}

Write-Host "[restore-mcp-env] DONE." -ForegroundColor Cyan
exit 0
