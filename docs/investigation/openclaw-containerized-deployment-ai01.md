# Investigation : Déploiement OpenClaw Containerisé sur myia-ai-01

**Issue :** #921
**Date :** 2026-04-03
**Auteur :** Roo Code (myia-web1, mode code-complex)
**Statut :** Investigation — En attente de revue

---

## Table des Matières

1. [Résumé Exécutif](#1-résumé-exécutif)
2. [Présentation d'OpenClaw](#2-présentation-dopenclaw)
3. [Architecture Cible](#3-architecture-cible)
4. [Expérience 1 : Assistant Gestion Cluster](#4-expérience-1--assistant-gestion-cluster)
5. [Expérience 2 : Explorateur Web](#5-expérience-2--explorateur-web)
6. [Sécurité et Isolation](#6-sécurité-et-isolation)
7. [Compatibilité Providers OpenAI-Compatible](#7-compatibilité-providers-openai-compatible)
8. [Prérequis Infrastructure](#8-prérequis-infrastructure)
9. [Plan de Déploiement Proposé](#9-plan-de-déploiement-proposé)
10. [Risques et Mitigations](#10-risques-et-mitigations)
11. [Recommandations](#11-recommandations)
12. [Annexes](#12-annexes)

---

## 1. Résumé Exécutif

Cette investigation évalue la faisabilité de déployer **OpenClaw** (assistant IA personnel open-source, 346K+ ⭐ GitHub) en mode containerisé sur **myia-ai-01**, pour mener deux expériences sandboxées distinctes :

| Expérience | Objectif | Accès réseau | Accès système | Risque |
|-----------|----------|-------------|--------------|--------|
| **Exp. 1** — Cluster Manager | Gestion des 5 machines exécutrices | Interne uniquement (pas de web) | Contrôlé via MCPs | **Élevé** (accès cluster) |
| **Exp. 2** — Web Explorer | Recherche et synthèse web | HTTP/HTTPS sortant filtré | Minimal (lecture seule) | **Modéré** |

**Conclusion préliminaire :** Le déploiement est **faisable** avec un effort d'intégration modéré. OpenClaw supporte nativement les providers OpenAI-compatible, dispose d'un écosystème MCP actif, et offre un modèle de skills/plugins extensible. Les défis principaux sont l'isolation réseau entre les deux expériences et l'intégration des MCPs existants (roo-state-manager, sk-agent) dans les containers.

---

## 2. Présentation d'OpenClaw

### 2.1 Qu'est-ce qu'OpenClaw ?

**OpenClaw** est un assistant IA personnel open-source (MIT License) fonctionnant comme un gateway/control plane :

- **Repository :** [github.com/openclaw/openclaw](https://github.com/openclaw/openclaw) (346,316 ⭐)
- **Langage :** TypeScript/Node.js
- **Licence :** MIT
- **Site :** [openclaw.ai](https://openclaw.ai)
- **Documentation :** [docs.openclaw.ai](https://docs.openclaw.ai)

### 2.2 Architecture

```
┌─────────────────────────────────────────┐
│  OpenClaw Gateway (Control Plane)        │
│  ├── Channels (WhatsApp, Telegram, ...)  │
│  ├── Skills (plugins)                    │
│  ├── MCP Adapters                        │
│  └── Provider LLM (OpenAI-compatible)    │
└─────────────────────────────────────────┘
```

**Composants clés :**
- **Gateway :** Serveur Node.js qui orchestre les interactions
- **Skills :** Plugins extensibles (5,400+ dans le registre communautaire)
- **Channels :** Interfaces de communication (WhatsApp, Telegram, Slack, Discord, WebChat, etc.)
- **MCP Support :** Via plugins communautaires (openclaw-mcp-adapter, openclaw-mcp-bridge)

### 2.3 Modèle de Déploiement

OpenClaw supporte plusieurs modes d'installation :
- **npm/pnpm/bun :** `openclaw onboard` (CLI guidé)
- **Docker :** Documentation dédiée ([docs.openclaw.ai/install/docker](https://docs.openclaw.ai/install/docker))
- **Nix :** [github.com/openclaw/nix-openclaw](https://github.com/openclaw/nix-openclaw)
- **Windows :** Via WSL2 (recommandé)

### 2.4 Écosystème MCP

Plusieurs projets MCP pour OpenClaw existent :

| Projet | Description | Pertinence |
|--------|-------------|-----------|
| [openclaw-mcp-adapter](https://github.com/androidStern-personal/openclaw-mcp-adapter) | Expose les outils MCP comme outils natifs OpenClaw | **Élevée** |
| [openclaw-mcp-bridge](https://github.com/AIWerk/openclaw-mcp-bridge) | Pont MCP servers → OpenClaw via `registerTool` | **Élevée** |
| [openclaw-mcp-plugin](https://github.com/lunarpulse/openclaw-mcp-plugin) | Plugin MCP avec support remote streamable HTTP | **Moyenne** |
| [openclaw-mcp-server](https://github.com/Helms-AI/openclaw-mcp-server) | Expose les outils OpenClaw Gateway vers Claude Code | **Faible** (sens inverse) |

---

## 3. Architecture Cible

### 3.1 Vue d'Ensemble

```
┌──────────────────────────────────────────────────────────────────┐
│  myia-ai-01 (Windows 11, 3x RTX 4090, 32GB RAM)                 │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Docker Network: openclaw-internal (bridge, isolated)        │ │
│  │                                                              │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  Exp. 1: cluster-manager (Container)                    │ │ │
│  │  │  ├── OpenClaw Gateway + Skills                          │ │ │
│  │  │  ├── MCP: roo-state-manager (Node.js)                   │ │ │
│  │  │  ├── MCP: sk-agent (Python)                             │ │ │
│  │  │  ├── MCP: desktop-control (TBD)                         │ │ │
│  │  │  ├── Network: internal-only (vLLM, Qdrant, RooSync)    │ │ │
│  │  │  └── Volumes: configs read-only, logs write-only        │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Docker Network: openclaw-web (bridge + filtered egress)     │ │
│  │                                                              │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │  Exp. 2: web-explorer (Container)                       │ │ │
│  │  │  ├── OpenClaw Gateway + Skills                          │ │ │
│  │  │  ├── MCP: sk-agent (Python)                             │ │ │
│  │  │  ├── MCP: playwright (browser sandboxed)                │ │ │
│  │  │  ├── Network: HTTP/HTTPS sortant filtré (proxy)        │ │ │
│  │  │  └── Volumes: none (stateless, pas de filesystem host)  │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Services Host (accès contrôlé via Docker port-mapping) :        │
│  ├── vLLM Qwen3.5-35B :5002 (GPU 0+1)                          │
│  ├── vLLM OmniCoder 2.0 :5001 (GPU 2)                          │
│  ├── Qdrant :6333                                                │
│  └── z.ai API (via proxy HTTPS sortant)                         │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 Isolation Réseau

| Réseau Docker | Exp. 1 (cluster-mgr) | Exp. 2 (web-explorer) |
|--------------|----------------------|----------------------|
| `openclaw-internal` | ✅ Connecté | ❌ Non connecté |
| `openclaw-web` | ❌ Non connecté | ✅ Connecté |
| Accès vLLM (:5001/:5002) | ✅ Via port-mapping | ✅ Via port-mapping |
| Accès Qdrant (:6333) | ✅ Via port-mapping | ❌ Bloqué |
| Accès web sortant | ❌ Bloqué (iptables) | ✅ Via proxy filtré |
| Accès host filesystem | ⚠️ Volumes limités | ❌ Aucun volume |

### 3.3 Flux de Données

```
Exp. 1 (Cluster Manager):
  User → OpenClaw → LLM (vLLM/z.ai) → Skills/MCPs → Actions cluster
  ↳ Logging: Toutes les actions → volume logs/ (audit trail)

Exp. 2 (Web Explorer):
  User → OpenClaw → LLM (vLLM/z.ai) → Skills/Playwright → Web
  ↳ Logging: Toutes les requêtes HTTP → volume logs/ (audit trail)
```

---

## 4. Expérience 1 : Assistant Gestion Cluster

### 4.1 Objectif

Un agent autonome qui assiste dans la gestion des 5 machines exécutrices (po-2023, po-2024, po-2025, po-2026, web1) depuis ai-01, en utilisant les MCPs existants du système RooSync.

### 4.2 MCPs Requis

| MCP | Version | Runtime | Intégration dans Container |
|-----|---------|---------|---------------------------|
| **roo-state-manager** | v2.3 | Node.js | ✅ Direct — copier le build dans le container |
| **sk-agent** | v1.x | Python | ✅ Direct — copier le package dans le container |
| **desktop-control** | TBD | TBD | ⚠️ À définir — options ci-dessous |

### 4.3 Options pour Desktop Control

| Option | Description | Avantages | Inconvénients |
|--------|-------------|-----------|---------------|
| **mcp-desktop-automation** | Contrôle desktop natif (souris, clavier) | Prêt à l'emploi | Accès X11/Wayland requis, complexe en container |
| **Playwright headless** | Screenshots + interaction web | Déjà dans notre stack | Limité aux interfaces web |
| **RDP/VNC client MCP** | Connexion bureau à distance | Contrôle complet des machines | Nécessite RDP activé sur chaque machine |
| **Custom SSH-based** | Commandes via SSH (déjà dans win-cli) | Simple, éprouvé | Pas de contrôle visuel |

**Recommandation :** Commencer par un **custom SSH-based** (réutiliser le pattern win-cli existant), puis évaluer Playwright pour les interfaces web d'administration. Le contrôle desktop complet (RDP/VNC) est un objectif Phase 2.

### 4.4 Modèles LLM

| Tâche | Modèle | Provider | Port/Endpoint |
|-------|--------|----------|---------------|
| Raisonnement principal | GLM-5.1 | z.ai API | HTTPS sortant |
| Tâches rapides | Qwen3.5-35B-A3B | vLLM local | :5002 |
| Code/spécialisé | OmniCoder 2.0 | vLLM local | :5001 |

### 4.5 Contraintes Spécifiques

1. **Pas d'accès web libre** — L'agent communique uniquement via le cluster interne
2. **Audit trail obligatoire** — Chaque action MCP doit être loggée avec horodatage
3. **Approbation humaine** — Les actions destructives (restart, delete, reconfigure) nécessitent une confirmation
4. **Credentials isolés** — Les clés API sont injectées via Docker secrets, pas de montage .env

### 4.6 Configuration Docker Compose (Draft)

```yaml
# docker-compose.exp1-cluster-manager.yml
version: "3.9"

services:
  cluster-manager:
    image: openclaw/openclaw:latest  # ou image custom
    container_name: openclaw-cluster-mgr
    restart: unless-stopped
    networks:
      - openclaw-internal
    environment:
      # Provider LLM
      - OPENAI_API_KEY=${ZAI_API_KEY}        # z.ai
      - OPENAI_BASE_URL=https://api.z.ai/v1  # ou proxy local
      - VLLM_QWEN_URL=http://host.docker.internal:5002/v1
      - VLLM_OMNICODER_URL=http://host.docker.internal:5001/v1
      # MCP Config
      - MCP_ROO_STATE_MANAGER=true
      - MCP_SK_AGENT=true
      # Sécurité
      - AUDIT_LOG_ENABLED=true
      - HUMAN_APPROVAL_REQUIRED=destructive
    volumes:
      - ./configs/exp1:/app/config:ro        # Config read-only
      - ./logs/exp1:/app/logs                 # Logs write-only
      - ./mcp-servers/roo-state-manager:/app/mcps/roo-state-manager:ro
      - ./mcp-servers/sk-agent:/app/mcps/sk-agent:ro
    # Pas de port exposé vers l'extérieur
    # Accès uniquement via Docker network
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 4G

networks:
  openclaw-internal:
    driver: bridge
    internal: true  # Pas d'accès sortant
```

---

## 5. Expérience 2 : Explorateur Web

### 5.1 Objectif

Un agent libre d'explorer le web pour la recherche et la synthèse d'information, avec un accès système minimal et un accès web filtré.

### 5.2 MCPs Requis

| MCP | Runtime | Intégration |
|-----|---------|-------------|
| **sk-agent** | Python | ✅ Direct |
| **playwright** | Node.js | ✅ Déjà dans notre stack |

### 5.3 Architecture de Navigation

```
┌─────────────────────────────────────────┐
│  Container web-explorer                  │
│                                          │
│  OpenClaw → Skill WebSearch → Proxy     │
│                                  ↓       │
│  ┌─────────────────────────────────┐    │
│  │  Squid / Caddy (reverse proxy)   │    │
│  │  Allowlist: *.wikipedia.org,     │    │
│  │  *.github.com, *.stackoverflow,  │    │
│  │  *.arxiv.org, *.mdn.mozilla.org  │    │
│  └─────────────────────────────────┘    │
│                    ↓                     │
│  ┌─────────────────────────────────┐    │
│  │  Playwright (headless Chromium)  │    │
│  │  Sandbox: no downloads,          │    │
│  │  no file:// protocol,            │    │
│  │  no WebRTC                       │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### 5.4 Filtrage Réseau

**Stratégie recommandée : Allowlist par défaut** (plutôt que blocklist)

| Catégorie | Domaines autorisés | Justification |
|-----------|-------------------|---------------|
| Documentation technique | *.wikipedia.org, *.mdn.mozilla.org, *.stackoverflow.com, *.docs.microsoft.com | Recherche technique |
| Code source | *.github.com, *.gitlab.com, *.npmjs.com | Référence code |
| Publications | *.arxiv.org, *.dl.acm.org, *.ieee.org | Articles de recherche |
| APIs publiques | api.github.com, *.cloudflare.com | Intégration |

**Bloqué par défaut :**
- Réseaux sociaux (facebook, twitter, instagram)
- Services de stockage cloud (dropbox, drive.google.com — prévention exfiltration)
- Services de messagerie
- Tout domaine non dans l'allowlist

### 5.5 Configuration Docker Compose (Draft)

```yaml
# docker-compose.exp2-web-explorer.yml
version: "3.9"

services:
  web-proxy:
    image: caddy:2-alpine
    container_name: openclaw-web-proxy
    networks:
      - openclaw-web
    # Configuration allowlist via Caddyfile

  web-explorer:
    image: openclaw/openclaw:latest
    container_name: openclaw-web-explorer
    restart: unless-stopped
    networks:
      - openclaw-web
    environment:
      - OPENAI_API_KEY=${ZAI_API_KEY}
      - OPENAI_BASE_URL=https://api.z.ai/v1
      - VLLM_QWEN_URL=http://host.docker.internal:5002/v1
      - HTTP_PROXY=http://web-proxy:3128
      - HTTPS_PROXY=http://web-proxy:3128
      - NO_PROXY=localhost,127.0.0.1
      - AUDIT_LOG_ENABLED=true
    volumes:
      - ./configs/exp2:/app/config:ro
      - ./logs/exp2:/app/logs
    # Pas de volume host — container stateless
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 4G

networks:
  openclaw-web:
    driver: bridge
    # Pas "internal: true" — besoin d'accès web sortant
```

---

## 6. Sécurité et Isolation

### 6.1 Matrice de Menaces

| Vecteur | Exp. 1 | Exp. 2 | Mitigation |
|---------|--------|--------|-----------|
| **Prompt Injection** | Critique | Élevé | System prompts durcis, validation des entrées |
| **Tool Abuse** | Critique | Moyen | Allowlist d'outils, approbation humaine pour actions destructives |
| **Data Exfiltration** | Moyen | Élevé | Pas de volume host (Exp. 2), réseau filtré |
| **Container Escape** | Élevé | Élevé | Docker rootless, capabilities minimales, seccomp |
| **Credential Theft** | Critique | Moyen | Docker secrets, pas de montage .env |
| **Lateral Movement** | Critique | Faible | Réseaux Docker séparés, pas de Docker socket |
| **Resource Exhaustion** | Moyen | Moyen | Limits CPU/RAM, cgroups |

### 6.2 Mesures de Sécurité par Couche

#### Couche 1 : Container

```yaml
security_opt:
  - no-new-privileges:true
  - seccomp:unconfined  # À remplacer par un profil custom
read_only: true          # Filesystem en lecture seule
tmpfs:
  - /tmp:noexec,nosuid,size=100m
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # Uniquement si nécessaire
```

#### Couche 2 : Réseau

- **Exp. 1 :** Réseau Docker `internal: true` (pas de route vers l'extérieur)
- **Exp. 2 :** Proxy allowlist + iptables rules sur le host
- **Mutuelle isolation :** Les deux containers ne sont PAS sur le même réseau Docker

#### Couche 3 : Credentials

```yaml
# Injection via Docker secrets (pas de variables en clair)
secrets:
  zai_api_key:
    file: ./secrets/zai_api_key.txt
  vllm_internal_token:
    file: ./secrets/vllm_internal_token.txt
```

#### Couche 4 : Audit

- **Logging exhaustif :** Toutes les actions MCP, requêtes LLM, et réponses sont loggées
- **Format structuré :** JSON avec timestamp, action, paramètres, résultat
- **Rotation :** Logs rotatés quotidiennement, rétention 30 jours
- **Monitoring :** Alertes sur patterns suspects (tentatives d'accès non autorisé, requêtes inhabituelles)

### 6.3 Mécanisme d'Approbation Humaine (Exp. 1)

Pour les actions critiques du Cluster Manager :

```
Agent → Action critique détectée
  → Log de l'action proposée
  → Notification au canal humain (Telegram/Discord)
  → Attente approbation (timeout: 5 min)
  → Si approuvé → Exécution
  → Si timeout/refusé → Annulation + log
```

**Actions nécessitant approbation :**
- Redémarrage d'une machine
- Modification de configuration système
- Exécution de commandes shell
- Accès à des fichiers sensibles
- Toute action marquée `destructive` dans le MCP

---

## 7. Compatibilité Providers OpenAI-Compatible

### 7.1 OpenClaw et Providers Custom

OpenClaw est conçu pour fonctionner avec n'importe quel provider OpenAI-compatible. La configuration se fait via des variables d'environnement ou le fichier de configuration :

```json
{
  "providers": {
    "z-ai": {
      "type": "openai",
      "apiKey": "${ZAI_API_KEY}",
      "baseURL": "https://api.z.ai/v1",
      "models": ["glm-5.1"]
    },
    "vllm-qwen": {
      "type": "openai",
      "apiKey": "local",
      "baseURL": "http://host.docker.internal:5002/v1",
      "models": ["qwen3.5-35b-a3b"]
    },
    "vllm-omnicoder": {
      "type": "openai",
      "apiKey": "local",
      "baseURL": "http://host.docker.internal:5001/v1",
      "models": ["omnicoder-2.0"]
    }
  }
}
```

### 7.2 Compatibilité Matrix

| Provider | Endpoint | Modèle | Statut | Notes |
|----------|----------|--------|--------|-------|
| **z.ai** | `api.z.ai/v1` | GLM-5.1 | ✅ Compatible | API OpenAI-compatible, nécessite clé |
| **vLLM local** | `localhost:5002/v1` | Qwen3.5-35B-A3B | ✅ Compatible | vLLM expose l'API OpenAI nativement |
| **vLLM local** | `localhost:5001/v1` | OmniCoder 2.0 | ⚠️ À vérifier | Pas encore déployé, API identique |
| **Anthropic** | N/A | Claude | ❌ Non pertinent | OpenClaw supporte mais pas dans notre scope |

### 7.3 Considérations Spécifiques

1. **Latence vLLM local :** Les containers Docker accèdent au host via `host.docker.internal` (latence minimale sur localhost)
2. **Rate limiting z.ai :** Le container doit respecter les rate limits du provider
3. **Token counting :** OpenClaw gère le comptage de tokens — à monitorer pour la consommation z.ai
4. **Streaming :** Supporté nativement par vLLM et z.ai via l'API OpenAI

---

## 8. Prérequis Infrastructure

### 8.1 Logiciel Requis sur myia-ai-01

| Composant | Version | Statut | Action |
|-----------|---------|--------|--------|
| **Docker Desktop** | 24+ | ⚠️ À vérifier | Installer si absent |
| **WSL2** | Recent | ✅ Probablement présent | Nécessaire pour Docker sur Windows |
| **Node.js** | 20+ | ✅ Déjà présent | Pour build MCPs |
| **Python** | 3.11+ | ✅ Déjà présent | Pour sk-agent |
| **Git** | 2.x | ✅ Présent | Pour cloner OpenClaw |

### 8.2 Ressources Matérielles

| Ressource | Disponible | Requis (estimation) | Impact |
|-----------|-----------|---------------------|--------|
| **CPU** | 32+ threads (i9/Threadripper) | 2-4 threads par container | Faible |
| **RAM** | 32 GB | 4 GB par container (8 GB total) | Modéré (25% de la RAM) |
| **GPU** | 3x RTX 4090 (72 GB VRAM) | Aucun (accès via API) | Nul |
| **Disque** | SSD NVMe | ~5 GB (images + logs) | Faible |

**Note importante :** OpenClaw n'a PAS besoin d'accès GPU direct. Les modèles LLM sont accédés via l'API vLLM (déjà en cours d'exécution sur les GPUs). Les containers tournent en mode CPU-only.

### 8.3 Réseau

| Besoin | Configuration |
|--------|--------------|
| Accès vLLM depuis Docker | `host.docker.internal:5001` et `:5002` |
| Accès z.ai depuis Docker | Sortie HTTPS via proxy ou direct |
| Accès Qdrant depuis Docker | `host.docker.internal:6333` (Exp. 1 uniquement) |
| Isolation Exp. 1 ↔ Exp. 2 | Réseaux Docker séparés |
| DNS | Docker DNS interne + DNS host pour résolution externe |

### 8.4 Volumes et Données

```
openclaw/
├── configs/
│   ├── exp1/                    # Config Cluster Manager
│   │   ├── openclaw.yaml
│   │   ├── mcp-config.json
│   │   └── skills/
│   └── exp2/                    # Config Web Explorer
│       ├── openclaw.yaml
│       ├── mcp-config.json
│       └── skills/
├── logs/
│   ├── exp1/                    # Audit trail Cluster Manager
│   └── exp2/                    # Audit trail Web Explorer
├── mcp-servers/
│   ├── roo-state-manager/       # Build Node.js (copié)
│   └── sk-agent/                # Package Python (copié)
└── secrets/
    ├── zai_api_key.txt          # Clé API z.ai
    └── vllm_internal_token.txt  # Token vLLM (si auth activée)
```

---

## 9. Plan de Déploiement Proposé

### Phase 0 : Préparation (1-2 jours)

- [ ] Vérifier/installer Docker Desktop sur myia-ai-01
- [ ] Cloner le repository OpenClaw et tester l'image Docker de base
- [ ] Valider l'accès aux providers LLM depuis un container Docker
- [ ] Préparer les secrets (clés API, tokens)

### Phase 1 : Expérience 2 — Web Explorer (3-5 jours)

**Pourquoi commencer par l'Exp. 2 ?** Moins de risques (pas d'accès cluster), plus simple à implémenter, permet de valider l'architecture de base.

- [ ] Créer le `docker-compose.exp2-web-explorer.yml`
- [ ] Configurer le proxy allowlist (Caddy/Squid)
- [ ] Intégrer le MCP sk-agent dans le container
- [ ] Intégrer Playwright headless dans le container
- [ ] Tester la navigation web sandboxée
- [ ] Valider l'audit trail
- [ ] Documenter les résultats

### Phase 2 : Expérience 1 — Cluster Manager (5-7 jours)

- [ ] Créer le `docker-compose.exp1-cluster-manager.yml`
- [ ] Intégrer le MCP roo-state-manager dans le container
- [ ] Intégrer le MCP sk-agent dans le container
- [ ] Implémenter le MCP desktop-control (SSH-based, Phase 1)
- [ ] Configurer le mécanisme d'approbation humaine
- [ ] Tester les actions cluster en mode dry-run
- [ ] Valider l'isolation réseau (pas de fuite vers l'extérieur)
- [ ] Tester en conditions réelles avec supervision

### Phase 3 : Production et Monitoring (2-3 jours)

- [ ] Mettre en place le monitoring (Prometheus/Grafana ou simple dashboards)
- [ ] Configurer les alertes (actions suspectes, consommation tokens)
- [ ] Écrire la documentation opérationnelle
- [ ] Former les utilisateurs (Claude Code, Roo Code)
- [ ] Planifier les sauvegardes et la reprise après incident

### Calendrier Estimé

```
Semaine 1 : Phase 0 + début Phase 1
Semaine 2 : Fin Phase 1 + début Phase 2
Semaine 3 : Fin Phase 2 + Phase 3
```

**Total estimé : 10-15 jours ouvrés**

---

## 10. Risques et Mitigations

### 10.1 Risques Techniques

| # | Risque | Probabilité | Impact | Mitigation |
|---|--------|------------|--------|-----------|
| R1 | OpenClaw ne supporte pas correctement les providers vLLM custom | Faible | Élevé | Tester en Phase 0 avant engagement |
| R2 | MCPs existants incompatibles avec l'environnement containerisé | Moyen | Élevé | Build spécifique container, tests d'intégration |
| R3 | Performance dégradée par la couche Docker | Faible | Faible | Benchmark en Phase 0, ajuster resources |
| R4 | Instabilité de l'image Docker OpenClaw | Faible | Moyen | Pin la version, image custom si nécessaire |
| R5 | Conflit de ports avec services existants | Faible | Moyen | Utiliser des ports non-standard, mapping explicite |

### 10.2 Risques de Sécurité

| # | Risque | Probabilité | Impact | Mitigation |
|---|--------|------------|--------|-----------|
| S1 | Prompt injection conduisant à des actions non autorisées | Élevé | Critique | System prompts durcis, approbation humaine, audit |
| S2 | Container escape vers le host | Faible | Critique | Docker rootless, capabilities minimales, seccomp |
| S3 | Exfiltration de données via le canal web (Exp. 2) | Moyen | Élevé | Allowlist stricte, monitoring, pas de volumes |
| S4 | Compromission des credentials API | Faible | Élevé | Docker secrets, rotation régulière |
| S5 | Mouvement latéral entre les deux expériences | Faible | Élevé | Réseaux Docker séparés, pas de communication inter-container |

### 10.3 Risques Opérationnels

| # | Risque | Probabilité | Impact | Mitigation |
|---|--------|------------|--------|-----------|
| O1 | Surconsommation de tokens z.ai | Moyen | Moyen | Monitoring, quotas, alertes |
| O2 | Instabilité du service (crash container) | Faible | Moyen | Restart policy, health checks, logs |
| O3 | Conflit avec les schedulers Roo existants | Moyen | Élevé | Coordination via INTERCOM, ports séparés |
| O4 | Maintenance complexe (2 containers + proxy) | Moyen | Faible | Documentation, scripts de gestion |

---

## 11. Recommandations

### 11.1 Recommandations Principales

1. **Commencer par l'Exp. 2** (Web Explorer) — risque moindre, validation rapide de l'architecture
2. **Utiliser Docker rootless** sur myia-ai-01 pour minimiser la surface d'attaque
3. **Implémenter l'audit trail dès le début** — ne pas attendre la production
4. **Prévoir un mécanisme de kill switch** — pouvoir arrêter instantanément chaque expérience
5. **Monitorer la consommation tokens** — surtout z.ai (coût direct)

### 11.2 Points de Décision

| Décision | Options | Recommandation |
|----------|---------|---------------|
| Image Docker de base | `openclaw/openclaw:latest` vs build custom | Commencer avec l'image officielle, customiser si besoin |
| Proxy web (Exp. 2) | Caddy vs Squid vs mitmproxy | **Caddy** (simple, performant, allowlist facile) |
| Desktop Control (Exp. 1) | SSH-based vs RDP vs Playwright | **SSH-based** (Phase 1), Playwright (Phase 2) |
| Monitoring | Prometheus/Grafana vs simple logs | **Simple logs** (Phase 1), Prometheus (Phase 3) |
| Channel de communication | WebChat vs Telegram vs Discord | **WebChat** (embarqué, pas de service externe) |

### 11.3 Prochaines Étapes Immédiates

1. **Valider Docker sur ai-01** — Vérifier que Docker Desktop est installé et fonctionnel
2. **Test de connectivité** — Lancer un container minimal et tester l'accès à vLLM et z.ai
3. **Prototype Exp. 2** — Docker compose minimal avec OpenClaw + proxy Caddy
4. **Rapport de validation** — Documenter les résultats du prototype

---

## 12. Annexes

### 12.1 Ressources OpenClaw

| Ressource | URL |
|-----------|-----|
| Repository principal | [github.com/openclaw/openclaw](https://github.com/openclaw/openclaw) |
| Documentation Docker | [docs.openclaw.ai/install/docker](https://docs.openclaw.ai/install/docker) |
| Skills Registry | [github.com/openclaw/clawhub](https://github.com/openclaw/clawhub) |
| Awesome Skills | [github.com/VoltAgent/awesome-openclaw-skills](https://github.com/VoltAgent/awesome-openclaw-skills) |
| MCP Adapter | [github.com/androidStern-personal/openclaw-mcp-adapter](https://github.com/androidStern-personal/openclaw-mcp-adapter) |
| MCP Bridge | [github.com/AIWerk/openclaw-mcp-bridge](https://github.com/AIWerk/openclaw-mcp-bridge) |
| Docker Images | [github.com/coollabsio/openclaw](https://github.com/coollabsio/openclaw) |

### 12.2 Infrastructure Existante RooSync

| Service | Host | Port | Utilisation |
|---------|------|------|-------------|
| vLLM Qwen3.5-35B | ai-01 | 5002 | Modèle principal local |
| vLLM OmniCoder 2.0 | ai-01 | 5001 | Modèle code local |
| Qdrant | ai-01 | 6333 | Vector DB |
| z.ai API | Cloud | 443 | Provider LLM cloud |
| Embeddings | ai-01 | — | Service embeddings |

### 12.3 Glossaire

| Terme | Définition |
|-------|-----------|
| **OpenClaw** | Assistant IA personnel open-source (TypeScript/Node.js) |
| **Gateway** | Serveur principal OpenClaw (control plane) |
| **Skill** | Plugin OpenClaw (équivalent d'un outil MCP) |
| **Channel** | Interface de communication (WhatsApp, Telegram, etc.) |
| **MCP** | Model Context Protocol — standard d'outils pour LLMs |
| **vLLM** | Serveur d'inférence LLM haute performance |
| **z.ai** | Provider LLM cloud (GLM-5.1) |
| **Sandbox** | Environnement isolé et contrôlé |

---

*Document produit par Roo Code (myia-web1) en mode code-complex. Investigation issue #921.*
*En attente de revue par le coordinateur (myia-ai-01).*
