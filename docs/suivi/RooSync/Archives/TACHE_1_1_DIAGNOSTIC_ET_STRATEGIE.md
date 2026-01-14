# Tâche 1.1: Diagnostic et Stratégie de Correction - Get-MachineInventory.ps1

## Version: 1.0.0
## Date de création: 2026-01-03
## Auteur: Roo Debug Mode

---

## 1. Diagnostic du Problème

### 1.1 Symptôme
Le script [`Get-MachineInventory.ps1`](../../scripts/inventory/Get-MachineInventory.ps1:1) provoque des gels d'environnement sur myia-po-2026 lors de l'exécution.

### 1.2 Point de blocage identifié
Le script bloque à l'étape "Sauvegarde de l'inventaire..." lors de l'exécution de la ligne 240 :

```powershell
$inventory | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
```

### 1.3 Test effectué
- **Commande exécutée** : `.\scripts\inventory\Get-MachineInventory.ps1 -MachineId 'test-debug' -Verbose`
- **Durée** : > 12 minutes (toujours en cours)
- **Dernière sortie** : "Écriture du fichier: C:\dev\roo-extensions\RooSync\shared\myia-po-2023\inventories\machine-inventory-test-debug.json"
- **Conclusion** : Le script bloque lors de la sérialisation/écriture JSON

---

## 2. Analyse des Causes Possibles

### 2.1 Sources potentielles du freeze

