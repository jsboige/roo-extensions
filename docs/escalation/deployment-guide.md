# Guide de Déploiement de la Configuration Recommandée

## Introduction

Ce guide détaille les étapes nécessaires pour déployer la configuration d'escalade recommandée suite à l'analyse comparative des trois configurations testées ("Test Escalade Qwen", "Test Escalade Qwen Avancé" et "Test Escalade Mixte"). La configuration recommandée vise à optimiser l'équilibre entre qualité des réponses, temps de réponse et comportement d'escalade approprié pour chaque mode.

## Prérequis

- Accès administrateur à l'environnement Roo
- PowerShell 5.1 ou supérieur
- Accès aux modèles Qwen et Claude spécifiés dans la configuration
- Droits de modification des fichiers de configuration de Roo

## Étapes de Déploiement

### 1. Sauvegarde des Configurations Existantes

Avant toute modification, créez une sauvegarde des configurations actuelles :

```powershell
# Créer un dossier de sauvegarde avec horodatage
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = ".\roo-config\backups\$timestamp"
New-Item -Path $backupDir -ItemType Directory -Force

# Copier les fichiers de configuration existants
Copy-Item -Path ".\roo-config\settings\modes.json" -Destination "$backupDir\modes.json"
Copy-Item -Path ".\roo-config\settings\settings.json" -Destination "$backupDir\settings.json"
Copy-Item -Path ".\roo-config\settings\servers.json" -Destination "$backupDir\servers.json"

Write-Host "Sauvegarde des configurations créée dans $backupDir" -ForegroundColor Green
```

### 2. Génération de la Configuration Recommandée

Exécutez le script d'analyse et de génération de recommandations :

```powershell
.\generate-recommendation.ps1
```

Ce script analysera les résultats des tests et générera le fichier `recommended-config.json` contenant la configuration optimale.

### 3. Application de la Configuration Recommandée

Utilisez le script suivant pour appliquer la configuration recommandée :

```powershell
# Script d'application de la configuration recommandée
$recommendedConfig = Get-Content -Path ".\recommended-config.json" | ConvertFrom-Json
$modesConfig = Get-Content -Path ".\roo-config\settings\modes.json" | ConvertFrom-Json

# Mise à jour des modèles pour chaque mode
foreach ($mode in $recommendedConfig.models.PSObject.Properties) {
    $modeName = $mode.Name
    $modelName = $mode.Value
    
    # Recherche du mode correspondant dans la configuration
    $targetMode = $modesConfig.modes | Where-Object { $_.slug -eq $modeName.ToLower() }
    
    if ($targetMode) {
        Write-Host "Mise à jour du modèle pour $modeName : $modelName" -ForegroundColor Cyan
        $targetMode.model = $modelName
    }
}

# Mise à jour des seuils d'escalade
foreach ($threshold in $recommendedConfig.escalationThresholds.PSObject.Properties) {
    $modeName = $threshold.Name
    $thresholdValue = $threshold.Value
    
    # Recherche du mode correspondant dans la configuration
    $targetMode = $modesConfig.modes | Where-Object { $_.slug -eq $modeName.ToLower() }
    
    if ($targetMode -and ($targetMode.PSObject.Properties.Name -contains "escalationThreshold")) {
        Write-Host "Mise à jour du seuil d'escalade pour $modeName : $thresholdValue" -ForegroundColor Cyan
        $targetMode.escalationThreshold = $thresholdValue
    }
    elseif ($targetMode) {
        Write-Host "Ajout du seuil d'escalade pour $modeName : $thresholdValue" -ForegroundColor Cyan
        Add-Member -InputObject $targetMode -MemberType NoteProperty -Name "escalationThreshold" -Value $thresholdValue
    }
}

# Mise à jour des seuils d'escalade interne
foreach ($threshold in $recommendedConfig.internalEscalationThresholds.PSObject.Properties) {
    $modeName = $threshold.Name
    $thresholdValue = $threshold.Value
    
    # Recherche du mode correspondant dans la configuration
    $targetMode = $modesConfig.modes | Where-Object { $_.slug -eq $modeName.ToLower() }
    
    if ($targetMode -and ($targetMode.PSObject.Properties.Name -contains "internalEscalationThreshold")) {
        Write-Host "Mise à jour du seuil d'escalade interne pour $modeName : $thresholdValue" -ForegroundColor Cyan
        $targetMode.internalEscalationThreshold = $thresholdValue
    }
    elseif ($targetMode) {
        Write-Host "Ajout du seuil d'escalade interne pour $modeName : $thresholdValue" -ForegroundColor Cyan
        Add-Member -InputObject $targetMode -MemberType NoteProperty -Name "internalEscalationThreshold" -Value $thresholdValue
    }
}

# Ajout des critères d'escalade personnalisés
foreach ($mode in $recommendedConfig.customEscalationCriteria.PSObject.Properties) {
    $modeName = $mode.Name
    $criteria = $mode.Value
    
    # Recherche du mode correspondant dans la configuration
    $targetMode = $modesConfig.modes | Where-Object { $_.slug -eq $modeName.ToLower() }
    
    if ($targetMode -and ($targetMode.PSObject.Properties.Name -contains "escalationCriteria")) {
        Write-Host "Mise à jour des critères d'escalade pour $modeName" -ForegroundColor Cyan
        $targetMode.escalationCriteria = $criteria
    }
    elseif ($targetMode) {
        Write-Host "Ajout des critères d'escalade pour $modeName" -ForegroundColor Cyan
        Add-Member -InputObject $targetMode -MemberType NoteProperty -Name "escalationCriteria" -Value $criteria
    }
}

# Sauvegarde de la configuration mise à jour
$modesConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath ".\roo-config\settings\modes.json" -Encoding utf8

Write-Host "Configuration mise à jour avec succès" -ForegroundColor Green
```

