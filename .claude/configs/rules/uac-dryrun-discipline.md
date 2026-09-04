# UAC & Dry-Run Discipline (Global)

**Scope :** toutes les sessions, tous les workspaces, toutes les machines (Claude Code + workers schedulés).
**Statut :** arbitrage USER direct du 2026-08-27 (incident CoursIA po-2024) — règle ferme, pas une proposition à débattre. Interprétation floue -> `[ASK]` AVANT de livrer.

**Pourquoi :** la disponibilité user est limitée (6 machines x 4-8 workspaces). Une fenêtre UAC consommée par un script buggé coûte une demi-journée d'attente. Un script UAC-touching sans dry-run = `[BLOCKED]` avec motif.

## Règle 1 — UAC : UN seul par lane, jamais une séquence

- Batcher les élévations en **une seule passe** (multi-scripts via `-ArgumentList`, ou wrapper dédié).
- Annoncer **à l'avance** sur le dashboard la liste exhaustive des UAC requis.
- Documenter ce que l'user doit faire pendant la fenêtre UAC (ex. cocher « toujours autoriser »).
- Tester en non-élevé d'abord quand c'est possible (cmd sans `-Verb RunAs`).

## Règle 2 — Dry-run EXIGÉ avant tout geste UAC-touching

Scripts concernés : schtasks (`Register/Unregister-ScheduledTask`), ACL/sécurité (`icacls`, `Set-Acl`), écritures `Program Files`/`Windows`/HKLM, install/désinstall service/driver, spawn `-Verb RunAs`/`sudo`, suppression de fichier protégé ou worktree sale.

- PowerShell : `-WhatIf` natif ou `$WhatIfPreference` ; Bash : `--dry-run` ou mode echo-only.
- **La sortie du dry-run est postée sur le dashboard avant le geste UAC** — traçabilité + audit croisé avant consommation de la fenêtre user.
- Exemptés : lectures pures (`Get-*`, `Test-Path`), dry-runs triviaux sur fichier jetable déjà identifié.

**Si friction** (script sans flag dry-run au source) : poster `[FRICTION]` avec le diff — rendre impossible le prochain incident.
