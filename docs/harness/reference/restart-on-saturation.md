# Restart-on-Saturation — Runbook empty-response (#2578)

**Issue:** #2578
**MAJ:** 2026-06-24
**Scope:** Detection + auto-restart procedure for saturated Claude Code worker sessions crashing with empty responses.

---

## Contexte

Sur les machines exécutantes `myia-po-2024/2025/2026`, des sessions `claude -p` atteignaient 86-100 MB de traces JSONL, provoquant des crashes silencieux : la gateway renvoyait un event `result` avec `subtype="success"` mais **aucun contenu** (ni texte, ni tool calls). Le `start-claude-worker.ps1` détectait `ReceivedResultEvent=true` → `StreamValid=true` → rapportait « ✅ SUCCÈS » trompeur. Les tâches scheduler échouaient sans output exploitable.

## Mandate user 2026-06-19 — SANCTUAIRE

**Les traces agentiques sont sanctuarisées. JAMAIS de GC, JAMAIS de suppression.**

- ❌ ~~GC automatique des sessions Roo >80 MB~~ — STRUCK, viole le mandat.
- ❌ ~~Suppression des sessions .jsonl~~ — INTERDIT.
- ✅ **Restart-on-saturation** : la session saturée est abandonnée en place, et la prochaine invocation `claude -p` démarre avec une fenêtre de contexte fraîche.
- ✅ **Split / externalisation SANS PERTE** : une grosse session se segmente, elle ne se jette pas. Pour archivage non-destructif, voir [`archive-large-sessions.ps1`](../../../scripts/claude/archive-large-sessions.ps1) (copy + verify, jamais delete).

---

## Detection — comment le worker reconnaît une empty response

`start-claude-worker.ps1` → `Invoke-Claude`, dans la boucle Ralph Wiggum :

```powershell
# Flag par itération
$AnyContentReceived = $false   # true si un text_delta OU tool_use est vu

# Après la fin du stream, AVANT le VERIFY block :
if ($ReceivedResultEvent -and $FinalResultText.Length -eq 0 -and -not $AnyContentReceived) {
    $ConsecutiveEmptyResponses++
    # ... log EMPTY_RESPONSE
    if ($ConsecutiveEmptyResponses -ge 2) {
        $Continue = $false   # break loop
    }
}
```

### Trois signaux distincts

| Signal | `ReceivedResultEvent` | `subtype` | `FinalResultText` | `AnyContentReceived` | Cause |
|--------|----------------------|-----------|-------------------|----------------------|-------|
| **Succès normal** | true | success | >0 OU 0 (tool-only) | true | — |
| **Coupure gateway** (#2571) | true | error_* | variable | variable | budget, runtime error |
| **Stream invalide** (#1433) | false / parse errors | — | — | — | corruption传输 |
| **Empty-response saturation** (#2578) | true | success | 0 | **false** | session saturée |

Le cas #2578 est le seul où la gateway **prétend le succès** mais n'a rien émis. C'est le signature de saturation.

## Auto-restart — comment ça marche sans intervention

1. Itération 1 vide → log `EMPTY_RESPONSE`, counter = 1, on continue
2. Itération 2 vide → counter = 2, **break loop** (plus de budget brûlé)
3. `Invoke-Claude` retourne `emptyResponseCount=2`, `success=$false`
4. `Check-Escalation` détecte `emptyResponseCount >= 2` → **skip escalation** (sinon haiku→sonnet sature pareil)
5. `Report-Results` poste un rapport avec `**Empty responses:** ⚠️ 2 ...`
6. Worker se termine normalement
7. **Prochain cycle scheduler** → `claude -p` invoque une **session fraîche** avec fenêtre de contexte clean = restart automatique

Les traces de la session saturée restent **intactes** sur disque dans `~/.claude/projects/<hash>/`.

---

## Procédure manuelle (si auto-restart ne suffit pas)

### Diagnostic — identifier une session saturée

```powershell
# Lister les sessions > 80 MB
Get-ChildItem "$env:USERPROFILE\.claude\projects" -Directory -Recurse -Depth 1 -ErrorAction SilentlyContinue |
    Where-Object { (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum -gt 80MB } |
    Select-Object FullName, @{N='SizeMB';E={[math]::Round((Get-ChildItem $_.FullName -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)}}
```

### Restart manuel d'une session interactive (VS Code)

1. Dans VS Code, fermer l'onglet de la session saturée (Cmd/Ctrl+W)
2. Ouvrir une nouvelle session Claude Code (Cmd/Ctrl+Esc)
3. La session fraîche démarre avec contexte clean

**NE JAMAIS** : supprimer `.jsonl` dans `~/.claude/projects/`, vider `globalStorage`, ou purger l'historique.

### Split non-destructif d'une très grosse session

Pour archiver une session > 100 MB SANS PERTE :

```powershell
# 1. Trouver la session
$session = "C:\Users\jsboi\.claude\projects\<hash>\<session-id>"

# 2. Copier (jamais déplacer) vers archive externe
$archive = "D:\Archives\claude-sessions\$(Split-Path $session -Leaf)"
Copy-Item -Path $session -Destination $archive -Recurse

# 3. Vérifier l'intégrité (byte-count)
$src = (Get-ChildItem $session -Recurse -File | Measure-Object Length -Sum).Sum
$dst = (Get-ChildItem $archive -Recurse -File | Measure-Object Length -Sum).Sum
if ($src -eq $dst) { Write-Host "OK: archive matches source" -ForegroundColor Green }
else { Write-Host "MISMATCH: do NOT delete source" -ForegroundColor Red; exit 1 }

# 4. SEULEMENT après vérification : laisser la source en place (sanctuary)
# La session reste sur disque, elle ne gêne plus car le worker démarre une session fraîche.
```

Voir aussi [`archive-large-sessions.ps1`](../../../scripts/claude/archive-large-sessions.ps1) pour une automatisation.

---

## Checklist ops post-incident

Quand un crash empty-response est rapporté :

- [ ] Confirmer via log worker : `EMPTY_RESPONSE #2578` apparaît ≥ 2 fois consécutives
- [ ] Vérifier que `Check-Escalation` a bien skip l'escalation (sinon haiku→sonnet a saturé aussi)
- [ ] Confirmer que le prochain cycle scheduler a démarré une session fraîche (log worker devrait montrer un stream normal)
- [ ] **NE PAS** supprimer la session saturée — elle reste en place pour audit
- [ ] Si pattern récurrent (> 2x en 24h) : investiguer la cause racine (souvent : prompt trop volumineux, MCP tools trop bavards, ou un worktree avec trop de fichiers non-commités)
- [ ] Documenter l'incident dans MEMORY.md avec taille session + machine + cause

## Anti-patterns INTERDITS

- ❌ `Remove-Item` sur `.jsonl` de session
- ❌ "Cleanup" automatisé des sessions > N MB
- ❌ Élaguer le `.claude/projects/` pour gagner de l'espace
- ❌ Archiver SANS vérifier byte-count source == destination
- ❌ Escalader le modèle sur empty-response (saturerait le modèle supérieur pareil)

---

**Référence technique :** [`start-claude-worker.ps1`](../../../scripts/scheduling/start-claude-worker.ps1) `Invoke-Claude` (détection + break), `Check-Escalation` (skip escalation), `Report-Results` (surface dans le rapport).
