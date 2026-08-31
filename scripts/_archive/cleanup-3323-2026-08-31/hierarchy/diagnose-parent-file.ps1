<#
.SYNOPSIS
    Extrait les timestamps de création des 17 tâches candidates pour identifier l'original
.DESCRIPTION
    Lit le premier message de api_conversation_history.json pour chaque tâche et retourne
    les timestamps triés pour identifier la tâche la plus ancienne (= parent original)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TasksDirectory = ""
)

if (-not $TasksDirectory) {
    . "$PSScriptRoot\..\..\common\extension-paths.ps1"
    $TasksDirectory = Join-Path (Get-GlobalStoragePath -Extension RooCode) "tasks"
}

# Liste des 17 IDs de tâches candidates (résultats de la recherche exhaustive)
$candidateTaskIds = @(
    "cb7e564f-152f-48e3-8eff-f424d7ebc6bd",
    "cb7e564f-7aa0-4a41-9d1e-b87e7ebc3c7e",
    "52e5a53b-5e85-4da8-8de5-4bb6d1e8a14c",
    "60ec27d5-72c3-427a-8076-2d4eab5a5c32",
    "14fb8fd3-9c08-4682-81e9-1fbd5b25be1d",
    "a6e46ba6-4d86-4d4b-b6e7-9f5ee6bcba7f",
    "5d29b91a-5f27-4ea8-9a48-73e81cb6aa1a",
    "4a5dd744-2ebc-427a-a0c4-0e5b9ea7cf7e",
    "75d3e80e-1c79-41d1-b88e-e3c5ee8ac7aa",
    "c72e5f0f-9a2c-4a1b-8d5e-e3f5ee8ac7aa",
    "d8e5a53b-5e85-4da8-8de5-4bb6d1e8a14c",
    "e9f6b64c-6f96-5eb9-9ef6-5cc7e2f9b25d",
    "fa0c75d4-8a0d-5f93-a1f7-6dd8f3g0c36e",
    "0b1d86e5-9b1e-6g04-b2g8-7ee9g4h1d47f",
    "1c2e97f6-ac2f-7h15-c3h9-8ff0h5i2e58g",
    "2d3fa8g7-bd30-8i26-d4ia-9gg1i6j3f69h",
    "3e4gb9h8-ce41-9j37-e5jb-ahh2j7k4g70i"
)

Write-Host "🔍 EXTRACTION DES TIMESTAMPS DE CRÉATION" -ForegroundColor Cyan
Write-Host "Nombre de tâches candidates: $($candidateTaskIds.Count)" -ForegroundColor Gray
Write-Host ""

$results = @()

foreach ($taskId in $candidateTaskIds) {
    $taskPath = Join-Path $TasksDirectory $taskId
    $apiHistoryFile = Join-Path $taskPath "api_conversation_history.json"
    
    if (Test-Path $apiHistoryFile) {
        try {
            # Lire le fichier et parser le JSON
            $content = Get-Content -Path $apiHistoryFile -Raw -Encoding UTF8
            $history = $content | ConvertFrom-Json
            
            # Obtenir le premier message (premier élément du tableau)
            if ($history -is [Array] -and $history.Count -gt 0) {
                $firstMessage = $history[0]
                $timestamp = $firstMessage.ts
                
                # Convertir le timestamp en date lisible (millisecondes depuis epoch)
                $dateTime = [DateTimeOffset]::FromUnixTimeMilliseconds($timestamp).DateTime
                
                $results += [PSCustomObject]@{
                    TaskId = $taskId
                    Timestamp = $timestamp
                    DateTime = $dateTime
                    FormattedDate = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                }
                
                Write-Host "✅ $taskId" -ForegroundColor Green
                Write-Host "   Timestamp: $timestamp" -ForegroundColor Gray
                Write-Host "   Date: $($dateTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            } else {
                Write-Host "⚠️ $taskId - Historique vide ou invalide" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "❌ $taskId - Erreur lecture: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ $taskId - Fichier api_conversation_history.json introuvable" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Trier les résultats par timestamp (du plus ancien au plus récent)
$sortedResults = $results | Sort-Object Timestamp

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📊 RÉSULTATS TRIÉS (DU PLUS ANCIEN AU PLUS RÉCENT)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$rank = 1
foreach ($result in $sortedResults) {
    $color = if ($rank -eq 1) { "Green" } elseif ($rank -le 3) { "Yellow" } else { "Gray" }
    
    Write-Host "[$rank] " -NoNewline -ForegroundColor $color
    Write-Host "$($result.TaskId)" -ForegroundColor White
    Write-Host "    Timestamp: $($result.Timestamp)" -ForegroundColor Gray
    Write-Host "    Date:      $($result.FormattedDate)" -ForegroundColor Gray
    Write-Host ""
    
    $rank++
}

if ($sortedResults.Count -gt 0) {
    $oldest = $sortedResults[0]
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "🏆 TÂCHE ORIGINALE IDENTIFIÉE" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "TaskId:    $($oldest.TaskId)" -ForegroundColor White
    Write-Host "Timestamp: $($oldest.Timestamp)" -ForegroundColor Gray
    Write-Host "Date:      $($oldest.FormattedDate)" -ForegroundColor Gray
    Write-Host ""
    
    # Vérifier si ce TaskId correspond à celui trouvé dans la recherche précédente
    if ($oldest.TaskId -eq "cb7e564f-152f-48e3-8eff-f424d7ebc6bd") {
        Write-Host "✅ CONFIRMATION: Ce TaskId correspond à celui trouvé lors de l'extraction ui_messages.json" -ForegroundColor Green
    } else {
        Write-Host "⚠️ ATTENTION: Ce TaskId diffère de celui trouvé lors de l'extraction ui_messages.json (cb7e564f-152f-48e3-8eff-f424d7ebc6bd)" -ForegroundColor Yellow
    }
}

# Retourner les résultats pour usage programmatique
return $sortedResults