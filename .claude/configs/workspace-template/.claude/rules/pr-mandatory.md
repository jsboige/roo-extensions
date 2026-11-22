# PR obligatoire — zéro push direct sur main

- Tout changement versionné passe par **branche → PR → review → merge**. Aucun push direct
  sur `main`, y compris pour de la doc ou une « petite correction ».
- Le travail se fait dans un **worktree** dédié ; cleanup (worktree + branche) après merge.
  L'état de livraison se lit dans `gh pr view --json state` — jamais dans l'ascendance git
  (le squash-merge la réécrit).
- Fichiers non versionnés (mémoire machine, dashboards, gitignored) : pas de PR nécessaire.
