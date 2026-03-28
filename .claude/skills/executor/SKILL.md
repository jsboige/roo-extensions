---
name: executor
description: Lance une session d'exécution multi-agent RooSync pour les machines executantes (myia-po-* et myia-web1). Peut démarrer une nouvelle session ou reprendre une session interrompue avec --resume. Phrase déclencheur : "/executor", "/executor --resume", "mode executor", "lance executor", "reprends executor".
metadata:
  author: "Roo Extensions Team"
  version: "2.0.0"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Requiert accès aux MCPs roo-state-manager, win-cli pour shell"
---

# Skill: Executor - Session d'Exécution RooSync avec Reprise

**Version:** 2.0.0
**Cree:** 2026-03-28
**MAJ:** 2026-03-28
**Usage:** `/executor` ou `/executor --resume`
**Methodologie:** SDDD triple grounding (voir `.claude/rules/sddd-conversational-grounding.md`)

---

## Objectif

Exécuter une session de travail autonome sur les machines executantes (myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026, myia-web1), avec la possibilité de **reprendre une session interrompue** là où elle s'est arrêtée.

---

## Workflow

### Phase 0 : Mode Détection

**Première action : déterminer si c'est une nouvelle session ou une reprise.**

```
ARGV analysis:
- Si contient "--resume" → Mode RESUME
- Sinon → Mode NEW (comportement normal)
```

**Pour --resume, vérifier l'existence d'un état sauvegardé :**
```bash
# Lire le fichier d'état
Read: .claude/executor-state.json
```

Si le fichier n'existe pas ou est vide → message d'erreur et proposer une nouvelle session.

---

### Phase 1 : Nouvelle Session (comportement normal)

**Si PAS de flag --resume :**

1. **Générer un sessionId unique** : UUID ou timestamp-machine
2. **Initialiser l'état** avec les métadonnées de session
3. **Exécuter le workflow normal** (voir ci-dessous "Workflow Executor Normal")

**Écriture de l'état initial :**
```json
{
  "sessionId": "{UUID}",
  "startTime": "2026-03-28T10:00:00Z",
  "lastActivity": "2026-03-28T10:00:00Z",
  "currentPhase": "PHASE_1",
  "tasksCompleted": [],
  "tasksInProgress": [],
  "tasksPending": [],
  "context": {
    "gitState": "{commit_hash}",
    "machineId": "myia-po-2023",
    "workspace": "wt-worker-{desc}",
    "notes": "Session démarrée"
  },
  "metadata": {
    "version": "1.0.0",
    "created": "2026-03-28T10:00:00Z",
    "modified": "2026-03-28T10:00:00Z",
    "sessionType": "interactive"
  }
}
```

---

### Phase 2 : Mode Resume (restauration d'état)

**Si flag --resume détecté :**

#### 2a. Lecture et validation de l'état

```
Read: .claude/executor-state.json
```

Si le fichier n'existe pas :
- Afficher : "Aucun état sauvegardé trouvé. Démarrage d'une nouvelle session..."
- Passer en Phase 1 (nouvelle session)

Si le fichier existe :
- Charger les données
- Valider que la session est récente (< 48h)
- Afficher le rapport de reprise (voir ci-dessous)

#### 2b. Rapport de Reprise

**Afficher automatiquement :**

```markdown
## 🔄 Session Executor Restaurée

**Session ID :** {sessionId}
**Dernière activité :** Il y a {X}h ({lastActivity})
**Phase en cours :** {currentPhase}
**Type de session :** {interactive|scheduled}

### 📍 État Git
- **Commit :** {gitState}
- **Machine :** {machineId}
- **Workspace :** {workspace}

### ✅ Tâches Complétées ({count})
{Liste des tâches complétées}

### 🔄 Tâches en Cours ({count})
{Liste des tâches en cours avec statut}

### 📋 Tâches en Attente ({count})
{Liste des tâches pending}

### 📝 Notes de Session
{notes si disponibles}

---

## Actions Disponibles

1. **Continuer la session** → Reprendre à {currentPhase}
2. **Démarrer une nouvelle session** → Effacer l'état et repartir à zéro
3. **Voir les détails** → Afficher plus d'informations sur une tâche spécifique

---

Continuer? [Y/n]
```

#### 2c. Restauration automatique

**Si confirmation (Y) :**
- Mettre à jour `lastActivity` avec timestamp actuel
- Restaurer le contexte de travail
- Continuer à la phase où la session s'est arrêtée

**Si refus (n) :**
- Proposer de démarrer une nouvelle session
- Archiver l'état actuel dans `.claude/executor-state.archive.json`

---

### Phase 3 : Workflow Executor Normal

**Exécuter les phases du workflow executor (voir `.claude/commands/executor.md`)**

**PHASES :**
- PHASE_0 : Pre-flight Check (MCPs, heartbeat)
- PHASE_1 : Collecte + Grounding SDDD
- PHASE_1.5 : Analyse traces scheduler
- PHASE_2 : Sélection de tâche
- PHASE_3 : Exécution autonome

