---
name: sync-tour
description: Tour de synchronisation complet multi-canal et multi-étapes. Utilise ce skill quand l'utilisateur demande un "tour de sync", veut "faire le point", ou demande l'état de la coordination. Exécute toutes les phases de synchronisation, validation, et planification.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Edit
  - Write
  - mcp__roo-state-manager__roosync_read_inbox
  - mcp__roo-state-manager__roosync_get_message
  - mcp__roo-state-manager__roosync_send_message
  - mcp__roo-state-manager__roosync_reply_message
  - mcp__roo-state-manager__roosync_mark_message_read
  - mcp__roo-state-manager__roosync_archive_message
  - mcp__roo-state-manager__roosync_get_status
  - mcp__github-projects-mcp__get_project
  - mcp__github-projects-mcp__get_project_items
  - mcp__github-projects-mcp__update_project_item_field
  - mcp__github-projects-mcp__list_repository_issues
  - mcp__github-projects-mcp__get_repository_issue
  - mcp__github-projects-mcp__create_issue
---

# Tour de Synchronisation Complet

Ce skill orchestre un tour de synchronisation complet en **8 phases** (Phase 0 + 7 phases principales).

---

## Phase 0 : Lecture INTERCOM Local (CRITIQUE)

**⚠️ TOUJOURS commencer par cette phase avant tout le reste !**

### Actions
1. Lire `.claude/local/INTERCOM-myia-ai-01.md` (derniers messages)
2. Identifier les messages récents de Roo (< 24h)
3. Extraire :
   - Tâches en cours ou terminées par Roo
   - Demandes à Claude
   - Modifications locales (submodule, fichiers)
   - Questions ou blocages

### Output attendu
```
## Phase 0 : INTERCOM Local

### Messages de Roo récents : X
| Heure | Type | Contenu |
|...

### Points clés
- Tâche Roo : [en cours/terminée]
- Demandes à Claude : [liste]
- Modifications locales : [fichiers]
```

**Si Roo signale un merge en cours ou des modifications locales : gérer AVANT Phase 2 !**

---

## Phase 1 : Collecte des Messages RooSync

**Agent :** `roosync-coordinator`

### Actions
1. Lire tous les messages non-lus avec `roosync_read_inbox`
2. Pour chaque message, récupérer les détails avec `roosync_get_message`
3. Extraire :
   - Rapports d'avancement des agents
   - Demandes et questions
   - Problèmes et blocages signalés
   - Tâches complétées annoncées

### Output attendu
```
## Phase 1 : Messages RooSync

### Messages reçus : X
| De | Sujet | Priorité | Résumé |
|...

### Points clés extraits
- Accomplissements : [liste]
- Demandes : [liste]
- Blocages : [liste]
```

---

## Phase 2 : Synchronisation Git

**Agent :** `git-sync` (ou gestion directe si conflits)

### Actions
1. `git fetch origin` - récupérer les changements distants
2. Analyser les commits entrants (`git log HEAD..origin/main`)
3. `git pull --no-rebase origin main` - merge conservatif
4. **Si conflits détectés :**
   - Lister fichiers en conflit (`git status`)
   - Pour chaque fichier :
     - Lire avec marqueurs `<<<<<<<`, `=======`, `>>>>>>>`
     - Analyser les deux versions
     - Résoudre (garder version récente/complète ou combiner)
     - `Edit` pour supprimer marqueurs et sauvegarder
   - `git add` fichiers résolus
   - `git commit` (message merge)
5. `git submodule update --init --recursive`
6. **Si submodule en conflit ou divergent :**
   - Vérifier modifications locales (`cd mcps/internal && git status`)
   - Si modifs importantes : `git commit -m "wip"`
   - Sinon : `git checkout -- .` (abandon)
   - `git pull origin main`
   - Retour répertoire principal
7. Vérifier l'état final (`git status`, `git log -1`)

### Output attendu
```
## Phase 2 : Git Sync

### Remote
- Commits entrants : X
- Auteurs : [liste]

### Merge
- Status : ✅ Success | ⚠️ Conflits résolus | ❌ Conflits non résolus
- Fichiers modifiés : Y
- Conflits résolus : [liste si applicable]

### Submodule
- Status : ✅ Synced | ⚠️ Modifications locales
- État : mcps/internal @ [hash]

### État actuel
- Branch : main @ [hash]
- Prêt pour push : ✅ Oui | ❌ Non (raison)
```

**⚠️ IMPORTANT :** Toujours pusher après résolution conflits pour débloquer les autres machines.

---

## Phase 3 : Validation Tests & Build

**Agent :** `test-runner`

### Actions
1. Lancer le build TypeScript
2. Si erreurs de build :
   - Lister les erreurs
   - Corriger les erreurs simples (imports, typos)
   - Relancer le build
3. Lancer les tests unitaires
4. Reporter les résultats

### Output attendu
```
## Phase 3 : Tests & Build

### Build
- Status : ✅ SUCCESS | ❌ FAILED (X erreurs)

### Tests
- Total : X | Pass : Y | Skip : Z | Fail : W

### Corrections effectuées
- [liste si applicable]
```

---

## Phase 4 : État GitHub Project & Issues

**Agent :** `github-tracker`

### Actions
1. Récupérer les items du Project #67
2. Compter par statut (Todo, In Progress, Done)
3. Lister les issues récentes
4. Vérifier les commentaires des issues mentionnées dans les messages RooSync
5. Identifier les incohérences (tâche annoncée "Done" mais pas marquée dans GitHub)

### Output attendu
```
## Phase 4 : GitHub Status

### Project #67
- Total : X items
- Done : Y (Z%)
- In Progress : A
- Todo : B

### Issues récentes
| # | Titre | Status | Dernière activité |
|...

### Incohérences détectées
- [tâche X annoncée Done mais encore Todo dans GitHub]
```