### 4. Vérification de la Configuration

Après l'application de la configuration, vérifiez que les modifications ont été correctement appliquées :

```powershell
# Vérification des modèles configurés
$modesConfig = Get-Content -Path ".\roo-config\settings\modes.json" | ConvertFrom-Json
$recommendedConfig = Get-Content -Path ".\recommended-config.json" | ConvertFrom-Json

Write-Host "Vérification des modèles configurés:" -ForegroundColor Cyan
foreach ($mode in $recommendedConfig.models.PSObject.Properties) {
    $modeName = $mode.Name
    $expectedModel = $mode.Value
    
    $targetMode = $modesConfig.modes | Where-Object { $_.slug -eq $modeName.ToLower() }
    
    if ($targetMode -and $targetMode.model -eq $expectedModel) {
        Write-Host "✅ $modeName : $expectedModel" -ForegroundColor Green
    }
    else {
        Write-Host "❌ $modeName : Attendu=$expectedModel, Actuel=$($targetMode.model)" -ForegroundColor Red
    }
}
```

### 5. Redémarrage des Services

Redémarrez les services Roo pour appliquer les modifications :

```powershell
# Redémarrage des services Roo
Write-Host "Redémarrage des services Roo..." -ForegroundColor Cyan

# Commande spécifique à votre environnement pour redémarrer les services
# Exemple : Restart-Service RooService

Write-Host "Services redémarrés avec succès" -ForegroundColor Green
```

## Ajustement des Seuils d'Escalade

Les seuils d'escalade recommandés sont basés sur l'analyse des tests effectués. Cependant, vous pourriez avoir besoin de les ajuster en fonction des retours utilisateurs ou de cas d'usage spécifiques.

### Ajustement Manuel des Seuils

Pour ajuster manuellement les seuils d'escalade :

1. Ouvrez le fichier `.\roo-config\settings\modes.json`
2. Localisez le mode que vous souhaitez ajuster
3. Modifiez les valeurs des propriétés suivantes :
   - `escalationThreshold` : Seuil pour l'escalade externe (vers un mode complexe)
   - `internalEscalationThreshold` : Seuil pour l'escalade interne (utilisation de plus de ressources)

Exemple d'ajustement pour le mode Code Simple :

```json
{
  "slug": "code-simple",
  "name": "💻 Code Simple",
  "model": "qwen/qwen3-14b",
  "escalationThreshold": 0.80,  // Augmenté de 0.75 à 0.80
  "internalEscalationThreshold": 0.65  // Augmenté de 0.60 à 0.65
}
```

### Recommandations pour l'Ajustement des Seuils

- **Augmenter le seuil** si vous observez trop d'escalades inutiles
- **Diminuer le seuil** si vous observez que des tâches complexes ne sont pas escaladées correctement
- Ajustez par incréments de 0.05 et testez après chaque modification
- Gardez toujours `internalEscalationThreshold` < `escalationThreshold`

## Surveillance et Évaluation des Performances

### Métriques à Surveiller

Pour évaluer l'efficacité de la configuration déployée, surveillez les métriques suivantes :