**Mise à jour automatique de l'état à chaque phase :**

```javascript
// À chaque transition de phase
currentPhase = "PHASE_X";
lastActivity = new Date().toISOString();

// Sauvegarder
Write: .claude/executor-state.json
```

**Suivi des tâches :**

- Quand une tâche est **commencée** → Ajouter à `tasksInProgress`
- Quand une tâche est **complétée** → Déplacer de `InProgress` à `tasksCompleted`
- Quand une tâche est **bloquée** → Marquer avec status "blocked" + raison

**Exemples de transitions d'état :**

```json
// Tâche commencée
"tasksInProgress": [
  {
    "issue": "#925",
    "status": "investigation",
    "branch": "wt/worker-myia-po-2023-issue-925",
    "notes": "Implémentation du système de reprise"
  }
]

// Tâche complétée
"tasksCompleted": ["#925", "#902", "#905"],
"tasksInProgress": [],

// Tâche bloquée
"tasksInProgress": [
  {
    "issue": "#914",
    "status": "blocked",
    "notes": "En attente de validation configs sur myia-ai-01"
  }
]
```

---

### Phase 4 : Sauvegarde Automatique de l'État

**L'état DOIT être sauvegardé automatiquement :**

1. **Au démarrage** de la session
2. **À chaque transition de phase** (PHASE_0 → PHASE_1 → etc.)
3. **Après chaque action significative** :
   - Tâche commencée
   - Tâche complétée
   - Commit effectué
   - PR créée
4. **Avant chaque tentative de completion** (`attempt_completion`)

**Utiliser l'outil Write pour mettre à jour le fichier :**

```
Write: .claude/executor-state.json
{
  ...état mis à jour...
}
```

**NE PAS utiliser Edit** → Réécrire tout le fichier pour garantir l'intégrité.

---

### Phase 5 : Intégration avec Debrief

**À la fin de la session (via `/debrief`) :**

1. **Sauvegarder l'état final** dans `.claude/executor-state.json`
2. **Créer un rapport de session** structuré
3. **Proposer de créer une issue GitHub** si travail inachevé (`tasksInProgress` non vide)

**Le skill debrief peut lire l'état executor pour :**

- Générer un résumé de session automatique
- Identifier les tâches inachevées
- Proposer des next actions basées sur l'état

---

### Phase 6 : Nettoyage et Archivage

**Quand une session est terminée avec succès :**

1. **Archiver l'état** dans `.claude/executor-state.archive/`
   - Nom du fichier : `executor-state-{sessionId}-{timestamp}.json`
2. **Effacer l'état courant** (remettre à null/vide)
3. **Garder seulement les 5 derniers archives** (nettoyer les plus anciennes)

**Si une session reste inachevée > 7 jours :**

- Signaler via dashboard workspace avec tag `[STALE]`
- Proposer de clôturer ou de reprendre manuellement

---

## 🛠️ Outils Utilisés

- **Read** : Lire l'état sauvegardé, workflows, documentation
- **Write** : Sauvegarder l'état (NE PAS utiliser Edit pour l'état)
- **Edit** : Modifier d'autres fichiers (code, configs)
- **Bash** : Commandes git, hostname, vérifications système
- **roosync_dashboard** : Rapporter la progression cross-machine
- **conversation_browser** : Grounding conversationnel SDDD

---

## 📏 Critères de Qualité

**Une bonne reprise de session doit être :**
- ✅ **Transparente** : L'utilisateur voit exactement où la session en est
- ✅ **Complète** : Toutes les informations contextuelles sont restaurées
- ✅ **Automatique** : Pas de manipulation manuelle de fichiers
- ✅ **Fiable** : L'état est sauvegardé à chaque étape critique

---

## 🚀 Invocation

```bash
# Nouvelle session (comportement normal)
/executor

# Reprendre la dernière session
/executor --resume

# Reprendre une session spécifique (futur)
/executor --resume {SESSION_ID}
```

---

## 📝 Notes

- **Durée estimée** : Session complète (2-4h)
- **Fréquence de sauvegarde** : À chaque phase (~15-30 min)
- **Pré-requis** : Avoir le fichier `.claude/executor-state.json` pour resume
- **Compatibilité** : Fonctionne avec le workflow Roo scheduler (orchestrator-simple)
- **Fallback** : Si le MCP dashboard échoue, utiliser le fichier INTERCOM local

---

## 🔧 Dépannage

**Problème : État non sauvegardé**
- Cause : Erreur d'écriture disque, permissions
- Solution : Vérifier les permissions `.claude/`, réessayer manuellement

**Problème : Session trop ancienne (> 48h)**
- Solution : Demander confirmation avant reprise, proposer nouvelle session

**Problème : Git state incompatible**
- Solution : Faire un `git pull` automatique, vérifier les conflits

---

**Dernière mise à jour :** 2026-03-28
