# Template Workspace - Framework Multi-Agent

**Version:** 1.0.0
**Source:** roo-extensions
**Date:** 2026-02-12

---

## 🎯 Objectif

Ce template permet de déployer le framework multi-agent (Claude Code + Roo Code) sur un nouveau workspace en **moins de 30 minutes**.

---

## 📋 Prérequis

| Outil | Version | Vérification |
|-------|---------|--------------|
| **VS Code** | Latest | `code --version` |
| **Claude Code** | Extension installée | Extensions UI |
| **Roo Code** | Extension installée | Extensions UI |
| **gh CLI** | ≥ 2.40 | `gh --version` |
| **Node.js** | ≥ 18 LTS | `node --version` |
| **PowerShell** | ≥ 7 | `$PSVersionTable.PSVersion` |

---

## 🚀 Installation Rapide

### Option 1: Script Automatisé (Recommandé)

```powershell
# Dans le nouveau workspace
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jsboige/roo-extensions/main/scripts/setup-workspace.ps1" -OutFile "setup-workspace.ps1"
.\setup-workspace.ps1 -ProjectName "MyProject" -Repo "username/repo"
```

### Option 2: Manuel

Copier les fichiers suivants depuis `roo-extensions/` :

```
.claude/
├── CLAUDE.md              # Adapter {{PROJECT_NAME}}
├── INTERCOM_PROTOCOL.md   # Copie directe
├── agents/                # git-sync, test-runner, code-explorer
├── skills/
│   ├── validate/
│   ├── git-sync/
│   └── github-status/
└── rules/
    ├── test-success-rates.md
    └── github-cli.md

.roo/
├── rules/                 # 01-general, 02-intercom, 03-mcp-usage
├── schedules.template.json
└── scheduler-workflow-executor.md

roo-config/
└── modes/                 # Copie complète
```

---

## ⚙️ Configuration Requise

### 1. Variables à Remplacer

Dans `.claude/CLAUDE.md` :

| Variable | Valeur | Exemple |
|----------|--------|---------|
| `{{PROJECT_NAME}}` | Nom du projet | `MyProject` |
| `{{REPO}}` | GitHub repo | `username/repo` |
| `{{MACHINE_ID}}` | ID machine | `my-machine` |

### 2. GitHub CLI

```bash
gh auth login
gh auth refresh -s project  # Pour GitHub Projects
```

### 3. Modes Roo

```powershell
cd roo-config/modes
node generate-modes.js
Copy-Item generated/simple-complex.roomodes ..\..\.roomodes
```

---

## ✅ Validation

Après installation, valider :

```powershell
# 1. Vérifier INTERCOM
Test-Path .claude/local/INTERCOM-*.md

# 2. Vérifier Roo
Test-Path .roo/rules/*.md
Test-Path .roomodes

# 3. Vérifier Modes
node roo-config/modes/generate-modes.js
```

---

## 🔧 Personnalisation

### Adapter le Scheduler

Éditer `.roo/scheduler-workflow-executor.md` :

- Changer les tâches spécifiques au projet
- Adapter les chemins de scripts
- Personnaliser l'intervalle (défaut: 180 minutes)

### Adapter INTERCOM

Le fichier `.claude/local/INTERCOM-{{MACHINE}}.md` est créé automatiquement avec le nom de la machine.

---

## 📚 Prochaines Étapes

1. **Créer une première tâche** via INTERCOM pour tester
2. **Exécuter le scheduler** une fois manuellement
3. **Valider la communication** Claude ↔ Roo via INTERCOM
4. **Personnaliser les skills** selon les besoins du projet

---

## 🆘 Support

Pour les problèmes :
- Voir [roo-extensions/.claude/TROUBLESHOOTING.md](https://github.com/jsboige/roo-extensions/blob/main/.claude/TROUBLESHOOTING.md)
- Issues GitHub: [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions/issues)

---

**Est-ce que ce template fonctionne pour vous ?**

- ⏱️ Temps de setup : ___ minutes
- ✅ Scheduler opérationnel : ___
- ✅ INTERCOM validé : ___
- 📝 Commentaires : ___
