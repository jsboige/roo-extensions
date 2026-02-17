# Investigation sk-agent MCP - Problème identifié

**Date:** 2026-02-16 → 2026-02-17 (Résolu)
**Machine:** myia-ai-01 (coordinateur)
**Contexte:** Déploiement du MCP sk-agent v2.0 avec FastMCP

---

---

## ✅ RÉSOLU (2026-02-17)

**Le vrai problème :** Le fichier `sk_agent_config.json` n'existait pas.

**Cause :** Le dépôt a été mis à jour (commit c455c8c) pour supprimer `sk_agent_config.json` du git (protection des API keys) et fournir `sk_agent_config.template.json` à la place.

**Solution appliquée :**

1. ✅ Créé `sk_agent_config.json` à partir du template
2. ✅ Configuré avec les API keys de myia-ai-01
3. ✅ Désactivé les modèles locaux non disponibles (zwz-8b, glm-4.7-flash)
4. ✅ Retiré l'entrée self-inclusion MCP (causait des problèmes)
5. ✅ Ajouté `sk_agent_config.json` au `.gitignore`

**Résultat :**

- ✅ Serveur sk-agent **fonctionne correctement**
- ✅ **13 outils listés** : call_agent, list_agents, list_tools, end_conversation, install_libreoffice, run_conversation, list_conversations, ask, analyze_image, zoom_image, analyze_video, analyze_document, list_models
- ✅ **7 agents disponibles** : analyst, vision-analyst, researcher, synthesizer, optimist, devils-advocate, mediator
- ✅ **2 modèles activés** : glm-5, glm-4.6v

**Note sur le bug Claude Code :**

L'investigation avait initialement identifié un bug Claude Code (notifications/initialized), mais **ce n'était pas le vrai problème**. Le serveur fonctionne correctement quand le protocole est respecté.

---

## Investigation initiale (gardée pour référence)

**Date:** 2026-02-16

**Problème :** Le serveur MCP sk-agent ne charge pas les outils dans Claude Code.

**Tests effectués :**

### 1. Serveur testé manuellement → ✅ Fonctionne
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize",...}' | python sk_agent.py
# Réponse: OK, 13 outils listés
```

### 2. Recherche web → Bug connu de Claude Code

**Sources :**
- **[#9011] [BUG] `*/list` MCP requests sent before `notifications/initialized`** (GitHub anthropics/claude-code)
  - https://github.com/anthropics/claude-code/issues/9011
- **[#1604] Missing MCP Notifications/Initialized in Handshake Protocol** (GitHub anthropics/claude-code)
  - https://github.com/anthropics/claude-code/issues/1604
- **[#423] MCP SSE Server: Received request before initialization was complete** (GitHub modelcontextprotocol/python-sdk)

### 3. Protocole MCP correct

Selon la spécification MCP :
1. Client envoie `initialize` → Serveur répond avec capacités
2. **Client envoie `notifications/initialized`** ← **Claude Code ne le fait pas**
3. Client peut maintenant appeler `tools/list`, `resources/list`, etc.

### 4. Tests effectués

| Test | Résultat |
|------|----------|
| FastMCP + notification `initialized` | ✅ 13 outils listés |
| FastMCP SANS notification | ❌ Invalid request parameters |
| MCP SDK standard + notification | ✅ Fonctionne |
| MCP SDK standard SANS notification | ❌ Invalid request parameters |

**Conclusion :** Le problème n'est PAS FastMCP. Le MCP SDK standard a le même comportement. C'est **Claude Code qui ne respecte pas le protocole MCP**.

## FastMCP vs MCP SDK standard

Malgré le bug Claude Code, **FastMCP reste le meilleur choix** pour sk-agent :

| Aspect | FastMCP | MCP SDK standard |
|--------|---------|------------------|
| Déclaration outils | `@mcp_server.tool()` - **décorateur simple** | `@server.call_tool()`, validation manuelle |
| Validation Pydantic | ✅ **Automatique** avec types | ❌ Manuel |
| Description dynamique | ✅ Facile avec `_update_tool_descriptions()` | ❌ Complexe |
| Outils générés | 13 (call_agent, list_agents, etc.) | Plus complexe à implémenter |

## Corrections appliquées

1. **Retiré l'entrée self-inclusion MCP** (chemin invalide `path/to/sk_agent.py`)
2. **Ajouté lifespan hook** pour pré-charger la config (sans MCPs externes)

## État actuel

- ✅ Serveur sk-agent **fonctionne correctement** (testé manuellement)
- ✅ Configuration Claude Code correcte
- ❌ Outils non visibles **à cause du bug Claude Code**
- 🔄 **En attente** : Correction de Claude Code pour envoyer `notifications/initialized`

## Action requise

**Pour les autres machines :**
- Le déploiement sk-agent v2.0 peut continuer
- Les outils ne seront pas visibles tant que Claude Code n'est pas mis à jour
- En attendant, les agents peuvent utiliser sk-agent directement via `python sk_agent.py`

**Pour le coordinateur (myia-ai-01) :**
- Surveiller les mises à jour Claude Code
- Tester après chaque mise à jour
- Documenter la correction quand disponible

---

**Investigé par:** Claude Code (myia-ai-01)
**Sources web consultées:** GitHub Issues (anthropics/claude-code, modelcontextprotocol/python-sdk), Stack Overflow
