# INTERCOM - Dashboard RooSync (Canal Principal)

**Version:** 2.0.0 (condensed from 1.0.0, aligned with .claude/rules/intercom-protocol.md)
**MAJ:** 2026-04-08

## Canal principal : Dashboard workspace

```
# Lire (OBLIGATOIRE debut de cycle)
roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 10)

# Ecrire
roosync_dashboard(action: "append", type: "workspace", tags: ["{TYPE}", "roo-scheduler"], content: "Message...")
```

**FALLBACK** (si MCP echoue) : `.claude/local/INTERCOM-{MACHINE}.md` — append-only, jamais inserer en haut.

## Types de messages

| Type | Usage |
| ---- | ----- |
| `DONE` | Tache terminee |
| `TASK` / `PROPOSAL` | Demander/recevoir une tache |
| `INFO` | Update de statut |
| `WARN` / `ERROR` | Avertissement / erreur bloquante |
| `ASK` / `REPLY` | Question / reponse |
| `ACK` | Accuser reception |
| `IDLE` | Fin de cycle sans tache |
| `FRICTION-FOUND` | Friction detectee |

## Regles d'engagement

- **[PROPOSAL] de Claude** → Traiter comme `[TASK]` prioritaire
- **[ASK] sans [REPLY]** → Repondre AVANT la tache principale
- **Fin de cycle [IDLE]** : Inclure `[SUGGESTION]` pour Claude
- **Contacter Claude** : avant issue GitHub, bloque >30 min, decision architecturale

---
**Historique versions completes :** Git history avant 2026-04-08
