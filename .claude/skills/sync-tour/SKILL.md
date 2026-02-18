---
name: sync-tour
description: Tour de synchronisation complet multi-canal et multi-étapes. Utilise ce skill quand l'utilisateur demande un "tour de sync", veut "faire le point", ou demande l'état de la coordination. Exécute toutes les phases de synchronisation, validation, et planification.
---

# Tour de Synchronisation Complet

Ce skill orchestre un tour de synchronisation complet en **9 phases** (Phase 0 + 8 phases principales).

### Skills utilises

Ce skill s'appuie sur 3 skills reutilisables :
- **`git-sync`** (Phase 2) : Pull conservatif, submodules, resolution conflits
- **`validate`** (Phase 3) : Build TypeScript + tests unitaires
- **`github-status`** (Phase 4) : Etat Project #67 via `gh` CLI

Ces skills peuvent aussi etre invoques independamment en dehors du sync-tour.

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

**Agent :** `roosync-hub` (coordinateur) ou `roosync-reporter` (exécutants)

### Actions
1. Lire tous les messages non-lus avec `roosync_read` (mode: inbox) ou legacy `roosync_read_inbox`
2. Pour chaque message, récupérer les détails avec `roosync_read` (mode: message) ou legacy `roosync_get_message`
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

**Skill :** `git-sync` (voir `.claude/skills/git-sync/SKILL.md`)

### Actions
Suivre le workflow du skill `git-sync` :
1. Fetch et analyse des commits entrants
2. Pull conservatif (`--no-rebase`)
3. Resolution de conflits si necessaire
4. Submodule update
5. Verification finale

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

**Skill :** `validate` (voir `.claude/skills/validate/SKILL.md`)

### Actions
Suivre le workflow du skill `validate` :
1. Build TypeScript (check only)
2. Correction erreurs simples si necessaire
3. Tests unitaires (`npx vitest run`)
4. Rapport des resultats

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

**Skill :** `github-status` (voir `.claude/skills/github-status/SKILL.md`)

### Actions
Suivre le workflow du skill `github-status` :
1. Progression globale du Project #67 (via `gh` CLI)
2. Issues recentes ouvertes
3. Detection d'incoherences (Done annonce mais pas marque)

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

**Agent :** `roosync-hub` (coordinateur) ou `roosync-reporter` (exécutants) - ou gestion directe

### Actions

