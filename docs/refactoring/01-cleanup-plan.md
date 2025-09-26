# Plan de Nettoyage et de Refactorisation - Phase 1

Ce document détaille la première phase de refactorisation du dépôt `roo-extensions`, axée sur le nettoyage, la centralisation et la clarification de la structure des fichiers et de la documentation.

## 1. Centralisation de la Documentation Principale

L'objectif est de regrouper toute la documentation de haut niveau dans le répertoire `docs`.

- **Déplacer :** [`ARCHITECTURE.md`](./ARCHITECTURE.md:1) -> `docs/architecture/01-main-architecture.md`
- **Déplacer :** [`GETTING-STARTED.md`](./GETTING-STARTED.md:1) -> `docs/guides/01-getting-started.md`
- **Déplacer :** [`CHANGELOG.md`](./CHANGELOG.md:1) -> `docs/project/01-changelog.md`
- **Déplacer :** [`COMMIT_STRATEGY.md`](./COMMIT_STRATEGY.md:1) -> `docs/guides/02-commit-strategy.md`

## 2. Nettoyage des Fichiers Obsolètes à la Racine

Suppression des plans et rapports obsolètes ou ponctuels qui n'ont plus leur place à la racine du projet.

- **Supprimer :** [`planning_refactoring_modes.md`](./planning_refactoring_modes.md:1) (obsolète)
- **Supprimer :** [`rapport-final-mission-sddd-jupyter-papermill-23092025.md`](./rapport-final-mission-sddd-jupyter-papermill-23092025.md:1) (rapport ponctuel)
- **Supprimer :** [`RAPPORT_VALIDATION_CONSOLIDATION_JUPYTER_PAPERMILL_24092025.md`](./RAPPORT_VALIDATION_CONSOLIDATION_JUPYTER_PAPERMILL_24092025.md:1) (rapport ponctuel)
- **Supprimer :** [`RAPPORT_RECUPERATION_REBASE_24092025.md`](./RAPPORT_RECUPERATION_REBASE_24092025.md:1) (rapport ponctuel)
- **Supprimer :** [`repair-plan.md`](./repair-plan.md:1) (plan ponctuel)
- **Supprimer :** [`conversation-analysis-reset-qdrant-issue.md`](./conversation-analysis-reset-qdrant-issue.md:1) (analyse ponctuelle)

## 3. Réorganisation du Répertoire `docs`

Clarification de la structure interne de `docs` pour séparer les rapports, les guides et la documentation d'architecture.

- **Consolider :** Fusionner `docs/reports` dans `docs/rapports`.
- **Déplacer :** Tous les rapports de validation (`validation-report-*.md`) de `docs/` vers `docs/rapports/validation/`.
- **Déplacer :** Tous les rapports de mission (`mission_report_*.md`, `RAPPORT-MISSION-*.md`) de `docs/` vers `docs/rapports/missions/`.
- **Déplacer :** Les guides spécifiques (`guide-*.md`) vers des sous-dossiers thématiques dans `docs/guides/`.

## 4. Gestion des Archives

Compression et nettoyage des dossiers d'archives pour alléger la structure du projet.

- **Archiver :** [`archive/`](./archive) -> `archive.zip` (et supprimer le dossier original).
- **Archiver :** [`docs/archive/`](./docs/archive) -> `docs/archive.zip` (et supprimer le dossier original).
- **Archiver :** [`refactor-backup-20250528-223209/`](./refactor-backup-20250528-223209) -> `archive/backups/refactor-backup-20250528-223209.zip` (et supprimer le dossier original).

## 5. Nettoyage des Tests et Rapports de Tests

Séparation claire entre les tests et leurs résultats.

- **Déplacer :** Les rapports de tests situés dans `tests/` (ex: `tests/escalation/rapport-tests-escalade.md`) vers `docs/rapports/tests/`.
