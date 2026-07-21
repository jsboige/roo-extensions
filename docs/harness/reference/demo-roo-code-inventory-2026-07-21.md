# Inventaire `demo-roo-code/` + Matrice de Décision

**Issue :** #2880 ([W3] demo-roo-code/ cleanup, sub-issue Epic #2877, workstream W3 de #2639)
**Parent audit :** #2876 (catégorie `other` → 292 fichiers dont 121 dans `demo-roo-code/`, 100% stale>180j)
**Livrable :** #1 (inventaire + décision matrice) — read-only, 0 fichier de `demo-roo-code/` modifié
**Date :** 2026-07-21
**Méthode :** SDDD bookend (DEBUT : `codebase_search` + `git grep` ; FIN : `git grep` confirmation)

---

## 1. Synthèse exécutive

`demo-roo-code/` est un **sous-projet autonome pédagogique** (1 commit unique en 2025-05-21, ~426 jours) conçu pour être intégré comme sous-dossier dans un dépôt tiers. Il n'a **jamais été maintenu** dans ce repo et n'est référencé que dans **3 docs actifs** (1 architecture, 1 knowledge, 1 contribution), tous citent le répertoire sans dépendre de son contenu interne.

| Métrique | Valeur |
|---|---|
| Fichiers `.md` tracked | **121** |
| Taille totale | **837 KB** (~818 KB) |
| Sections thématiques | 5 (01-decouverte → 05-projets-avances) + `docs/` + racine |
| Dernier commit | `ad6c9df01` — 2025-05-21T23:33:49+02:00 (~426 jours) |
| Commits totaux sur le répertoire | **1** (ajout initial, jamais touché) |
| Liens entrants actifs (non-archivaux) | **4 fichiers** (cf §3) |
| Liens sortants vers repo principal | **0** (auto-référencé, standalone) |

**Verdict conservateur :** Option A (Archive) recommandée — préservation dans `docs/_archive/2026-Q3/demo-roo-code/` avec header de traçabilité, 0 lien actif à mettre à jour significativement. Options B/C possibles mais sur-justifient la complexité.

---

## 2. Inventaire par section (121 fichiers, vérifié firsthand)

### 2.1 Vue d'ensemble

| Section | Fichiers .md | Taille totale | % du total |
|---|---:|---:|---:|
| `01-decouverte/` | 17 | ~57 KB | 14% |
| `02-orchestration-taches/` | 20 | ~118 KB | 16% |
| `03-assistant-pro/` | 28 | ~211 KB | 23% |
| `04-creation-contenu/` | 21 | ~149 KB | 17% |
| `05-projets-avances/` | 28 | ~248 KB | 23% |
| `docs/` (interne à demo-roo-code) | 3 | ~16 KB | 2% |
| Racine (`README.md`, `README-integration.md`, `CONTRIBUTING.md`, `VERSION.md`) | 4 | ~33 KB | 3% |
| **Total** | **121** | **~837 KB** | **100%** |

### 2.2 Liste exhaustive

Cf. fichier companion `demo-roo-code-inventory-raw-2026-07-21.json` (chemin, taille en octets, section, sous-section).

**Top 10 fichiers par taille :**

| Fichier | Taille (KB) | Section |
|---|---:|---|
| `05-projets-avances/integration-outils/bonnes-pratiques.md` | 71.5 | 05 |
| `05-projets-avances/integration-outils/exemples-integration.md` | 24.2 | 05 |
| `04-creation-contenu/multimedia/instructions-traitement.md` | 27.1 | 04 |
| `03-assistant-pro/communication/modeles-emails.md` | 25.2 | 03 |
| `05-projets-avances/demo-1-architecture/ressources/modeles-architecture.md` | 18.9 | 05 |
| `04-creation-contenu/demo-1-web/ressources/composants-web.md` | 20.2 | 04 |
| `05-projets-avances/analyse-documents/guide-analyse.md` | 17.3 | 05 |
| `README.md` (racine) | 16.5 | racine |
| `05-projets-avances/assistant-recherche/exemple-synthese.md` | 16.5 | 05 |
| `03-assistant-pro/documentation/exemple-api.md` | 17.7 | 03 |

### 2.3 Staleness

