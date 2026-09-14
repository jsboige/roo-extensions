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

### Un `append` qui expire n'est PAS un message perdu -- relire, jamais retenter

`handleAppend` **ecrit d'abord**, condense ensuite -- et l'attend. Au timeout, le message est donc
*generalement* deja sur disque, mais pas toujours : mesure du 02/07/2026, **3 appends expires,
1 seul ecrit**. Ce n'est *ni* « c'est toujours ecrit » *ni* « ce n'est jamais ecrit ».

1. **Ne jamais retenter a l'aveugle** -- le retry **duplique** sur un canal que sept machines lisent.
2. **Relire** (`action: "read"`, `section: "intercom"`) : **seule la relecture tranche.**
3. Re-poster **seulement** si la relecture ne trouve pas le message ; ne rapporter une panne que
   dans ce cas.

Au-dela de 92 %, le **meme appel** paie en plus une passe de condensation LLM entiere (facteur
**~75x** mesure, dont 99,4 % pour le bloc `## Status`). Un seul agent paie a la fois (#2818, #2464),
d'ou un symptome intermittent alors que le mecanisme est deterministe : c'est une **marge**, pas un bug.

**Mesures completes, mecanisme WRITE-FIRST, A/B :** [`docs/harness/reference/intercom-append-timeout.md`](../../docs/harness/reference/intercom-append-timeout.md)

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
