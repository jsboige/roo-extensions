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

**Un `append` qui expire n'est PAS un message perdu.** L'ecriture precede la condensation
(`WRITE-FIRST` puis `await condenseIntercom`) : au-dela de 92 %, le meme appel paie en plus une passe
LLM entiere (35 s sur le seul echantillon journalise ; po-2024 rapporte un timeout client a 180 s).
Le message est deja sur disque.

- **Ne jamais retenter** un `append` qui expire : l'ecriture ayant precede, le retry **duplique**.
- **Relire** (`action: "read"`) et verifier que le message y est. Il y sera.
- Ne rapporter une panne que si la relecture **ne le trouve pas**.

Un seul agent paie (verrou #2818 + skip hash #2464) : d'ou un symptome intermittent, alors que le
mecanisme est deterministe.

**Fichier INTERCOM local (DEPRECATED)** : `.claude/local/INTERCOM-{MACHINE}.md` — UNIQUEMENT si MCP dashboard echoue. Append-only, jamais inserer en haut.

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
| `[WAKE-CLAUDE]` | Claude traite immediatement | **IMMEDIATE** |
| `[WAKE-ROO]` | Roo traite immediatement | **IMMEDIATE** |
| `[FRICTION-FOUND]` | Noter pour contexte | Haute |
| `[ERROR]` | Investiger | Haute |
| `[ASK]` | Repondre | Moyenne |
| `[DONE]` | Analyser | Normale |

**Trigger bidirectionnel (#1955) :** `[WAKE-CLAUDE]` reveille le Claude Worker via le dashboard-watcher (poll <1h). `[WAKE-ROO]` reveille le Roo scheduler a son prochain cycle (max 6h). Voir [`docs/harness/reference/bidirectional-trigger.md`](../../docs/harness/reference/bidirectional-trigger.md).

## Regles d'engagement

- **[PROPOSAL] de Roo** → Traiter comme `[TASK]` prioritaire par Claude
- **[ASK] sans [REPLY]** → Repondre AVANT la tache principale
- **Fin de cycle [IDLE]** : Inclure `[SUGGESTION]` pour Claude
- **Contacter Claude** : avant issue GitHub, bloque >30 min, decision architecturale

---
**Historique versions completes :** Git history avant 2026-04-10
