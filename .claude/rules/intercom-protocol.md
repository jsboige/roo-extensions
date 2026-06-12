# Regles Communication Dashboard (Claude Code)

**Version:** 3.4.0 (slim)
**MAJ:** 2026-05-23 (condense action removed from tool)

---

## Canal Principal : Dashboard Workspace

**Tout agent DOIT rapporter sur le dashboard `workspace`.**

Seuls 3 types : `global`, `machine`, `workspace`.

### Ecrire / Lire

```
roosync_dashboard(action: "append", type: "workspace", tags: ["DONE", "claude-interactive"], content: "...")
roosync_dashboard(action: "read", type: "workspace")
```

Tags : `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`

Auto-condensation preemptive a 92% (~46 KB).

### Lecture complete OBLIGATOIRE (#2306)

**NE JAMAIS lire uniquement `section: "status"`.** La section status est un snapshot statique qui peut etre perime.

- **OBLIGATOIRE** : `roosync_dashboard(action: "read", type: "workspace", section: "all")` ou au minimum `section: "intercom", intercomLimit: 20`
- Le status est une boussole, pas une verite absolue. Les decisions se prennent sur les messages intercom recents.

### Condensation

L'action `condense` a ete **retiree du schema** — elle n'est plus disponible. L'auto-condensation preemptive a 92% (~46 KB) gere l'espace de maniere optimale. Aucune intervention manuelle necessaire.

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

**Mentions v3, crossPost, worktrees auto-detection :** [`docs/harness/reference/intercom-v3-mentions.md`](../../docs/harness/reference/intercom-v3-mentions.md)
