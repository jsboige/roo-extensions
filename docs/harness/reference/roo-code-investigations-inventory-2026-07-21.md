# W6 #2883 — roo-code-customization/investigations/ inventory + decision matrix

**Workstream** : W6 de l'Epic #2877 ([EPIC] Consolidation documentation), sous-issue #2883.
**Source** : audit #2876, categorie `other` (292 fichiers) → 24 dans `roo-code-customization/investigations/`.
**Scan date** : 2026-07-21 · **Machine** : myia-po-2026 (Epic owner lane).
**Livrable** : read-only (inventaire + matrice de decision). **Aucun fichier d'investigation modifie dans ce PR** — l'execution de l'archive est gated a une PR follow-up apres decision user.

## Synthese

- **24 fichiers** `.md`, **299.2 KB** total
- **Age** : tous entre 295 et 347 jours (Aug-Sep 2025) → 100% stale >180j, ~100% stale >365j sous peu
- **References entrantes actives** : **0** (voir section dediee)
- **Recommandation** : **Option A — Archive** globale vers `docs/_archive/2026-Q3/roo-code-investigations/` (gated PR follow-up)

## Repartition par theme

| Theme | Count | Taille (KB) |
|---|---:|---:|
| `condensation-poc` | 4 | 59.1 |
| `grappes-clusters` | 2 | 41.3 |
| `incident-file-search` | 2 | 10.3 |
| `other` | 3 | 45.0 |
| `powershell-typescript-migration` | 3 | 31.4 |
| `sddd-mission-reports` | 7 | 75.6 |
| `xml-export-validation` | 3 | 36.3 |
| **Total** | **24** | **299.2** |

## Inventaire detaille (24 fichiers)

| # | Fichier | Theme | Size (KB) | Last commit | SHA |
|---:|---|---|---:|---|---|
| 1 | `06-incident-loss-assessment.md` | `incident-file-search` | 4.7 | 2025-08-25 | `ad7555d92` |
| 2 | `07-file-search-analysis.md` | `incident-file-search` | 5.6 | 2025-08-07 | `4692173ce` |
| 3 | `08-ui-crash-deep-dive.md` | `other` | 12.7 | 2025-08-11 | `087e0a869` |
| 4 | `09-context-condensation-analysis.md` | `condensation-poc` | 21.4 | 2025-08-11 | `087e0a869` |
| 5 | `10-condensation-poc-design-rapport-mission.md` | `condensation-poc` | 9.0 | 2025-08-11 | `087e0a869` |
| 6 | `10-condensation-poc-design.md` | `condensation-poc` | 13.4 | 2025-08-11 | `087e0a869` |
| 7 | `11-sddd-process-post-mortem.md` | `sddd-mission-reports` | 13.7 | 2025-08-11 | `087e0a869` |
| 8 | `12-vhp-condensation-analysis.md` | `condensation-poc` | 15.3 | 2025-08-25 | `ad7555d92` |
| 9 | `analyse-architecture-actuelle-grappes.md` | `grappes-clusters` | 14.4 | 2025-09-12 | `c131af2e6` |
| 10 | `analyse-restauration-taches.md` | `other` | 9.3 | 2025-08-20 | `7bf3c69f1` |
| 11 | `checkpoint-semantique-mi-mission-grappes.md` | `sddd-mission-reports` | 16.2 | 2025-09-12 | `c131af2e6` |
| 12 | `checkpoint-semantique-mi-mission.md` | `sddd-mission-reports` | 8.0 | 2025-09-12 | `c131af2e6` |
| 13 | `export-integration-analysis.md` | `xml-export-validation` | 7.8 | 2025-09-12 | `86768ce51` |
| 14 | `powershell-to-nodejs-analysis.md` | `powershell-typescript-migration` | 14.0 | 2025-09-12 | `86768ce51` |
| 15 | `powershell-typescript-comparative-analysis.md` | `powershell-typescript-migration` | 10.6 | 2025-09-12 | `c131af2e6` |
| 16 | `propositions-ameliorations-techniques.md` | `other` | 23.0 | 2025-09-12 | `c131af2e6` |
| 17 | `rapport-mission-sddd.md` | `sddd-mission-reports` | 15.1 | 2025-09-12 | `c131af2e6` |
| 18 | `SDDD-xml-export-mission-report.md` | `sddd-mission-reports` | 5.6 | 2025-09-12 | `86768ce51` |
| 19 | `SDDD-xml-validation-mission-final-report.md` | `sddd-mission-reports` | 8.4 | 2025-09-12 | `86768ce51` |
| 20 | `specification-extensions-grappes.md` | `grappes-clusters` | 26.9 | 2025-09-12 | `c131af2e6` |
| 21 | `typescript-implementation-gaps.md` | `powershell-typescript-migration` | 6.8 | 2025-09-12 | `c131af2e6` |
| 22 | `validation-semantique-finale.md` | `sddd-mission-reports` | 8.6 | 2025-09-12 | `c131af2e6` |
| 23 | `xml-export-specification.md` | `xml-export-validation` | 22.7 | 2025-09-12 | `86768ce51` |
| 24 | `xml-implementation-validation.md` | `xml-export-validation` | 5.8 | 2025-09-12 | `86768ce51` |

## References entrantes (skepticism — verifie firsthand)

**Verification** : `git grep -l "roo-code-customization/investigations"` hors du dossier lui-meme.

