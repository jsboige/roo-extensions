param(
    [switch]$WhatIf = $false
)

# Chemin vers les taches Roo
$TasksPath = "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"

if (-not (Test-Path $TasksPath)) {
    Write-Host "Chemin des taches non trouve: $TasksPath" -ForegroundColor Red
    exit 1
}

Write-Host "[SCAN] Scanning for corrupted api_conversation_history.json files..." -ForegroundColor Yellow

$totalFiles = 0
$corruptedFiles = 0
$repairedFiles = 0
$failedRepairs = 0

Get-ChildItem -Path $TasksPath -Directory | ForEach-Object {
    $apiHistoryFile = Join-Path $_.FullName "api_conversation_history.json"
    
    if (Test-Path $apiHistoryFile) {
        $totalFiles++
        
        # Lire le contenu en tant que bytes pour detecter le BOM
        $bytes = [System.IO.File]::ReadAllBytes($apiHistoryFile)
        
        # Verifier si le fichier commence par un BOM UTF-8 (EF BB BF)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $corruptedFiles++
            Write-Host "[ERROR] BOM detecte: $apiHistoryFile" -ForegroundColor Red
            
            if (-not $WhatIf) {
                try {
                    # Lire le contenu texte et enlever le BOM
                    $content = [System.IO.File]::ReadAllText($apiHistoryFile, [System.Text.Encoding]::UTF8)
                    if ($content.StartsWith([char]0xFEFF)) {
                        $content = $content.Substring(1)
                    }
                    
                    # Verifier que c'est du JSON valide
                    $null = $content | ConvertFrom-Json
                    
                    # Reecrire sans BOM
                    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                    [System.IO.File]::WriteAllText($apiHistoryFile, $content, $utf8NoBom)
                    
                    $repairedFiles++
                    Write-Host "[OK] Repare: $apiHistoryFile" -ForegroundColor Green
                }
                catch {
                    $failedRepairs++
                    Write-Host "[FAIL] Echec reparation $apiHistoryFile : $($_.Exception.Message)" -ForegroundColor Magenta
                }
            }
            else {
                Write-Host "[SIM] Serait repare: $apiHistoryFile" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "`n[RESUME] RESULTATS:" -ForegroundColor Cyan
Write-Host "Fichiers analyses: $totalFiles"
Write-Host "Fichiers corrompus (BOM): $corruptedFiles"

if ($WhatIf) {
    Write-Host "Mode simulation - Aucune modification effectuee" -ForegroundColor Yellow
}
else {
    Write-Host "Fichiers repares: $repairedFiles" -ForegroundColor Green
    Write-Host "Echecs de reparation: $failedRepairs" -ForegroundColor Red
}

if ($corruptedFiles -eq 0) {
    Write-Host "[SUCCESS] Aucun fichier corrompu trouve !" -ForegroundColor Green
}
elseif (-not $WhatIf -and $repairedFiles -gt 0) {
    Write-Host "[INFO] Redemarrez maintenant le serveur roo-state-manager" -ForegroundColor Cyan
}