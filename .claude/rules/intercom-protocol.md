# Regles Communication Dashboard (Claude Code)

**Version:** 3.2.0 (slim)

---

## Canal Principal : Dashboard Workspace

**Tout agent DOIT rapporter sur le dashboard `workspace`.**

Seuls 3 types : `global`, `machine`, `workspace`.

### Ecrire / Lire

```
roosync_dashboard(action: "append", type: "workspace", tags: ["DONE", "claude-interactive"], content: "...")
roosync_dashboard(action: "read", type: "workspace")
```

Tags : `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`, `PROGRESS`

**Team Pipeline tags (#1853) :** `team-plan`, `team-prd`, `team-exec`, `team-verify`, `team-fix`

Auto-condensation preemptive a 92% (~46 KB).

### Fichier INTERCOM local (DEPRECATED)

`.claude/local/INTERCOM-{MACHINE}.md` — UNIQUEMENT si MCP dashboard echoue.

## Dialogue Bidirectionnel

- Debut session : identifier dernier Roo message, ecrire `[ACK]` si necessaire, `[PROPOSAL]` si idle
- Fin session : `[PROPOSAL]` avec suggestions si Roo idle
- **Anti-Silence :** NE JAMAIS laisser 2 cycles Roo `[IDLE]` consecutifs sans `[PROPOSAL]`.

## Priorite

| Tag | Action |
|-----|--------|
| `[WAKE-CLAUDE]` | IMMEDIAT |
| `[ERROR]` | Haute |
| `[ASK]` | Moyenne |
| `[DONE]` | Normale |

---

## Team Pipeline Reporting (#1853)

**Pour les tâches complexes (>3 fichiers OU >50 LOC), les agents DOIVENT :**

1. **Utiliser le paramètre `teamStage` dans les rapports dashboard :**
```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["PROGRESS", "team-exec"],
  teamStage: "team-exec",
  content: "..."
)
```

2. **Suivre l'ordre des stages :** team-plan → team-prd → team-exec → team-verify → [DONE]
   - team-fix loop si team-verify échoue

3. **Stages Team disponibles :**
   - `team-plan` : Planification (sous-tâches, dépendances)
   - `team-prd` : Clarification exigences et contraintes
   - `team-exec` : Exécution de l'implémentation
   - `team-verify` : Vérification (build + tests)
   - `team-fix` : Correction des problèmes (loop)
   - `none` : Pas de stage Team (tâches simples)

4. **Tags recommandés par stage :**
   - team-plan → `["PROGRESS", "team-plan"]`
   - team-prd → `["PROGRESS", "team-prd"]`
   - team-exec → `["PROGRESS", "team-exec"]`
   - team-verify → `["DONE", "team-verify"]` (succès) ou `["PROGRESS", "team-verify"]` (échec)
   - team-fix → `["PROGRESS", "team-fix"]`

---

**Mentions v3, crossPost, worktrees auto-detection :** [`docs/harness/reference/intercom-v3-mentions.md`](docs/harness/reference/intercom-v3-mentions.md)
