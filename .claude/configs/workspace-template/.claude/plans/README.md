# Plans / Progress — convention (optionnelle)

Référence : **ADR 015** (roo-extensions `docs/harness/adr/015-plans-progress-convergence-coursia.md`)
et règle `plans-progress-usage.md`.

Un chantier long crée optionnellement `.claude/plans/<id>.md` (plan humain) et
`.claude/progress/<id>.json` (état machine-readable). Justifié si **au moins un** :

1. Durée inter-sessions (survit à un redémarrage).
2. Reprise automatique (un script/agent reprend où il s'est arrêté).
3. Multi-agents coordonnés au-delà du dashboard.

Hors de ces trois cas : **ne crée pas de plan/progress** — Project + issue + branche suffisent.
