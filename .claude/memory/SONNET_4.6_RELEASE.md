# Claude Sonnet 4.6 - Release Notes et Configuration

**Date de sortie :** 2026-02-18
**Status :** NOUVEAU - À évaluer

---

## Informations

Claude Sonnet 4.6 est le nouveau modèle de la famille Claude, positionné entre Haiku et Opus.

**Caractéristiques attendues :**
- Plus rapide qu'Opus 4.6
- Plus intelligent qu'Haiku 4.5
- Bon compromis vitesse/intelligence
- Coût intermédiaire

---

## État actuel des configurations

### Configuration Roo (roo-config/model-configs.json)

**Modes simples :** `local-simple-tgwui` (GLM-4.7-Flash auto-hébergé via text-generation-webui)
- ~50 tok/sec solo, ~200 tok/sec batch
- ~220k KV cache
- Max 2-3 sessions simultanées

**Modes complexes :** `sddd-complex-glm5` (GLM-5 via z.ai)
- Modèle flagship "~Opus 4.6 level"
- Température: 0.7

### Machines confirmées

| Machine | Provider | Modèle simple | Modèle complexe |
|---------|----------|---------------|-----------------|
| myia-po-2026 | Local + z.ai | GLM-4.7-Flash (TGWUI) | GLM-5 (z.ai) ✅ |
| Autres | À vérifier | À vérifier | À vérifier |

### Fichiers de configuration

**Roo Code :**
- `roo-config/model-configs.json` ✅ **MAJ 2026-02-18** : Ajouté configs Sonnet 4.6
- `roo-config/modes/modes-config.json`

**Claude Code :**
- `.claude/settings.json` (workspace)
- `~/.claude/settings.json` (global)

---

## Configurations ajoutées (2026-02-18)

**Nouvelles apiConfigs dans model-configs.json :**

1. **`claude-sonnet-4.6`** (OpenRouter)
   - Provider: openrouter
   - Model: `anthropic/claude-sonnet-4.6`
   - Description: "Claude Sonnet 4.6 - Nouveau modèle 2026-02-18"

2. **`claude-sonnet-4.6-anthropic`** (API directe)
   - Provider: anthropic
   - Model: `claude-sonnet-4-20250514`
   - Description: "Claude Sonnet 4.6 via API Anthropic directe"

**Nouveau profil :**
- **"Configuration Sonnet 4.6 (NOUVEAU 2026-02-18)"** : local-simple (GLM-4.7-Flash) + Sonnet 4.6 pour les modes complexes

---

## Actions requises

1. **Vérifier les configurations actuelles** sur chaque machine
2. **Tester Sonnet 4.6** si disponible via Anthropic
3. **Comparer performances** vs GLM-5 et Opus 4.6
4. **Mettre à jour** si Sonnet 4.6 est meilleur compromis

---

## Notes de tests

(À remplir après tests)

---

**Référence :** Demande utilisateur du 2026-02-18