| # | Source | Probabilité | Description |
|---|--------|-------------|-------------|
| 1 | **Sérialisation JSON trop profonde** | 🔴 **ÉLEVÉE** | `-Depth 10` sur un objet volumineux peut prendre un temps exponentiel |
| 2 | **Objet `$inventory` trop grand** | 🔴 **ÉLEVÉE** | La collecte récursive des scripts peut créer un objet massif |
| 3 | **Problème d'encodage** | 🟡 MOYENNE | L'écriture du fichier peut bloquer sur certains caractères |
| 4 | **Problème de permissions** | 🟢 FAIBLE | Le chemin de sortie peut être inaccessible (mais message d'erreur attendu) |
| 5 | **Problème de verrouillage** | 🟢 FAIBLE | Un autre processus peut verrouiller le fichier (mais message d'erreur attendu) |

### 2.2 Sources les plus probables

1. **Sérialisation JSON trop profonde** (Probabilité: 80%)
   - L'objet `$inventory` contient des milliers de scripts collectés récursivement
   - `-Depth 10` force PowerShell à parcourir toute la structure
   - La complexité temporelle de la sérialisation peut être O(n^d) où n est la taille et d la profondeur

2. **Objet `$inventory` trop grand** (Probabilité: 70%)
   - La commande `Get-ChildItem -Path $dir.FullName -Filter "*.ps1" -Recurse` peut scanner des milliers de fichiers
   - Chaque script est ajouté à l'objet `$inventory`
   - L'objet final peut contenir des dizaines de milliers de propriétés

---

## 3. Stratégie de Correction

### 3.1 Objectifs
1. Éliminer le freeze lors de la sérialisation JSON
2. Maintenir la fonctionnalité complète de collecte d'inventaire
3. Améliorer la performance globale du script
4. Ajouter des timeouts pour éviter les blocages infinis

### 3.2 Approche proposée

#### Correction 1: Réduire la profondeur de sérialisation
```powershell
# AVANT (ligne 240):
$inventory | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

# APRÈS:
$inventory | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $OutputPath -Encoding UTF8
```

**Justification** :
- `-Depth 5` est suffisant pour la structure de l'inventaire
- `-Compress` réduit la taille du fichier et accélère l'écriture
- La plupart des données sont à une profondeur de 3-4 niveaux

#### Correction 2: Limiter la collecte récursive
```powershell
# AVANT (ligne 180):
$scripts = Get-ChildItem -Path $dir.FullName -Filter "*.ps1" -Recurse

# APRÈS:
$scripts = Get-ChildItem -Path $dir.FullName -Filter "*.ps1" -Recurse -Depth 3
```

**Justification** :
- Limite la profondeur de recherche à 3 niveaux
- Évite de scanner des milliers de fichiers inutiles
- La plupart des scripts sont dans les 3 premiers niveaux

#### Correction 3: Ajouter des timeouts
```powershell
# Ajouter au début du script:
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Wrapper avec timeout pour les opérations critiques
$job = Start-Job -ScriptBlock {
    param($inventory, $OutputPath)
    $inventory | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $OutputPath -Encoding UTF8
} -ArgumentList $inventory, $OutputPath

if (-not (Wait-Job $job -Timeout 60)) {
    Stop-Job $job
    Write-Error "Timeout lors de la sauvegarde de l'inventaire"
    exit 1
}

$job | Remove-Job
```

**Justification** :
- Évite les blocages infinis
- Timeout de 60 secondes pour la sérialisation
- Nettoyage propre du job en cas de timeout

#### Correction 4: Améliorer la gestion des erreurs
```powershell
# Ajouter des logs de progression
Write-Host "  Sérialisation JSON en cours..." -ForegroundColor Gray
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    $inventory | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $OutputPath -Encoding UTF8
    $stopwatch.Stop()
    Write-Host "  Sérialisation terminée en $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Green
} catch {
    $stopwatch.Stop()
    Write-Host "  Erreur lors de la sérialisation: $_" -ForegroundColor Red
    Write-Host "  Temps écoulé avant erreur: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Yellow
    exit 1
}
```

**Justification** :
- Permet de diagnostiquer les problèmes futurs
- Mesure le temps réel de sérialisation
- Fournit des informations détaillées en cas d'erreur

### 3.3 Plan d'implémentation

1. **Phase 1: Diagnostic approfondi**
   - Mesurer la taille de l'objet `$inventory`
   - Identifier les sections les plus volumineuses
   - Tester différentes profondeurs de sérialisation

2. **Phase 2: Implémentation des corrections**
   - Appliquer Correction 1 (réduire la profondeur)
   - Appliquer Correction 2 (limiter la récursion)
   - Appliquer Correction 3 (ajouter des timeouts)
   - Appliquer Correction 4 (améliorer la gestion des erreurs)

3. **Phase 3: Tests et validation**
   - Tester sur myia-po-2026
   - Tester sur myia-po-2023
   - Valider que l'inventaire est complet
   - Mesurer le temps d'exécution

4. **Phase 4: Documentation**
   - Documenter les changements
   - Mettre à jour les commentaires dans le script
   - Créer un guide de dépannage

---

## 4. Risques et Alternatives

### 4.1 Risques identifiés

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Perte de données avec `-Depth 5` | MOYEN | Tester et valider que toutes les données sont présentes |
| Timeout trop court | FAIBLE | Ajuster le timeout en fonction des tests |
| Performance dégradée avec `-Depth 3` | FAIBLE | Utiliser `-Depth 5` comme compromis |

### 4.2 Alternatives

1. **Utiliser `System.Text.Json` au lieu de `ConvertTo-Json`**
   - Plus performant que `ConvertTo-Json`
   - Nécessite .NET Core 3.0+
   - Plus complexe à implémenter

2. **Sauvegarder en plusieurs fichiers**
   - Un fichier par catégorie (MCPs, modes, scripts, etc.)
   - Plus complexe à gérer
   - Nécessite une modification de l'architecture

3. **Utiliser un format binaire (ex: BSON)**
   - Plus rapide à sérialiser
   - Moins lisible pour les humains
   - Nécessite des outils spécifiques

**Alternative recommandée** : Utiliser `System.Text.Json` si les corrections proposées ne suffisent pas.

---

## 5. Critères de Validation

### 5.1 Critères fonctionnels
- ✅ Le script s'exécute sans freeze
- ✅ L'inventaire est collecté correctement
- ✅ Toutes les catégories sont présentes (MCPs, modes, specs, scripts)
- ✅ Le fichier JSON est valide et lisible

### 5.2 Critères de performance
- ✅ Le temps d'exécution est < 5 minutes
- ✅ La sérialisation JSON prend < 60 secondes
- ✅ La taille du fichier JSON est raisonnable (< 10 MB)

### 5.3 Critères de qualité
- ✅ Aucune erreur ou exception n'est levée
- ✅ Les logs de progression sont clairs
- ✅ La gestion des erreurs est robuste

---

## 6. Journal des Modifications

| Date | Modification | Auteur |
|------|--------------|--------|
| 2026-01-03 | Création du document de diagnostic et stratégie | Roo Debug Mode |

---

## 7. Liens

- **Tâche principale**: [`TACHE_1_1_Corriger_Get-MachineInventory.ps1.md`](./TACHE_1_1_Corriger_Get-MachineInventory.ps1.md)
- **Script cible**: [`../../scripts/inventory/Get-MachineInventory.ps1`](../../scripts/inventory/Get-MachineInventory.ps1)
- **Checkpoint**: CP1.1
- **Issue GitHub**: PVTI_lAHOADA1Xc4BLw3wzgjKFM8

---

**Document généré par:** Roo Debug Mode
**Date de génération:** 2026-01-03T23:40:00Z
**Version:** 1.0.0
**Statut:** 🟡 Diagnostic terminé, stratégie définie
