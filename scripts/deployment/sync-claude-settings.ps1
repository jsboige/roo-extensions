# sync-claude-settings.ps1 — Harmonisation flotte ~/.claude/settings.json (reference po-2023)
# Mandat user 21-22/08/2026 : diffuser la structure de reference du settings.json du hub.
# 23/08 v2 : modele custom -> gpt-5.6-sol (onboarding OpenAI Pro, credits Codex).
# 23/08 v2.2 : fenetre de compaction = SEULEMENT-SI-ABSENT (miroir garde #3215, WARN ai-01 15:05Z) —
#              le settings.json de la machine FAIT FOI (.claude/rules/context-window.md v6).
# Idempotent : re-executable sans effet de bord. Backup horodate avant chaque ecriture.
# NE TOUCHE PAS : permissions, model, effortLevel, et toute autre cle locale.
# Preserve le x-proxy-key existant (canal secret) et ne l'ecrit JAMAIS ailleurs qu'a sa place.
#
# Usage:
#   pwsh -File sync-claude-settings.ps1 -MachineName myia-po-2024          # applique
#   pwsh -File sync-claude-settings.ps1 -MachineName myia-po-2024 -Verify  # lecture seule
#   -BaseUrl pour surcharge ponctuelle (defaut = table ci-dessous)
#
# Apres application : RESTART de VS Code / Claude Code requis (env lu au demarrage seulement).

param(
  [Parameter(Mandatory = $true)]
  [string]$MachineName,
  [string]$BaseUrl,
  [switch]$Verify
)
$ErrorActionPreference = 'Stop'

# NB (23/08, incident po-204 c.272) : la table peut deriver de la topologie REELLE d'une machine
# (po-204 a retire son sidecar c.184 → hub direct). La garde de connectivite ci-dessous bloque
# l'ecriture si l'endpoint ne repond pas ; si votre entree est périmée, surchargez -BaseUrl.
$BaseUrlTable = @{
  'myia-po-2023' = 'http://192.168.0.46:3000'   # hub (direct)
  'myia-ai-01'   = 'http://localhost:3000'      # sidecar local (vivant 22/08, .51:3000)
  'myia-po-2024' = 'http://192.168.0.46:3000'   # hub direct (sidecar retiré c.184) — corrigé 23/08
  'myia-po-2026' = 'https://models.myia.io'     # WAN (netstat :3000 = com.docker.backend, PAS un sidecar — corrigé 23/08, 3e stale-table)
  'myia-po-2025' = 'https://models.myia.io'     # WAN itinérante (domaine public, pas d'IP LAN)
  'myia-po-2027' = 'https://models.myia.io'     # WAN itinérante (2 IPs publiques observées, légitime user 23/08)
  'myia-web1'    = 'https://models.myia.io'     # WAN
}
if (-not $BaseUrl) { $BaseUrl = $BaseUrlTable[$MachineName] }
if (-not $BaseUrl) { throw "Machine inconnue '$MachineName' et -BaseUrl absent. Machines: $($BaseUrlTable.Keys -join ', ')" }

