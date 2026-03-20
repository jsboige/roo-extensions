# Règle de Configuration Context Window et Condensation

**Version:** 2.1.0
**Créé:** 2026-02-21
**Mis à jour:** 2026-03-19
**Issues:** #502 (boucle) + #555 (saturation) + #736 (boucle po-2023) + #737 (instabilité)

---

## CONFIGURATION OBLIGATOIRE (À faire via l'UI Roo)

**⚠️ Redémarrage VS Code REQUIS après modification**

**Chaque agent Roo DOIT configurer ces paramètres dans son instance :**

### 1. Seuil de condensation (CRITIQUE)

**Chemin UI :** Settings → Context Management → Auto-condensation → Threshold

| Profil | Seuil requis | Raison |
|--------|-------------|--------|
| **default** (GLM-5 via z.ai) | **80%** | Marge 26k tokens, prévient boucles avec harnais lourd (#736) |
| **simple** (Qwen 3.5 35B A3B local) | **80%** | Même raison (contexte ~131k) |
| Tout profil GLM | **80%** | GLM réel = 131k tokens (pas 200k) |

**DANGER :**
- Seuil ≤ 50% avec INTERCOM > 800 lignes = **boucle infinie** condensation (#502)
- Seuil 70% avec harnais lourd (~65K tokens) = **boucle** condensation (#736)

### 2. Taille de contexte GLM (CRITIQUE)

**La fenêtre de contexte réelle des modèles GLM est 131k tokens, PAS 200k.**

Les 200k annoncés incluent les tokens de sortie. Roo doit savoir que le contexte d'entrée disponible est limité à ~131k.

Si l'interface permet de configurer la taille de contexte du modèle, utiliser **131072** (131k).

---

## Pourquoi 80% ?

| Seuil | Effet | Problème |
|-------|-------|----------|
| 50% | Compaction à ~65k | **Trop tôt** → boucle infinie (#502) |
| 70% | Compaction à ~92k | Boucle avec harnais lourd (#736) |
| **80%** | **Compaction à ~105k** | **Optimal** → marge 26k |
| 90% | Compaction à ~118k | Trop tard, risque saturation |

**Évolution :** Le seuil est passé de 70% à 80% après l'incident #736 (2026-03-18).
Avec la réduction du harnais auto-chargé (24→10 rules, ~65K→~35K tokens), 80% offre un bon compromis.

---

## Comment vérifier la configuration actuelle

Lors du démarrage d'une session scheduler, vérifier :
1. Le seuil de condensation est à **80%** (ni 50%, ni 70%)
2. Si l'INTERCOM est > 600 lignes (~12k tokens), condenser l'INTERCOM D'ABORD avant de le lire complètement
3. Signaler dans l'INTERCOM si la boucle de condensation se produit

---

## Références

- **#502** : Boucle infinie condensation (seuil trop bas = 50%)
- **#555** : Saturation contexte GLM-5 (seuil trop haut = 90%+)
- **#736** : Boucle condensation po-2023 (70% insuffisant avec harnais lourd)
- **#737** : Instabilité récurrente scheduler (investigation root causes)
- **#580** : META-ANALYSIS - Règles condensation Claude
- **Solution unifiée :** 80% pour les deux côtés (Roo + Claude Code)
