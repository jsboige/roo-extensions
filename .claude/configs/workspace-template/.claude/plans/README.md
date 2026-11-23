# Plans / Progress — convention optionnelle (ADR 015)

La convention complète vit côté roo-extensions : `.claude/rules/plans-progress-usage.md` et
`docs/harness/reference/plans-progress-schema.md` (ADR 015). Ce répertoire ne se remplit
que si elle s'applique.

**Les 3 critères — créer un plan/progress seulement si AU MOINS UN tient :**

1. **Durée inter-sessions** — le chantier survit à un redémarrage de session.
2. **Reprise automatique** — un script/agent doit pouvoir reprendre là où il s'était arrêté.
3. **Multi-agents coordonnés** — plusieurs agents partagent un état structuré au-delà du
   dashboard.

Hors de ces cas : Project + issues + branches suffisent. **Le défaut est l'absence.**

Rappels de forme si un chantier s'ouvre :

- `.claude/plans/<id>.md` — plan lisible humainement, journal de sessions append-only.
- `.claude/progress/<id>.json` — état machine-readable ; `status: "completed"` exige
  `completed_at` (et `metric_after` si chantier à métrique) — un `completed` sans
  `completed_at` est un mensonge.
- Écritures atomiques (`.tmp` + rename) ; pas d'écriture automatique par hook.
