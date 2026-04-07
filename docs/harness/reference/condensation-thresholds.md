# Règles de Condensation - Contextes GLM

**Version:** 3.0.0
**Créé:** 2026-02-21
**Mis à jour:** 2026-04-07
**Issues:** #502 (boucle) + #555 (saturation) + #618 (harmonisation) + #736 (boucle po-2023) → **Solution: 75%**

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
| **GLM-5** (z.ai) | 131k tokens | **75%** = ~98k | Marge 33k. Standard unifie Roo+Claude (#1152) |
| **GLM-4.7** (z.ai) | 131k tokens | **75%** = ~98k | Idem |
| **GLM-4.7 Flash** (auto-hébergé) | 131k tokens | **75%** = ~98k | Idem |
| **GLM-4.5 Air** (z.ai) | 131k tokens | **75%** = ~98k | Idem |

---

## Configuration Claude Code (settings.json)

**Chemin :** `c:\Users\{user}\.claude\settings.json`

**Pour z.ai (GLM) :**
```json
{
  "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "200000",
  "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75"
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
Seuil de déclenchement : 75%
```

**Pourquoi 75% ?**
- 50% de 200k = 100k → Boucle infinie (#502)
- 70% de 200k = 140k → Boucle avec harnais lourd (#736, po-2023)
- **75% de 200k = 150k** → **Compaction à ~98k réels, marge 33k**
- 80% de 200k = 160k → OK aussi mais marge plus faible (26k)
- 90% → Trop haut, risque saturation avant compaction

**Note :** Standard unifié Roo + Claude (#1152). Le harnais condensé v2.0+ (24→10 rules, ~65K→~35K tokens) rend 75% viable. Seuil validé sur toutes les machines.

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
4. Régler "Seuil de déclenchement" à **75%**
5. Sauvegarder

### 3. Vérifier que la boucle s'arrête

Après configuration :
- Exécuter une tâche scheduler
- Vérifier que l'INTERCOM ne boucle plus
- Si problème persiste : vérifier le harnais auto-chargé (trop lourd ?)

---

## Références

- **Issue #502 :** Boucle infinie condensation Roo
- **Source communauté :** La taille réelle GLM est ~131k (200k inclut output)
- **Test manuel :** Seuil 75% validé sur toutes les machines (standard unifié #1152)

---

**Dernière mise à jour :** 2026-04-07
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
