# Script pour tester les scénarios d'escalade entre modes simples et complexes
# Ce script permet de valider les procédures d'escalade fonctionnelle

param (
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "test-results"
)

# Création du répertoire de sortie s'il n'existe pas
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputPath = Join-Path -Path $scriptPath -ChildPath $OutputDir

if (-not (Test-Path $outputPath)) {
    New-Item -Path $outputPath -ItemType Directory | Out-Null
}

# Définition des scénarios de test
$scenarios = @(
    @{
        Name = "Escalade Code Simple vers Complex"
        FromMode = "code-simple"
        ToMode = "code-complex"
        Task = "Implémenter un système de cache distribué avec Redis pour une application web Node.js. Le système doit gérer la synchronisation entre plusieurs instances, la gestion des expirations, et inclure des mécanismes de fallback en cas d'indisponibilité de Redis."
        ExpectedEscalation = $true
        EscalationType = "Externe"
        Reason = "Tâche complexe nécessitant une architecture distribuée"
    },
    @{
        Name = "Escalade Debug Simple vers Complex"
        FromMode = "debug-simple"
        ToMode = "debug-complex"
        Task = "Diagnostiquer un problème de performance dans une application React qui devient lente après plusieurs heures d'utilisation. Les utilisateurs rapportent des fuites mémoire et des ralentissements progressifs, mais le problème n'est pas reproductible facilement en environnement de développement."
        ExpectedEscalation = $true
        EscalationType = "Externe"
        Reason = "Problème complexe de performance avec fuite mémoire"
    },
    @{
        Name = "Escalade Architect Simple vers Complex"
        FromMode = "architect-simple"
        ToMode = "architect-complex"
        Task = "Concevoir une architecture microservices pour une plateforme e-commerce avec haute disponibilité, capable de gérer des pics de trafic saisonniers. L'architecture doit inclure des stratégies de résilience, de mise à l'échelle automatique, et un plan de migration depuis le monolithe existant."
        ExpectedEscalation = $true
        EscalationType = "Externe"
        Reason = "Conception d'architecture distribuée complexe"
    },
    @{
        Name = "Escalade Ask Simple vers Complex"
        FromMode = "ask-simple"
        ToMode = "ask-complex"
        Task = "Comparer en détail les avantages et inconvénients des architectures serverless, microservices et monolithiques pour différents types d'applications. Inclure des considérations de performance, coût, maintenabilité, et évolutivité avec des exemples concrets pour chaque approche."
        ExpectedEscalation = $true
        EscalationType = "Externe"
        Reason = "Analyse comparative complexe nécessitant une synthèse approfondie"
    },
    @{
        Name = "Escalade Orchestrator Simple vers Complex"
        FromMode = "orchestrator-simple"
        ToMode = "orchestrator-complex"
        Task = "Orchestrer le développement d'une application de gestion de projet avec authentification, tableau de bord analytique, et intégration à des services externes. Le projet nécessite la coordination de plusieurs composants interdépendants et un workflow de déploiement continu."
        ExpectedEscalation = $true
        EscalationType = "Externe"
        Reason = "Orchestration complexe avec multiples composants interdépendants"
    },
    @{
        Name = "Escalade Interne Code Simple"
        FromMode = "code-simple"
        ToMode = "code-simple"
        Task = "Implémenter une fonction de validation de formulaire qui vérifie les champs email, téléphone et adresse selon les formats internationaux. L'utilisateur a explicitement demandé de rester en mode simple malgré la complexité modérée de la tâche."
        ExpectedEscalation = $true
        EscalationType = "Interne"
        Reason = "Validation complexe avec formats internationaux mais demande explicite de rester en mode simple"
    },
    @{
        Name = "Pas d'Escalade Code Simple"
        FromMode = "code-simple"
        ToMode = "code-simple"
        Task = "Ajouter une fonction de validation d'email simple à un formulaire HTML existant. La fonction doit vérifier le format basique d'un email et afficher un message d'erreur si le format est incorrect."
        ExpectedEscalation = $false
        EscalationType = "Aucune"
        Reason = "Tâche simple ne nécessitant pas d'escalade"
    }
)

