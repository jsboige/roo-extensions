# Analyse Croisée des Harnais Roo ↔ Claude

**Date :** 2026-04-05
**Auteur :** Roo Code (code-complex, GLM-5)
**Contexte :** Étape 2 méta-analyse — inventaire, mappings et anomalies

---

## 1. Inventaire des Fichiers

### 1.1 `.roo/rules/` — 22 fichiers

| # | Fichier | Version | MAJ | Issues | Rôle |
|---|---------|---------|-----|--------|------|
| 01 | `01-general.md` | — | — | — | Vue d'ensemble, structure dépôt, hiérarchie |
| 02 | `02-intercom.md` | — | — | #745 | Dashboard workspace, format messages |
| 03 | `03-mcp-usage.md` | — | — | — | MCPs disponibles, économie tokens |
| 04 | `04-sddd-grounding.md` | 2.1.0 | 2026-02-23 | #636, #881, #952 | Triple grounding, conversation_browser |
| 05 | `05-tool-availability.md` | 1.6.0 | 2026-03-22 | #650, #708, #791 | STOP & REPAIR, inventaire MCP |
| 06 | `07-orchestrator-delegation.md` | — | — | #563, #803 | Orchestrateurs = new_task uniquement |
| 07 | `08-file-writing.md` | 1.0.0 | 2026-03-10 | — | Limitation Qwen 3.5 (>200 lignes) |
| 08 | `09-github-checklists.md` | — | — | — | Checklists validation issues |
| 09 | `10-ci-guardrails.md` | 2.0.0 | 2026-03-23 | #626, #827 | Validation build+tests avant push |
| 10 | `11-incident-history.md` | 1.0.0 | 2026-03-15 | #710 | Historique incidents MCP |
| 11 | `12-machine-constraints.md` | 1.0.0 | 2026-03-15 | #710 | Contraintes par machine |
| 12 | `13-test-success-rates.md` | 1.1.0 | 2026-03-24 | #710, #827 | Taux succès, commandes test |
| 13 | `14-tdd-recommended.md` | 1.0.0 | 2026-03-15 | #710 | TDD recommandé |
| 14 | `15-coordinator-responsibilities.md` | 1.0.0 | 2026-03-15 | #710 | Responsabilités coordinateur |
| 15 | `16-no-tools-warnings.md` | 1.1.0 | 2026-03-30 | #608, #881, #952 | Fix #881, detailLevel |
| 16 | `17-friction-protocol.md` | 1.0.0 | 2026-03-15 | #710 | Signalement frictions |
| 17 | `18-meta-analysis.md` | 2.0.0 | 2026-03-30 | #705, #981, #982, #855 | Architecture 3x2, méta-analyse |
| 18 | `19-github-cli.md` | — | — | #368, #706 | gh CLI, GraphQL, Project #67 |
| 19 | `20-pr-mandatory.md` | 1.0.0 | 2026-03-23 | #895 | PR obligatoire, cleanup worktrees |
| 20 | `21-skepticism-protocol.md` | 2.0.0 | 2026-03-23 | — | Scepticisme, vérification |
| 21 | `22-validation.md` | — | — | CONS-3/4 | Checklist validation technique |
| 22 | `23-no-deletion-without-proof.md` | 1.0.0 | 2026-03-24 | #815 | Pas de suppression sans preuve |

**Note :** Pas de fichier `06-*` (numérotation manquante).

### 1.2 `.claude/rules/` — 12 fichiers

| # | Fichier | Version | MAJ | Issues | Rôle |
|---|---------|---------|-----|--------|------|
| 1 | `agents-architecture.md` | 2.0.0 | 2026-04-05 | #556 | Subagents, skills, commands |
| 2 | `ci-guardrails.md` | 3.0.0 | 2026-04-05 | #827 | Garde-fous CI |
| 3 | `context-window.md` | 2.0.0 | 2026-04-05 | #502, #736 | Condensation seuil 80% |
| 4 | `conversation-browser-guide.md` | 1.0.0 | — | #1063, #881 | Guide conversation_browser |
| 5 | `file-writing.md` | 2.0.0 | 2026-04-05 | — | Patterns écriture fichiers |
| 6 | `intercom-protocol.md` | 3.0.0 | 2026-04-05 | #657 | Dashboard workspace, dialogue |
| 7 | `no-deletion-without-proof.md` | 2.0.0 | 2026-04-05 | #815 | Pas de suppression sans preuve |
| 8 | `pr-mandatory.md` | 2.0.0 | 2026-04-05 | — | PR obligatoire |
| 9 | `sddd-grounding.md` | 1.0.0 | — | #1063 | Triple grounding SDDD |
| 10 | `skepticism-protocol.md` | 3.0.0 | 2026-04-05 | — | Scepticisme raisonnable |
| 11 | `tool-availability.md` | 2.0.0 | 2026-04-05 | — | STOP & REPAIR |
| 12 | `validation.md` | 2.0.0 | — | #724 | Checklist validation |

