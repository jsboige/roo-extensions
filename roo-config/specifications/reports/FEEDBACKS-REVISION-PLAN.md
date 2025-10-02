# 📋 Plan de Révision - Feedbacks Utilisateur

**Date :** 30 Septembre 2025  
**Version Initiale :** 1.0.0  
**Statut :** Analyse feedbacks en cours

---

## 🎯 Vue d'Ensemble

Suite à la revue utilisateur des spécifications v1.0.0, **8 points majeurs** nécessitent révision pour garantir cohérence et applicabilité pratique.

### Priorités Identifiées

| Priorité | Points | Impact | Complexité |
|----------|--------|--------|------------|
| 🔴 P0 CRITIQUE | 3 points | Architecturale | Élevée |
| 🟡 P1 MAJEURE | 3 points | Opérationnelle | Moyenne |
| 🟢 P2 MINEURE | 2 points | Documentation | Faible |

---

## 📊 Synthèse des Feedbacks

### 🔴 PRIORITÉ 0 - ARCHITECTURALE CRITIQUE

#### FB-01 : Redéfinition Concept Escalade
**Source :** README.md L94-108  
**Fichiers impactés :** [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md)

**Problème actuel :**
- Confusion entre "escalade" (phénomène précis) et "changement de mode" (multiples raisons)
- 5 mécaniques mélangent escalade, désescalade, et sous-tâches
- Terminologie imprécise crée ambiguïté

**Clarification demandée :**
> "Le terme d'escalade devrait désigner un phénomène précis: le fait qu'un mode simple en fasse appel à un mode complexe."

**3 Formes d'Escalade identifiées :**
1. **Escalade Interne** : Mode simple switch dans même tâche → mode complex
2. **Escalade Externe Compétente** : Mode simple a les infos mais pas la compétence → crée sous-tâche avec toutes infos
3. **Escalade Externe Contextuelle** : Mode simple n'a pas contexte frais → termine en échec, orchestrateur réinstruira mode complex

**Distinction Escalade vs Sous-tâches :**
- **Escalade** = Toujours simple → complex (montée en compétence)
- **Sous-tâches** = Peut être pour multiples raisons (décomposition, économie, délégation)

**Révision nécessaire :**
- ✅ Conserver : Escalade Externe (simple → complex)
- ❌ Supprimer : "Désescalade" comme escalade inverse
- ❌ Supprimer : "Escalade par Approfondissement" (= sous-tâches normales)
- ❌ Supprimer : "Désescalade Économique" (= délégation sous-tâches)
- ⚠️ Revoir : Escalade Interne (éviter switch mode, préférer sous-tâches)

**Actions :**
1. Réécrire section 1 "Escalade Externe" : 3 variantes (interne, externe-compétente, externe-contextuelle)
2. Supprimer sections 2, 4, 5 : Renommer en "Mécaniques Sous-tâches" (nouveau document)
3. Clarifier terminologie partout dans spécifications

---

#### FB-02 : Orchestrateur Anti-Symétrique
**Source :** README.md L32  
**Fichiers impactés :** [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)

**Problème actuel :**
- Protocole SDDD demande `codebase_search` à TOUS les modes
- Orchestrateur n'a AUCUN outil → impossible

**Clarification demandée :**
> "L'orchestrateur n'a aucun outil, il doit se baser sur ses modes de sous-tâches pour se grounder. Aussi son instruction est anti-symmétrique de celle des autres modes sur ce point là."

**Révision nécessaire :**
1. Ajouter section "Exception Orchestrateurs" dans SDDD
2. Grounding indirect via sous-tâches :
   - Sous-tâche grounding : Mode simple fait `codebase_search` + synthèse
   - Orchestrateur reçoit synthèse dans rapport terminaison
3. Même principe pour tous documents suivis (reports, checkpoints)

