# Conception : Roadmap Consciente du Contexte (Context-Aware Roadmap)

**Projet :** RUSH-SYNC  
**Framework :** SDDD (Semantic-Documentation-Driven-Design)  
**Date :** 2025-08-01 
**Version :** 1.0
**Auteur :** Roo, Architecte

---

## 1. Résumé Exécutif

Ce document de conception a pour objectif de faire évoluer le système de `sync-roadmap.md` pour le rendre conscient du contexte d'exécution. Actuellement, les décisions de la roadmap sont générées avec des informations minimales. L'objectif est d'enrichir chaque décision avec les métadonnées contextuelles collectées par la fonction `Get-LocalContext`, améliorant ainsi la traçabilité, le diagnostic et la fiabilité du système de synchronisation.

Ce document détaille le nouveau format de la roadmap et les modifications de code nécessaires pour l'implémenter.

## 2. Analyse de l'Existant

*   **Point d'injection identifié :** La fonction `Compare-Config` dans le module `modules/Actions.psm1` est responsable de la génération des blocs de décision dans `sync-roadmap.md`.
*   **Orchestration :** Le script `sync-manager.ps1` est l'orchestrateur principal. Il appelle les actions définies dans les modules.
*   **Collecte de contexte :** Le `sync-manager.ps1` appelle déjà la fonction `Get-LocalContext` et stocke le résultat dans la variable `$localContext`. Cependant, cette variable n'est pas encore passée aux fonctions d'action comme `Compare-Config`.

## 3. Nouveau Format de Bloc de Décision

Pour lier chaque décision à son contexte, le format du bloc de décision dans `sync-roadmap.md` sera étendu comme suit. Ce format utilise une structure clé-valeur claire pour une meilleure lisibilité et un parsing automatisé facilité.

```markdown
### DECISION ID: <UUID>
- **Status:** PENDING
- **Machine:** [Nom de la machine, e.g., DESKTOP-ROO]
- **Timestamp (UTC):** [Timestamp ISO 8601]
- **Source Action:** [Nom de l'action, e.g., Compare-Config]
- **Details:** [Description de la divergence ou de l'action]
- **Diff:**
  ```diff
  ... (contenu du diff, si applicable) ...
  ```
- **Contexte d'Exécution:**
  ```json
  {
    "computerInfo": {
      "osName": "Microsoft Windows 11 Pro",
      "computerName": "DESKTOP-ROO",
      "manufacturer": "ROO Corp",
      "model": "System Product Name"
    },
    "powershell": {
      "version": "7.4.2",
      "edition": "Core"
    },
    "rooEnvironment": {
        "mcps": ["filesystem", "searxng"],
        "modes": ["code", "architect"]
    }
  }
  ```

**Champs Clés :**
*   `DECISION ID`: Un identifiant unique (un `[guid]::NewGuid()` en PowerShell) pour chaque décision, permettant un suivi précis.
*   `Status`: L'état de la décision (PENDING, APPROVED, REJECTED, APPLIED). Initialisé à `PENDING`.
*   `Machine`: Le nom de la machine où la décision a été générée (`$localContext.computerInfo.CsName`).
*   `Timestamp (UTC)`: La date et l'heure exactes de la génération (`$localContext.timestamp`).
*   `Source Action`: Le nom de l'action qui a déclenché la décision (ici, `Compare-Config`).
*   `Details`: Une description textuelle de la raison de la décision.
*   `Diff`: Le `diff` généré, s'il y en a un.
*   `Contexte d'Exécution`: Un bloc JSON contenant un sous-ensemble des informations les plus pertinentes de `$localContext`.

## 4. Plan de Modification du Code

### 4.1. `modules/Actions.psm1`

#### a) Mise à jour de la signature de `Compare-Config`
La signature de la fonction `Compare-Config` doit être modifiée pour accepter un nouvel objet `$LocalContext`.

**Avant :**
```powershell
function Compare-Config {
    [CmdletBinding()]
    param(
        [psobject]$Configuration
    )
    # ...
}
```

