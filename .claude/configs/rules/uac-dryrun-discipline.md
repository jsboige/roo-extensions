# UAC & Dry-Run Discipline (Global)

**Scope :** toutes les sessions, tous les workspaces, toutes les machines (Claude Code + workers schedulés).
**Statut :** arbitrage USER direct du 2026-08-27 (incident CoursIA po-2024) — règle ferme. Interprétation floue -> `[ASK]` AVANT de livrer.

**Pourquoi :** la disponibilité user est limitée (6 machines x 4-8 workspaces). Une fenêtre UAC consommée par un script buggé coûte une demi-journée d'attente. Un script UAC-touching sans dry-run = `[BLOCKED]` avec motif.

## Règle 1 — UAC : UN seul par lane, jamais une séquence

- **Prêt au clic** : l'agent exécute **immédiatement** quand l'accord tombe (aucun `Read`/recherche à ce moment) et **reste présent** ; s'il a besoin de la fenêtre, il l'a déjà dry-runnée.
- Batcher les élévations en **une seule passe** (`-ArgumentList` ou wrapper) ; annoncer **à l'avance** sur le dashboard la liste exhaustive ; documenter ce que l'user fait pendant la fenêtre ; tester en non-élevé d'abord quand c'est possible.

## Règle 2 — Dry-run EXIGÉ avant tout geste UAC-touching

Cibles : schtasks, ACL/sécurité, écritures `Program Files`/`Windows`/HKLM, service/driver, `-Verb RunAs`/`sudo`, suppression de fichier protégé ou worktree sale.
PowerShell : `-WhatIf` natif ou équivalent de construction (`New-ScheduledTask` assemble et valide l'objet sans écrire) ou `$WhatIfPreference` ; Bash : `--dry-run`/echo-only. **La sortie du dry-run est postée sur le dashboard avant le geste.** Exemptés : lectures pures, dry-runs triviaux sur fichier jetable identifié.

### 2a — L'ENVELOPPE fait partie du geste

Ce qui s'exécute en élevé n'est pas le script du dépôt mais **le lanceur que l'agent vient d'écrire** — c'est lui qui porte les erreurs de syntaxe (plus de la moitié des UAC flotte, constat user 2026-10-07).

- **Écrire le lanceur pour l'interpréteur qui l'exécutera** — `powershell.exe` 5.1 chez nous (`pwsh` absent de certaines machines) ; un paramètre 7.x tue le script au parse (cas mesuré : `Out-File -Encoding utf8NoBOM` est PS7 seulement ; UTF-8 sans BOM en 5.1 = `[System.IO.File]::WriteAllText($p,$c,(New-Object System.Text.UTF8Encoding($false)))`).
- **Lancer la chaîne ENTIÈRE en non-élevé** (lanceur inclus) : le run doit échouer sur **la seule privilège** (`Accès refusé`/`0x80070005`). Échec sur autre chose = bug du geste : corriger et refaire, la fenêtre user n'est pas ouverte. Un `-WhatIf` sur la cible ne dispense pas de ce run.

## Règle 3 — Verifier avec un instrument qui VOIT le resultat

Une tâche `SYSTEM`/`RunLevel Highest` est **invisible au jeton standard** : `Get-ScheduledTask` et `Test-Path` rendent « absent » **exactement comme pour une tâche inexistante** — « absente » en non-élevé n'est **pas une mesure** (et la rapporter comme échec déclenche une seconde fenêtre UAC pour rien).

- Confirmation valide : **sortie du processus élevé lui-même** (CIM `State=Ready`) ou lecture de même portée.
- Seul instrument non élevé distinguant les deux causes : `schtasks /query /tn "<nom>"` → `Accès refusé` (existe) vs `introuvable` (absent).
- L'**effet réel** (boot, service up) se vérifie à son propre déclencheur — noter ce qui reste à confirmer plutôt que le déclarer acquis.

**Si friction** (script sans flag dry-run au source) : poster `[FRICTION]` avec le diff.

**Cas fondateur 2026-10-07** (lanceur PS7-only, fenêtre consommée, replay non-élevé manquant) : [`docs/harness/global-rules-detail.md`](../../docs/harness/global-rules-detail.md) §« UAC & Dry-run — cas fondateur ».
