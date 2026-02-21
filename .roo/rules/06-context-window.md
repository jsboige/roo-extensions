# Règle de Configuration Context Window et Condensation

**Version:** 1.0.0
**Créé:** 2026-02-21
**Issue:** #502

---

## CONFIGURATION OBLIGATOIRE (À faire via l'UI Roo)

**Chaque agent Roo DOIT configurer ces paramètres dans son instance :**

### 1. Seuil de condensation (CRITIQUE)

**Chemin UI :** Settings → API Configuration → Context Window → Condensation Threshold

| Profil | Seuil requis | Raison |
|--------|-------------|--------|
| **default** (GLM 5.0) | **80%** | Éviter boucle infinie avec INTERCOM ~15k tokens |
| **simple** (GLM 4.7 Flash) | **80%** | Même raison |
| Tout profil GLM | **80-85%** | GLM réel = 131k tokens (pas 200k) |

**DANGER :** Seuil ≤ 50% avec INTERCOM > 800 lignes = boucle infinie condensation.

### 2. Taille de contexte GLM (CRITIQUE)

**La fenêtre de contexte réelle des modèles GLM est 131k tokens, PAS 200k.**

Les 200k annoncés incluent les tokens de sortie. Roo doit savoir que le contexte d'entrée disponible est limité à ~131k.

Si l'interface permet de configurer la taille de contexte du modèle, utiliser **131072** (131k).

---

## Comment vérifier la configuration actuelle

Lors du démarrage d'une session scheduler, vérifier :
1. Le seuil de condensation n'est pas ≤ 60%
2. Si l'INTERCOM est > 600 lignes (~12k tokens), condenser l'INTERCOM D'ABORD avant de le lire complètement
3. Signaler dans l'INTERCOM si la boucle de condensation se produit

---

## Référence : Bug #502

- Symptôme : Boucle infinie → condensation → relecture INTERCOM → condensation...
- Root cause : Seuil 50% par défaut + INTERCOM 800 lignes = ~15k tokens > 65k (50% de 131k)
- Fix : Seuil 80-85% = condensation seulement à >104k tokens utilisés
