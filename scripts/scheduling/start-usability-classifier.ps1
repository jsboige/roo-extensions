<#
.SYNOPSIS
    Launcher for the Claude-UsabilityClassifier scheduled task (#4327, RX122).

.DESCRIPTION
    Runs scripts/diagnostic/classify-machine-usability.ps1 with the DPAPI
    credential file and appends the run (header, output, exit code) to
    outputs/scheduling/logs/usability-classifier.log - the repo's usual
    scheduling log location (rotated by rotate-scheduling-logs.ps1, #3834).

    Invoked by the generated VBS (wscript.exe, SW_HIDE - the
    harden-hidden-tasks convention) so the 5-minute fire never flashes a
    console. The classifier's own exit code is the launcher's exit code, so
    LastTaskResult reflects the sweep: 0 clean / 1 unreachable / 2
    reachable-but-unusable / 3 incomplete measurement (bad credential file
    included - it fails loud, before any probe).

    The credential file is a DPAPI PSCredential (Export-Clixml), readable
    ONLY by the user who exported it - which is why the task runs Interactive
    as that same user. Nothing in this launcher prints or logs the password.

.PARAMETER CredentialFile
    Path of the credential file. Default: %USERPROFILE%\.roo-state-manager\
    winrm-classifier.cred.xml (the install script bakes the same path into
    the VBS, so this default is the fallback, not the source of truth).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\scheduling\start-usability-classifier.ps1
#>
param(
    [string]$CredentialFile = ""
)

$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = (Resolve-Path "$scriptDir\..\..").Path
$classifier = Join-Path $repoRoot 'scripts\diagnostic\classify-machine-usability.ps1'
if ([string]::IsNullOrEmpty($CredentialFile)) {
    $CredentialFile = Join-Path $HOME '.roo-state-manager\winrm-classifier.cred.xml'
}

# The usual scheduling log location (start-meta-audit.ps1, Vibe-Feeder): one
# rolling file per tool, weekly archive-then-remove by rotate-scheduling-logs.
$logDir = Join-Path $repoRoot 'outputs\scheduling\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'usability-classifier.log'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'), $Message
    Add-Content -Path $logFile -Value $line
}

if (-not (Test-Path $classifier)) {
    Write-Log "ABORT: classifier not found: $classifier"
    exit 1
}

$psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = 'powershell.exe' }

Write-Log "=== usability-classifier fire (task Claude-UsabilityClassifier) ==="
# Child process on purpose: the classifier ends with `exit N`, and an `exit`
# in a script called with `&` would terminate THIS launcher's session before
# the exit code could be logged.
$out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $classifier -CredentialFile $CredentialFile 2>&1
$code = $LASTEXITCODE
foreach ($l in @($out)) { Write-Log "  $l" }
Write-Log "=== exit $code ==="
exit $code
