# Archive — guides 2025 (lot W10, #2877)

> Déposé le 2026-11-08 par `myia-web1:roo-extensions` (cycle c.772), lot **W10** de l'Epic #2877
> (consolidation documentation). Suite du lot W9 (`docs/archive/roo-code-analyses-2025/`, PR #4600).

## Contenu

| Fichier | Âge au déplacement | Octets | Nature |
|---|---|---|---|
| `procedures-maintenance.md` | 391 j | 8 129 | procédures de maintenance d'époque (supplantées par `docs/harness/reference/`) |
| `guide-utilisation-mcp-jupyter.md` | 391 j | 12 626 | guide « MCP Jupyter Corrigé » (artefact du fix d'août 2025 ; le savoir opérationnel papermill vit dans `docs/harness/` — 17 fichiers le portent, dont `deny-fallback-probe.md`) |
| `consolidated-task-management-guide.md` | 391 j | 4 035 | guide gestion des tâches Roo (août 2025, cite des commandes d'époque) |
| `vscode-extension-debug-powershell-configuration.md` | 383 j | 21 610 | config debug VS Code PowerShell — déjà classée « stale-6m » par l'audit du 21/07 et listée « superseded » dans `superseded-by-closed-issues-audit-table-2026-07-21.json` |

## Preuve de préservation (no-deletion-without-proof)

- **Rien de supprimé** : les 4 entrées sont des `rename ... (100 %)` dans le diffstat (aucun octet modifié).
- **Consommateurs mesurés sur l'arbre courant** (`git grep -F` par nom de fichier, hors `docs/archive/`/`docs/_archive/`) : la seule liste porteuse était `docs/INDEX.md`, mise à jour dans le **même commit** (4 lignes retirées, décomptes 17→13 et 68→64, renvoi vers cette archive).
- Les mentions dans `docs/harness/reference/doc-audit-2026-07-21.md` et `superseded-by-closed-issues-audit-table-2026-07-21.json` sont des **enregistrements d'audit datés** — laissés intacts volontairement (ils citent le chemin d'époque, comme un ADR).
- **Aucun doublon** de ces 4 noms ailleurs dans l'arbre courant (`git ls-files` vérifié par nom).

## Exclusions assumées (arbitrage, pas archivage)

- **`docs/guides/guide-synchronisation-submodules.md`** (391 j, même zone) : exclu du lot car [`docs/roosync/SUBMODULE_WORKFLOW.md:379`](../../roosync/SUBMODULE_WORKFLOW.md) porte un **lien vivant** vers lui. Décider de son sort = arbitrage de doublon (quel document garde l'autorité), pas un `git mv` — même frontière que le trio `SCHEDULED_*` identifié en W9.
- `docs/roo-code/adr/` : intouchable (enregistrement daté, décision W9).
- Toute réparation de lien dans les docs rsm actives : lot web2 (#2639), hors périmètre.

## Gel

Cette archive est en **lecture seule** : aucun de ces fichiers ne doit être réédité ici. Le contenu
historique reste consultable pour la traçabilité des décisions d'époque.
