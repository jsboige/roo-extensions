# Regles Communication Locale et Dashboard (Claude Code)

**Version:** 3.2.0 (mentions v3)
**MAJ:** 2026-04-17

---

## Canal Principal : Dashboard Workspace

**Tout agent DOIT rapporter sur le dashboard `workspace`.** C'est le hub central visible par TOUTES les machines.

Seuls 3 types de dashboards existent : `global`, `machine`, `workspace`. Le type `workspace+machine` a ete SUPPRIME.

### Ecrire

```
roosync_dashboard(action: "append", type: "workspace", tags: ["{DONE|PROGRESS|BLOCKED|INFO}", "claude-interactive"], content: "...")
```

Tags disponibles : `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`, `SUGGESTION`

### Lire

```
roosync_dashboard(action: "read", type: "workspace")
```

Auto-condensation a **50 KB** : le dashboard reste toujours lisible en un seul appel. Pas besoin de `intercomLimit`.

### Fichier INTERCOM local (DEPRECATED)

`.claude/local/INTERCOM-{MACHINE}.md` — utiliser UNIQUEMENT si le MCP dashboard echoue (GDrive offline).
Si utilise : **ordre chronologique** (append-only, jamais inserer en haut, jamais ecraser avec Write).

---

## Mentions structurees et Cross-Post (v3, #1363)

Deux champs orthogonaux sur `append` :

- **`mentions[]`** — notifier des utilisateurs. Chaque entree respecte XOR : `userId` OU `messageId` (jamais les deux, jamais aucun des deux).
- **`crossPost[]`** — repliquer le meme message dans d'autres dashboards, SANS notification. Erreur par cible isolee.

### mentions[]

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

Reference par `messageId` (format v3 `machineId:workspace:ic-ts-rand`) :

```
mentions: [{ messageId: "myia-ai-01:roo-extensions:ic-2026-04-17T0809-3lmh" }]
```

Dedup par `machineId` (plusieurs mentions vers la meme machine = une notification RooSync). Dispatch fire-and-forget (n'echoue pas l'append si RooSync indisponible).

### crossPost[]

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

Self-skip : une cible pointant vers le dashboard source ne duplique pas. Target manquant + `createIfNotExists: false` = entree `{ key, ok: false, error }` dans `result.crossPost`.

### messageId v3

Format : `${machineId}:${workspace}:ic-${ts}-${rand}`. Le split parse sur les **deux premiers** `:` (le 3e segment peut contenir des `-` et `:`).

---

## Worktrees Git (#1364)

**FIX APPLIQUE :** Les agents lancés depuis un worktree (`.claude/worktrees/wt-*`) postent maintenant automatiquement dans le dashboard du workspace parent, pas dans un dashboard spécifique au worktree.

**Comportement auto :**
- Détection : Si le cwd contient `.claude/worktrees/`, l'outil remonte automatiquement au workspace parent
- Contexte préservé : Le champ `author.worktree` contient le nom du worktree (ex: `wt-worker-myia-ai-01-20260413-110726`)
- Dashboard clé : `workspace-roo-extensions` (parent) au lieu de `workspace-wt-worker-*` (worktree)

**Pas d'action requise** des agents — la détection est automatique. Le paramètre `workspace` explicite reste disponible pour les cas particuliers.

---

## Dialogue Bidirectionnel (#657)

### Debut de session

1. Identifier le dernier message de Roo (`[DONE]`, `[IDLE]`, `[ASK]`)
2. Si `[DONE]`/`[IDLE]` sans `[ACK]` de Claude → ecrire `[ACK]`
3. Si Roo idle → `[PROPOSAL]` avec 1-2 taches suggerees
4. Si `[ASK]` sans `[REPLY]` → repondre AVANT de commencer son travail

### Fin de session

- Roo idle : `[PROPOSAL]` avec 1-3 suggestions
- Roo actif : `[INFO]` sur ce que Claude a fait

### Anti-Silence

**NE JAMAIS laisser 2 cycles consecutifs de Roo [IDLE] sans [PROPOSAL].**

---

## Priorite des messages

| Tag | Action | Priorite |
|-----|--------|----------|
| `[WAKE-CLAUDE]` | Traiter immediatement | **IMMEDIATE** |
| `[FRICTION-FOUND]` | Noter pour contexte | Haute |
| `[ERROR]` | Investiger | Haute |
| `[ASK]` | Repondre | Moyenne |
| `[DONE]` | Analyser | Normale |

---

**Historique versions completes :** Git history avant 2026-04-05
