# Spécifications GPU - myia-po-2023

**Date de documentation:** 2026-01-26  
**Machine:** myia-po-2023  
**Objectif:** Estimation des capacités d'exécution de modèles LLM

---

## Configuration GPU

### GPU 0 : NVIDIA GeForce RTX 3080 Laptop

| Spécification | Valeur |
|---------------|--------|
| **Modèle** | NVIDIA GeForce RTX 3080 Laptop |
| **VRAM Totale** | 16 GB (16384 MiB) |
| **Bus ID** | 00000000:01:00.0 |
| **Driver Version** | 591.74 |
| **CUDA Version** | 13.1 |
| **TDP Max** | 150W |
| **Température actuelle** | 58°C |
| **Utilisation actuelle** | 36W / 150W |
| **Utilisation VRAM** | 0 MiB / 16384 MiB |

### GPU 1 : NVIDIA GeForce RTX 3090

| Spécification | Valeur |
|---------------|--------|
| **Modèle** | NVIDIA GeForce RTX 3090 |
| **VRAM Totale** | 24 GB (24576 MiB) |
| **Bus ID** | 00000000:06:00.0 |
| **Driver Version** | 591.74 |
| **CUDA Version** | 13.1 |
| **TDP Max** | 350W |
| **Température actuelle** | 27°C |
| **Utilisation actuelle** | 18W / 350W |
| **Utilisation VRAM** | 93556 MiB / 24576 MiB |

---

## Capacités CUDA/cuDNN

| Composant | Version |
|-----------|---------|
| **CUDA** | 13.1 |
| **Driver NVIDIA** | 591.74 |
| **Architecture** | Ampere (RTX 30 series) |
| **Tensor Cores** | Oui (3ème génération) |
| **Compute Capability** | 8.6 |

---

## Estimation des Modèles LLM Supportés

### Basé sur la VRAM disponible

Les estimations ci-dessous sont basées sur les recommandations générales pour l'inférence de modèles LLM. La VRAM requise dépend de la quantification (precision) utilisée.

#### GPU 0 (RTX 3080 Laptop - 16 GB VRAM)

| Taille Modèle | Quantization 4-bit | Quantization 8-bit | FP16 |
|---------------|-------------------|-------------------|------|
| **7B** | ✅ ~5-6 GB | ✅ ~8-9 GB | ✅ ~14-15 GB |
| **13B** | ✅ ~9-10 GB | ⚠️ ~16-17 GB | ❌ >24 GB |
| **34B** | ❌ >16 GB | ❌ >32 GB | ❌ >64 GB |
| **70B** | ❌ >32 GB | ❌ >64 GB | ❌ >128 GB |

**Recommandations GPU 0 :**
- ✅ Modèles 7B en 4-bit, 8-bit ou FP16
- ✅ Modèles 13B en 4-bit (limite)
- ❌ Modèles 34B+ non recommandés

#### GPU 1 (RTX 3090 - 24 GB VRAM)

| Taille Modèle | Quantization 4-bit | Quantization 8-bit | FP16 |
|---------------|-------------------|-------------------|------|
| **7B** | ✅ ~5-6 GB | ✅ ~8-9 GB | ✅ ~14-15 GB |
| **13B** | ✅ ~9-10 GB | ✅ ~16-17 GB | ✅ ~26-28 GB |
| **34B** | ⚠️ ~20-22 GB | ❌ >32 GB | ❌ >64 GB |
| **70B** | ❌ >32 GB | ❌ >64 GB | ❌ >128 GB |

**Recommandations GPU 1 :**
- ✅ Modèles 7B en 4-bit, 8-bit ou FP16
- ✅ Modèles 13B en 4-bit ou 8-bit
- ⚠️ Modèles 34B en 4-bit (limite)
- ❌ Modèles 70B non recommandés

#### Capacités combinées (Multi-GPU)

Avec les deux GPUs (16 GB + 24 GB = 40 GB VRAM totale) :

| Taille Modèle | Quantization 4-bit | Quantization 8-bit | FP16 |
|---------------|-------------------|-------------------|------|
| **7B** | ✅ | ✅ | ✅ |
| **13B** | ✅ | ✅ | ✅ |
| **34B** | ✅ | ⚠️ ~40 GB | ❌ |
| **70B** | ⚠️ ~40 GB | ❌ | ❌ |

**Recommandations Multi-GPU :**
- ✅ Modèles 7B et 13B en toutes quantizations
- ✅ Modèles 34B en 4-bit
- ⚠️ Modèles 70B en 4-bit (limite stricte)

---

## Notes et Recommandations

### Optimisations possibles

1. **Quantization 4-bit (GPTQ/AWQ/EXL2)** : Permet d'exécuter des modèles plus volumineux avec une perte de qualité minimale
2. **Offloading vers CPU** : Permet d'exécuter des modèles plus grands que la VRAM disponible (plus lent)
3. **Flash Attention** : Optimisation pour réduire l'utilisation VRAM et augmenter la vitesse d'inférence

### Frameworks recommandés

- **llama.cpp** : Supporte quantization 4-bit/8-bit, très efficace
- **AutoGPTQ** : Quantization GPTQ pour modèles Transformers
- **vLLM** : Inférence optimisée avec PagedAttention
- **Ollama** : Interface simple pour exécuter des modèles LLM

### Cas d'usage suggérés

| Cas d'usage | GPU recommandé | Modèle suggéré |
|-------------|----------------|----------------|
| Chat général | GPU 0 (3080) | Llama-3-8B 4-bit |
| Code assistant | GPU 1 (3090) | CodeLlama-13B 8-bit |
| RAG léger | GPU 0 (3080) | Mistral-7B 4-bit |
| RAG avancé | GPU 1 (3090) | Mixtral-8x7B 4-bit |
| Multi-GPU | Les deux | Llama-3-70B 4-bit (expérimental) |

---

## Commandes utiles

```bash
# Vérifier l'état des GPUs
nvidia-smi

# Surveillance en temps réel
watch -n 1 nvidia-smi

# Vérifier la version CUDA
nvcc --version

# Vérifier la version cuDNN
cat /usr/local/cuda/include/cudnn_version.h
```

---

## Historique des modifications

| Date | Modification | Auteur |
|------|--------------|--------|
| 2026-01-26 | Création initiale de la documentation GPU | Roo Code |
