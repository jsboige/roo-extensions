# Skill : Redistribution Memoire & Regles — V2 (5 Tiers)

**Version:** 3.0.0 (2026-05-16)
**Issue:** #2223
**Usage:** `/redistribute-memory` ou "redistribue la memoire", "audite les regles", "nettoie CLAUDE.md"

Ce skill audite et redistribue les connaissances entre 5 niveaux de hierarchie. Il detecte les antipatterns, propose un plan de redistribution, et l'execute apres validation utilisateur.

**La version complete du skill se trouve dans :** `.claude/skills/redistribute-memory/SKILL.md`

**Documentation de reference :** `docs/harness/reference/redistribute-memory-skill.md`

---

## Les 5 Tiers

| Tier | Fichier | Scope | Chargement |
|------|---------|-------|------------|
| **T1** Machine Global | `~/.claude/CLAUDE.md` | Toutes sessions, tous workspaces | Auto |
| **T2** Workspace Projet | `{workspace}/CLAUDE.md` | Ce workspace | Auto |
| **T3** Workspace Rules | `{workspace}/.claude/rules/*.md` | Ce workspace | Auto — **SACRE** |
| **T4** Workspace Deferred | `{workspace}/docs/harness/reference/*.md` | Ce workspace | Lazy (`Read`) |
| **T5** Machine+Workspace Memory | `~/.claude/projects/{slug}/memory/*.md` | Machine+workspace | Auto-injecte |

---

## Workflow rapide

1. **Phase 0** : Auto-detection (machine, workspace, slug, chemins tiers)
2. **Phase 1** : Audit (volume, lignes, sections par tier)
3. **Phase 2** : Detection antipatterns (6 types)
4. **Phase 3** : Plan dry-run (actions proposees, validation user)
5. **Phase 4** : Execution (apres validation uniquement)
6. **Phase 5** : Rapport (dashboard workspace)

---

## Regles absolues

- **dry-run par defaut** — aucun changement sans validation user
- **T3 (rules) = sacre** — jamais touche sans validation explicite par action
- **T5 (MEMORY.md) = preserve** — aucune suppression de lecons sans preuve d'obsolescence
- **Multi-workspace** — fonctionne sur tout workspace (roo-extensions, CoursIA, autre)

---

## 6 Antipatterns detectes

1. T1<->T2 duplication (info universelle dupliquee dans CLAUDE.md projet)
2. T1 contamination (info projet-specifique dans le global)
3. Deferred candidate (procedure longue dans T2 au lieu de T4)
4. Rules redondantes (chevauchement >30% entre fichiers T3)
5. Topic orphelin (fichier T5 non reference dans MEMORY.md)
6. Contenu obsolete (dates >14j, issues fermees, metriques decalees)

---

## Cross-links

- **Source skill :** `.claude/skills/redistribute-memory/SKILL.md`
- **Reference doc :** `docs/harness/reference/redistribute-memory-skill.md`
- **CoursIA #1157** : Phase 1 utilisera ce skill V2
- **roo-extensions #2224** : MCP footprint audit (issue jumelle)
