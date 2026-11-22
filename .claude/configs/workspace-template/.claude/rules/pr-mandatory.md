# PR obligatoire — zéro push direct sur main

- Tout changement passe par **worktree → PR → review → merge** (squash).
- Anti-double-claim avant de coder (voir `agent-claim.md`).
- Worktree retiré après merge/close ; la branche se supprime **séparément**.
- Jamais de `--no-verify`, jamais de force-push sur branche partagée.
- Pas de PR pour les fichiers non versionnés (mémoire locale, dashboards, gitignorés).
