# Investigation #461 - Worktrees Integration

**Machine :** myia-po-2025 (MYIA-PO-2025)
**Agent :** Claude Code (executor autonome)
**Date :** 2026-02-12 18:00-19:00 UTC
**Phase :** Phase 1 - Investigation Layer 3

---

## Résumé Exécutif

L'investigation révèle que **les 3 layers de l'infrastructure worktree existent déjà**, contrairement à ce que l'issue #461 suggère. Le vrai travail consiste à :

1. **Compléter les 5 stubs TODO** dans `start-claude-worker.ps1`
2. **Aligner les conventions de chemin** entre layers
3. **Tester l'intégration** complète

---

## Infrastructure Existante

### Layer 1 : Scripts PowerShell (✅ PRODUCTION-READY)

**Chemin réel :** `scripts/worktrees/` (PAS `roo-config/worktree/scripts/`)

| Script | Taille | Description |
|--------|--------|-------------|
| `create-worktree.ps1` | 6KB | Création sécurisée worktree avec branche feature |
| `submit-pr.ps1` | 4KB | Soumission PR après validation build/tests |
| `cleanup-worktree.ps1` | 5KB | Nettoyage worktree après merge |

**Conventions :**
- Emplacement worktrees : `../roo-extensions-wt/{issue-titre}/`
- Nommage branches : `feature/{ISSUE_NUMBER}-{titre-court}`
- Validation build/tests avant PR

**Documentation :** `docs/dev/WORKTREE-WORKFLOW.md` (197 lignes)

---

### Layer 2 : Service Roo Code VS Code (✅ INTÉGRÉ)

**Chemin :** `roo-code/packages/core/src/worktree/` (submodule)

| Fichier | Description |
|---------|-------------|
| `worktree-service.ts` | API platform-agnostic pour opérations Git worktree |
| `worktree-include.ts` | Logique include patterns |
| `types.ts` | TypeScript types (Worktree, CreateWorktreeOptions, etc.) |
| `__tests__/` | Tests unitaires |

**API clés :**
- `listWorktrees(cwd)` - Lister worktrees actifs
- `createWorktree(cwd, options)` - Créer nouveau worktree
- `getCurrentBranch(cwd)` - Obtenir branche courante
- `getGitRootPath(cwd)` - Obtenir racine repo

**Caractéristiques :**
- Utilise simple-git + native CLI
- Pas de dépendances VS Code (platform-agnostic)
- Gestion erreurs robuste

---

### Layer 3 : Scheduling Worker (⚠️ 5 STUBS TODO)

**Chemin :** `scripts/scheduling/start-claude-worker.ps1` (PAS dans `roo-config/`)

**Taille :** 372 lignes

**Workflow actuel :**
1. Récupérer tâche RooSync (ligne 95-112)
2. Déterminer mode approprié (ligne 114-132)
3. Créer worktree optionnel (ligne 134-158)
4. Lancer Claude avec mode (ligne 178-245)
5. Vérifier conditions d'escalade (ligne 247-270)
6. Reporter résultats au coordinateur (ligne 272-298)
7. Cleanup worktree (ligne 349-351)

---

## Les 5 Stubs TODO Identifiés

### TODO #1 : Ligne 99-101 (Get-NextTask)

**Location :** Function `Get-NextTask`

```powershell
# TODO: Implémenter appel MCP via claude CLI
# Pour l'instant, retourne tâche factice
```

**Implémentation requise :**
- Appeler `roosync_read` (mode: inbox) via Claude CLI
- Parser JSON des messages RooSync
- Extraire tâche avec priorité la plus élevée
- Retourner objet tâche structuré

**Code stub actuel :**
```powershell
$Task = @{
    id = "msg-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    subject = "Sync tour quotidien"
    priority = "MEDIUM"
    suggestedMode = "sync-simple"
    prompt = "Effectue un sync-tour complet : git pull, check messages RooSync, valider build/tests, reporter status."
}
```

---

### TODO #2 : Ligne 205-206 (Invoke-Claude)

**Location :** Function `Invoke-Claude`

```powershell
# TODO: Ajouter support model selection (via env var ou config)
# Pour l'instant, utilise modèle par défaut
```

