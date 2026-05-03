# Bidirectional Trigger — [WAKE-CLAUDE] / [WAKE-ROO]

**Version:** 1.0.0
**Issue:** #1955 (Claude→Roo direction), #1954 (Claude side dispatcher fix)
**MAJ:** 2026-05-03

---

## Resume

Mecanisme de reveil croise entre les deux agents principaux du cluster :

- **`[WAKE-CLAUDE]`** : Roo signale une demande urgente au Claude Worker. Detecte par le `dashboard-watcher` (poll <1h), spawn `claude -p` immediat.
- **`[WAKE-ROO]`** : Claude Code signale une demande urgente au Roo scheduler. Detecte par le scheduler `orchestrator-simple` au prochain cycle (max 6h).

```
Claude Code --[WAKE-ROO]--> Dashboard --> Roo Scheduler (IMMEDIATE, max 6h)
    ^                                      |
    +--------[WAKE-CLAUDE]------------------+
              (poll-dashboard.ps1, ~1h interval)
```

---

## Quand l'utiliser

### Claude → Roo (`[WAKE-ROO]`)

- PR cree et review Roo demandee
- Tache delegue qui necessite execution immediate (build, test, deploy)
- Conflit git a resoudre par Roo `-complex`
- Question architecturale necessitant input Roo

### Roo → Claude (`[WAKE-CLAUDE]`)

- Tache complexe escaladee de Roo vers Claude (echec `-simple` ou `-complex`)
- Decision strategique requise (architecture, API design)
- Bug critique a investigation profonde
- Coordination multi-machine necessitant Claude

---

## Usage

### Cote Claude (Claude → Roo)

```javascript
// Apres avoir cree une PR ou termine une tache necessitant suivi Roo
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["WAKE-ROO"],
  content: "PR #1961 creee — review Roo demandee. CI 3/3 green, naming inconsistency fixee."
)
```

Roo detecte le tag a son prochain cycle (max 6h), traite IMMEDIATEMENT, poste `[ACK]`.

### Cote Roo (Roo → Claude)

```javascript
// Roo escalade une tache vers Claude
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["WAKE-CLAUDE"],
  content: "Issue #XXXX necessite refactor architectural — escalade vers Claude."
)
```

Claude Worker (via `dashboard-watcher` cron) detecte le tag dans l'heure, spawn `claude -p` qui traite la demande.

---

## Mecanique technique

### Cote Claude Worker (`[WAKE-CLAUDE]`)

- **Script** : [`scripts/dashboard-scheduler/poll-dashboard.ps1`](../../../scripts/dashboard-scheduler/poll-dashboard.ps1)
- **AllowedTags par defaut** : `ASK,TASK,BLOCKED,ORDER,PING,URGENT,WAKE-CLAUDE`
- **Override env var** : `DASHBOARD_WATCHER_TAGS` (unifie wrapper + script, #1961)
- **Frequence poll** : ~1h (via Task Scheduler Windows)
- **Action** : Spawn `claude -p` avec contexte du message

### Cote Roo Scheduler (`[WAKE-ROO]`)

- **Workflow** : [`.roo/scheduler-workflow-executor.md`](../../../.roo/scheduler-workflow-executor.md), [`.roo/scheduler-workflow-coordinator.md`](../../../.roo/scheduler-workflow-coordinator.md)
- **Detection** : Step 1 (lecture dashboard), tag `[WAKE-ROO]` recherche en priorite
- **Frequence cycle** : Variable (configure via Task Scheduler, typique 6h)
- **Action** : Traiter contenu IMMEDIATEMENT, `[ACK]` dashboard, escalader vers `-complex` si necessaire

---

## Garde-fous

### Anti-saturation

- **Claude side** : `dashboard-watcher` evite le re-spawn si meme message deja traite (lock file `.claude/locks/watcher-{workspace}.lastack`)
- **Roo side** : Roo poste `[ACK]` pour signaler le traitement, evitant qu'un autre cycle re-traite le meme message

### Anti-loop

- Ne JAMAIS poster `[WAKE-ROO]` en reponse a `[WAKE-CLAUDE]` et inversement, sauf nouvelle demande de fond
- Un `[ACK]` ferme le cycle. Pas de relance automatique.

### Priorite vs autres tags

- `[WAKE-*]` est **TOUJOURS prioritaire** sur `[TASK]`, `[PROPOSAL]`, `[ASK]`, `[INFO]`
- Si plusieurs `[WAKE-*]` simultanes : traiter par ordre chronologique (timestamp)
- Si `[WAKE-CLAUDE]` ET `[WAKE-ROO]` simultanes : chaque agent traite le sien

---

## Test du systeme

### Verifier cote Claude

```powershell
# Poster un test
roosync_dashboard(action: "append", type: "workspace", tags: ["WAKE-CLAUDE"], content: "TEST trigger Claude")

# Verifier que dashboard-watcher detecte
.\scripts\dashboard-scheduler\poll-dashboard.ps1 -Workspaces roo-extensions -Stub
# Doit afficher : [INFO] Actionable message detected: WAKE-CLAUDE
```

### Verifier cote Roo

```javascript
// Roo, a son prochain cycle :
roosync_dashboard(action: "read", type: "workspace")
// Doit voir le tag [WAKE-ROO] et traiter selon Decision Etape 1
```

---

## Historique

- **2026-05-03 (#1954)** : Fix initial `WAKE-CLAUDE` absent du `AllowedTags` par defaut. PR #1961.
- **2026-05-03 (#1961)** : Naming env var unifie `DASHBOARD_WATCHER_TAGS` (wrapper + script).
- **2026-05-03 (#1955)** : Symetrique `[WAKE-ROO]` ajoute aux workflows Roo. Cette PR.

---

## References

- [`.roo/rules/02-dashboard.md`](../../../.roo/rules/02-dashboard.md) — Tableau des priorites
- [`.claude/rules/intercom-protocol.md`](../../../.claude/rules/intercom-protocol.md) — Protocole dashboard cote Claude
- [`scripts/dashboard-scheduler/poll-dashboard.ps1`](../../../scripts/dashboard-scheduler/poll-dashboard.ps1) — Watcher Claude side
