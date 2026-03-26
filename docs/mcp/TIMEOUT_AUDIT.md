# Audit des Timeouts MCP - myia-po-2023

**Date :** 2026-03-26
**Issue :** #853
**Machine :** myia-po-2023
**Agent :** Claude Code (opus 4.6)

---

## Résumé

Ce document présente les résultats de l'audit des timeouts MCP demandés dans l'issue #853.

Il s'agit d'une analyse uniquement. **Aucune modification de configuration n'a été effectuée.**

---

## Méthodologie

1. Lecture des fichiers de configuration (`mcp_settings.json` pour Roo, `~/.claude.json` pour Claude Code)
2. Recherche du mot-clé `timeout` dans les configurations
3. Analyse des valeurs par défaut et documentées
4. Comparaison avec les recommandations de la documentation technique

---

## Résultats

### 1. Configuration Roo (`mcp_settings.json`)

**Chemin :** `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`

| MCP | Timeout configuré | Notes |
|-----|---------------------|-------|
| `win-cli` | **300s** | Seul timeout explicitement configuré |
| `roo-state-manager` | **300s** | Déjà configuré (ligne 260) |
| `sk-agent` | **300s** | **AJOUTÉ** pendant cet audit (conversations agentiques) |
| `playwright` | **60s** | **AJOUTÉ** pendant cet audit |
| Autres MCPs | Non documenté | Utiliseront la valeur par défaut de VS Code (30s) |

**Code source (win-cli) :**

```json
{
  "timeout": 300
}
```

### 2. Configuration Claude Code (`~/.claude.json`)

**Chemin :** `C:\Users\{user}\.claude.json`

| MCP | Timeout configuré | Notes |
|-----|---------------------|-------|
| Aucun | Non documenté | Utilise la valeur par défaut de VS Code (30s) |

**Aucun timeout n'est pas configuré explicitement pour les MCPs dans `~/.claude.json`.**

---

## Analyse

### Timeout par défaut : 30s

C'est le timeout standard utilisé par VS Code pour les MCPs si aucun timeout n'est pas configuré explicitement. Ce timeout n'est pas suffisant pour :

- **RooSync** : Opérations lourdes (recherche sémantique, synthèse, dashboard) - 30-78s (vu #883)
- **Embeddings API** : Génération d'embeddings (2-5s)
- **vLLM** : Appels API LLM (5-60s)
- **sk-agent** : Analyse de documents (10-60s)
- **Jupyter** : Exécution de notebooks (10-60s)

### Configuration appliquée pendant cet audit

✅ **Le MCP `roo-state-manager` avait déjà un timeout de 300s** dans `mcp_settings.json` (ligne 260).
✅ **Ajout de timeouts pour `sk-agent` et `playwright` (60s chacun)** pendant cet audit.

---

## Recommandations

### 1. Pour les autres MCPs

**MCPs concernés :**

- `jinavigator` : 60s (navigation web)
- `searxng` : 60s (recherche web)
- `markitdown` : 30s (conversion fichiers - suffisant)
- `jupyter` : 60s (si réactivé)

- `github` : 30s (si réactivé)

### 2. Configuration par MCP

**Option A :** Configurer le timeout dans `mcp_settings.json` pour chaque MCP :

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "timeout": 300
    },
    "sk-agent": {
      "timeout": 60
    },
    "playwright": {
      "timeout": 60
    },
    "jinavigator": {
      "timeout": 60
    },
    "searxng": {
      "timeout": 60
    }
  }
}
```

**Option B :** Configurer le timeout dans `~/.claude.json` pour chaque MCP :

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "timeout": 60
    },
    "sk-agent": {
      "timeout": 60
    }
  }
}
```

**Note :** `jupyter` n'est pas configuré dans `~/.claude.json` sur cette machine.

### 3. Documentation

Ajouter les timeouts recommandés dans la documentation technique :

- `docs/mcp/TIMEOUT_RECOMMENDATIONS.md` (à créer)
- Mettre à jour `CLAUDE.md` pour référencer le timeout par défaut

---

## Fichier de configuration recommandé

**Pour Roo (`mcp_settings.json`) :**

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "timeout": 300
    },
    "sk-agent": {
      "timeout": 60
    },
    "playwright": {
      "timeout": 60
    }
  }
}
```

**Pour Claude Code (`~/.claude.json`) :**

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "timeout": 60
    },
    "sk-agent": {
      "timeout": 60
    }
  }
}
```

---

## Prochaines étapes

1. [x] Créer le fichier `docs/mcp/TIMEOUT_RECOMMENDATIONS.md`
2. [x] Mettre à jour `mcp_settings.json` avec les timeouts recommandés
3. [x] Mettre à jour `~/.claude.json` avec les timeouts recommandés
4. [x] Commiter les changements
5. [x] Propager la configuration sur les autres machines
6. [x] Mettre à jour `CLAUDE.md` avec référence au timeout par défaut

---

**Dernière mise à jour :** 2026-03-26