**Implémentation requise :**
- Lire modèle depuis `$ModeConfig.model` (déjà dans config)
- Mapper vers Claude CLI flag (ex: `--model opus-4-6`)
- Support env var `CLAUDE_MODEL` pour override global
- Validation modèle disponible

**Variables de contexte :**
- `$ModeConfig.model` (ex: "opus-4-6", "sonnet-4-5", "haiku")
- `$ClaudeArgs` array pour arguments CLI

---

### TODO #3 : Ligne 220-227 (Invoke-Claude)

**Location :** Function `Invoke-Claude` - Exécution Claude

```powershell
# Lancer Claude (note: cette ligne ne fonctionnera pas encore car
# il faut implémenter l'intégration avec Ralph Wiggum pour les boucles)
# $Output = & claude @ClaudeArgs 2>&1

# Pour l'instant, simuler succès
Write-Log "[SIMULATION] Claude s'exécuterait avec mode $ModeId" "INFO"
$Output = "Simulation: sync-tour complété avec succès"
```

**Implémentation requise :**
- Décommenter ligne execution Claude CLI
- Ajouter support Ralph Wiggum pour boucles autonomes (si disponible)
- Gérer timeout et erreurs d'exécution
- Parser output pour détecter succès/échec
- Compter itérations réelles (vs simulées)

**Dépendance externe :**
- Ralph Wiggum technique (mentionné dans `docs/architecture/scheduling-claude-code.md:194`)
- Permet boucles autonomes (gather context → take action → verify work → repeat)
- Détection intelligente de sortie (évite boucles infinies)

---

### TODO #4 : Ligne 266-268 (Check-Escalation)

**Location :** Function `Check-Escalation`

```powershell
# TODO: Analyser output pour détecter conditions d'escalade
# (conflits git, complexité détectée, etc.)
```

**Implémentation requise :**
- Parser output de Claude pour patterns d'escalade :
  - Conflits Git : `CONFLICT`, `Merge conflict in`
  - Complexité détectée : `This task requires complex mode`, `Too complex for simple mode`
  - Erreurs build : `Build failed`, `Tests failed`
  - Dépassement itérations : comparaison avec `$ModeConfig.maxIterations`
- Retourner mode d'escalade approprié (simple → complex)
- Logger raison de l'escalade

**Contexte actuel :**
- Escalade uniquement sur `$Result.success = $false`
- Manque détection proactive de complexité

---

### TODO #5 : Ligne 294-296 (Report-Results)

**Location :** Function `Report-Results`

```powershell
# TODO: Envoyer message RooSync au coordinateur
# Pour l'instant, juste logger
```

**Implémentation requise :**
- Appeler `roosync_send` via Claude CLI
- Envoyer rapport au coordinateur (myia-ai-01)
- Format message RooSync :
  - `to: "myia-ai-01"`
  - `subject: "[WORKER-REPORT] $($env:COMPUTERNAME) - $($Task.id)"`
  - `body: $ReportMessage` (déjà formaté en markdown)
  - `priority: "MEDIUM"`
  - `tags: ["worker-report", "automated"]`
- Gérer erreurs d'envoi (retry, fallback log)

**Message template déjà préparé :**
```markdown
## Worker Report - $($env:COMPUTERNAME)
**Tâche:** $($Task.id) - $($Task.subject)
**Mode utilisé:** $FinalMode
**Statut:** ✅ SUCCÈS / ❌ ÉCHEC
**Itérations:** $($Result.iterations)
### Output
\`\`\`
$($Result.output)
\`\`\`
### Logs
Voir: $LogFile
```

---

## Misalignment de Convention de Chemin

### Problème Identifié

**Issue #461 mentionne :**
- Layer 1 : `roo-config/worktree/scripts/New-SafeWorktree.ps1`
- Layer 3 : `roo-config/worktree/scripts/start-claude-worker.ps1`

**Réalité :**
- Layer 1 : `scripts/worktrees/` (create, submit, cleanup)
- Layer 3 : `scripts/scheduling/start-claude-worker.ps1`

**Conséquence :** L'issue référence des chemins qui n'existent pas.

---

### Worktree Path Conventions (Incohérent)

