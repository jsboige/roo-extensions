# Analyse de Deduplication des Scripts PowerShell

**Date:** 2026-05-06
**Issue:** #656
**Mode:** Analyse statique des scripts `scripts/` et `scripts/_archive/`

---

## 1. Statistiques Generales

| Categorie | Nombre |
|-----------|--------|
| Scripts `.ps1` dans `scripts/` | ~340 |
| Scripts dans `scripts/_archive/duplicates/` | 8 |
| Scripts dans `scripts/_archive/dated/` | 20 |
| Scripts dans `scripts/_archive/` (racine) | 2 |
| **Total scripts** | **~370** |

---

## 2. Doublons de Nom Exact

**AUCUN doublon de nom exact trouve.** Tous les scripts ont des noms uniques dans l'arborescence `scripts/`.

---

## 3. Scripts dans `_archive/duplicates/` (8 fichiers)

Ces scripts sont **uniquement** dans le dossier `duplicates` et ne sont dupliqués nulle part ailleurs :

| Script | Statut |
|--------|--------|
| `auto-cleanup.ps1` | Uniquement dans `_archive/duplicates/` |
| `auto-review-simple.ps1` | Uniquement dans `_archive/duplicates/` |
| `cleanup-worktrees.ps1` | Uniquement dans `_archive/duplicates/` |
| `compile-mcp-servers.ps1` | Uniquement dans `_archive/duplicates/` |
| `Convert-McpSettings.ps1` | Uniquement dans `_archive/duplicates/` |
| `Convert-McpSettings-Fixed.ps1` | Uniquement dans `_archive/duplicates/` |
| `Generate-UTF8ValidationReport.ps1` | Uniquement dans `_archive/duplicates/` |
| `mcp-monitor.ps1` | Uniquement dans `_archive/duplicates/` |

**Conclusion:** Ce dossier est deja une zone d'archivage. Ces scripts sont des doublons qui ont deja ete identifies et deplaces ici. **Aucune action necessaire** - ils sont deja archives.

---

## 4. Paires Semantiques Identifiees

### 4.1 `auto-review.ps1` vs `auto-review-simple.ps1`

| Aspect | auto-review.ps1 | auto-review-simple.ps1 |
|--------|-----------------|------------------------|
| **Emplacement** | `scripts/review/` | `scripts/_archive/duplicates/` |
| **Fonction** | Review complet via sk-agent HTTP | Version legere via vLLM direct |
| **Relation** | Script principal | Delegate vers auto-review.ps1 en mode vllm |

**Verdict:** `auto-review-simple.ps1` est une version legere qui delegate vers le script principal. **CONSOLIDABLE** - `auto-review-simple.ps1` peut etre supprime et remplace par un appel direct a `auto-review.ps1 -Mode vllm`.

---

### 4.2 `cleanup-worktree.ps1` vs `cleanup-worktrees.ps1`

| Aspect | cleanup-worktree.ps1 | cleanup-worktrees.ps1 |
|--------|----------------------|-----------------------|
| **Emplacement** | `scripts/worktrees/` | `scripts/_archive/duplicates/` |
| **Fonction** | Nettoie UN worktree apres merge PR | Nettoie TOUS les worktrees orphelons |
| **Différence** | Operation ciblee sur une PR | Operation batch automatique |

**Verdict:** **PAS DE DOUBLON** - Deux fonctions differentes. `cleanup-worktree.ps1` est pour un worktree specifique, `cleanup-worktrees.ps1` est pour le nettoyage batch.

---

### 4.3 `Convert-McpSettings.ps1` vs `Convert-McpSettings-Fixed.ps1`

| Aspect | Convert-McpSettings.ps1 | Convert-McpSettings-Fixed.ps1 |
|--------|-------------------------|-------------------------------|
| **Emplacement** | `scripts/_archive/duplicates/` | `scripts/_archive/duplicates/` |
| **Fonction** | Conversion MCP settings | Version corrigee du meme script |
| **Différence** | Version originale (fichier avec BOM/encodage problematique) | Version corrigee (encodage propre) |

**Verdict:** **DOUBLON CONSOLIDABLE** - Garder uniquement `Convert-McpSettings-Fixed.ps1` (version fonctionnelle), supprimer l'original.

---

### 4.4 `test-jupyter-papermill-mcp-integration.ps1` vs `test-jupyter-papermill-mcp-simple.ps1`

