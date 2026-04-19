# INTERCOM - Dashboard RooSync (Canal Principal)

**Version:** 3.2.0 (synchronized with .claude/rules/intercom-protocol.md v3.2.0)
**MAJ:** 2026-04-19

## Canal principal : Dashboard workspace

Seuls 3 types de dashboards existent : `global`, `machine`, `workspace`. Le type `workspace+machine` a ete SUPPRIME.

```
# Lire (OBLIGATOIRE debut de cycle)
roosync_dashboard(action: "read", type: "workspace")

# Ecrire
roosync_dashboard(action: "append", type: "workspace", tags: ["{TYPE}", "roo-scheduler"], content: "Message...")
```

**Auto-condensation a 85% d'utilisation** (seuil preemptif, declenchee lors de chaque append). Pas besoin de `intercomLimit`.

**FALLBACK** (si MCP echoue) : `.claude/local/INTERCOM-{MACHINE}.md` — append-only, jamais inserer en haut.

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
    { userId: { machineId: "myia-ai-01", workspace: "roo-extensions" }, note: "review please" }
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

## Worktrees Git (#1364)

Les agents lances depuis un worktree (`.claude/worktrees/wt-*`) postent automatiquement dans le dashboard du workspace parent, pas dans un dashboard specifique au worktree.

- Detection : Si le cwd contient `.claude/worktrees/`, l'outil remonte automatiquement au workspace parent
- Contexte preserve : Le champ `author.worktree` contient le nom du worktree
- Dashboard cle : `workspace-roo-extensions` (parent) au lieu de `workspace-wt-worker-*` (worktree)

**Pas d'action requise** des agents — la detection est automatique.

## Types de messages

| Type | Usage |
| ---- | ----- |
| `DONE` | Tache terminee |
| `PROGRESS` | Tache en cours, avance normale |
| `BLOCKED` | Tache bloquee, besoin d'aide |
| `TASK` / `PROPOSAL` | Demander/recevoir une tache |
| `INFO` | Update de statut |
| `WARN` / `ERROR` | Avertissement / erreur bloquante |
| `ASK` / `REPLY` | Question / reponse |
| `ACK` | Accuser reception |
| `IDLE` | Fin de cycle sans tache |
| `SUGGESTION` | Proposition de tache pour Claude |
| `FRICTION-FOUND` | Friction detectee |

## Dialogue Bidirectionnel (#657)

### Debut de session

1. Identifier le dernier message de Claude (`[DONE]`, `[IDLE]`, `[ASK]`)
2. Si `[DONE]`/`[IDLE]` sans `[ACK]` de Roo → ecrire `[ACK]`
3. Si Claude idle → `[PROPOSAL]` avec 1-2 taches suggerees
4. Si `[ASK]` sans `[REPLY]` → repondre AVANT de commencer la tache principale

### Fin de session

- Claude idle : `[PROPOSAL]` avec 1-3 suggestions
- Claude actif : `[INFO]` sur ce que Roo a fait

### Anti-Silence

**NE JAMAIS laisser 2 cycles consecutifs de Claude [IDLE] sans [PROPOSAL].**

## Priorite des messages

| Tag | Action | Priorite |
| ----- | -------- | ---------- |
| `[WAKE-CLAUDE]` | Traiter immediatement | **IMMEDIATE** |
| `[FRICTION-FOUND]` | Noter pour contexte | Haute |
| `[ERROR]` | Investiger | Haute |
| `[ASK]` | Repondre | Moyenne |
| `[DONE]` | Analyser | Normale |

## Regles d'engagement

- **[PROPOSAL] de Roo** → Traiter comme `[TASK]` prioritaire par Claude
- **[ASK] sans [REPLY]** → Repondre AVANT la tache principale
- **Fin de cycle [IDLE]** : Inclure `[SUGGESTION]` pour Claude
- **Contacter Claude** : avant issue GitHub, bloque >30 min, decision architecturale

---
**Historique versions completes :** Git history avant 2026-04-10
