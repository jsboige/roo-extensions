# Memory Auto-Injection - Feature Documentation

**Issue:** #1377
**Status:** Implemented ✅
**Date:** 2026-04-13
**Pattern Source:** Reddit 3-agent setup analysis (#1369)

---

## Overview

Le système d'auto-injection de mémoire prévient les erreurs récurrentes en chargeant automatiquement les leçons pertinentes de MEMORY.md au début de chaque tâche.

**Pattern validé (#1369) :**
- Reddit 3-agent setup utilise `lessons-learned.md` avant CHAQUE tâche
- Capture les erreurs récurrentes (ex: "SVG charts utilisent fixed viewBox")
- Faible coût de maintenance, économise des heures
- Mémoire active, pas passive

---

## Architecture

### Composants

1. **Skill `memory-inject`** (`.claude/skills/memory-inject/SKILL.md`)
   - Détection automatique du type de tâche
   - Filtrage des leçons par pertinence
   - Injection dans le contexte

2. **Intégration Session Pattern** (`~/.claude/CLAUDE.md`)
   - Étape 1.5 entre dashboard et travail
   - Invoqué automatiquement au début de chaque session

3. **Sources de mémoire** (hiérarchie)
   - `PROJECT_MEMORY.md` (projet, via git)
   - `MEMORY.md` (local, par machine)
   - `.claude/rules/*.md` (auto-chargées)
   - `~/.claude/CLAUDE.md` (global)

---

## Catégories de Tâches

| Catégorie | Mots-clés | Leçons typiques |
|-----------|-----------|-----------------|
| **mcp** | MCP, tool, serveur, config | AlwaysAllow, transport types, restart |
| **test** | test, vitest, jest, coverage | `npx vitest run`, troncation output |
| **git** | commit, push, PR, merge, worktree | Conventional commits, submodule workflow |
| **build** | build, compile, npm, typescript | Build path, dist vs build |
| **consolidation** | consolidate, merge, refactor | Checklist comptage avant/après |
| **coordination** | dashboard, RooSync, INTERCOM | Protocole communication, tags |
| **documentation** | doc, README, guide | SDDD bookend, triple grounding |

---

## Scoring de Pertinence

### Facteurs

| Facteur | Poids | Exemple |
|---------|-------|---------|
| **Correspondance catégorie** | 3.0 | Leçon MCP pour tâche MCP |
| **Récurrence** | 2.0 | Mentionnée 3+ fois = critique |
| **Impact** | 1.5 | "Critical", "IMPORTANT" |
| **Fraîcheur** | 1.0 | < 30 jours = plus pertinent |
| **Expérience utilisateur** | 0.5 | Patterns observés |

### Seuils

- **Score ≥ 3.0** : Toujours injecter (critique)
- **Score 2.0-2.9** : Injecter si pertinent (optionnel)
- **Score < 2.0** : Ne pas injecter (bruit)

---

## Workflow

### Début de Tâche

```
1. roosync_dashboard(read)     → Messages récents
2. memory-inject                → Leçons pertinentes
3. codebase_search (bookend)    → Contexte existant
4. conversation_browser         → Historique
5. TRAVAIL                      → Implémentation
```

### Fin de Tâche (debrief)

```
1. Capturer les leçons apprises
2. Mettre à jour MEMORY.md
3. Incrémenter compteurs de récurrence
4. Session suivante bénéficie des leçons
```

---

## Leçons par Catégorie

### MCP

```markdown
**MCP tools load at startup only**
- Pourquoi: Code changes ignored without restart
- Solution: VS Code restart obligatoire après modification MCP
- Impact: Évite heures de debug inutile

**Toujours vérifier alwaysAllow**
- Pourquoi: Nouveaux outils bloqués sans approbation
- Solution: roosync_mcp_management(subAction: "sync_always_allow")
- Impact: Outils disponibles immédiatement
```

### Test

```markdown
**Jamais npm test (watch mode bloque)**
- Pourquoi: Watch mode attend input indéfiniment
- Solution: npx vitest run (CI)
- Impact: Tests terminent, pas de blocage

**Tronquer output Vitest**
- Pourquoi: Output atteint ~600K chars
- Solution: npx vitest run 2>&1 | Select-Object -Last 30
- Impact: Contexte exploitable
```

### Git

```markdown
**Submodule workflow**
- Pourquoi: Commit parent sans commit submodule = pointer non mis à jour
- Solution: Commit inside first, push, puis git add mcps/internal dans parent
- Impact: Sous-module synchronisé

**Conventional commits**
- Pourquoi: Historique git illisible sans format standard
- Solution: type(scope): description + Co-Authored-By
- Impact: Git history exploitable
```

### Consolidation

```markdown
**Checklist comptage avant/après**
- Pourquoi: Oublier de retirer les anciens = compte augmente au lieu de baisser
- Solution: Compter AVANT, implémenter, compter APRÈS, calculer écart
- Impact: Consolidation validée

**Toujours retirer les deprecated**
- Pourquoi: Commenter ne suffit pas, exports pollués
- Solution: Retirer des exports barrel, pas juste commenter
- Impact: Compte outils correct
```

---

## Maintenance

### Quotidienne (après chaque tâche)

- **Si leçon utile** : Incrémenter compteur de récurrence
- **Si leçon non pertinente** : Décrémenter score, commenter pourquoi
- **Si nouvelle erreur récurrente** : Créer nouvelle leçon (score 3.0 par défaut)

### Mensuelle

- **Nettoyer les leçons obsolètes** : Score < 1.0 depuis 3 mois → archiver
- **Fusionner les doublons** : Leçons similaires → combiner
- **Déplacer les inutilisées** : Jamais utilisées → archive

---

## Intégration SDDD

Le skill `memory-inject` s'intègre dans le workflow SDDD existant :

```
BOOKEND DEBUT (existant)
  ↓
MEMORY-INJECT (nouveau)
  ↓
CONVERSATIONNEL (existant)
  ↓
TECHNIQUE (existant)
  ↓
TRAVAIL
  ↓
BOOKEND FIN (existant)
```

---

## Critères de Qualité

Une bonne leçon auto-injectée doit être :

- ✅ **Spécifique** : Action concrète, pas vague
- ✅ **Contextuelle** : Quand/où l'appliquer
- ✅ **Mesurable** : Impact quantifiable
- ✅ **Validée** : Testée dans des sessions réelles
- ✅ **Concise** : < 3 lignes pour éviter la surcharge

---

## Métriques

### Impact Attendu

- **-50%** d'erreurs récurrentes (estimation Reddit)
- **< 1 seconde** de surcharge par tâche
- **Faible coût** de maintenance (mensuelle)

### Mesure du Succès

- Taux de réduction des erreurs connues
- Temps économisé par session
- Nombre de leçons maintenues vs utilisées

---

## Références

- **Issue #1377** : Feature request originale
- **Issue #1369** : Analyse Reddit 3-agent setup
- **Skill** : `.claude/skills/memory-inject/SKILL.md`
- **Integration** : `~/.claude/CLAUDE.md` (Session Pattern)

---

**Dernière mise à jour :** 2026-04-13
