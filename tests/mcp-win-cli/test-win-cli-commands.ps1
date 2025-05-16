# Test des commandes complexes avec Win-CLI
Write-Host "Test des commandes complexes avec Win-CLI"

# Fonction pour exécuter une commande et afficher le résultat
function Test-Command {
    param (
        [string]$Shell,
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "`n[$Shell] $Description"
    Write-Host "Commande: $Command"
    
    try {
        if ($Shell -eq "PowerShell") {
            $result = Invoke-Expression $Command
            Write-Host "Résultat:"
            $result
        } elseif ($Shell -eq "CMD") {
            $result = cmd /c $Command
            Write-Host "Résultat:"
            $result
        } elseif ($Shell -eq "GitBash") {
            $gitBashPath = "C:\Program Files\Git\bin\bash.exe"
            if (Test-Path $gitBashPath) {
                $result = & $gitBashPath -c $Command
                Write-Host "Résultat:"
                $result
            } else {
                Write-Host "Git Bash non trouvé: $gitBashPath"
            }
        }
        Write-Host "Statut: Succès"
    } catch {
        Write-Host "Erreur: $($_.Exception.Message)"
        Write-Host "Statut: Échec"
    }
}

# Tests pour PowerShell
Write-Host "`n=== Tests pour PowerShell ==="

# Test de commandes séquentielles avec ;
Test-Command -Shell "PowerShell" -Command "Get-Process | Select-Object -First 3; Get-Service | Select-Object -First 3" -Description "Commandes séquentielles avec ;"

# Test de redirection avec |
Test-Command -Shell "PowerShell" -Command "Get-Process | Where-Object { `$_.CPU -gt 0 } | Select-Object -First 3" -Description "Redirection avec |"

# Test de condition avec -and
Test-Command -Shell "PowerShell" -Command "`$a = 5; `$b = 10; if (`$a -lt `$b -and `$b -gt 0) { 'Condition vraie' } else { 'Condition fausse' }" -Description "Condition avec -and"

# Tests pour CMD
Write-Host "`n=== Tests pour CMD ==="

# Test de commandes séquentielles avec &
Test-Command -Shell "CMD" -Command "dir /b & echo Test" -Description "Commandes séquentielles avec &"

# Test de commandes séquentielles avec &&
Test-Command -Shell "CMD" -Command "dir /b && echo Test" -Description "Commandes séquentielles avec &&"

# Test de redirection avec |
Test-Command -Shell "CMD" -Command "dir | findstr /i windows" -Description "Redirection avec |"

# Tests pour Git Bash
Write-Host "`n=== Tests pour Git Bash ==="

# Test de commandes séquentielles avec ;
Test-Command -Shell "GitBash" -Command "ls -la; echo Test" -Description "Commandes séquentielles avec ;"

# Test de commandes séquentielles avec &&
Test-Command -Shell "GitBash" -Command "ls -la && echo Test" -Description "Commandes séquentielles avec &&"

# Test de redirection avec |
Test-Command -Shell "GitBash" -Command "ls -la | grep test" -Description "Redirection avec |"

Write-Host "`nTests terminés"