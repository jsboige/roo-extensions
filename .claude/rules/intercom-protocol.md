# Regles Communication Dashboard (Claude Code)

**Version:** 3.5.0 (slim 2 — mesures append-timeout relocalisées, #2368)
**MAJ:** 2026-09-26

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

Auto-condensation preemptive a 92% (~46 KB) — l'action `condense` est retiree du schema, aucune intervention manuelle necessaire.

### Lecture complete OBLIGATOIRE (#2306)

**NE JAMAIS lire uniquement `section: "status"`.** La section status est un snapshot statique qui peut etre perime.

- **OBLIGATOIRE** : `roosync_dashboard(action: "read", type: "workspace", section: "all")` ou au minimum `section: "intercom", intercomLimit: 20`
- Le status est une boussole, pas une verite absolue. Les decisions se prennent sur les messages intercom recents.

### Un `append` qui expire n'est PAS un message perdu -- relire, jamais retenter

`handleAppend` **ecrit d'abord**, condense ensuite — au timeout le message est *generalement* deja sur disque, mais pas toujours (mesure 02/07/2026 : 3 appends expires, 1 seul ecrit). Ce n'est *ni* « toujours ecrit » *ni* « jamais ecrit ».

1. **Ne jamais retenter a l'aveugle** -- le retry **duplique** sur un canal que sept machines lisent.
2. **Relire** (`action: "read"`, `section: "intercom"`) : **seule la relecture tranche.**
3. Re-poster **seulement** si la relecture ne trouve pas le message ; ne rapporter une panne que dans ce cas.

Au-dela de 92 %, le meme appel paie en plus une passe de condensation LLM entiere (facteur **~75x** mesure ; un seul agent paie a la fois, #2818/#2464) — c'est une **marge, pas un bug**. **Mesures completes, mecanisme WRITE-FIRST, A/B :** [`intercom-append-timeout.md`](../../docs/harness/reference/intercom-append-timeout.md)

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
