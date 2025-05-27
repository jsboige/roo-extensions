# Phase 2 - Log des Corrections MCP

**Date**: 27/05/2025 01:32
**Objectif**: Correction des références MCP obsolètes et résolution des duplications

## Fichiers sauvegardés

- `mcps/README.md` → `cleanup-backups/20250527-012300/phase2/README.md.backup`
- `mcps/TROUBLESHOOTING.md` → `cleanup-backups/20250527-012300/phase2/TROUBLESHOOTING.md.backup`
- `mcps/REORGANISATION-RAPPORT.md` → `cleanup-backups/20250527-012300/phase2/REORGANISATION-RAPPORT.md.backup`

## Corrections à effectuer

### 1. Références Jupyter obsolètes
- [ ] `mcps/README.md` ligne 47: Supprimer référence `external/jupyter/`
- [ ] `mcps/TROUBLESHOOTING.md` ligne 1256: Corriger lien Jupyter
- [ ] `mcps/REORGANISATION-RAPPORT.md`: Mettre à jour statut actuel

### 2. Duplication Docker
- [ ] Analyser différences entre `mcps/docker/` et `mcps/external/docker/`
- [ ] Fusionner ou supprimer selon logique appropriée

### 3. Validation cohérence
- [ ] Vérifier tous les liens internes
- [ ] S'assurer documentation reflète structure actuelle

## Modifications effectuées

### ✅ 1. Références Jupyter obsolètes corrigées
- `mcps/README.md` ligne 47: ✅ Corrigé `external/jupyter/` → `internal/servers/jupyter-mcp-server/`
- `mcps/TROUBLESHOOTING.md` ligne 1256: ✅ Corrigé lien Jupyter vers internal
- `mcps/REORGANISATION-RAPPORT.md`: ✅ Mis à jour statut Jupyter comme obsolète

### ✅ 2. Duplication Docker résolue
- ✅ Sauvegardé `mcps/docker/` vers `cleanup-backups/20250527-012300/phase2/docker-simple-backup/`
- ✅ Créé `mcps/external/docker/BUILD-LOCAL.md` avec contenu du guide simple
- ✅ Mis à jour `mcps/external/docker/README.md` pour référencer le nouveau guide
- ✅ Supprimé le répertoire dupliqué `mcps/docker/`

### ✅ 3. Références external-mcps corrigées
- ✅ `mcps/TROUBLESHOOTING.md`: 6 remplacements `external-mcps` → `external`
- ✅ `mcps/INDEX.md`: 13 remplacements `external-mcps` → `external`
- ✅ `mcps/INSTALLATION.md`: 6 remplacements `external-mcps` → `external`
- ✅ `mcps/SEARCH.md`: 2 remplacements `external-mcps` → `external`
- ✅ `mcps/external/win-cli/installation.md`: 2 remplacements `external-mcps` → `external`

### ⚠️ 4. Références mcp-servers identifiées
- 79 références à `mcp-servers` trouvées dans 29 fichiers
- Certaines sont dans des logs/historiques (à ne pas modifier)
- D'autres sont des références GitHub externes (à ne pas modifier)
- Les références dans la documentation principale nécessitent une évaluation cas par cas
