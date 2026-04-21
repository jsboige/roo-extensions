# Guide conversation_browser — Usage et Fix #881

**Version:** 1.0.0 (moved from .claude/rules/)
**Issue:** #1063
**Contexte:** Fix #881 applique — `detailLevel: "NoTools"` maintenant alias vers `Compact`
**MAJ:** 2026-04-21
**Location:** Moved to `docs/harness/reference/` as part of rules consolidation #1606

---

## Point d'Entree OBLIGATOIRE

**TOUJOURS commencer par `list`** pour obtenir les IDs de taches :

```
conversation_browser(action: "list", workspace: "C:/dev/roo-extensions", limit: 20)
```