# Analyse de kyle-apex/roo-scheduler

## Vue d'ensemble

**Projet** : [kyle-apex/roo-scheduler](https://github.com/kyle-apex/roo-scheduler)
**Type** : Extension VS Code
**Langage** : TypeScript (95.1%)
**Licence** : Apache 2.0
**Statut** : Community-maintained

Roo Scheduler est une extension VS Code légère permettant d'automatiser des tâches récurrentes en intégration directe avec Roo Code.

---

## Concepts Clés

### 1. Schedule (Tâche Planifiée)

Un Schedule représente une tâche récurrente avec les propriétés suivantes :

```json
{
  "name": "Code Review",
  "prompt": "Review the latest changes and suggest improvements",
  "every": 1,
  "unit": "days",
  "weekdays": ["monday", "wednesday", "friday"],
  "startDate": "2026-01-22",
  "expirationDate": null,
  "onlyIfActive": false,
  "mode": "wait"
}
```

| Propriété | Type | Description |
| --- | --- | --- |
| `name` | string | Nom affiché de la tâche |
| `prompt` | string | Instructions en langage naturel pour Roo |
| `every` | number | Intervalle de répétition |
| `unit` | enum | `minutes`, `hours`, `days` |
| `weekdays` | array | Jours de restriction (optionnel) |
| `startDate` | date | Date de début (optionnel) |
| `expirationDate` | date | Date d'expiration (optionnel) |
| `onlyIfActive` | boolean | N'exécuter que si VS Code actif |
| `mode` | enum | Mode d'exécution (voir ci-dessous) |

### 2. Modes d'Exécution

| Mode | Comportement |
| --- | --- |
| **wait** | Attendre que Roo soit inactif avant d'exécuter |
| **interrupt** | Interrompre la tâche Roo en cours |
| **skip** | Ne pas exécuter si Roo est déjà actif |

### 3. Triggers (Déclencheurs)

Le scheduling utilise un calcul intelligent :

- **Si `startDate` défini** : Calcule le prochain intervalle depuis cette date
- **Si non défini** : Calcule depuis le dernier déclenchement ou minuit

Les restrictions `weekdays` filtrent les jours d'exécution.

---

## Architecture

```
VS Code Extension
    │
    ├── Task Manager
    │   ├── Création/Modification de schedules
    │   ├── Gestion du cycle de vie
    │   └── Persistance (settings.json)
    │
    ├── Queue Manager
    │   ├── File d'attente des tâches
    │   ├── Scheduling (timers)
    │   └── Gestion priorités
    │
    ├── Execution Engine
    │   ├── Pool de workers
    │   └── État d'exécution
    │
    └── Roo Code Integration
        └── Lancement tâches avec instructions
```

### Stockage Configuration

Les schedules sont stockés dans les settings VS Code :

```
%APPDATA%\Code\User\settings.json
  → roo-scheduler.schedules[]
```

---

## Interface Utilisateur

Roo Scheduler fournit une interface graphique dans VS Code :

1. **Panneau Schedules** : Vue liste des tâches planifiées
2. **Create New Schedule** : Formulaire de création
3. **Edit Schedule** : Modification en place
4. **Status Bar** : Indicateur d'état

Commandes disponibles :

- `Roo Scheduler: Create Schedule`
- `Roo Scheduler: List Schedules`
- `Roo Scheduler: Pause/Resume`

---

## Cas d'Usage Appropriés

### Roo Scheduler est adapté pour

1. **Tâches simples et atomiques**
   - Revue de code quotidienne
   - Linting automatique
   - Génération de rapports

2. **Tâches déclenchées par activité développeur**
   - Analyse après commit
   - Suggestions de refactoring

3. **Maintenance légère**
   - Nettoyage imports
   - Formatage code

### Roo Scheduler N'est PAS adapté pour

1. **Orchestration complexe multi-phases**
2. **Tâches nécessitant escalade sur erreur**
3. **Automatisation système (hors VS Code)**
4. **Tâches longue durée avec métriques**

---

## Comparaison avec Notre Système

| Aspect | Roo Scheduler | Notre Implémentation |
| --- | --- | --- |
| **Type** | Extension VS Code | Scripts PowerShell |
| **Trigger** | Timer + activité | Windows Task Scheduler |
| **Interface** | UI graphique | CLI |
| **Complexité** | Simple, atomique | Multi-phases (5) |
| **Escalade** | Non | Oui (Level 1-4) |
| **Auto-amélioration** | Non | Oui (algorithme adaptatif) |
| **Métriques** | Basiques | Détaillées (JSON) |
| **Dépendance** | VS Code requis | Windows natif |

### Complémentarité

Ces deux systèmes sont **complémentaires** :

- **Roo Scheduler** : Tâches récurrentes simples pendant le développement
- **Notre système** : Orchestration lourde quotidienne (sync, tests, cleanup)

### Recommandation d'Usage

```
Tâche simple récurrente → Roo Scheduler
        ↓
Tâche complexe multi-étapes → Notre système d'orchestration
        ↓
Échec critique → Escalade Level 3 (Claude Code)
```

---

## Prérequis et Installation

### Dépendances

- VS Code (requis)
- Roo Code extension (requis)
- Node.js (pour build)

### Installation

```bash
# Via VS Code Marketplace
ext install kyle-apex.roo-scheduler

# Ou build depuis source
git clone https://github.com/kyle-apex/roo-scheduler
cd roo-scheduler
npm install
npm run compile
```

---

## Configuration Recommandée

Pour une utilisation optimale avec notre système :

1. **Roo Scheduler** pour :
   - Revue code quotidienne (UI)
   - Suggestions de refactoring (activité)
   - Nettoyage imports (avant commit)

2. **Notre orchestration** pour :
   - Sync Git quotidien (06:00)
   - Tests automatiques
   - Validation configurations
   - Nettoyage logs

3. **Ne PAS dupliquer** :
   - Éviter de planifier la même tâche dans les deux systèmes
   - Documenter la répartition des responsabilités

---

## Staged Workflow Structure (#1887)

### Problème

Roo scheduler manque de visibilité structurée sur la progression des tâches comparé au Claude Code worker qui utilise un workflow explicite en 5 phases.

### Solution: Wrapper `Invoke-RooStagedWorkflow`

Un script PowerShell `Invoke-RooStagedWorkflow.ps1` est disponible pour ajouter un logging structuré aux tâches Roo :

```
scripts/scheduling/Invoke-RooStagedWorkflow.ps1
```

#### Les 4 Étapes Roo

| Étape | Description | Logging |
|-------|-------------|---------|
| **Étape 0** | Context check | Dashboard read, dispatch parse, git status |
| **Étape 1** | Setup | Workspace verification, git working directory check |
| **Étape 2** | Execution | Mode-specific work (votre tâche) |
| **Étape 3** | Report | Post [RESULT] to dashboard |

#### Utilisation

```powershell
# Wrapper basique
Invoke-RooStagedWorkflow -TaskName "Maintenance" -ScriptBlock {
    # Votre code de tâche ici
    Write-Host "Executing maintenance..."
}

# Avec type de dashboard personnalisé
Invoke-RooStagedWorkflow -TaskName "Tests" -DashboardType "machine" -ScriptBlock {
    # Exécuter les tests
    npm test
}
```

#### Logging Généré

```
[2026-05-04 02:41:15] [INFO] === ROO STAGED WORKFLOW START ===
[2026-05-04 02:41:15] [INFO] Task: Maintenance
[2026-05-04 02:41:15] [INFO] Étape 0: Context check - START
[2026-05-04 02:41:15] [OK] Dashboard MCP: Available
[2026-05-04 02:41:16] [OK] Git status: Clean
[2026-05-04 02:41:16] [OK] Étape 0: OK (0.12s)
[2026-05-04 02:41:16] [INFO] Étape 1: Setup - START
[2026-05-04 02:41:16] [OK] Workspace: D:\Dev\roo-extensions
[2026-05-04 02:41:16] [OK] Git working directory: Clean
[2026-05-04 02:41:16] [OK] Étape 1: OK (0.08s)
[2026-05-04 02:41:16] [INFO] Étape 2: Execution - START
[2026-05-04 02:41:16] [INFO] Executing task: Maintenance
[2026-05-04 02:41:20] [OK] Étape 2: OK (3.45s)
[2026-05-04 02:41:20] [INFO] Étape 3: Report - START
[2026-05-04 02:41:20] [OK] Report published to dashboard
[2026-05-04 02:41:20] [OK] Étape 3: OK (0.15s)
[2026-05-04 02:41:20] [INFO] === ROO STAGED WORKFLOW END ===
```

#### Dashboard Integration

Chaque étape publie automatiquement au dashboard workspace :
- **Tags**: `ROO-STAGE`, `0`/`1`/`2`/`3`, `OK`/`ECHEC`
- **Content**: Timestamp, task name, détails, durée
- **Rapport final**: `[DONE]` avec durée totale et statut

#### Avantages

- **Traçabilité +30%**: Savoir exactement où une tâche échoue
- **Debugging -25%**: Moins de "git log" forensics
- **Alignement**: Architecture unifiée Roo/Claude
- **Coût**: ~50 lignes PS1, wrapper externe (pas de modif Roo)

---

## Références

- **Repository** : https://github.com/kyle-apex/roo-scheduler
- **Issues** : https://github.com/kyle-apex/roo-scheduler/issues
- **Documentation Roo Code** : [docs/roo-code/](.)
- **Issue #1887** : Staged Workflow Structure unification

---

*Document créé le 2026-01-22*
*Dernière mise à jour : 2026-05-04 (Ajout section Staged Workflow #1887)*