# Fonction pour générer une sous-tâche de test d'escalade
function Generate-EscalationSubtask {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Scenario,
        [Parameter(Mandatory=$true)]
        [string]$ConfigName
    )
    
    $result = [PSCustomObject]@{
        Name = $Scenario.Name
        FromMode = $Scenario.FromMode
        ToMode = $Scenario.ToMode
        Task = $Scenario.Task
        ExpectedEscalation = $Scenario.ExpectedEscalation
        EscalationType = $Scenario.EscalationType
        Reason = $Scenario.Reason
        ConfigName = $ConfigName
        SubtaskId = [guid]::NewGuid().ToString()
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Génération de sous-tâche: $($Scenario.Name)" -ForegroundColor Cyan
    Write-Host "Mode initial: $($Scenario.FromMode)" -ForegroundColor Cyan
    Write-Host "Mode attendu: $($Scenario.ToMode)" -ForegroundColor Cyan
    Write-Host "Escalade attendue: $($Scenario.ExpectedEscalation) ($($Scenario.EscalationType))" -ForegroundColor Cyan
    Write-Host "Configuration: $ConfigName" -ForegroundColor Cyan
    Write-Host "ID de sous-tâche: $($result.SubtaskId)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Création du message de sous-tâche
    $subtaskMessage = @"
# Test d'Escalade: $($Scenario.Name)

## Contexte
- **Configuration**: $ConfigName
- **Mode initial**: $($Scenario.FromMode)
- **Mode attendu**: $($Scenario.ToMode)
- **Escalade attendue**: $($Scenario.ExpectedEscalation) ($($Scenario.EscalationType))
- **ID de sous-tâche**: $($result.SubtaskId)

## Tâche à exécuter
```
$($Scenario.Task)
```

## Instructions
1. Exécutez cette tâche dans le mode $($Scenario.FromMode)
2. Observez si une escalade se produit (et de quel type)
3. Documentez le comportement observé
4. **IMPORTANT**: Mentionnez explicitement dans votre rapport de terminaison:
   - S'il y a eu une escalade (oui/non)
   - Le type d'escalade (Externe/Interne/Aucune)
   - Le temps approximatif avant l'escalade
   - Le message d'escalade exact (si applicable)
   - Toute observation pertinente sur le comportement d'escalade

Votre rapport sera utilisé pour évaluer l'efficacité de la configuration "$ConfigName" pour les décisions d'escalade.
"@

    # Affichage de la sous-tâche
    Write-Host "Sous-tâche générée:" -ForegroundColor Yellow
    Write-Host $subtaskMessage -ForegroundColor White
    
    # Sauvegarde de la sous-tâche dans un fichier
    $subtaskFileName = "subtask-$($result.SubtaskId.Substring(0, 8)).md"
    $subtaskFilePath = Join-Path -Path $outputPath -ChildPath $subtaskFileName
    $subtaskMessage | Set-Content -Path $subtaskFilePath
    
    Write-Host "`nSous-tâche sauvegardée dans: $subtaskFilePath" -ForegroundColor Green
    
    return $result
}

# Génération des sous-tâches
$configName = Read-Host "Entrez le nom de la configuration de test (ex: Test Escalade Mixte)"

$results = @()
foreach ($scenario in $scenarios) {
    $subtaskResult = Generate-EscalationSubtask -Scenario $scenario -ConfigName $configName
    $results += $subtaskResult
}

# Génération du rapport
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$subtasksListPath = Join-Path -Path $outputPath -ChildPath "subtasks-list-$timestamp.json"
$subtasksReadmePath = Join-Path -Path $outputPath -ChildPath "README-subtasks-$timestamp.md"

# Sauvegarde de la liste des sous-tâches en JSON
$results | ConvertTo-Json -Depth 5 | Set-Content -Path $subtasksListPath

# Génération du README pour les sous-tâches
$readmeContent = @"
# Tests d'Escalade - Sous-tâches

## Configuration: $configName
Date de génération: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Liste des Sous-tâches

| ID | Scénario | Mode Initial | Mode Attendu | Escalade Attendue |
|----|----------|--------------|--------------|-------------------|
$(foreach ($result in $results) {
    "| $($result.SubtaskId.Substring(0, 8)) | $($result.Name) | $($result.FromMode) | $($result.ToMode) | $($result.ExpectedEscalation) ($($result.EscalationType)) |"
})

## Instructions pour l'Analyse des Résultats

1. Exécutez chaque sous-tâche individuellement
2. Collectez les résultats de chaque test, en particulier les informations sur l'escalade
3. Utilisez le script d'analyse `analyze-test-results.ps1` pour comparer les résultats avec les configurations précédentes
4. Mettez à jour le rapport comparatif `comparison-report.md` avec les nouvelles données

## Fichiers de Sous-tâches

$(foreach ($result in $results) {
    $subtaskFileName = "subtask-$($result.SubtaskId.Substring(0, 8)).md"
    "- [$($result.Name)]($subtaskFileName)"
})

"@

$readmeContent | Set-Content -Path $subtasksReadmePath

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Résumé de la génération de sous-tâches" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total des sous-tâches générées: $($results.Count)" -ForegroundColor White
Write-Host "`nListe des sous-tâches sauvegardée: $subtasksListPath" -ForegroundColor Yellow
Write-Host "README des sous-tâches sauvegardé: $subtasksReadmePath" -ForegroundColor Yellow

# Ouverture du README des sous-tâches
Invoke-Item $subtasksReadmePath

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "INSTRUCTIONS POUR LES TESTS D'ESCALADE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "1. Créez une nouvelle tâche pour chaque sous-tâche générée" -ForegroundColor White
Write-Host "2. Exécutez la tâche dans le mode spécifié et observez le comportement d'escalade" -ForegroundColor White
Write-Host "3. Documentez les résultats en mentionnant explicitement les informations d'escalade" -ForegroundColor White
Write-Host "4. Utilisez le script d'analyse pour comparer les résultats avec les configurations précédentes" -ForegroundColor White
Write-Host "5. Mettez à jour le rapport comparatif avec les nouvelles données" -ForegroundColor White