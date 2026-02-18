# Règles MyIA-Web1 - Contraintes Spécifiques

**Machine:** MyIA-Web1
**RAM:** 2GB (contrainte critique)
**OS:** Windows Server 2019
**Rôle:** Agent exécutant (pas coordinateur)

---

## Contraintes Critiques

### RAM 2GB - JavaScript Heap Out of Memory

**Problème:** Les tests unitaires et build TypeScript échouent avec "FATAL ERROR: JavaScript heap out of memory" sur cette machine.

**Solution TOUJOURS appliquer :**

```bash
# Tests (TOUJOURS avec maxWorkers=1)
npx vitest run --maxWorkers=1

# Si échoue encore, ajouter --no-coverage
npx vitest run --reporter=verbose --no-coverage --maxWorkers=1

# JAMAIS npm test (bloque en mode watch)
```

**Taux de succès attendu :** 3294/3308 PASS (99.6%)

---

## Configuration RooSync SINGULIÈRE

**Compte Google différent** des autres machines (jsboige@gmail.com vs compte perso).

**Path ROOSYNC_SHARED_PATH :**
```
C:\Drive\.shortcut-targets-by-id\1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB\.shared-state
```

**NE PAS utiliser :** `G:/Mon Drive/...` (n'existe pas sur cette machine)

---

## MCPs Indisponibles

| MCP | Statut | Alternative |
|-----|--------|------------|
| jupyter-mcp | N/A (2GB RAM) | Script externe |
| github-projects-mcp | Déprécié | `gh` CLI |

---

## Capacités Réelles (au-delà de la RAM)

**IMPORTANT :** La charge LLM (Opus 4.6) est sur le provider z.ai, PAS local.

**✅ JE PEUX FAIRE :**
- **Investigation code** : Read, Grep, Glob, codebase_search → Pas de consommation RAM locale
- **Écriture code** : Edit, Write → Pas de consommation RAM locale
- **Git operations** : add, commit, push → Pas de consommation RAM locale
- **Tests ciblés** : `npx vitest run --maxWorkers=1` → Fonctionne (99.6% pass)
- **Implémentation features** : Logique métier, refactoring → Pas de RAM
- **Bug fixes** : Investigation + correction → Pas de RAM
- **Architecture** : Analyse, design → CPU LLM, pas RAM locale

**❌ LIMITATIONS :**
- Tests complets SANS --maxWorkers → OOM (contourné avec --maxWorkers=1)
- Build TypeScript complet → Parfois OOM (build partiel possible)

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

**Dernière mise à jour :** 2026-02-18