# ── Cles de reference (structure po-2023, 22/08/2026) — ANTHROPIC_CUSTOM_HEADERS gere a part ──
$RefEnv = [ordered]@{
  'ANTHROPIC_AUTH_TOKEN'                            = ''
  'ANTHROPIC_BASE_URL'                              = $BaseUrl
  'ANTHROPIC_DEFAULT_FABLE_MODEL'                   = 'claude-fable-5[1m]'
  'ANTHROPIC_DEFAULT_FABLE_MODEL_NAME'              = 'Fable 5'
  'ANTHROPIC_DEFAULT_FABLE_MODEL_DESCRIPTION'       = 'Anthropic Fable 5 (SOTA)'
  'ANTHROPIC_DEFAULT_OPUS_MODEL'                    = 'claude-opus-5[1m]'
  'ANTHROPIC_DEFAULT_OPUS_MODEL_NAME'               = 'Opus'
  'ANTHROPIC_DEFAULT_OPUS_MODEL_DESCRIPTION'        = 'Rôle Opus — modèle décidé par claudish (Anthropic natif, bascule en cascade si plan épuisé)'
  'ANTHROPIC_DEFAULT_SONNET_MODEL'                  = 'claude-sonnet-5[1m]'
  'ANTHROPIC_DEFAULT_SONNET_MODEL_NAME'             = 'Sonnet'
  'ANTHROPIC_DEFAULT_SONNET_MODEL_DESCRIPTION'      = 'Rôle Sonnet — modèle décidé par claudish (bascule budget selon les quotas)'
  'ANTHROPIC_DEFAULT_HAIKU_MODEL'                   = 'claude-haiku-4-5-20251001[1m]'
  'ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME'              = 'Haiku'
  'ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION'       = 'Rôle Haiku — modèle décidé par claudish (bascule budget selon les quotas)'
  'ANTHROPIC_CUSTOM_MODEL_OPTION'                   = 'gpt-5.6-sol'
  'ANTHROPIC_CUSTOM_MODEL_OPTION_NAME'              = 'Sol (GPT-5.6 via OpenAI Pro)'
  'ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION'       = 'SOTA OpenAI GPT-5.6 Sol, souscription Pro (crédits Codex, OAuth chatgpt.com). Lane analyse lourde hors cascade failover. Modèles intermédiaires = providers chinois.'
  'API_TIMEOUT_MS'                                  = '600000'
  'MCP_TOOL_TIMEOUT'                                = '900000'
  'CLAUDE_CODE_MAX_CONTEXT_TOKENS'                  = '1000000'
  'CLAUDE_CODE_AUTO_COMPACT_WINDOW'                 = '280000'
  'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE'                 = '95'
}

$path = Join-Path $env:USERPROFILE '.claude\settings.json'

function Show-State([string]$label, $settings) {
  Write-Output "== $label =="
  if (-not $settings -or -not $settings.env) { Write-Output "  (env absent)"; return }
  foreach ($k in @('ANTHROPIC_BASE_URL','ANTHROPIC_DEFAULT_OPUS_MODEL','ANTHROPIC_DEFAULT_SONNET_MODEL','ANTHROPIC_DEFAULT_HAIKU_MODEL','ANTHROPIC_DEFAULT_FABLE_MODEL','ANTHROPIC_CUSTOM_MODEL_OPTION','CLAUDE_CODE_AUTO_COMPACT_WINDOW')) {
    $v = $settings.env.$k
    if ($null -eq $v) { $v = '<ABSENT>' }
    Write-Output ("  {0,-42} = {1}" -f $k, $v)
  }
  $h = $settings.env.ANTHROPIC_CUSTOM_HEADERS
  if ($h) { Write-Output ("  {0,-42} = {1}" -f 'ANTHROPIC_CUSTOM_HEADERS(X-Machine)', (($h -split "`n") | Where-Object { $_ -match 'X-Claudish-Machine' })) }
}

if (-not (Test-Path $path)) {
  if ($Verify) { Write-Output "ABSENT: $path — rien a verifier"; exit 0 }
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  [System.IO.File]::WriteAllText($path, '{"env":{}}', [System.Text.UTF8Encoding]::new($false))
}

$raw = [System.IO.File]::ReadAllText($path)
$settings = $null
try { $settings = $raw | ConvertFrom-Json } catch { throw "settings.json illisible (JSON invalide): $($_.Exception.Message)" }
Show-State 'AVANT' $settings
if ($Verify) { exit 0 }

# ── Garde connectivite (anti port mort — incident po-204 23/08 : table périmée = base_url cassé) ──
try { $u = [Uri]$BaseUrl } catch { throw "BaseUrl illisible : '$BaseUrl'" }
$tcpOk = Test-NetConnection -ComputerName $u.Host -Port $u.Port -WarningAction SilentlyContinue
if (-not $tcpOk.TcpTestSucceeded) {
  throw @"
ENDPOINT FERME : $BaseUrl ne repond pas (TcpTestSucceeded=False).
Ecrire ce base_url casserait le routage modeles. La table du script derive peut-etre de la
topologie reelle de cette machine (sidecar local vs hub direct). Verifier avec netstat, puis
relancer avec -BaseUrl <endpoint ouvert>, ou corriger la table.
"@
}

