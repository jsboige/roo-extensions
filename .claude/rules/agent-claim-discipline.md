# Agent Claim Discipline — No Unverified Success

**Version:** 1.2.0 (slim)
**Issues :** #1605, #1666 Phase A2

---

## Regle Absolue

**Un agent ne peut PAS declarer un travail termine en citant un artefact git sans que cet artefact soit verifiable a l'instant du rapport.**

## Discipline requise — Pour l'agent qui rapporte

**Avant** de poster `[DONE]`/`[RESULT]` avec un artefact :

1. **Commit** : `git cat-file -e <SHA> && git branch --contains <SHA>` — sinon NE PAS le citer
2. **Push** : `git ls-remote origin <BRANCH>` — doit retourner une ligne
3. **PR** : `gh pr view <N> --json state,url` — doit retourner state + url valide
4. **Tests** : Le output vitest doit etre visible dans les logs

## Pour l'agent qui recoit/relaie

**Ne JAMAIS** traiter un artefact cite comme acquis sans verification :
- Coordinateur : verifier avant d'archiver
- Trieur : verifier PR est MERGED (pas OPEN)
- Meta-analyste : "reussites rapportees" = donnees brutes a qualifier

---

**Garde-fous harness (worker scripts, spawn/poll, sanctions) :** [`docs/harness/reference/agent-claim-discipline-detailed.md`](docs/harness/reference/agent-claim-discipline-detailed.md)

**Principe condense** : *"Pas de SHA sans `git cat-file -e`. Pas de PR sans URL 200. Pas de `[DONE]` sur une promesse."*