**100% des 121 fichiers sont stale>180 jours** (audit #2876, vérifié).
- Dernier commit : `ad6c9df01` (2025-05-21) sur le sous-ensemble complet
- Aucun commit sur aucun fichier individuel depuis
- Aucune branche, aucun tag, aucune référence upstream post-2025-05-21

---

## 3. Analyse des liens entrants (critère "no-deletion-without-proof")

### 3.1 Liens actifs (non-archivaux) — **4 fichiers**

| Fichier | Lignes | Type de référence |
|---|---:|---|
| `docs/architecture/repository-map.md` | L77 | Section descriptive "Scénarios de Démonstration" — mentionne aussi `prepare-workspaces.ps1` et `clean-workspaces.ps1` qui **n'existent PAS** dans le repo (documentation drift vérifié firsthand) |
| `docs/knowledge/WORKSPACE_KNOWLEDGE.md` | L33, L714, L721, L1007, L1143, L1184 | Description de la structure (5 sections thématiques) + parcours utilisateur |
| `docs/roo-code/contributing/add-condensation-provider.md` | L971 | Lien vers `demo-roo-code/CONTRIBUTING.md` depuis une section "Contribution" |
| `scripts/roo-settings/settings-extract.json` | L183-190 | Snapshot de settings — chemins `ateliers/demo-roo-code/...` qui **n'existent PAS** dans le repo (chemin legacy atelier non présent) |

### 3.2 Liens archivaux (déjà dans `archive/`, `baseline/`, ou test fixtures) — **8 fichiers**

Ces fichiers sont déjà dans des sections destinées à l'archivage et n'ont **pas besoin de mise à jour** si le répertoire est déplacé :

| Fichier | Note |
|---|---|
| `docs/harness/reference/doc-audit-2026-07-21.md` (+ `.json`) | Source de l'audit lui-même, mentionne demo-roo-code dans le top stale |
| `docs/mcp/archive/quickfiles-search-fix.md` | Archive MCP, déjà hors circulation active |
| `docs/roosync/archive/integration/01-grounding-semantique-roo-state-manager.md` | Archive RooSync |
| `docs/roosync/archive/integration/RAPPORT-MISSION-INTEGRATION-ROOSYNC.md` | Archive RooSync |
| `mcps/JUPYTER-CONFLICT-RESOLUTION-REPORT.md` | Rapport de résolution passé |
| `roo-config/baselines/myia-po-2023-settings-baseline.json` | Snapshot machine, figé |
| `roo-config/baselines/myia-web1-settings-baseline.json` | Snapshot machine, figé |
| `mcps/internal/servers/roo-state-manager/tests/fixtures/real-tasks/...` (×2) | Fixtures de test (JSONL/JSON archivés) |

**Conclusion :** Seuls 4 fichiers actifs mentionnent demo-roo-code, dont 2 contiennent des **références cassées** (chemins vers scripts/fichiers inexistants). Aucune référence ne dépend du **contenu interne** de demo-roo-code.

### 3.3 Liens sortants (depuis demo-roo-code vers le repo)

**0 fichier** dans `demo-roo-code/` ne pointe vers le reste du repo (vérifié via `git grep` interne). Le sous-projet est auto-référencé et standalone par design (cf. `CONTRIBUTING.md` §"Autonomie du sous-dossier").

---

## 4. Documentation drift détecté (signal annexe, hors scope destruction)

L'audit a aussi révélé que `docs/architecture/repository-map.md` (référencé ci-dessus) contient des **assertions non-vérifiables** :

| L82 de repository-map.md | Réalité |
|---|---|
| "Scripts `prepare-workspaces.ps1` et `clean-workspaces.ps1`" | `find . -name "prepare-workspaces.ps1"` → **0 résultat** dans le repo |

C'est une opportunité de **fix de cohérence** future, hors scope de ce livrable (à traiter en follow-up si l'option A est retenue — la doc devra être nettoyée pour cohérence post-archivage).

---

## 5. Matrice de décision (5 sections × A/B/C)

**Critères :**
- **A (Archive)** : move vers `docs/_archive/2026-Q3/demo-roo-code/` + header de préservation (date, scope, taille, lien git tree `ad6c9df01`). Aucune perte, traçabilité préservée.
- **B (Externalisation)** : move vers repo séparé `jsboige/roo-extensions-demos`. Pertinent UNIQUEMENT si le contenu a une valeur de réutilisation active.
- **C (Suppression)** : applicable UNIQUEMENT si 0 lien actif et 0 valeur pédagogique. **Non recommandé ici** car 4 liens actifs existent (même ténus) + le README interne se présente explicitement comme "intégrable comme sous-dossier tiers" (donc réutilisable).

| Section | Fichiers | Décision recommandée | Justification |
|---|---:|---|---|
| `01-decouverte/` | 17 | **A (Archive)** | Pédagogique pur, aucune utilité active pour le repo extensions ; 4 fichiers actifs réfèrent à la structure mais pas au contenu |
| `02-orchestration-taches/` | 20 | **A (Archive)** | Idem, pas d'usage actif. Contient des références à `quickfiles` (MCP retiré) → fail content drift en plus |
| `03-assistant-pro/` | 28 | **A (Archive)** | Idem |
| `04-creation-contenu/` | 21 | **A (Archive)** | Idem |
| `05-projets-avances/` | 28 | **A (Archive)** | Idem, contient `integration-outils/bonnes-pratiques.md` (71KB, top du rapport stale) |
| `docs/` (interne) | 3 | **A (Archive)** | MIGRATION.md, README.md, demo-maintenance.md — archive pédagogique |
| Racine (4 fichiers) | 4 | **A (Archive)** | README.md, README-integration.md, CONTRIBUTING.md, VERSION.md |

