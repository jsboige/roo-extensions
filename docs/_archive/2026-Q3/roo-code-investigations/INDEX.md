# Archive INDEX — roo-code-customization/investigations/

**Archive date** : 2026-07-21
**Source audit** : [W6 #2883](https://github.com/jsboige/roo-extensions/issues/2883) · [PR #2896 inventory + decision matrix](https://github.com/jsboige/roo-extensions/pull/2896)
**Parent epic** : [#2877](https://github.com/jsboige/roo-extensions/issues/2877) (Consolidation documentation, workstream W6)
**Original path** : `roo-code-customization/investigations/` (24 fichiers `.md`, Aug-Sep 2025)
**Archive reason** : Folder orphelin de la doc active (0 incoming ref). Findings « consommés » dans PRs/commits merges. Archive reversible preserve git history.

## Méthode de preservation

Chaque fichier a été déplacé via `git mv` (préserve l'historique). Le header HTML en tête de chaque fichier list :
- Chemin d'origine
- Dernier SHA dans le chemin d'origine
- Raison de l'archive (theme + PRs/commits merges liés)
- Référence à l'audit canonique

Retracer l'historique complet : `git log --follow -- docs/_archive/2026-Q3/roo-code-investigations/<file>`

## Inventaire (24 fichiers)

| # | Fichier | Theme | Last SHA | Date | PR archive | Statut |
|---|---|---|---|---|---|---|
| 1 | `06-incident-loss-assessment.md` | incident-file-search | `ad7555d92` | 2025-08-25 | follow-up | pending |
| 2 | `07-file-search-analysis.md` | incident-file-search | `4692173ce` | 2025-08-07 | follow-up | pending |
| 3 | `08-ui-crash-deep-dive.md` | other | `087e0a869` | 2025-08-11 | follow-up | pending |
| 4 | `09-context-condensation-analysis.md` | condensation-poc | `087e0a869` | 2025-08-11 | follow-up | pending |
| 5 | `10-condensation-poc-design.md` | condensation-poc | `087e0a869` | 2025-08-11 | follow-up | pending |
| 6 | `10-condensation-poc-design-rapport-mission.md` | condensation-poc | `087e0a869` | 2025-08-11 | follow-up | pending |
| 7 | `11-sddd-process-post-mortem.md` | sddd-mission-reports | `087e0a869` | 2025-08-11 | **PR 1 (this)** | ✅ archived |
| 8 | `12-vhp-condensation-analysis.md` | condensation-poc | `ad7555d92` | 2025-08-25 | follow-up | pending |
| 9 | `analyse-architecture-actuelle-grappes.md` | grappes-clusters | `c131af2e6` | 2025-09-12 | follow-up | pending |
| 10 | `analyse-restauration-taches.md` | other | `7bf3c69f1` | 2025-08-20 | follow-up | pending |
| 11 | `checkpoint-semantique-mi-mission-grappes.md` | sddd-mission-reports | `c131af2e6` | 2025-09-12 | **PR 1 (this)** | ✅ archived |
| 12 | `checkpoint-semantique-mi-mission.md` | sddd-mission-reports | `c131af2e6` | 2025-09-12 | **PR 1 (this)** | ✅ archived |
| 13 | `export-integration-analysis.md` | xml-export-validation | `86768ce51` | 2025-09-12 | follow-up | pending |
| 14 | `powershell-to-nodejs-analysis.md` | powershell-typescript-migration | `86768ce51` | 2025-09-12 | follow-up | pending |
| 15 | `powershell-typescript-comparative-analysis.md` | powershell-typescript-migration | `c131af2e6` | 2025-09-12 | follow-up | pending |
| 16 | `propositions-ameliorations-techniques.md` | other | `c131af2e6` | 2025-09-12 | follow-up | pending |
| 17 | `rapport-mission-sddd.md` | sddd-mission-reports | `c131af2e6` | 2025-09-12 | **PR 1 (this)** | ✅ archived |
| 18 | `SDDD-xml-export-mission-report.md` | sddd-mission-reports | `86768ce51` | 2025-09-12 | **PR 1 (this)** | ✅ archived |
| 19 | `SDDD-xml-validation-mission-final-report.md` | sddd-mission-reports | `86768ce51` | 2025-09-12 | **PR 1 (this)** | ✅ archived |
| 20 | `specification-extensions-grappes.md` | grappes-clusters | `c131af2e6` | 2025-09-12 | follow-up | pending |
| 21 | `typescript-implementation-gaps.md` | powershell-typescript-migration | `c131af2e6` | 2025-09-12 | follow-up | pending |
| 22 | `validation-semantique-finale.md` | sddd-mission-reports | `c131af2e6` | 2025-09-12 | **PR 1 (this)** | ✅ archived |
| 23 | `xml-export-specification.md` | xml-export-validation | `86768ce51` | 2025-09-12 | follow-up | pending |
| 24 | `xml-implementation-validation.md` | xml-export-validation | `86768ce51` | 2025-09-12 | follow-up | pending |

## Themes (7 total)

| Theme | Count | Archive PR | Statut |
|---|---:|---|---|
| sddd-mission-reports | 7 | **PR 1 (this)** | ✅ archived |
| condensation-poc | 4 | PR 2 (follow-up) | pending |
| incident-file-search | 2 | PR 2 (follow-up, grouped) | pending |
| grappes-clusters | 2 | PR 3 (follow-up) | pending |
| powershell-typescript-migration | 3 | PR 3 (follow-up) | pending |
| xml-export-validation | 3 | PR 4 (follow-up) | pending |
| other (ui-crash / restauration / propositions) | 3 | PR 4 (follow-up, grouped) | pending |

## Findings consommés (GitHub cross-ref)

| Theme investigation | PRs/commits merges liés | Statut |
|---|---|---|
| SDDD process / mission reports | `.claude/rules/sddd-grounding.md` (active rule) | ✅ institutionalized |
| XML export/validation | #2551, #2745, #2474, #2552 (submod bumps) | ✅ merged in submodule |
| Condensation POC | auto-condensation 92% live in roo-state-manager | ✅ merged |
| PowerShell → TypeScript migration | submodule RSM is TypeScript | ✅ done |
| Grappes (clusters) | pas de PR directe (peut-être ADR) | ⚠️ à confirmer |

## Liens entrants (post-archive)

Aucun lien cassé par cette archive dans le code/doc active. Les 2 références à `export-integration-analysis.md` dans `docs/roosync/archive/integration/` (déjà archivees) seront mises à jour dans PR 4 (quand ce fichier sera deplacé).

## Conformité

- ✅ **Consolider != Archiver** : `ANALYZE` (audit #2896) → `MERGE` (themes dispatchés) → `ARCHIVE` (cette PR)
- ✅ **No-deletion-without-proof** : chaque fichier a son SHA + URL PR source dans son header
- ✅ **Reversible** : `git mv` préserve l'historique complet via `git log --follow`
- ✅ **Surgical (#1936)** : 1 commit par fichier + 1 INDEX.md

---

*Generated 2026-07-21 by myia-po-2023 · W6 #2883 archive PR 1 (SDDD theme) · Epic #2877*
