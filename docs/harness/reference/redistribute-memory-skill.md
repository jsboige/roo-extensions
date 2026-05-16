# Redistribute-Memory Skill V2 — Guide de référence

**Version:** 3.0.0
**Issue:** #2223
**MAJ:** 2026-05-16

---

## Vue d'ensemble

Le skill `redistribute-memory` audite et redistribue les connaissances entre 5 niveaux de hiérarchie (tiers). Il détecte les antipatterns de placement, propose un plan de redistribution, et l'exécute après validation utilisateur.

**Principes clés :**
- **Dry-run par défaut** — aucun changement sans validation user
- **T3 (rules) = sacré** — jamais touché sans validation explicite par action
- **T5 (MEMORY.md) = préservé** — aucune suppression de leçons sans preuve d'obsolescence
- **Multi-workspace** — fonctionne sur tout workspace sans modification du code skill

---

## Les 5 Tiers

| Tier | Fichier | Scope | Chargement | Mutabilité |
|------|---------|-------|------------|------------|
| **T1** | `~/.claude/CLAUDE.md` | Machine global, multi-workspace | Auto (toute session) | Faible (template git) |
| **T2** | `{workspace}/CLAUDE.md` | Workspace projet | Auto (sessions du projet) | Moyen (git) |
| **T3** | `{workspace}/.claude/rules/*.md` | Workspace rules | Auto (auto-loaded) | **SACRÉ** |
| **T4** | `{workspace}/docs/harness/reference/*.md` | Workspace deferred docs | Lazy (`Read` ciblé) | Élevé (git, docs) |
| **T5** | `~/.claude/projects/{slug}/memory/*.md` | Machine+workspace memory | Auto-injecté | Élevé (local) |

---

## Invocation

| Phrase | Mode |
|--------|------|
| "redistribue la mémoire" | dry-run (audit + plan) |
| "redistribue et applique" | dry-run + exécution après validation |
| "audit tiers" | dry-run Phase 0-1 uniquement |
| "/redistribute-memory" | dry-run complet |

---

## Workflow (5 phases)

### Phase 0 : Auto-détection

Résout automatiquement les chemins des 5 tiers à partir de la machine et du workspace courant.

1. Détecte la machine (hostname)
2. Identifie le workspace (cwd)
3. Calcule le slug Claude Code pour T5
4. Vérifie l'existence de chaque tier

### Phase 1 : Audit des 5 Tiers

Collecte pour chaque tier : nombre de fichiers, lignes, taille, dernière MAJ, sections thématiques.

**Seuils d'alerte :**
- T2 > 500 lignes → SATURATION
- T3 fichier > 150 lignes → VERBOSE
- T5 > 200 lignes → TRUNCATION RISK
- Doublons entre tiers → REDONDANCE

### Phase 2 : Détection d'Antipatterns

6 antipatterns recherchés :

| # | Antipattern | Détection |
|---|------------|-----------|
| AP1 | T1↔T2 duplication | Comparaison sections T1 vs T2 |
| AP2 | T1 contamination | Info projet-spécifique dans T1 |
| AP3 | Deferred candidate | Section >30L procédure dans T2 |
| AP4 | Rules redondantes | Chevauchement >30% entre fichiers T3 |
| AP5 | Topic orphelin | Fichier T5 non référencé dans MEMORY.md |
| AP6 | Contenu obsolète | Dates >14j, issues fermées, métriques décalées |

### Phase 3 : Plan de Redistribution (dry-run)

Produit un plan concret avec :
- Liste d'actions (Déplacer / Dédupliquer / Déférer / Indexer / Nettoyer)
- Source et destination par action
- Risque et impact par action
- Flag si l'action touche T3 (validation explicite requise)
- Total avant/après par tier

### Phase 4 : Exécution (après validation user)

Applique uniquement les actions validées par l'utilisateur. Pour chaque action :
1. Vérifie que le contenu source existe toujours
2. Exécute la transformation
3. Vérifie la cohérence

### Phase 5 : Rapport

