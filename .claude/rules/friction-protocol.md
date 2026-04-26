# Protocole de Friction

**Version:** 1.0.0 (slim)
**Issue :** #1033

---

## Principe

**Tout agent rencontrant une friction DOIT la signaler au collectif.** Les skills evoluent par friction REELLE, pas par anticipation theorique.

## Signaler via Dashboard (PRINCIPAL)

```
roosync_dashboard(action: "append", type: "workspace", tags: ["FRICTION", "claude-interactive"], content: "...")
```

Alternative : RooSync `to: "all"` ou GitHub issue `[FRICTION] Description`.

## Criteres d'Approbation

- Probleme REEL (pas theorique)
- Solution minimale et ciblee
- **Rejet si :** feature creep, complexite, probleme theorique

---

**Quand signaler, traitement detaille :** [`docs/harness/reference/friction-protocol-detailed.md`](docs/harness/reference/friction-protocol-detailed.md)
