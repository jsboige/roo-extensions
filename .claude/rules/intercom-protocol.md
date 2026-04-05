# Regles Communication Locale et Dashboard (Claude Code)

**Version:** 3.0.0 (condensed from 2.1.0)
**MAJ:** 2026-04-05

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