**Observation :** Tous les fichiers Claude (sauf `conversation-browser-guide.md` et `sddd-grounding.md`) ont été condensés le 2026-04-05 avec un passage à v2.0.0+.

---

## 2. Mappings Officiels Roo ↔ Claude

### 2.1 Mappings cohérents ✅

| Roo | Claude | Commentaire |
|-----|--------|-------------|
| `02-intercom.md` | `intercom-protocol.md` v3.0.0 | Même canal (dashboard workspace). Claude ajoute dialogue bidirectionnel (#657). |
| `16-no-tools-warnings.md` | `conversation-browser-guide.md` | Même contenu detailLevel/fix #881. Claude est un guide dédié. |

### 2.2 Mappings avec incohérence de version ⚠️

| Roo | Claude | Écart |
|-----|--------|-------|
| `04-sddd-grounding.md` v2.1.0 (2026-02-23) | `sddd-grounding.md` v1.0.0 (sans date, #1063) | Roo plus détaillé (filtres #636), Claude plus récent mais condensé |
| `05-tool-availability.md` v1.6.0 (2026-03-22) | `tool-availability.md` v2.0.0 (2026-04-05) | Claude plus récent et condensé |
| `10-ci-guardrails.md` v2.0.0 (2026-03-23) | `ci-guardrails.md` v3.0.0 (2026-04-05) | Claude plus récent |
| `20-pr-mandatory.md` v1.0.0 (2026-03-23) | `pr-mandatory.md` v2.0.0 (2026-04-05) | Claude ajoute anti-double-claim |
| `21-skepticism-protocol.md` v2.0.0 (2026-03-23) | `skepticism-protocol.md` v3.0.0 (2026-04-05) | Claude plus récent |
| `22-validation.md` (sans version) | `validation.md` v2.0.0 | Claude versionné, Roo non |
| `23-no-deletion-without-proof.md` v1.0.0 | `no-deletion-without-proof.md` v2.0.0 (2026-04-05) | Claude plus récent |
| `08-file-writing.md` v1.0.0 | `file-writing.md` v2.0.0 (2026-04-05) | Contenus différents (Roo = limitation Qwen, Claude = patterns Edit/Write) |

### 2.3 Règles Roo sans équivalent Claude ⚠️

| Fichier Roo | Justification | Action recommandée |
|-------------|---------------|-------------------|
| `01-general.md` | Partiellement couvert par `agents-architecture.md` | Fusionner le contenu structure dépôt dans `agents-architecture.md` |
| `03-mcp-usage.md` | Info répartie dans `tool-availability.md` et `sddd-grounding.md` | Pas d'action (couvert) |
| `07-orchestrator-delegation.md` | Spécifique Roo (modes orchestrator) | Pas d'action (pas pertinent pour Claude) |
| `09-github-checklists.md` | Pas d'équivalent | Ajouter une règle Claude pour checklists issues |
| `11-incident-history.md` | Info dans `docs/harness/reference/` | Déplacer vers docs/ (pas une règle) |
| `12-machine-constraints.md` | Info dans `docs/harness/` | Pas d'action (référence) |
| `13-test-success-rates.md` | Partiellement dans `ci-guardrails.md` | Pas d'action (couvert) |
| `14-tdd-recommended.md` | Pas d'équivalent | Pas critique |
| `15-coordinator-responsibilities.md` | Partiellement dans `agents-architecture.md` | Pas d'action (spécifique coordinateur) |
| `17-friction-protocol.md` | Référencé dans `sddd-grounding.md` | Ajouter une règle Claude minimale |
| `18-meta-analysis.md` | Info dans `docs/harness/reference/meta-analysis.md` | Pas d'action (trop spécifique Roo) |
| `19-github-cli.md` | Claude utilise gh CLI nativement | Pas d'action |

### 2.4 Règle Claude sans équivalent Roo ⚠️

| Fichier Claude | Justification | Action recommandée |
|----------------|---------------|-------------------|
| `context-window.md` | Seuil condensation 80% | Info partiellement dans `12-machine-constraints.md`. Ajouter référence croisée. |

---

## 3. Anomalies Détectées

### 3.1 Haute Priorité 🔴

#### A. Décalage version systématique
**Tous les fichiers Claude ont été condensés le 2026-04-05 (v2.0.0+) tandis que les fichiers Roo sont restés aux versions antérieures (v1.0.0 à v2.1.0, MAJ 2026-02-23 à 2026-03-30).**

Les contenus ont divergé : Claude est maintenant plus concis mais potentiellement incomplet sur les détails opérationnels Roo.

**Impact :** Un agent lisant les deux harnais peut trouver des informations contradictoires ou manquantes.

#### B. 10 règles Roo sans équivalent Claude
Les règles `09-github-checklists.md`, `11-incident-history.md`, `12-machine-constraints.md`, `13-test-success-rates.md`, `14-tdd-recommended.md`, `15-coordinator-responsibilities.md`, `17-friction-protocol.md`, `18-meta-analysis.md`, `19-github-cli.md` n'ont pas d'équivalent côté Claude.

**Impact :** Claude n'a pas accès à ces règles dans son harnais. Certaines sont couvertes par d'autres fichiers, d'autres sont manquantes.

#### C. Verbosité excessive du harnais Roo
Les fichiers `.roo/rules/` totalisent environ **2000+ lignes** chargées dans le system prompt. Les plus volumineux :
- `04-sddd-grounding.md` : ~300 lignes
- `05-tool-availability.md` : ~200 lignes
- `18-meta-analysis.md` : ~300 lignes
- `19-github-cli.md` : ~200 lignes
- `21-skepticism-protocol.md` : ~150 lignes

**Impact :** Consommation de tokens significative dans chaque conversation Roo. Le harnais Claude (12 fichiers condensés) consomme environ 50% moins de tokens.

### 3.2 Moyenne Priorité 🟡

#### D. Chevauchement `04-sddd-grounding.md` ↔ `16-no-tools-warnings.md`
Les deux fichiers Roo documentent les recommandations `detailLevel` et le fix #881. Le contenu se recouvre à ~40%.

**Recommandation :** Fusionner `16-no-tools-warnings.md` dans `04-sddd-grounding.md` (section detailLevel).

#### E. `11-incident-history.md` n'est pas une règle
Ce fichier documente l'historique des incidents. C'est de la documentation, pas une règle opérationnelle.

**Recommandation :** Déplacer vers `docs/harness/reference/incident-history.md` (déjà référencé).

#### F. `14-tdd-recommended.md` trop court
12 lignes, contenu trivial. Pourrait être fusionné avec `13-test-success-rates.md`.

#### G. Numérotation manquante (pas de `06-*`)
La séquence passe de `05-*` à `07-*`. Pas de bug fonctionnel mais incohérence de nommage.

#### H. IDs GraphQL hardcodés dans `19-github-cli.md`
Les field IDs du Project #67 sont hardcodés et peuvent devenir obsolètes si GitHub modifie les IDs.

### 3.3 Basse Priorité 🟢

#### I. 7 fichiers Roo sans version explicite
`01-general.md`, `02-intercom.md`, `03-mcp-usage.md`, `07-orchestrator-delegation.md`, `09-github-checklists.md`, `19-github-cli.md`, `22-validation.md` n'ont pas de version ni date de MAJ.

#### J. `context-window.md` (Claude) sans équivalent Roo
L'information sur le seuil de condensation 80% est partiellement dans `12-machine-constraints.md` mais pas dans une règle dédiée.

#### K. `08-file-writing.md` (Roo) vs `file-writing.md` (Claude)
Contenus très différents : Roo se concentre sur la limitation Qwen 3.5, Claude sur les patterns Edit/Write. Ce sont des règles adaptées à chaque agent, pas une incohérence.

---

## 4. Recommandations

### 4.1 Actions immédiates (haute priorité)

| # | Action | Bénéfice |
|---|--------|----------|
| R1 | **Condenser le harnais Roo** sur le modèle Claude (v2.0.0 condensées) | Réduction ~50% tokens par conversation |
| R2 | **Fusionner** `16-no-tools-warnings.md` dans `04-sddd-grounding.md` | Éliminer chevauchement |
| R3 | **Déplacer** `11-incident-history.md` vers `docs/harness/reference/` | Clarifier rôle (doc vs règle) |
| R4 | **Ajouter versions** aux 7 fichiers Roo sans version | Traçabilité |

### 4.2 Actions planifiées (moyenne priorité)

| # | Action | Bénéfice |
|---|--------|----------|
| R5 | **Fusionner** `14-tdd-recommended.md` dans `13-test-success-rates.md` | Réduction fichiers |
| R6 | **Ajouter** `friction-protocol.md` minimal côté Claude | Parité minimale |
| R7 | **Ajouter** référence croisée `context-window.md` dans `12-machine-constraints.md` | Cohérence |
| R8 | **Renommer** la séquence (combler le trou `06-*`) | Cohérence nommage |

### 4.3 Actions différées (basse priorité)

| # | Action | Bénéfice |
|---|--------|----------|
| R9 | **Extraire** IDs GraphQL de `19-github-cli.md` vers un fichier de config | Maintenabilité |
| R10 | **Évaluer** quelles règles Roo spécifiques méritent un équivalent Claude | Parité |

---

## 5. Métriques Résumées

| Métrique | Roo | Claude |
|----------|-----|--------|
| Nombre de fichiers | 22 | 12 |
| Fichiers versionnés | 15/22 (68%) | 12/12 (100%) |
| Dernière MAJ globale | 2026-03-30 | 2026-04-05 |
| Fichiers sans équivalent | 10 | 1 |
| Chevauchements internes | 2 (04↔16, 13↔14) | 0 |
| Fichiers mal catégorisés | 1 (11 = doc dans rules) | 0 |

---

**Fin du rapport.**
