# INTERCOM - Dashboard RooSync (Canal Principal)

**Version:** 3.1.0 (condensation threshold 85%, synchronized with .claude/rules/intercom-protocol.md v3.3.0)
**MAJ:** 2026-04-19

## Canal principal : Dashboard workspace

```
# Lire (OBLIGATOIRE debut de cycle)
roosync_dashboard(action: "read", type: "workspace")

# Ecrire
roosync_dashboard(action: "append", type: "workspace", tags: ["{TYPE}", "roo-scheduler"], content: "Message...")
```

**Auto-condensation a 85% d'utilisation** (seuil preemptif, declenchee lors de chaque append) : le dashboard reste lisible en un seul appel. Pas besoin de `intercomLimit`.

**FALLBACK** (si MCP echoue) : `.claude/local/INTERCOM-{MACHINE}.md` — append-only, jamais inserer en haut.

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
