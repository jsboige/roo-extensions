# Meta-Analyste — Claude Code

**Version:** 1.2.0 (moved from .claude/rules/)
**Issue:** #1375 (cree), #1455 (durcissement hard-reject), #1584 (config drift operational)
**Miroir de :** `.roo/scheduler-workflow-meta-analyst.md` (Roo scheduler, 297 lignes)
**MAJ:** 2026-04-21
**Location:** Moved to `docs/harness/reference/` as part of rules consolidation #1606

---

## ROLE

Observer, analyser, PROPOSER. Le meta-analyste ne dispatche pas, ne trie pas, ne modifie rien.
Les propositions sont des issues GitHub `needs-approval` que le coordinateur ou l'utilisateur traitera.

**Cadence :** Ad-hoc (quand l'utilisateur le demande ou au debut/fin de session coordinateur). Pas de scheduler Claude — contrairement a Roo qui tourne toutes les 72h en `orchestrator-complex`.