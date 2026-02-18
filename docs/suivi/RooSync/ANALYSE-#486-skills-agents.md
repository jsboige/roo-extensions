# Analyse #486 - Amélioration Skills/Agents/Commands/Rules/Modes

**Date:** 2026-02-18
**Auteur:** Claude Code (myia-po-2023)
**Issue:** https://github.com/jsboige/roo-extensions/issues/486

---

## 1. État des Lieux

### 1.1 Inventaire Skills (6)

| Skill | Bash Requis | Fallback | Statut |
|-------|-------------|----------|--------|
| `sync-tour` | ✅ Oui | ❌ Aucun | ⚠️ Paralysé sans bash |
| `git-sync` | ✅ Oui | ❌ Aucun | ⚠️ Paralysé sans bash |
| `github-status` | ❌ Non (gh CLI via bash) | ❌ Aucun | ⚠️ Partiel |
| `validate` | ✅ Oui | ❌ Aucun | ⚠️ Paralysé sans bash |
| `debrief` | ✅ Oui | ❌ Aucun | ⚠️ Partiel |
| `redistribute-memory` | ? | ? | Non analysé |

### 1.2 Inventaire Agents (12)

| Agent | Bash Requis | Autres Outils | Statut sans bash |
|-------|-------------|---------------|------------------|
| `intercom-handler` | ❌ Non | Read, Glob, Grep | ✅ Fonctionnel |
| `sddd-router` | ❌ Non | Read, Glob, Grep | ✅ Fonctionnel |
| `intercom-compactor` | ❌ Probablement non | Read, Glob, Grep | ✅ Probablement OK |
| `github-tracker` | ✅ Oui (gh CLI) | Read, Grep | ⚠️ Partiel |
| `task-planner` | ❌ Non | Read, Grep, Glob, Bash | ✅ Analyse OK |
| `roosync-hub` | ❌ Non | MCPs RooSync | ✅ Fonctionnel |
| `roosync-reporter` | ❌ Non | MCPs RooSync | ✅ Fonctionnel |
| `dispatch-manager` | ❌ Non | Read, Grep, Glob | ✅ Fonctionnel |
| `task-worker` | ✅ Oui | Read, Grep, Glob, Edit, Write | ⚠️ Investigation OK, validation non |
| `consolidation-worker` | ✅ Oui | Read, Grep, Glob, Edit, Write | ⚠️ Code OK, build/tests non |
| `test-investigator` | ✅ Oui | Read, Grep, Glob, Bash, Edit | ⚠️ Analyse OK, run tests non |
| `doc-updater` | ✅ Oui | Read, Grep, Glob, Edit, Write, Bash | ⚠️ Écriture OK, git non |

### 1.3 Inventaire Commands (4)

| Command | Bash Requis | Impact |
|---------|-------------|--------|
| `/coordinate` | ✅ Oui | Phases git/tests paralysées |
| `/executor` | ✅ Oui | Phases git/tests paralysées |
| `/debrief` | ⚠️ Partiel | Git metrics non disponibles |
| `/switch-provider` | ❌ Non | ✅ Fonctionnel |

---

## 2. Problèmes Identifiés

### 2.1 Dépendance Critique Bash

**Problème:** Issue #488 - Bash tool silently fails avec "Exit code 1"

**Impact:**
- 8/12 agents partiellement paralysés
- 4/6 skills non fonctionnels
- Workflow executor/coordinate dégradé

**Cause probable:** Mise à jour Claude Code (voir GitHub issues anthropics/claude-code)

### 2.2 Absence de Fallback

**Problème:** Aucun skill/agent n'a de mécanisme de fallback vers:
- MCP `win-cli` (commandes shell Windows)
- Outils alternatifs (PowerShell via MCP)

**Conséquence:** Tout échec bash = blocage complet

### 2.3 Incohérence Dépendances

**Problème:** Certains agents listent `Bash` dans `tools:` mais pourraient fonctionner sans:
- `task-planner` - Analyse seulement, n'a pas besoin de bash
- `doc-updater` - Read/Write suffisent pour documentation

---

## 3. Propositions d'Amélioration

### 3.1 Règle Bash-Fallback (NOUVEAU)

Créer `.claude/rules/bash-fallback.md`:

```markdown
# Règle Bash-Fallback

## Problème
L'outil Bash peut échouer silencieusement (issue #488).

## Mitigation

### Priorité 1: Éviter Bash
Toujours privilégier les outils natifs:
- **Read** au lieu de `cat`
- **Glob** au lieu de `ls`/`find`
- **Grep** au lieu de `grep`
- **Edit/Write** au lieu de `sed`/`echo`

### Priorité 2: MCP win-cli
Si bash indispensable, utiliser MCP `win-cli` comme fallback:
```
try Bash → si Exit code 1 → utiliser mcp__win-cli__execute_command
```

### Priorité 3: Dégradation Gracieuse
Si shell indisponible:
1. Documenter les actions bloquées
2. Continuer avec tâches alternatives (lecture, analyse, documentation)
3. Signaler via RooSync au coordinateur
```

### 3.2 Mise à Jour Agents

**Agents à corriger (retirer Bash si non requis):**
- `task-planner` → Retirer Bash (analyse uniquement)
- `doc-updater` → Retirer Bash (git sera fait manuellement)

**Agents à renforcer (fallback win-cli):**
- `task-worker` → Ajouter note sur fallback
- `consolidation-worker` → Ajouter note sur validation manuelle
- `test-investigator` → Ajouter note sur investigation sans run

### 3.3 Skill "validate" Sans Bash

Créer variante `validate-read-only`:
- Build check → Demander à utilisateur
- Tests → Demander à utilisateur
- Analyse résultats → Agent lit les fichiers de log

### 3.4 Command "executor" Résilient

Mettre à jour executor.md pour:
1. Détecter échec bash en Phase 1
2. Passer en mode "dégradé" (lecture/analyse uniquement)
3. Signaler au coordinateur via RooSync

---

## 4. Actions Recommandées

| Priorité | Action | Impact |
|----------|--------|--------|
| **P0** | Créer règle `bash-fallback.md` | Documente mitigation |
| **P0** | Mettre à jour CLAUDE.md avec #488 | Informe toutes les machines |
| **P1** | Créer skill `shell-fallback` | Standardise mitigation |
| **P1** | Mettre à jour `executor.md` | Mode dégradé |
| **P2** | Nettoyer dépendances Bash agents | Réduit dépendance |

---

## 5. Métriques de Succès

- **Résilience** : 80% des agents fonctionnels sans bash
- **Documentation** : 100% des règles documentées
- **Recovery** : Temps de récupération < 5 min après détection bash cassé

---

**Prochaine étape:** Valider propositions avec coordinateur puis implémenter.
