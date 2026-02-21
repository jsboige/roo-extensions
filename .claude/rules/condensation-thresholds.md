# Règles de Condensation - Contextes GLM

**Version:** 1.0.0
**Créé:** 2026-02-21
**Issue:** #502 - Boucle infinie condensation Roo

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
| **GLM-5** (z.ai) | 131k tokens | **80%** = ~105k | Marge de sécurité 25k |
| **GLM-4.7** (z.ai) | 131k tokens | **80%** = ~105k | Marge de sécurité 25k |
| **GLM-4.7 Flash** (auto-hébergé) | 131k tokens | **80%** = ~105k | Marge de sécurité 25k |
| **GLM-4.5 Air** (z.ai) | 131k tokens | **80%** = ~105k | Marge de sécurité 25k |

---

## Configuration Roo (via UI)

**Chemin :** Settings → Context Management → Auto-condensation

**Recommandation :**
```
Seuil de déclenchement : 80%
```

**Pourquoi 80% et pas 50% ?**
- 50% de 200k = 100k (trop bas pour contexte 131k réel)
- 80% de 200k = 160k (suffisant pour 131k + marge)
- Si Roo utilise la valeur réelle 131k : 80% = ~105k (parfait)

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
4. Régler "Seuil de déclenchement" à **80%**
5. Sauvegarder

### 3. Vérifier que la boucle s'arrête

Après configuration :
- Exécuter une tâche scheduler
- Vérifier que l'INTERCOM ne boucle plus
- Si problème persiste : augmenter à 85%

---

## Références

- **Issue #502 :** Boucle infinie condensation Roo
- **Source communauté :** La taille réelle GLM est ~131k (200k inclut output)
- **Test manuel :** Seuil 80% validé sur myia-po-2023 (fin de boucle)

---

**Dernière mise à jour :** 2026-02-21
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
