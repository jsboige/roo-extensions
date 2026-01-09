# MCP Bootstrap Report - myia-ai-01

**Date:** 2026-01-05
**Machine:** myia-ai-01 (Baseline Master / Coordinator)
**Status:** ✅ Configuration complète, en attente de test utilisateur

---

## 📋 Configuration MCP Actuelle

### Fichier de configuration

**Emplacement:** [`.claude/.mcp.json`](.claude/.mcp.json)

```json
{
  "mcpServers": {
    "github-projects-mcp": {
      "type": "stdio",
      "command": "node",
      "args": [
        "d:/roo-extensions/mcps/internal/servers/github-projects-mcp/dist/index.js"
      ],
      "cwd": "d:/roo-extensions/mcps/internal/servers/github-projects-mcp/"
    }
  }
}
```

### Composants vérifiés

| Composant | Chemin | Status |
|-----------|--------|--------|
| Configuration MCP | `.claude/.mcp.json` | ✅ Créé |
| Serveur MCP | `mcps/internal/servers/github-projects-mcp/dist/index.js` | ✅ Présent |
| Fichier .env | `mcps/internal/servers/github-projects-mcp/.env` | ✅ Présent |
| Documentation | `.claude/MCP_SETUP.md` | ✅ À jour |

---

## 🔐 Gestion des secrets

**Approche retenue :** Chargement automatique du `.env` par le MCP serveur

- ✅ Aucun token GitHub dans `.mcp.json`
- ✅ `.env` existant dans le répertoire du serveur MCP
- ✅ `cwd` configuré pour que le serveur trouve son `.env`
- ✅ Configuration safe pour le commit dans git

**Tokens GitHub configurés :**
- `GITHUB_TOKEN` (jsboige@gmail.com)
- `GITHUB_TOKEN_EPITA` (jsboigeEpita)
- `GITHUB_ACCOUNTS_JSON` (format JSON pour multi-comptes)

---

## 📚 Documentation créée

### Fichiers de configuration

1. **[`.claude/.mcp.json`](.claude/.mcp.json)** - Configuration MCP pour Claude Code
   - Format: stdio transport
   - Commit: `94071086`

2. **[`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md)** - Guide d'installation MCP
   - Instructions pour les 5 machines
   - Procédure de vérification
   - Dépannage de base

3. **[`.claude/INDEX.md`](.claude/INDEX.md)** - Cartographie documentation
   - Inventaire MCP complet (6 internes + 12 externes)
   - Point d'entrée unique

4. **[`.claude/MCP_ANALYSIS.md`](.claude/MCP_ANALYSIS.md)** - Analyse des capacités MCP
   - Tableaux comparatifs
   - Portabilité des MCPs

### Documentation de travail

5. **[`CLAUDE.md`](CLAUDE.md)** - Contexte workspace auto-chargé
   - Vue d'ensemble RooSync v2.3
   - Rôles et responsabilités
   - Inventaire des sous-modules
   - Instructions pour les autres machines

6. **[`.claude/CLAUDE_CODE_GUIDE.md`](.claude/CLAUDE_CODE_GUIDE.md)** - Guide pour agents
   - Bootstrap + SDDD
   - Phases 0-3 détaillées

---

## 🚀 Prochaines étapes

### Phase 1: Validation sur myia-ai-01 (IMMÉDIAT)

**Action requise de l'utilisateur :**

Tester les outils MCP après redémarrage VS Code :

```bash
# Dans Claude Code, tester :
/mcp

# Ou demander :
"Peux-tu lister les projets GitHub disponibles ?"
```

**Critères de succès :**
- [ ] Le MCP server démarre sans erreur
- [ ] Les outils GitHub Projects sont disponibles
- [ ] Peut lister les projets GitHub
- [ ] Peut créer/mettre à jour des issues

**Si succès :** Créer issue GitHub de validation et passer à Phase 2
**Si échec :** Debug et corriger la configuration

---

### Phase 2: Déploiement multi-machine (APRÈS VALIDATION)

**Machines cibles :**
- myia-po-2023
- myia-po-2024
- myia-po-2026
- myia-web-01

**Procédure pour chaque machine :**

1. **Pull dernier changements :**
   ```bash
   git pull origin main
   ```

2. **Vérifier la configuration :**
   ```bash
   Test-Path "d:\roo-extensions\.claude\.mcp.json"
   ```

3. **Vérifier le serveur MCP :**
   ```bash
   Test-Path "d:\roo-extensions\mcps\internal\servers\github-projects-mcp\dist\index.js"
   ```

4. **Redémarrer VS Code**

5. **Créer issue GitHub :** `[CLAUDE-MACHINE] Bootstrap Complete - NOM_MACHINE`

---

### Phase 3: Documentation multi-agent (POST-DÉPLOIEMENT)

Créer issues GitHub pour :
- [ ] Test des capacités MCP réelles
- [ ] Documentation des outils disponibles
- [ ] Guide d'utilisation des outils MCP pour agents
- [ ] Bon pratiques de coordination via GitHub Projects

---

## 📊 Historique des commits

| Commit | Description | Date |
|--------|-------------|------|
| `94071086` | fix(claude-code): Correct MCP configuration to use stdio transport | 2026-01-05 |
| `049f18a9` | fix(claude-code): Change MCP port from 3001 to 3002 | 2026-01-05 |
| `43ca802d` | feat(claude-code): Add CLAUDE.md and MCP configuration | 2026-01-05 |

---

## 🔍 Points d'attention

### Configuration correcte

✅ **Format JSON :** Utilise `"type"` pas `"transport"`
✅ **Transport :** stdio (pas HTTP) pour github-projects-mcp
✅ **Chemin absolu :** `d:/roo-extensions/...`
✅ **Working directory :** Configuré pour charger `.env` automatiquement

### Erreurs à éviter

❌ **Ne pas utiliser** `"transport": "http"` - format incorrect
❌ **Ne pas utiliser** `"disabled": false` - champ non supporté
❌ **Ne pas utiliser** `"envFile": ".env"` - pas supporté
❌ **Ne pas hardcoder** les tokens GitHub dans `.mcp.json`

---

## 📞 Support et coordination

**Canal principal :** Issues GitHub avec label `claude-code`

**Pour problèmes :**
1. Créer issue avec tag `claude-code` et `bug`
2. Inclure logs de VS Code (Output > Claude Code)
3. Inclure contenu de `.mcp.json` (sans tokens)

**Pour questions :**
1. Vérifier [`.claude/INDEX.md`](.claude/INDEX.md) - documentation map
2. Vérifier [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md) - setup guide
3. Créer issue avec tag `claude-code` et `question`

---

**Statut:** En attente de validation utilisateur avant déploiement multi-machine

**Dernière mise à jour:** 2026-01-05 13:47
