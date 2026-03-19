# Règles de Condensation - Contextes GLM

**Version:** 2.3.0
**Créé:** 2026-02-21
**Mis à jour:** 2026-03-18
**Issues:** #502 (boucle) + #555 (saturation) + #618 (harmonisation) + #736 (boucle po-2023) → **Solution: 80%**

---

## Problème

Les modèles GLM (Zhipu AI) annoncent **200k tokens** de contexte mais la réalité est **~131k tokens**.

**Cause :** Les 200k incluent les tokens de sortie. La taille réelle du contexte d'entrée est ~131k.

### Impact

- Seuil de condensation par défaut : **50%** de 200k = 100k tokens
- Avec INTERCOM à 800 lignes (~15k tokens) + harnais Roo
- Le seuil est atteint trop rapidement
- → **Boucle infinie de condensation**

---

## Solution : Seuils Corrigés

| Modèle | Contexte Réel | Seuil Recommandé | Justification |
|--------|---------------|------------------|---------------|
| **GLM-5** (z.ai) | 131k tokens | **80%** = ~105k | Marge 26k. 70% causait boucles avec harnais lourd (#736) |
| **GLM-4.7** (z.ai) | 131k tokens | **80%** = ~105k | Idem |
| **GLM-4.7 Flash** (auto-hébergé) | 131k tokens | **80%** = ~105k | Idem |
| **GLM-4.5 Air** (z.ai) | 131k tokens | **80%** = ~105k | Idem |

---

## Configuration Claude Code (settings.json)

**Chemin :** `c:\Users\{user}\.claude\settings.json`

**Pour z.ai (GLM) :**
```json
{
  "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
}
```

**Pour Anthropic :**
- Ne PAS définir cette variable (défaut fonctionne, dépend du modèle)

**⚠️ NE JAMAIS utiliser 50%** → Boucle de condensation infinie !
**⚠️ 70% insuffisant** avec harnais lourd (~65K tokens) → Boucle sur po-2023 (#736)

---

## Configuration Roo (via UI)

**Chemin :** Settings → Context Management → Auto-condensation

**Recommandation :**
```
Seuil de déclenchement : 80%
```

**Pourquoi 80% ?**
- 50% de 200k = 100k → Boucle infinie (#502)
- 70% de 200k = 140k → Boucle avec harnais lourd (#736, po-2023)
- **80% de 200k = 160k** → **Compaction à ~105k réels, marge 26k**
- 90% → Trop haut, risque saturation avant compaction

**Note :** Avec la réduction du harnais auto-chargé (24→10 rules, ~65K→~35K tokens), 80% offre un bon compromis entre marge utile et prévention des boucles.

---

## Actions Requises

### 1. Documenter dans Roo (si possible)

Si Roo permet de configurer `contextWindow` par modèle :
```json
{
  "glm-5": { "contextWindow": 131000 },
  "glm-4.7": { "contextWindow": 131000 },
  "glm-4.7-flash": { "contextWindow": 131000 },
  "glm-4.5-air": { "contextWindow": 131000 }
}
```

### 2. Configurer le seuil dans Roo UI

1. Ouvrir les paramètres Roo (icon gear)
2. Aller dans "Context Management"
3. Trouver "Auto-condensation"
4. Régler "Seuil de déclenchement" à **70%**
5. Sauvegarder

### 3. Vérifier que la boucle s'arrête

Après configuration :
- Exécuter une tâche scheduler
- Vérifier que l'INTERCOM ne boucle plus
- Si problème persiste : augmenter à 80%

---

## Références

- **Issue #502 :** Boucle infinie condensation Roo
- **Source communauté :** La taille réelle GLM est ~131k (200k inclut output)
- **Test manuel :** Seuil 80% validé sur myia-po-2023 (fin de boucle)

---

**Dernière mise à jour :** 2026-03-09
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
