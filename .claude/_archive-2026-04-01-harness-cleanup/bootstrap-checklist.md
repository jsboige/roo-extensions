# Bootstrap Checklist - Nouvelle Machine RooSync

**Objectif :** Configuration complète d'une nouvelle machine dans l'écosystème RooSync multi-agent

**Durée estimée :** 30-45 minutes

---

## Prérequis

- [ ] Windows 10/11 avec PowerShell 7+
- [ ] Node.js 18+ installé
- [ ] Git configuré (SSH ou HTTPS)
- [ ] VS Code installé
- [ ] Accès Google Drive partagé (RooSync)

---

## Phase 1 : Clone & Build (10 min)

### 1.1 Clone repository

```bash
cd d:/dev  # ou autre répertoire de travail
git clone git@github.com:jsboige/roo-extensions.git
cd roo-extensions
```

### 1.2 Initialize submodules

```bash
git submodule update --init --recursive
cd mcps/internal
git checkout main
cd ../..
```

### 1.3 Build MCP roo-state-manager

```bash
cd mcps/internal/servers/roo-state-manager
npm install
npm run build
cd ../../../..
```

### 1.4 Run tests

```bash
cd mcps/internal/servers/roo-state-manager
npx vitest run
# Vérifier : ~3200 tests passent (>95%)
cd ../../../..
```

---

## Phase 2 : Configuration GitHub (5 min)

### 2.1 Login GitHub CLI

```bash
gh auth login
# Choisir : GitHub.com, HTTPS, Login via browser
```

### 2.2 Ajouter scopes requis

```bash
# Vérifier scopes actuels
gh auth status

# Ajouter scope project (requis pour GitHub Projects)
gh auth refresh --hostname github.com -s project

# Vérifier scope ajouté
gh auth status
# Doit afficher : 'gist', 'project', 'read:org', 'repo', 'workflow'
```

### 2.3 Tester accès Project #67

```bash
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { title items(first: 5) { totalCount } } } }' --jq '.data.user.projectV2'
# Doit afficher : "RooSync Multi-Agent Tasks", totalCount: ~141
```

---

## Phase 3 : Configuration MCPs (10 min)

### 3.1 Vérifier ~/.claude.json

Ouvrir `C:\Users\{USERNAME}\.claude.json` (Windows) ou `~/.claude.json` (Linux/Mac).

Vérifier que `roo-state-manager` est configuré avec le wrapper :

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": [
        "D:/dev/roo-extensions/mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs"
      ],
      "disabled": false
    }
  }
}
```

### 3.2 Vérifier autres MCPs

MCPs recommandés pour toutes les machines :

- [ ] `markitdown` (conversion fichiers)
- [ ] `playwright` (automatisation web)
- [ ] `roo-state-manager` (RooSync)

### 3.3 Redémarrer VS Code

Fermer et rouvrir VS Code pour charger les MCPs.

### 3.4 Vérifier outils disponibles

Ouvrir Claude Code, vérifier que les outils MCP sont disponibles :

```
roosync_send, roosync_read, roosync_manage, roosync_inventory, etc.
```

---

## Phase 4 : Configuration Scheduler Roo (10 min)

### 4.1 Déployer schedules.json

```powershell
cd roo-extensions
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy
```

### 4.2 Vérifier configuration

```powershell
cat .roo\schedules.json
```

Vérifier :

- [ ] `machineId` : correct (nom de la machine en minuscules)
- [ ] `id` : unique (timestamp)
- [ ] `startMinute` : staggering correct (voir tableau ci-dessous)
- [ ] `active` : true
- [ ] Pas de `_template_note`

**Staggering recommandé :**

| Machine | startMinute | Raison |
|---------|-------------|--------|
| myia-ai-01 | 00 | Coordinateur en premier |
| myia-po-2023 | 30 | Alternance avec ai-01 |
| myia-po-2024 | 00 | Alternance avec po-2023 |
| myia-po-2025 | 30 | Alternance avec po-2024 |
| myia-po-2026 | 00 | Alternance avec po-2025 |
| myia-web1 | 30 | Alternance avec po-2026 |

### 4.3 Activer extension Roo Scheduler

1. Ouvrir VS Code
2. Extensions → Rechercher "Roo Scheduler" (kylehoskins.roo-scheduler)
3. Installer si nécessaire
4. Vérifier que le scheduler apparaît dans la barre latérale Roo

⚠️ **ATTENTION :** Après activation dans l'UI, le `startMinute` peut être réinitialisé à `00`. Vérifier et corriger si nécessaire.

### 4.4 Tester configuration

```powershell
.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action test
```

---

## Phase 5 : Premier Sync-Tour (10 min)

### 5.1 Créer INTERCOM local

Vérifier que `.claude/local/INTERCOM-{MACHINE}.md` existe :

```bash
ls .claude/local/
```

Si absent, créer :

```markdown
# INTERCOM - {MACHINE}

