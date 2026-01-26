# Spécifications GPU - Infrastructure Multi-Machine RooSync

**Version:** 1.1.0
**Date:** 2026-01-26
**Auteur:** Claude Code + Roo (collecte multi-machines)
**Statut:** 🟢 2/5 machines documentées

---

## Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Spécifications par Machine](#spécifications-par-machine)
3. [Analyse des Capacités](#analyse-des-capacités)
4. [Recommandations Hébergement Local](#recommandations-hébergement-local)
5. [Références](#références)

---

## Vue d'ensemble

### Objectif

Documenter les capacités GPU des 5 machines du système RooSync Multi-Agent pour évaluer les possibilités d'hébergement local de modèles LLM.

### Contexte

**Système RooSync (5 machines)** :
- myia-ai-01 (Coordinateur)
- myia-po-2023
- myia-po-2024
- myia-po-2026
- myia-web1

**Besoin** : Déterminer quelles machines peuvent héberger localement des modèles pour réduire les coûts API.

---

## Spécifications par Machine

### myia-ai-01 (Coordinateur)

**GPU** :
🔄 *En attente de collecte*

**VRAM** :
🔄 *En attente*

**Drivers** :
🔄 *En attente*

**Capacités** :
🔄 *À analyser*

---

### myia-po-2023

> 📋 **Documentation détaillée :** [docs/hardware/gpu-specs-myia-po-2023.md](../hardware/gpu-specs-myia-po-2023.md)

**Configuration Multi-GPU :**

| GPU | Modèle | VRAM |
|-----|--------|------|
| GPU 0 | RTX 3080 Laptop | 16 GB |
| GPU 1 | RTX 3090 | 24 GB |
| **Total** | - | **40 GB** |

**CUDA :** 13.1 | **Driver :** 591.74 | **Architecture :** Ampere

**Capacités hébergement local :**
- ✅ Modèles 7B-13B en toutes quantizations
- ✅ Modèles 34B en 4-bit
- ⚠️ Modèles 70B en 4-bit (limite multi-GPU)

**Date collecte :** 2026-01-26

---

### myia-po-2024

**GPU** :
🔄 *En attente de collecte*

**VRAM** :
🔄 *En attente*

**Drivers** :
🔄 *En attente*

**Capacités** :
🔄 *À analyser*

---

### myia-po-2026

**GPU** :
NVIDIA GeForce RTX 3080 Ti Laptop GPU

**VRAM** :
~4 Go (4.29 GB)

**Drivers** :
Version 32.0.15.9174

**UUID** :
GPU-0ab3345e-f1ef-8f0c-e82a-8cbb3a8ed0f4

**Résolution actuelle** :
1920 x 1080

**Capacités hébergement local** :
⚠️ **VRAM limitée (4 Go)** - Insuffisant pour la plupart des modèles LLM
- GLM 4.7 Air (4B) : ❌ Limite (4 Go min, 8 Go recommandé)
- GLM 4.7 (7B) : ❌ Impossible (8 Go min requis)
- Utilisation recommandée : **API uniquement**

---

### myia-web1

**GPU** :
🔄 *En attente de collecte*

**VRAM** :
🔄 *En attente*

**Drivers** :
🔄 *En attente*

**Capacités** :
🔄 *À analyser*

---

## Analyse des Capacités

### Critères pour Hébergement Local

| Modèle | VRAM Minimum | VRAM Recommandé | Performance |
|--------|--------------|-----------------|-------------|
| **GLM 4.7 Air (4B)** | 4 GB | 8 GB | Rapide |
| **GLM 4.7 (7B)** | 8 GB | 16 GB | Moyen |
| **Llama 3.1 8B** | 8 GB | 16 GB | Moyen |
| **Mixtral 8x7B** | 32 GB | 48 GB | Lent |

### Répartition Recommandée

🔄 *À compléter après collecte des specs*

---

## Recommandations Hébergement Local

### Scénario 1 : Machines avec GPU Puissant (16+ GB VRAM)

- Héberger GLM 4.7 (7B) localement
- Réduire appels API z.ai
- Mode fallback vers API si nécessaire

### Scénario 2 : Machines avec GPU Moyen (8-16 GB VRAM)

- Héberger GLM 4.7 Air (4B) localement
- Tâches simples en local
- Tâches complexes via API

### Scénario 3 : Machines sans GPU (CPU only)

- Continuer utilisation API
- Pas d'hébergement local

---

## Références

- [Documentation SDDD Architecture 2-Niveaux](../sddd/ARCHITECTURE_2_NIVEAUX.md)
- [RooSync Multi-Agent Guide](../roosync/GUIDE-TECHNIQUE-v2.3.md)
- [Issue #354 - Documentation specs GPUs](https://github.com/jsboige/roo-extensions/issues/354)

---

**Dernière mise à jour :** 2026-01-26 16:00:00
**Statut collecte :** 2/5 machines documentées (myia-po-2023 complet, myia-po-2026 partiel)