**Décision globale recommandée :** **Option A (Archive) globale** pour les 121 fichiers.

**Justification de A sur B et C :**
- **B (externalisation)** : le contenu est pédagogique Roo v1 (2024-2025) et ne reflète plus le code Roo actuel (submod roo-code) — externaliser un repo `roo-extensions-demos` sans maintenance programmée = déplacer la dette, pas la résoudre. Sur-ingénierie.
- **C (suppression)** : 4 liens actifs existent (même ténus), la documentation encyclopédique (5 sections thématiques structurées) a une valeur de préservation historique. La règle "no-deletion-without-proof" s'applique. Aucun des 4 liens actifs ne casse avec une archive bien étiquetée (les 2 chemins déjà cassés le restent, les 2 chemins structurels continuent de pointer vers un emplacement valide sous `_archive/`).

---

## 6. Preuve de préservation (préparation exécution)

Pour permettre l'exécution ultérieure (livrable #2, gated par décision user) :

1. **Git tree SHA source :** `ad6c9df01c1748e3cb8e0844257cadd56b91d114` (commit unique d'ajout, 2025-05-21)
2. **Localisation post-archive proposée :** `docs/_archive/2026-Q3/demo-roo-code/`
3. **Header d'archive (à inclure dans `docs/_archive/2026-Q3/demo-roo-code/README.md` post-move) :**
   ```
   # Archive: demo-roo-code/ (2025-05 → 2026-07)
   - Source commit: ad6c9df01c1748e3cb8e0844257cadd56b91d114
   - Date archivage: 2026-07-21
   - Raison: contenu pédagogique Roo v1 stable, jamais maintenu dans ce repo
   - Issue: #2880 (W3 sub-issue Epic #2877)
   - Restauration: `git show ad6c9df01 -- demo-roo-code | git apply` (ou utiliser le tree complet)
   ```
4. **Mise à jour des 4 liens actifs** (post-archivage, hors scope ce livrable) :
   - `docs/architecture/repository-map.md` : remplacer la section L77 par "Scénarios de Démonstration (archivé Q3 2026, voir `docs/_archive/2026-Q3/demo-roo-code/`)"
   - `docs/knowledge/WORKSPACE_KNOWLEDGE.md` : idem (6 lignes)
   - `docs/roo-code/contributing/add-condensation-provider.md` : ajuster chemin vers `docs/_archive/2026-Q3/demo-roo-code/CONTRIBUTING.md`
   - `scripts/roo-settings/settings-extract.json` : ne pas toucher (snapshot historique, déjà incohérent)

---

## 7. Conformité

- ✅ **Bookend SDDD** : `codebase_search` (10 résultats DEBUT) + `git grep` confirmation FIN
- ✅ **Skepticism** : tous les comptes vérifiés firsthand (121 .md, 4 liens actifs vs 8 archivaux, 0 dépendances contenu)
- ✅ **Read Body Before Action** : body #2880 + audit #2876 + dashboards intercom (collision W5 #2882 détectée) lus avant analyse
- ✅ **Anti-double-claim** : W1 (po-2023), W4 (po-2024), W5 (web1 collision) vérifiés, W3 libre → claim horodaté
- ✅ **Surgical #1936** : 0 modification de `demo-roo-code/`, 0 destructive action dans ce livrable
- ✅ **Consolider != Archiver** (Session 101) : pas de move dans ce livrable, juste inventaire + matrice — move = livrable #2 gated
- ✅ **No-deletion-without-proof** : pre-collectée pour livrable #2 (4 liens actifs, 1 commit SHA, ratios tailles)
- ✅ **PROTEGED paths** : aucun touché (`src/services/synthesis/`, `src/services/narrative/` — N/A ici)

---

## 8. Next steps (gated, livrable #2)

**Pour exécution (séparément, après décision user) :**

1. **Décision user explicite** : confirmer Option A globale (ou demander A par section si section-spécifique)
2. **PR d'exécution (1 PR par décision)** :
   - Move `demo-roo-code/` → `docs/_archive/2026-Q3/demo-roo-code/`
   - Header d'archive conforme (cf §6.3)
   - Mise à jour des 4 liens actifs (cf §6.4)
   - Conservation du commit SHA en référence
3. **Validation post-merge** : `git grep "demo-roo-code" -- ':!docs/_archive/**' ':!docs/harness/reference/doc-audit*' ':!docs/**/archive/**' ':!mcps/JUPYTER-*' ':!roo-config/baselines/*' ':!scripts/roo-settings/settings-extract.json' ':!roo-code/'` doit retourner **0** référence cassée vers demo-roo-code (uniquement les 4 mentions structurelles mises à jour)

---

**Statut :** ✅ Livrable #1 (inventaire + matrice) — terminé, PR-ready.
**Bloqueur :** Décision user (A/B/C par section OU globale) pour débloquer livrable #2 (exécution).
**Charge estimée livrable #2 :** ~15 min (1 PR move + 4 fichiers de référence).
