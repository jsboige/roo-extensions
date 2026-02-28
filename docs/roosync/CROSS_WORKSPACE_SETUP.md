# Guide Cross-Workspace RooSync

**Créé:** 2026-03-01
**Issue:** #526
**Status:** Phases 1-3 validées, Phase 4 en cours

---

## Contexte

Extension de RooSync pour permettre la coordination multi-agent sur **plusieurs workspaces** d'une même machine.

**Format validé:** `machine:workspace` (ex: `myia-ai-01:2025-Epita-Intelligence-Symbolique`)

---

## Configuration d'un Nouveau Workspace

### Prérequis

- Git repository actif
- Configuration Roo (.roomodes ou .roo/)
- Potentiel de travail multi-agent (pas juste infra/backup)

### Étape 1 : Configuration RooSync (.roo/)

Créer `.roo/.env` :
```bash
# Configuration RooSync
ROOSYNC_MACHINE_ID=myia-ai-01  # Adapter selon la machine
ROOSYNC_SHARED_PATH=G:/Mon Drive/Synchronisation/RooSync/.shared-state

# Synchronisation automatique désactivée
ROOSYNC_AUTO_SYNC=false

# Configuration Embeddings (optionnel si codebase_search requis)
EMBEDDING_MODEL=qwen3-4b-awq-embedding
EMBEDDING_DIMENSIONS=2560
EMBEDDING_API_BASE_URL=https://embeddings.myia.io/v1
EMBEDDING_API_KEY=<secret>

# Configuration Qdrant (optionnel)
QDRANT_URL=https://qdrant.myia.io
QDRANT_API_KEY=<secret>
QDRANT_COLLECTION_NAME=roo_tasks_semantic_index
```

Modifier `.roo/mcp.json` :
```json
{
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": ["D:\\roo-extensions\\mcps\\internal\\servers\\roo-state-manager\\build\\index.js"],
      "env": {
        "ROOSYNC_MACHINE_ID": "myia-ai-01",
        "ROOSYNC_SHARED_PATH": "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
      }
    }
  }
}
```

**Important :** Préserver les MCPs existants (ex: `argumentation_analysis_mcp`).

### Étape 2 : Configuration Claude Code (.claude/)

Créer structure minimale :
```bash
mkdir -p .claude/local .claude/memory .claude/rules
```

Créer `.claude/.env` (copie de `.roo/.env`).

Créer `.claude/local/INTERCOM-{MACHINE_ID}.md` :
```markdown
# INTERCOM Local - {MACHINE_ID}:{WORKSPACE}

**Workspace:** {WORKSPACE_NAME}
**Machine:** {MACHINE_ID}
**Dernière MAJ:** {DATE}

---

## [{DATE}] system -> roo [INFO]
### Configuration RooSync Activée

Le workspace {WORKSPACE_NAME} est maintenant configuré pour RooSync.
```

Créer `.claude/memory/PROJECT_MEMORY.md` :
```markdown
# PROJECT_MEMORY - {WORKSPACE_NAME}

**Machine principale:** {MACHINE_ID}
**Dernière MAJ:** {DATE}

## Configuration RooSync

**Activé le:** {DATE} (issue #526)

**Workspaces liés :**
- roo-extensions (coordination)

**Utilisation RooSync :**
- Format destinataire: `{MACHINE_ID}:{WORKSPACE_NAME}`
- Communication locale: `.claude/local/INTERCOM-{MACHINE_ID}.md`
```

**Important :** Préserver les skills/commands/agents existants.

### Étape 3 : Test Cross-Workspace

Depuis le workspace `roo-extensions`, envoyer un message test :
```typescript
roosync_send(
  action: "send",
  to: "myia-ai-01:2025-Epita-Intelligence-Symbolique",
  subject: "[TEST] Configuration RooSync",
  body: "Test de communication cross-workspace.",
  priority: "MEDIUM"
)
```