---

## Phase 5 : Mise à Jour GitHub

**Actions directes (pas de subagent)**

### Actions

**1. Marquer tâches "Done"** (basé sur Phase 0 INTERCOM + Phase 1 RooSync)
   - Identifier tâches complétées annoncées par les agents
   - Vérifier cohérence avec git log (commits récents)
   - Mettre à jour statut dans Project #67
   - Ajouter commentaire "Complété par [machine/agent]"

**2. Mettre à jour statuts "In Progress"**
   - Si tâche annoncée démarrée → marquer In Progress
   - Ajouter commentaire d'assignation

**3. Ajouter commentaires aux issues existantes**
   - Feedback sur rapports machines
   - Liens vers commits pertinents
   - Updates sur avancement

**4. Créer nouvelles issues (⚠️ VALIDATION OBLIGATOIRE)**
   - **AVANT de créer :** Demander validation utilisateur explicite
   - Présenter : titre, description, raison, priorité
   - **ATTENDRE** confirmation
   - Seulement après : créer l'issue
   - **Exception :** Bugs critiques bloquants (mais informer immédiatement)

### Output attendu
```
## Phase 5 : Mises à jour GitHub

### Changements effectués
- Item [ID] : Todo → Done (raison + commit référence)
- Item [ID2] : Todo → In Progress (assigné à [machine])
- Issue #X : Commentaire ajouté (lien)

### Validation utilisateur en attente
- Nouvelle issue proposée : "[Titre]" - En attente confirmation
```

---

## Phase 6 : Planification & Ventilation

**Agent :** `task-planner`

### Actions
1. Analyser l'avancement global
2. Pour chaque machine (5 machines x 2 agents = 10 slots) :
   - Identifier le travail en cours
   - Proposer la prochaine tâche Roo (technique)
   - Proposer la prochaine tâche Claude (coordination)
3. Équilibrer la charge
4. Identifier les dépendances et blocages

### Output attendu
```
## Phase 6 : Planification

### Avancement global
- Progression : X% (Y/Z Done)
- Vélocité estimée : A tâches/jour

### Ventilation par machine

| Machine | Status | Tâche Roo | Tâche Claude |
|---------|--------|-----------|--------------|
| myia-ai-01 | ✅ | T2.8 (en cours) | Coordination |
| myia-po-2023 | ✅ | T3.1 (suggérée) | T3.2 (suggérée) |
| myia-po-2024 | ✅ | ... | ... |
| myia-po-2026 | 🔴 HS | - | - |
| myia-web1 | ✅ | ... | ... |

### Prochaines priorités
1. [tâche critique]
2. [tâche importante]
```

---

## Phase 7 : Réponses RooSync

**Agent :** `roosync-coordinator` (ou gestion directe)

### Actions

**1. Pour chaque machine ayant envoyé un message :**
   - Préparer une réponse personnalisée
   - Inclure :
     - ✅ Accusé réception : "Bien reçu ton rapport sur [sujet]"
     - 📋 Feedback : validation ou correction
     - 🎯 Prochaine tâche assignée (claire, avec GitHub #)
     - 🔗 Références : issues, commits, documentation
   - Priorité du message selon urgence
   - Envoyer avec `roosync_reply_message`

**2. Machines silencieuses (pas de message récent) :**
   - Si dernière activité > 48h : envoyer message priorité HIGH
   - Si dernière activité > 72h : envoyer message priorité URGENT
   - Si dernière activité > 96h : signaler à l'utilisateur + réassigner tâches critiques
   - Envoyer avec `roosync_send_message`

**3. Machines actives sans nouvelle tâche :**
   - Envoyer mise à jour sur déploiement en cours
   - Demander rapport status local
   - Assigner tâches buffer si disponibles

**4. Gestion des messages :**
   - Marquer tous les messages traités comme lus (`roosync_mark_message_read`)
   - Archiver les messages > 7 jours si conversation terminée (`roosync_archive_message`)

### Output attendu
```
## Phase 7 : Réponses envoyées

### Messages envoyés : X
| À | Sujet | Priorité | Type |
|---|-------|----------|------|
| myia-po-2023 | Prochaine tâche T1.10 | MEDIUM | Réponse |
| myia-web1 | URGENT - Statut requis | URGENT | Relance |
|...

### Gestion
- Messages marqués lus : Y
- Messages archivés : Z

### Machines silencieuses détectées
- myia-web1 : 72h+ (message URGENT #3 envoyé)
```

---

## Rapport Final

À la fin du tour de sync, produire un **rapport consolidé** :

```markdown
# Tour de Sync - [DATE HEURE]

## Résumé Exécutif
- Messages traités : X
- Git : ✅ Synced @ [hash]
- Tests : Y/Z pass
- GitHub : A% Done
- Machines actives : B/5

## Actions effectuées
1. [liste des actions]

## Décisions prises
1. [ventilation des tâches]

## Points d'attention
- [blocages, risques]

## Prochaines étapes
1. [pour chaque machine active]
```

---

## Notes d'utilisation

### Fréquence
- **Début de session** : Tour complet (toutes les phases)
- **Pendant le travail** : Phases spécifiques à la demande
- **Fin de session** : Tour complet + commit des changements

### Permissions requises
Ce skill nécessite de nombreuses permissions car il :
- Lit et écrit des messages RooSync
- Fait des pull/merge Git
- Lance des builds et tests
- Modifie des fichiers (corrections)
- Met à jour GitHub Projects et Issues

### Durée estimée
Un tour complet prend généralement 5-10 minutes selon le volume de messages et l'état des tests.
