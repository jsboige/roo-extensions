# Script de Diagnostic d'Indexation roo-state-manager
# Date: 2025-11-04 12:30 UTC
# Objectif: Identifier pourquoi les vecteurs ne sont pas indexés dans Qdrant

param(
    [Parameter(Mandatory=$false)]
    [string]$TaskId = $null
)

Write-Host "🔍 DIAGNOSTIC D'INDEXATION ROO-STATE-MANAGER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Configuration
$ErrorActionPreference = "Stop"

# Fonction pour logger avec timestamp
function Log-Message {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "SUCCESS" { "Green" }
        "DEBUG" { "Gray" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Fonction pour tester la connexion OpenAI
function Test-OpenAIConnection {
    try {
        Log-Message "Test de connexion OpenAI..." "DEBUG"
        $openaiKey = $env:OPENAI_API_KEY
        if (-not $openaiKey) {
            Log-Message "OPENAI_API_KEY non définie" "ERROR"
            return $false
        }
        
        $headers = @{
            "Authorization" = "Bearer $openaiKey"
            "Content-Type" = "application/json"
        }
        
        $body = @{
            model = "text-embedding-3-small"
            input = "test embedding"
        } | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/embeddings" -Method Post -Headers $headers -Body $body -TimeoutSec 30
        
        if ($response.StatusCode -eq 200) {
            $data = $response.Content | ConvertFrom-Json
            $vector = $data.data[0].embedding
            Log-Message "✅ Connexion OpenAI OK - Dimension vecteur: $($vector.Length)" "SUCCESS"
            return $true
        } else {
            Log-Message "❌ Échec connexion OpenAI - Status: $($response.StatusCode)" "ERROR"
            Log-Message "Réponse: $($response.Content)" "ERROR"
            return $false
        }
    }
    catch {
        Log-Message "Exception lors du test OpenAI: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Fonction pour tester la connexion Qdrant
function Test-QdrantConnection {
    try {
        Log-Message "Test de connexion Qdrant..." "DEBUG"
        $qdrantUrl = $env:QDRANT_URL
        $qdrantKey = $env:QDRANT_API_KEY
        
        if (-not $qdrantUrl -or -not $qdrantKey) {
            Log-Message "Variables Qdrant non définies" "ERROR"
            return $false
        }
        
        $headers = @{
            "api-key" = $qdrantKey
            "Content-Type" = "application/json"
        }
        
        # Test de connexion via collections
        $response = Invoke-RestMethod -Uri "$qdrantUrl/collections" -Method Get -Headers $headers -TimeoutSec 30
        
        if ($response.StatusCode -eq 200) {
            $data = $response.Content | ConvertFrom-Json
            $collection = $data.collections | Where-Object { $_.name -eq "roo_tasks_semantic_index" }
            
            if ($collection) {
                Log-Message "✅ Connexion Qdrant OK - Collection trouvée" "SUCCESS"
                Log-Message "   Points: $($collection.points_count)" "INFO"
                Log-Message "   Vecteurs: $($collection.vectors_count)" "INFO"
                Log-Message   "Status: $($collection.status)" "INFO"
                return $true
            } else {
                Log-Message "⚠️ Collection roo_tasks_semantic_index non trouvée" "WARN"
                return $false
            }
        } else {
            Log-Message "❌ Échec connexion Qdrant - Status: $($response.StatusCode)" "ERROR"
            return $false
        }
    }
    catch {
        Log-Message "Exception lors du test Qdrant: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Fonction pour tester une indexation complète
function Test-TaskIndexing {
    param([string]$TaskId)
    
    if (-not $TaskId) {
        Log-Message "Aucun TaskId fourni, utilisation d'un test par défaut" "WARN"
        # Chercher une tâche existante
        $storagePath = "$env:USERPROFILE\.roo\storage\tasks"
        if (Test-Path $storagePath) {
            $tasks = Get-ChildItem $storagePath -Directory | Where-Object { $_.Name -ne ".skeletons" } | Select-Object -First 1
            if ($tasks) {
                $TaskId = $tasks.Name
                Log-Message "Utilisation de la tâche: $TaskId" "INFO"
            } else {
                Log-Message "Aucune tâche trouvée pour le test" "ERROR"
                return
            }
        } else {
            Log-Message "Répertoire de stockage Roo non trouvé: $storagePath" "ERROR"
            return
        }
    }
    
    Log-Message "🧪 Test d'indexation pour la tâche: $TaskId" "INFO"
    
    try {
        # Simuler le processus d'indexation
        $taskPath = "$env:USERPROFILE\.roo\storage\tasks\$TaskId"
        
        if (-not (Test-Path $taskPath)) {
            Log-Message "Répertoire de tâche non trouvé: $taskPath" "ERROR"
            return
        }
        
        # Vérifier les fichiers requis
        $apiHistory = "$taskPath\api_conversation_history.json"
        $metadata = "$taskPath\task_metadata.json"
        
        Log-Message "Vérification des fichiers..." "DEBUG"
        Log-Message "   API History: $(if (Test-Path $apiHistory) { '✅' } else { '❌' })" "INFO"
        Log-Message "   Metadata: $(if (Test-Path $metadata) { '✅' } else { '❌' })" "INFO"
        
        if ((Test-Path $apiHistory) -and (Test-Path $metadata)) {
            Log-Message "✅ Fichiers de tâche valides" "SUCCESS"
            
            # Tester l'extraction de chunks
            try {
                $apiContent = Get-Content $apiHistory -Raw | ConvertFrom-Json
                $metadataContent = Get-Content $metadata -Raw | ConvertFrom-Json
                
                Log-Message "   Messages API: $($apiContent.Count)" "INFO"
                Log-Message "   Workspace: $($metadataContent.workspace)" "INFO"
                
                # Simuler la création d'un embedding
                $testText = "Test embedding pour diagnostic"
                Log-Message "Test de génération d'embedding..." "DEBUG"
                
                $openaiKey = $env:OPENAI_API_KEY
                $headers = @{
                    "Authorization" = "Bearer $openaiKey"
                    "Content-Type" = "application/json"
                }
                
                $body = @{
                    model = "text-embedding-3-small"
                    input = $testText
                } | ConvertTo-Json -Depth 10
                
                $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/embeddings" -Method Post -Headers $headers -Body $body -TimeoutSec 30
                
                if ($response.StatusCode -eq 200) {
                    $data = $response.Content | ConvertFrom-Json
                    $vector = $data.data[0].embedding
                    
                    Log-Message "✅ Embedding généré avec succès" "SUCCESS"
                    Log-Message "   Dimension: $($vector.Length)" "INFO"
                    Log-Message "   Premières valeurs: $($vector[0..4] -join ', ')" "DEBUG"
                    
                    # Tester l'insertion dans Qdrant
                    Log-Message "Test d'insertion Qdrant..." "DEBUG"
                    
                    $qdrantUrl = $env:QDRANT_URL
                    $qdrantKey = $env:QDRANT_API_KEY
                    $headers = @{
                        "api-key" = $qdrantKey
                        "Content-Type" = "application/json"
                    }
                    
                    $point = @{
                        id = "test-point-$(Get-Date -Format 'yyyyMMddHHmmss')"
                        vector = $vector
                        payload = @{
                            task_id = $TaskId
                            chunk_type = "test"
                            content = $testText
                            host_os = "diagnostic-script"
                        }
                    } | ConvertTo-Json -Depth 10
                    
                    $qdrantBody = @{
                        points = @($point)
                    } | ConvertTo-Json -Depth 10
                    
                    $qdrantResponse = Invoke-RestMethod -Uri "$qdrantUrl/collections/roo_tasks_semantic_index/points" -Method Put -Headers $headers -Body $qdrantBody -TimeoutSec 30
                    
                    if ($qdrantResponse.StatusCode -eq 200) {
                        Log-Message "✅ Insertion Qdrant réussie" "SUCCESS"
                    } else {
                        Log-Message "❌ Échec insertion Qdrant - Status: $($qdrantResponse.StatusCode)" "ERROR"
                        Log-Message "Réponse: $($qdrantResponse.Content)" "ERROR"
                    }
                } else {
                    Log-Message "❌ Échec génération embedding - Status: $($response.StatusCode)" "ERROR"
                }
            }
            catch {
                Log-Message "Exception lors du test d'indexation: $($_.Exception.Message)" "ERROR"
            }
        } else {
            Log-Message "❌ Fichiers manquants pour l'indexation" "ERROR"
        }
    }
    catch {
        Log-Message "Exception générale: $($_.Exception.Message)" "ERROR"
    }
}

# Exécution des tests
Write-Host "`n🚀 DÉBUT DES TESTS DE DIAGNOSTIC`n" -ForegroundColor Yellow

# Test 1: Variables d'environnement
Log-Message "Vérification des variables d'environnement..." "INFO"
$envVars = @("OPENAI_API_KEY", "QDRANT_URL", "QDRANT_API_KEY", "QDRANT_COLLECTION_NAME")
foreach ($var in $envVars) {
    $value = [Environment]::GetEnvironmentVariable($var)
    if ($value) {
        Log-Message "   $var : ✅ défini" "SUCCESS"
    } else {
        Log-Message "   $var : ❌ manquant" "ERROR"
    }
}

# Test 2: Connexions
Write-Host "`n📡 TEST DES CONNEXIONS`n" -ForegroundColor Yellow
$openaiOk = Test-OpenAIConnection
$qdrantOk = Test-QdrantConnection

if ($openaiOk -and $qdrantOk) {
    Log-Message "✅ Toutes les connexions sont fonctionnelles" "SUCCESS"
} else {
    Log-Message "❌ Problèmes de connexion détectés" "ERROR"
}

# Test 3: Indexation
Write-Host "`n🧪 TEST D'INDEXATION`n" -ForegroundColor Yellow
Test-TaskIndexing -TaskId $TaskId

Write-Host "`n🏁 DIAGNOSTIC TERMINÉ`n" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan