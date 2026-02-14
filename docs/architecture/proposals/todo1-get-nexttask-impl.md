# Proposition d'implémentation TODO #1 - Get-NextTask

**Issue :** #461 - Worktrees Integration
**Fichier :** `scripts/scheduling/start-claude-worker.ps1`
**Lignes :** 99-101
**Date :** 2026-02-12
**Machine :** myia-po-2025

---

## Contexte

Le TODO #1 nécessite d'implémenter la fonction `Get-NextTask` pour récupérer la prochaine tâche depuis l'inbox RooSync.

**TODO actuel (ligne 99-101) :**
```powershell
# TODO: Implémenter appel MCP via claude CLI
# Pour l'instant, retourne tâche factice
```

---

## Approches Évaluées

### ❌ Approche 1 : Invocation MCP via Claude CLI

**Tentative :**
```powershell
$InboxJson = & claude --dangerously-skip-permissions -p "Exécute roosync_read..."
```

**Problèmes :**
- Claude CLI en mode `-p` génère une réponse textuelle, pas juste l'output de l'outil
- Temps d'exécution long (30s+ timeout)
- Nécessite parsing de la réponse Claude pour extraire le JSON

**Verdict :** ❌ Trop complexe et fragile

---

### ❌ Approche 2 : Invocation MCP directe (JSON-RPC)

**Concept :** Créer un script Node.js qui communique avec le serveur MCP via stdio (JSON-RPC)

**Problèmes :**
- Nécessite comprendre le protocole JSON-RPC MCP
- Dépendance supplémentaire (Node.js script)
- Plus complexe que nécessaire

**Verdict :** ❌ Overkill pour le besoin

---

### ✅ Approche 3 : Lecture directe des fichiers JSON

**Concept :** Lire les fichiers JSON dans `$env:ROOSYNC_SHARED_PATH/messages/inbox/`

**Avantages :**
- ✅ Simple et direct
- ✅ Aucune dépendance externe
- ✅ Rapide (lecture fichiers locaux)
- ✅ Format JSON bien défini

