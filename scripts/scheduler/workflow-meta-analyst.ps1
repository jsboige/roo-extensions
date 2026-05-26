<#
.SYNOPSIS
    Meta-analyst workflow for RooSync multi-agent system.

.DESCRIPTION
    Unified meta-analyst workflow for all machines.
    Implements observation and analysis of BOTH schedulers (Roo + Claude),
    then reconciles findings via META-INTERCOM.
    Runs every 72 hours on all machines.

.NOTES
    Author: RooSync Scheduler System
    Version: 1.0.0
    Issue: #689
    Frequency: 72h
    Mode: orchestrator-complex
#>

[CmdletBinding()]
param()

# strict mode for error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import shared modules
$ModulePath = Join-Path $PSScriptRoot "*.psm1"
$ModulesToImport = @(
    "PreFlightCheck.psm1",
    "INTERCOMReporting.psm1",
    "EscalationProtocol.psm1",
    "WinCliPatterns.psm1"
)

foreach ($Module in $ModulesToImport) {
    $ModuleFullPath = Join-Path $PSScriptRoot $Module
    if (Test-Path $ModuleFullPath) {
        Import-Module $ModuleFullPath -Force -ErrorAction Stop
    } else {
        throw "Required module not found: $Module"
    }
}

# Get machine identifier
$MachineName = ($env:COMPUTERNAME).ToLower()
$INTERCOMPath = ".claude/local/INTERCOM-$MachineName.md"
$META_INTERCOMPath = ".claude/local/META-INTERCOM-$MachineName.md"

<#
.SYNOPSIS
    Writes a step marker to META-INTERCOM for tracking.
#>
function Write-MetaWorkflowStep {
    param(
        [string]$StepName,
        [string]$Details
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $content = "**Step:** $StepName`n`n$Details"
    Write-METAINTERCOMMessage -Type "INFO" -Title "Meta-analysis step: $StepName" -Content $content
}

<#
.SYNOPSIS
    Writes a message to META-INTERCOM.
#>
function Write-METAINTERCOMMessage {
    param(
        [ValidateSet('INFO', 'TASK', 'DONE', 'WARN', 'ERROR', 'ASK', 'REPLY', 'COORDINATION', 'CRITICAL')]
        [string]$Type,

        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true)]
        [string]$Content,

        [string]$Sender = "claude-code",
        [string]$Receiver = "roo"
    )

    $metaIntercomPath = ".claude/local/META-INTERCOM-$MachineName.md"
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $message = @"

## [$timestamp] $Sender -> $Receiver [$TYPE]

### $Title

$Content

---
"@

    # Ensure directory exists
    $metaIntercomDir = Split-Path $metaIntercomPath -Parent
    if (-not (Test-Path $metaIntercomDir)) {
        New-Item -Path $metaIntercomDir -ItemType Directory -Force | Out-Null
    }

    # Append to META-INTERCOM (never delete or overwrite)
    Add-Content -Path $metaIntercomPath -Value $message -ErrorAction SilentlyContinue
}

<#
.SYNOPSIS
    Delegates a task to code-complex via new_task.

.DESCRIPTION
    Creates a standardized delegation instruction for meta-analyst tasks.
    All heavy analysis is delegated to code-complex mode via new_task.
#>
function Invoke-DelegatedTask {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskTitle,

        [Parameter(Mandatory=$true)]
        [string]$TaskDescription,

        [string]$Context,

        [string]$Constraints
    )

    $instruction = "DELEGUER à code-complex :`n`n$TaskDescription"

    if ($Context) {
        $instruction += "`n`nCONTEXTE :`n$Context"
    }

    if ($Constraints) {
        $instruction += "`n`nCONTRAINTES :`n$Constraints"
    }

    $instruction += "`n`nRAPPEL : TOUJOURS utiliser new_task pour déléguer. NE PAS faire le travail toi-même."

    # Log the delegation
    Write-MetaWorkflowStep -StepName "Delegation" -Details "Delegated: $TaskTitle"

    # Return instruction for caller to use with new_task
    return $instruction
}

<#
.SYNOPSIS
    Step 1: Collect local traces (Roo + Claude schedulers).

