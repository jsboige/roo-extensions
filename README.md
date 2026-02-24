# 🚀 Roo Extensions - Écosystème Multi-Agent de Développement Intelligent

**Version** : 2.3.1
**Statut** : ✅ **Production Ready**
**Dernière mise à jour** : 24 février 2026
**GitHub Project** : [RooSync Multi-Agent Tasks #67](https://github.com/users/jsboige/projects/67)

---

## 🎯 Vue d'Ensemble

Roo Extensions est un **système multi-agent coordonné** qui orchestre Roo (assistant VS Code) et Claude Code sur **6 machines** en parallèle. Ce dépôt centralise des **modes personnalisés**, des **serveurs MCP** (36 outils RooSync), un **scheduler automatique Roo**, et un **protocole de coordination RooSync**.

### 🏆 Réalisations Principales

- ✅ **6 machines actives** : Coordination bicéphale Roo + Claude Code
- ✅ **6 MCPs déployés** : roo-state-manager, playwright, searxng, markitdown, win-cli, sk-agent
- ✅ **RooSync v2.3** : Messagerie inter-machines + baseline-driven sync
- ✅ **36 outils MCP RooSync** : Consolidés via CONS-1 à CONS-13
- ✅ **Scheduler Roo automatique** : Exécution toutes les 3h avec escalade CLI
- ✅ **GitHub Projects #67** : 172/184 Done (93.5%)
- ✅ **6811 tests unitaires** : 373 fichiers, CI GitHub Actions (Node 18+20)

---

## 🚀 Démarrage Rapide

### Prérequis

- **Roo** installé et configuré dans VS Code
- **Claude Code** CLI (optionnel, pour escalade Niveau 3)
- **PowerShell 7.2+** (recommandé pour scripts Windows)
- **Node.js 18+** (pour serveurs MCP)
- **Git 2.30+** (pour synchronisation et sous-modules)
- **Accès modèles** : Anthropic Claude ou z.ai GLM-5

### Installation en 4 Étapes

1. **Cloner le dépôt et initialiser les sous-modules :**
    ```bash
    git clone https://github.com/jsboige/roo-extensions.git
    cd roo-extensions
    git submodule update --init --recursive
    ```

2. **Déployer la configuration complète :**
    ```powershell
    # Déploiement global (CLAUDE.md + agents + skills)
    ./.claude/configs/scripts/Deploy-GlobalConfig.ps1

    # Déploiement des modes Roo
    node roo-config/scripts/generate-modes.js
    Copy-Item roo-config/modes/generated/simple-complex.roomodes .roomodes

    # Déploiement du scheduler Roo
    .\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy
    ```

3. **Installer et configurer les MCPs :**
    ```powershell
    # Installation des MCPs internes
    cd mcps/internal
    npm install
    npm run build
    # Submodule: mcps/internal pointe vers jsboige-mcp-servers
    ```

4. **Redémarrer VS Code** et activer les nouveaux modes et MCPs

### Protocol de Claim (Anti Double-Traitement)

Avant de travailler sur une tâche, **toujours la revendiquer** :

```bash
# 1. Commenter l'issue
gh issue comment {NUM} --repo jsboige/roo-extensions --body "🔒 Claimed by {MACHINE} (Claude Code)."

# 2. Mettre à jour Project #67
gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(...) }"
```

Voir [CLAUDE.md](CLAUDE.md) pour les IDs des champs Machine/Agent.

---

## 🏗️ Architecture Multi-Agent

### Machines du Système

| Machine | Rôle | MCPs |
|---------|------|------|
| **myia-ai-01** | Coordinateur | GitHub CLI + RooSync + roo-state-manager |
| **myia-po-2023** | Exécutant | GitHub CLI + RooSync |
| **myia-po-2024** | Exécutant | GitHub CLI + RooSync |
| **myia-po-2025** | Exécutant | GitHub CLI + RooSync |
| **myia-po-2026** | Exécutant | GitHub CLI + RooSync + DCMCP (pilote) |
| **myia-web1** | Exécutant | GitHub CLI + RooSync |

### Structure du Projet

```
roo-extensions/
├── 📁 .claude/                    # Configuration Claude Code agents
│   ├── agents/                    # 12 subagents spécialisés
│   ├── skills/                    # 6 skills auto-invoqués
│   ├── commands/                  # 4 slash commands
│   ├── rules/                     # 9 règles auto-chargées
│   └── local/                     # Communication locale (INTERCOM)
├── 📁 docs/                       # Documentation technique consolidée
│   ├── roosync/                   # Protocoles RooSync v2.3
│   ├── architecture/              # Designs et analyses
│   ├── guides/                    # Guides utilisateur
│   ├── scheduler/                 # Documentation scheduler (NOUVEAU)
│   └── framework-multi-agent/     # Templates coordination
├── 📁 mcps/internal/servers/
│   ├── roo-state-manager/         # 36 outils MCP (wrapper v4)
│   └── sk-agent/                  # 7 outils (Python FastMCP + Semantic Kernel)
├── 📁 roo-config/                 # Configuration centralisée
│   ├── modes/                     # 10 modes Roo (5 simple + 5 complex)
│   ├── scheduler/                 # Orchestration autonome (3h interval)
│   └── settings/                  # Paramètres globaux
├── 📁 scripts/                    # Utilitaires (sync-roo-alwaysallow.js, etc.)
└── 📄 CLAUDE.md                   # Guide principal agents
```

### MCPs Actifs (2026-02-20)

**6 serveurs MCP déployés sur 6 machines :**

| MCP | Outils | Description |
|-----|--------|-------------|
| **roo-state-manager** | 36 | Messaging RooSync, config sync, task browsing, semantic search |
| **sk-agent** | 7 | Agents IA (Semantic Kernel) : analyst, researcher, critic, etc. |
| **playwright** | 20 | Browser automation, screenshots, form filling |
| **markitdown** | 1 | Conversion documents (PDF, DOCX, XLSX) → Markdown |
| **win-cli** | 7+ | Windows CLI, SSH, commandes shell (fork local 0.2.0) |
| **searxng** | 2 | Recherche web sémantique |

**GitHub CLI (gh)** - Remplace github-projects-mcp (#368). Issues, PRs, Projects via command line.

**Documentation complète :** [`mcps/README.md`](mcps/README.md)

---

## 🎯 Composants Principaux

### 1. 🔄 RooSync v2.3 - Coordination Multi-Machines

**Architecture :** 6 machines coordonnées (1 coordinateur + 5 exécutants)

#### Fonctionnalités Clés

- ✅ **Messagerie inter-machines** : roosync_send, roosync_read, roosync_manage (CONS-1)
- ✅ **Configuration sync** : collect, publish, apply, compare (CONS-2/3/4)
- ✅ **Inventory automatique** : Détection système complète (6 machines)
- ✅ **Scheduler Roo** : Orchestration autonome (3h interval, modes simple/complex)
- ✅ **35 outils MCP** : Wrapper v4 pass-through (tasks, search, export, diagnostic)

#### Workflow Principal
```
Collect → Publish → Compare → Validate → Apply
```

#### Modes Coordination

- **Bicéphale** : Roo (technique) + Claude Code (coordination/documentation)
- **Autonomie** : Niveau 1 (simple tasks) → Niveau 2+ (complex tasks, en cours)
- **Communication** : RooSync (inter-machines), INTERCOM (locale Roo ↔ Claude)

**Documentation complète :** [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md)

### 2. 🎭 Modes Roo Personnalisés

#### Architecture à 2 Niveaux

- **Modes Simples** : Tâches courantes (GLM-5 gratuit)
- **Modes Complexes** : Tâches avancées (GLM-5 + escalade CLI)

#### 5 Familles de Modes

- **Code** : Développement et refactoring
- **Debug** : Diagnostic et résolution problèmes
- **Architect** : Conception et architecture
- **Ask** : Questions et recherche
- **Orchestrator** : Coordination et délégation

#### Escalade Automatique
```
-simple → -complex → claude -p (CLI)
```

**Documentation :** [`.claude/ESCALATION_MECHANISM.md`](.claude/ESCALATION_MECHANISM.md)

### 3. 🤖 Agents et Skills Claude Code

#### 12 Subagents Disponibles

| Agent | Usage |
|-------|-------|
| **git-sync** | Pull conservatif + résolution conflits |
| **test-runner** | Build + tests unitaires |
| **code-fixer** | Investigation et correction bugs |
| **code-explorer** | Exploration codebase |
| **doc-updater** | Mise à jour documentation |
| **test-investigator** | Investigation tests échoués/instables |
| **roosync-hub** | Hub central messages RooSync (coordinateur) |
| **dispatch-manager** | Assignation tâches aux machines (coordinateur) |
| **task-planner** | Planification multi-agent (coordinateur) |
| **roosync-reporter** | Rapports au coordinateur (exécutant) |
| **task-worker** | Exécution tâches assignées (exécutant) |
| **consolidation-worker** | Consolidations CONS-X (spécialisé) |

#### 6 Skills Auto-Invoqués

- **sync-tour** : Tour de sync complet (9 phases)
- **validate** : CI local (build + tests)
- **git-sync** : Synchronisation Git
- **github-status** : État Project #67
- **redistribute-memory** : Audit et redistribution mémoire
- **debrief** : Analyse session + capture leçons

**Documentation :** [`.claude/agents/`](.claude/agents/) et [`.claude/skills/`](.claude/skills/)

---

## 📊 Métriques et Performance

### Infrastructure
- **6 machines actives** : Coordination 24/7
- **Scheduler Roo** : Toutes les 3h (staggered par machine)
- **CI GitHub Actions** : Node 18+20 sur ubuntu-latest
- **Build + Tests** : ~56s (6811 tests, 373 fichiers)

### MCPs
- **roo-state-manager** : 36 outils, <500ms réponse
- **sk-agent** : 11 agents IA, 4 conversations, 4 modèles
- **Taux de réussite tests** : 100% (6811/6811)

### RooSync v2.3
- **Messagerie** : <1s latence inter-machines (GDrive partagé)
- **Baseline sync** : 2-4s par machine
- **Qdrant** : 20 collections, 212K+ vecteurs (2560 dims)

---

## 🚀 Guides Démarrage Rapide

### Installation Complète pour Nouveaux Utilisateurs

```powershell
# 1. Cloner et initialiser
git clone https://github.com/jsboige/roo-extensions.git
cd roo-extensions
git submodule update --init --recursive

# 2. Déployer configuration globale (Claude Code)
./.claude/configs/scripts/Deploy-GlobalConfig.ps1

# 3. Déployer modes Roo + scheduler
node roo-config/scripts/generate-modes.js
Copy-Item roo-config/modes/generated/simple-complex.roomodes .roomodes
./roo-config/scheduler/scripts/install/deploy-scheduler.ps1 -Action deploy

# 4. Installer MCPs internes
cd mcps/internal && npm install && npm run build

# 5. Redémarrer VS Code
```

### Configuration MCP roo-state-manager

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": ["mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs"],
      "transportType": "stdio",
      "env": {
        "ROOSYNC_SHARED_PATH": "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
      }
    }
  }
}
```

---

## 📚 Documentation Complète

### Points d'Entrée Principaux

- **Guide Agent Claude Code** : [`CLAUDE.md`](CLAUDE.md)
- **Architecture Multi-Agent** : [`.claude/INDEX.md`](.claude/INDEX.md)
- **Serveurs MCP** : [`mcps/README.md`](mcps/README.md)
- **Escalade Roo** : [`.claude/ESCALATION_MECHANISM.md`](.claude/ESCALATION_MECHANISM.md)

### Documentation RooSync v2.3

- **Guide Technique** : [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md)
- **Protocole INTERCOM** : [`.claude/INTERCOM_PROTOCOL.md`](.claude/INTERCOM_PROTOCOL.md)

### Guides Techniques

- **Dépannage MCP** : [`docs/guides/TROUBLESHOOTING-GUIDE.md`](docs/guides/TROUBLESHOOTING-GUIDE.md)
- **Encodage UTF-8** : [`docs/encoding/quick-start-encoding.md`](docs/encoding/quick-start-encoding.md)

---

## 🛠️ Dépannage et Support

### Problèmes Courants

1. **MCPs ne démarrent pas**

   - Vérifier installation Node.js 18+
   - Exécuter `npm install && npm run build` dans `mcps/internal`
   - Redémarrer VS Code (les MCPs sont chargés au démarrage uniquement)

2. **Outils MCP non disponibles**

   - Vérifier `~/.claude.json` → section `mcpServers`
   - Tester le serveur : `node mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs`
   - Consulter [`docs/guides/TROUBLESHOOTING-GUIDE.md`](docs/guides/TROUBLESHOOTING-GUIDE.md)

3. **Scheduler Roo ne s'exécute pas**

   - Vérifier `.roo/schedules.json` existe
   - Extension Roo Scheduler installée ?
   - Voir les traces : `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\`

4. **Modes non disponibles**

   - Vérifier `.roomodes` existe à la racine
   - Régénérer : `node roo-config/scripts/generate-modes.js`

### Support Technique

- **Documentation** : [`CLAUDE.md`](CLAUDE.md) + [`docs/`](docs/)
- **Issues GitHub** : [github.com/jsboige/roo-extensions/issues](https://github.com/jsboige/roo-extensions/issues)

---

## 🤝 Contribution

### Workflow de Contribution

1. **Claimer l'issue** : `gh issue comment {NUM} --body "🔒 Claimed by {MACHINE}"`
2. **Créer une branche** pour vos modifications
3. **Tester** : `npx vitest run` (JAMAIS `npm test`)
4. **Documenter** dans `docs/` si changement significatif
5. **Soumettre une PR** avec description complète

### Règles Importantes

- **Toujours lire un fichier avant de le modifier** (Edit tool l'exige)
- **Utiliser `npx vitest run`** pour les tests (pas `npm test`)
- **Commit submodule en premier** : `mcps/internal` est un submodule git
- **Ne jamais utiliser `--force`** sur les branches partagées

---

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

---

## 🎯 Statut du Projet

**Version actuelle** : 2.3.1
**Statut** : ✅ **Production Ready**
**Dernière mise à jour** : 20 février 2026
**GitHub Project** : [172/184 Done (93.5%)](https://github.com/users/jsboige/projects/67)

### Accomplissements v2.3

- ✅ **Architecture multi-agent** : 6 machines coordonnées (1 coordinateur + 5 exécutants)
- ✅ **Scheduler Roo** : Orchestration autonome (3h interval, modes simple/complex, escalade)
- ✅ **Wrapper MCP v4** : 36 outils roo-state-manager exposés (pass-through)
- ✅ **CI Pipeline** : GitHub Actions (Node 18+20, ubuntu-latest)
- ✅ **Tests robustes** : 6811 PASS sur 373 fichiers
- ✅ **sk-agent** : 11 agents IA via FastMCP + Semantic Kernel
- ✅ **codebase_search** : Recherche sémantique dans le code (Qdrant + embeddings)
- ✅ **Documentation consolidée** : 48→4 docs (-96% lignes, Phase 2 #470) + docs/scheduler/ (NOUVEAU)

### Roadmap

- **v2.4** : Autonomie Niveau 2 (tasks complex via scheduler + escalade Claude Code)
- **v2.5** : Adoption worktrees + PRs pour workflow multi-agent (#448)
- **v3.0** : Split roo-state-manager en modules indépendants (#454)

---

**🚀 Prêt à transformer votre développement multi-machines avec Roo Extensions ?**

Consultez [`CLAUDE.md`](CLAUDE.md) pour le guide complet de l'agent Claude Code.