**Inconvénient :**
- Bypass le MCP (mais pour un worker automatisé, c'est acceptable)

**Verdict :** ✅ **RECOMMANDÉ**

---

## Implémentation Proposée

### Code PowerShell

```powershell
function Get-NextTask {
    <#
    .SYNOPSIS
    Récupère la prochaine tâche non-lue depuis l'inbox RooSync

    .DESCRIPTION
    Lit les fichiers JSON dans l'inbox RooSync, filtre ceux destinés à
    cette machine ou à "all", retourne la tâche avec la priorité la plus élevée.

    .OUTPUTS
    Hashtable avec les propriétés: id, subject, priority, prompt
    #>

    Write-Log "Récupération prochaine tâche RooSync..."

    # Récupérer le shared path depuis env
    $SharedPath = $env:ROOSYNC_SHARED_PATH
    if (-not $SharedPath) {
        Write-Log "ROOSYNC_SHARED_PATH non défini, utilisation tâche factice" "WARN"
        return Get-FallbackTask
    }

    # Chemin inbox
    $InboxPath = Join-Path $SharedPath "messages\inbox"
    if (-not (Test-Path $InboxPath)) {
        Write-Log "Inbox RooSync introuvable: $InboxPath" "WARN"
        return Get-FallbackTask
    }

    # Récupérer machine ID
    $MachineId = $env:COMPUTERNAME.ToLower()
    Write-Log "Machine ID: $MachineId"

    # Lire tous les messages JSON
    $Messages = Get-ChildItem $InboxPath -Filter "*.json" | ForEach-Object {
        try {
            $Content = Get-Content $_.FullName -Raw | ConvertFrom-Json
            return $Content
        }
        catch {
            Write-Log "Erreur lecture message $($_.Name): $_" "WARN"
            return $null
        }
    } | Where-Object { $_ -ne $null }

    Write-Log "Messages dans inbox: $($Messages.Count)"

    # Filtrer messages pour cette machine
    $MyMessages = $Messages | Where-Object {
        ($_.to -eq $MachineId -or $_.to -eq "all") -and $_.status -eq "unread"
    }

    Write-Log "Messages non-lus pour $MachineId : $($MyMessages.Count)"

    if ($MyMessages.Count -eq 0) {
        Write-Log "Aucune tâche dans l'inbox" "INFO"
        return $null
    }

    # Trier par priorité (URGENT > HIGH > MEDIUM > LOW)
    $PriorityOrder = @{ "URGENT" = 1; "HIGH" = 2; "MEDIUM" = 3; "LOW" = 4 }
    $NextMessage = $MyMessages | Sort-Object {
        $PriorityOrder[$_.priority]
    } | Select-Object -First 1

    # Construire objet tâche
    $Task = @{
        id = $NextMessage.id
        subject = $NextMessage.subject
        priority = $NextMessage.priority
        prompt = $NextMessage.body
        messageFile = Join-Path $InboxPath "$($NextMessage.id).json"
    }

    Write-Log "Tâche récupérée: $($Task.id) - $($Task.subject) [Priority: $($Task.priority)]"

    return $Task
}

function Get-FallbackTask {
    <#
    .SYNOPSIS
    Retourne une tâche factice si RooSync est indisponible
    #>

    return @{
        id = "fallback-sync-tour"
        subject = "Sync tour quotidien (fallback)"
        priority = "LOW"
        prompt = "Effectue un sync-tour complet : git pull, check INTERCOM, valider build/tests, reporter status dans INTERCOM local."
        messageFile = $null
    }
}

function Mark-TaskAsRead {
    param([string]$MessageFile)

    <#
    .SYNOPSIS
    Marque un message comme lu en modifiant le JSON
    #>

    if (-not $MessageFile -or -not (Test-Path $MessageFile)) {
        Write-Log "Impossible de marquer comme lu: fichier introuvable" "WARN"
        return
    }

    try {
        $Message = Get-Content $MessageFile -Raw | ConvertFrom-Json
        $Message.status = "read"

        # Sauvegarder (UTF-8 sans BOM)
        $JsonText = $Message | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($MessageFile, $JsonText, [System.Text.UTF8Encoding]::new($false))

        Write-Log "Message marqué comme lu: $($Message.id)"
    }
    catch {
        Write-Log "Erreur marquage message: $_" "ERROR"
    }
}
```

---

## Modifications nécessaires dans start-claude-worker.ps1

### 1. Ajouter après Get-NextTask (ligne ~112)

```powershell
# Appeler après traitement de la tâche (ligne ~280)
if ($Task.messageFile) {
    Mark-TaskAsRead -MessageFile $Task.messageFile
}
```

### 2. Vérifier que $env:ROOSYNC_SHARED_PATH est défini

Ajouter en début de script (après ligne 10) :

```powershell
# Vérifier configuration RooSync
if (-not $env:ROOSYNC_SHARED_PATH) {
    Write-Warning "ROOSYNC_SHARED_PATH non défini. Le worker utilisera des tâches fallback."
    Write-Warning "Définir la variable pour activer la récupération RooSync."
}
```

---

## Tests recommandés

### Test 1 : Pas de messages

```powershell
# Vider l'inbox temporairement
mv "G:/Mon Drive/Synchronisation/RooSync/.shared-state/messages/inbox/*.json" /tmp/
.\start-claude-worker.ps1 -DryRun
# Vérifier que fallback task est retournée
```

### Test 2 : Message urgent

```powershell
# Créer message test
$Msg = @{
    id = "msg-test-urgent"
    from = "myia-ai-01"
    to = "myia-po-2025"
    subject = "Test urgence"
    body = "Tâche de test urgente"
    priority = "URGENT"
    status = "unread"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 10

[System.IO.File]::WriteAllText(
    "G:/Mon Drive/Synchronisation/RooSync/.shared-state/messages/inbox/msg-test-urgent.json",
    $Msg,
    [System.Text.UTF8Encoding]::new($false)
)

.\start-claude-worker.ps1 -DryRun
# Vérifier que le message urgent est récupéré
```

### Test 3 : Plusieurs messages avec priorités

```powershell
# Créer 3 messages (URGENT, HIGH, LOW)
# Vérifier que URGENT est traité en premier
```

---

## Estimation

- **Implémentation** : 1-2h
- **Tests** : 30 min
- **Documentation** : 30 min
- **TOTAL** : **2-3h**

---

## Prochaines étapes

1. **Valider cette approche** avec le coordinateur (ou l'utilisateur)
2. **Implémenter** les fonctions dans `start-claude-worker.ps1`
3. **Tester** avec messages réels de l'inbox
4. **Documenter** dans le README.md

---

## Note sur Ralph Wiggum

Ralph Wiggum (TODO #3) est **orthogonal** à cette implémentation. Ralph gère les **boucles d'exécution Claude** (gather context → take action → verify → repeat), pas la récupération des tâches.

Les deux peuvent coexister :
- `Get-NextTask` → récupère la tâche depuis RooSync
- `Invoke-Claude` → exécute Claude avec Ralph Wiggum pour boucles autonomes

---

**Auteur :** Claude Code (myia-po-2025)
**Révision :** 1.0
**Statut :** ✅ Prêt pour validation
