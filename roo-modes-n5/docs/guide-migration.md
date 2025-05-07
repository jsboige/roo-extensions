# Guide de Migration vers l'Architecture d'Orchestration à 5 Niveaux

Ce guide vous accompagne dans la migration de l'architecture existante vers la nouvelle architecture d'orchestration à 5 niveaux de complexité.

## Table des Matières

1. [Introduction](#introduction)
2. [Comparaison des Architectures](#comparaison-des-architectures)
3. [Stratégies de Migration](#stratégies-de-migration)
4. [Migration des Configurations](#migration-des-configurations)
5. [Migration des Scripts](#migration-des-scripts)
6. [Migration des Tests](#migration-des-tests)
7. [Période de Coexistence](#période-de-coexistence)
8. [Vérification Post-Migration](#vérification-post-migration)
9. [Résolution des Problèmes Courants](#résolution-des-problèmes-courants)

## Introduction

La migration vers l'architecture d'orchestration à 5 niveaux offre plusieurs avantages :

- Meilleure granularité dans la gestion de la complexité des tâches
- Optimisation de l'utilisation des ressources
- Mécanismes d'escalade/désescalade plus efficaces
- Utilisation optimisée des MCPs disponibles
- Nettoyage systématique des fichiers intermédiaires

Ce guide vous aide à effectuer cette migration de manière progressive et sécurisée.

## Comparaison des Architectures

### Architecture Existante

L'architecture existante dans `roo-modes/` est basée sur une approche à deux niveaux principaux :
- Modes simples (code-simple, debug-simple, etc.)
- Modes complexes (code-complex, debug-complex, etc.)

### Nouvelle Architecture

La nouvelle architecture dans `roo-modes-n5/` introduit 5 niveaux de complexité :
1. **MICRO** - Pour les tâches très simples et rapides
2. **MINI** - Pour les tâches simples mais nécessitant un peu plus de contexte
3. **MEDIUM** - Pour les tâches de complexité moyenne
4. **LARGE** - Pour les tâches complexes nécessitant une analyse approfondie
5. **ORACLE** - Pour les tâches très complexes nécessitant une expertise avancée

## Stratégies de Migration

Trois stratégies de migration sont possibles :

### 1. Migration Progressive (Recommandée)

- Déployer la nouvelle architecture en parallèle de l'ancienne
- Migrer progressivement les modes un par un
- Tester chaque mode après migration
- Basculer complètement une fois tous les modes migrés

### 2. Migration par Fonctionnalité

- Identifier les fonctionnalités clés
- Migrer chaque fonctionnalité vers la nouvelle architecture
- Tester chaque fonctionnalité après migration
- Basculer complètement une fois toutes les fonctionnalités migrées

### 3. Migration Complète

- Déployer la nouvelle architecture en une seule fois
- Basculer complètement vers la nouvelle architecture
- Conserver l'ancienne architecture comme sauvegarde

## Migration des Configurations

### Étape 1 : Analyse des Configurations Existantes

Analysez les configurations existantes dans `roo-modes/configs/` pour comprendre leur structure et leur contenu.

```powershell
# Exemple de commande pour analyser les configurations existantes
Get-Content -Path "roo-modes/configs/standard-modes.json" | ConvertFrom-Json | Format-List
```

### Étape 2 : Mappage des Modes

Mappez les modes existants vers les nouveaux niveaux de complexité :

| Mode Existant | Nouveau Niveau |
|---------------|---------------|
| code-simple   | MICRO ou MINI |
| code-complex  | LARGE ou ORACLE |
| debug-simple  | MICRO ou MINI |
| debug-complex | LARGE ou ORACLE |
| architect-simple | MINI ou MEDIUM |
| architect-complex | LARGE ou ORACLE |
| ask-simple    | MICRO ou MINI |
| ask-complex   | MEDIUM ou LARGE |
| orchestrator-simple | MINI ou MEDIUM |
| orchestrator-complex | LARGE ou ORACLE |

### Étape 3 : Conversion des Configurations

Convertissez les configurations existantes vers le nouveau format :

1. Extrayez les informations pertinentes des modes existants
2. Adaptez-les au format des nouveaux niveaux de complexité
3. Ajoutez les nouvelles métadonnées spécifiques à chaque niveau

```powershell
# Exemple de script pour convertir une configuration
$existingConfig = Get-Content -Path "roo-modes/configs/standard-modes.json" -Raw | ConvertFrom-Json
$newConfig = @{
    "complexityLevel" = @{
        "level" = 3,
        "name" = "MEDIUM",
        "slug" = "medium",
        # Autres métadonnées...
    },
    "customModes" = @()
}

# Conversion des modes...
# [Code de conversion ici]

$newConfig | ConvertTo-Json -Depth 100 | Set-Content -Path "roo-modes-n5/configs/medium-modes.json"
```

### Étape 4 : Validation des Configurations

Validez les nouvelles configurations pour vous assurer qu'elles sont correctes :

```powershell
# Validation des configurations
Get-Content -Path "roo-modes-n5/configs/medium-modes.json" -Raw | ConvertFrom-Json
```

## Migration des Scripts

### Étape 1 : Analyse des Scripts Existants

Analysez les scripts existants dans `roo-modes/scripts/` pour comprendre leur fonctionnement.

```powershell
# Exemple de commande pour analyser les scripts existants
Get-Content -Path "roo-modes/scripts/deploy-modes.ps1"
```

### Étape 2 : Adaptation des Scripts

Adaptez les scripts existants pour qu'ils fonctionnent avec la nouvelle architecture :

1. Mettez à jour les chemins de fichiers
2. Adaptez la logique de déploiement
3. Ajoutez la gestion des nouveaux niveaux de complexité

```powershell
# Exemple d'adaptation d'un script
$existingScript = Get-Content -Path "roo-modes/scripts/deploy-modes.ps1"
$newScript = $existingScript -replace "roo-modes/configs", "roo-modes-n5/configs"
# Autres adaptations...
$newScript | Set-Content -Path "roo-modes-n5/scripts/deploy.ps1"
```

### Étape 3 : Test des Scripts

Testez les nouveaux scripts pour vous assurer qu'ils fonctionnent correctement :

```powershell
# Test des scripts
./roo-modes-n5/scripts/deploy.ps1 -DryRun
```

## Migration des Tests

### Étape 1 : Analyse des Tests Existants

Analysez les tests existants dans `roo-modes/tests/` pour comprendre leur fonctionnement.

```powershell
# Exemple de commande pour analyser les tests existants
Get-Content -Path "roo-modes/tests/test-escalade.js"
```

### Étape 2 : Adaptation des Tests

Adaptez les tests existants pour qu'ils fonctionnent avec la nouvelle architecture :

1. Mettez à jour les chemins de fichiers
2. Adaptez la logique de test
3. Ajoutez des tests spécifiques aux nouveaux niveaux de complexité

```javascript
// Exemple d'adaptation d'un test
const existingTest = fs.readFileSync("roo-modes/tests/test-escalade.js", "utf8");
const newTest = existingTest.replace("roo-modes/configs", "roo-modes-n5/configs");
// Autres adaptations...
fs.writeFileSync("roo-modes-n5/tests/test-escalade.js", newTest);
```

### Étape 3 : Test des Tests

Testez les nouveaux tests pour vous assurer qu'ils fonctionnent correctement :

```powershell
# Test des tests
node roo-modes-n5/tests/test-escalade.js
```

## Période de Coexistence

Pendant la période de coexistence des deux architectures :

### Configuration de la Coexistence

1. Assurez-vous que les deux architectures peuvent fonctionner en parallèle
2. Évitez les conflits de noms de modes
3. Documentez clairement quelle architecture est utilisée pour chaque tâche

### Gestion des Conflits

En cas de conflit entre les deux architectures :

1. Identifiez la source du conflit
2. Donnez la priorité à l'architecture la plus adaptée à la tâche
3. Documentez la résolution du conflit

## Vérification Post-Migration

Après la migration, effectuez les vérifications suivantes :

### Vérification des Configurations

```powershell
# Vérification des configurations
Get-ChildItem -Path "roo-modes-n5/configs" -Filter "*.json" | ForEach-Object {
    $config = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
    Write-Host "Configuration $($_.Name) : $($config.customModes.Count) modes"
}
```

### Vérification des Scripts

```powershell
# Vérification des scripts
./roo-modes-n5/scripts/deploy.ps1 -Verify
```

### Vérification des Tests

```powershell
# Vérification des tests
node roo-modes-n5/tests/test-escalade.js
node roo-modes-n5/tests/test-desescalade.js
```

## Résolution des Problèmes Courants

### Problème : Modes Manquants

**Symptômes** : Certains modes ne sont pas disponibles après la migration.

**Solution** : Vérifiez que tous les modes ont été correctement mappés et convertis.

```powershell
# Vérification des modes manquants
$existingModes = (Get-Content -Path "roo-modes/configs/standard-modes.json" -Raw | ConvertFrom-Json).customModes.slug
$newModes = @()
Get-ChildItem -Path "roo-modes-n5/configs" -Filter "*.json" | ForEach-Object {
    $config = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
    $newModes += $config.customModes.slug
}
$missingModes = $existingModes | Where-Object { $_ -notin $newModes }
Write-Host "Modes manquants : $missingModes"
```

### Problème : Conflits de Noms

**Symptômes** : Des conflits de noms entre les modes des deux architectures.

**Solution** : Renommez les modes en conflit ou utilisez des préfixes/suffixes pour les distinguer.

```powershell
# Résolution des conflits de noms
$newConfig = Get-Content -Path "roo-modes-n5/configs/medium-modes.json" -Raw | ConvertFrom-Json
foreach ($mode in $newConfig.customModes) {
    if ($mode.slug -in $existingModes) {
        $mode.slug = "n5-" + $mode.slug
        $mode.name = "N5 " + $mode.name
    }
}
$newConfig | ConvertTo-Json -Depth 100 | Set-Content -Path "roo-modes-n5/configs/medium-modes.json"
```

### Problème : Erreurs de Déploiement

**Symptômes** : Erreurs lors du déploiement des nouvelles configurations.

**Solution** : Vérifiez les chemins de fichiers et les permissions.

```powershell
# Vérification des chemins et permissions
Test-Path -Path "$env:APPDATA\Code\User\globalStorage\anthropic.claude\roo"
Get-Acl -Path "$env:APPDATA\Code\User\globalStorage\anthropic.claude\roo"
```

### Problème : Performances Dégradées

**Symptômes** : Performances dégradées après la migration.

**Solution** : Vérifiez que les modes sont correctement mappés aux niveaux de complexité appropriés.

```powershell
# Vérification des mappages de complexité
Get-ChildItem -Path "roo-modes-n5/configs" -Filter "*.json" | ForEach-Object {
    $config = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
    foreach ($mode in $config.customModes) {
        Write-Host "Mode $($mode.slug) : Niveau $($config.complexityLevel.name)"
    }
}