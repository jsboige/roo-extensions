---
name: memory-inject
description: Auto-inject relevant MEMORY.md lessons at task start based on task type. Utilise ce skill automatiquement au début de chaque tâche significative pour prévenir les erreurs récurrentes. Pattern validé par l'analyse Reddit 3-agent (#1369).
metadata:
  author: "Roo Extensions Team"
  version: "1.0.0"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
    restrictions: "Requiert accès aux fichiers MEMORY.md (projet et local)"
---

# Skill: Memory Auto-Injection

**Version:** 1.0.0
**Cree:** 2026-04-13
**Issue:** #1377
**Pattern source:** Reddit 3-agent setup analysis (#1369)

---

## Objectif

Auto-injecter les leçons pertinentes de MEMORY.md au début de chaque tâche pour prévenir les erreurs récurrentes, basé sur le pattern validé par l'analyse Reddit 3-agent.

**Pattern Reddit (validé #1369) :**
- `lessons-learned.md` est lu avant CHAQUE tâche
- Capture les erreurs récurrentes (ex: SVG charts utilisent fixed viewBox)
- Faible coût de maintenance, économise des heures
- Mémoire active, pas passive

---

## Fonctionnement

### Détection automatique du type de tâche

Le skill détecte automatiquement le type de tâche basé sur:
1. **Mots-clés dans la demande utilisateur** (ex: "test", "MCP", "git", "PR")
2. **Contexte du workspace** (fichiers modifiés, branche actuelle)
3. **Historique récent** (conversation_browser pour tâches similaires)

### Catégories de tâches

| Catégorie | Mots-clés | Leçons typiques |
|-----------|-----------|-----------------|
| **mcp** | MCP, tool, serveur, config | AlwaysAllow, transport types, restart |
| **test** | test, vitest, jest, coverage | `npx vitest run`, troncation output |
| **git** | commit, push, PR, merge, worktree | Conventional commits, submodule workflow |
| **build** | build, compile, npm, typescript | Build path, dist vs build |
| **consolidation** | consolidate, merge, refactor | Checklist comptage avant/après |
| **coordination** | dashboard, RooSync, INTERCOM | Protocole communication, tags |
| **documentation** | doc, README, guide | SDDD bookend, triple grounding |

### Injection conditionnelle

Le skill n'injecte que les leçons **pertinentes** pour:
- Éviter la surcharge contextuelle
- Garder les leçons fraîches (pas de dilution)
- Permettre la mise à jour du scoring

---

## Workflow

### Phase 1 : Détection du type de tâche

**Analyser la demande utilisateur :**

```bash
# Extraire les mots-clés de la demande
# Identifier la catégorie principale
# Détecter les sous-catégories (ex: mcp + config)
```

**Heuristique de détection :**

1. **Mots-clés primaires** (poids 3.0) : déterminent la catégorie
2. **Mots-clés secondaires** (poids 1.5) : raffinent la sous-catégorie
3. **Contexte fichier** (poids 1.0) : fichiers dans le staging area
4. **Historique** (poids 0.5) : tâches similaires récentes

**Exemple :**

```
Demande: "Ajouter un outil MCP pour roo-state-manager"
→ mcp (3.0) + tool (1.5) + roo-state-manager (contexte)
→ Catégorie: mcp + consolidation
```

### Phase 2 : Lecture des MEMORY.md

**Sources de mémoire (par ordre de priorité) :**

1. **Mémoire Projet** : `.claude/memory/PROJECT_MEMORY.md`
2. **Mémoire Locale** : `~/.claude/projects/<hash>/memory/MEMORY.md`
3. **Règles Projet** : `.claude/rules/*.md` (auto-chargées)
4. **Config Globale** : `~/.claude/CLAUDE.md`

**Commande :**

```bash
# Lire MEMORY.md projet
Read(".claude/memory/PROJECT_MEMORY.md")

# Extraire les leçons pour la catégorie détectée
# Filtrer par pertinence (scoring > 0.5)
```

### Phase 3 : Filtrage par pertinence

**Scoring des leçons :**

| Facteur | Poids | Exemple |
|---------|-------|---------|
| **Correspondance catégorie** | 3.0 | Leçon MCP pour tâche MCP |
| **Récurrence** | 2.0 | Mentionnée 3+ fois = critique |
| **Impact** | 1.5 | "Critical", "IMPORTANT" |
| **Fraîcheur** | 1.0 | < 30 jours = plus pertinent |
| **Expérience utilisateur** | 0.5 | Patterns observés |

**Seuil d'injection :**
- Score ≥ 3.0 : **Toujours injecter** (critique)
- Score 2.0-2.9 : **Injecter si pertinent** (optionnel)
- Score < 2.0 : **Ne pas injecter** (bruit)

### Phase 4 : Injection dans le contexte

**Format d'injection :**

```markdown
## 🎓 Leçons pertinentes (auto-injectées depuis MEMORY.md)

### Catégorie: [NOM_CATEGORIE]

**[LECON_1]**
- Pourquoi: [Contexte erreur récurrente]
- Solution: [Action concrète]
- Impact: [Résultat mesurable]

**[LECON_2]**
...
```

**Position dans le contexte :**
- Après les règles auto-chargées (`.claude/rules/*.md`)
- Avant la demande utilisateur
- Maximum 5 leçons pour éviter la surcharge

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
- Solution: `roosync_mcp_management(subAction: "sync_always_allow")`
- Impact: Outils disponibles immédiatement

**Transport type matters**
- Pourquoi: Stdio vs SSE changes behaviour
- Solution: Vérifier `transportType: 'stdio'|'sse'` dans config
- Impact: Connexion MCP fonctionne
```

### Test

```markdown
**Jamais npm test (watch mode bloque)**
- Pourquoi: Watch mode attend input indéfiniment
- Solution: `npx vitest run` (CI) ou `npx vitest run --config vitest.config.ci.ts`
- Impact: Tests terminent, pas de blocage

**Tronquer output Vitest**
- Pourquoi: Output atteint ~600K chars
- Solution: `npx vitest run 2>&1 | Select-Object -Last 30`
- Impact: Contexte exploitable
```

### Git

```markdown
**Submodule workflow**
- Pourquoi: Commit parent sans commit submodule = pointer non mis à jour
- Solution: Commit inside first, push, puis `git add mcps/internal` dans parent
- Impact: Sous-module synchronisé

**Conventional commits**
- Pourquoi: Historique git illisible sans format standard
- Solution: `type(scope): description` + `Co-Authored-By: Claude Opus 4.6`
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

### Coordination

```markdown
**Dashboard = canal principal**
- Pourquoi: RooSync = inter-machine, INTERCOM = local
- Solution: `roosync_dashboard(type: "workspace")` pour coordination
- Impact: Communication visible par toutes machines

**Rapport [DONE] obligatoire**
- Pourquoi: Coordinateur ne peut pas commander sans visibilité
- Solution: Toujours poster `roosync_dashboard(tags: ["DONE"])` en fin de session
- Impact: Coordination fluide
```

---

## Protocole de Mise à Jour

### Après chaque tâche

**Si une leçon a évité une erreur :**
1. Incrémenter le compteur de récurrence
2. Mettre à jour l'impact mesuré
3. Marquer comme "validated"

**Si une leçon n'était pas pertinente :**
1. Décrémenter le score de pertinence
2. Ajouter un commentaire "not applicable: [raison]"
3. Considérer déplacement vers autre catégorie

**Si une nouvelle erreur récurrente est détectée :**
1. Créer une nouvelle leçon
2. Associer à la catégorie appropriée
3. Scorer initialement à 3.0 (critique par défaut)

### Maintenance mensuelle

**Nettoyer les leçons obsolètes :**
- Score < 1.0 depuis 3 mois → archiver
- Doublons détectés → fusionner
- Leçons jamais utilisées → déplacer vers "archive"

---

## Invocation

### Automatique (recommandé)

Le skill devrait être invoqué automatiquement au début de chaque tâche significative via un hook système:

```bash
# Dans .claude/settings.json ou hooks
{
  "hooks": {
    "before_task": "memory-inject"
  }
}
```

### Manuel

```bash
# Invocation directe
/memory-inject

# Invocation avec contexte spécifique
/memory-inject --category mcp
```

---

## Intégration avec le Système

### Avec SDDD

**Le skill memory-inject s'intègre dans le SDDD bookend :**

```
1. BOOKEND DEBUT: codebase_search (existant)
2. MEMORY-INJECT: Ce skill (nouveau)
3. CONVERSATIONNEL: conversation_browser (existant)
4. TECHNIQUE: Read/Grep code source (existant)
5. TRAVAIL: Implémenter/corriger/documenter
6. BOOKEND FIN: codebase_search validation (existant)
```

### Avec debrief

**Le skill debrief alimente memory-inject :**

```
debrief (fin de session)
  → Capture les leçons apprises
  → Met à jour MEMORY.md
  → Incrémente les compteurs de récurrence

memory-inject (début session suivante)
  → Lit MEMORY.md
  → Filtre par pertinence
  → Injecte les leçons validées
```

---

## Critères de Qualité

**Une bonne leçon auto-injectée doit être :**

- ✅ **Spécifique** : Action concrète, pas vague
- ✅ **Contextuelle** : Quand/où l'appliquer
- ✅ **Mesurable** : Impact quantifiable
- ✅ **Validée** : Testée dans des sessions réelles
- ✅ **Concise** : < 3 lignes pour éviter la surcharge

**Exemples :**

❌ **Mauvais** : "Vérifier les configs MCP"
✅ **Bon** : "Après modification MCP, TOUJOURS redémarrer VS Code (tools load at startup only)"

❌ **Mauvais** : "Attention aux tests"
✅ **Bon** : "JAMAIS `npm test` (watch mode bloque). Utiliser `npx vitest run`."

---

## Notes

- **Durée estimée** : < 1 seconde (lecture + filtrage)
- **Fréquence** : À chaque début de tâche significative
- **Coût maintenance** : Faible (mise à jour mensuelle)
- **Impact attendu** : -50% d'erreurs récurrentes (estimation Reddit)

---

**Dernière mise à jour :** 2026-04-13
**Issue associée :** #1377