**Actions :**
1. Modifier [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) : Ajouter section "Grounding Orchestrateurs"
2. Créer template sous-tâche grounding pour orchestrateurs
3. Documenter pattern "grounding par délégation"

---

#### FB-03 : Universalisation new_task()
**Source :** README.md L139  
**Fichiers impactés :** [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md)

**Problème actuel :**
- Doc indique : "❌ Pas dans code/debug/ask simples (pas d'orchestration)"
- Restriction arbitraire empêche décomposition et escalade

**Clarification demandée :**
> "Tous les modes doivent pouvoir créer des sous-tâches que ce soit pour décomposer des tâches atomisables, ou bien pour escalader en confiant des actions complexes à un mode dédié."

**Raisons création sous-tâches :**
1. **Décomposition atomique** : Tâche trop large → sous-tâches
2. **Escalade externe-compétente** : Compétence insuffisante → sous-tâche mode approprié
3. **Économie contexte** : Saturation tokens → délégation actions lourdes
4. **Parallélisation** : Tâches indépendantes → sous-tâches parallèles

**Révision nécessaire :**
- Supprimer restriction modes simples
- Ajouter guidelines décomposition pour TOUS modes
- Clarifier : Orchestrateurs = décomposition systématique, Autres = décomposition opportuniste

**Actions :**
1. Modifier [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md) : Section "Applicable à TOUS modes"
2. Ajouter critères quand sous-tâche appropriée vs action directe
3. Documenter patterns décomposition par type de mode

---

### 🟡 PRIORITÉ 1 - OPÉRATIONNELLE MAJEURE

#### FB-04 : Économie Contexte - Angles Morts Lectures Ciblées
**Source :** README.md L278-281  
**Fichiers impactés :** [`context-economy-patterns.md`](context-economy-patterns.md)

**Problème actuel :**
- Pattern 5 "Lecture Ciblée Progressive" présenté comme économie
- Risque angles morts et multiplication aller-retours

**Clarification demandée :**
> "Attention à l'économie de contexte qui peut induire des angles morts. Typiquement les lectures ciblées sont des risques et multiplient les aller-retours ce qui est souvent contre productif."

**Principes révisés :**
1. **Première lecture INTÉGRALE** au moins une fois
2. **Regrounding régulier** : Remettre fichier complet en mémoire périodiquement
3. **Vraie économie** : Délégation sous-tâches atomiques (patterns search, etc.)
4. **Progression conversation** : Plus on avance → plus on délègue → orchestrateur ne fait plus d'actions

**Révision nécessaire :**
- ⚠️ Revoir Pattern 5 : Avertir des risques, recommander lecture intégrale d'abord
- ✅ Renforcer Pattern 1 : Délégation systématique = vraie économie
- Ajouter section "Anti-Pattern Lecture Fragmentée"

**Actions :**
1. Modifier [`context-economy-patterns.md`](context-economy-patterns.md) Pattern 5
2. Ajouter section "Principes Grounding vs Économie"
3. Documenter pattern "Évolution Mode Complex → Orchestrateur"

---

#### FB-05 : Grounding Conversationnel 50k Tokens
**Source :** README.md L47  
**Fichiers impactés :** [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md), [`context-economy-patterns.md`](context-economy-patterns.md)

**Problème actuel :**
- Checkpoint "tous les 50k tokens" flou
- Pas clair que c'est grounding via `roo-state-manager`

**Clarification demandée :**
> "Tous les 50k tokens: faire le grounding conversationnel"

**Révision nécessaire :**
1. Préciser : Checkpoint 50k = Grounding conversationnel obligatoire
2. Outil : `roo-state-manager view_conversation_tree` ou `search_tasks_semantic`
3. Objectif : Vérifier on n'a pas dévié, recontextualiser décisions passées

**Actions :**
1. Modifier [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md) Phase 2
2. Ajouter template checkpoint 50k avec grounding conversationnel
3. Lier avec [`context-economy-patterns.md`](context-economy-patterns.md) Pattern 4

---

