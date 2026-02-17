# Répertoire des Scripts

Ce répertoire centralise tous les scripts PowerShell et JavaScript utilisés pour l'outillage et l'automatisation du projet. Les scripts sont organisés en sous-répertoires basés sur leur fonctionnalité.

**À la racine :** Aucun script (tous ventilés dans les sous-répertoires)

## Structure des Répertoires (26 sous-répertoires)

**Diagnostic & Debug:**

- `/diagnostic` : Outils pour le diagnostic de l'environnement technique
  - `/hierarchy` : Scripts de debug hiérarchie des tâches (9 scripts)

**Git & Workflow:**

- `/git` : Scripts d'opération Git
- `/git-workflow` : Scripts de workflow Git complexes (commit, submodule, retour main)

**Encoding & Format:**

- `/encoding` : Scripts pour la correction de l'encodage des fichiers (BOM, UTF-8, emoji)
- `/utf8` : Scripts spécifiques UTF-8

**MCP & Services:**

- `/mcp` : Scripts de gestion et validation des serveurs MCP
- `/roosync` : Scripts de synchronisation multi-machines

**Maintenance & Cleanup:**

- `/maintenance` : Outils pour la maintenance du projet
- `/cleanup` : Scripts de nettoyage

**Tests & Validation:**

- `/testing` : Scripts de tests unitaires et E2E
- `/validation` : Scripts de validation fonctionnelle

**Setup & Install:**

- `/setup` : Scripts pour la configuration initiale
- `/install` : Scripts d'installation des dépendances

**Analysis:**

- `/analysis` : Scripts d'analyse de code et commits
- `/audit` : Scripts d'audit

**Monitoring:**

- `/monitoring` : Scripts de monitoring
- `/inventory` : Scripts d'inventaire

**Messaging:**

- `/messaging` : Scripts de ventilation et communication

**Scheduling:**

- `/scheduling` : Scripts liés au scheduler Roo

**Autres:**

- `/deployment` : Scripts pour le déploiement des configurations
- `/docs` : Scripts de documentation
- `/memory` : Scripts de gestion mémoire
- `/worktrees` : Scripts de gestion des worktrees
- `/benchmarks` : Scripts de benchmark
- `/claude-md` : Scripts spécifiques Claude MD

## Scripts Archivés (_archive/)

Le répertoire `/_archive` contient les scripts obsolètes ou à usage unique, **ne pas utiliser**.

**Sous-répertoires d'archive:**

- `consolidate-docs/` : Scripts consolidation docs (terminé, 4 scripts)
- `consolidation-phase/` : Scripts de phases #481 (4 scripts)
- `demo-scripts/` : Scripts de démo obsolètes (3 scripts)
- `ffmpeg/` : Scripts FFmpeg (obsolète, 6 scripts)
- `github-projects-mcp/` : Scripts tests MCP GitHub Projects (déprécié, 3 scripts)
- `transients/` : Scripts temporaires (1 script)

**Date de consolidation :** 2026-02-17 (Issue #481)

Pour plus de détails sur l'architecture, voir [`docs/repository-map.md`](../docs/repository-map.md).