| Source | Convention | Exemple |
|--------|------------|---------|
| **Layer 1 (scripts/worktrees/)** | `../roo-extensions-wt/{issue-titre}/` | `d:/Dev/roo-extensions-wt/417-worktree-workflow/` |
| **Layer 3 (start-claude-worker.ps1:143)** | `.worktrees/{WorktreeName}` | `d:/Dev/roo-extensions/.worktrees/claude-worker-msg-123/` |
| **Documentation (WORKTREE-WORKFLOW.md:120)** | `{parent-du-repo}/roo-extensions-wt/` | `d:/Dev/roo-extensions-wt/` |

**Incohérence :**
- Layer 1 crée worktrees **HORS** du repo (`../roo-extensions-wt/`)
- Layer 3 crée worktrees **DANS** le repo (`.worktrees/`)
- Layer 1 utilise issue number + titre
- Layer 3 utilise task ID arbitraire

**Impact :**
- Worktrees de Layer 3 gitignored (`.worktrees/` probablement dans .gitignore)
- Worktrees de Layer 1 partagés entre machines (dossier parent)
- Collision possible si les deux layers utilisés simultanément

---

### Worktree Naming Conventions (Incohérent)

| Source | Pattern | Exemple |
|--------|---------|---------|
| **Layer 1** | `{issue-number}-{titre-court}` | `417-worktree-workflow` |
| **Layer 3** | `claude-worker-{TaskId}` | `claude-worker-msg-20260212-abc123` |

**Incohérence :**
- Layer 1 utilise issue number GitHub (référence pérenne)
- Layer 3 utilise task ID RooSync (éphémère)
- Pas de lien entre task RooSync et issue GitHub

---

### Recommandations d'Alignement

**Option 1 : Utiliser Layer 1 partout**
- Modifier Layer 3 pour appeler `scripts/worktrees/create-worktree.ps1`
- Avantage : Cohérence, réutilise code robuste
- Inconvénient : Dépendance entre layers

**Option 2 : Harmoniser conventions dans Layer 3**
- Changer `.worktrees/` → `../roo-extensions-wt/`
- Changer `claude-worker-{TaskId}` → `{issue-number}-{titre}` (extraire issue du message)
- Avantage : Layer 3 autonome mais cohérent
- Inconvénient : Duplication de code

**Option 3 : Abstraction partagée**
- Créer `scripts/lib/worktree-helpers.ps1` avec fonctions communes
- Layer 1 et Layer 3 appellent cette lib
- Avantage : DRY, cohérence garantie
- Inconvénient : Refactoring plus lourd

**Recommandation finale :** **Option 1** (réutiliser Layer 1)
- Minimise le code à écrire
- Réutilise scripts testés
- Garantit cohérence

---

## Architecture Layer 3 (Analyse Complète)

### Workflow Actuel

