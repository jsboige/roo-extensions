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

**Quand le timeout se produit, le message est deja sur disque.** `handleAppend` ecrit d'abord
(`// === WRITE-FIRST: persist message to disk immediately ===`), *puis* declenche la condensation si
le dashboard depasse 92 % -- et il l'**attend** (`await condenseIntercom`, `dashboard.ts`). Le
commentaire du code le dit : l'append incremental est *"the authoritative state -- no message loss"*.

Sous 92 % ton `append` coute quelques ms ; a partir de 92 % le **meme appel** paie en plus une passe
de condensation LLM entiere. **Mesure directe (ai-01, 01/09/2026)** : append total **45,3 s**, dont
**1,9 s d'ecriture** et **42,3 s de condensation** -- soit **93 % du temps passe APRES que le message
soit devenu durable**. Dans ces 42,3 s, l'appel LLM du bloc `## Status` pese a lui seul **99,4 %**.
po-2024 rapporte (c.327, non reverifie ici) un timeout client a **180 s** sur son propre append.
Cet appel-ci n'a pas expire ; le point n'est pas qu'il expire toujours, c'est que le meme appel coute
~24x plus cher au-dela du seuil. L'ordre de grandeur varie ; la propriete qui suit, non.

**Conduite a tenir quand un `append` expire :**

1. **Ne jamais retenter a l'aveugle** -- si l'ecriture a eu lieu, le retry **duplique** sur un canal
   que sept machines lisent.
2. **Relire** (`action: "read"`, `section: "intercom"`) : **seule la relecture tranche.** Ce n'est
   *ni* « c'est toujours ecrit » *ni* « ce n'est jamais ecrit ». Mesure du 02/07/2026 sur
   `workspace-myia-open-webui` : **3 appends expires a 300 s, 1 seul avait ete ecrit.** Le
   `WRITE-FIRST` rend l'ecriture *anterieure* a la condensation, pas *garantie* : l'appel peut aussi
   expirer avant elle.
3. Re-poster **seulement** si la relecture ne trouve pas le message ; ne rapporter une panne que dans
   ce cas.

Un seul agent paie : verrou inter-processus (#2818) + skip sur hash (#2464). Les autres appends
passent en quelques ms pendant ce temps, d'ou un symptome **intermittent et irreproductible** alors
que le mecanisme est parfaitement deterministe. C'est une **marge**, pas un bug.

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
