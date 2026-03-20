---
name: sync-tour
description: Tour de synchronisation complet multi-canal et multi-étapes. Utilise ce skill quand l'utilisateur demande un "tour de sync", veut "faire le point", ou demande l'état de la coordination. Exécute toutes les phases de synchronisation, validation, et planification.
metadata:
  author: "Roo Extensions Team"
  version: "2.1.0"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
    restrictions: "Requiert accès RooSync + GitHub CLI + Git"
---

# Tour de Synchronisation Complet

Ce skill orchestre un tour de synchronisation complet en **9 phases** (Phase 0 + 8 phases principales).

### Skills utilises

Ce skill s'appuie sur 3 skills reutilisables :
- **`git-sync`** (Phase 2) : Pull conservatif, submodules, resolution conflits
- **`validate`** (Phase 3) : Build TypeScript + tests unitaires
- **`github-status`** (Phase 4) : Etat Project #67 via `gh` CLI

Ces skills peuvent aussi etre invoques independamment en dehors du sync-tour.

### Agents utilises

Ce skill fait appel a des agents specialises :
- **`config-auditor`** (Phase 1.5) : Audit configuration MCP/modes pour prevenir les incidents (#614)
- **`task-planner`** (Phase 6) : Analyse avancement et ventilation des taches

---

## Phase 0 : Contexte Local + Grounding SDDD (CRITIQUE)

**⚠️ TOUJOURS commencer par cette phase avant tout le reste !**

**Methodologie :** Triple grounding SDDD. Voir `.claude/rules/sddd-conversational-grounding.md`.

### Actions

**0a. Bookend SDDD (debut de tache) :**
```
codebase_search(query: "etat courant synchronisation coordination", workspace: "d:\\roo-extensions")
conversation_browser(action: "current", workspace: "d:\\roo-extensions")
```
But : Comprendre ce que Roo fait MAINTENANT + ce qui existe dans le code/la doc.

**0b. Lecture INTERCOM (via Dashboard) :**
1. **METHODE OBLIGATOIRE :** `roosync_dashboard(action: "read", type: "workspace+machine", section: "intercom", intercomLimit: 10)`
2. **Fallback fichier** (si MCP echoue) : Lire `.claude/local/INTERCOM-{MACHINE}.md`
3. Identifier les messages recents de Roo (< 24h)
4. Extraire :
   - Taches en cours ou terminees par Roo
   - Demandes a Claude
   - Modifications locales (submodule, fichiers)
   - Questions ou blocages

### Output attendu
```
## Phase 0 : Contexte Local + SDDD

### Grounding semantique
- codebase_search : X resultats pertinents
- Roo tache active : [description] ou [aucune]

### Messages INTERCOM recents : Y
| Heure | Type | Contenu |
|...

### Points cles
- Tache Roo : [en cours/terminee]
- Demandes a Claude : [liste]
- Modifications locales : [fichiers]
```

**Si Roo signale un merge en cours ou des modifications locales : gerer AVANT Phase 2 !**

---

## Phase 1 : Collecte des Messages RooSync (CRITIQUE — NE JAMAIS SAUTER)

> **⚠️ OBLIGATOIRE : Lire l'inbox RooSync AVANT toute analyse git ou GitHub. Ne JAMAIS déclarer une machine "silencieuse" sans avoir vérifié l'inbox. C'est la source principale d'information sur l'activité des autres machines.**

**Agent :** `roosync-hub` (coordinateur) ou `roosync-reporter` (exécutants)

### Actions
1. Lire tous les messages non-lus avec `roosync_read` (mode: inbox)
2. Pour chaque message, récupérer les détails avec `roosync_read` (mode: message)
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

## Phase 1.5 : Audit Configuration (CRITIQUE)

**Agent :** `config-auditor`

**Objectif :** Detecter les derives de configuration MCP/modes avant qu'elles ne causent des incidents.

### Reference

Issue #614: Integrate config-auditor to reduce config incidents by ~70%.

### Actions

Lancer l'audit de configuration via l'agent config-auditor :

```
Agent(
  subagent_type="config-auditor",
  prompt="Auditer la configuration MCP sur cette machine.
          Verifier: win-cli fork local, roo-state-manager present avec 34 outils,
          pas de MCPs obsoletes (desktop-commander, github-projects-mcp).
          Rapporter les ecarts classes par severite (CRITICAL/WARNING/INFO)."
)
```

### Scope de l'audit

Le config-auditor verifie :
- **Config MCP (mcp_settings.json)** : win-cli fork local, roo-state-manager present, alwaysAllow coherence
- **MCPs obsolètes** : desktop-commander, github-projects-mcp ne doivent pas être présents
- **Modes Roo (.roomodes)** : Nombre de modes attendus, profils valides, groups=[]
- **Scheduler (.roo/schedules.json)** : Intervalle 180min, staggering correct
- **Config RooSync** : Variables d'environnement EMBEDDING_*, QDRANT_*, ROOSYNC_*

### Output attendu

```
## Phase 1.5 : Audit Configuration

### Résultat audit
- Critiques : X (bloqueurs)
- Warnings : Y (à nettoyer si possible)
- Infos : Z (documentaires)

### Actions requises
- [ ] [Description action critique]
- [ ] [Description action warning]

### Decision
- ✅ Continue vers Phase 2 (si 0 critiques)
- ⚠️ STOP & REPAIR requis (si critiques detectees)
```

### Si CRITICAL detecté

Arreter le sync-tour immediatement :
1. Documenter le probleme via `roosync_dashboard(action: "append", type: "workspace+machine", tags: ["CRITICAL"])` (fallback: fichier INTERCOM)
2. Envoyer message RooSync URGENT au coordinateur
3. NE PAS continuer vers Phase 2 (Git Sync)

**Resume attendu :**
```
## Phase 1.5 : ERREUR CRITIQUE
- Problème : [description]
- Impact : [scheduler bloqué / MCP manquant / etc.]
- Action : [STOP & REPAIR avant continuation]
```

---

## Phase 1.6 : Détection Frictions (#637)

**Objectif :** Identifier les patterns d'erreurs récurrents dans les traces Roo et Claude via recherche sémantique.

**Quand l'exécuter :** Toujours (prend < 30 secondes). Les résultats alimentent Phase 5 (GitHub updates) et Phase 6 (planification).

### Actions

```
roosync_search(
  action: "semantic",
  search_query: "impossible bloque erreur echec fail permission denied",
  has_errors: true,
  start_date: "{72h ago}",
  max_results: 10
)
```

### Analyse des résultats

Pour chaque résultat retourné :
1. Identifier le `tool_name` (outil fautif)
2. Identifier le `source` (roo ou claude-code)
3. Identifier le `model` (modèle spécifique si pertinent)
4. Compter les occurrences par outil/type

**Seuil d'action :** Pattern ≥ 2 occurrences → candidat friction à signaler

### Requêtes complémentaires (optionnelles si frictions détectées)

```
# Historique outil spécifique (si un outil ressort souvent)
roosync_search(action: "semantic", search_query: "erreur {NOM_OUTIL}", tool_name: "{NOM_OUTIL}", max_results: 5)

# Messages utilisateurs uniquement (frustrations directes)
roosync_search(action: "semantic", search_query: "bloque erreur", role: "user", exclude_tool_results: true, start_date: "{72h ago}", max_results: 5)
```

### Output attendu

```
## Phase 1.6 : Frictions Détectées

### Résultats recherche (72h, has_errors=true)
- X résultats trouvés

### Patterns (≥ 2 occurrences)
| Outil/Contexte | Occurrences | Source | Exemple |
|----------------|-------------|--------|---------|
| write_to_file  | 3           | roo    | "impossible de créer..." |
| roosync_send   | 2           | both   | "timeout..." |

### Actions recommandées
- [ ] Créer issue friction pour [outil] si pattern confirmé (Phase 5)
- [ ] Signaler au coordinateur si systémique (Phase 7)

### Résumé
- Frictions détectées : X | Patterns à signaler : Y
```

**Si aucune friction détectée :** Documenter "0 frictions (72h)" et continuer Phase 1.7.

---

## Phase 1.7 : Vérification Notifications Git (#741)

**Objectif :** Détecter les notifications critiques (CI failures, PRs oubliées, stashes orphelins) avant la synchronisation. Prend < 1 minute.

**⚠️ Note CLI :** `gh notification list` n'existe pas. Utiliser `gh api notifications`.

### Actions

```bash
# Notifications GitHub (filtrer sur le repo courant)
gh api notifications --jq '.[] | select(.repository.full_name | contains("roo-extensions")) | {title: .subject.title, type: .subject.type, unread: .unread}'

# PRs ouvertes
gh pr list --repo jsboige/roo-extensions

# Stashes git (parent + submodule)
git stash list
cd mcps/internal && git stash list && cd ../..

# Statut workspace
git status
```

### Analyse des résultats

- **Notifications critiques** : CI failure récent (< 24h) sur main → investiguer AVANT Phase 2
- **PRs en attente** : PR ouverte sans reviewer → vérifier si assignée
- **Stashes orphelins** : stash > 72h → investiguer (code perdu ?)
- **Workspace sale** : fichiers modifiés non commités → gérer AVANT git sync

### Output attendu

```
## Phase 1.7 : Notifications Git

| Vérification | Résultat |
|-------------|---------|
| Notifications critiques (roo-extensions) | ✅ Aucune / ⚠️ X critique(s) |
| PRs ouvertes | ✅ Aucune / ℹ️ X PR(s) |
| Stashes orphelins | ✅ Aucun / ⚠️ X stash(es) |
| Workspace | ✅ Clean / ⚠️ Fichiers modifiés |
```

**Si notifications critiques ou workspace sale :** Gérer AVANT Phase 2.

---

## Phase 2 : Synchronisation Git

**Skill :** `git-sync` (voir `.claude/skills/git-sync/SKILL.md`)

**⚠️ Si Bash échoue silencieusement :** Voir `docs/guides/BASH_FALLBACK.md` → utiliser MCP win-cli en fallback.

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

### Gestion des Erreurs et Auto-Rollback (NOUVEAU)

**Si une erreur critique survient pendant le sync :**

| Situation | Action | Commande |
|-----------|--------|----------|
| Merge conflict non résoluble | Abandonner le merge | `git merge --abort` |
| Tests échouent après pull | Identifier le commit coupable | `git bisect start HEAD HEAD~5` |
| Submodule cassé | Reset propre du submodule | `cd mcps/internal && git reset --hard origin/main` |
| Workspace dirty bloqué | Stash les changements locaux | `git stash push -m "sync-tour-$(date)"` |

**Point de restauration :**
```bash
# En cas de problème majeur, revenir à l'état avant sync
git reflog expire --expire=now HEAD@{1}  # Marquer le point dangereux
git reset --hard HEAD@{2}                 # Revenir à l'état stable
```

**Rapport d'erreur :**
```
## Phase 2 : ERREUR CRITIQUE
- Type : [Merge conflict | Tests fail | Submodule error]
- Action : [Rollback effectué | Manual intervention required]
- Commit incriminé : [hash] si identifié
- Message d'erreur : [details]
```

---

## Phase 3 : Validation Tests & Build

**Skill :** `validate` (voir `.claude/skills/validate/SKILL.md`)

**⚠️ Si Bash échoue silencieusement :** Voir `docs/guides/BASH_FALLBACK.md` → utiliser MCP win-cli en fallback.

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

## Phase 3.5 : Mise à jour Checklists GitHub (CRITIQUE)

**Référence :** [`../../docs/github-checklists.md`](../../docs/github-checklists.md)

### Objectif

S'assurer que les tableaux de validation dans les issues GitHub sont maintenues à jour pour garantir une traçabilité fiable.

### Actions

**Si une issue avec un tableau de validation est en cours :**

1. **Identifier le tableau** dans le corps de l'issue
2. **Mettre à jour les cases** correspondantes à cette machine :
   - Remplacer `⬜` par `✅` (PASS) ou `❌` (FAIL)
3. **Commettre immédiatement** la mise à jour :
   ```bash
   gh issue edit {NUM} --body "TABLEAU_MAJ"
   ```
4. **Vérifier que toutes les cases** sont cochées avant de fermer l'issue

**RÈGLE ABSOLUE : NE JAMAIS commenter ou fermer une issue avec un tableau vide.**

### Output attendu
```
## Phase 3.5 : Checklists GitHub

### Issues avec tableaux de validation
- Issue #XXX : Tableau mis à jour (X/Y cases cochées)
- Issue #YYY : Tableau complet (100%) → Prêt pour fermeture
- Issue #ZZZ : Tableau partiel → En attente d'autres machines

### Actions effectuées
- Mises à jour : X
- Commentaires : Y
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
   - ⚠️ **VÉRIFIER CHECKLIST** : S'assurer que le tableau est 100% rempli avant de marquer Done
   - Identifier tâches complétées annoncées par les agents
   - Vérifier cohérence avec git log (commits récents)
   - Mettre à jour statut dans Project #67
   - Ajouter commentaire "Complété par [machine/agent]"
   - **Référence :** [`../../docs/github-checklists.md`](../../docs/github-checklists.md)

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
   - Envoyer avec `roosync_send` (action: reply)

**2. Machines silencieuses (pas de message récent) :**
   - Si dernière activité > 48h : envoyer message priorité HIGH
   - Si dernière activité > 72h : envoyer message priorité URGENT
   - Si dernière activité > 96h : signaler à l'utilisateur + réassigner tâches critiques
   - Envoyer avec `roosync_send` (action: send)

**3. Machines actives sans nouvelle tâche :**
   - Envoyer mise à jour sur déploiement en cours
   - Demander rapport status local
   - Assigner tâches buffer si disponibles

**4. Gestion des messages :**
   - Marquer tous les messages traités comme lus via `roosync_manage` (action: mark_read)
   - Archiver les messages > 7 jours si conversation terminée via `roosync_manage` (action: archive)

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

**0. Bookend SDDD (fin de tache) :**
```
codebase_search(query: "synchronisation coordination etat machines", workspace: "d:\\roo-extensions")
```
Verifier que les modifications de ce tour (doc, rules, code) sont coherentes avec l'existant.

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

## Phase 4bis : Vision 360 RooSync (Coordinateur)

**Objectif :** Utiliser les outils RooSync au-dela de la messagerie pour une vision globale des machines.

### Actions

**4bis-a. Etat des machines :**
```
roosync_heartbeat(action: "status", filter: "all", includeHeartbeats: true)
```

**4bis-b. Comparaison des configs (si heartbeat montre des machines actives) :**
```
roosync_compare_config(granularity: "mcp")
```

**4bis-c. Rafraichir le dashboard MCP :**
```
roosync_refresh_dashboard(baseline: "myia-ai-01")
```

**4bis-d. Inventaire machine (optionnel, si drift detecte) :**
```
roosync_inventory(type: "all")
```

### Output attendu
```
## Phase 4bis : Vision 360 RooSync

### Machines enregistrees : X/6
| Machine | Heartbeat | Dernier signal | Config sync |
|...

### Drifts detectes
- [machine] : MCP [nom] manquant vs baseline
- [machine] : config divergente sur [aspect]

### Actions requises
- [machine] doit executer roosync_config(action: "collect") + publish
```

**4bis-e. Audit post-modification MCP (si config modifiee ce tour) :**

Si des modifications MCP ont ete effectuees pendant ce tour (via `manage_mcp_settings` ou manuellement), lancer un audit via sk-agent :
```
call_agent(agent: "critic", prompt: "Audit MCP config changes: [description]. Check alwaysAllow completeness, disabled servers, naming consistency, drift vs other machines.")
```
Inclure le resultat de l'audit dans le rapport de Phase 4bis.

### Friction
Si un outil RooSync ne fonctionne pas ou donne des resultats inexploitables, signaler :
```
roosync_send(action: "send", to: "all", subject: "[FRICTION] Outil RooSync [nom]", body: "...", tags: ["friction", "roosync"])
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

## Phase 9 : Mise à jour Dashboard Hiérarchique GDrive

**Objectif :** Mettre à jour le dashboard partagé GDrive avec l'état actuel de la machine.

**Outil :** `roosync_dashboard` (Phase 1 #546)

### Actions

**9a. Mettre à jour la section machine :**
```
roosync_dashboard(
  section: "machine",
  machine: "{MACHINE}",
  workspace: "roo-extensions",
  content: "{ETAT_ACTUEL_MARKDOWN}",
  mode: "replace"
)
```

Le contenu markdown doit inclure :
- État : actif/inactif, cycle N
- Dernière action : [résumé]
- Git : hash, statut
- Tests : résultats
- Notes libres de l'agent

**9b. Mettre à jour les métriques globales (coordinateur uniquement) :**
```
roosync_dashboard(
  section: "metrics",
  content: "{METRIQUES_GITHUB}",
  mode: "replace"
)
```

### Output attendu
```
## Phase 9 : Dashboard GDrive

### Mise à jour effectuée
- Section machine : {MACHINE}/roo-extensions
- Dashboard path : {ROOSYNC_SHARED_PATH}/DASHBOARD.md
- Timestamp : {date}

### État rapporté
- Git : {hash}
- Tests : {résultats}
- Messages traités : {X}
```

---

## Notes d'utilisation

### Frequence
- **Debut de session** : Tour complet (toutes les phases)
- **Pendant le travail** : Phases specifiques a la demande
- **Fin de session** : Tour complet + Phase 8 obligatoire + Phase 9 (dashboard) + commit des changements
- **Avant saturation contexte** : Phase 8 en priorite (sauvegarder l'experience)

### Permissions requises
Ce skill necessite de nombreuses permissions car il :
- Lit et ecrit des messages RooSync
- Fait des pull/merge Git
- Lance des builds et tests
- Modifie des fichiers (corrections)
- Met a jour GitHub Projects et Issues
- Met a jour les fichiers memoire (Phase 8)
- Met a jour le dashboard GDrive (Phase 9)

### Duree estimee
Un tour complet prend generalement 6-12 minutes selon le volume de messages et l'etat des tests. La Phase 1.5 (audit) ajoute 1-2 minutes. La Phase 8 ajoute 2-3 minutes. La Phase 9 ajoute 30 secondes.
