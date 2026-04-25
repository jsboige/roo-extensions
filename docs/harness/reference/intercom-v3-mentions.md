# Mentions Structurees et Cross-Post — Reference Detaillee

**Version:** 3.2.0
**Issue :** #1363
**Source :** `.claude/rules/intercom-protocol.md` (version slim)

---

## Mentions v3 — Utilisation Detaillee

### mentions[] par userId

```
roosync_dashboard(
  action: "append", type: "workspace",
  content: "Review requested",
  mentions: [
    { userId: { machineId: "po-2023", workspace: "roo-extensions" } },
    { userId: { machineId: "po-2024", workspace: "roo-extensions" }, note: "review please" }
  ]
)
```

### mentions[] par messageId (reference croisee)

Format messageId v3 : `${machineId}:${workspace}:ic-${ts}-${rand}`

```
mentions: [{ messageId: "myia-ai-01:roo-extensions:ic-2026-04-17T0809-3lmh" }]
```

**Parsing :** Le split parse sur les **deux premiers** `:` (le 3e segment peut contenir des `-` et `:`).

**XOR :** Chaque entree respecte `userId` OU `messageId` (jamais les deux, jamais aucun des deux).

**Dedup :** Par `machineId` (plusieurs mentions vers la meme machine = une notification RooSync).

**Dispatch :** Fire-and-forget (n'echoue pas l'append si RooSync indisponible).

---

## Cross-Post — Replication Multi-Dashboard

```
roosync_dashboard(
  action: "append", type: "workspace",
  content: "Infra-wide announcement",
  crossPost: [
    { type: "global" },
    { type: "machine", machineId: "po-2023" }
  ],
  createIfNotExists: true
)
```

- **Self-skip :** Une cible pointant vers le dashboard source ne duplique pas.
- **Target manquant :** `createIfNotExists: false` = entree `{ key, ok: false, error }` dans `result.crossPost`.
- **Erreur isolee :** Erreur par cible, pas globale.

---

## Worktrees Git — Comportement Auto (#1364)

Les agents lances depuis un worktree (`.claude/worktrees/wt-*`) postent automatiquement dans le dashboard du workspace parent.

- **Detection :** Si le cwd contient `.claude/worktrees/`, l'outil remonte automatiquement au workspace parent
- **Contexte preserve :** Le champ `author.worktree` contient le nom du worktree
- **Dashboard cible :** `workspace-roo-extensions` (parent) au lieu de `workspace-wt-worker-*`

**Pas d'action requise** des agents. Le parametre `workspace` explicite reste disponible pour les cas particuliers.
