# Plan de Nettoyage et de Refactorisation - Phase 1

Ce document détaille la première phase de refactorisation du dépôt `roo-extensions`, axée sur le nettoyage, la centralisation et la clarification de la structure des fichiers et de la documentation.

## 1. Centralisation de la Documentation Principale

L'objectif est de regrouper toute la documentation de haut niveau dans le répertoire `docs`.

- [x] **Déplacer :** `ARCHITECTURE.md` -> `docs/architecture/01-main-architecture.md`
- [x] **Déplacer :** `GETTING-STARTED.md` -> `docs/guides/01-getting-started.md`
- [x] **Déplacer :** `CHANGELOG.md` -> `docs/project/01-changelog.md`
- [x] **Déplacer :** `COMMIT_STRATEGY.md` -> `docs/guides/02-commit-strategy.md`

## 2. Nettoyage des Fichiers Obsolètes à la Racine

Suppression des plans et rapports obsolètes ou ponctuels qui n'ont plus leur place à la racine du projet.

- [x] **Supprimer :** `planning_refactoring_modes.md` (obsolète)
- [x] **Supprimer :** `rapport-final-mission-sddd-jupyter-papermill-23092025.md` (rapport ponctuel)
- [x] **Supprimer :** `RAPPORT_VALIDATION_CONSOLIDATION_JUPYTER_PAPERMILL_24092025.md` (rapport ponctuel)
- [x] **Supprimer :** `RAPPORT_RECUPERATION_REBASE_24092025.md` (rapport ponctuel)
- [x] **Supprimer :** `repair-plan.md` (plan ponctuel)
- [x] **Supprimer :** `conversation-analysis-reset-qdrant-issue.md` (analyse ponctuelle)

## 3. Réorganisation du Répertoire `docs`

Clarification de la structure interne de `docs` pour séparer les rapports, les guides et la documentation d'architecture.

- [x] **Consolider :** Fusionner `docs/reports` dans `docs/rapports`.
- [x] **Déplacer :** Tous les rapports de validation (`validation-report-*.md`) de `docs/` vers `docs/rapports/validation/`.
- [x] **Déplacer :** Tous les rapports de mission (`mission_report_*.md`, `RAPPORT-MISSION-*.md`) de `docs/` vers `docs/rapports/missions/`.
- **Déplacer :** Les guides spécifiques (`guide-*.md`) vers des sous-dossiers thématiques dans `docs/guides/`.

## 4. Gestion des Archives

Compression et nettoyage des dossiers d'archives pour alléger la structure du projet.

- **Archiver :** [`archive/`](./archive) -> `archive.zip` (et supprimer le dossier original).
- **Archiver :** [`docs/archive/`](./docs/archive) -> `docs/archive.zip` (et supprimer le dossier original).
- **Archiver :** [`refactor-backup-20250528-223209/`](./refactor-backup-20250528-223209) -> `archive/backups/refactor-backup-20250528-223209.zip` (et supprimer le dossier original).

## 5. Nettoyage des Tests et Rapports de Tests

Séparation claire entre les tests et leurs résultats.

- **Déplacer :** Les rapports de tests situés dans `tests/` (ex: `tests/escalation/rapport-tests-escalade.md`) vers `docs/rapports/tests/`.