#### FB-06 : MCPs git/win-cli vs Terminal Natif
**Source :** README.md L191  
**Fichiers impactés :** [`mcp-integrations-priority.md`](mcp-integrations-priority.md)

**Problème actuel :**
- MCPs git et win-cli mentionnés mais pas dans doc
- win-cli devait remplacer terminal pour code/debug
- Besoin clarification stratégie

**Clarification demandée :**
> "Il faut qu'on détermine exactement ce qu'on fait des MCPs git et surtout win-cli. Ce dernier était sensé remplacer le terminal natif pour les modes code et debug, mais il faut pour cela le débrider quant aux workspaces acceptés. Sinon réautoriser le terminal pour tous les modes non orchestrateur."

**Investigation nécessaire :**
1. État actuel win-cli MCP
2. Restrictions workspace actuelles
3. Bénéfices vs terminal natif
4. Décision : Débrider win-cli OU Réautoriser terminal

**Actions :**
1. Créer sous-tâche investigation : État win-cli + git MCPs
2. Document décision après investigation
3. Mettre à jour [`mcp-integrations-priority.md`](mcp-integrations-priority.md) selon décision

---

### 🟢 PRIORITÉ 2 - DOCUMENTATION MINEURE

#### FB-07 : Format Numérotation Hiérarchie
**Source :** README.md L131  
**Fichiers impactés :** [`hierarchie-numerotee-subtasks.md`](hierarchie-numerotee-subtasks.md)

**Problème actuel :**
- Format `1.0` pour tâche principale
- Suggestion : Simplifier en `1`

**Clarification demandée :**
> "pourquoi 1.0, je dirais 1"

**Révision nécessaire :**
- Débat format : `1` vs `1.0`
- Argument `1.0` : Cohérence niveaux (1.0 → 1.1 → 1.1.1)
- Argument `1` : Plus simple, évident que c'est racine

**Actions :**
1. Décision utilisateur : Garder `1.0` ou simplifier `1` ?
2. Appliquer partout si changement
3. Mettre à jour exemples et templates

---

#### FB-08 : Factorisation Champs Config Roo
**Source :** README.md L237  
**Fichiers impactés :** [`factorisation-commons.md`](factorisation-commons.md)

**Problème actuel :**
- Système factorisation proposé
- Pas clair où insérer dans config Roo existante

**Clarification demandée :**
> "Ok pour le principe d'une factorisation, il faudra regarder dans quels champs de config roo on insère tout cela (il y a déjà une partie commune à tous les modes, mais ça n'est peut-être pas ce qu'on souhaite utiliser, à vérifier)"

**Investigation nécessaire :**
1. Examiner structure `custom_modes.json` actuelle
2. Identifier champs `globalInstructions` vs `customInstructions`
3. Stratégie assemblage : Références markdown vs Injection dynamique

**Actions :**
1. Créer sous-tâche investigation : Structure custom_modes.json
2. Proposer stratégie intégration
3. Mettre à jour [`factorisation-commons.md`](factorisation-commons.md) avec détails implémentation

---

## 🗺️ Plan d'Action Incrémental

### Phase 1 : Investigations (P1-P2)

**2.3.2.A Investigation win-cli/git MCPs**
- Examiner état actuel MCPs
- Recommandation terminal natif vs win-cli
- Documenter décision

**2.3.2.B Investigation custom_modes.json**
- Analyser structure config existante
- Identifier champs factorisation
- Proposer stratégie assemblage

### Phase 2 : Révisions Critiques (P0)

**2.3.3 Révision Escalade** (FB-01)
- Réécrire [`escalade-mechanisms-revised.md`](escalade-mechanisms-revised.md)
- 3 formes escalade : Interne, Externe-Compétente, Externe-Contextuelle
- Créer document séparé "Mécaniques Sous-tâches"

