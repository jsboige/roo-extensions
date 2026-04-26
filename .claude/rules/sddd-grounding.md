# SDDD — Triple Grounding (Obligatoire)

**Version:** 1.0.0 (slim)
**Issue :** #1063

---

## Principe

**SDDD :** Tout travail significatif croise 3 sources :
1. **Semantique** — `codebase_search` + `roosync_search(semantic)` : trouver par concept
2. **Conversationnel** — `conversation_browser` + traces Roo : historique
3. **Technique** — Read, Grep, Glob, Git : code source = verite

**Regle absolue :** Ne jamais se contenter d'une seule source.

## Pattern Bookend (OBLIGATOIRE)

**`codebase_search` en DEBUT et FIN** de chaque tache significative.

| Type de tache | Bookend |
|---------------|---------|
| Feature/fix/investigation | OUI (debut + fin) |
| Mise a jour doc | OUI (debut + fin) |
| Commit/push, reponse question | NON |

## codebase_search — Toujours passer `workspace` explicitement

Requetes en **anglais** avec vocabulaire du code. 4 passes : large → `directory_prefix` → grep exact → reformuler.

## Si un outil SDDD echoue

Signaler via friction : `docs/harness/reference/friction-protocol.md`

---

**Multi-pass protocol, filtres roosync_search, workflow complet :** [`docs/harness/reference/sddd-grounding-detailed.md`](docs/harness/reference/sddd-grounding-detailed.md)
