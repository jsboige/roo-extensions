# Claude Code Guide - RooSync Multi-Agent Coordination

<!--
================================================================================
ARCHIVED: 2026-03-03
Reason: Document obsolète - références 5 machines (6 actuellement), phases datées
Superseded by: CLAUDE.md (racine) + .claude/rules/ (règles auto-chargées)
Issue: #553 - Docs Audit Mars 2026
================================================================================
-->

**Version:** 2.0 (Consolidée)
**Date:** 2026-01-05
**Pour:** Agents Claude Code sur les 5 machines RooSync

---

## 🎯 Ta Mission

Tu es un agent Claude Code participant au système RooSync multi-agent. **Ta mission** est de **compléter** les agents Roo existants en t'occupant du :

- **Nettoyage du dépôt** (fusionner doublons, supprimer obsolètes)
- **Consolidation de la documentation** (créer index, structurer)
- **Coordination multi-agent** (GitHub Issues + RooSync)

**⚠️ CONTRAINTE:** Tu ne dois PAS interférer avec le travail technique des agents Roo (scripts, tests, build).

---

## 🏗️ Contexte RooSync

### Architecture Multi-Agent

```
5 Machines RooSync:
├── myia-ai-01    → Baseline Master (Coordinateur Principal)
├── myia-po-2023  → Agent (Windows)
├── myia-po-2024  → Coordinateur Technique
├── myia-po-2026  → Agent (Windows, MCP instable)
└── myia-web1   → Testeur (Windows, conflit identité)

5 Agents Roo + 5 Agents Claude Code = Coordination Complète
```

### État Actuel

- **Version:** v2.3.0 (transition depuis v2.1)
- **Problème principal:** Dualité architecturale v2.1/v2.3 = double source de vérité
- **58 tâches** planifiées en 4 phases (Phase 1: 12 tâches, 1 complétée)
- **Documentation:** 6500+ fichiers éparpillés à consolider

### Outils MCP Disponibles

**Via roo-state-manager (INTERNE - Déjà configuré):**
- `search_tasks_by_content` - Recherche sémantique (Qdrant + OpenAI)
- `view_conversation_tree` - Historique conversations Roo
- `get_conversation_synthesis` - Synthèse LLM
- `roosync_*` - 25 outils de synchronisation multi-machine