| Aspect | -integration.ps1 | -simple.ps1 |
|--------|------------------|-------------|
| **Emplacement** | `scripts/mcp/` | `scripts/mcp/` |
| **Fonction** | Test d'integration complet | Version simplifiee |

**Verdict:** **CONSOLIDABLE** - La version "simple" est une version allégée. Garder la version "integration" comme reference principale, supprimer le "-simple" si la version integration couvre tous les cas.

---

### 4.5 `test-staged-workflow.ps1` vs `test-staged-workflow-simple.ps1`

| Aspect | test-staged-workflow.ps1 | test-staged-workflow-simple.ps1 |
|--------|--------------------------|---------------------------------|
| **Emplacement** | `scripts/scheduling/` | `scripts/scheduling/` |
| **Fonction** | Test complet du workflow | Test simple de logging |

**Verdict:** **CONSOLIDABLE** - Le "-simple" est un test de validation basique. Garder le complet, supprimer le "-simple" si le complet couvre le meme scope.

---

### 4.6 `validate-deployment.ps1` vs `validate-deployment-simple.ps1`

| Aspect | validate-deployment.ps1 | validate-deployment-simple.ps1 |
|--------|-------------------------|--------------------------------|
| **Emplacement** | `scripts/validation/` | `scripts/validation/` |
| **Fonction** | Validation deployment UTF-8 | Version simplifiee |

**Verdict:** **CONSOLIDABLE** - Garder la version principale, supprimer le "-simple" si la version principale est suffisante.

---

### 4.7 Autres paires de moindre importance

| Paire | Verdict |
|-------|---------|
| `ventilation-rapports.ps1` vs `ventilation-rapports-complement.ps1` | **UTILES** - Le complement ajoute des donnees supplementaires |
| `poll-dashboard.ps1` vs `poll-dashboard-wrapper.ps1` | **UTILES** - Le wrapper ajoute une couche d'abstraction |
| `install-worktree-cleanup-scheduled-task.ps1` vs `worktree-cleanup.ps1` | **UTILES** - L'un installe la tache planifiee, l'autre execute le nettoyage |
| `setup.ps1` vs `setup-ascii-safe.ps1` vs `setup-docker-watchdog.ps1` etc. | **UTILES** - `setup.ps1` est le point d'entree, les autres sont specialises |

---

## 5. Recommendations de Consolidation

### Priorite HAUTE (doublons evidents)

| Action | Scripts | Gain |
|--------|---------|------|
| Supprimer `Convert-McpSettings.ps1` | Garder uniquement `-Fixed` | 1 fichier |
| Supprimer `auto-review-simple.ps1` | Delegate vers `auto-review.ps1 -Mode vllm` | 1 fichier |

### PriorITE MOYENNE (versions "simple" en doublon partiel)

| Action | Scripts | Gain |
|--------|---------|------|
| Supprimer `test-jupyter-papermill-mcp-simple.ps1` | Garder `-integration` | 1 fichier |
| Supprimer `test-staged-workflow-simple.ps1` | Garder `test-staged-workflow.ps1` | 1 fichier |
| Supprimer `validate-deployment-simple.ps1` | Garder `validate-deployment.ps1` | 1 fichier |

### PriorITE BASSE (scripts deja archives)

| Action | Scripts | Gain |
|--------|---------|------|
| Vider `_archive/duplicates/` | 8 fichiers deja archives | 8 fichiers |

---

## 6. Total Potentiel de Consolidation

| Categorie | Fichiers a supprimer |
|-----------|---------------------|
| Priorite HAUTE | 2 |
| Priorite MOYENNE | 3 |
| Priorite BASSE (archive) | 8 |
| **TOTAL** | **13 fichiers** |

---

## 7. Scripts a NE PAS Toucher

Les scripts suivants ont des fonctions distinctes et ne sont PAS des doublons :

- `cleanup-worktree.ps1` vs `cleanup-worktrees.ps1` (fonctions differentes)
- `ventilation-rapports.ps1` vs `ventilation-rapports-complement.ps1` (complementaire)
- `poll-dashboard.ps1` vs `poll-dashboard-wrapper.ps1` (wrapper d'abstraction)
- `install-worktree-cleanup-scheduled-task.ps1` vs `worktree-cleanup.ps1` (installation vs execution)
- `setup.ps1` et ses variantes specialisees (`setup-ascii-safe`, `setup-docker-watchdog`, etc.)

---

**Fin de l'analyse.**
