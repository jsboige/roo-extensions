# Règles de Condensation - Contextes GLM

**Version:** 2.0.0
**Créé:** 2026-02-21
**Mis à jour:** 2026-03-06
**Issues:** #502 (boucle Roo) + #555 (saturation GLM-5)

---

## Problèmes Identifiés

Deux problèmes **opposés** ont été identifiés :

| Issue | Problème | Seuil | Effet |
|-------|----------|-------|-------|
| **#502** | Boucle infinie condensation Roo | Trop BAS (50%) | Compaction trop fréquente |
| **#555** | Saturation contexte GLM-5 | Trop HAUT (80%+) | Compaction trop tardive |

**Solution unifiée : 70%** - Compromis optimal entre les deux extrêmes.

---

## Contexte Technique

Les modèles GLM (Zhipu AI via z.ai) annoncent **200k tokens** mais :
- **Contexte réel d'entrée :** ~131k tokens (200k inclut output)
- **Seuil 50% (trop bas)** : Compaction à ~65k → boucle infinie
- **Seuil 80%+ (trop haut)** : Compaction à ~105k+ → explosion contexte
- **Seuil 70% (optimal)** : Compaction à ~92k → marge de sécurité 40k

---

## Seuil Unifié : 70%

| Modèle | Contexte Réel | Seuil Recommandé | Tokens au déclenchement |
|--------|---------------|------------------|-------------------------|
| **GLM-5** (z.ai) | 131k | **70%** | ~92k |
| **GLM-4.7** (z.ai) | 131k | **70%** | ~92k |
| **GLM-4.7 Flash** (auto-hébergé) | 131k | **70%** | ~92k |
| **GLM-4.5 Air** (z.ai) | 131k | **70%** | ~92k |

---

## Configuration Claude Code (z.ai provider)

**Fichier :** `~/.claude/settings.json`

```json
{
    "env": {
        "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "70"
    }
}
```

**⚠️ Redémarrage VS Code OBLIGATOIRE après modification.**

---

## Configuration Roo

### Option 1 : Via RooSync (RECOMMANDÉ pour déploiement multi-machines)

**RooSync peut déployer automatiquement le seuil de condensation sur toutes les machines.**

```bash
# Sur la machine de référence (ai-01), collecter les settings
roosync_config(action: "collect", targets: ["settings"])

# Publier sur GDrive
roosync_config(action: "publish", version: "2.3.4", description: "Seuil condensation 70%")

# Sur les autres machines, appliquer
roosync_config(action: "apply", targets: ["settings"])
```

**Settings concernés :**
- `autoCondenseContext` - Activation/désactivation
- `autoCondenseContextPercent` - **Seuil de déclenchement (70%)**
- `condensingApiConfigId` - API config pour condensation

**⚠️ Redémarrage VS Code OBLIGATOIRE après application.**

### Option 2 : Via l'UI Roo

**Chemin :** Settings → Context Management → Auto-condensation

**Valeur recommandée :**
```
Seuil de déclenchement : 70%
```

---

## Pourquoi 70% ?

| Seuil | Effet | Problème |
|-------|-------|----------|
| 50% | Compaction à ~65k | **Trop tôt** → boucle infinie (#502) |
| 70% | Compaction à ~92k | **Optimal** → marge 40k |
| 80% | Compaction à ~105k | **Trop tard** → explosion (#555) |

---

## Références

- **Issue #502 :** Boucle infinie condensation Roo (CLOSED)
- **Issue #555 :** Saturation contexte GLM-5 (CLOSED)
- **Issue #580 :** META-ANALYSIS - Règles condensation Claude
- **Source communauté :** Contexte réel GLM ~131k (200k inclut output)

---

**Dernière mise à jour :** 2026-03-06
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