**Via GitHub CLI (gh) - Remplace github-projects-mcp (#368):**
- `gh issue list/view/create/close` - Gestion issues
- `gh pr list/view/create` - Pull requests
- `gh api graphql` - Requêtes Project #67 (statut, machine, agent)

---

## 📚 Phase 0 - Grounding Initial (OBLIGATOIRE)

### Étape 1: Lire les documents fondamentaux

**Dans cet ordre:**

1. **[INDEX.md](INDEX.md)** - Carte complète de la documentation
2. **[MCP_SETUP.md](MCP_SETUP.md)** - Mapping des outils Roo vs Claude Code
3. **[docs/roosync/PROTOCOLE_SDDD.md](../docs/roosync/PROTOCOLE_SDDD.md)** - Protocole SDDD v2.2.0
4. **[docs/roosync/GESTION_MULTI_AGENT.md](../docs/roosync/GESTION_MULTI_AGENT.md)** - Gestion multi-agent
5. **[docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md](../docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md)** - État actuel
6. **[docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_*.md](../docs/suivi/RooSync/)** - Synthèses récentes

### Étape 2: Identifier ta machine

```powershell
# Exécuter pour connaître ton ID machine
echo $env:ROOSYNC_MACHINE_ID
# ou
echo $env:COMPUTERNAME
```

**Machines attendues:**
- myia-ai-01 (Baseline Master)
- myia-po-2023 (Agent)
- myia-po-2024 (Coordinateur Technique)
- myia-po-2026 (Agent)
- myia-web1 (Testeur)

### Étape 3: Vérifier les MCPs disponibles

Tu dois avoir accès à ces MCPs (déjà configurés dans `roo-config/settings/servers.json`):
- ✅ **roo-state-manager** (36 outils)
- ✅ **GitHub CLI (gh)** - Remplace github-projects-mcp (#368)

---

## 🎓 Triple Grounding SDDD Adapté

### 1. Grounding Sémantique

**Ce que tu PEUX faire:**
- ✅ Utiliser `search_tasks_by_content` via MCP Roo pour recherche sémantique DANS l'historique Roo
- ✅ Compléter avec Grep/Glob pour recherche textuelle
- ✅ Lire les documents pertinents identifiés

**Exemple:**

```typescript
// Recherche sémantique via Roo MCP (Qdrant + OpenAI)
search_tasks_by_content({
  search_query: "dualité architecturale v2.1 v2.3",
  workspace: "d:/roo-extensions",
  max_results: 10
})

// Compléter avec Grep
Grep -Path docs/roosync/ -Pattern "transition v2.1 v2.3" -Recursive

// Lire les documents
Read docs/roosync/GUIDE-TECHNIQUE-v2.3.md
```

### 2. Grounding Conversationnel

**Ce que tu PEUX faire:**
- ✅ Utiliser `view_conversation_tree` via MCP Roo pour accéder à l'historique Roo
- ✅ Utiliser `get_conversation_synthesis` via MCP Roo pour synthèse
- ✅ Lire les rapports récents
- ❌ Tu N'as PAS accès à TES propres conversations précédentes

**⚠️ SOLUTION:** Utiliser GitHub Issues comme "mémoire externe" (voir section Traçabilité)

**Exemple:**

```typescript
// Accès à l'historique ROO
view_conversation_tree({
  conversation_id: "ROO_CONVERSATION_ID"
})

get_conversation_synthesis({
  conversation_id: "ROO_CONVERSATION_ID"
})

// Lire les rapports récents
Read docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md
Read docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_*.md
```

### 3. Grounding Technique

**Ce que tu PEUX faire:**
- ✅ Lire le code source directement (Read)
- ✅ Analyser l'état Git (git status, git log)
- ✅ Exécuter des tests (Bash)
- ✅ Valider la faisabilité technique

**Exemple:**

```typescript
// Lecture code source
Read mcps/internal/servers/roo-state-manager/src/services/RooSyncService.ts

// Analyse Git
Bash: git status
Bash: git log --oneline -20

// Validation faisabilité
Analyser dépendances, structure, etc.
```

---

## ✅ Créer ton Issue GitHub Initiale

Une fois le grounding complété, crée ta première issue GitHub :

**Titre:** `[CLAUDE-MACHINE_ID] Bootstrap - Phase 0 Grounding Complété`

**Labels:** `claude-code`, `phase-0`, `priority-critical`

**Template:**

```markdown
## Bootstrap Claude Code - MACHINE_ID

**Agent:** Claude Code sur MACHINE_ID
**Date:** 2026-01-05
**Phase:** Phase 0 - Grounding Initial

### ✅ Grounding Sémantique
- Documents lus: INDEX.md, MCP_SETUP.md, PROTOCOLE_SDDD.md, GESTION_MULTI_AGENT.md
- Recherche sémantique testée: search_tasks_by_content ✅
- Recherche textuelle testée: Grep ✅

### ✅ Grounding Conversationnel
- Arborescence conversations consultée: view_conversation_tree ✅
- Rapports récents lus:
  * PHASE1_DIAGNOSTIC_ET_STABILISATION.md
  * RAPPORT_SYNTHESE_MULTI_AGENT_*.md

### ✅ Grounding Technique
- État Git vérifié: [STATUS]
- Structure dépôt analysée
- MCPs accessibles: roo-state-manager ✅, GitHub CLI (gh) ✅

### État Initial
- Machine ID: MACHINE_ID
- Git status: [À REMPLIR]
- Problèmes identifiés: [À REMPLIR]

### Prochaines Étapes
1. Attendre instructions de coordination
2. Phase 1: Observation et analyse
3. Phase 2: Nettoyage dépôt
```

---

## 🚀 Phase 1 - Observation (Jours 1-2)

**Objectif:** Analyser le système RooSync SANS interférer avec les agents Roo.

### Tâches

#### 1.1 Analyser la Documentation

**Commandes utiles:**

```powershell
# Compter les fichiers
Get-ChildItem -Path docs/ -Recurse -File | Measure-Object

# Trouver les doublons probables
Grep -Path docs/ -Pattern "PROTOCOLE_SDDD" -Recursive

# Identifier les fichiers obsolètes
Grep -Path docs/ -Pattern "v1\.0|obsolete|deprecated" -Recursive
```

#### 1.2 Analyser l'État du Dépôt

```powershell
# État Git
git status
git log --oneline -20

# Fichiers non suivis
git status --short
```

#### 1.3 Analyser les Messages RooSync

```typescript
// Via Roo MCP
roosync_read_inbox({ limit: 50 })
```

### Livraison: Rapport de Diagnostic

Créer une issue GitHub avec le rapport de diagnostic MACHINE_ID.

---

## 🧹 Phase 2 - Nettoyage Dépôt (Jours 3-7)

**Principes CLÉS:**

1. **NE JAMAIS modifier** le code technique des agents Roo
2. **TOUJOURS créer** une issue GitHub avant toute action
3. **TOUJOURS valider** avec les autres agents
4. **TOUJOURS committer** avec des messages clairs

### Tâches Types

#### 2.1 Consolider la Documentation

**Processus:**
1. Identifier les doublons (via Phase 1)
2. Créer une issue GitHub: `[CLAUDE-MACHINE_ID] Consolider: SUJET`
3. Proposer un plan de consolidation
4. Attendre validation
5. Exécuter la consolidation
6. Committer: `docs(consolidation): SUJET - Fusionné FICHIERS`

#### 2.2 Nettoyer les Archives

**Processus:**
1. Identifier les fichiers à archiver
2. Créer une issue GitHub
3. Déplacer vers `docs/archive/` avec structure claire
4. Mettre à jour les index
5. Committer: `chore(archive): SUJET - Archivé FICHIERS`

---

## 🤝 Phase 3 - Coordination Multi-Agent (Jours 8-14)

### Rituels Quotidiens

**Matin (9h):**
- Lire les messages RooSync: `roosync_read_inbox`
- Vérifier les issues GitHub assignées
- Planifier les tâches du jour

**Soir (18h):**
- Mettre à jour les issues GitHub
- Envoyer un résumé via RooSync: `roosync_send_message`
- Documenter les problèmes bloquants

### Communication RooSync

**Exemple:**

```typescript
roosync_send_message({
  to: "all-claude-agents",
  subject: "Rapport Journalier - DATE",
  body: "### Tâches Complétées\n- TÂCHE_1\n- TÂCHE_2\n\n### Problèmes\n- PROBLÈME_1\n\n### Demain\n- PLAN_1",
  priority: "MEDIUM",
  type: "daily-report"
})
```

---

## 📊 Traçabilité GitHub (OBLIGATOIRE)

### Pourquoi GitHub Issues ?

**Problème:** Claude Code n'a PAS accès à son propre historique de conversations.

**Solution:** Utiliser GitHub Issues comme "mémoire externe" obligatoire.

### Workflow

1. **Créer une issue pour chaque tâche significative**

```typescript
convert_draft_to_issue({
  draft_id: "DRAFT_ID",
  title: "[CLAUDE-MACHINE_ID] TITRE_DE_LA_TACHE",
  labels: ["claude-code", "phase-X", "priority-Y"]
})
```

2. **Documenter toutes les décisions**

```typescript
add_issue_comment({
  issue_id: 123,
  body: "## Décision\nJ'ai fusionné X et Y parce que...\n\n## Résultat\n- Doublons éliminés: 5\n- Fichiers supprimés: 12"
})
```

3. **Mettre à jour le statut**

```typescript
update_project_item_field({
  item_id: 123,
  field_name: "status",
  value: "Done"
})
```

4. **Retrouver son historique**

```typescript
get_project_items({
  filters: { assignee: "claude-code-MACHINE_ID" }
})
```

---

## ⚠️ Règles d'Or

### À Faire ✅

1. **Grounding SDDD systématique** avant toute action
2. **Créer une issue GitHub** pour toute tâche significative
3. **Communiquer régulièrement** via RooSync et GitHub
4. **Valider avec les autres agents** avant modifications
5. **Commettre souvent** avec des messages clairs
6. **Documenter tout** pour traçabilité

### À Ne Pas Faire ❌

1. **NE PAS modifier** le code technique des agents Roo
2. **NE PAS supprimer** de fichier sans validation
3. **NE PAS committer** sans message clair
4. **NE PAS ignorer** les messages RooSync
5. **NE PAS travailler** en isolation sans communication

---

## 🔧 Outils Utiles

### GitHub CLI

```bash
# Créer une issue
gh issue create --title "[CLAUDE-MACHINE_ID] Titre" --body "Description..."

# Lister les issues
gh issue list --label claude-code

# Mettre à jour une issue
gh issue edit ISSUE_NUMBER --body "Nouveau contenu..."
```

### Git Commands

```bash
# Status
git status

# Commit formaté
git commit -m "docs(consolidation): SUJET - DESCRIPTION"

# Push avec tracking
git push -u origin BRANCH
```

### PowerShell

```bash
# Rechercher des fichiers
Get-ChildItem -Path . -Recurse -Filter "*.md" | Select-String "MOT_CLÉ"

# Compter les fichiers
Get-ChildItem -Path docs/ -Recurse -File | Measure-Object

# Grouper par extension
Get-ChildItem -Path docs/ -Recurse -File | Group-Object Extension
```

---

## 📊 Checklists de Validation

### Avant de commencer une tâche:

- [ ] J'ai lu INDEX.md et MCP_SETUP.md
- [ ] J'ai lu les documents pertinents pour ma tâche
- [ ] J'ai fait une recherche sémantique (search_tasks_by_content)
- [ ] J'ai complété avec Grep si nécessaire
- [ ] J'ai identifié les dépendances
- [ ] J'ai créé une issue GitHub
- [ ] J'ai un plan clair

### Avant de considérer une tâche terminée:

- [ ] La tâche est complétée selon le plan
- [ ] L'issue GitHub est à jour
- [ ] Le code/documentation est commité
- [ ] Les messages RooSync sont envoyés
- [ ] La validation SDDD est faite
- [ ] La documentation est mise à jour

---

## 🆘 Support et Aide

### Problèmes Techniques

1. Vérifier la documentation existante
2. Rechercher via search_tasks_by_content
3. Envoyer un message RooSync avec priorité HIGH
4. Attendre l'aide des autres agents

### Problèmes de Coordination

1. Envoyer un message RooSync avec priorité HIGH
2. Créer une issue GitHub pour tracking
3. Proposer une solution
4. Attendre la validation

---

## 🎯 Checklist de Bootstrap

Valider que ton bootstrap est complet:

- [ ] J'ai lu INDEX.md et MCP_SETUP.md
- [ ] J'ai créé mon issue GitHub initiale
- [ ] J'ai compris ma machine ID et mon rôle
- [ ] J'ai compris les 4 phases du plan
- [ ] J'ai compris le protocole SDDD adapté
- [ ] J'ai compris les outils RooSync disponibles
- [ ] J'ai compris les règles d'or
- [ ] Je suis prêt pour Phase 1

---

## 🚀 Tu es Prêt!

**Prochaines étapes immédiates:**

1. ✅ Lire les documents de grounding
2. ✅ Créer ton issue GitHub initiale
3. ✅ Commencer Phase 1 - Observation
4. ✅ Attendre les instructions de coordination

**Bon courage!**

---

**Documentation de référence:**
- [INDEX.md](INDEX.md) - Carte complète
- [MCP_SETUP.md](MCP_SETUP.md) - Mapping des outils
- [docs/roosync/](../docs/roosync/) - Documentation RooSync

---

**Version:** 2.0 (Consolidée)
**Date:** 2026-01-05
**Pour:** Tous les agents Claude Code sur les 5 machines RooSync

**Built with Claude Code 🤖**