**Après :**
```powershell
function Compare-Config {
    [CmdletBinding()]
    param(
        [psobject]$Configuration,
        [psobject]$LocalContext
    )
    # ...
}
```

#### b) Modification de la génération du bloc de décision
Le corps de la fonction `Compare-Config` doit être mis à jour pour utiliser les informations de `$LocalContext` afin de générer le nouveau format de bloc de décision.

```powershell
# Extrait du bloc de génération du diff dans Compare-Config

if ($diff) {
    # Génération d'un UUID pour la décision
    $decisionId = [guid]::NewGuid().ToString()

    # Extraction des données contextuelles pertinentes
    $machineName = $LocalContext.computerInfo.CsName
    $timestamp = $LocalContext.timestamp
    $contextSubset = $LocalContext | Select-Object computerInfo, powershell, rooEnvironment | ConvertTo-Json -Depth 5

    # Construction du nouveau bloc de décision
    $diffBlock = @"

### DECISION ID: $decisionId
- **Status:** PENDING
- **Machine:** $machineName
- **Timestamp (UTC):** $timestamp
- **Source Action:** Compare-Config
- **Details:** Une différence a été détectée entre la configuration locale et la configuration de référence.
- **Diff:**
  `diff
$($diff | Out-String)
  `
- **Contexte d'Exécution:**
  `json
$contextSubset
  `

**Action Proposée :**
- `[ ]` **Approuver & Fusionner :** Mettre à jour la configuration de référence avec les changements locaux.
"@
    Add-Content -Path $roadmapPath -Value $diffBlock
    Write-Host "Différence de configuration consignée dans la feuille de route avec l'ID $decisionId."
}
```

### 4.2. `sync-manager.ps1`

L'appel à `Invoke-SyncManager` doit être modifié pour passer la variable `$localContext` (qui est déjà disponible dans le scope principal du script) à l'action. La fonction `Invoke-SyncManager` (dans `Core.psm1`, non montré ici mais l'inférence est claire) devra être adaptée pour relayer ce paramètre.

**Dans `sync-manager.ps1`:**

```powershell
# Ligne existante
$localContext = Get-LocalContext
$config = Resolve-AppConfiguration

# ... (Mise à jour du dashboard et du rapport) ...

# L'appel à Invoke-SyncManager doit maintenant inclure le contexte
$params = $PSBoundParameters
$params.Add('LocalContext', $localContext)

Invoke-SyncManager -SyncAction $Action -Parameters $params
```

### 4.3. `modules/Core.psm1` (Inférence)

La fonction `Invoke-SyncManager` dans ce module devra être mise à jour pour extraire le paramètre `LocalContext` et le passer à la fonction d'action (`Compare-Config` dans notre cas).

```powershell
# Logique inférée pour Invoke-SyncManager dans Core.psm1

function Invoke-SyncManager {
    param(
        [string]$SyncAction,
        [hashtable]$Parameters
    )
    # ...
    $actionParams = @{
        Configuration = $config # $config est résolu à l'intérieur
    }

    if ($Parameters.ContainsKey('LocalContext')) {
        $actionParams.Add('LocalContext', $Parameters['LocalContext'])
    }
    
    # Appel de la fonction d'action (ex: Compare-Config)
    & $SyncAction @actionParams
    # ...
}
```
## 5. Prochaines Étapes

1.  **Implémentation :** Créer une nouvelle tâche de type "code" pour implémenter les modifications décrites dans ce document.
2.  **Validation :** Exécuter l'action `Compare-Config` après avoir introduit une modification dans `config/sync-config.json` et vérifier que le `sync-roadmap.md` est généré avec le nouveau format enrichi.
3.  **Mise à jour de `Apply-Decisions` (hors périmètre initial) :** Dans une future itération, l'action `Apply-Decisions` devra être mise à jour pour archiver les blocs de décision en se basant sur leur `DECISION ID`.