1. **Taux d'escalade** : Pourcentage de requêtes qui déclenchent une escalade
2. **Temps de réponse** : Temps moyen pour obtenir une réponse
3. **Satisfaction utilisateur** : Retours qualitatifs sur la pertinence des réponses
4. **Coût d'utilisation** : Consommation de tokens et coût associé

### Mise en Place d'un Système de Surveillance

Créez un script de surveillance pour collecter ces métriques :

```powershell
# Script de surveillance des performances d'escalade
$logDir = ".\logs\escalation"
$metricsFile = "$logDir\metrics-$(Get-Date -Format 'yyyyMMdd').csv"

# Création du répertoire de logs si nécessaire
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force
}

# Initialisation du fichier de métriques s'il n'existe pas
if (-not (Test-Path -Path $metricsFile)) {
    "Timestamp,Mode,TaskType,EscalationType,ResponseTime,TokensUsed,Cost" | Out-File -FilePath $metricsFile -Encoding utf8
}

# Fonction pour enregistrer une métrique
function Log-EscalationMetric {
    param (
        [string]$Mode,
        [string]$TaskType,
        [string]$EscalationType,
        [int]$ResponseTime,
        [int]$TokensUsed,
        [double]$Cost
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp,$Mode,$TaskType,$EscalationType,$ResponseTime,$TokensUsed,$Cost" | Out-File -FilePath $metricsFile -Append -Encoding utf8
}

# Exemple d'utilisation
# Log-EscalationMetric -Mode "CodeSimple" -TaskType "Complex" -EscalationType "External" -ResponseTime 8 -TokensUsed 1200 -Cost 0.024
```

### Analyse Périodique des Performances

Planifiez une analyse hebdomadaire des métriques collectées :

```powershell
# Script d'analyse hebdomadaire des performances
$logDir = ".\logs\escalation"
$weekStart = (Get-Date).AddDays(-7).ToString("yyyyMMdd")
$weekEnd = (Get-Date).ToString("yyyyMMdd")
$reportFile = "$logDir\weekly-report-$weekStart-$weekEnd.md"

# Collecte des métriques de la semaine
$weeklyMetrics = Get-ChildItem -Path $logDir -Filter "metrics-*.csv" | 
    Where-Object { $_.BaseName -ge "metrics-$weekStart" -and $_.BaseName -le "metrics-$weekEnd" } |
    Get-Content | 
    ConvertFrom-Csv

# Analyse des métriques
$totalRequests = $weeklyMetrics.Count
$externalEscalations = ($weeklyMetrics | Where-Object { $_.EscalationType -eq "External" }).Count
$internalEscalations = ($weeklyMetrics | Where-Object { $_.EscalationType -eq "Internal" }).Count
$noEscalations = ($weeklyMetrics | Where-Object { $_.EscalationType -eq "None" }).Count

$externalEscalationRate = [math]::Round(($externalEscalations / $totalRequests) * 100, 2)
$internalEscalationRate = [math]::Round(($internalEscalations / $totalRequests) * 100, 2)
$noEscalationRate = [math]::Round(($noEscalations / $totalRequests) * 100, 2)

$avgResponseTime = [math]::Round(($weeklyMetrics | Measure-Object -Property ResponseTime -Average).Average, 2)
$totalCost = [math]::Round(($weeklyMetrics | Measure-Object -Property Cost -Sum).Sum, 2)

# Génération du rapport
$report = @"
# Rapport Hebdomadaire des Performances d'Escalade
## Période: $weekStart au $weekEnd

### Statistiques Globales
- **Nombre total de requêtes**: $totalRequests
- **Temps de réponse moyen**: $avgResponseTime ms
- **Coût total**: $totalCost $

### Comportements d'Escalade
- **Escalades externes**: $externalEscalations ($externalEscalationRate%)
- **Escalades internes**: $internalEscalations ($internalEscalationRate%)
- **Sans escalade**: $noEscalations ($noEscalationRate%)

### Analyse par Mode
"@

# Analyse par mode
$modes = $weeklyMetrics | Select-Object -Property Mode -Unique

foreach ($mode in $modes.Mode) {
    $modeMetrics = $weeklyMetrics | Where-Object { $_.Mode -eq $mode }
    $modeRequests = $modeMetrics.Count
    $modeExternalEscalations = ($modeMetrics | Where-Object { $_.EscalationType -eq "External" }).Count
    $modeInternalEscalations = ($modeMetrics | Where-Object { $_.EscalationType -eq "Internal" }).Count
    $modeNoEscalations = ($modeMetrics | Where-Object { $_.EscalationType -eq "None" }).Count
    
    $modeExternalEscalationRate = [math]::Round(($modeExternalEscalations / $modeRequests) * 100, 2)
    $modeInternalEscalationRate = [math]::Round(($modeInternalEscalations / $modeRequests) * 100, 2)
    $modeNoEscalationRate = [math]::Round(($modeNoEscalations / $modeRequests) * 100, 2)
    
    $modeAvgResponseTime = [math]::Round(($modeMetrics | Measure-Object -Property ResponseTime -Average).Average, 2)
    $modeTotalCost = [math]::Round(($modeMetrics | Measure-Object -Property Cost -Sum).Sum, 2)
    
    $report += @"

#### $mode
- **Nombre de requêtes**: $modeRequests
- **Temps de réponse moyen**: $modeAvgResponseTime ms
- **Coût total**: $modeTotalCost $
- **Taux d'escalade externe**: $modeExternalEscalationRate%
- **Taux d'escalade interne**: $modeInternalEscalationRate%
- **Taux sans escalade**: $modeNoEscalationRate%
"@
}

# Recommandations basées sur l'analyse
$report += @"

### Recommandations
"@

if ($externalEscalationRate -gt 40) {
    $report += @"
- **Ajustement des seuils d'escalade externe**: Le taux d'escalade externe est élevé ($externalEscalationRate%). Envisagez d'augmenter les seuils d'escalade ou d'utiliser des modèles plus puissants pour les modes simples.
"@
}

if ($internalEscalationRate -lt 10) {
    $report += @"
- **Optimisation de l'escalade interne**: Le taux d'escalade interne est faible ($internalEscalationRate%). Envisagez de réduire les seuils d'escalade interne pour mieux utiliser les ressources disponibles.
"@
}

if ($avgResponseTime -gt 15) {
    $report += @"
- **Amélioration des temps de réponse**: Le temps de réponse moyen est élevé ($avgResponseTime ms). Envisagez d'utiliser des modèles plus légers pour les tâches simples ou d'optimiser les prompts.
"@
}

# Sauvegarde du rapport
$report | Out-File -FilePath $reportFile -Encoding utf8

Write-Host "Rapport hebdomadaire généré: $reportFile" -ForegroundColor Green
```

