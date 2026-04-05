# Claw Ecosystem - Comparative Analysis

**Issue:** #1073
**Date:** 2026-04-05
**Author:** Claude Code (myia-ai-01)
**Context:** Suite de #921 (OpenClaw) et #953 (Agent Zero)

---

## Executive Summary

L'écosystème Claw s'est considérablement diversifié depuis mars 2026, avec 5 variantes principales identifiées. Cette analyse compare **OpenClaw**, **Claw Code**, **NanoClaw**, **ZeroClaw**, et **Agent Zero** selon 7 critères clés pour nos expériences (Web Explorer, Cluster Manager).

**Recommandation principale :** **NanoClaw** pour Exp. 2 (Web Explorer) + **Agent Zero** pour Exp. 1 (Cluster Manager).

---

## Vue d'ensemble de l'écosystème

| Variante | Repo | Stars | Statut | Focus principal |
|----------|------|-------|--------|----------------|
| **OpenClaw** | [openclaw/openclaw](https://github.com/openclaw/openclaw) | 346K+ | Production | Multi-canal, ecosystem mature |
| **Claw Code** | [ultraworkers/claw-code](https://github.com/ultraworkers/claw-code) | 72K+ | Beta | Framework code-first, Rust/Python |
| **NanoClaw** | [qwibitai/nanoclaw](https://github.com/qwibitai/nanoclaw) | ? | Production | Sécurité Docker, containerisation |
| **ZeroClaw** | ? | ? | Concept | Runtime Rust minimal (<5MB RAM) |
| **Agent Zero** | [agent0ai/agent-zero](https://github.com/agent0ai/agent-zero) | ? | Production | Framework agentique, MCP natif |

---

## Analyse comparative selon 7 critères

### 1. Support providers OpenAI-compatible (z.ai, vLLM local) ✅ OBLIGATOIRE

| Variante | Support z.ai | Support vLLM local | Modèle recommandé | Notes |
|----------|-------------|-------------------|------------------|-------|
| **OpenClaw** | ✅ Oui | ✅ Oui | Multi-provider routing | Anthropic Claude, OpenAI GPT-5.4, DeepSeek, Ollama |
| **Claw Code** | ✅ Probable | ✅ Probable | OpenAI-compatible | Clean-room rewrite de Claude Code architecture |
| **NanoClaw** | ✅ Oui | ✅ Oui | Via Anthropic SDK | Tourne sur Anthropic's Agents SDK |
| **ZeroClaw** | ⚠️ Inconnu | ⚠️ Inconnu | ? | Runtime Rust (<5MB), détails manquants |
| **Agent Zero** | ✅ Oui | ✅ Oui | OpenAI-compatible | Documentation extensive pour providers |

**Verdict :** Tous (sauf ZeroClaw) supportent les providers OpenAI-compatible. **glm-5-turbo** (z.ai) est optimal pour l'agentique :
- Agentic Index: 65.9 (top open-model)
- BrowseComp: 62.0-75.9% (web retrieval)
- SWE-bench Verified: 77.8% (coding)
- Vending Bench 2: #1 open-source (long-horizon tasks)

**Sources:**
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Z.ai GLM-5 Overview](https://docs.z.ai/guides/llm/glm-5)
- [GLM-5 Turbo Review](https://designforonline.com/ai-models/z-ai-glm-5-turbo/)

---

### 2. Support MCP (Model Context Protocol) ✅

| Variante | MCP Server | MCP Client | MCP Skills | Écosystème |
|----------|-----------|-----------|-----------|-----------|
| **OpenClaw** | ✅ Oui | ✅ Oui | 3,200+ (ClawHub) | 500+ servers npm/GitHub |
| **Claw Code** | ✅ Complet | ✅ 6 transports | Stdio, SSE, HTTP, WS, SDK, Proxy | OAuth, config hashing |
| **NanoClaw** | ⚠️ Non natif | ⚠️ Via SDK | Limité | Anthropic SDK comme base |
| **ZeroClaw** | ❌ Inconnu | ❌ Inconnu | ? | Pas de doc trouvée |
| **Agent Zero** | ✅ Oui (server) | ✅ Oui (3 types) | code-execution-mcp | Stdio, SSE, HTTP streaming |

**Détail Agent Zero MCP :**
- **MCP Client :** 3 types de serveurs supportés (Stdio local, SSE remote, HTTP streaming)
- **MCP Server :** Expose Agent Zero aux autres clients (Claude, Cursor, Windsurf)
- **code-execution-mcp :** Tool dédié pour exécution terminal + Python

**Verdict :** **OpenClaw** et **Claw Code** ont le meilleur support MCP (écosystème 500+ servers). **Agent Zero** a un support natif solide. **NanoClaw** est limité (Anthropic SDK uniquement).

**Nos MCPs critiques :**
- `roo-state-manager` (34 tools) — RooSync, conversations, dashboards
- `sk-agent` (Python) — Multi-modal, vision, documents

**Compatibilité :** OpenClaw/Claw Code peuvent connecter nos MCPs via le protocole standard. Agent Zero aussi (via Stdio/SSE).

**Sources:**
- [OpenClaw MCP Guide](https://launchmyopenclaw.com/openclaw-mcp-guide/)
- [Claw Code Overview](https://claw-code.codes/)
- [Agent Zero MCP Setup](https://github.com/agent0ai/agent-zero/blob/main/docs/mcp_setup.md)

---

### 3. Docker / Containerisation 🐳

| Variante | Docker natif | Sandboxing | Isolation | Commande |
|----------|-------------|-----------|-----------|----------|
| **OpenClaw** | ⚠️ Possible | ⚠️ Limité | Application-level | npm global install (pas container-first) |
| **Claw Code** | ❌ Non documenté | ❌ Non | ? | En développement |
| **NanoClaw** | ✅✅✅ **Natif** | ✅ **Docker Sandboxes** | MicroVM + container | `docker run nanoclaw` |
| **ZeroClaw** | ⚠️ Inconnu | ⚠️ Rust minimal | Hypothétique | Binary <5MB RAM |
| **Agent Zero** | ✅ Oui | ✅ Container isolation | Docker-first | `docker run -p 80:80 agent0ai/agent-zero` |

**NanoClaw — Champion containerisation :**
- **Architecture double-isolation :**
  - Layer 1: Chaque agent = 1 container (filesystem isolé)
  - Layer 2: Tous containers = 1 MicroVM (protection host)
- **Sécurité :** Credentials jamais dans container (OneCLI Agent Vault proxy)
- **Codebase minimal :** 15 files, ~700 lignes (auditable)
- **Partnership Docker officiel :** Docker Sandboxes intégration native

**Agent Zero — Docker-first :**
- Installation 1-liner Docker
- Web UI intégrée (port 80)
- Plugin system extensible

**Verdict :** **NanoClaw** est le leader sécurité containerisée (Docker Sandboxes MicroVM). **Agent Zero** est Docker-friendly mais moins radical. **OpenClaw** est npm-first (pas container-native).

**Sources:**
- [NanoClaw Docker Sandboxes](https://www.docker.com/blog/run-nanoclaw-in-docker-shell-sandboxes/)
- [NanoClaw Security Guide](https://nanoclaw.dev/blog/nanoclaw-docker-sandboxes/)
- [Agent Zero GitHub](https://github.com/agent0ai/agent-zero)

---

### 4. Patterns de harnais (orchestration, coordination, mémoire)

| Variante | Architecture | Patterns identifiés | Mémoire | Skills |
|----------|------------|-------------------|---------|--------|
| **OpenClaw** | Gateway + Skills + Tools | Multi-agent (Skills modulaires) | ? | ClawHub (3,200+ skills) |
| **Claw Code** | Autonomous workflows | Event-driven orchestration, recovery loops | Lanes state (machine-readable) | Rust/Python hybrid |
| **NanoClaw** | Groups + Containers | 1 group = 1 container + CLAUDE.md | Per-group CLAUDE.md | Minimal (sécurité > features) |
| **ZeroClaw** | Rust minimal | Deterministic (all-or-nothing) | Stateless | Ultra-léger (<10ms startup) |
| **Agent Zero** | Hierarchical multi-agent | Superior/subordinate delegation | Persistent auto-learning | SKILL.md standard ouvert |

**Agent Zero — Patterns Agentic Design (#843, #953) :**
- **Multi-Agent Collaboration :** Hiérarchie supérieur/subordonné (Gulli/Sauco Chapitre 7)
- **Computer as Tool :** Terminal natif + code execution (Chapitre 5)
- **Memory Management :** Mémoire persistante auto-apprenante (Chapitre 8)
- **Planning :** Décomposition de tâches prompt-driven (Chapitre 6)
- **100% prompt-driven :** Toute config dans `prompts/` (zéro hard-code)

**Claw Code — Autonomous workflows :**
- **Event-driven orchestration :** Parallel coding sessions
- **Recovery loops :** Résilience auto-correction
- **Machine-readable state :** Lanes state tracking

**NanoClaw — Simplicité radicale :**
- **1 group = 1 CLAUDE.md :** Mémoire isolée par container
- **Minimal features :** 15 files, 700 lignes (vs 512K lignes Claude Code original)

**Verdict :** **Agent Zero** implémente le plus de patterns Agentic Design. **Claw Code** a des workflows autonomes avancés. **NanoClaw** privilégie simplicité > features.

**Synergies avec RooSync :**

| Concept | RooSync actuel | Gap potentiel |
|---------|---------------|---------------|
| Skills System | `.claude/skills/` + `.roomodes` | **SKILL.md standard** (Agent Zero) = interop Claude/Codex/Goose |
| Mémoire | MEMORY.md + Qdrant + dashboards | **Auto-learning memory** (Agent Zero) = apprentissage passé |
| Prompts-driven | `.claude/rules/` + code | **100% prompts** (Agent Zero) = zéro hard-code |
| Container isolation | ❌ Non | **Docker Sandboxes** (NanoClaw) = sécurité renforcée |

**Sources:**
- [Agent Zero Documentation](https://github.com/agent0ai/agent-zero/tree/main/docs)
- [Claw Family Variants](https://medium.com/data-science-in-your-pocket/best-openclaw-variants-to-know-2aac9eb6bd6d)

---

### 5. Sécurité (isolation, audit trail, contrôle d'accès)

| Variante | Isolation | Credentials | Audit | Sandbox escape protection |
|----------|----------|------------|-------|--------------------------|
| **OpenClaw** | Application-level | Stockage local | Logs standard | ⚠️ Limité |
| **Claw Code** | ? | ? | ? | ⚠️ Non documenté |
| **NanoClaw** | **MicroVM + Container** | **Agent Vault (proxy)** | Per-container logs | ✅ **Double-layer** |
| **ZeroClaw** | Rust safety | ? | Deterministic | Hypothétique |
| **Agent Zero** | Container isolation | Env vars | Git-based projects | ✅ Workspace isolation |

**NanoClaw — Sécurité by Design :**
1. **Double isolation :**
   - Container : agents ne voient pas les données des autres
   - MicroVM : container escape ne touche pas l'host
2. **Credentials zero-trust :**
   - OneCLI Agent Vault injecte auth au niveau proxy
   - API calls sortent via proxy (rate limits + policies)
3. **Filesystem :** Montages explicites uniquement (pas d'accès global)
4. **Audit :** Logs par container, traçabilité complète

**Agent Zero — Git-based Projects :**
- Clone codebase dans workspace isolé
- Browser Agent (Playwright) sandboxé
- MCP connections auditables

**OpenClaw — Risques identifiés :**
- Application-level permissions (contournables)
- Pas d'isolation forte par défaut
- **NanoClaw** créé en réponse au "OpenClaw's security mess" ([The New Stack](https://thenewstack.io/nanoclaw-containerized-ai-agents/))

**Verdict :** **NanoClaw** est le champion sécurité. **Agent Zero** a une isolation correcte. **OpenClaw** nécessite hardening manuel.

**Sources:**
- [NanoClaw Docker Sandboxes Security](https://www.docker.com/blog/nanoclaw-docker-sandboxes-agent-security/)
- [The Register: NanoClaw Security](https://www.theregister.com/2026/03/13/nanoclaw_latches_onto_docker_sandboxes/)

---

### 6. Maturité / Communauté

| Variante | Stars GitHub | Activité | Documentation | Ecosystem |
|----------|-------------|----------|--------------|-----------|
| **OpenClaw** | 346K+ ⭐⭐⭐ | Très active | Extensive | 500+ MCP servers, ClawHub |
| **Claw Code** | 72K+ ⭐⭐ | Active (beta) | En cours | Communauté naissante |
| **NanoClaw** | ? ⭐ | Active | Bonne | Docker partnership |
| **ZeroClaw** | ? | ⚠️ Concept | Minime | Pas d'écosystème identifié |
| **Agent Zero** | ? ⭐ | Active | **Excellente** | A2A protocol, Skills standard |

**OpenClaw — Écosystème mature :**
- "Fastest-growing open-source project in history" (9K → 60K stars en jours)
- 50+ intégrations messaging (WhatsApp, Telegram, Slack, Teams, Discord...)
- ClawHub : 3,200+ skills
- 500+ MCP servers npm/GitHub

**Claw Code — Momentum fort :**
- "Fastest repo to 100K stars" (72K en premiers jours)
- Clean-room rewrite de Claude Code (après leak npm 512K lignes)
- Développé par "lobsters/claws" autonomes (meta-agentic)

**Agent Zero — Documentation best-in-class :**
- Docs structurées (Installation, Architecture, Extensions, Connectivity)
- SKILL.md standard ouvert (compatible Claude Code, Codex, Goose, Copilot)
- A2A protocol (Agent-to-Agent)
- code-execution-mcp repo dédié

**NanoClaw — Partnership Docker :**
- Docker Sandboxes intégration officielle
- Communauté sécurité-first
- Codebase minimal (auditable)

**ZeroClaw — Statut incertain :**
- Mentionné dans guides comparatifs
- Pas de repo GitHub public identifié
- Peut être un concept/vaporware

**Verdict :** **OpenClaw** a l'écosystème le plus mature. **Agent Zero** a la meilleure documentation. **Claw Code** a un momentum fort. **ZeroClaw** est incertain.

**Sources:**
- [OpenClaw Ultimate Guide 2026](https://skywork.ai/skypage/en/ultimate-guide-openclaw-github/2038544722909990912)
- [Claw Code Launch Press Release](https://www.24-7pressrelease.com/press-release/533389/claw-code-launches-open-source-ai-coding-agent-framework-with-72000-github-stars-in-first-days)

---

### 7. Pertinence pour nos 2 expériences

#### Expérience 2 : Web Explorer (sandboxed, recherche/synthèse)

**Besoin :**
- Accès web sandbox (Playwright)
- Recherche sémantique (SearXNG)
- Synthèse multi-sources
- **Sécurité critique** (exposition internet)

**Classement :**

| Variante | Score | Justification |
|----------|-------|--------------|
| **NanoClaw** | ⭐⭐⭐⭐⭐ | **Winner** — Docker Sandboxes MicroVM, isolation parfaite, Anthropic SDK (compatible Playwright MCP) |
| **Agent Zero** | ⭐⭐⭐⭐ | Browser Agent natif (Playwright intégré), Git-based projects, bonne isolation |
| **OpenClaw** | ⭐⭐⭐ | Multi-canal, écosystème riche, mais sécurité application-level |
| **Claw Code** | ⭐⭐ | En beta, sécurité non documentée |
| **ZeroClaw** | ⭐ | Statut incertain |

**Recommandation Exp. 2 :** **NanoClaw** avec Docker Sandboxes + MCP Playwright.

**Architecture proposée :**
```
Container NanoClaw
├── Anthropic SDK (agent core)
├── MCP Client → Playwright (browser automation)
├── MCP Client → roo-state-manager (reporting)
├── OneCLI Agent Vault (credentials SearXNG API, etc.)
└── Filesystem isolé (/workspace montage explicite)
```

**Avantages :**
- MicroVM = protection host contre exploits web
- Agent Vault = credentials jamais exposées au container
- Logs auditables par container
- Codebase minimal (700 lignes) = surface d'attaque réduite

#### Expérience 1 : Cluster Manager (gestion machines via MCPs)

**Besoin :**
- Intégration MCPs critiques (roo-state-manager, sk-agent)
- Multi-agent distribué
- Mémoire persistante cross-sessions
- Orchestration complexe

**Classement :**

| Variante | Score | Justification |
|----------|-------|--------------|
| **Agent Zero** | ⭐⭐⭐⭐⭐ | **Winner** — MCP natif (Stdio/SSE/HTTP), hiérarchie multi-agent, mémoire auto-apprenante, SKILL.md standard |
| **OpenClaw** | ⭐⭐⭐⭐ | Écosystème MCP 500+ servers, ClawHub skills, mais architecture npm-first |
| **Claw Code** | ⭐⭐⭐ | MCP complet (6 transports), mais beta + doc manquante |
| **NanoClaw** | ⭐⭐ | Trop minimaliste, MCP limité (SDK uniquement) |
| **ZeroClaw** | ⭐ | Statut incertain |

**Recommandation Exp. 1 :** **Agent Zero** comme framework agentique principal.

**Architecture proposée :**
```
Agent Zero (Docker)
├── MCP Client → roo-state-manager (RooSync, conversations, dashboards)
├── MCP Client → sk-agent (vision, documents, multi-modal)
├── MCP Server → expose Agent Zero aux autres clients (Claude Desktop, etc.)
├── Hierarchical agents (superior → subordinates)
├── Persistent memory (auto-learning)
└── SKILL.md standard (interop Claude Code, Codex, Goose)
```

**Avantages :**
- MCP natif 3 types (Stdio, SSE, HTTP) = connecte nos MCPs
- Hiérarchie multi-agent = patterns Agentic Design (#843)
- Mémoire auto-apprenante = apprentissage des solutions passées
- SKILL.md = interopérabilité avec notre `.claude/skills/`
- Docker-first = déploiement facile sur ai-01

**Synergies RooSync :**

| Concept RooSync | Équivalent Agent Zero | Action |
|----------------|---------------------|--------|
| `.claude/skills/` | SKILL.md standard | **Migrer vers SKILL.md** (interop Codex/Goose) |
| MEMORY.md + Qdrant | Mémoire auto-apprenante | **Évaluer** le système mémoire Agent Zero |
| `.claude/rules/` | `prompts/` 100% markdown | **Considérer** migration prompts-driven |
| RooSync dashboards | ? | **Connecter** via MCP roo-state-manager |

---

## Tableau de synthèse — 7 critères

| Critère | OpenClaw | Claw Code | NanoClaw | ZeroClaw | Agent Zero |
|---------|---------|-----------|---------|---------|-----------|
| **1. OpenAI-compatible (z.ai, vLLM)** | ✅ Multi-provider | ✅ Probable | ✅ Anthropic SDK | ⚠️ Inconnu | ✅ Oui |
| **2. MCP support** | ✅✅ 500+ servers | ✅✅ 6 transports | ⚠️ SDK limité | ❌ Inconnu | ✅ Natif (Stdio/SSE/HTTP) |
| **3. Docker / Containerisation** | ⚠️ npm-first | ❌ Non doc | ✅✅✅ **MicroVM** | ⚠️ Rust minimal | ✅ Docker-first |
| **4. Patterns harnais** | Skills modulaires | Event-driven workflows | Minimal (700 lignes) | Deterministic | ✅✅ Multi-agent hiérarchique |
| **5. Sécurité** | ⚠️ App-level | ❌ Non doc | ✅✅✅ **Agent Vault** | ⚠️ Rust safety | ✅ Container isolation |
| **6. Maturité / Communauté** | ✅✅✅ 346K stars | ✅✅ 72K stars | ✅ Docker partnership | ❌ Incertain | ✅✅ Doc excellente |
| **7A. Exp. 2 (Web Explorer)** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ **Winner** | ⭐ | ⭐⭐⭐⭐ |
| **7B. Exp. 1 (Cluster Mgr)** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐⭐⭐ **Winner** |

**Légende :**
- ✅✅✅ : Excellent
- ✅✅ : Très bon
- ✅ : Bon
- ⚠️ : Limité / Incertain
- ❌ : Absent / Non documenté

---

## Recommandations finales

### Déploiement immédiat

#### 1. **NanoClaw** pour Expérience 2 (Web Explorer) 🦞

**Pourquoi :**
- **Sécurité best-in-class :** Docker Sandboxes MicroVM (protection sandbox escape)
- **Credentials zero-trust :** Agent Vault proxy (jamais dans container)
- **Codebase auditable :** 15 files, 700 lignes (vs 512K lignes Claude Code)
- **Partnership Docker officiel :** Support long-terme garanti

**Installation :**
```bash
# Sur myia-ai-01
docker run -d \
  --name nanoclaw-web-explorer \
  -p 8082:80 \
  -v /data/nanoclaw/workspace:/workspace \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  qwibitai/nanoclaw:latest

# Connexion MCPs (via config Anthropic SDK)
# - Playwright (browser automation)
# - roo-state-manager (reporting RooSync)
```

**Reverse proxy IIS :** `nanoclaw.myia.io` → port 8082

**Limitations acceptées :**
- MCP support limité (Anthropic SDK uniquement) — mais Playwright + roo-state-manager suffisent pour Exp. 2
- Features minimales — mais sécurité > features pour exposition internet

#### 2. **Agent Zero** pour Expérience 1 (Cluster Manager) 🤖

**Pourquoi :**
- **MCP natif complet :** Stdio/SSE/HTTP (connecte roo-state-manager + sk-agent)
- **Multi-agent hiérarchique :** Patterns Agentic Design (#843)
- **Mémoire auto-apprenante :** Apprentissage solutions passées
- **SKILL.md standard :** Interopérabilité Claude Code, Codex, Goose
- **Docker-first :** Déploiement facile

**Installation :**
```bash
# Sur myia-ai-01
docker run -d \
  --name agent-zero-cluster \
  -p 8081:80 \
  -v /data/agent-zero/workspace:/workspace \
  -e OPENAI_API_BASE_URL=https://open.bigmodel.cn/api/paas/v4/ \
  -e OPENAI_API_KEY=$Z_AI_API_KEY \
  -e MODEL=glm-5-turbo \
  agent0ai/agent-zero:latest

# Configuration MCP (agent-zero/docs/mcp_setup.md)
# - roo-state-manager (Stdio)
# - sk-agent (Stdio)
```

**Reverse proxy IIS :** `agent-zero.myia.io` → port 8081

**Modèle LLM :** glm-5-turbo (z.ai) — Agentic Index 65.9, BrowseComp 75.9%

**Synergies RooSync à explorer :**
1. Migrer `.claude/skills/` → SKILL.md standard (interop)
2. Évaluer mémoire auto-apprenante vs Qdrant actuel
3. Connecter Agent Zero MCP Server → Claude Desktop (expose Agent Zero comme MCP)

### Investigations complémentaires (priorité basse)

#### 3. **Claw Code** (veille technologique)

**Pourquoi suivre :**
- Momentum communautaire fort (72K stars en jours)
- Rust/Python hybrid (performance)
- Autonomous workflows avancés (event-driven, recovery loops)

**Action :** Veille GitHub releases, attendre maturité beta → production

#### 4. **OpenClaw** (référence écosystème)

**Pourquoi suivre :**
- Écosystème MCP le plus riche (500+ servers)
- ClawHub skills (3,200+)
- Standard de facto multi-canal

**Action :** Tester skills OpenClaw compatibles avec Agent Zero SKILL.md

#### 5. **ZeroClaw** (concept incertain)

**Statut :** Pas de repo public identifié, mentionné uniquement dans guides comparatifs.

**Action :** Aucune jusqu'à clarification (possiblement vaporware ou concept de benchmark).

---

## Next Steps (Issues à créer)

### Issues deployment

1. **#NEW-1 :** Déployer NanoClaw (Web Explorer) sur myia-ai-01
   - Labels: `enhancement`, `experiment-2`, `security`
   - Priorité: HIGH
   - Étapes: Docker install, MCP config (Playwright, roo-state-manager), reverse proxy IIS

2. **#NEW-2 :** Déployer Agent Zero (Cluster Manager) sur myia-ai-01
   - Labels: `enhancement`, `experiment-1`, `roosync`
   - Priorité: HIGH
   - Étapes: Docker install, MCP config (roo-state-manager, sk-agent), glm-5-turbo config

3. **#NEW-3 :** Évaluer migration SKILL.md standard (Agent Zero)
   - Labels: `enhancement`, `architecture`, `investigation`
   - Priorité: MEDIUM
   - Étapes: Comparer `.claude/skills/` vs SKILL.md, tester interop Claude Code/Codex

4. **#NEW-4 :** Benchmark glm-5-turbo (z.ai) pour workloads agentiques
   - Labels: `enhancement`, `performance`
   - Priorité: MEDIUM
   - Étapes: BrowseComp, MCP-Atlas, τ²-Bench sur nos use cases

### Issues investigation (veille)

5. **#NEW-5 :** Veille Claw Code releases (beta → production)
   - Labels: `investigation`, `watching`
   - Priorité: LOW

6. **#NEW-6 :** Évaluer mémoire auto-apprenante Agent Zero vs Qdrant
   - Labels: `investigation`, `memory`
   - Priorité: LOW

---

## Risques identifiés

### Risque 1 : Fragmentation écosystème Claw

**Impact :** Communauté divisée entre OpenClaw, Claw Code, NanoClaw.

**Mitigation :** Adopter standards ouverts (MCP, SKILL.md) pour minimiser lock-in.

### Risque 2 : Maturité Agent Zero / NanoClaw

**Impact :** Moins de stars/communauté qu'OpenClaw.

**Mitigation :**
- NanoClaw : Docker partnership = support long-terme
- Agent Zero : Documentation excellente + A2A protocol standard

### Risque 3 : Sécurité OpenClaw

**Impact :** Application-level permissions contournables.

**Mitigation :** Ne PAS utiliser OpenClaw pour Exp. 2 (internet-facing). Réserver à use cases internes si déployé.

### Risque 4 : ZeroClaw vaporware

**Impact :** Temps perdu à investiguer un concept inexistant.

**Mitigation :** Aucune action avant clarification statut (repo public, documentation).

---

## Conclusion

L'écosystème Claw offre des solutions complémentaires :

- **NanoClaw** = champion sécurité containerisée (Exp. 2 Web Explorer)
- **Agent Zero** = champion framework agentique + MCP (Exp. 1 Cluster Manager)
- **OpenClaw** = référence écosystème mature (veille, skills)
- **Claw Code** = momentum fort (veille beta → production)
- **ZeroClaw** = statut incertain (ignorer jusqu'à clarification)

**Stratégie recommandée :**

1. **Déployer NanoClaw + Agent Zero immédiatement** (issues #NEW-1, #NEW-2)
2. **Évaluer SKILL.md standard** pour interop (issue #NEW-3)
3. **Benchmark glm-5-turbo** (z.ai) pour nos workloads (issue #NEW-4)
4. **Veille** Claw Code + OpenClaw skills (issues #NEW-5, #NEW-6)

Cette approche maximise sécurité (NanoClaw MicroVM), capabilities agentiques (Agent Zero multi-agent), et interopérabilité (standards ouverts MCP + SKILL.md).

---

## Sources

### Articles et guides
- [OpenClaw Ultimate Guide 2026](https://skywork.ai/skypage/en/ultimate-guide-openclaw-github/2038544722909990912)
- [10 GitHub Repositories to Master OpenClaw - KDnuggets](https://www.kdnuggets.com/10-github-repositories-to-master-openclaw)
- [Claw Code Launch Press Release](https://www.24-7pressrelease.com/press-release/533389/claw-code-launches-open-source-ai-coding-agent-framework-with-72000-github-stars-in-first-days)
- [Best OpenClaw Variants (Medium)](https://medium.com/data-science-in-your-pocket/best-openclaw-variants-to-know-2aac9eb6bd6d)
- [Claw Family Overview (DEV)](https://dev.to/0xkoji/a-quick-look-at-claw-family-28e3)

### Documentation technique
- [OpenClaw MCP Guide](https://launchmyopenclaw.com/openclaw-mcp-guide/)
- [OpenClaw MCP Integration](https://openclawblog.space/articles/openclaw-mcp-integration-guide-model-context-protocol)
- [Claw Code Overview](https://claw-code.codes/)
- [Agent Zero Documentation](https://github.com/agent0ai/agent-zero/tree/main/docs)
- [Agent Zero MCP Setup](https://github.com/agent0ai/agent-zero/blob/main/docs/mcp_setup.md)
- [Agent Zero code-execution-mcp](https://github.com/agent0ai/code-execution-mcp)

### Sécurité et containerisation
- [NanoClaw Docker Sandboxes (Docker Blog)](https://www.docker.com/blog/run-nanoclaw-in-docker-shell-sandboxes/)
- [NanoClaw Security Guide (Docker)](https://www.docker.com/blog/nanoclaw-docker-sandboxes-agent-security/)
- [NanoClaw Partnership Press Release](https://www.docker.com/press-release/nanoclaw-partners-with-docker-to-run-ai-agents-safely/)
- [NanoClaw Security (The Register)](https://www.theregister.com/2026/03/13/nanoclaw_latches_onto_docker_sandboxes/)
- [NanoClaw Containerized Agents (The New Stack)](https://thenewstack.io/nanoclaw-containerized-ai-agents/)

### Modèles et benchmarks
- [GLM-5 Overview (Z.ai)](https://docs.z.ai/guides/llm/glm-5)
- [GLM-5 Turbo Review](https://designforonline.com/ai-models/z-ai-glm-5-turbo/)
- [GLM-5 GitHub](https://github.com/zai-org/GLM-5)
- [GLM-5V-Turbo Launch (MarkTechPost)](https://www.marktechpost.com/2026/04/01/z-ai-launches-glm-5v-turbo-a-native-multimodal-vision-coding-model-optimized-for-openclaw-and-high-capacity-agentic-engineering-workflows-everywhere/)

### Repositories GitHub
- [OpenClaw](https://github.com/openclaw/openclaw)
- [Claw Code](https://github.com/ultraworkers/claw-code)
- [NanoClaw](https://github.com/qwibitai/nanoclaw)
- [Agent Zero](https://github.com/agent0ai/agent-zero)

---

**Dernière mise à jour :** 2026-04-05
**Prochaine révision recommandée :** Après déploiement NanoClaw + Agent Zero (3-4 semaines)
