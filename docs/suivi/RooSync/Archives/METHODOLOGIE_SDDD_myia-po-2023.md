# Méthodologie SDDD pour myia-po-2023

**Date:** 2026-01-04
**Auteur:** myia-po-2023
**Version:** 1.0
**Basé sur:** PROTOCOLE_SDDD v2.0.0

---

## Table des Matières

1. [Introduction](#1-introduction)
2. [Contexte et Rôle](#2-contexte-et-rôle)
3. [Principes Fondamentaux SDDD](#3-principes-fondamentaux-sddd)
4. [Workflow SDDD pour myia-po-2023](#4-workflow-sddd-pour-myia-po-2023)
5. [Grounding Sémantique](#5-grounding-sémantique)
6. [Journalisation dans les Issues GitHub](#6-journalisation-dans-les-issues-github)
7. [Mise à Jour de la Documentation](#7-mise-à-jour-de-la-documentation)
8. [Création d'Issues à partir des Drafts](#8-création-dissues-à-partir-des-drafts)
9. [Coordination avec les Autres Agents](#9-coordination-avec-les-autres-agents)
10. [Tâches Assignées à myia-po-2023](#10-tâches-assignées-à-myia-po-2023)
11. [Checklist de Validation](#11-checklist-de-validation)
12. [Annexes](#12-annexes)

---

## 1. Introduction

### 1.1 Objectif

Ce document définit la méthodologie spécifique pour l'agent **myia-po-2023** afin d'appliquer le protocole **SDDD (Semantic Documentation Driven Design) v2.0.0** dans le contexte du projet RooSync multi-agent.

### 1.2 Portée

Cette méthodologie s'applique à toutes les tâches assignées à myia-po-2023, y compris :
- Les 18 tâches du plan d'action multi-agent
- Les sous-tâches créées par décomposition
- Les tâches de coordination et communication inter-agents

### 1.3 Documents de Référence

| Document | Emplacement | Description |
|----------|--------------|-------------|
| PROTOCOLE_SDDD.md | docs/roosync/PROTOCOLE_SDDD.md | Protocole SDDD v2.0.0 |
| Message RooSync | msg-20260102T235504-htyuqq | Directive principale de myia-ai-01 |
| Répartition Tâches | docs/suivi/RooSync/REPARTITION_TACHES_MULTI_AGENT.md | 18 tâches assignées |
| Rapport Synthèse | docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md | État du système |
| Plan d'Action | docs/suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md | 4 phases, 58 tâches |

---

## 2. Contexte et Rôle

### 2.1 Rôle de myia-po-2023

**Rôle Principal:** Participation système

**Responsabilités:**
- Exécuter les tâches assignées dans le plan d'action multi-agent
- Participer à la coordination inter-agents via RooSync
- Maintenir la documentation à jour
- Journaliser toutes les opérations dans les issues GitHub

**Charge de Travail:**
- **Total:** 18 tâches actives (17.6%)
- **Phase 1:** 7 tâches (Actions immédiates)
- **Phase 2:** 7 tâches (Actions à court terme)
- **Phase 3:** 1 tâche (Actions à moyen terme)
- **Phase 4:** 3 tâches (Actions à long terme)

### 2.2 Architecture RooSync

```
myia-ai-01 (Baseline Master / Coordinateur Principal)
    ↓ Définit la baseline et valide
myia-po-2024 (Coordinateur Technique)
    ↓ Orchestre et coordonne
myia-po-2026, myia-po-2023, myia-web-01 (Agents)
    ↓ Exécutent et rapportent
```

### 2.3 État Actuel de myia-po-2023

| Aspect | État | Notes |
|--------|-------|-------|
| Git | À jour | Synchronisé avec origin/main |
| RooSync | 🟢 OK (3/3 online) | Opérationnel |
| MCP | ✅ Stable | 4 MCP désactivés, 0 mode personnalisé |
| Node.js | v25.2.1 | ✅ Mis à jour vers v24+ |
| Vulnérabilités npm | 5 détectées | 3 moderate, 2 high |
| Recompilation MCP | Non effectuée | Outils v2.3 non disponibles |

---

## 3. Principes Fondamentaux SDDD

### 3.1 Documentation First

**Principe:** La documentation est créée AVANT le code et guide l'implémentation.

**Application pour myia-po-2023:**
1. Toujours commencer par lire la documentation existante
2. Créer ou mettre à jour la documentation avant d'implémenter
3. Utiliser la documentation comme source de vérité

### 3.2 Semantic Search (Grounding)

**Principe:** Utiliser la recherche sémantique pour se grounder sur le contexte existant.

**Application pour myia-po-2023:**
1. Effectuer des recherches sémantiques en début de tâche
2. Effectuer des recherches sémantiques pendant la tâche si nécessaire
3. Effectuer des recherches sémantiques en fin de tâche pour vérifier la documentation

### 3.3 Traceability

**Principe:** Toute opération doit être traçable via les issues GitHub.

**Application pour myia-po-2023:**
1. Journaliser TOUTE opération dans l'issue GitHub correspondante
2. Utiliser des commentaires structurés pour faciliter la traçabilité
3. Référencer les documents et les décisions prises

### 3.4 Continuous Improvement

**Principe:** La documentation est un document vivant qui évolue avec le projet.

**Application pour myia-po-2023:**
1. Mettre à jour la documentation après chaque tâche
2. Documenter les leçons apprises
3. Proposer des améliorations au protocole SDDD

---

## 4. Workflow SDDD pour myia-po-2023

### 4.1 Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────┐
│ 1. RÉCEPTION DE LA TÂCHE                                │
│    - Lire le message RooSync                               │
│    - Identifier la tâche assignée                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. GROUNDING SÉMANTIQUE (DÉBUT)                         │
│    - Rechercher la documentation existante                 │
│    - Lire les documents de référence                        │
│    - Comprendre le contexte technique                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. CRÉATION DE L'ISSUE GITHUB                           │
│    - Convertir le draft en issue complète                  │
│    - Ajouter les labels et assignations                    │
│    - Créer la structure de commentaires                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. PLANIFICATION                                         │
│    - Décomposer la tâche en sous-tâches                  │
│    - Identifier les dépendances                            │
│    - Estimer l'effort                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. IMPLÉMENTATION                                        │
│    - Exécuter les sous-tâches séquentiellement           │
│    - Journaliser chaque opération                         │
│    - Effectuer des groundings réguliers                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. VALIDATION                                           │
│    - Tester les changements                               │
│    - Vérifier les critères de succès                     │
│    - Documenter les résultats                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. MISE À JOUR DE LA DOCUMENTATION                      │
│    - Mettre à jour les documents techniques               │
│    - Mettre à jour les guides opérationnels              │
│    - Créer ou mettre à jour les spécifications SDDD      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. GROUNDING SÉMANTIQUE (FIN)                          │
│    - Rechercher la documentation mise à jour               │
│    - Vérifier la cohérence                              │
│    - Identifier les améliorations possibles               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 9. CLÔTURE DE L'ISSUE                                   │
│    - Résumer les actions effectuées                        │
│    - Référencer les documents mis à jour                │
│    - Proposer les prochaines étapes                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 10. COORDINATION INTER-AGENTS                           │
│     - Envoyer un message RooSync aux autres agents       │
│     - Informer de la complétion de la tâche             │
│     - Coordonner les tâches dépendantes                  │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Étapes Détaillées

#### Étape 1: Réception de la Tâche

**Actions:**
1. Lire le message RooSync de myia-ai-01
2. Identifier la tâche assignée dans le plan d'action
3. Vérifier les dépendances avec les autres tâches
4. Confirmer l'acceptation de la tâche

**Outils:**
- `roosync_read_inbox` pour lire les messages
- `roosync_get_message` pour lire le contenu d'un message
- `roosync_mark_message_read` pour marquer comme lu

**Critère de Validation:**
- La tâche est clairement identifiée
- Les dépendances sont comprises
- L'acceptation est confirmée

#### Étape 2: Grounding Sémantique (Début)

**Actions:**
1. Effectuer une recherche sémantique sur la documentation existante
2. Lire les documents de référence pertinents
3. Comprendre le contexte technique et architectural
4. Identifier les documents à mettre à jour

**Outils:**
- `codebase_search` pour la recherche sémantique
- `read_file` pour lire les documents

**Requêtes Sémantiques Types:**
- "RooSync architecture baseline-driven workflow"
- "SDDD protocol grounding semantic search"
- "myia-po-2023 assigned tasks documentation"
- "RooSync v2.3 tools and services"

**Critère de Validation:**
- La documentation existante est comprise
- Le contexte technique est maîtrisé
- Les documents à mettre à jour sont identifiés

#### Étape 3: Création de l'Issue GitHub

**Actions:**
1. Identifier le draft correspondant dans le projet GitHub
2. Convertir le draft en issue complète
3. Ajouter les labels appropriés
4. S'assigner à l'issue
5. Créer la structure de commentaires

**Outils:**
- `mcp--github-projects-mcp--get_project_items` pour lister les drafts
- `mcp--github-projects-mcp--convert_draft_to_issue` pour convertir
- `mcp--github-projects-mcp--create_issue` pour créer une issue

**Structure de l'Issue:**

```markdown
## Tâche [Numéro]: [Titre]

### Description
[Description détaillée de la tâche]

### Contexte
- **Phase:** [Phase 1/2/3/4]
- **Priorité:** [CRITICAL/HIGH/MEDIUM/LOW]
- **Checkpoint:** [CPx.x]
- **Agents Responsables:** [Liste des agents]

### Critères de Succès
- [ ] Critère 1
- [ ] Critère 2
- [ ] Critère 3

### Dépendances
- Tâche [Numéro]: [Description]

### Documentation de Référence
- [Document 1](lien)
- [Document 2](lien)

---

## Journal d'Exécution

### 📋 Planification
[Commentaire de planification]

### 🔍 Grounding Initial
[Commentaire de grounding initial]

### ⚙️ Exécution
[Commentaires d'exécution]

### ✅ Validation
[Commentaire de validation]

### 📚 Documentation Mise à Jour
[Commentaire de documentation]

### 🏁 Clôture
[Commentaire de clôture]
```

**Critère de Validation:**
- L'issue est créée avec tous les champs requis
- Les labels sont corrects
- La structure de commentaires est en place

#### Étape 4: Planification

**Actions:**
1. Décomposer la tâche en sous-tâches
2. Identifier les dépendances entre sous-tâches
3. Estimer l'effort pour chaque sous-tâche
4. Créer un plan d'exécution

**Outils:**
- Commentaires dans l'issue GitHub

**Format de Planification:**

```markdown
### 📋 Planification

**Sous-tâches:**
1. [ ] Sous-tâche 1 (estimation: X min)
2. [ ] Sous-tâche 2 (estimation: Y min)
3. [ ] Sous-tâche 3 (estimation: Z min)

**Dépendances:**
- Sous-tâche 2 dépend de Sous-tâche 1
- Sous-tâche 3 dépend de Sous-tâche 2

**Risques:**
- Risque 1: Description
- Risque 2: Description

**Mitigation:**
- Mitigation 1: Description
- Mitigation 2: Description
```

**Critère de Validation:**
- Les sous-tâches sont clairement définies
- Les dépendances sont identifiées
- L'effort est estimé de manière réaliste

#### Étape 5: Implémentation

**Actions:**
1. Exécuter les sous-tâches séquentiellement
2. Journaliser chaque opération dans l'issue
3. Effectuer des groundings réguliers
4. Gérer les imprévus

**Outils:**
- Commentaires dans l'issue GitHub
- `codebase_search` pour les groundings réguliers
- Outils MCP appropriés pour l'exécution

**Format de Journalisation:**

```markdown
### ⚙️ Exécution

**[Date/Heure] - Sous-tâche 1**
- Action: Description de l'action
- Commande: `commande exécutée`
- Résultat: Succès/Échec
- Détails: [Détails supplémentaires]

**[Date/Heure] - Grounding**
- Requête: "requête sémantique"
- Résultats: [Résumé des résultats]
- Décision: [Décision prise]

**[Date/Heure] - Sous-tâche 2**
- Action: Description de l'action
- Commande: `commande exécutée`
- Résultat: Succès/Échec
- Détails: [Détails supplémentaires]
```

**Critère de Validation:**
- Toutes les sous-tâches sont exécutées
- Toutes les opérations sont journalisées
- Les groundings sont effectués régulièrement

#### Étape 6: Validation

**Actions:**
1. Tester les changements effectués
2. Vérifier les critères de succès
3. Documenter les résultats
4. Identifier les problèmes résiduels

**Outils:**
- Tests appropriés (unitaires, intégration, E2E)
- Commentaires dans l'issue GitHub

**Format de Validation:**

```markdown
### ✅ Validation

**Tests Exécutés:**
- Test 1: ✅/❌ [Description]
- Test 2: ✅/❌ [Description]
- Test 3: ✅/❌ [Description]

**Critères de Succès:**
- [x] Critère 1: [Validation]
- [x] Critère 2: [Validation]
- [x] Critère 3: [Validation]

**Problèmes Résiduels:**
- Problème 1: Description
- Problème 2: Description

**Recommandations:**
- Recommandation 1: Description
- Recommandation 2: Description
```

**Critère de Validation:**
- Tous les tests passent
- Tous les critères de succès sont validés
- Les problèmes résiduels sont documentés

#### Étape 7: Mise à Jour de la Documentation

**Actions:**
1. Mettre à jour les documents techniques
2. Mettre à jour les guides opérationnels
3. Créer ou mettre à jour les spécifications SDDD
4. Mettre à jour l'index de documentation

**Outils:**
- `write_to_file` pour créer/mettre à jour les documents
- `apply_diff` pour les modifications ciblées

**Documents à Mettre à Jour:**
- `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`
- `docs/roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`
- `docs/roosync/PROTOCOLE_SDDD.md`
- `docs/INDEX.md` (index principal)

**Format de Documentation:**

```markdown
### 📚 Documentation Mise à Jour

**Documents Modifiés:**
- [Document 1](lien): Description des modifications
- [Document 2](lien): Description des modifications

**Nouveaux Documents:**
- [Document 3](lien): Description du nouveau document

**Index Mis à Jour:**
- [docs/INDEX.md](lien): Ajout des références aux nouveaux documents
```

**Critère de Validation:**
- Tous les documents pertinents sont mis à jour
- Les modifications sont cohérentes
- L'index est à jour

#### Étape 8: Grounding Sémantique (Fin)

**Actions:**
1. Effectuer une recherche sémantique sur la documentation mise à jour
2. Vérifier la cohérence de la documentation
3. Identifier les améliorations possibles
4. Proposer des améliorations au protocole SDDD

**Outils:**
- `codebase_search` pour la recherche sémantique

**Requêtes Sémantiques Types:**
- "Documentation mise à jour [sujet de la tâche]"
- "SDDD protocol improvements [sujet de la tâche]"
- "RooSync [composant modifié] documentation"

**Format de Grounding Final:**

```markdown
### 🔍 Grounding Final

**Requêtes Sémantiques:**
- Requête 1: "requête sémantique"
  - Résultats: [Résumé]
  - Cohérence: ✅/❌
- Requête 2: "requête sémantique"
  - Résultats: [Résumé]
  - Cohérence: ✅/❌

**Améliorations Identifiées:**
- Amélioration 1: Description
- Amélioration 2: Description

**Propositions SDDD:**
- Proposition 1: Description
- Proposition 2: Description
```

**Critère de Validation:**
- La documentation mise à jour est cohérente
- Les améliorations sont identifiées
- Les propositions SDDD sont documentées

#### Étape 9: Clôture de l'Issue

**Actions:**
1. Résumer les actions effectuées
2. Référencer les documents mis à jour
3. Proposer les prochaines étapes
4. Fermer l'issue

**Outils:**
- Commentaires dans l'issue GitHub
- `mcp--github-projects-mcp--update_issue_state` pour fermer l'issue

**Format de Clôture:**

```markdown
### 🏁 Clôture

**Résumé des Actions:**
- Action 1: Description
- Action 2: Description
- Action 3: Description

**Documents Mis à Jour:**
- [Document 1](lien)
- [Document 2](lien)

**Prochaines Étapes:**
- Étape 1: Description
- Étape 2: Description

**Statut:** ✅ Complété
```

**Critère de Validation:**
- Le résumé est complet
- Les documents sont référencés
- Les prochaines étapes sont claires
- L'issue est fermée

#### Étape 10: Coordination Inter-Agents

**Actions:**
1. Envoyer un message RooSync aux autres agents
2. Informer de la complétion de la tâche
3. Coordonner les tâches dépendantes
4. Demander validation si nécessaire

**Outils:**
- `roosync_send_message` pour envoyer un message
- `roosync_read_inbox` pour lire les réponses

**Format de Message RooSync:**

```markdown
**Sujet:** ✅ Tâche [Numéro] Complétée - [Titre]

**De:** myia-po-2023
**À:** [Liste des agents concernés]
**Priorité:** MEDIUM

**Résumé:**
La tâche [Numéro] a été complétée avec succès.

**Actions Effectuées:**
- Action 1: Description
- Action 2: Description
- Action 3: Description

**Documents Mis à Jour:**
- [Document 1](lien)
- [Document 2](lien)

**Prochaines Étapes:**
- Étape 1: Description
- Étape 2: Description

**Validation Requise:**
- [ ] Validation par [Agent]
- [ ] Validation par [Agent]

**Issue GitHub:** [Lien vers l'issue]
```

**Critère de Validation:**
- Le message est envoyé aux agents concernés
- Le résumé est complet
- Les prochaines étapes sont claires
- La validation est demandée si nécessaire

---

## 5. Grounding Sémantique

### 5.1 Principes du Grounding

**Définition:** Le grounding est le processus par lequel un agent se familiarise avec le contexte existant en utilisant la recherche sémantique.

**Objectifs:**
- Comprendre la documentation existante
- Identifier les documents pertinents
- Éviter les duplications
- Maintenir la cohérence

### 5.2 Quand Effectuer du Grounding

**Moments Obligatoires:**
1. **En début de tâche:** Pour comprendre le contexte initial
2. **Pendant la tâche:** Si un changement de direction est nécessaire
3. **En fin de tâche:** Pour vérifier la cohérence de la documentation mise à jour

**Moments Recommandés:**
1. **Avant une décision importante:** Pour s'assurer de la cohérence
2. **Après un problème:** Pour identifier les solutions existantes
3. **Avant de créer un nouveau document:** Pour éviter les duplications

### 5.3 Comment Effectuer du Grounding

**Étapes:**

1. **Formuler une requête sémantique**
   - Utiliser des mots-clés pertinents
   - Inclure le contexte technique
   - Être spécifique mais flexible

2. **Exécuter la recherche sémantique**
   - Utiliser l'outil `codebase_search`
   - Spécifier le chemin si nécessaire
   - Analyser les résultats

3. **Lire les documents pertinents**
   - Lire les documents identifiés
   - Prendre des notes sur les points clés
   - Identifier les sections pertinentes

4. **Synthétiser les informations**
   - Combiner les informations de plusieurs documents
   - Identifier les contradictions ou incohérences
   - Formuler une compréhension globale

5. **Documenter le grounding**
   - Documenter les requêtes effectuées
   - Documenter les résultats trouvés
   - Documenter les décisions prises

### 5.4 Exemples de Requêtes Sémantiques

**Pour le Contexte RooSync:**
- "RooSync architecture baseline-driven workflow"
- "RooSync v2.3 tools and services"
- "RooSync baseline management"
- "RooSync decision validation process"

**Pour le Protocole SDDD:**
- "SDDD protocol grounding semantic search"
- "SDDD documentation first principle"
- "SDDD traceability requirements"
- "SDDD continuous improvement"

**Pour les Tâches Assignées:**
- "myia-po-2023 assigned tasks documentation"
- "Tâche [Numéro] [Titre] documentation"
- "Checkpoint [CPx.x] validation criteria"
- "Phase [1/2/3/4] tasks documentation"

**Pour les Composants Techniques:**
- "BaselineService implementation"
- "NonNominativeBaselineService implementation"
- "ConfigSharingService implementation"
- "IdentityManager implementation"

### 5.5 Format de Documentation du Grounding

```markdown
### 🔍 Grounding

**Requête Sémantique:**
```
[Requête sémantique]
```

**Résultats:**
- [Document 1](lien): Description pertinente
- [Document 2](lien): Description pertinente
- [Document 3](lien): Description pertinente

**Synthèse:**
[Synthèse des informations trouvées]

**Décisions Prises:**
- Décision 1: Description
- Décision 2: Description

**Documents à Consulter:**
- [Document 1](lien)
- [Document 2](lien)
```

---

## 6. Journalisation dans les Issues GitHub

### 6.1 Principes de la Journalisation

**Définition:** La journalisation est le processus d'enregistrement de toutes les opérations effectuées lors de l'exécution d'une tâche.

**Objectifs:**
- Maintenir la traçabilité
- Faciliter le debugging
- Documenter les décisions
- Permettre la révision

### 6.2 Quoi Journaliser

**Opérations à Journaliser:**
1. **Commandes exécutées:** Toutes les commandes CLI
2. **Outils MCP utilisés:** Tous les appels aux outils MCP
3. **Fichiers modifiés:** Tous les fichiers créés/modifiés/supprimés
4. **Décisions prises:** Toutes les décisions importantes
5. **Problèmes rencontrés:** Tous les problèmes et leurs solutions
6. **Tests exécutés:** Tous les tests et leurs résultats
7. **Groundings effectués:** Toutes les recherches sémantiques

### 6.3 Comment Journaliser

**Format Structuré:**

```markdown
**[Date/Heure] - [Catégorie]**

**Action:** [Description de l'action]

**Commande:**
```bash
[Commande exécutée]
```

**Outil MCP:**
```json
{
  "tool": "[nom de l'outil]",
  "parameters": {
    "param1": "valeur1",
    "param2": "valeur2"
  },
  "result": "[succès/échec]"
}
```

**Résultat:** [Succès/Échec]

**Détails:**
- Détail 1: Description
- Détail 2: Description

**Décision:** [Décision prise si applicable]
```

### 6.4 Exemples de Journalisation

**Exemple 1: Exécution d'une commande CLI**

```markdown
**2026-01-04T10:30:00Z - Commande CLI**

**Action:** Mettre à jour Node.js vers v24+

**Commande:**
```bash
pwsh -c "node --version"
```

**Résultat:** Succès

**Détails:**
- Version actuelle: v23.11.0
- Version cible: v24.0.0
- Action requise: Télécharger et installer Node.js v24+

**Décision:** Procéder à l'installation de Node.js v24+
```

**Exemple 2: Utilisation d'un outil MCP**

```markdown
**2026-01-04T10:35:00Z - Outil MCP**

**Action:** Collecter l'inventaire de configuration

**Outil MCP:**
```json
{
  "tool": "roosync_get_machine_inventory",
  "parameters": {
    "machineId": "myia-po-2023"
  },
  "result": "succès"
}
```

**Résultat:** Succès

**Détails:**
- Inventaire collecté avec succès
- Fichier créé: RooSync/shared/myia-po-2023/inventory.json
- Taille: 15.2 KB

**Décision:** Inventaire valide, procéder à la comparaison
```

**Exemple 3: Modification d'un fichier**

```markdown
**2026-01-04T10:40:00Z - Modification de Fichier**

**Action:** Corriger les incohérences ConfigSharingService.ts

**Fichier:** mcps/internal/servers/roo-state-manager/src/services/ConfigSharingService.ts

**Modifications:**
- Ligne 49: Remplacer `process.env.COMPUTERNAME` par `process.env.ROOSYNC_MACHINE_ID || process.env.COMPUTERNAME || 'unknown'`
- Ligne 220: Remplacer `process.env.COMPUTERNAME` par `machineId`

**Résultat:** Succès

**Détails:**
- 2 lignes modifiées
- Compilation TypeScript réussie
- Tests unitaires passés

**Décision:** Modifications validées, procéder au commit
```

### 6.5 Fréquence de la Journalisation

**Règle Générale:** Journaliser après chaque opération significative.

**Opérations Significatives:**
- Exécution d'une commande CLI
- Appel à un outil MCP
- Création/modification/suppression d'un fichier
- Prise d'une décision importante
- Rencontre d'un problème
- Exécution d'un test
- Grounding sémantique

**Fréquence Recommandée:**
- Au minimum: Une fois par sous-tâche
- Idéalement: Après chaque opération significative
- Maximum: Une fois par minute (pour éviter le spam)

---

## 7. Mise à Jour de la Documentation

### 7.1 Principes de la Mise à Jour

**Définition:** La mise à jour de la documentation est le processus de modification des documents existants pour refléter les changements effectués.

**Objectifs:**
- Maintenir la documentation à jour
- Assurer la cohérence
- Faciliter la maintenance
- Permettre la révision

### 7.2 Quoi Mettre à Jour

**Documents à Mettre à Jour:**

1. **Documentation Technique:**
   - `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`
   - `docs/roosync/GUIDE-DEVELOPPEUR-v2.1.md`
   - Spécifications techniques des composants modifiés

2. **Documentation Opérationnelle:**
   - `docs/roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md`
   - Guides d'utilisation des outils modifiés
   - Procédures opérationnelles mises à jour

3. **Documentation SDDD:**
   - `docs/roosync/PROTOCOLE_SDDD.md`
   - Spécifications SDDD des composants modifiés
   - Méthodologies mises à jour

4. **Index de Documentation:**
   - `docs/INDEX.md`
   - Index des sections modifiées
   - Références aux nouveaux documents

### 7.3 Comment Mettre à Jour

**Étapes:**

1. **Identifier les documents à mettre à jour**
   - Lister tous les documents pertinents
   - Prioriser les documents critiques
   - Identifier les sections à modifier

2. **Lire les documents existants**
   - Comprendre la structure actuelle
   - Identifier les sections à modifier
   - Prendre des notes sur les changements

3. **Appliquer les modifications**
   - Utiliser `apply_diff` pour les modifications ciblées
   - Utiliser `write_to_file` pour les modifications importantes
   - Maintenir la cohérence du style

4. **Vérifier les modifications**
   - Relire les documents modifiés
   - Vérifier la cohérence
   - Valider les liens et références

5. **Mettre à jour l'index**
   - Ajouter les références aux nouveaux documents
   - Mettre à jour les sections modifiées
   - Valider les liens

### 7.4 Format de Mise à Jour

**Pour les Modifications Ciblées:**

```markdown
### 📚 Documentation Mise à Jour

**Document:** [Nom du document](lien)

**Section:** [Nom de la section]

**Modifications:**
- Modification 1: Description
- Modification 2: Description

**Justification:** [Justification des modifications]
```

**Pour les Nouveaux Documents:**

```markdown
### 📚 Nouveau Document

**Document:** [Nom du document](lien)

**Description:** [Description du nouveau document]

**Contenu:**
- Section 1: Description
- Section 2: Description

**Justification:** [Justification de la création]
```

**Pour l'Index:**

```markdown
### 📚 Index Mis à Jour

**Document:** docs/INDEX.md

**Modifications:**
- Ajout de la référence à [Document 1](lien)
- Mise à jour de la section [Section 1]
- Ajout de la sous-section [Sous-section 1]

**Justification:** [Justification des modifications]
```

### 7.5 Exemples de Mise à Jour

**Exemple 1: Modification d'une Section**

```markdown
### 📚 Documentation Mise à Jour

**Document:** docs/roosync/GUIDE-TECHNIQUE-v2.3.md

**Section:** 2.3 Services Baseline

**Modifications:**
- Ajout de la description du NonNominativeBaselineService
- Mise à jour de la section sur la gestion des baselines non-nominatives
- Ajout d'exemples d'utilisation

**Justification:** La tâche 2.7 a simplifié l'architecture des baselines non-nominatives, la documentation doit refléter ces changements.
```

**Exemple 2: Création d'un Nouveau Document**

```markdown
### 📚 Nouveau Document

**Document:** docs/roosync/GUIDE-MIGRATION-v2.1-v2.3.md

**Description:** Guide de migration de RooSync v2.1 vers v2.3

**Contenu:**
- Introduction: Contexte de la migration
- Prérequis: Conditions requises pour la migration
- Étapes de migration: Procédure détaillée
- Validation: Critères de succès
- Dépannage: Problèmes courants et solutions

**Justification:** La tâche 2.17 requiert la création d'un guide de migration pour aider les agents à compléter la transition v2.1→v2.3.
```

**Exemple 3: Mise à Jour de l'Index**

```markdown
### 📚 Index Mis à Jour

**Document:** docs/INDEX.md

**Modifications:**
- Ajout de la référence au GUIDE-MIGRATION-v2.1-v2.3.md dans la section "Guides"
- Mise à jour de la section "Documentation RooSync" pour inclure le nouveau guide
- Ajout de la sous-section "Migration" dans la section "Guides"

**Justification:** Le nouveau guide de migration doit être référencé dans l'index principal pour faciliter son accès.
```

---

## 8. Création d'Issues à partir des Drafts

### 8.1 Principes de la Création d'Issues

**Définition:** La création d'issues à partir des drafts est le processus de conversion des drafts du projet GitHub en issues complètes.

**Objectifs:**
- Formaliser les tâches
- Faciliter le suivi
- Permettre la collaboration
- Maintenir la traçabilité

### 8.2 Quand Créer des Issues

**Moments Obligatoires:**
1. **Avant de commencer une tâche:** Toujours créer l'issue correspondante
2. **Après réception d'une tâche:** Créer l'issue dès que possible
3. **Avant de décomposer une tâche:** Créer l'issue parente d'abord

**Moments Recommandés:**
1. **Après le grounding initial:** Créer l'issue avec le contexte complet
2. **Avant la planification:** Créer l'issue pour faciliter la planification
3. **Après validation des dépendances:** Créer l'issue avec les dépendances confirmées

### 8.3 Comment Créer des Issues

**Étapes:**

1. **Identifier le draft correspondant**
   - Lister les drafts du projet GitHub
   - Identifier le draft correspondant à la tâche
   - Vérifier le contenu du draft

2. **Convertir le draft en issue**
   - Utiliser l'outil `convert_draft_to_issue`
   - Spécifier le dépôt cible
   - Valider la conversion

3. **Compléter l'issue**
   - Ajouter les labels appropriés
   - S'assigner à l'issue
   - Ajouter les assignations supplémentaires si nécessaire
   - Créer la structure de commentaires

4. **Valider l'issue**
   - Vérifier que tous les champs sont remplis
   - Vérifier que les labels sont corrects
   - Vérifier que la structure de commentaires est en place

### 8.4 Structure d'une Issue

```markdown
## Tâche [Numéro]: [Titre]

### Description
[Description détaillée de la tâche]

### Contexte
- **Phase:** [Phase 1/2/3/4]
- **Priorité:** [CRITICAL/HIGH/MEDIUM/LOW]
- **Checkpoint:** [CPx.x]
- **Agents Responsables:** [Liste des agents]

### Critères de Succès
- [ ] Critère 1
- [ ] Critère 2
- [ ] Critère 3

### Dépendances
- Tâche [Numéro]: [Description]

### Documentation de Référence
- [Document 1](lien)
- [Document 2](lien)

---

## Journal d'Exécution

### 📋 Planification
[Commentaire de planification]

### 🔍 Grounding Initial
[Commentaire de grounding initial]

### ⚙️ Exécution
[Commentaires d'exécution]

### ✅ Validation
[Commentaire de validation]

### 📚 Documentation Mise à Jour
[Commentaire de documentation]

### 🏁 Clôture
[Commentaire de clôture]
```

### 8.5 Labels Recommandés

**Labels de Priorité:**
- `priority:critical`
- `priority:high`
- `priority:medium`
- `priority:low`

**Labels de Phase:**
- `phase:1`
- `phase:2`
- `phase:3`
- `phase:4`

**Labels de Statut:**
- `status:todo`
- `status:in-progress`
- `status:review`
- `status:done`

**Labels de Type:**
- `type:bug`
- `type:feature`
- `type:improvement`
- `type:documentation`

**Labels d'Agent:**
- `agent:myia-ai-01`
- `agent:myia-po-2023`
- `agent:myia-po-2024`
- `agent:myia-po-2026`
- `agent:myia-web-01`

### 8.6 Exemple de Création d'Issue

**Draft Original:**

```markdown
## Tâche 1.1: Corriger Get-MachineInventory.ps1

**Priorité:** CRITICAL
**Agents:** myia-po-2026, myia-po-2023
**Checkpoint:** CP1.1

Identifier la cause des freezes d'environnement et corriger le script Get-MachineInventory.ps1.
```

**Issue Convertie:**

```markdown
## Tâche 1.1: Corriger Get-MachineInventory.ps1

### Description
Identifier la cause des freezes d'environnement et corriger le script Get-MachineInventory.ps1. Le script échoue lors de son exécution et cause des gels d'environnement sur myia-po-2026.

### Contexte
- **Phase:** Phase 1: Actions Immédiates
- **Priorité:** CRITICAL
- **Checkpoint:** CP1.1
- **Agents Responsables:** myia-po-2026, myia-po-2023

### Critères de Succès
- [ ] Le script s'exécute sans freeze
- [ ] L'inventaire est correctement collecté
- [ ] Le fichier inventory.json est créé et contient les informations attendues

### Dépendances
- Aucune

### Documentation de Référence
- [RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md](docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)
- [PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md](docs/suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)

---

## Journal d'Exécution

### 📋 Planification
[À compléter]

### 🔍 Grounding Initial
[À compléter]

### ⚙️ Exécution
[À compléter]

### ✅ Validation
[À compléter]

### 📚 Documentation Mise à Jour
[À compléter]

### 🏁 Clôture
[À compléter]
```

**Labels Ajoutés:**
- `priority:critical`
- `phase:1`
- `status:todo`
- `type:bug`
- `agent:myia-po-2026`
- `agent:myia-po-2023`

---

## 9. Coordination avec les Autres Agents

### 9.1 Principes de la Coordination

**Définition:** La coordination inter-agents est le processus de communication et de collaboration entre les agents du cluster RooSync.

**Objectifs:**
- Faciliter la collaboration
- Coordonner les tâches dépendantes
- Partager les informations
- Résoudre les conflits

### 9.2 Quand Coordonner

**Moments Obligatoires:**
1. **Avant de commencer une tâche:** Informer les autres agents concernés
2. **Après complétion d'une tâche:** Informer les autres agents du résultat
3. **En cas de problème:** Demander de l'aide aux autres agents
4. **Avant de prendre une décision importante:** Consulter les autres agents

**Moments Recommandés:**
1. **Pendant l'exécution d'une tâche:** Partager les progrès réguliers
2. **Après un grounding important:** Partager les découvertes
3. **Avant de mettre à jour la documentation:** Demander une revue

### 9.3 Comment Coordonner

**Outils:**
- `roosync_send_message` pour envoyer des messages
- `roosync_read_inbox` pour lire les messages
- `roosync_get_message` pour lire un message spécifique
- `roosync_reply_message` pour répondre à un message
- `roosync_mark_message_read` pour marquer un message comme lu

**Types de Messages:**

1. **Notification de Début:**
   - Informer qu'une tâche commence
   - Partager le plan d'exécution
   - Demander des validations si nécessaire

2. **Progrès Régulier:**
   - Partager les progrès
   - Informer des problèmes rencontrés
   - Demander de l'aide si nécessaire

3. **Notification de Complétion:**
   - Informer qu'une tâche est complétée
   - Partager les résultats
   - Coordonner les tâches dépendantes

4. **Demande d'Aide:**
   - Demander de l'aide pour un problème
   - Partager le contexte
   - Proposer des solutions

5. **Consultation:**
   - Demander l'avis des autres agents
   - Partager une proposition
   - Demander une validation

### 9.4 Format des Messages RooSync

**Notification de Début:**

```markdown
**Sujet:** 🚀 Tâche [Numéro] Démarrée - [Titre]

**De:** myia-po-2023
**À:** [Liste des agents concernés]
**Priorité:** MEDIUM

**Résumé:**
La tâche [Numéro] a été démarrée.

**Plan d'Exécution:**
1. Sous-tâche 1: Description
2. Sous-tâche 2: Description
3. Sous-tâche 3: Description

**Estimation:** [Durée estimée]

**Issue GitHub:** [Lien vers l'issue]

**Validation Requise:**
- [ ] Validation par [Agent]
- [ ] Validation par [Agent]
```

**Progrès Régulier:**

```markdown
**Sujet:** 📊 Progrès Tâche [Numéro] - [Titre]

**De:** myia-po-2023
**À:** [Liste des agents concernés]
**Priorité:** LOW

**Résumé:**
Progrès de la tâche [Numéro].

**Sous-tâches Complétées:**
- [x] Sous-tâche 1: Description
- [x] Sous-tâche 2: Description

**Sous-tâches en Cours:**
- [ ] Sous-tâche 3: Description (en cours)

**Problèmes Rencontrés:**
- Problème 1: Description
- Problème 2: Description

**Prochaines Étapes:**
- Étape 1: Description
- Étape 2: Description

**Issue GitHub:** [Lien vers l'issue]
```

**Notification de Complétion:**

```markdown
**Sujet:** ✅ Tâche [Numéro] Complétée - [Titre]

**De:** myia-po-2023
**À:** [Liste des agents concernés]
**Priorité:** MEDIUM

**Résumé:**
La tâche [Numéro] a été complétée avec succès.

**Actions Effectuées:**
- Action 1: Description
- Action 2: Description
- Action 3: Description

**Documents Mis à Jour:**
- [Document 1](lien)
- [Document 2](lien)

**Prochaines Étapes:**
- Étape 1: Description
- Étape 2: Description

**Validation Requise:**
- [ ] Validation par [Agent]
- [ ] Validation par [Agent]

**Issue GitHub:** [Lien vers l'issue]
```

**Demande d'Aide:**

```markdown
**Sujet:** ❓ Demande d'Aide - Tâche [Numéro]

**De:** myia-po-2023
**À:** [Liste des agents concernés]
**Priorité:** HIGH

**Résumé:**
Besoin d'aide pour la tâche [Numéro].

**Problème:**
[Description du problème]

**Contexte:**
- Tâche: [Numéro] - [Titre]
- Sous-tâche en cours: [Description]
- Actions effectuées: [Description]

**Tentatives de Résolution:**
- Tentative 1: Description
- Tentative 2: Description

**Demande:**
[Description de la demande d'aide]

**Issue GitHub:** [Lien vers l'issue]
```

**Consultation:**

```markdown
**Sujet:** 💬 Consultation - [Sujet]

**De:** myia-po-2023
**À:** [Liste des agents concernés]
**Priorité:** MEDIUM

**Résumé:**
Consultation sur [sujet].

**Contexte:**
- Tâche: [Numéro] - [Titre]
- Sous-tâche en cours: [Description]

**Proposition:**
[Description de la proposition]

**Questions:**
1. Question 1?
2. Question 2?
3. Question 3?

**Validation Requise:**
- [ ] Validation par [Agent]
- [ ] Validation par [Agent]

**Issue GitHub:** [Lien vers l'issue]
```

### 9.5 Fréquence de la Coordination

**Règle Générale:** Coordonner régulièrement pour maintenir la transparence.

**Fréquence Recommandée:**
- **Notification de début:** Une fois au début de la tâche
- **Progrès régulier:** Une fois par jour ou après chaque sous-tâche importante
- **Notification de complétion:** Une fois à la fin de la tâche
- **Demande d'aide:** Dès qu'un problème est rencontré
- **Consultation:** Avant de prendre une décision importante

---

## 10. Tâches Assignées à myia-po-2023

### 10.1 Vue d'Ensemble

**Total:** 18 tâches actives (17.6%)

| Phase | Nombre de Tâches | Tâches |
|-------|-------------------|---------|
| Phase 1 | 7 | 1.1, 1.3, 1.7, 1.8, 1.9, 1.10, 1.11 |
| Phase 2 | 7 | 2.1, 2.2, 2.6, 2.16, 2.17, 2.18, 2.19, 2.24, 2.25 |
| Phase 3 | 1 | 3.2, 3.4, 3.7 |
| Phase 4 | 3 | 4.10, 4.11, 4.12 |

### 10.2 Phase 1: Actions Immédiates

| # | Tâche | Priorité | Agents Responsables | Checkpoint | Statut |
|---|---------|-----------|-------------------|-------------|---------|
| 1.1 | Corriger Get-MachineInventory.ps1 | CRITICAL | myia-po-2026, myia-po-2023 | CP1.1 | ✅ Créé |
| 1.3 | Lire et répondre aux messages non-lus | HIGH | myia-ai-01, myia-po-2023, myia-web-01 | CP1.3 | ✅ Créé |
| 1.7 | Corriger les vulnérabilités npm | HIGH | myia-po-2023, myia-po-2024 | CP1.7 | ✅ Créé |
| 1.8 | Créer le répertoire RooSync/shared/myia-po-2026 | MEDIUM | myia-po-2026, myia-po-2023 | CP1.8 | ✅ Créé |
| 1.9 | Recompiler le MCP sur toutes les machines | MEDIUM | Toutes les machines | CP1.9 | ✅ Créé |
| 1.10 | Valider les outils RooSync sur chaque machine | MEDIUM | Toutes les machines | CP1.10 | ✅ Créé |
| 1.11 | Collecter les inventaires de configuration | HIGH | Toutes les machines | CP1.11 | ✅ Créé |

### 10.3 Phase 2: Actions à Court Terme

| # | Tâche | Priorité | Agents Responsables | Checkpoint | Statut |
|---|---------|-----------|-------------------|-------------|---------|
| 2.1 | Compléter la transition v2.1→v2.3 | HIGH | myia-po-2024, myia-po-2023 | CP2.1 | ✅ Créé |
| 2.2 | Mettre à jour Node.js vers v24+ sur myia-po-2023 | MEDIUM | myia-po-2023, myia-po-2026 | CP2.2 | ✅ Créé |
| 2.6 | Améliorer la gestion du cache | MEDIUM | myia-ai-01, myia-po-2023 | CP2.6 | ✅ Créé |
| 2.16 | Corriger l'incohérence InventoryCollector | MEDIUM | myia-ai-01, myia-po-2023 | CP2.16 | ✅ Créé |
| 2.17 | Créer le guide de migration v2.1 → v2.3 | MEDIUM | myia-ai-01, myia-po-2023 | CP2.14 | ✅ Créé |
| 2.18 | Clarifier les transitions de version (v2.1, v2.2, v2.3) | MEDIUM | myia-po-2023, myia-po-2024 | CP2.14 | ✅ Créé |
| 2.19 | Créer un index principal docs/INDEX.md | MEDIUM | myia-po-2023, myia-po-2024 | CP2.14 | ✅ Créé |
| 2.24 | Investiguer les causes des commits de correction fréquents | MEDIUM | myia-po-2024, myia-po-2023 | CP2.16 | ✅ Créé |
| 2.25 | Standardiser la nomenclature sur myia-web-01 | MEDIUM | myia-web-01, myia-po-2023 | CP2.17 | ✅ Créé |

### 10.4 Phase 3: Actions à Moyen Terme

| # | Tâche | Priorité | Agents Responsables | Checkpoint | Statut |
|---|---------|-----------|-------------------|-------------|---------|
| 3.2 | Améliorer la documentation | MEDIUM | myia-po-2024, myia-po-2023 | CP3.2 | ✅ Créé |
| 3.4 | Créer tests E2E complets | MEDIUM | myia-web-01, myia-po-2023 | CP3.4 | ✅ Créé |
| 3.7 | Différencier erreurs script vs système | MEDIUM | myia-ai-01, myia-po-2023 | CP3.7 | ✅ Créé |

### 10.5 Phase 4: Actions à Long Terme

| # | Tâche | Priorité | Agents Responsables | Checkpoint | Statut |
|---|---------|-----------|-------------------|-------------|---------|
| 4.10 | Analyser les besoins de documentation multi-agent | MEDIUM | myia-ai-01, myia-po-2024 | CP4.4 | ✅ Créé |
| 4.11 | Implémenter la documentation multi-agent | MEDIUM | myia-ai-01, myia-po-2024 | CP4.4 | ✅ Créé |
| 4.12 | Créer le rapport de validation CP4.4 | MEDIUM | myia-ai-01, myia-po-2024 | CP4.4 | ✅ Créé |

### 10.6 Méthodologie par Tâche

Pour chaque tâche, suivre la méthodologie SDDD décrite dans la section 4.

**Points Clés:**
1. **Grounding Initial:** Rechercher la documentation existante sur le sujet de la tâche
2. **Création d'Issue:** Convertir le draft en issue complète avec la structure de commentaires
3. **Planification:** Décomposer la tâche en sous-tâches et estimer l'effort
4. **Exécution:** Exécuter les sous-tâches séquentiellement en journalisant chaque opération
5. **Validation:** Tester les changements et vérifier les critères de succès
6. **Documentation:** Mettre à jour les documents pertinents
7. **Grounding Final:** Vérifier la cohérence de la documentation mise à jour
8. **Clôture:** Résumer les actions et fermer l'issue
9. **Coordination:** Informer les autres agents de la complétion

---

## 11. Checklist de Validation

### 11.1 Checklist de Début de Tâche

- [ ] Lire le message RooSync de myia-ai-01
- [ ] Identifier la tâche assignée
- [ ] Vérifier les dépendances
- [ ] Confirmer l'acceptation de la tâche
- [ ] Effectuer le grounding initial
- [ ] Créer l'issue GitHub
- [ ] Planifier les sous-tâches
- [ ] Estimer l'effort

### 11.2 Checklist d'Exécution

- [ ] Exécuter les sous-tâches séquentiellement
- [ ] Journaliser chaque opération
- [ ] Effectuer des groundings réguliers
- [ ] Gérer les imprévus
- [ ] Tester les changements
- [ ] Vérifier les critères de succès

### 11.3 Checklist de Fin de Tâche

- [ ] Mettre à jour la documentation
- [ ] Effectuer le grounding final
- [ ] Résumer les actions
- [ ] Référencer les documents
- [ ] Proposer les prochaines étapes
- [ ] Fermer l'issue
- [ ] Envoyer un message RooSync
- [ ] Coordonner les tâches dépendantes

### 11.4 Checklist de Documentation

- [ ] Mettre à jour les documents techniques
- [ ] Mettre à jour les guides opérationnels
- [ ] Mettre à jour les spécifications SDDD
- [ ] Mettre à jour l'index de documentation
- [ ] Vérifier la cohérence
- [ ] Valider les liens et références

### 11.5 Checklist de Coordination

- [ ] Informer les autres agents du début de la tâche
- [ ] Partager les progrès réguliers
- [ ] Demander de l'aide si nécessaire
- [ ] Consulter les autres agents avant les décisions importantes
- [ ] Informer les autres agents de la complétion
- [ ] Coordonner les tâches dépendantes

---

## 12. Annexes

### 12.1 Glossaire

| Terme | Définition |
|--------|------------|
| **Baseline** | Configuration de référence pour une machine |
| **Baseline Master** | Machine responsable de gérer la baseline nominative |
| **Baseline Non-Nominative** | Baseline partagée entre plusieurs machines sans attribution nominative |
| **Checkpoint** | Point de validation pour confirmer qu'une tâche est complétée |
| **Draft** | Ébauche de tâche dans le projet GitHub |
| **Grounding** | Processus de familiarisation avec le contexte existant |
| **Issue** | Tâche formelle dans le dépôt GitHub |
| **MCP** | Model Context Protocol - Protocole de communication entre le système et les agents |
| **RooSync** | Système de synchronisation multi-machines |
| **SDDD** | Semantic Documentation Driven Design - Méthodologie de développement |
| **Semantic Search** | Recherche basée sur le sens plutôt que sur les mots-clés exacts |

### 12.2 Références

**Documents SDDD:**
- [PROTOCOLE_SDDD.md](docs/roosync/PROTOCOLE_SDDD.md)
- [METHODOLOGIE_SDDD_myia-po-2023.md](docs/roosync/METHODOLOGIE_SDDD_myia-po-2023.md)

**Documents RooSync:**
- [GUIDE-TECHNIQUE-v2.3.md](docs/roosync/GUIDE-TECHNIQUE-v2.3.md)
- [GUIDE-OPERATIONNEL-UNIFIE-v2.1.md](docs/roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md)
- [GUIDE-DEVELOPPEUR-v2.1.md](docs/roosync/GUIDE-DEVELOPPEUR-v2.1.md)

**Documents de Suivi:**
- [REPARTITION_TACHES_MULTI_AGENT.md](docs/suivi/RooSync/REPARTITION_TACHES_MULTI_AGENT.md)
- [RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md](docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)
- [PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md](docs/suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)

### 12.3 Outils MCP

**Outils RooSync:**
- `roosync_init`: Initialisation du système RooSync
- `roosync_get_status`: Récupération du statut de synchronisation
- `roosync_compare_config`: Comparaison des configurations
- `roosync_list_diffs`: Liste des différences détectées
- `roosync_update_baseline`: Mise à jour du fichier baseline
- `roosync_collect_config`: Collecte de la configuration locale
- `roosync_publish_config`: Publication de la configuration vers le partage
- `roosync_apply_config`: Application d'une configuration
- `roosync_get_machine_inventory`: Collecte de l'inventaire système
- `roosync_send_message`: Envoi d'un message à une autre machine
- `roosync_read_inbox`: Lecture de la boîte de réception
- `roosync_get_message`: Récupération d'un message spécifique
- `roosync_mark_message_read`: Marquage d'un message comme lu
- `roosync_reply_message`: Réponse à un message existant

**Outils GitHub:**
- `list_projects`: Lister les projets GitHub
- `get_project`: Récupérer les détails d'un projet
- `get_project_items`: Récupérer les éléments d'un projet
- `add_item_to_project`: Ajouter un élément à un projet
- `create_issue`: Créer une issue dans un dépôt
- `update_issue_state`: Modifier l'état d'une issue

**Outils de Fichiers:**
- `read_file`: Lire un fichier
- `write_to_file`: Écrire un fichier
- `apply_diff`: Appliquer des modifications ciblées
- `list_files`: Lister les fichiers d'un répertoire

**Outils de Recherche:**
- `codebase_search`: Recherche sémantique dans le codebase

### 12.4 Modèles de Messages

**Modèle de Message de Début:**
```markdown
**Sujet:** 🚀 Tâche [Numéro] Démarrée - [Titre]

**De:** myia-po-2023
**À:** [Liste des agents concernés]
**Priorité:** MEDIUM

**Résumé:**
La tâche [Numéro] a été démarrée.

**Plan d'Exécution:**
1. Sous-tâche 1: Description
2. Sous-tâche 2: Description
3. Sous-tâche 3: Description

**Estimation:** [Durée estimée]

**Issue GitHub:** [Lien vers l'issue]

**Validation Requise:**
- [ ] Validation par [Agent]
- [ ] Validation par [Agent]
```

**Modèle de Message de Complétion:**
```markdown
**Sujet:** ✅ Tâche [Numéro] Complétée - [Titre]

**De:** myia-po-2023
**À:** [Liste des agents concernés]
**Priorité:** MEDIUM

**Résumé:**
La tâche [Numéro] a été complétée avec succès.

**Actions Effectuées:**
- Action 1: Description
- Action 2: Description
- Action 3: Description

**Documents Mis à Jour:**
- [Document 1](lien)
- [Document 2](lien)

**Prochaines Étapes:**
- Étape 1: Description
- Étape 2: Description

**Validation Requise:**
- [ ] Validation par [Agent]
- [ ] Validation par [Agent]

**Issue GitHub:** [Lien vers l'issue]
```

### 12.5 Bonnes Pratiques

**Grounding:**
- Toujours effectuer un grounding en début de tâche
- Utiliser des requêtes sémantiques spécifiques
- Documenter les résultats du grounding
- Effectuer des groundings réguliers pendant la tâche

**Journalisation:**
- Journaliser TOUTE opération significative
- Utiliser un format structuré
- Inclure les commandes exécutées
- Inclure les résultats obtenus
- Documenter les décisions prises

**Documentation:**
- Mettre à jour la documentation après chaque tâche
- Maintenir la cohérence du style
- Valider les liens et références
- Mettre à jour l'index

**Coordination:**
- Informer les autres agents régulièrement
- Partager les progrès
- Demander de l'aide si nécessaire
- Consulter avant les décisions importantes

**Issues GitHub:**
- Toujours créer une issue avant de commencer une tâche
- Utiliser les labels appropriés
- Créer la structure de commentaires
- Fermer l'issue après complétion

---

**Document généré par:** myia-po-2023
**Date de génération:** 2026-01-04T00:20:00Z
**Version:** 1.0
**Basé sur:** PROTOCOLE_SDDD v2.0.0
