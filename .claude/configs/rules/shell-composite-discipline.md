# Shell composé — jamais `cd <chemin>` ni `rm` dans une commande composée

**Issue :** #4214 (mandat user 15/10) — en mode bypass, une commande Bash composée
`cd <autre répertoire> && … rm …` suspend la session sur une attente d'approbation
**silencieuse** : 2-3 agents gelés/jour en flotte (mesure claudish#474 : 49 attentes
≥ 2 min/jour sur cette forme, médiane 121 s). La garde PreToolUse `guard-bash-composite`
(#4244, `scripts/hooks/guard-bash-composite.js`) refuse cette conjonction — la règle
évite l'essai et couvre la famille entière, pas seulement la conjonction.

1. **Jamais `cd <chemin>` dans une commande composée.** Opérer depuis le répertoire
   courant : `git -C <chemin> …`, chemins explicites, ou `cd` en commande isolée.
2. **Jamais `rm` dans une commande composée.** Suppression en commande isolée sur
   fichiers nommés ; worktree → `git worktree remove` ; jamais `rm -rf` sur un chemin absolu.

Un refus du garde = réécriture attendue (son message la donne mot pour mot), jamais un
contournement. Rollback opérateur uniquement : `BASH_COMPOSITE_GUARD=0`.

**Détail (câblage, incidents fondateurs) :** `docs/harness/reference/bash-composite-guard.md`.
