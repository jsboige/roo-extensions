# SDDD Protocol (Global)

**Triple grounding obligatoire pour tout travail significatif.**

## 3 sources a croiser
1. **Technique** — Code source (Read, Grep, Glob, Git)
2. **Conversationnel** — `conversation_browser(action: "list")` puis `view`
3. **Semantique** — `codebase_search` + `roosync_search(action: "semantic")`

## Pattern Bookend
`codebase_search` en DEBUT et FIN de chaque tache significative.

**DEBUT de tache :**
- Trouver la documentation existante sur le sujet (README, docs/, CLAUDE.md, issues)
- Verifier que la tache n'a pas deja ete faite (code existant, PR precedente)
- Identifier le contexte : qui a travaille dessus, quelles decisions ont ete prises

**FIN de tache :**
- Verifier que le travail est retrouvable (code indexe, tests presents)
- Confirmer que la documentation afferente a ete mise a jour (celle trouvee en debut de tache via codebase_search)
- S'assurer que le travail est coherent avec le reste du projet

## codebase_search
- **TOUJOURS** passer `workspace` explicitement
- Requetes en **anglais** avec vocabulaire du code
- 4 passes : large → directory_prefix → grep exact → reformuler

## conversation_browser
- **`list` est OBLIGATOIRE en premier** — sans IDs, les autres actions echouent
- `summarize_type: "trace"` recommande (pas "synthesis")

## Scepticisme
Ne JAMAIS propager une affirmation non verifiee. Qualifier : VERIFIE / RAPPORTE / SUPPOSE.