**1. Pour chaque machine ayant envoyé un message :**
   - Préparer une réponse personnalisée
   - Inclure :
     - ✅ Accusé réception : "Bien reçu ton rapport sur [sujet]"
     - 📋 Feedback : validation ou correction
     - 🎯 Prochaine tâche assignée (claire, avec GitHub #)
     - 🔗 Références : issues, commits, documentation
   - Priorité du message selon urgence
   - Envoyer avec `roosync_send` (action: reply) ou legacy `roosync_reply_message`

**2. Machines silencieuses (pas de message récent) :**
   - Si dernière activité > 48h : envoyer message priorité HIGH
   - Si dernière activité > 72h : envoyer message priorité URGENT
   - Si dernière activité > 96h : signaler à l'utilisateur + réassigner tâches critiques
   - Envoyer avec `roosync_send` (action: send) ou legacy `roosync_send_message`

**3. Machines actives sans nouvelle tâche :**
   - Envoyer mise à jour sur déploiement en cours
   - Demander rapport status local
   - Assigner tâches buffer si disponibles

**4. Gestion des messages :**
   - Marquer tous les messages traités comme lus via `roosync_manage` (action: mark_read) ou legacy `roosync_mark_message_read`
   - Archiver les messages > 7 jours si conversation terminée via `roosync_manage` (action: archive) ou legacy `roosync_archive_message`

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

## Phase 8 : Consolidation des Connaissances

**Objectif :** Preserver l'experience acquise pour que la prochaine session demarre avec le contexte a jour.

### Pourquoi cette phase est critique

Les sessions Claude Code ont un contexte limite. Sans consolidation, les apprentissages (patterns, bugs resolus, decisions) sont perdus au redemarrage. Cette phase assure la continuite entre sessions.

### Actions

**1. Mettre a jour MEMORY.md (prive, auto-charge)**

Fichier : `~/.claude/projects/d--roo-extensions/memory/MEMORY.md`

Mettre a jour les sections suivantes :
- **Current State** : git hash, tests, nombre d'outils, machines actives
- **Issue Tracker** : nouvelles issues, issues fermees, changements de statut
- **Lessons Learned** : ajouter tout nouveau pattern ou piege decouvert (1 ligne chacun)
- Supprimer les infos obsoletes (issues fermees, etats depasses)

**2. Mettre a jour PROJECT_MEMORY.md (partage via git)**

Fichier : `.claude/memory/PROJECT_MEMORY.md`

Ajouter uniquement les apprentissages **universels** (utiles a toutes les machines) :
- Nouvelles conventions, patterns, decisions architecturales
- Nouveaux MCPs integres, outils ajoutes
- Bugs importants resolus et comment
- Ne PAS ajouter d'etats ephemeres (hash git, nombre de tests)

**3. Mettre a jour ~/.claude/CLAUDE.md (global utilisateur)**

Fichier : `~/.claude/CLAUDE.md`

Ce fichier contient les preferences utilisateur **cross-projets** (s'applique a TOUS les workspaces).
Mettre a jour si une nouvelle preference ou convention a ete decouverte :
- Nouvelles definitions terminologiques (ex: "consolider" = analyze + merge + archive)
- Conventions de travail generales (ex: "ne jamais archiver sans verifier la couverture")
- Preferences de communication ou de style
- Ne PAS y mettre d'infos specifiques a un projet (ca va dans le CLAUDE.md du workspace)

**4. Evaluer les fichiers de regles (si drift detecte)**

Verifier si CLAUDE.md (workspace), `.roo/rules/`, `.claude/rules/` sont a jour :
- Nombre de machines correct ?
- Nouveaux outils documentes ?
- Regles obsoletes a retirer ?
- Nouvelles conventions a formaliser ?

Si oui, proposer les modifications (ne pas saturer, rester concis).

### Ce qu'il faut consolider (exemples)

| Type | Exemple | Ou |
|------|---------|-----|
| Bug resolu | "Case-sensitive machineId: toujours .toLowerCase()" | MEMORY.md Lessons |
| Nouveau pattern | "sk-agent = Python MCP via FastMCP + Semantic Kernel" | PROJECT_MEMORY.md |
| Decision | "RooSync = Claude only, INTERCOM = local" | Deja dans rules |
| Etat courant | "Git @ abc123, 3252 tests, 3/6 heartbeat" | MEMORY.md Current State |
| Convention | "git pull --no-rebase (jamais --rebase)" | PROJECT_MEMORY.md Decisions |
| Preference user | "consolider = analyser + merger + archiver" | ~/.claude/CLAUDE.md |

### Ce qu'il ne faut PAS consolider

- Details de session (messages RooSync traites, conflits git temporaires)
- Informations deja presentes dans les fichiers
- Speculations ou hypotheses non verifiees

### Output attendu

```
## Phase 8 : Consolidation

### MEMORY.md (prive)
- Current State : mis a jour (git hash, tests, issues)
- Lessons Learned : +X nouvelles entrees
- Infos obsoletes retirees : Y

### PROJECT_MEMORY.md (partage)
- Sections ajoutees : [liste si applicable]
- Pas de changement si rien de nouveau

### ~/.claude/CLAUDE.md (global utilisateur)
- Preferences ajoutees : [liste si applicable]
- Pas de changement si rien de nouveau

### Regles
- Mises a jour : [fichiers modifies si applicable]
- Pas de changement si a jour
```

### Outils de diagnostic (optionnels)

Les scripts suivants peuvent aider a **visualiser les differences** entre memoire privee et partagee, mais la decision de consolidation reste a l'agent :
```bash
# Voir ce qui pourrait etre partage (DryRun = lecture seule)
powershell scripts/memory/extract-shared-memory.ps1 -DryRun

# Voir ce qui pourrait etre importe (DryRun = lecture seule)
powershell scripts/memory/merge-memory.ps1 -DryRun
```

**Principe :** La consolidation demande du jugement. Ces scripts presentent l'information, l'agent decide quoi consolider et ou.

---

## Outils MCP Avances Disponibles

### Recherche semantique dans le code (`codebase_search`)

Recherche par **concept** dans le workspace indexe par Qdrant (pas par texte exact).

```
codebase_search(query: "rate limiting for embeddings", workspace: "d:\\roo-extensions")
```

**IMPORTANT :** Toujours passer le parametre `workspace` explicitement. L'auto-detection ne fonctionne pas correctement pour Claude Code (pointe vers le repertoire du serveur MCP).

**Prerequis :** Variables `.env` configurees :
```
EMBEDDING_MODEL=Alibaba-NLP/gte-Qwen2-1.5B-instruct
EMBEDDING_DIMENSIONS=2560
EMBEDDING_API_BASE_URL=http://embeddings.myia.io:11436/v1
EMBEDDING_API_KEY=vllm-placeholder-key-2024
```

### Recherche semantique dans les taches (`roosync_search`)

```
roosync_search(action: "semantic", search_query: "codebase search bug fix")
roosync_search(action: "text", search_query: "codebase_search")
```

La recherche semantique utilise Qdrant (index des conversations Roo). La recherche textuelle scanne le cache directement.

### Indexation des taches (`roosync_indexing`)

```
roosync_indexing(action: "diagnose")  # Etat de l'index Qdrant
roosync_indexing(action: "index", task_id: "...")  # Indexer une tache
roosync_indexing(action: "rebuild")  # Reconstruire l'index complet
```

### Comparaison de configuration (`roosync_compare_config`)

Compare les configurations MCP, modes Roo, et profils entre machines :

```
roosync_compare_config(granularity: "mcp")   # MCPs uniquement
roosync_compare_config(granularity: "mode")   # Modes Roo
roosync_compare_config(granularity: "full")   # Comparaison complete
roosync_compare_config(source: "myia-ai-01", target: "myia-po-2025", filter: "sk-agent")
```

---

## Rapport Final

A la fin du tour de sync, produire un **rapport consolide** :

```markdown
# Tour de Sync - [DATE HEURE]

## Resume Executif
- Messages traites : X
- Git : Synced @ [hash]
- Tests : Y/Z pass
- GitHub : A% Done
- Machines actives : B/6
- Connaissances consolidees : oui/non

## Actions effectuees
1. [liste des actions]

## Decisions prises
1. [ventilation des taches]

## Points d'attention
- [blocages, risques]

## Prochaines etapes
1. [pour chaque machine active]
```

---

## Notes d'utilisation

### Frequence
- **Debut de session** : Tour complet (toutes les phases)
- **Pendant le travail** : Phases specifiques a la demande
- **Fin de session** : Tour complet + Phase 8 obligatoire + commit des changements
- **Avant saturation contexte** : Phase 8 en priorite (sauvegarder l'experience)

### Permissions requises
Ce skill necessite de nombreuses permissions car il :
- Lit et ecrit des messages RooSync
- Fait des pull/merge Git
- Lance des builds et tests
- Modifie des fichiers (corrections)
- Met a jour GitHub Projects et Issues
- Met a jour les fichiers memoire (Phase 8)

### Duree estimee
Un tour complet prend generalement 5-10 minutes selon le volume de messages et l'etat des tests. La Phase 8 ajoute 2-3 minutes.
