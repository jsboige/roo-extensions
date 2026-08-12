# Architecture — Consolidation acquisition documentaire et analyse web

**Issue :** #494 `[ARCHITECTURE] Consolidation capacités acquisition documentaire et analyse web`
**Auteur :** Claude Code (myia-ai-01)
**Date :** 2026-08-12
**Statut :** Recommandation v1 (post-investigation ai-01 c.206)
**Périmètre :** 6 machines (myia-ai-01 coordinateur, myia-po-2023/24/25/26, myia-web1)

---

## TL;DR

**Aucun nouveau MCP `doc-processor` à créer.** Les briques existent, sont'opérationnelles, et l'écart
de l'issue #494 porte moins sur des trous techniques que sur **trois absences de surface** :

1. **Aucun routage canonique** : quel outil pour quel type de doc n'est pas documenté.
2. **Le plugin `markitdown-ocr` (LLM Vision OCR)** est mergé dans `mcps/external/markitdown/source/`
   mais **non déployé** sur les machines consommatrices (seul `markitdown` de base tourne).
3. **TikaService ai-01** est exposé **host-level** (`0.0.0.0:9917`) mais pas routé comme un service
   first-class : pas de binding systématique dans `sk_agent_config.json`, pas d'endpoint distant
   accessible aux machines `web1` et `po-2023..2026` (réseau OVH distinct).

**Recommandation principale :** un **doc d'orchestration** routant 5 cas d'usage vers 4 backends
existants, sans nouveau service. Étalement sur 2 incréments — (1) doc + bindings sk-agent,
(2) routeur fleet optionnel.

## 1. Périmètre d'investigation

Vérifications effectuées le 2026-08-12 sur myia-ai-01 + sources croisées (commentaire web1
du 2026-05-18, dashboard 2026-08-12 09:05, `sk_agent_config.json` réel).

### 1.1 Services réels (mesurés firsthand)

| Service | Statut ai-01 | Endpoint | Source vérifiée |
|---------|--------------|----------|-----------------|
| **Tika** (`open-webui-infra-tika-1`) | UP 8h+ | `0.0.0.0:9917 → 9998/tcp` (host) ; `apache-tika:9998` dans `open-webui-shared` | `docker ps` |
| **Qdrant** (`qdrant_production`) | UP 8h+ healthy | `http://localhost:6333` | `docker ps`, `curl /→200` |
| **Qwen3.6 35B MoE** (`vllm-medium-qwen36-moe`) | UP 8h+ healthy | `http://localhost:5002/v1` | `docker ps` |
| **zwz (Qwen3 8B VL finetuned)** | **NOT FOUND** | — | `docker ps --filter name=zwz` → 0 résultats |
| **Tesseract** | **NOT INSTALLED** | — | `where tesseract` → absent |
| **Pandoc** | **NOT INSTALLED** | — | `where pandoc` → absent |
| **GLM-4.6V (vision cloud)** | UP via z.ai | `https://api.z.ai/api/coding/paas/v4` | `sk_agent_config.json` |
| **Qwen3.6-35B local vision** | UP | `http://localhost:5002/v1` (`vision: true`) | `sk_agent_config.json` |
| **OWUI `vision-expert`** | UP | `http://localhost:2090/openai` | `sk_agent_config.json` |

**Distinction importante** : l'issue #494 mentionne `zwz (Qwen3 8B VL finetuned)` comme un container
distinct "aux performances excellentes". Ce container **n'est pas en cours d'exécution** sur ai-01
au 2026-08-12. Plusieurs hypothèses non vérifiées (arrêté, jamais déployé dans ce host, ou
présent ailleurs dans le cluster). **Action :** investigation `docker ps -a` + `grep zwz` dans
les autres machines avant de prévoir son exposition.

### 1.2 MCPs réels (déjà opérationnels)

