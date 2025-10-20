# Script d'analyse des nouveautés de roo-state-manager
# Mission : Configuration du système de messagerie inter-agents
# Date : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Write-Host "=== MISSION : Configuration messagerie inter-agents roo-state-manager ===" -ForegroundColor Magenta
Write-Host "Etape 1 : Analyse des nouveautes" -ForegroundColor Yellow

# Navigation vers le repertoire roo-state-manager
$rooStatePath = "mcps/internal/servers/roo-state-manager"
Set-Location $rooStatePath

Write-Host "Repertoire actuel : $(Get-Location)" -ForegroundColor Green
Write-Host ""

# 1. Verifier les derniers commits
Write-Host "=== DERNIERS COMMITS (10 derniers) ===" -ForegroundColor Cyan
git log --oneline -10
Write-Host ""

# 2. Chercher les mentions de "messaging"
Write-Host "=== COMMITS AVEC 'messaging' ===" -ForegroundColor Cyan
$messagingCommits = git log --all --grep="messaging" --oneline
if ($messagingCommits) {
    $messagingCommits
} else {
    Write-Host "Aucun commit trouve avec 'messaging'" -ForegroundColor Yellow
}
Write-Host ""

# 3. Chercher les mentions de "inter-agent"
Write-Host "=== COMMITS AVEC 'inter-agent' ===" -ForegroundColor Cyan
$interAgentCommits = git log --all --grep="inter-agent" --oneline
if ($interAgentCommits) {
    $interAgentCommits
} else {
    Write-Host "Aucun commit trouve avec 'inter-agent'" -ForegroundColor Yellow
}
Write-Host ""

# 4. Chercher les mentions de "agent" (5 derniers)
Write-Host "=== COMMITS AVEC 'agent' (5 derniers) ===" -ForegroundColor Cyan
$agentCommits = git log --all --grep="agent" --oneline -5
if ($agentCommits) {
    $agentCommits
} else {
    Write-Host "Aucun commit trouve avec 'agent'" -ForegroundColor Yellow
}
Write-Host ""

# 5. Verifier le README
Write-Host "=== RECHERCHE DANS README ===" -ForegroundColor Cyan
if (Test-Path "README.md") {
    Write-Host "README.md trouve, recherche des termes 'messag|agent|communication'" -ForegroundColor Green
    $readmeMatches = Get-Content "README.md" | Select-String -Pattern "messag|agent|communication" -Context 2
    if ($readmeMatches) {
        $readmeMatches
    } else {
        Write-Host "Aucune correspondance trouvee dans README.md" -ForegroundColor Yellow
    }
} else {
    Write-Host "README.md non trouve" -ForegroundColor Red
}
Write-Host ""

# 6. Chercher les fichiers .env*
Write-Host "=== FICHIERS .env* ===" -ForegroundColor Cyan
$envFiles = Get-ChildItem -Path . -Recurse -Filter "*.env*" -ErrorAction SilentlyContinue
if ($envFiles) {
    $envFiles | ForEach-Object { Write-Host $_.FullName -ForegroundColor Green }
} else {
    Write-Host "Aucun fichier .env* trouve" -ForegroundColor Yellow
}
Write-Host ""

# 7. Chercher les fichiers *example*
Write-Host "=== FICHIERS EXAMPLE ===" -ForegroundColor Cyan
$exampleFiles = Get-ChildItem -Path . -Recurse -Filter "*example*" | Where-Object { $_.Extension -in @('.env', '.json', '.md') } -ErrorAction SilentlyContinue
if ($exampleFiles) {
    $exampleFiles | ForEach-Object { Write-Host $_.FullName -ForegroundColor Green }
} else {
    Write-Host "Aucun fichier example trouve" -ForegroundColor Yellow
}
Write-Host ""

# 8. Analyser la structure des repertoires
Write-Host "=== STRUCTURE DES REPERTOIRES ===" -ForegroundColor Cyan
Get-ChildItem -Path . | Where-Object { $_.PSIsContainer } | ForEach-Object { 
    Write-Host "Dossier: $($_.Name)" -ForegroundColor Green
    try {
        Get-ChildItem $_.FullName -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
            Write-Host "   Fichier: $($_.Name)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   Acces refuse" -ForegroundColor Yellow
    }
}
Write-Host ""

Write-Host "=== FIN D'ANALYSE ===" -ForegroundColor Magenta