# ── Merge ──
if (-not $settings.env) {
  $settings | Add-Member -MemberType NoteProperty -Name 'env' -Value ([pscustomobject]@{}) -Force
}
# SEULEMENT-SI-ABSENT (garde symetrique #3215). Ces cles ne s'ecrivent que pour bootstrapper
# une machine vierge — JAMAIS pour ecraser un choix machine (ai-01=310k, ai-01 API_TIMEOUT_MS=3000000,
# ai-01 modele selecteur=qwen3.8-max, route machine ANTHROPIC_BASE_URL). La table BaseUrl sert de
# valeur de bootstrap ; sa garde TCP prouve seulement qu'un endpoint repond, pas que c'est le bon.
# Les cles ANTHROPIC_CUSTOM_MODEL_OPTION* ne se surchargent pas non plus : la route du selecteur est
# un choix machine ET, tant que #3276 n'est pas tranchee, ecrire la valeur par defaut (gpt-5.6-sol)
# propagerait la route sous investigation (findings ai-01 27/08).
# Le plancher PCT >= 90 reste garanti par deploy-claude-mcp-settings.ps1.
$OnlyIfAbsent = @('CLAUDE_CODE_AUTO_COMPACT_WINDOW', 'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE', 'API_TIMEOUT_MS', 'ANTHROPIC_BASE_URL', 'ANTHROPIC_CUSTOM_MODEL_OPTION', 'ANTHROPIC_CUSTOM_MODEL_OPTION_NAME', 'ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION')
$changed = @()
foreach ($k in $RefEnv.Keys) {
  $new = [string]$RefEnv[$k]
  $old = $settings.env.$k
  if ($null -eq $old) {
    $settings.env | Add-Member -MemberType NoteProperty -Name $k -Value $new -Force
    $changed += "+ $k"
  } elseif ("$old" -ne $new -and $k -notin $OnlyIfAbsent) {
    $settings.env.$k = $new
    $changed += "~ $k : '$old' -> '$new'"
  }
}

# ANTHROPIC_CUSTOM_HEADERS : machine name impose, x-proxy-key PRESERVE
$existingHeaders = [string]$settings.env.ANTHROPIC_CUSTOM_HEADERS
$proxyKeyLine = @($existingHeaders -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^x-proxy-key:' }) | Select-Object -First 1
if (-not $proxyKeyLine) {
  Write-Warning "Aucun x-proxy-key existant — header placeholder ecrit. Recuperer la cle par canal secret (DM autodestructeur po-203) puis re-executer."
  $proxyKeyLine = 'x-proxy-key: A_COMPLETER_PAR_CANAL_SECRET'
}
$newHeaders = "X-Claudish-Machine: $MachineName`n$proxyKeyLine"
if ($existingHeaders -ne $newHeaders) {
  # Add-Member -Force : cree si absent (affectation directe jette sur PSCustomObject vierge)
  $settings.env | Add-Member -MemberType NoteProperty -Name 'ANTHROPIC_CUSTOM_HEADERS' -Value $newHeaders -Force
  $changed += '~ ANTHROPIC_CUSTOM_HEADERS (machine=' + $MachineName + ', x-proxy-key preserve)'
}

# ── Backup + ecriture UTF-8 sans BOM ──
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bak = "$path.bak-$stamp"
Copy-Item $path $bak
$json = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))

# ── Relecture + validation ──
$check = [System.IO.File]::ReadAllText($path) | ConvertFrom-Json
if (-not $check.env.ANTHROPIC_DEFAULT_SONNET_MODEL) { throw "VALIDATION ECHOUEE: cle absente apres ecriture — restaurer $bak" }
Show-State 'APRES' $check
Write-Output ""
Write-Output "Backup: $bak"
if ($changed.Count -eq 0) {
  Write-Output "Resultat: DEJA ALIGNE (0 changement)"
} else {
  Write-Output "Resultat: $($changed.Count) changement(s):"
  $changed | ForEach-Object { Write-Output "  $_" }
}
Write-Output "RESTART VS Code / Claude Code requis pour prise en compte (env lu au demarrage)."
