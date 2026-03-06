# Règle de Configuration Context Window et Condensation

**Version:** 2.0.0
**Créé:** 2026-02-21
**Mis à jour:** 2026-03-06
**Issues:** #502 (boucle) + #555 (saturation)

---

## CONFIGURATION OBLIGATOIRE (À faire via l'UI Roo)

**⚠️ Redémarrage VS Code REQUIS après modification**

**Chaque agent Roo DOIT configurer ces paramètres dans son instance :**

### 1. Seuil de condensation (CRITIQUE)

**Chemin UI :** Settings → Context Management → Auto-condensation → Threshold

| Profil | Seuil requis | Raison |
|--------|-------------|--------|
| **default** (GLM-5 via z.ai) | **70%** | Compromis optimal #502+#555 |
| **simple** (Qwen 3.5 35B A3B local) | **70%** | Même raison (contexte ~131k) |
| Tout profil GLM | **70%** | GLM réel = 131k tokens (pas 200k) |

**DANGER :**
- Seuil ≤ 50% avec INTERCOM > 800 lignes = **boucle infinie** condensation (#502)
- Seuil ≥ 80% avec GLM-5 = **explosion contexte** (#555)

### 2. Taille de contexte GLM (CRITIQUE)

**La fenêtre de contexte réelle des modèles GLM est 131k tokens, PAS 200k.**

Les 200k annoncés incluent les tokens de sortie. Roo doit savoir que le contexte d'entrée disponible est limité à ~131k.

Si l'interface permet de configurer la taille de contexte du modèle, utiliser **131072** (131k).

---

## Pourquoi 70% ?

| Seuil | Effet | Problème |
|-------|-------|----------|
| 50% | Compaction à ~65k | **Trop tôt** → boucle infinie (#502) |
| 70% | Compaction à ~92k | **Optimal** → marge 40k |
| 80% | Compaction à ~105k | **Trop tard** → explosion (#555) |

---

## Comment vérifier la configuration actuelle

Lors du démarrage d'une session scheduler, vérifier :
1. Le seuil de condensation est à **70%** (ni 50%, ni 80%+)
2. Si l'INTERCOM est > 600 lignes (~12k tokens), condenser l'INTERCOM D'ABORD avant de le lire complètement
3. Signaler dans l'INTERCOM si la boucle de condensation se produit

---

## Références

- **#502** : Boucle infinie condensation (seuil trop bas = 50%)
- **#555** : Saturation contexte GLM-5 (seuil trop haut = 80%+)
- **#580** : META-ANALYSIS - Règles condensation Claude
- **Solution unifiée :** 70% pour les deux côtés (Roo + Claude Code)
