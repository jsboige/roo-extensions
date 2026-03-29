---
name: executor
description: Lance une session d'exécution multi-agent RooSync pour les machines executantes (myia-po-* et myia-web1). Peut démarrer une nouvelle session ou reprendre une session interrompue avec --resume. Phrase déclencheur : "/executor", "/executor --resume", "mode executor", "lance executor", "reprends executor".
metadata:
  author: "Roo Extensions Team"
  version: "3.0.0"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Requiert accès aux MCPs roo-state-manager, win-cli pour shell"
  changement_v3_0: "Etat de session via roosync_dashboard (workspace) au lieu de .claude/executor-state.json (fichier repo). Plus d approbation utilisateur requise, visible par tout le cluster."
---

# Skill: Executor - Session d'Exécution RooSync avec Reprise

**Version:** 3.0.0
**Cree:** 2026-03-28
**MAJ:** 2026-03-28
**Usage:** `/executor` ou `/executor --resume`
**Methodologie:** SDDD triple grounding (voir `.claude/rules/sddd-conversational-grounding.md`)
**Changement v3.0 :** Etat de session via `roosync_dashboard` (workspace) au lieu de `.claude/executor-state.json` (fichier repo). Plus d approbation utilisateur requise, visible par tout le cluster.

---

## Objectif

Exécuter une session de travail autonome sur les machines executantes (myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026, myia-web1), avec la possibilité de **reprendre une session interrompue** là où elle s'est arrêtée.

---

## Gestion de l'État — Dashboard Workspace

**L'état de session est stocké dans le dashboard RooSync `workspace`, PAS dans un fichier local.**

### Pourquoi ?

- **Pas d'approbation utilisateur** : Les appels MCP ne nécessitent pas de validation manuelle (contrairement aux Write/Edit dans le repo)
- **Visible par tout le cluster** : Les autres agents voient l'état de chaque exécuteur en temps réel
- **Auto-condensation** : Le dashboard se nettoie à 500 messages
- **Persistance GDrive** : L'état survit aux redémarrages de session

### Format du message d'état

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["EXECUTOR-STATE", "{machineId}", "{sessionId}"],
  content: "## 🔄 Executor State — {machineId}

**Session:** {sessionId}
**Phase:** {currentPhase}
**Dernière activité:** {ISO_TIMESTAMP}
**Git:** {commit_hash}

### ✅ Complétées ({count})
{liste}

### 🔄 En cours ({count})
{liste avec statut}

### 📋 En attente ({count})
{liste}

### 📝 Notes
{notes}"
)
```

### Tags convention

| Tag | Usage |
|-----|-------|
| `EXECUTOR-STATE` | Identifie un message d'état (permet filtrage) |
| `{machineId}` | Ex: `myia-po-2025` (permet filtrage par machine) |
| `{sessionId}` | Ex: `exec-po2025-20260328` (permet filtrage par session) |

---

## Workflow

### Phase 0 : Mode Détection

**Première action : déterminer si c'est une nouvelle session ou une reprise.**

```
ARGV analysis:
- Si contient "--resume" → Mode RESUME
- Sinon → Mode NEW (comportement normal)
```

**Pour --resume, chercher le dernier état dans le dashboard :**
```
roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 50)
```
Chercher le dernier message avec tag `EXECUTOR-STATE` pour cette machine.

Si aucun état trouvé → message d'erreur et proposer une nouvelle session.

---

### Phase 1 : Nouvelle Session (comportement normal)

**Si PAS de flag --resume :**

1. **Générer un sessionId unique** : `exec-{machineId}-{YYYYMMDD}`
2. **Capturer l'état git** : `git log --oneline -1`
3. **Poster l'état initial** via dashboard :

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["EXECUTOR-STATE", "{machineId}", "{sessionId}"],
  content: "## 🔄 Executor State — {machineId}

**Session:** {sessionId}
**Phase:** PHASE_0
**Démarrage:** {ISO_TIMESTAMP}
**Git:** {commit_hash}
**Machine:** {hostname}

### ✅ Complétées (0)
*Aucune*

### 🔄 En cours (0)
*Aucune*

### 📋 En attente
*En cours de collecte...*

### 📝 Notes
Session démarrée"
)
```

4. **Exécuter le workflow normal** (voir "Workflow Executor Normal" ci-dessous)

---

### Phase 2 : Mode Resume (restauration d'état)

**Si flag --resume détecté :**

#### 2a. Lecture et validation de l'état

```
roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 50)
```

Chercher le dernier message `EXECUTOR-STATE` pour cette machine. Si trouvé :
- Valider que `lastActivity` est < 48h
- Afficher le rapport de reprise

