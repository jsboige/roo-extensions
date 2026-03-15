# Configuration MCP par Machine - Référence

**Issue :** #688 - Harmoniser configuration MCP win-cli
**Dernière mise à jour :** 2026-03-15
**Documentation complète :** [docs/mcps/INDEX.md](mcps/INDEX.md)

---

## Principe : Claude Code vs Roo ont des configs séparées

| Agent | Fichier de config | Chemin |
|-------|-------------------|--------|
| **Roo** | `mcp_settings.json` | `%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/` |
| **Claude Code** | `~/.claude.json` | `C:/Users/{user}/.claude.json` |

**Ces deux fichiers sont INDÉPENDANTS.** Un MCP peut être actif pour Roo mais absent de Claude Code, et vice-versa.

---

## MCPs par Agent (Référence Actuelle)

### Claude Code (`~/.claude.json`)

| MCP | Statut | Notes |
|-----|--------|-------|
| `roo-state-manager` | ✅ OBLIGATOIRE | 37 outils - coordination, grounding |
| `playwright` | ✅ Recommandé | Browser automation |
| `sk-agent` | ⚠️ Optionnel | Multi-agent LLM (si configuré) |
| `win-cli` | ❌ **RETIRÉ** (#658) | Claude utilise l'outil `Bash` natif |

### Roo (`mcp_settings.json`)

| MCP | Statut | Notes |
|-----|--------|-------|
| `win-cli` | ✅ OBLIGATOIRE | Shell pour modes -simple (depuis b91a841c) |
| `roo-state-manager` | ✅ OBLIGATOIRE | 37 outils |
| `playwright` | ✅ Actif | Browser automation |
| `markitdown` | ✅ Actif | Conversion documents |

---

## Configuration win-cli (Roo UNIQUEMENT)

### ⚠️ Version correcte : Fork local 0.2.0

```json
"win-cli": {
  "command": "node",
  "args": ["D:/Dev/roo-extensions/mcps/external/win-cli/server/dist/index.js"],
  "transportType": "stdio",
  "disabled": false,
  "alwaysAllow": [
    "execute_command",
    "get_command_history",
    "get_current_directory",
    "get_active_terminal_cwd",
    "create_ssh_connection",
    "delete_ssh_connection",
    "read_ssh_connections",
    "ssh_disconnect",
    "ssh_execute",
    "update_ssh_connection"
  ]
}
```

### ❌ Version incorrecte : NE PAS utiliser

```json
"win-cli": {
  "command": "npx",
  "args": ["-y", "@anthropic/win-cli"]
}
```

**Pourquoi :** La version npm 0.2.1 est cassée. Le fork local 0.2.0 dans `mcps/external/win-cli/server/` est la version fonctionnelle.

---

## Vérification par Machine

### Test win-cli (pour Roo)

```
# Dans Roo, en mode code-simple :
execute_command(shell="powershell", command="echo OK")
# Résultat attendu : "OK"
```

### Test Bash natif (pour Claude Code)

```bash
# Dans Claude Code :
echo OK
# Résultat attendu : "OK"
```

### Statut par machine (#658)

| Machine | win-cli retiré de Claude | win-cli Roo OK | Bash Claude OK |
|---------|--------------------------|----------------|----------------|
| myia-ai-01 | ⬜ | ⬜ | ⬜ |
| myia-po-2023 | ✅ | ✅ | ✅ |
| myia-po-2024 | ✅ | ⬜ | ⬜ |
| myia-po-2025 | ✅ | ✅ | ✅ |
| myia-po-2026 | ⬜ | ⬜ | ⬜ |
| myia-web1 | ⬜ | ⬜ | ⬜ |

---

## Configuration roo-state-manager (Claude Code)

```json
"roo-state-manager": {
  "command": "node",
  "args": ["D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs"],
  "cwd": "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/"
}
```

**Note :** Adapter le chemin selon l'installation locale. Le fichier `mcp-wrapper.cjs` est le point d'entrée correct (pas `build/index.js` directement).

---

## Pre-flight Check dans les Schedulers

Tous les schedulers Roo vérifient win-cli au démarrage :

```
# Étape 0 dans chaque workflow scheduler :
execute_command(shell="powershell", command="echo OK")
# Si échoue → STOP IMMEDIAT → écrire dans INTERCOM [CRITICAL]
```

**Références :**
- [`.roo/scheduler-workflow-executor.md`](../.roo/scheduler-workflow-executor.md) - lignes 153-169
- [`.roo/scheduler-workflow-coordinator.md`](../.roo/scheduler-workflow-coordinator.md) - lignes 44-57
- [`.roo/scheduler-workflow-meta-analyst.md`](../.roo/scheduler-workflow-meta-analyst.md) - lignes 27-35

---

## Références

- [docs/mcps/INDEX.md](mcps/INDEX.md) - Documentation complète de tous les MCPs
- [`.claude/MCP_SETUP.md`](../.claude/MCP_SETUP.md) - Installation initiale Claude Code
- [`.claude/rules/tool-availability.md`](../.claude/rules/tool-availability.md) - Protocole STOP & REPAIR
- [Issue #658](https://github.com/jsboige/roo-extensions/issues/658) - Retrait win-cli de Claude Code