```
┌─────────────────────────────────────────────────────────┐
│              start-claude-worker.ps1                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Get-NextTask                                        │
│     └─> TODO #1: Appeler roosync_read                  │
│                                                         │
│  2. Determine-Mode                                      │
│     └─> Utilise suggestedMode ou défaut                │
│                                                         │
│  3. Create-Worktree (si -UseWorktree)                  │
│     └─> ⚠️ Crée dans .worktrees/ (incohérent)         │
│                                                         │
│  4. Invoke-Claude                                       │
│     ├─> TODO #2: Support model selection               │
│     └─> TODO #3: Exécution réelle + Ralph Wiggum       │
│                                                         │
│  5. Check-Escalation                                    │
│     └─> TODO #4: Analyser output pour escalade         │
│                                                         │
│  6. Report-Results                                      │
│     └─> TODO #5: Envoyer roosync_send                  │
│                                                         │
│  7. Remove-Worktree                                     │
│     └─> Cleanup automatique                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Dépendances Externes

| Dépendance | Statut | Impact |
|------------|--------|--------|
| **Claude CLI** | ✅ Disponible | Requis pour tous les TODO |
| **Ralph Wiggum** | ⚠️ À vérifier | TODO #3 (boucles autonomes) |
| **MCP roo-state-manager** | ✅ Déployé | TODO #1, #5 (roosync_*) |
| **Git worktrees** | ✅ Native | Toutes fonctions worktree |
| **modes-config.json** | ✅ Existe | Configuration modes |

---

## Plan de Complétion (Phase 2)

### TODO #1 : Get-NextTask (Priorité : HAUTE)

**Estimation :** 1-2h

**Implémentation :**
```powershell
function Get-NextTask {
    Write-Log "Récupération prochaine tâche RooSync..."

    # Appeler roosync_read via Claude CLI
    $InboxJson = & claude --dangerously-skip-permissions -p "Exécute roosync_read avec mode=inbox, status=unread. Retourne uniquement le JSON brut." 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Erreur appel roosync_read: $InboxJson" "ERROR"
        return $null
    }

    $Inbox = $InboxJson | ConvertFrom-Json

    # Extraire tâche avec priorité la plus élevée
    $PriorityOrder = @{ "URGENT" = 1; "HIGH" = 2; "MEDIUM" = 3; "LOW" = 4 }
    $NextMessage = $Inbox.messages | Sort-Object { $PriorityOrder[$_.priority] } | Select-Object -First 1

    if (-not $NextMessage) {
        Write-Log "Aucune tâche dans l'inbox" "WARN"
        return $null
    }

    # Parser message pour extraire prompt
    $Task = @{
        id = $NextMessage.id
        subject = $NextMessage.subject
        priority = $NextMessage.priority
        suggestedMode = # TODO: Parser body pour extraire mode suggéré
        prompt = $NextMessage.body
    }

    Write-Log "Tâche récupérée: $($Task.id) - $($Task.subject)"
    return $Task
}
```

---

### TODO #2 : Model Selection (Priorité : MOYENNE)

**Estimation :** 30 min

**Implémentation :**
```powershell
function Invoke-Claude {
    # ...existing code...

    # Lire modèle depuis config ou env var
    $Model = if ($env:CLAUDE_MODEL) {
        $env:CLAUDE_MODEL
    } elseif ($ModeConfig.model) {
        $ModeConfig.model
    } else {
        "opus-4-6"  # Défaut
    }

    Write-Log "Modèle sélectionné: $Model"

    # Mapper vers Claude CLI flag
    $ClaudeArgs = @(
        "--dangerously-skip-permissions",
        "--model", $Model,
        "-p", "`"$Prompt`""
    )

    # ...existing code...
}
```

---

### TODO #3 : Exécution Claude (Priorité : HAUTE)

**Estimation :** 2-3h (avec tests)

**Implémentation :**
```powershell
function Invoke-Claude {
    # ...existing code...

    try {
        Push-Location $WorkingDir

        Write-Log "Exécution dans: $WorkingDir"
        Write-Log "Commande: claude $($ClaudeArgs -join ' ')"

        # Exécution réelle
        $Output = & claude @ClaudeArgs 2>&1 | Out-String

        # Compter itérations (si Ralph Wiggum disponible)
        # TODO: Parser output pour détecter nombre d'itérations
        $IterationCount = 1

        Pop-Location

        # Détecter succès/échec
        $Success = $LASTEXITCODE -eq 0

        Write-Log "Exécution Claude terminée (code: $LASTEXITCODE)"
        Write-Log "Output: $($Output.Substring(0, [Math]::Min(500, $Output.Length)))..."

        return @{
            success = $Success
            output = $Output
            mode = $ModeId
            iterations = $IterationCount
        }
    }
    catch {
        Pop-Location
        Write-Log "Erreur exécution Claude: $_" "ERROR"
        return @{ success = $false; error = $_.Exception.Message }
    }
}
```

---

### TODO #4 : Détection Escalade (Priorité : MOYENNE)

**Estimation :** 1-2h

**Implémentation :**
```powershell
function Check-Escalation {
    param(
        $Result,
        [string]$CurrentMode
    )

    $ModeConfig = Get-ModeConfig -ModeId $CurrentMode

    if (-not $ModeConfig -or -not $ModeConfig.escalation) {
        return $null
    }

    # Vérifier échec
    if (-not $Result.success) {
        Write-Log "Échec détecté, escalade vers: $($ModeConfig.escalation.triggerMode)" "WARN"
        return $ModeConfig.escalation.triggerMode
    }

    # Analyser output pour patterns d'escalade
    $Output = $Result.output

    # Conflits Git
    if ($Output -match "CONFLICT|Merge conflict in") {
        Write-Log "Conflit Git détecté, escalade vers mode complex" "WARN"
        return $ModeConfig.escalation.triggerMode
    }

    # Complexité détectée
    if ($Output -match "This task requires complex mode|Too complex for simple mode") {
        Write-Log "Complexité détectée, escalade vers mode complex" "WARN"
        return $ModeConfig.escalation.triggerMode
    }

    # Erreurs build/tests
    if ($Output -match "Build failed|Tests failed|\d+ failing") {
        Write-Log "Erreurs build/tests détectées, escalade vers mode complex" "WARN"
        return $ModeConfig.escalation.triggerMode
    }

    # Dépassement itérations
    if ($Result.iterations -ge $ModeConfig.maxIterations) {
        Write-Log "Dépassement maxIterations ($($ModeConfig.maxIterations)), escalade" "WARN"
        return $ModeConfig.escalation.triggerMode
    }

    return $null
}
```

---

### TODO #5 : Report RooSync (Priorité : HAUTE)

**Estimation :** 1h

**Implémentation :**
```powershell
function Report-Results {
    param($Task, $Result, [string]$FinalMode)

    Write-Log "Rapport des résultats au coordinateur..."

    $ReportMessage = @"
## Worker Report - $($env:COMPUTERNAME)

**Tâche:** $($Task.id) - $($Task.subject)
**Mode utilisé:** $FinalMode
**Statut:** $(if ($Result.success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })
**Itérations:** $($Result.iterations)

### Output
``````
$($Result.output)
``````

### Logs
Voir: $LogFile
"@

    # Envoyer message RooSync
    try {
        $SendArgs = @"
Exécute roosync_send avec :
- action: send
- to: myia-ai-01
- subject: [WORKER-REPORT] $($env:COMPUTERNAME) - $($Task.id)
- body: $ReportMessage
- priority: MEDIUM
- tags: ["worker-report", "automated"]

Retourne uniquement le JSON de confirmation.
"@

        $SendResult = & claude --dangerously-skip-permissions -p $SendArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Rapport envoyé au coordinateur via RooSync"
        } else {
            Write-Log "Erreur envoi RooSync, fallback sur log local: $SendResult" "WARN"
        }
    }
    catch {
        Write-Log "Exception envoi RooSync: $_" "ERROR"
    }

    # Fallback : toujours logger localement
    Write-Log $ReportMessage
}
```

---

## Alignement Conventions de Chemin (Phase 2)

### Recommandation : Réutiliser Layer 1

**Modification de `Create-Worktree` (ligne 134-158) :**

```powershell
function Create-Worktree {
    param([string]$TaskId)

    if (-not $UseWorktree) {
        Write-Log "Worktree désactivé, travail sur branche principale"
        return $null
    }

    Write-Log "Création worktree via script Layer 1..."

    try {
        # Extraire issue number du TaskId (ex: msg-123 ou issue-456)
        if ($TaskId -match "issue-(\d+)") {
            $IssueNumber = $matches[1]
        } else {
            # Fallback : utiliser TaskId comme nom
            Write-Log "Pas d'issue number détecté, utilisation TaskId: $TaskId" "WARN"

            # Créer worktree manuellement (convention Layer 1)
            $WorktreeName = "worker-$TaskId"
            $WorktreePath = Join-Path (Split-Path $RepoRoot -Parent) "roo-extensions-wt\$WorktreeName"

            git worktree add $WorktreePath -b $WorktreeName 2>&1 | ForEach-Object { Write-Log $_ "GIT" }

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Erreur création worktree" "ERROR"
                return $null
            }

            Write-Log "Worktree créé: $WorktreePath"
            return $WorktreePath
        }

        # Appeler script Layer 1 si issue number disponible
        $CreateScript = Join-Path $RepoRoot "scripts\worktrees\create-worktree.ps1"

        if (-not (Test-Path $CreateScript)) {
            Write-Log "Script Layer 1 introuvable: $CreateScript" "ERROR"
            return $null
        }

        & $CreateScript -IssueNumber $IssueNumber 2>&1 | ForEach-Object { Write-Log $_ }

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Erreur script Layer 1" "ERROR"
            return $null
        }

        # Déterminer path créé par Layer 1
        $IssueTitle = # TODO: Récupérer via gh issue view
        $WorktreePath = Join-Path (Split-Path $RepoRoot -Parent) "roo-extensions-wt\$IssueNumber-$IssueTitle"

        Write-Log "Worktree créé avec succès: $WorktreePath"
        return $WorktreePath
    }
    catch {
        Write-Log "Erreur création worktree: $_" "ERROR"
        return $null
    }
}
```

---

## Tests de Validation (Phase 3)

### Test 1 : Get-NextTask

**Commande :**
```powershell
.\start-claude-worker.ps1 -DryRun
```

**Validation :**
- [ ] Appelle roosync_read correctement
- [ ] Parse JSON inbox
- [ ] Extrait tâche avec priorité la plus élevée
- [ ] Retourne objet Task structuré

---

### Test 2 : Model Selection

**Commande :**
```powershell
$env:CLAUDE_MODEL = "sonnet-4-5"
.\start-claude-worker.ps1 -DryRun -TaskId "test"
```

**Validation :**
- [ ] Utilise modèle depuis env var
- [ ] Passe --model correctement à Claude CLI
- [ ] Fallback sur modèle par défaut si env var absente

---

### Test 3 : Exécution Claude

**Commande :**
```powershell
.\start-claude-worker.ps1 -TaskId "test" -Mode "sync-simple"
```

**Validation :**
- [ ] Exécute Claude CLI réellement (pas simulation)
- [ ] Capture output correctement
- [ ] Détecte succès/échec via exit code
- [ ] Compte itérations (si Ralph Wiggum disponible)

---

### Test 4 : Détection Escalade

**Setup :** Créer tâche avec output contenant "CONFLICT"

**Commande :**
```powershell
.\start-claude-worker.ps1 -TaskId "conflict-test" -Mode "sync-simple"
```

**Validation :**
- [ ] Détecte pattern "CONFLICT" dans output
- [ ] Escalade vers mode complex
- [ ] Log raison de l'escalade

---

### Test 5 : Report RooSync

**Commande :**
```powershell
.\start-claude-worker.ps1 -TaskId "test"
```

**Validation post-exécution :**
- [ ] Message RooSync envoyé au coordinateur
- [ ] Format message correct (markdown, métadonnées)
- [ ] Fallback sur log local si envoi échoue

---

### Test 6 : Worktree Integration

**Commande :**
```powershell
.\start-claude-worker.ps1 -UseWorktree -TaskId "issue-461"
```

**Validation :**
- [ ] Appelle script Layer 1 si issue number détecté
- [ ] Crée worktree dans `../roo-extensions-wt/` (cohérent Layer 1)
- [ ] Exécute Claude dans worktree
- [ ] Cleanup worktree après exécution

---

## Estimation Temps (Phase 2+3)

| Tâche | Estimation | Priorité |
|-------|------------|----------|
| TODO #1 (Get-NextTask) | 1-2h | HAUTE |
| TODO #2 (Model Selection) | 30 min | MOYENNE |
| TODO #3 (Exécution Claude) | 2-3h | HAUTE |
| TODO #4 (Détection Escalade) | 1-2h | MOYENNE |
| TODO #5 (Report RooSync) | 1h | HAUTE |
| Alignement worktree paths | 1-2h | HAUTE |
| Tests validation (6 tests) | 2-3h | HAUTE |
| Documentation finale | 1h | MOYENNE |

**Total :** 10-16h (réparti sur 2-3 sessions)

---

## Prochaines Actions

**Court terme (aujourd'hui) :**
1. ✅ Investigation Layer 3 complétée
2. ⏳ Annoncer findings dans INTERCOM
3. ⏳ Reporter au coordinateur via RooSync
4. ⏳ Demander validation approche alignement

**Moyen terme (demain) :**
1. Implémenter les 5 TODO (10-12h)
2. Tester chaque TODO individuellement
3. Intégration tests E2E
4. Validation build + tests unitaires

**Long terme (après-demain) :**
1. Documentation complète workflow Layer 3
2. Mise à jour CLAUDE.md (section worktrees)
3. Commit + PR
4. Reporter fermeture #461

---

**Document créé :** 2026-02-12 19:00 UTC
**Agent :** Claude Code (myia-po-2025)
**Phase suivante :** Annonce findings + validation approche