Si aucun état trouvé :
- Afficher : "Aucun état sauvegardé trouvé sur le dashboard. Démarrage d'une nouvelle session..."
- Passer en Phase 1 (nouvelle session)

#### 2b. Rapport de Reprise

**Afficher automatiquement :**

```markdown
## 🔄 Session Executor Restaurée

**Session ID :** {sessionId}
**Dernière activité :** Il y a {X}h
**Phase en cours :** {currentPhase}

### 📍 État Git
- **Commit :** {gitState}
- **Machine :** {machineId}

### ✅ Tâches Complétées ({count})
{Liste des tâches complétées}

### 🔄 Tâches en Cours ({count})
{Liste des tâches en cours avec statut}

### 📋 Tâches en Attente ({count})
{Liste des tâches pending}

---

Continuer? [Y/n]
```

#### 2c. Restauration automatique

**Si confirmation (Y) :**
- Poster un nouveau message d'état via dashboard avec `lastActivity` mis à jour
- Continuer à la phase où la session s'est arrêtée

**Si refus (n) :**
- Proposer de démarrer une nouvelle session

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

Poster un message dashboard à chaque transition :
```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["EXECUTOR-STATE", "{machineId}", "{sessionId}"],
  content: "## 🔄 Executor State — {machineId}
**Phase:** PHASE_X | **Activité:** {ISO_TIMESTAMP} | **Git:** {hash}
..."
)
```

**Suivi des tâches :**

- Quand une tâche est **commencée** → Poster état avec tâche dans "En cours"
- Quand une tâche est **complétée** → Poster état avec tâche déplacée dans "Complétées"
- Quand une tâche est **bloquée** → Poster état avec raison du blocage

---

### Phase 4 : Sauvegarde Automatique de l'État

**L'état DOIT être posté sur le dashboard automatiquement :**

1. **Au démarrage** de la session
2. **À chaque transition de phase** (PHASE_0 → PHASE_1 → etc.)
3. **Après chaque action significative** :
   - Tâche commencée
   - Tâche complétée
   - Commit effectué
   - PR créée
4. **Avant chaque tentative de completion** (`attempt_completion`)

**Utiliser `roosync_dashboard(action: "append")` — PAS Write/Edit de fichier.**

---

### Phase 5 : Intégration avec Debrief

**À la fin de la session (via `/debrief`) :**

1. **Poster l'état final** via dashboard (session terminée)
2. **Créer un rapport de session** structuré
3. **Proposer de créer une issue GitHub** si travail inachevé (`tasksInProgress` non vide)

**Le skill debrief peut lire le dashboard pour :**
- Trouver le dernier message `EXECUTOR-STATE` de la machine
- Générer un résumé de session automatique
- Identifier les tâches inachevées

---

### Phase 6 : Staleness Detection

**Si une session reste inachevée > 7 jours :**

- Le coordinateur peut détecter les sessions stale en cherchant les messages `EXECUTOR-STATE` anciens
- Le dashboard s'auto-condense à 500 messages, les états très anciens sont naturellement archivés

---

## 🛠️ Outils Utilisés

- **Bash** : Commandes git, hostname, vérifications système
- **roosync_dashboard** : Sauvegarder et restaurer l'état de session + rapporter progression
- **roosync_read/manage** : Lire inbox, marquer messages
- **roosync_send** : Répondre aux dispatches
- **conversation_browser** : Grounding conversationnel SDDD
- **Read/Grep/Glob** : Investigation codebase
- **Edit** : Modifier le code source (uniquement pour le travail, pas l'état)

---

## 📏 Critères de Qualité

**Une bonne reprise de session doit être :**
- ✅ **Transparente** : L'utilisateur voit exactement où la session en est
- ✅ **Complète** : Toutes les informations contextuelles sont restaurées depuis le dashboard
- ✅ **Automatique** : Pas de manipulation manuelle de fichiers
- ✅ **Fiable** : L'état est sauvegardé via MCP (pas de friction approbation)
- ✅ **Partagée** : Les autres agents du cluster voient l'état en temps réel

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
- **Pré-requis** : MCP roo-state-manager fonctionnel (dashboard accessible)
- **Compatibilité** : Fonctionne avec le workflow Roo scheduler (orchestrator-simple)

---

## 🔧 Dépannage

**Problème : Dashboard indisponible (GDrive offline)**
- Cause : GDrive sync en pause, réseau coupé
- Solution : Utiliser fichier INTERCOM local comme fallback temporaire, synchroniser au retour

**Problème : Session trop ancienne (> 48h)**
- Solution : Demander confirmation avant reprise, proposer nouvelle session

**Problème : Git state incompatible**
- Solution : Faire un `git pull` automatique, vérifier les conflits

---

**Dernière mise à jour :** 2026-03-28