| MCP | Outils | Hébergement | Notes |
|-----|--------|-------------|-------|
| **markitdown** | 1 | web1 + Roo (pyproject) | PDF/DOCX/PPTX/XLSX → Markdown |
| **markitdown-ocr** (plugin) | — | `mcps/external/markitdown/source/packages/markitdown-ocr/` | LLM Vision OCR ; **non déployé** sur les machines consommatrices |
| **searxng** | 2 | ai-01 (Docker searxng), routé par Roo | `searxng_web_search` + `web_url_read` |
| **playwright** | 23 | Claude + Roo | Automation web, screenshots |
| **sk-agent** | 9 outils + 32 agents dynamiques | ai-01 (container `sk-agent`) | `call_agent`, `list_agents`, `review_pr`, etc. |
| **jinavigator** (fork `mcp-jinavigator`) | n tools | web1 (Claude Code MCP) | `convert_web_to_markdown`, `access_jina_resource`, `multi_convert` |
| **open-terminal-mcp** | 1 | ai-01 (container `open-terminal-myia`) | `run_command` dans sandbox OWUI |

### 1.3 Agents sk-agent liés à l'acquisition (vérifiés dans `sk_agent_config.json`)

| Agent | Modèle | MCPs | Rôle pertinent |
|-------|--------|------|----------------|
| `analyst` | `glm-5.1` | searxng, playwright | Web search + browse |
| `vision-analyst` | `glm-4.6v` (cloud) | searxng | Vision cloud |
| `vision-local` | `qwen3.6-35b-a3b` (local) | — | **Vision locale 86 tok/s, 262K ctx** — VRAIE OCR locale |
| `owui-vision-expert` | `vision-expert` (OWUI proxy) | — | Multi-modal via OWUI |
| `manuscript-processor` | — | — | **NON EXISTE** — proposition issue #494 rejetée car open-terminal suffit |

## 2. Découvertes clés (ce que l'investigation a changé)

### 2.1 `markitdown-ocr` est la pièce manquante principale

`mcps/external/markitdown/source/packages/markitdown-ocr/` est un **plugin LLM Vision OCR** mergé
mais **jamais activé** dans les déploiements `markitdown` Roo. Il supporte nativement :

- PDF scanné (full-page OCR fallback par page, 300 DPI)
- DOCX, PPTX, XLSX avec images embarquées
- Toute API OpenAI-compatible (`llm_client` + `llm_model`)

**Implication :** la colonne "PDF scanné | Tesseract (partiel) | zwz + PaddleOCR" du tableau
initial de l'issue #494 est **fausse**. Tesseract n'est pas installé ; zwz n'est pas exposé ;
et `markitdown-ocr` LLM Vision couvre le cas d'usage **dès aujourd'hui** en s'appuyant sur
Qwen3.6 (local) ou GLM-4.6V (cloud) déjà configurés.