**2.3.4 Révision Orchestrateur** (FB-02)
- Ajouter section "Exception Orchestrateurs" dans [`sddd-protocol-4-niveaux.md`](sddd-protocol-4-niveaux.md)
- Documenter grounding par délégation
- Créer templates sous-tâches grounding

**2.3.5 Révision Hiérarchie** (FB-03)
- Universaliser `new_task()` pour TOUS modes
- Documenter critères décomposition opportuniste
- Patterns par type de mode

### Phase 3 : Révisions Majeures (P1)

**2.3.6 Révision Économie Contexte** (FB-04)
- Revoir Pattern 5 "Lecture Ciblée" avec avertissements
- Renforcer délégation systématique
- Documenter évolution Complex → Orchestrateur

**2.3.7 Révision Grounding 50k** (FB-05)
- Préciser checkpoint 50k = grounding conversationnel
- Template checkpoint avec `roo-state-manager`
- Lier avec patterns économie

**2.3.8 Révision MCPs** (FB-06)
- Appliquer décision investigation 2.3.2.A
- Mettre à jour [`mcp-integrations-priority.md`](mcp-integrations-priority.md)
- Documenter win-cli vs terminal

### Phase 4 : Révisions Mineures (P2)

**2.3.9.A Révision Format Numérotation** (FB-07)
- Décision utilisateur : `1` vs `1.0`
- Appliquer changement si nécessaire

**2.3.9.B Révision Factorisation** (FB-08)
- Appliquer décision investigation 2.3.2.B
- Détailler implémentation assemblage

**2.3.10 Révision Protocole SDDD** (Anti-angles-morts)
- Ajouter section "Patterns Anti-Angles-Morts"
- Documenter lecture intégrale obligatoire
- Warnings sur fragmentations

### Phase 5 : Validation Finale

**2.4 Validation Cohérence**
- Vérifier cohérence inter-documents
- Tester templates sur cas réels
- Rapport validation final

---

## 📋 Décisions Utilisateur Requises

### D1 : Format Numérotation (FB-07)
**Question :** Garder `1.0` pour tâche principale ou simplifier en `1` ?
- **Option A** : `1.0` → Cohérence avec sous-niveaux
- **Option B** : `1` → Simplicité, évident que racine

**Impact :** Cosmétique, tous exemples et templates

### D2 : Escalade Interne (FB-01)
**Question :** Autoriser switch_mode au sein d'une tâche (simple → complex) ou toujours sous-tâche ?
- **Option A** : Autoriser switch_mode interne (contexte préservé)
- **Option B** : Toujours sous-tâche (évite incompatibilités contexte)

**Impact :** Mécanique fondamentale, templates escalade

### D3 : win-cli vs Terminal (FB-06)
**Question :** Stratégie terminaux pour modes non-orchestrateur ?
- **Option A** : Débrider win-cli MCP (configuration workspace)
- **Option B** : Réautoriser terminal natif (execute_command)

**Impact :** Architecture MCP, capacités modes code/debug

---

## 📊 Estimation Effort

| Phase | Tâches | Complexité | Durée Estimée |
|-------|--------|------------|---------------|
| Phase 1 | 2 investigations | Moyenne | 2-3h |
| Phase 2 | 3 révisions P0 | Élevée | 4-5h |
| Phase 3 | 3 révisions P1 | Moyenne | 3-4h |
| Phase 4 | 3 révisions P2 | Faible | 1-2h |
| Phase 5 | 1 validation | Moyenne | 2h |
| **TOTAL** | **12 tâches** | **Variable** | **12-16h** |

---

## 🎯 Prochaines Actions Immédiates

1. **Validation Plan** : Utilisateur approuve plan d'action
2. **Décisions D1-D3** : Utilisateur tranche options
3. **Phase 1 Investigations** : Lancer sous-tâches investigation
4. **Phase 2 P0** : Révisions critiques architecture

---

**Note :** Ce plan est incrémental et adaptable. Chaque phase produit des livrables validables avant passage à la suivante.