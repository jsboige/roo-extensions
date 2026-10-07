# UAC & Dry-Run Discipline (Global)

**Scope :** toutes les sessions, tous les workspaces, toutes les machines (Claude Code + workers schedulés).
**Statut :** arbitrage USER direct du 2026-08-27 (incident CoursIA po-2024) — règle ferme, pas une proposition à débattre. Interprétation floue -> `[ASK]` AVANT de livrer.

**Pourquoi :** la disponibilité user est limitée (6 machines x 4-8 workspaces). Une fenêtre UAC consommée par un script buggé coûte une demi-journée d'attente. Un script UAC-touching sans dry-run = `[BLOCKED]` avec motif.

## Règle 1 — UAC : UN seul par lane, jamais une séquence

- **Prêt au clic.** La fenêtre UAC dure quelques secondes : l'agent doit pouvoir **exécuter immédiatement** quand l'accord tombe — aucun `Read`, aucune recherche, aucun « qu'est-ce que je devais faire ». Un user dont l'agent cherche au moment où il accorde repart sur une autre instance. Corollaire : l'agent qui demande un UAC **reste présent** ; s'il a besoin de la fenêtre, il l'a déjà dry-runnée.
- Batcher les élévations en **une seule passe** (multi-scripts via `-ArgumentList`, ou wrapper dédié).
- Annoncer **à l'avance** sur le dashboard la liste exhaustive des UAC requis.
- Documenter ce que l'user doit faire pendant la fenêtre UAC (ex. cocher « toujours autoriser »).
- Tester en non-élevé d'abord quand c'est possible (cmd sans `-Verb RunAs`).

## Règle 2 — Dry-run EXIGÉ avant tout geste UAC-touching

Scripts concernés : schtasks (`Register/Unregister-ScheduledTask`), ACL/sécurité (`icacls`, `Set-Acl`), écritures `Program Files`/`Windows`/HKLM, install/désinstall service/driver, spawn `-Verb RunAs`/`sudo`, suppression de fichier protégé ou worktree sale.

- PowerShell : `-WhatIf` natif ou son équivalent de construction (`New-ScheduledTask` — assemble et valide l'objet complet sans écrire — quand la cible est `Register-ScheduledTask`, cmdlet CDXML sans `SupportsShouldProcess`) ou `$WhatIfPreference` ; Bash : `--dry-run` ou mode echo-only.
- **La sortie du dry-run est postée sur le dashboard avant le geste UAC** — traçabilité + audit croisé avant consommation de la fenêtre user.
- Exemptés : lectures pures (`Get-*`, `Test-Path`), dry-runs triviaux sur fichier jetable déjà identifié.

### 2a — L'ENVELOPPE fait partie du geste

Ce qui s'exécute en élevé n'est pas le script du dépôt, c'est **le lanceur que l'agent vient d'écrire**. Un dry-run qui ne valide que la cible laisse le maillon neuf non testé — et c'est lui qui porte les erreurs de syntaxe. Plus de la moitié des UAC de la flotte contiennent des erreurs de syntaxe (constat user 2026-10-07) : c'est exactement ce trou.

- **Écrire le lanceur pour l'interpréteur qui l'exécutera.** L'élévation Windows lance **Windows PowerShell 5.1**, jamais `pwsh` 7. Un paramètre de cmdlet qui n'existe qu'en 7.x tue le script au parse — avant la première ligne utile. Cas mesuré : `Out-File -Encoding utf8NoBOM` est **PS7 seulement** ; en 5.1 l'ensemble valide est `unknown;string;unicode;bigendianunicode;utf8;utf7;utf32;ascii;default;oem`. UTF-8 sans BOM en 5.1 = `[System.IO.File]::WriteAllText($p,$c,(New-Object System.Text.UTF8Encoding($false)))`.
- **Lancer la chaîne ENTIÈRE en non-élevé** — lanceur inclus, exactement la commande qui sera élevée. Le run doit aller jusqu'au bout et **échouer sur la seule privilège** (`Register-ScheduledTask` -> `Accès refusé` / `HRESULT 0x80070005`). Échec sur autre chose = bug du geste, pas de l'élévation : corriger et refaire, la fenêtre user n'est pas ouverte.
- Un `-WhatIf` sur la cible ne dispense pas de ce run : la syntaxe du lanceur ne s'y trouve pas.

## Règle 3 — Verifier avec un instrument qui VOIT le resultat

Une tâche enregistrée en `SYSTEM`/`RunLevel Highest` est **invisible au jeton standard** : `Get-ScheduledTask` (énumération), `schtasks /query /tn`, et `Test-Path C:\Windows\System32\Tasks\<nom>` rendent tous `Accès refusé`. « Absente » en non-élevé est alors un **artefact de visibilité**, pas un échec — et le rapporter comme un échec déclenche une seconde fenêtre UAC pour rien.

- La confirmation valide vient d'un contexte qui peut lire l'objet : la **sortie du processus élevé lui-même** (lecture du service par CIM, `State=Ready`), ou toute lecture de même portée.
- Distinguer les deux causes d'un « absent » : **refus d'accès** (l'ACL cache l'objet -> il peut exister) vs **introuvable**. Un instrument muet ne prouve rien.
- L'**effet réel** (démarrage au boot, service up) se vérifie à son propre déclencheur : noter ce qui reste à confirmer au prochain boot plutôt que de le déclarer acquis.

**Si friction** (script sans flag dry-run au source) : poster `[FRICTION]` avec le diff — rendre impossible le prochain incident.

---

**Cas fondateur 2026-10-07 (myia-po-2025, #1171).** `Register-ScheduledTask` pour `Docker-Auto-Start` : la cible `install-docker-autostart.ps1` avait été dry-runnée par assemblage `New-ScheduledTask*` (objet complet, sans écrire) et était saine — mais le **lanceur** écrit pour l'occasion portait `-Encoding utf8NoBOM`, PS7 seulement. Le run élevé a produit 4 erreurs `ValidateSet` sur `Out-File`, zéro installation, fenêtre user consommée. Réécrit en 5.1-safe, puis **rejoué entier en non-élevé** : il est allé jusqu'à `Accès refusé` sur `Register-ScheduledTask` seul — c'est ce run qui manquait. Relancé élevé -> `State=Ready`. La vérification suivante a rendu « tâche absente », refusé après contrôle : `Test-Path` et `schtasks /query` rendent `Accès refusé` (règle 3), la tâche existe bien.
