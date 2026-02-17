# Script pour analyser le matching parent-enfant
# Objectif: comparer l'instruction de bc93a6f7 avec les <new_task> de ac8aa7b4

$parentHead = Get-Content "exports\ui-snippets\ac8aa7b4-319c-4925-a139-4f4adca81921-head.txt" -Raw
$childHead = Get-Content "exports\ui-snippets\bc93a6f7-cd2e-4686-a832-46e3cd14d338-head.txt" -Raw

# Extraire l'instruction de l'enfant (premier message user)
$childJson = $childHead | ConvertFrom-Json
$childInstruction = ""
foreach ($msg in $childJson) {
    if ($msg.type -eq 'say' -and $msg.say -eq 'text') {
        $childInstruction = $msg.text
        break
    }
}

Write-Host "=== INSTRUCTION ENFANT bc93a6f7 (192 premiers chars) ===" -ForegroundColor Cyan
$childPrefix = $childInstruction.Substring(0, [Math]::Min(192, $childInstruction.Length))
Write-Host $childPrefix
Write-Host ""

# Extraire les <new_task> du parent
Write-Host "=== RECHERCHE <new_task> dans PARENT ac8aa7b4 ===" -ForegroundColor Yellow
$parentJson = $parentHead | ConvertFrom-Json
$newTaskCount = 0
foreach ($msg in $parentJson) {
    if ($msg.text -and $msg.text -match '<new_task>') {
        $newTaskCount++
        # Extraire le contenu après <new_task>
        if ($msg.text -match '<new_task>\s*(.+?)(\s*<|\Z)') {
            $taskContent = $matches[1].Trim()
            $taskPrefix = $taskContent.Substring(0, [Math]::Min(192, $taskContent.Length))
            Write-Host "NEW_TASK #$newTaskCount (192 premiers chars):" -ForegroundColor Green
            Write-Host $taskPrefix
            
            # Tester si l'instruction enfant commence par ce préfixe
            if ($childInstruction.StartsWith($taskContent.Substring(0, [Math]::Min($taskContent.Length, $childInstruction.Length)))) {
                Write-Host "✓ MATCH POTENTIEL!" -ForegroundColor Magenta
            }
            Write-Host ""
        }
    }
}

Write-Host "Total <new_task> trouvés: $newTaskCount" -ForegroundColor Yellow