## Résolution des Problèmes Courants

### Problème 1: Taux d'Escalade Trop Élevé

**Symptômes:**
- Plus de 50% des requêtes sont escaladées vers des modes complexes
- Les utilisateurs rapportent des changements de mode fréquents

**Solutions:**
1. Augmentez les seuils d'escalade externe pour les modes concernés
2. Vérifiez que les modèles simples sont correctement configurés
3. Ajustez les critères d'escalade personnalisés pour être moins sensibles

### Problème 2: Temps de Réponse Trop Longs

**Symptômes:**
- Les utilisateurs rapportent des délais d'attente importants
- Les temps de réponse moyens dépassent 20 secondes

**Solutions:**
1. Utilisez des modèles plus légers pour les modes simples
2. Réduisez les seuils d'escalade pour permettre une transition plus rapide vers des modèles optimisés
3. Optimisez les prompts pour réduire la taille des entrées

### Problème 3: Qualité des Réponses Insuffisante

**Symptômes:**
- Les utilisateurs rapportent des réponses incomplètes ou incorrectes
- Taux élevé de reformulations des questions

**Solutions:**
1. Réduisez les seuils d'escalade pour permettre plus facilement le passage à des modèles plus puissants
2. Utilisez des modèles plus puissants pour les modes simples
3. Ajustez les critères d'escalade personnalisés pour mieux détecter les tâches complexes

### Problème 4: Coûts d'Utilisation Élevés

**Symptômes:**
- Augmentation significative des coûts d'API
- Utilisation excessive des modèles complexes

**Solutions:**
1. Augmentez les seuils d'escalade pour limiter le recours aux modèles complexes
2. Utilisez des modèles intermédiaires pour certains modes simples
3. Implémentez une stratégie de mise en cache pour les requêtes fréquentes

## Conclusion

Ce guide de déploiement vous a fourni les étapes nécessaires pour mettre en place la configuration d'escalade recommandée, ainsi que des conseils pour l'ajuster, la surveiller et résoudre les problèmes courants.

La configuration recommandée représente un point de départ optimisé basé sur l'analyse des tests effectués, mais elle devra probablement être affinée en fonction de vos cas d'usage spécifiques et des retours utilisateurs.

N'hésitez pas à consulter le rapport final de comparaison (`final-comparison-report.md`) pour comprendre les raisons derrière les choix de configuration recommandés.

---

*Document généré le 16/05/2025*