**Action recommandée (INC-1) :** déployer `markitdown-ocr` sur les machines Roo consommatrices
(markitdown tourne déjà sur ces machines, le plugin s'installe en adjonction).

### 2.2 Tika est déjà exposé host-level — pas de MCP à wrapper

Le commentaire web1 (c.2026-05-18) recommande d'exposer Tika via "API REST + MCP wrapper". Vérification
2026-08-12 : **Tika est déjà exposé** sur `0.0.0.0:9917` côté host. Le wrapper MCP n'est pas
nécessaire — il faudrait (a) l'exposer hors du host ai-01 (DNS + reverse proxy) ou (b) rester sur
l'accès direct depuis open-terminal-myia (qui est dans `open-webui-shared`).

**Action recommandée (INC-1bis) :** Tika routé via `open-terminal-myia` (clairement plus simple
que d'exposer un service Docker host sur le WAN). Le sandbox OWUI dispose de `curl`, `pdfplumber`,
`scikit-learn`, `pandas`, `ffmpeg` (cf. PNG intégré au commentaire LIVRESAGITÉS #73).

### 2.3 zwz n'est pas sur ai-01 actuellement

L'investigation `docker ps` ne trouve pas de container `zwz`. Le seul modèle Qwen tournant est
`qwen3.6-35b-a3b` (35B MoE AWQ, 86 tok/s, **vision+thinking**). Ce modèle **couvre la majorité
des cas d'usage OCR** avec une qualité supérieure à Tesseract et souvent comparable à un Qwen3 8B
VL spécialisé.

**Action :** ne pas présumer `zwz` comme dépendance. Si réapparition, ajouter dans sk-agent comme
`zwz-vl` (base_url dédié). Le `vision-local` actuel via `qwen3.6-35b-a3b` est l'option immédiate.

### 2.4 Pas de MCP `doc-processor` à créer

L'option 4 du tableau de l'issue propose un "MCP `doc-processor` unifié avec auto-détection".
**Pas recommandé** : c'est de la complexité (router, cache, type detection, fallbacks) sans
valeur ajoutée par rapport à un **mini-doc d'orchestration** qui dicte à l'agent quel tool
appeler en premier. L'agent a déjà la capacité de détecter `pdfplumber` empty → basculer sur
markitdown-ocr. Le routing est **stateless** et **sans cache** : pas d'état partagé qui
justifie un service.

### 2.5 `jinavigator` (Jina) doit rester, malgré le retrait de `web_reader`

Le tableau #2306/2210 a déclassé `web_reader` (routeur Claudish) au profit de `searxng
web_url_read` + prefix `r.jina.ai`. Mais `jinavigator` reste valide pour le **crawler multi-page**
(`multi_convert` tool). À conserver.

## 3. Recommandation d'architecture

### 3.1 Workflow unifié (pseudo-code agent)

```text
input: document URI (file://, http://, ou chemin local)

1. DÉTECTER type :
   - fichier local :
     * extension .pdf → pipeline PDF
     * extension .docx/.pptx/.xlsx → markitdown-native
     * extension .png/.jpg/.jpeg → vision direct
     * autre → marquerdown en fallback
   - URL http(s) → pipeline Web
   - chemin OCaml/Code → grep/read

2. ROUTER :
   ── PDF textuel (extractable text via pdfplumber > 0 char) :
      markitdown file.pdf
   ── PDF scanné (extractable text == 0 char) :
      markitdown file.pdf --use-plugins
        --llm-client openai --llm-model qwen3.6-35b-a3b
      (fallback cloud: --llm-model glm-4.6v)
   ── DOCX / PPTX / XLSX :
      markitdown file.docx (markitdown-ocr auto si images embarquées)
   ── Image (PNG/JPG) :
      sk-agent call_agent(agent="vision-local", message=<image>)
   ── URL :
      searxng_web_search (recherche préalable)
      → si page riche : searxng web_url_read(r.jina.ai prefix)
      → si single page simple : playwright snapshot + markdown_extract
      → si multi-page crawler : jinavigator multi_convert
   ── Document mixte (PDF + images + tableaux) :
      open-terminal-myia run_command (sandbox Python) :
      - curl -T $FILE http://apache-tika:9998/tika (texte principal)
      - markitdown $FILE --use-plugins (images)
      - concaténer en markdown structuré

3. RETOUR : Markdown structuré, prêt pour analyse (LLM downstream ou indexation Qdrant)
```

### 3.2 Tableau de routage canonique (livrable principal)

| Type doc | Backend principal | Backend fallback | MCP/agent de routage |
|----------|-------------------|------------------|----------------------|
| PDF textuel | markitdown | tika via open-terminal | `markitdown` MCP |
| PDF scanné | markitdown-ocr (llm=qwen3.6-35b-a3b) | tika via open-terminal | `markitdown` MCP + plugin |
| DOCX/PPTX/XLSX | markitdown (markitdown-ocr auto si images) | tika + open-terminal | `markitdown` MCP |
| Image (PNG/JPG) | sk-agent `vision-local` (qwen3.6-35b-a3b) | sk-agent `vision-analyst` (glm-4.6v cloud) | `sk-agent` MCP |
| URL single | searxng `web_url_read` (r.jina.ai prefix) | playwright snapshot | `searxng` MCP |
| URL multi-page | jinavigator `multi_convert` | searxng + playwright | `jinavigator` MCP |
| Document complexe/OCR-lourd | open-terminal-myia `run_command` | tika via open-terminal | `open-terminal` MCP |
| Web search | searxng `web_search` | — | `searxng` MCP |

### 3.3 Bindings sk-agent (INC-1)

Ajouter 2 entrées dans `mcps/internal/servers/sk-agent/sk_agent_config.json` (et sa version
template) :

```json
{
  "id": "tika",
  "description": "Apache Tika service for heavy document OCR (host-level, accessible via open-terminal sandbox)",
  "command": "python",
  "args": ["../open-terminal-mcp/open_terminal_mcp.py"],
  "env": {
    "OPEN_TERMINAL_URL": "http://open-terminal-myia:8000",
    "TIKA_BASE_URL": "http://apache-tika:9998"
  }
},
{
  "id": "markitdown_ocr",
  "description": "Markitdown with LLM Vision OCR plugin (PDF scan, DOCX/PPTX/XLSX images)",
  "command": "markitdown",
  "args": ["--use-plugins", "--llm-client", "openai", "--llm-model", "qwen3.6-35b-a3b"]
}
```

**Note pratique :** `markitdown-ocr` est un plugin Python, pas un service. Le binding ci-dessus
est un *alias* documentant le routage ; l'invocation effective reste `markitdown --use-plugins
--llm-client ... <file>` par l'agent. Le but est de **rendre la connaissance du routage
explicite dans le config sk-agent**, pas de re-créer un serveur.

### 3.4 Connectivité fleet (INC-2 — optionnel)

**Question :** Les machines `web1` et `po-2023..2026` peuvent-elles atteindre ai-01:9917 (Tika) ou
ai-01:5002 (Qwen3.6) en direct ?

**Réponse mesurée :** web1 (OVH, réseau distinct) **ne peut pas** atteindre les services host
d'ai-01 sauf via reverse-proxy. Les machines `po-*` (LAN) dépendent de la topologie.

**Recommandation :** ne pas exposer Tika/Qwen3.6 sur le WAN OVH. Pour `web1`, le routing
recommandé est d'**utiliser `searxng` prefix r.jina.ai ou `playwright`** (déjà opérationnels) pour
le contenu web, et d'**invoquer sk-agent MCP en HTTP** pour les workloads lourds (vision).

**Action sk-agent HTTP (à investiguer) :** container `sk-agent` expose-t-il un endpoint HTTP ?
Si non, INC-2 = ajouter un bridge. **Pas dans l'INC-1** pour éviter le scope creep.

## 4. Spécification MCP unifié — analyse et rejet

L'option 4 du tableau propose un MCP `doc-processor` unifié. **Rejet argumenté** :

| Critère | MCP unifié | Doc d'orchestration (recommandé) |
|---------|-----------|----------------------------------|
| Complexité | Élevée (router + cache + fallbacks) | Faible (5 lignes dans ce fichier) |
| État partagé | Nécessaire (cache, métadata) | Aucun |
| Latence ajoutée | ≥ 1 hop réseau | Aucun |
| Maintenance | Continue (suivi des backends) | Quasi nulle (référence) |
| Couverture | Identique | Identique |
| Risque régression | Élevé (cache invalidé, fallbacks cascadent) | Faible (routing local à l'agent) |

**Conclusion :** le MCP unifié ne résout aucun problème que la doc ne résout plus simplement.

## 5. Plan de déploiement par incrément

### INC-1 (court terme — 1 à 2 cycles)

**Livrables :**
- [ ] Ce document mergé dans `docs/architecture/`
- [ ] Bindings sk-agent (template + sync) pour `tika` et `markitdown_ocr` (3.3)
- [ ] Déploiement `markitdown-ocr` plugin sur machines Roo qui ont déjà `markitdown`
      (web1 + 4 po-*) — une commande `pip install -e
      mcps/external/markitdown/source/packages/markitdown-ocr/` par machine
- [ ] Validation sur 1 cas d'usage réel (ex: scanner un PDF scanné de 10 pages)

**Critères de succès :**
- Document de routage accessible à tous les agents
- Routage effectif sans intervention manuelle (suivi patrouille dashboard)
- Au moins 1 cas d'usage bout-en-bout validé sur web1 (côté light) + ai-01 (côté heavy)

### INC-2 (moyen terme — après stabilisation INC-1)

**Livrables conditionnels :**
- [ ] Investigation `docker ps -a` + `grep zwz` pour clarifier le statut de zwz (s'il existe ailleurs)
- [ ] Endpoint HTTP sk-agent si pas déjà exposé (vérif + éventuellement bridge)
- [ ] Routage fleet-wide web1 → ai-01 via sk-agent HTTP (si INC-1 démontre la demande)

**Critères de succès :**
- Latence bout-en-bout web1 < 30 s pour un PDF scanné 10 pages
- Pas de nouvelle dépendance externe (tout est interne au cluster)

### INC-3 (refus / reporté)

- ❌ MCP `doc-processor` unifié — pas de valeur démontrée
- ❌ `zwz` (Qwen3 8B VL finetuned) en tant que dépendance — pas présent, à ré-inventorier
- ❌ PaddleOCR — la LLM Vision OCR (qwen3.6-35b-a3b) couvre les cas d'usage ; PaddleOCR apporterait
       de la complexité binaire (wrapper Python, installation) sans gain observable

## 6. Vérification croisée (scepticisme protocol)

| Affirmation | Source | Vérification | Statut |
|--------------|--------|--------------|--------|
| "zwz container présent sur ai-01" | Issue #494 (description initiale) | `docker ps --filter name=zwz` → 0 résultats | **RAPPORTÉ PAR USER, infirmé** |
| "Tika accessible depuis open-terminal" | Commentaire user 2026-03-04 LIVRESAGITÉS #73 | `docker ps` : `open-terminal-myia` + `open-webui-infra-tika-1` sur `open-webui-shared` | **VERIFIÉ** |
| "markitdown-ocr plugin existe" | Codebase search | `mcps/external/markitdown/source/packages/markitdown-ocr/README.md` | **VERIFIÉ firsthand** |
| "markitdown-ocr déployé sur machines consommatrices" | À confirmer | pas de trace d'install sur web1/po-* dans le repo | **SUPPOSÉ non** |
| "Qwen3.6 35B vision OK" | sk-agent config | `qwen3.6-35b-a3b` `vision: true` ; container up | **VERIFIÉ** |
| "Tesseract installé partiellement" | Issue #494 | `where tesseract` → absent | **INFIRMÉ** |

## 7. Sources et liens

- Issue #494 + 4 commentaires (2006-03-04 LIVRESAGITÉS, 2026-03-24 dispatch BACKLOG, 2026-05-02 backlog-sweep, 2026-05-18 web1 investigation)
- `mcps/external/markitdown/source/packages/markitdown-ocr/README.md` (plugin LLM Vision OCR)
- `mcps/internal/servers/sk-agent/sk_agent_config.json` (bindings agents + modèles)
- `~/roo-extensions/.claude/worktrees/wt-bump-976` (PR #976 fix [NOTIF] — contexte dashboard)
- Dashboard workspace 2026-08-12 09:05 (status flotte, blockers en cours)

---

**Action immédiate :** review de ce document, merge INC-1, puis déploiement `markitdown-ocr`+
bindings sk-agent. INC-2 (sk-agent HTTP + fleet routing) en discussion si demande web1 émerge.
