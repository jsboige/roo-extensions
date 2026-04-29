# Dashboard RooSync (Canal Principal)

**Version:** 3.2.0 (synced with .claude/rules/intercom-protocol.md)
**MAJ:** 2026-04-19

## Canal principal : Dashboard workspace

```
# Lire (OBLIGATOIRE debut de cycle)
roosync_dashboard(action: "read", type: "workspace")

# Ecrire
roosync_dashboard(action: "append", type: "workspace", tags: ["{TYPE}", "roo-scheduler"], content: "Message...")
```

**Auto-condensation préemptive à 92% d'utilisation** (≈46 KB, filet de sécurité à 50 KB). Le dashboard reste lisible en un seul appel. Pas besoin de `intercomLimit`.

**FALLBACK** (si MCP echoue) : `.claude/local/INTERCOM-{MACHINE}.md` — append-only, jamais inserer en haut.

## Mentions et Cross-Post (v3, #1363)

Deux champs sur `append` :

- **`mentions[]`** — notifier des utilisateurs. Chaque entree : `userId` OU `messageId` (XOR).
- **`crossPost[]`** — repliquer le message dans d'autres dashboards, SANS notification.

```javascript
// Notifier des machines
roosync_dashboard(action: "append", type: "workspace", content: "...",
  mentions: [
    { userId: { machineId: "po-2023", workspace: "roo-extensions" } },
    { messageId: "myia-ai-01:roo-extensions:ic-2026-04-17T0809-3lmh" }
  ])

// Cross-poster vers global et machine
roosync_dashboard(action: "append", type: "workspace", content: "...",
  crossPost: [{ type: "global" }, { type: "machine", machineId: "po-2023" }])
```

Dedup par `machineId`. Dispatch fire-and-forget. Format messageId v3 : `${machineId}:${workspace}:ic-${ts}-${rand}`.

## Worktrees Git (#1364)

Les agents en worktree (`.claude/worktrees/wt-*`) postent automatiquement dans le dashboard parent. Detection automatique, pas d'action requise.

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
