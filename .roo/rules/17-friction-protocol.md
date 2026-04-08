# Protocole de Friction

**Version:** 2.0.0 (condensed from 1.1.0, aligned with .claude/rules/friction-protocol.md)
**MAJ:** 2026-04-08

## Principe

**Tout agent rencontrant une friction DOIT le signaler au collectif.** Les skills evoluent par friction REELLE, pas theorique.

## Quand signaler

- Outil ne fonctionne pas (timeout, vide, erreur)
- Bookend SDDD sans resultat utile
- Skill/workflow hors protocole
- Doc introuvable malgre triple grounding
- Config ne correspond pas a la documentation

## Comment signaler

### Dashboard workspace (PRINCIPAL)

```
roosync_dashboard(action: "append", type: "workspace", tags: ["FRICTION", "roo-scheduler"], content: "Probleme + Contexte + Impact + Suggestion")
```

### RooSync (friction systeme)

```
roosync_send(action: "send", to: "all", subject: "[FRICTION] Description", body: "...", tags: ["friction"])
```

### Issue GitHub

Title: `[FRICTION] Description` + labels.

## Criteres d'approbation

Resout un probleme REEL. Solution minimale et ciblee. **Rejeter si** : feature creep, complexite, probleme theorique.

---
**Historique versions completes :** Git history avant 2026-04-08
