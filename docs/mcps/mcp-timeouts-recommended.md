# MCP Timeouts Recommandés

**Version:** 1.0.0
**Créé:** 2026-03-26
**Issue:** #853

---

## Vue d'ensemble

Ce document documente les timeouts recommandés pour chaque serveur MCP, basés sur leur comportement attendu et leur domaine d'utilisation.

---

## Timeouts Recommandés

| MCP | Timeout | Rationale |
|-----|---------|-----------|
| **win-cli** | 300s (5 min) | Commandes shell peuvent prendre du temps (build, tests, git) |
| **roo-state-manager** | 300s (5 min) | Opérations complexes (recherche sémantique, conversation_browser) |
| **sk-agent** | 300s (5 min) | Appels LLM peuvent prendre du temps (30s-2min) |
| **playwright** | 60s (1 min) | Navigation web, généralement rapide mais peut être lent sur pages lourdes |
| **searxng** | 60s (1 min) | Recherche web externe, dépend du réseau |
| **jinavigator** | 60s (1 min) | Conversion web → Markdown, dépend du réseau |
| **markitdown** | 60s (1 min) | Conversion de fichiers, peut être lent sur gros documents |
| **jupyter** | 300s (5 min) | Exécution de notebooks peut prendre du temps |

---

## Timeouts par défaut (30s)

Les MCP suivants n'ont PAS de timeout explicite et utilisent le défaut de 30s :

- **Aucun** - Tous les MCP critiques ont maintenant un timeout explicite

---

## Configuration Actuelle (myia-po-2023)

```json
{
  "win-cli": {
    "timeout": 300
  },
  "roo-state-manager": {
    "timeout": 300
  },
  "sk-agent": {
    "timeout": 300
  },
  "playwright": {
    "timeout": 60
  },
  "searxng": {
    "timeout": 60
  },
  "jinavigator": {
    "timeout": 60
  },
  "markitdown": {
    "timeout": 60
  }
}
```

---

## Actions Requises

1. **Vérifier sur toutes les machines** que les timeouts sont cohérents
2. **Surveiller** les timeouts dans les logs pour ajuster si nécessaire

---

## Références

- Issue #853: [FRICTION] Timeout MCP - Les serveurs MCP ne répondent pas après 30s
- `.claude/rules/tool-availability.md`: Inventaire des MCPs attendus

---

**Dernière mise à jour:** 2026-03-26