Vérifier réception dans l'inbox du workspace cible.

---

## Workspaces Configurés (2026-03-01)

### myia-ai-01

| Workspace | Git | Roo | Claude | RooSync | Priorité |
|-----------|-----|-----|--------|---------|----------|
| roo-extensions | ✅ | ✅ | ✅ | ✅ ACTIF | - |
| 2025-Epita-Intelligence-Symbolique | ✅ | ✅ | ✅ | ✅ ACTIF | HIGH |
| semantic-fleet | ✅ | ✅ | ❌ | ⏸️ TODO | MEDIUM |
| 2025-Epita-Intelligence-Symbolique-4 | ✅ | ✅ | ❌ | ⏸️ TODO | MEDIUM |

### myia-po-2024

| Workspace | Git | Roo | Claude | RooSync | Note |
|-----------|-----|-----|--------|---------|------|
| roo-extensions | ✅ | ✅ | ✅ | ✅ ACTIF | Seul éligible |

### myia-web1

| Workspace | Git | Roo | Claude | RooSync | Note |
|-----------|-----|-----|--------|---------|------|
| roo-extensions | ✅ | ✅ | ✅ | ✅ ACTIF | Seul éligible |

**Autres machines (po-2023, po-2025, po-2026) :** Inventaire en cours.

---

## Phase 4 : Scheduling Cross-Workspace (TODO)

**Objectif :** Permettre au scheduler Roo de travailler sur plusieurs workspaces d'une même machine.

**Modifications requises :**

### Script `start-claude-worker.ps1`

```powershell
param(
    [string]$Workspace = "roo-extensions"  # Défaut
)

# Résoudre chemin absolu du workspace
$WorkspacePath = switch ($Workspace) {
    "roo-extensions" { "D:\roo-extensions" }
    "2025-Epita-Intelligence-Symbolique" { "D:\2025-Epita-Intelligence-Symbolique" }
    "semantic-fleet" { "D:\semantic-fleet" }
    default { throw "Workspace inconnu: $Workspace" }
}

# cd vers le workspace
Set-Location $WorkspacePath

# Lire INTERCOM du workspace cible
$IntercomPath = Join-Path $WorkspacePath ".claude\local\INTERCOM-$env:COMPUTERNAME.md"

# Lancer Claude avec contexte du workspace
# ... (reste du script)
```

### Scheduler `.roo/schedules.json`

Ajouter tâches cross-workspace :
```json
{
  "id": "cross-workspace-epita",
  "name": "Epita Symbolique Tasks",
  "workspace": "2025-Epita-Intelligence-Symbolique",
  "schedule": "0 */6 * * *",
  "enabled": true
}
```

**Status :** Différé pour coordination collective (issue #527 proposée).

---

## Troubleshooting

### Message cross-workspace non reçu

1. Vérifier `ROOSYNC_MACHINE_ID` identique dans .roo/.env et .claude/.env
2. Vérifier `ROOSYNC_SHARED_PATH` pointe vers Google Drive
3. Tester avec `roosync_read(mode: "inbox")` dans le workspace cible

### MCP roo-state-manager non disponible

1. Vérifier build : `cd mcps/internal/servers/roo-state-manager && npm run build`
2. Vérifier chemin dans `.roo/mcp.json` (absolu, backslashes sur Windows)
3. Redémarrer VS Code après modification

### Skills/commands écrasés

La configuration RooSync ne doit JAMAIS écraser les skills/commands existants. Créer uniquement la structure minimale (.env, INTERCOM, PROJECT_MEMORY).

---

## Références

- Issue #526 : https://github.com/jsboige/roo-extensions/issues/526
- Format message : `docs/roosync/ROOSYNC_PROTOCOL.md`
- MCPs : `.claude/MCP_SETUP.md`

---

**Dernière mise à jour :** 2026-03-01
**Contributeur :** myia-ai-01 (Claude Code Opus 4.6)
