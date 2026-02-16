# 🚀 Roo Extensions - Écosystème Multi-Agent de Développement Intelligent

**Version** : 2.3.0
**Statut** : ✅ **Production Ready**
**Dernière mise à jour** : 16 février 2026
**GitHub Project** : [RooSync Multi-Agent Tasks #67](https://github.com/users/jsboige/projects/67)

---

## 🎯 Vue d'Ensemble

Roo Extensions est un **système multi-agent coordonné** qui orchestre Roo (assistant VS Code) et Claude Code sur **6 machines** en parallèle. Ce dépôt centralise des **modes personnalisés**, des **serveurs MCP** (39 outils RooSync), un **scheduler automatique Roo**, et un **protocole de coordination RooSync**.

### 🏆 Réalisations Principales

- ✅ **6 machines actives** : Coordination bicéphale Roo + Claude Code
- ✅ **18 MCPs fonctionnels** : 7 internes + 11 externes
- ✅ **RooSync v2.3** : Messagerie inter-machines + baseline-driven sync
- ✅ **39 outils MCP RooSync** : Consolidés via CONS-1 à CONS-13
- ✅ **Scheduler Roo automatique** : Exécution toutes les 3h avec escalade CLI
- ✅ **GitHub Projects #67** : 147/165 Done (89.1%)

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
├── 📁 mcps/                       # 18 MCPs fonctionnels
│   ├── internal/                   # 7 MCPs internes (submodule)
│   │   └── servers/
│   │       ├── roo-state-manager/   # 🎯 39 outils RooSync
│   │       ├── quickfiles/          # Manipulation fichiers batch
│   │       ├── jinavigator/         # Navigation web
│   │       ├── jupyter-mcp-server/  # Intégration Jupyter
│   │       ├── jupyter-papermill/   # Notebooks Papermill
│   │       ├── sk-agent/            # 🆕 Proxy LLM multi-modèles
│   │       └── github-projects-mcp/ # ⚠️ DÉPRÉCIÉ → utiliser gh CLI
│   └── external/                   # 11 MCPs externes
│       ├── win-cli/                # Commandes Windows
│       ├── desktop-commander/      # 🆕 Remplacement win-cli (pilote)
│       ├── playwright/             # Browser automation
│       ├── markitdown/             # Conversion documents
│       └── ... (autres)
├── 📁 roo-config/                 # Configuration centralisée
│   ├── settings/                   # Paramètres globaux Roo
│   ├── modes/                      # 10 modes (5 familles × 2 niveaux)
│   └── scheduler/                  # Scripts scheduler Roo
├── 📁 .claude/                     # Configuration Claude Code
│   ├── agents/                     # Subagents spécialisés
│   ├── skills/                     # Skills auto-invoqués
│   ├── commands/                   # Slash commands
│   ├── rules/                      # Règles projet
│   └── local/INTERCOM-*.md         # Communication locale Roo
├── 📁 docs/                        # Documentation technique
│   ├── architecture/               # Spécifications techniques
│   ├── guides/                     # Guides d'utilisation
│   └── roosync/                    # Documentation RooSync v2.3
├── 📁 scripts/                     # Scripts utilitaires
├── 📁 tests/                       # 3294 tests automatisés
└── 📄 CLAUDE.md                    # Guide agent Claude Code
```

### MCPs Internes (7)

| Serveur | Outils | Statut |
|---------|--------|--------|
| roo-state-manager | 39 | ✅ Actif |
| quickfiles | 4 | ✅ Actif |
| jinavigator | 3 | ✅ Actif |
| jupyter-mcp-server | 8 | ✅ Actif |
| jupyter-papermill | 2 | ✅ Actif |
| sk-agent | 3 | 🆕 Nouveau |
| github-projects-mcp | 57 | ⚠️ Déprécié → `gh` CLI |

---

## 🎯 Composants Principaux

### 1. 🤖 Serveurs MCP (Model Context Protocol)

**18 MCPs (7 internes + 11 externes)** :

#### 🔴 Internes (Tier 1)
1. **roo-state-manager** : 39 outils RooSync (messagerie, tâches, export, search)
2. **quickfiles** : Manipulation fichiers batch
3. **jinavigator** : Navigation web et extraction Markdown
4. **jupyter-mcp-server** : Intégration notebooks Jupyter
5. **jupyter-papermill** : Exécution notebooks paramétrés
6. **sk-agent** : 🆕 Proxy LLM multi-modèles (Claude, GLM, etc.)

#### ⚠️ Déprécié
- **github-projects-mcp** : → Utiliser `gh` CLI (#368)

#### 🟡 Externes (Tier 3)
- **win-cli** / **desktop-commander** : Commandes shell
- **playwright** : Browser automation
- **markitdown** : Conversion documents (PDF, DOCX, etc.)
- **git**, **github**, **mcp-server-ftp**, etc.

**Documentation :** [`mcps/README.md`](mcps/README.md)

### 2. 🔄 RooSync v2.3 - Coordination Multi-Agent

**Architecture multi-machines** avec messagerie inter-machines :

#### Fonctionnalités Clés
- ✅ **6 machines coordonnées** : Roo + Claude Code en parallèle
- ✅ **Messagerie RooSync** : `roosync_send`, `roosync_read`, `roosync_manage`
- ✅ **39 outils MCP** : Consolidés via CONS-1 à CONS-13
- ✅ **INTERCOM local** : Communication Roo ↔ Claude Code
- ✅ **Baseline sync** : Config harmonisée entre machines

#### Workflow Principal
```
Scheduler (3h) → INTERCOM → Git Sync → Tasks → Rapport
```

**Documentation :** [`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`](docs/roosync/GUIDE-TECHNIQUE-v2.3.md)

### 3. 🎭 Modes Roo Personnalisés

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

### 4. 🤖 Agents et Skills Claude Code

#### Subagents Disponibles
- **git-sync** : Pull conservatif + résolution conflits
- **test-runner** : Build + tests unitaires
- **code-fixer** : Investigation et correction bugs
- **code-explorer** : Exploration codebase
- **doc-updater** : Mise à jour documentation

#### Skills Auto-Invoqués
- **sync-tour** : Tour de sync complet (8 phases)
- **validate** : CI local (build + tests)
- **git-sync** : Synchronisation Git

**Documentation :** [`.claude/agents/`](.claude/agents/)

---

## 📊 Métriques et Performance

### Infrastructure
- **6 machines actives** : Coordination 24/7
- **Scheduler Roo** : Toutes les 3h (staggered)
- **Build + Tests** : ~35s (3294 tests)

### MCPs
- **roo-state-manager** : 39 outils, <500ms réponse
- **Taux de réussite tests** : 99.6% (3294/3295)

### RooSync v2.3
- **Messagerie** : <1s latence inter-machines
- **Baseline sync** : 2-4s par machine
- **Fiabilité** : >99% succès

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

**Version actuelle** : 2.3.0
**Statut** : ✅ **Production Ready**
**Dernière mise à jour** : 16 février 2026
**GitHub Project** : [147/165 Done (89.1%)](https://github.com/users/jsboige/projects/67)

### Roadmap

- ✅ **v2.3** : RooSync v2.3 + Scheduler Roo + 39 outils consolidés
- 🔄 **v2.4** : DesktopCommanderMCP migration + sk-agent déploiement
- 📋 **v2.5** : Worktrees + PRs workflow multi-agent
- 🔮 **v3.0** : Intelligence artificielle pour recommandations

---

**🚀 Prêt à transformer votre développement multi-machines avec Roo Extensions ?**

Consultez [`CLAUDE.md`](CLAUDE.md) pour le guide complet de l'agent Claude Code.