# Claude Code Global Configuration Templates

Ce repertoire contient les templates de configuration Claude Code deployables globalement (`~/.claude/`).

## Structure

```
configs/
├── README.md                    # Ce fichier
├── user-global-claude.md        # Template pour ~/.claude/CLAUDE.md
├── agents/                      # Agents generiques (-> ~/.claude/agents/)
│   ├── code-explorer.md
│   ├── git-sync.md
│   ├── test-runner.md
│   └── workers/
│       ├── code-fixer.md
│       ├── doc-updater.md
│       └── test-investigator.md
├── skills/                      # Skills generiques (-> ~/.claude/skills/)
│   ├── validate/SKILL.md
│   ├── git-sync/SKILL.md
│   └── debrief/SKILL.md
└── commands/                    # Commands generiques (-> ~/.claude/commands/)
    ├── switch-provider.md
    └── debrief.md
```

## Deploiement

### Methode rapide (script)

```powershell
# Deployer TOUT vers ~/.claude/
powershell -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1

# Deployer un type specifique
powershell -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target agents
powershell -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target skills
powershell -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target commands
powershell -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target claude-md
```

### Methode manuelle

```powershell
# CLAUDE.md global
Copy-Item .claude/configs/user-global-claude.md $HOME/.claude/CLAUDE.md

# Agents
Copy-Item -Recurse .claude/configs/agents/* $HOME/.claude/agents/

# Skills
Copy-Item -Recurse .claude/configs/skills/* $HOME/.claude/skills/

# Commands
Copy-Item -Recurse .claude/configs/commands/* $HOME/.claude/commands/
```

## Hierarchie de priorite

Claude Code applique les configurations dans cet ordre (le plus specifique gagne) :

```
~/.claude/          (global - ces templates)
  └── overridden by
.claude/            (projet)
  └── overridden by
packages/X/.claude/ (sous-package)
```

Exemple : si `roo-extensions/.claude/skills/validate/SKILL.md` existe, il override
`~/.claude/skills/validate/SKILL.md` dans ce workspace uniquement.

## Workflow de mise a jour

1. **Modifier** le template dans `.claude/configs/`
2. **Commit + push** dans roo-extensions
3. Sur chaque machine : `git pull` puis relancer le script de deploiement
4. Les changements sont effectifs a la prochaine session Claude Code

## Agents generiques vs projet-specifiques

| Generique (configs/) | Projet-specifique (.claude/agents/) |
|-----------------------|--------------------------------------|
| code-fixer | roosync-hub |
| test-investigator | dispatch-manager |
| test-runner | roosync-reporter |
| code-explorer | task-worker |
| git-sync | consolidation-worker |
| doc-updater | intercom-handler |

Les agents generiques fonctionnent dans n'importe quel workspace.
Les agents projet-specifiques referent a la structure roo-extensions.