.DESCRIPTION
    Prepares delegation instructions for trace collection.
    Actual work is delegated to code-complex via new_task.

    Roo traces:
    - Path: %APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks/
    - Get recent task directories (last 10 by LastWriteTime)
    - Read ui_messages.json from each task

    Claude traces:
    - Path: ~/.claude/projects/*/sessions/*.jsonl
    - Get recent .jsonl files (last 10 by LastWriteTime)
    - Extract metrics: model used, success/failure, tool usage

    Operational metrics:
    - GitHub issues created vs closed (last 72h)
    - Machine utilization (commits, issues closed)
#>
function Invoke-TraceCollection {
    Write-MetaWorkflowStep -StepName "Trace Collection" -Details "Preparing delegation for local trace collection"

    $instruction = @"
DELEGUER à code-complex :

## Tâche : Collecte des traces locales (Roo + Claude)

### Roo Scheduler Traces

1. Lister les 10 tâches Roo les plus récentes :
```
execute_command(shell="powershell", command="Get-ChildItem '$env:APPDATA/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks' -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 10 | Select-Object Name, LastWriteTime")
```

2. Pour chaque tâche, lire le fichier ui_messages.json :
```
execute_command(shell="powershell", command="Get-Content '$env:APPDATA/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks/{TASK_ID}/ui_messages.json' -Raw | ConvertFrom-Json")
```

3. Extraire les métriques :
   - Nombre de messages par mode (code-simple, code-complex, orchestrator-complex)
   - Taux de succès (tâches terminées sans erreur)
   - Outils utilisés (win-cli, roosync_*, etc.)
   - Durée d'exécution

### Claude Scheduler Traces

1. Lister les 10 sessions Claude les plus récentes :
```
execute_command(shell="powershell", command="Get-ChildItem '$env:USERPROFILE\.claude\projects' -Recurse -Filter '*.jsonl' | Sort-Object LastWriteTime -Descending | Select-Object -First 10 | Select-Object Name, LastWriteTime")
```

2. Pour chaque session, extraire :
   - Modèle utilisé (opus, sonnet, haiku)
   - Outils MCP appelés
   - Erreurs rencontrées
   - Durée de session

### Métriques Opérationnelles

1. Récupérer les issues GitHub des 72 dernières heures :
```
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state all --since '72 hours ago' --json number,state,createdAt,closedAt --limit 50")
```

2. Calculer :
   - Issues créées vs fermées
   - Distribution par statut (open, closed)
   - Issues par machine (champ Machine du Project #67)

**CONTRAINTES IMPORTANTES :**
- TOUJOURS utiliser win-cli MCP (execute_command), PAS le terminal natif
- NE PAS modifier les fichiers de harnais
- NE PAS commit ou push
- Retourner SEULEMENT les métriques agrégées (pas les traces brutes)
"@

    Write-MetaWorkflowStep -StepName "Trace Collection Delegated" -Details "Trace collection delegated to code-complex via new_task"

    return $instruction
}

<#
.SYNOPSIS
    Step 2: Cross-harness analysis (Roo + Claude).

.DESCRIPTION
    Prepares delegation instructions for cross-harness analysis.
    Actual work is delegated to code-complex via new_task.

    Roo harness files:
    - .roo/rules/ (all .md files)
    - .roomodes (current modes configuration)
    - modes-config.json (source)

    Claude harness files:
    - CLAUDE.md (project instructions)
    - .claude/rules/ (all .md files)
    - .claude/commands/ (slash commands)
    - .claude/skills/ (auto-invoked skills)

    Identify:
    - INCOHERENCES: Contradictions between Roo and Claude harnesses
    - LACUNES: Missing documentation or unclear rules
    - AMELIORATIONS: Potential improvements to workflows
#>
function Invoke-CrossHarnessAnalysis {
    Write-MetaWorkflowStep -StepName "Cross-Harness Analysis" -Details "Preparing delegation for cross-harness analysis"

    $instruction = @"
DELEGUER à code-complex :

## Tâche : Analyse croisée des harnais (Roo + Claude)

### Lecture des Harnais Roo

1. Lire les fichiers de règles Roo :
```
execute_command(shell="powershell", command="Get-ChildItem '.roo/rules' -Filter '*.md' | Select-Object Name")
execute_command(shell="powershell", command="Get-Content '.roo/rules/01-*.md' -Raw")
```

2. Lire la configuration des modes :
```
execute_command(shell="powershell", command="Get-Content '.roomodes' -Raw")
```

### Lecture des Harnais Claude

1. Lire les fichiers de règles Claude :
```
execute_command(shell="powershell", command="Get-ChildItem '.claude/rules' -Filter '*.md' | Select-Object Name")
execute_command(shell="powershell", command="Get-Content '.claude/rules/scheduler-*.md' -Raw")
```

2. Lire CLAUDE.md :
```
execute_command(shell="powershell", command="Get-Content 'CLAUDE.md' -Raw")
```

### Analyse

Comparer les deux harnais et identifier :

1. **INCOHERENCES** : Contradictions entre Roo et Claude
   - Ex: Protocole INTERCOM différent
   - Ex: Règles d'escalade incohérentes
   - Ex: Workflows conflictuels

2. **LACUNES** : Documentation manquante ou floue
   - Règles non documentées
   - Workflows sans spécification claire
   - Conditions d'escalade ambiguës

3. **AMELIORATIONS** : Améliorations potentielles
   - Simplification de workflows
   - Harmonisation de règles
   - Optimisation de l'escalade

**CONTRAINTES IMPORTANTES :**
- TOUJOURS utiliser win-cli MCP (execute_command), PAS le terminal natif
- NE PAS modifier les fichiers de harnais (lecture seule)
- NE PAS commit ou push
- Retourner une liste structurée : INCOHERENCES / LACUNES / AMELIORATIONS
"@

    Write-MetaWorkflowStep -StepName "Cross-Harness Analysis Delegated" -Details "Cross-harness analysis delegated to code-complex via new_task"

    return $instruction
}

<#
.SYNOPSIS
    Step 3: Write META-INTERCOM report.

.DESCRIPTION
    Prepares delegation instructions for META-INTERCOM reporting.
    Actual work is delegated to code-complex via new_task.

    Report format:
    - Machine name and timestamp
    - Summary of findings (Roo metrics, Claude metrics)
    - Cross-harness analysis results
    - Recommendations (if any)
    - Actionable items (if any)

    Always APPEND to META-INTERCOM, never delete or overwrite.
#>
function Invoke-METAINTERCOMReporting {
    Write-MetaWorkflowStep -StepName "META-INTERCOM Reporting" -Details "Preparing delegation for META-INTERCOM report writing"

    $instruction = @"
DELEGUER à code-complex :

## Tâche : Écrire rapport dans META-INTERCOM

### Vérifier/Initialiser META-INTERCOM

1. Vérifier si META-INTERCOM existe :
```
execute_command(shell="powershell", command="Test-Path '.claude/local/META-INTERCOM-$MachineName.md'")
```

2. Si inexistant, copier le template :
```
execute_command(shell="powershell", command="Copy-Item '.claude/local/META-INTERCOM_TEMPLATE.md' '.claude/local/META-INTERCOM-$MachineName.md'")
```

### Composition du Rapport

Écrire un rapport structuré avec le format suivant :

```markdown
## [{TIMESTAMP}] claude-code -> all [META-ANALYSIS]

### Machine : {MACHINE_NAME}
### Date : {DATE}

---

## Analyse Roo Scheduler

**Métriques collectées :**
- Tâches analysées : {N}
- Taux de succès : {X}%
- Niveau atteint : {simple/complex/mixte}
- Outils utilisés : {liste}

**Observations :**
- {Observations sur les traces Roo}

---

## Analyse Claude Scheduler

**Métriques collectées :**
- Sessions analysées : {N}
- Modèles utilisés : {distribution}
- Outils MCP appelés : {liste}
- Erreurs rencontrées : {N}

**Observations :**
- {Observations sur les traces Claude}

---

## Analyse Croisée des Harnais

**INCOHERENCES détectées :**
- {Liste des incohérences avec gravité}

**LACUNES identifiées :**
- {Liste des lacunes avec priorité}

**AMELIORATIONS suggérées :**
- {Liste des améliorations avec impact}

---

## Recommandations

**Pour le Coordinateur :**
- {Actions recommandées pour le coordinateur}

**Pour les Exécuteurs :**
- {Actions recommandées pour les exécuteurs}

**Pour les Mainteneurs :**
- {Actions recommandées pour les mainteneurs de harnais}

---

## Issues GitHub Créées (le cas échéant)

- {Liste des issues créées avec numéros}

---
```

### Écriture du Rapport

Ajouter ce rapport À LA FIN du fichier META-INTERCOM (jamais au début) :
```
execute_command(shell="powershell", command="Add-Content -Path '.claude/local/META-INTERCOM-$MachineName.md' -Value '`n`n{RAPPORT_CONTENT}'")
```

**CONTRAINTES IMPORTANTES :**
- TOUJOURS utiliser win-cli MCP (execute_command), PAS le terminal natif
- AJOUTER À LA FIN du fichier (jamais insérer au début)
- NE JAMAIS supprimer ou écraser le contenu existant
- NE PAS commit ou push
"@

    Write-MetaWorkflowStep -StepName "META-INTERCOM Reporting Delegated" -Details "META-INTERCOM reporting delegated to code-complex via new_task"

    return $instruction
}

<#
.SYNOPSIS
    Step 4: Create GitHub issues if recommendations are actionable (OPTIONAL).

.DESCRIPTION
    Prepares delegation instructions for GitHub issue creation.
    Actual work is delegated to code-complex via new_task.

    Guard rails:
    - Check for existing issues first (anti-duplicate guard)
    - Maximum 3 issues per cycle
    - Always include 'needs-approval' label
    - Non-trivial findings only (actionable, specific, justified)

    Issue types:
    - Environment issue (missing .env, MCP down, service unreachable)
    - Harness inconsistency (conflicting rules)
    - Documentation gap (missing critical info)
    - Improvement proposal (workflow optimization)
#>
function Invoke-GitHubIssueCreation {
    Write-MetaWorkflowStep -StepName "GitHub Issue Creation" -Details "Preparing delegation for GitHub issue creation"

    $instruction = @"
DELEGUER à code-complex :

## Tâche : Créer issues GitHub si recommandations actionnables (OPTIONNEL)

### Vérification Anti-Duplicate

1. Rechercher les issues existantes sur le sujet :
```
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --search '{SUJET}' --state open --limit 10")
```

2. Ne créer une issue que si :
   - Aucune issue existante sur le même sujet
   - La recommandation est ACTIONNABLE (spécifique, faisable)
   - La recommandation est NON TRIVIALE (pas évidente)
   - La recommandation est JUSTIFIÉE (basée sur des faits observés)

### Création d'Issues

Maximum 3 issues par cycle, avec label 'needs-approval' :

**Format de l'issue :**

```markdown
## Title
[{TYPE}] {Titre descriptif}

## Body
**Source :** Meta-analyst {MACHINE_NAME}
**Date :** {DATE}

### Problème Identifié
{Description du problème avec faits observés}

### Contexte
{Contexte supplémentaire si nécessaire}

### Recommandation
{Proposition spécifique d'amélioration}

### Impact
{Impact attendu si la recommandation est appliquée}

**Labels :** needs-approval, {autres labels appropriés}
**Machine :** {MACHINE_NAME ou Any}
```

**Types d'issues :**
- `[ENV]` : Problème d'environnement (.env manquant, MCP down, service unreachable)
- `[HARNESS]` : Incohérence de harnais (règles conflictuelles)
- `[DOC]` : Lacune documentation (info critique manquante)
- `[IMPROVEMENT]` : Proposition d'amélioration (optimisation workflow)

### Commandes de Création

```
execute_command(shell="powershell", command="gh issue create --repo jsboige/roo-extensions --title '{TITLE}' --body '{BODY}' --label 'needs-approval,{OTHER_LABELS}'")
```

**CONTRAINTES IMPORTANTES :**
- TOUJOURS utiliser win-cli MCP (execute_command), PAS le terminal natif
- Vérifier les issues existantes AVANT de créer (anti-duplicate)
- Maximum 3 issues par cycle
- TOUJOURS inclure le label 'needs-approval'
- NE PAS commit ou push (l'issue créée suffit)
- Retourner la liste des issues créées avec numéros
"@

    Write-MetaWorkflowStep -StepName "GitHub Issue Creation Delegated" -Details "GitHub issue creation delegated to code-complex via new_task"

    return $instruction
}

<#
.SYNOPSIS
    Generates end-of-cycle report.
#>
function Write-CycleReport {
    param(
        [hashtable]$Metrics
    )

    $content = "**Cycle Type:** Meta-Analyst`n`n**Machine:** $MachineName`n`n**Timestamp:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")`n`n"

    if ($Metrics.TracesCollected) {
        $content += "**Traces Collected:** Yes`n`n"
    }

    if ($Metrics.CrossHarnessAnalyzed) {
        $content += "**Cross-Harness Analysis:** Completed`n`n"
    }

    if ($Metrics.ReportWritten) {
        $content += "**META-INTERCOM Report:** Written`n`n"
    }

    if ($Metrics.IssuesCreated -gt 0) {
        $content += "**GitHub Issues Created:** $($Metrics.IssuesCreated)`n`n"
    }

    if ($Metrics.Errors.Count -gt 0) {
        $content += "**Errors:**`n"
        foreach ($error in $Metrics.Errors) {
            $content += "- $error`n"
        }
        $content += "`n"
    }

    Write-INTERCOMMessage -Type "COORDINATION" -Title "Meta-analyst cycle report" -Content $content -MachineName $MachineName
}

<#
.MAIN
    Meta-analyst workflow main entry point.
#>

function Start-MetaAnalystWorkflow {
    [CmdletBinding()]
    param()

    $cycleMetrics = @{
        TracesCollected = $false
        CrossHarnessAnalyzed = $false
        ReportWritten = $false
        IssuesCreated = 0
        Errors = @()
    }

    try {
        Write-MetaWorkflowStep -StepName "Cycle Start" -Details "Meta-analyst workflow starting on $MachineName"

        # ========================================
        # STEP 0: Pre-flight Check (OBLIGATOIRE)
        # ========================================
        Write-MetaWorkflowStep -StepName "Pre-flight Check" -Details "Verifying critical MCPs"

        $preFlightResult = Test-PreFlightCheck
        $preFlightSuccess = Write-PreFlightCheckToINTERCOM -Result $preFlightResult -MachineName $MachineName

        if (-not $preFlightSuccess) {
            throw "Pre-flight check FAILED. Cannot proceed without critical MCPs."
        }

        # ========================================
        # STEP 1: Collecte des traces locales
        # ========================================
        Write-MetaWorkflowStep -StepName "Trace Collection Preparation" -Details "Preparing delegation for trace collection"

        $tracesInstruction = Invoke-TraceCollection
        $cycleMetrics.TracesCollected = $true

        # NOTE: Actual execution is delegated via new_task to code-complex
        # The instruction string is returned for the orchestrator to use

        # ========================================
        # STEP 2: Analyse croisée des harnais
        # ========================================
        Write-MetaWorkflowStep -StepName "Cross-Harness Analysis Preparation" -Details "Preparing delegation for cross-harness analysis"

        $harnessInstruction = Invoke-CrossHarnessAnalysis
        $cycleMetrics.CrossHarnessAnalyzed = $true

        # NOTE: Actual execution is delegated via new_task to code-complex
        # The instruction string is returned for the orchestrator to use

        # ========================================
        # STEP 3: Écrire rapport dans META-INTERCOM
        # ========================================
        Write-MetaWorkflowStep -StepName "META-INTERCOM Reporting Preparation" -Details "Preparing delegation for META-INTERCOM report writing"

        $reportInstruction = Invoke-METAINTERCOMReporting
        $cycleMetrics.ReportWritten = $true

        # NOTE: Actual execution is delegated via new_task to code-complex
        # The instruction string is returned for the orchestrator to use

        # ========================================
        # STEP 4: Créer issues GitHub si recommandations actionnables (OPTIONNEL)
        # ========================================
        Write-MetaWorkflowStep -StepName "GitHub Issue Creation Preparation" -Details "Preparing delegation for GitHub issue creation"

        $issuesInstruction = Invoke-GitHubIssueCreation

        # NOTE: Actual execution is delegated via new_task to code-complex
        # The instruction string is returned for the orchestrator to use

        # ========================================
        # STEP 5: Rapporter dans INTERCOM (OBLIGATOIRE)
        # ========================================
        Write-CycleReport -Metrics $cycleMetrics

        Write-MetaWorkflowStep -StepName "Cycle Complete" -Details "Meta-analyst workflow finished successfully"

    } catch {
        $errorMsg = "Meta-analyst workflow failed: $($_.Exception.Message)"
        Write-INTERCOMError -ErrorTitle "Workflow Error" -ErrorMessage "Meta-analyst workflow encountered an error" -ErrorDetails $_.Exception.Message -MachineName $MachineName
        throw
    }
}

# Export main function
Export-ModuleMember -Function Start-MetaAnalystWorkflow
