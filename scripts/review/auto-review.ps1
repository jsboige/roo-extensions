# Auto-Review Script - sk-agent + GitHub Comment
# Lance une review automatique via sk-agent et poste le résultat en commentaire

$ErrorActionPreference = "Stop"

# Configuration
$RepoOwner = "jsboige"
$RepoName = "roo-extensions"
$SkAgentEndpoint = "https://skagents.myia.io/mcp"
$SkAgentApiKey = "181ecbaa03674f028e4dbb3c7efc8cb6"
$MaxDiffSize = 10000 # Taille max du diff (en caractères)

Write-Host "[AUTO-REVIEW] Démarrage de la review automatique" -ForegroundColor Green

# Étape 1: Vérifier s'il y a de nouveaux commits
try {
    Write-Host "[AUTO-REVIEW] Vérification des nouveaux commits..."
    $lastCommitHash = git rev-parse HEAD~1
    $currentHash = git rev-parse HEAD

    if ($lastCommitHash -eq $currentHash) {
        Write-Host "[AUTO-REVIEW] Aucun nouveau commit, sortie." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "[AUTO-REVIEW] Nouveau commit détecté: $currentHash" -ForegroundColor Cyan
} catch {
    Write-Host "[AUTO-REVIEW] Erreur lors de la vérification des commits: $_" -ForegroundColor Red
    exit 1
}

# Étape 2: Récupérer le diff
try {
    Write-Host "[AUTO-REVIEW] Récupération du diff..."
    $diff = git diff HEAD~1 HEAD --no-color

    if ([string]::IsNullOrWhiteSpace($diff)) {
        Write-Host "[AUTO-REVIEW] Diff vide, sortie." -ForegroundColor Yellow
        exit 0
    }

    # Limiter la taille du diff
    if ($diff.Length -gt $MaxDiffSize) {
        Write-Host "[AUTO-REVIEW] Diff trop long ($($diff.Length) chars), tronquature..." -ForegroundColor Yellow
        $diff = $diff.Substring(0, $MaxDiffSize) + "`n[... Diff tronqué ...]"
    }

    Write-Host "[AUTO-REVIEW] Diff récupéré ($($diff.Length) caractères)" -ForegroundColor Cyan
} catch {
    Write-Host "[AUTO-REVIEW] Erreur lors de la récupération du diff: $_" -ForegroundColor Red
    exit 1
}

# Étape 3: Trouver l'issue/PR associé
try {
    Write-Host "[AUTO-REVIEW] Recherche de l'issue/PR associée..."

    # Utiliser les commits messages pour trouver une référence issue/PR
    $commitMessage = git log --format=%B -n 1 HEAD
    $issueNumber = $null

    # Chercher des patterns comme: "Fix #123", "Close #456", "PR #789", "Issue #541"
    $patterns = @(
        '(?i)(fix|close|resolve)[\s\-]*#(\d+)',
        '(?i)issue[\s\-]*#(\d+)',
        '(?i)#[\s]*(\d+)(?:\s|$|\)|,|\.|;)'
    )

    foreach ($pattern in $patterns) {
        if ($commitMessage -match $pattern) {
            $issueNumber = $matches[1]
            Write-Host "[AUTO-REVIEW] Issue #${issueNumber} trouvée dans le commit message" -ForegroundColor Cyan
            break
        }
    }

    # Si aucune issue trouvée, chercher parmi les 10 dernières issues ouvertes
    if (-not $issueNumber) {
        $issues = gh issue list --repo "$RepoOwner/$RepoName" --state open --limit 10 --json number,title
        if ($issues) {
            $issues = $issues | ConvertFrom-Json
            $commitShort = $currentHash.Substring(0, 7)

            foreach ($issue in $issues) {
                if ($commitMessage.Contains(" #$($issue.number) ") -or $commitMessage.Contains("#$($issue.number)")) {
                    $issueNumber = $issue.number
                    Write-Host "[AUTO-REVIEW] Issue #${issueNumber} trouvée par correspondance" -ForegroundColor Cyan
                    break
                }
            }
        }
    }

    # Si toujours aucune issue, utiliser la plus récente (pour tests)
    if (-not $issueNumber) {
        $latestIssue = gh issue list --repo "$RepoOwner/$RepoName" --state open --limit 1 --json number --jq '.[0].number'
        if ($latestIssue) {
            $issueNumber = $latestIssue
            Write-Host "[AUTO-REVIEW] Issue #${issueNumber} utilisée (la plus récente)" -ForegroundColor Yellow
        }
    }

    if (-not $issueNumber) {
        Write-Host "[AUTO-REVIEW] Aucune issue/PR trouvée, sortie." -ForegroundColor Yellow
        exit 0
    }

} catch {
    Write-Host "[AUTO-REVIEW] Erreur lors de la recherche de l'issue: $_" -ForegroundColor Red
    exit 1
}

# Étape 4: Appeler sk-agent pour la review
try {
    Write-Host "[AUTO-REVIEW] Appel de sk-agent pour la review..."

    # Préparer le prompt pour sk-agent
    $prompt = @"
Tu es un expert en review de code. Tu dois analyser ce diff et fournir une review constructive avec 4 perspectives:

1. **Sécurité**: Problèmes de sécurité potentiels
2. **Performance**: Optimisations possibles
3. **Maintenabilité**: Qualité du code, lisibilité
4. **Synthèse**: Points forts et améliorations globales

Format de réponse (Markdown):
## Auto-Review par sk-agent

### 📝 Résumé
[Breve synthèse des changements]

### 🔍 Analyse détaillée
#### Sécurité
[Points de sécurité]

#### Performance
[Points de performance]

#### Maintenabilité
[Points de maintenabilité]

### 🎯 Synthèse finale
[Points forts + recommandations]

---
*Review automatique générée par sk-agent sur la machine ${env:COMPUTERNAME}*
"@

    # Construire la requête sk-agent
    $body = @{
        jsonrpc = "2.0"
        id = 1
        method = "tools/call"
        params = @{
            name = "create_conversation"
            arguments = @{
                conversation_type = "code-review"
                participants = @("critic", "optimist", "devils-advocate", "pragmatist")
                context = @{
                    diff = $diff
                    commit_hash = $currentHash
                    file_paths = $diff | Select-String -Pattern "^(diff|---|\+\+\+)" -Context 0 | ForEach-Object { $_.Line } | Where-Object { $_ -match "^diff a/|^--- a/|\+\+\+ b/" } | ForEach-Object { $_ -replace "^(diff a/|--- a/|\+\+\+ b/)", "" } | Select-Object -First 10
                }
            }
        }
    } | ConvertTo-Json -Depth 10

    # Appeler l'API sk-agent
    $response = Invoke-RestMethod -Uri $SkAgentEndpoint -Method Post -Headers @{
        "Authorization" = "Bearer $SkAgentApiKey"
        "Content-Type" = "application/json"
    } -Body $body

    if ($response.result -and $result.content) {
        $reviewResult = $result.content[0].text
        Write-Host "[AUTO-REVIEW] Review reçue de sk-agent" -ForegroundColor Cyan
    } else {
        throw "Réponse invalide de sk-agent"
    }

} catch {
    Write-Host "[AUTO-REVIEW] Erreur lors de l'appel à sk-agent: $_" -ForegroundColor Red
    # Fallback: créer une review simple
    $reviewResult = @"
## Auto-Review par sk-agent

### 📝 Résumé
Review automatique suite au commit $currentHash

### ⚠️ Attention
Une erreur est survenue lors de l'appel à sk-agent. Review manuelle recommandée.

---
*Review automatique générée par sk-agent sur la machine ${env:COMPUTERNAME}*
"@
}

# Étape 5: Poster le commentaire
try {
    Write-Host "[AUTO-REVIEW] Postage du commentaire sur l'issue #$issueNumber..."

    # Ajouter des métadonnées
    $reviewWithMetadata = @"
$reviewResult

**Informations techniques:**
- Machine: ${env:COMPUTERNAME}
- Commit: $currentHash
- Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- Script: auto-review.ps1
"@

    # Poster le commentaire
    $commentResult = gh api repos/$RepoOwner/$RepoName/issues/$issueNumber/comments -f body=$reviewWithMetadata

    if ($commentResult) {
        $commentId = $commentResult.id
        Write-Host "[AUTO-REVIEW] Commentaire posté avec succès (ID: $commentId)" -ForegroundColor Green
        Write-Host "[AUTO-REVIEW] URL: https://github.com/$RepoOwner/$RepoName/issues/$issueNumber#issuecomment-$commentId" -ForegroundColor Cyan
    } else {
        throw "Le commentaire n'a pas été posté"
    }

} catch {
    Write-Host "[AUTO-REVIEW] Erreur lors du post du commentaire: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[AUTO-REVIEW] Workflow terminé avec succès!" -ForegroundColor Green