**Machine:** {MACHINE}
**Purpose:** Local Claude Code <-> Roo agent communication
**Created:** {DATE}

---

## [{DATE} {TIME}] system -> all [INFO]

INTERCOM initialized on {MACHINE}.
Workspace: d:/dev/roo-extensions

---
```

### 5.2 Lancer premier sync-tour

Dans Claude Code :

```
Fais un tour de sync complet
```

Ou invoquer le skill :

```
/sync-tour
```

### 5.3 Vérifier résultats

- [ ] Phase 0 : INTERCOM lu
- [ ] Phase 1 : Messages RooSync lus (probablement 0 au premier run)
- [ ] Phase 2 : Git synchronisé
- [ ] Phase 3 : Tests passent (>95%)
- [ ] Phase 4 : GitHub accessible (scope project OK)
- [ ] Phase 5 : Aucune mise à jour nécessaire
- [ ] Phase 6 : Planification OK
- [ ] Phase 7 : Inventaire collecté et envoyé au coordinateur

---

## Phase 6 : Validation Finale (5 min)

### 6.1 Collecter inventaire

```
roosync_inventory type=machine machineId={MACHINE}
```

Vérifier output :

- [ ] MCPs actifs : 3+ (markitdown, playwright, roo-state-manager)
- [ ] Roo Modes : 12 modes
- [ ] Système : Windows/Linux détecté
- [ ] Chemins : Corrects

### 6.2 Envoyer rapport coordinateur

Dans Claude Code :

```
Envoie un message RooSync au coordinateur (myia-ai-01) pour annoncer que myia-{MACHINE} est opérationnelle.
```

### 6.3 Vérifier dashboard

Le coordinateur devrait régénérer le dashboard et voir la nouvelle machine.

---

## Checklist Finale

- [ ] **Git** : Clone + submodules initialisés
- [ ] **Build** : MCP roo-state-manager compilé et testé
- [ ] **GitHub** : CLI configuré avec scope `project`
- [ ] **MCPs** : roo-state-manager + autres MCPs actifs
- [ ] **Scheduler** : Déployé avec bon startMinute + actif
- [ ] **INTERCOM** : Fichier créé
- [ ] **Sync-tour** : Premier tour complété avec succès
- [ ] **Inventaire** : Collecté et envoyé au coordinateur
- [ ] **Dashboard** : Machine visible dans le dashboard RooSync

---

## Troubleshooting

### Tests échouent (>5%)

```bash
cd mcps/internal/servers/roo-state-manager
npm run build
npx vitest run --reporter=verbose
```

Vérifier les erreurs spécifiques. Si problème de dépendances :

```bash
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Scope GitHub manquant

```bash
gh auth refresh --hostname github.com -s project
gh auth status  # Vérifier 'project' présent
```

### Scheduler ne s'active pas

1. Vérifier extension installée : `code --list-extensions | grep roo-scheduler`
2. Vérifier `.roo/schedules.json` syntaxe valide (JSON)
3. Redémarrer VS Code

### MCPs non chargés

1. Vérifier `~/.claude.json` syntaxe correcte
2. Vérifier chemins absolus (pas de `~` ou variables)
3. Redémarrer VS Code

---

**Dernière mise à jour :** 2026-02-11
**Version :** 1.0
**Maintenu par :** Claude Code (myia-ai-01)