| Source | Type | Actif ? |
|---|---|---|
| `docs/harness/reference/doc-audit-2026-07-21.md` | auto-reference (mon audit #2876) | NON (self-ref) |
| `docs/harness/reference/doc-audit-raw-2026-07-21.json` | companion JSON audit | NON (self-ref) |
| `docs/roosync/archive/integration/01-grounding-semantique-roo-state-manager.md` | **archive** (path `archive/`) | NON (deja archive) |
| `docs/roosync/archive/integration/RAPPORT-MISSION-INTEGRATION-ROOSYNC.md` | **archive** (path `archive/`) | NON (deja archive) |

**INDEX.md / README.md / CLAUDE.md** : **0 reference** a `roo-code-customization/investigations` specifiquement.
(`docs/INDEX.md` mentionne `investigations/` 4x mais pour `docs/roosync/investigations/` et `docs/harness/investigations/` — des dirs differents.)

**Conclusion** : le dossier est **orphelin de la doc active**. Aucun entrypoint (INDEX/README/CLAUDE) n'y pointe. Les 2 seules refs non-self sont elles-memes dans `archive/`.

## Cross-reference GitHub (findings « consommes »)

Les investigations ont feeding du travail merge. Cross-ref des themes cles vs PRs/commits :

| Theme investigation | PRs/commits merges lies | Statut |
|---|---|---|
| XML export/validation | #2551, #2745, #2474, #2552 (submod bumps roo-state-manager) | findings MERGED dans submod |
| Condensation POC | code condensation live dans RSM (dashboard auto-condensation 92%) | findings MERGED |
| Grappes (clusters) | pas de PR directe trouvee (mot-cle absent des titres) | a confirmer (peut-etre ADR) |
| PowerShell→TypeScript migration | submodule RSM est en TypeScript (migration done) | findings MERGED (fact) |
| SDDD process | SDDD protocol doc `.claude/rules/sddd-grounding.md` actif | findings institutionalises |

**Lecture** : la majorite des investigations ont abouti a du code/doc merge. Leur valeur de reference active est faible — l'historique git des PRs/commits citees preserve les decisions.

## Matrice de decision (recommandation par fichier)

| Option | Action | Fichiers concernes | Rationale |
|---|---|---|---|
| **A — Archive** (recommande) | move vers `docs/_archive/2026-Q3/roo-code-investigations/` avec header preservation | **24/24** | Orphelin de doc active, findings merges, 0 ref active. Archive preserve git history + access |
| B — Keep in place | ne rien faire | 0 | Aucun fichier n'a de ref active justifiant un keep |
| C — Delete | suppression | 0 | Trop risique sans audit file-by-file des cross-refs ADR/design docs (cf. lecon web1 c.164 sur `learner` skill) |

### Pourquoi Option A (Archive) et non C (Delete)

- **Regle `Consolider != Archiver`** (Session 101) : archive = preservation prouvee, pas suppression.
- **Regle `no-deletion-without-proof`** : chaque suppression exigerait un audit des cross-refs dans ADRs + design docs. Web1 c.164 a montre que `learner` skill (count "0 invocations") etait en fait reference dans ADR 006 + design docs — **count-based orphan detection est fallible**. Meme risque ici : une investigation peut etre citee dans un ADR sans etre dans mon grep.
- **Archive est reversible** (contrairement a delete). Si une investigation s'averere necessaire, elle reste accessible dans `_archive/`.

## Preuve de preservation (pour la PR follow-up d'execution)

Pour chaque fichier archive, le header de preservation devra contenir :
```
<!-- Archived 2026-07-21 from roo-code-customization/investigations/<file> -->
<!-- Last commit: <SHA> (<date>) — git history preserved via git mv -->
<!-- Original path accessible via: git log --follow -- docs/_archive/2026-Q3/roo-code-investigations/<file> -->
```

**`git mv`** preserve l'historique (vs copy+delete). Le `git log --follow` traverse le rename. Aucune perte d'information.

## Conformite

- ✅ **Read Body Before Action** : #2883 body + #2880 (W3 template) + PR #2894 (po-2025 livrable) lus avant execution
- ✅ **Anti-double-claim** : 0 PR sur W6 (#2883) au moment du pickup (CronList + gh pr list verifies)
- ✅ **Consolider != Archiver** : ce PR = inventaire read-only, 0 fichier modifie dans `roo-code-customization/investigations/`
- ✅ **no-deletion-without-proof** : Option C (delete) ecartee, Option A (archive reversible) recommandee
- ✅ **Skepticism** : references entrantes verifiees firsthand (git grep), cross-ref GitHub, INDEX.md refs desambiguises (autres dirs)
- ✅ **Anti-speculative** : recommandation Archive GATED a decision user, pas executee dans ce PR

## Next steps (post-decision user)

1. **User review** de cet inventaire + confirmer Option A (Archive globale)
2. **PR follow-up** (gated) : `git mv` des 24 fichiers vers `docs/_archive/2026-Q3/roo-code-investigations/` + header preservation + update 2 refs dans `docs/roosync/archive/integration/`
3. **Cloture #2883** apres merge de la PR follow-up

## Companion data

- `roo-code-investigations-inventory-raw-2026-07-21.json` (8412 bytes) — donnees programmatiques pour la PR follow-up

---
*Genere par myia-po-2026 · W6 #2883 · Epic #2877 · 2026-07-21*