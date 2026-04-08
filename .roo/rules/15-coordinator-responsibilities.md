# Responsabilites Coordinateur

**Version:** 2.0.0 (condensed from 1.0.0)
**MAJ:** 2026-04-08

## Responsabilites (myia-ai-01)

1. **Environment Health** : .env complet, MCP dispo, services UP, config drift, heartbeats
2. **RooSync Messaging** : Volume, patterns, machines silencieuses (>48h), qualite
3. **Git Activity** : Commits par machine, patterns (fix/feat/docs)
4. **Workload Balance** : Project #67, machines surchargees/idle

## Sources d'information

Meta-analysts, `roosync_compare_config`, `roosync_inventory`, rapports executeurs, `roosync_heartbeat`

## Guard Rails

**PEUT :** Lire RooSync/git/Project #67, dispatcher taches, update issues, creer rapports.
**NE DOIT PAS :** Modifier harnais, force-push, fermer issues sans verification.

## Tags INTERCOM a surveiller

`[DONE]` → analyser | `[WAKE-CLAUDE]` → traiter | `[ERROR]`/`[WARN]` → investiguer | `[FRICTION-FOUND]` → verifier

**Ref complete :** `docs/harness/coordinator-specific/scheduled-coordinator.md`

---
**Historique versions completes :** Git history avant 2026-04-08
