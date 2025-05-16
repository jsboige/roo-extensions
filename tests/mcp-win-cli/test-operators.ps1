# Test des opérateurs dans PowerShell
Write-Host "Test des opérateurs dans PowerShell"

# Test de l'opérateur & (en arrière-plan)
Write-Host "`nTest de l'opérateur & (en arrière-plan)"
Write-Host "Exécution de: Start-Process notepad -WindowStyle Minimized"
Start-Process notepad -WindowStyle Minimized
Start-Sleep -Seconds 2
Stop-Process -Name notepad -Force -ErrorAction SilentlyContinue

# Test de l'opérateur |
Write-Host "`nTest de l'opérateur |"
Write-Host "Exécution de: Get-Process | Select-Object -First 3"
Get-Process | Select-Object -First 3

# Test de l'opérateur ;
Write-Host "`nTest de l'opérateur ;"
Write-Host "Exécution de: Get-Process; Get-Service"
Get-Process | Select-Object -First 3; Get-Service | Select-Object -First 3

# Test de l'opérateur `
Write-Host "`nTest de l'opérateur ``"
Write-Host "Exécution de: Write-Host `"Ligne 1`nLigne 2`""
Write-Host "Ligne 1`nLigne 2"

# Test de commandes multiples avec séparateur
Write-Host "`nTest de commandes multiples avec séparateur"
Write-Host "Exécution de: Get-Process | Select-Object -First 3; Get-Service | Select-Object -First 3"
Get-Process | Select-Object -First 3; Get-Service | Select-Object -First 3

# Test de l'opérateur -and (équivalent logique de &&)
Write-Host "`nTest de l'opérateur -and (équivalent logique de &&)"
Write-Host "Exécution de: (Test-Path 'C:\Windows') -and (Test-Path 'C:\Program Files')"
$result = (Test-Path "C:\Windows") -and (Test-Path "C:\Program Files")
Write-Host "Résultat: $result"

Write-Host "`nTests terminés"