Génère un rapport avant/après et le poste sur le dashboard workspace.

---

## Critères de placement par tier

### T1 — Machine Global
**"Est-ce utile dans TOUT workspace ?"**

Git workflow, tool discipline, safety rules, OS gotchas, terminologie utilisateur, knowledge preservation.

### T2 — Workspace Projet
**"Spécifique au projet, haut niveau."**

Architecture, canaux de communication, vue d'ensemble. Résumés 3-5 lignes + liens vers T4 pour les détails.

### T3 — Workspace Rules (SACRÉ)
**"Règles techniques auto-chargées."**

Protocoles techniques, conventions de code, checklists validation, sécurité. Ne jamais modifier sans validation user par action.

### T4 — Workspace Deferred
**"Documentation détaillée, accès lazy."**

Procédures build/deploy, docs MCP détaillées, architecture détaillée, guides opérationnels, post-mortems.

### T5 — Machine+Workspace Memory
**"État transitoire, lessons learned."**

État courant, lessons récentes, info spécifique machine, index des topic files.

---

## T4 adaptatif

Le skill détecte automatiquement la structure de docs du workspace :

| Workspace | Chemin T4 détecté |
|-----------|-------------------|
| roo-extensions | `docs/harness/reference/` |
| CoursIA | `docs/` (si pas de `docs/harness/reference/`) |
| Autre | Premier `docs/` trouvé ou proposé |

---

## Exemple de sortie dry-run

```
## Plan de Redistribution — myia-po-2025 / D:\roo-extensions

### Résumé
- 4 antipatterns détectés
- 3 actions proposées
- Volume estimé : -120 lignes T2, +1 fichier T4

### Actions proposées

#### ACTION-1 : Déférer
- **Source :** T2, CLAUDE.md, lignes 45-130 (Procédure MCP détaillée)
- **Destination :** T4, docs/harness/reference/mcp-procedure.md
- **Contenu :** Configuration MCP complète avec diagnostic
- **Raison :** Procédure 85 lignes dans T2, mieux en deferred
- **Impact :** T2 -85 lignes, T4 +1 fichier
- **Risque :** Faible (info accessible via Read)
- **Requiert validation T3 :** non

#### ACTION-2 : Dédupliquer
- **Source :** T2, CLAUDE.md, lignes 200-220 (Git workflow)
- **Destination :** (retrait, déjà dans T1)
- **Contenu :** Conventional commits + force push rules
- **Raison :** Déjà présent dans T1 (~/.claude/CLAUDE.md lignes 30-50)
- **Impact :** T2 -20 lignes
- **Risque :** Faible
- **Requiert validation T3 :** non

#### ACTION-3 : Indexer
- **Source :** T5, memory/docker-patterns.md
- **Destination :** T5, MEMORY.md (index)
- **Contenu :** Ajouter référence au topic file orphelin
- **Raison :** Fichier existant non référencé dans l'index
- **Impact :** T5 +2 lignes
- **Risque :** Faible
- **Requiert validation T3 :** non

### Validation requise
- [ ] ACTION-1 : Déférer procédure MCP vers docs/
- [ ] ACTION-2 : Retirer doublon Git workflow de T2
- [ ] ACTION-3 : Indexer topic file orphelin
```

---

## Historique

| Version | Date | Changement |
|---------|------|------------|
| 1.0.0 | 2026-01 | Version initiale |
| 2.0.0 | 2026-02 | Multi-workspace, scan complet, diagnostic rapide |
| 3.0.0 | 2026-05-16 | V2 issue #2223 — 5 tiers, 6 antipatterns, dry-run par défaut, T3 sacré, T5 préservé |

---

## Cross-links

- **CoursIA #1157** : Phase 1 utilisera ce skill V2 pour déport CLAUDE.md vers `docs/cartography.md` + `docs/procedures.md`
- **roo-extensions #2224** : MCP footprint audit (issue jumelle, scope séparé)
- **Skill source :** `.claude/skills/redistribute-memory/SKILL.md`
