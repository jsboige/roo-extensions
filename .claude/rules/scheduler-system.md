# Systeme de Scheduler Roo - Reference Technique

Extrait de CLAUDE.md le 2026-02-19. Documentation complete du systeme de planification automatique Roo.

---

## Architecture du Systeme

**Composants :**

1. **Extension Roo Scheduler** (`kylehoskins.roo-scheduler`)
   - Extension VS Code qui lit `.roo/schedules.json`
   - Execute les taches selon l'intervalle configure
   - Traces dans `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks`

2. **Configuration Scheduler**
   - **Template** : `.roo/schedules.template.json` (source generique)
   - **Deploye** : `.roo/schedules.json` (personnalise par machine)

3. **Modes Roo** (10 modes : 5 familles x 2 niveaux)
   - **Source** : `roo-config/modes/modes-config.json`
   - **Template** : `roo-config/modes/templates/commons/mode-instructions.md`
   - **Genere** : `roo-config/modes/generated/simple-complex.roomodes`
   - **Deploye** : `.roomodes` (copie a la racine)

---

## Generation et Deploiement

### Modes Roo

```bash
# Generer les modes
node roo-config/scripts/generate-modes.js

# Deployer
Copy-Item roo-config/modes/generated/simple-complex.roomodes .roomodes
```

**REGLE :** Ne JAMAIS modifier `.roomodes` directement. Modifier les sources et regenerer.

### Scheduler

```powershell
# Deployer
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy

# Desactiver
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action disable

# Statut
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action status
```

**Parametres de production :**
- **Intervalle** : 180 minutes (3h)
- **Staggering** : startMinute different par machine
  - myia-ai-01: 00, myia-po-2023: 30, myia-po-2024: 00, myia-po-2025: 30, myia-po-2026: 00, myia-web1: 30
- **Mode** : `orchestrator-simple` (delegue aux modes `-simple` via `new_task`)

**BUG CONNU :** Le scheduler cache la config au demarrage. Apres deploy, redemarrer VS Code IMMEDIATEMENT avant le prochain tick.

---

## Workflow d'une Execution Scheduler

1. **Lire INTERCOM** local → Chercher messages [SCHEDULED], [TASK], [URGENT]
2. **Verifier workspace** → `git status`, signaler si dirty
3. **Executer taches** → DELEGUER via `new_task` (jamais faire soi-meme)
4. **Rapporter** → Ecrire dans INTERCOM local (PAS roosync_send)
5. **Ne PAS commiter** → Claude Code valide et commit
6. **Maintenance INTERCOM** → Si >1000 lignes, condenser

---

## Mecanisme d'Escalade

**Documentation complete :** [`.claude/ESCALATION_MECHANISM.md`](.claude/ESCALATION_MECHANISM.md)

3 couches d'escalade automatique :
1. **Couche Scheduler** : `orchestrator-simple` → `orchestrator-complex` (6 criteres)
2. **Couche Modes** : `*-simple` → `*-complex` (4 criteres par mode)
3. **Couche Orchestrateurs** : Instructions SDDD, delegation, routage inter-famille

**Principe :** Commencer simple (economique), escalader si necessaire (puissant).

### Roadmap Autonomie Progressive (#462)

| Niveau | Statut | Description |
|--------|--------|-------------|
| **1 : Roo Simple** | ACTUEL | Taches `-simple` (git, build, tests, cleanup) |
| **2 : Roo Complex** | EN COURS | Taches `-complex` avec validation Claude |
| **3 : Claude INTERCOM** | PLANIFIE | Claude Code lit INTERCOM et execute |
| **4 : Claude Scheduled** | FUTUR | Claude Code schedule automatiquement |
| **5 : Autonomie** | VISION | Collaboration continue, worktrees, PRs |

---

## Traces d'Execution

**Chemin :** `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\{TASK_ID}`

**Fichiers :**
- `api_conversation_history.json` - Historique complet
- `task_metadata.json` - Metadonnees
- `ui_messages.json` - Messages UI condenses

**Verification reguliere :** Consulter traces apres chaque run (~3h), analyser delegations, erreurs.

---

## Workflow d'Amelioration

1. **Identifier** : Lire traces (`ui_messages.json`)
2. **Corriger** :
   - Orchestrateur → `roo-config/modes/modes-config.json` → regenerer → copier `.roomodes`
   - Scheduler → `.roo/schedules.template.json` → redeploy
3. **Tester** : Attendre prochain tick ou relancer
4. **Deployer** : Commit + push, chaque machine pull + redeploy

### Fichiers Sources (Ne Jamais Modifier les Cibles)

| Source | Generateur | Cible |
|--------|-----------|-------|
| `roo-config/modes/modes-config.json` | `generate-modes.js` | `simple-complex.roomodes` |
| `roo-config/modes/templates/commons/mode-instructions.md` | (idem) | (idem) |
| `.roo/schedules.template.json` | `deploy-scheduler.ps1` | `.roo/schedules.json` |
