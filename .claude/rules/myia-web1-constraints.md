# Règles MyIA-Web1 - Contraintes Spécifiques

**Machine:** MyIA-Web1
**RAM:** 16GB (vérifié 2026-03-05, ancienne doc erronée)
**OS:** Windows Server 2019
**Rôle:** Agent exécutant (pas coordinateur)

---

## Contraintes Critiques

### Gestion Mémoire

**État réel (2026-03-05):** 16GB RAM totale, ~8GB disponibles.

**Consommation typique:**
- VS Code (20 processus): ~3.2 GB
- Claude (2 agents): ~1.2 GB
- IIS w3wp (2 workers): ~537 MB
- SQL Server: ~468 MB
- Node.js (12 processus): ~800 MB

**Solution TOUJOURS appliquer pour tests:**

```bash
# Tests (recommandé avec maxWorkers=1 pour stabilité)
npx vitest run --maxWorkers=1

# Si échoue, ajouter --no-coverage
npx vitest run --reporter=verbose --no-coverage --maxWorkers=1

# JAMAIS npm test (bloque en mode watch)
```

**Note:** L'ancienne documentation indiquait 2GB - c'était une erreur. La machine a toujours eu 16GB.

---

## Configuration RooSync SINGULIÈRE

**Compte Google différent** des autres machines (jsboige@gmail.com vs compte perso).

**Path ROOSYNC_SHARED_PATH :**
```
C:\Drive\.shortcut-targets-by-id\1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB\.shared-state
```

**NE PAS utiliser :** `G:/Mon Drive/...` (n'existe pas sur cette machine)

---

## MCP win-cli (CRITIQUE depuis modes fix b91a841c)

**Depuis le commit `b91a841c`, win-cli est OBLIGATOIRE.** Les modes `code-simple` et `debug-simple` n'ont plus le groupe `command`. Sans win-cli, le scheduler Roo est totalement bloqué.

**Config correcte (fork local 0.2.0) :**
```json
"win-cli": {
  "command": "node",
  "args": ["{CHEMIN_ROO_EXTENSIONS}/mcps/external/win-cli/server/dist/index.js"],
  "transportType": "stdio",
  "disabled": false,
  "alwaysAllow": [
    "create_ssh_connection", "delete_ssh_connection", "execute_command",
    "get_active_terminal_cwd", "get_command_history", "get_current_directory",
    "read_ssh_connections", "ssh_disconnect", "ssh_execute", "update_ssh_connection"
  ]
}
```

**NE PAS utiliser** `npx @anthropic/win-cli` (npm 0.2.1 cassé).

**Vérification :** `manage_mcp_settings(action: "read")` → section win-cli doit pointer vers le fork local.

---

## Seuil de Condensation (CRITIQUE depuis #502)

**Problème :** Les modèles GLM annoncent 200k tokens mais la réalité est ~131k.

**Seuil CORRECT :** **80%** minimum (pas 50%)

**Si < 80% :** Risque de boucle infinie de condensation quand l'INTERCOM grossit.

**Documentation complète :** [`.claude/rules/condensation-thresholds.md`](condensation-thresholds.md)

---

## MCPs Indisponibles

| MCP | Statut | Alternative |
|-----|--------|------------|
| jupyter-mcp | disabled (historique) | Script externe |
| github-projects-mcp | Déprécié | `gh` CLI |

---

## Capacités Réelles

**IMPORTANT :** La charge LLM (Opus 4.6) est sur le provider z.ai, PAS local.

**✅ JE PEUX FAIRE :**
- **Investigation code** : Read, Grep, Glob, codebase_search
- **Écriture code** : Edit, Write
- **Git operations** : add, commit, push
- **Tests ciblés** : `npx vitest run --maxWorkers=1` → Fonctionne (99.6% pass)
- **Implémentation features** : Logique métier, refactoring
- **Bug fixes** : Investigation + correction
- **Architecture** : Analyse, design

**⚠️ ATTENTION :**
- Tests complets SANS --maxWorkers → Peut ralentir VS Code
- Build TypeScript complet → Peut être long (préférer build incrémental)

**PRÉFÉRENCES DE TÂCHES :**
1. Investigation + implémentation (code, architecture, bugs)
2. Features substantielles (pas juste doc/mise à jour)
3. Analyse architecture (split roo-state-manager, worktrees, etc.)

**À DÉLÉGUER :**
- Tâches de pure documentation (si machine plus disponible)
- Reporting répétitif (automatiser si possible)

---

## Provider z.ai

**Modèles disponibles :**
- `opus` → GLM-5 (flagship)
- `sonnet` → GLM-4.7 (balanced)
- `haiku` → GLM-4.5-Air (fast)

**Endpoint :** `https://api.z.ai/api/anthropic`

---

## Communication Locale

**INTERCOM :** `.claude/local/INTERCOM-myia-web1.md`

**Règle :** TOUJOURS vérifier INTERCOM au démarrage de session pour messages de Roo.

---

**Dernière mise à jour :** 2026-03-05 (correction RAM 2GB → 16GB)
