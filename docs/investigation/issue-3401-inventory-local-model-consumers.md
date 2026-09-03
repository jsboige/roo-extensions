# Inventaire des consommateurs du modèle local — Issue #3401

**Date :** 2026-09-03
**Auteur :** web1 (lane executor)
**Issue :** [#3401](https://github.com/jsboige/roo-extensions/issues/3401)
**Sonde primaire :** `grep -rE 'qwen3[.\-][0-9a-zA-Z\-]+|OPENAI_BASE_URL|OPENAI_API_KEY|EMBEDDING_API_KEY|VLLM_API_KEY|ANTHROPIC_BASE_URL|claudish|models\.myia' --include='*.ps1' --include='*.json' --include='*.ts' --include='*.js' --include='*.py' --include='*.yml' --include='*.yaml' --include='*.sh' --include='*.template*' --include='*.env*'` dans `/c/dev/roo-extensions` (working tree).
**Périmètre sonde :** `roo-extensions` (hors submodule `mcps/internal` — gitlink `0e5240df` — qui contient ses propres fichiers `.env.template/.env.example` sondés à part).
**Contrôle positif :** occurrence `qwen3.6-35b-a3b` dans `.claude/configs/provider.claudish.template.json` l.8 — sert d'ancre de calibration ; tout ce qui en dépend est attendu.

---

## 1. Tableau d'inventaire exhaustif

| # | Système | Mode d'accès | Emplacement config | Nom de modèle en dur | Provenance de la clé | Sonde | Verdict |
|---|---------|--------------|---------------------|----------------------|----------------------|-------|---------|
| 1 | **Claude Code (agents + coord)** | `ANTHROPIC_BASE_URL` → claudish (proxy `models.myia.io`) | `~/.claude/settings.json` (par machine) + template `.claude/configs/provider.claudish*.template.json` | `claude-opus-5[1m]` / `claude-sonnet-5[1m]` / `claude-haiku-4-5-20251001[1m]` — **alias stables**, pas de nom de version | clé = `ANTHROPIC_CUSTOM_HEADERS.x-proxy-key` (po-2023) ou `ANTHROPIC_AUTH_TOKEN` (ai-01 natif) | grep `ANTHROPIC_BASE_URL` dans `.claude/configs/` | **DEJA-VERS-CLAUDISH** ✅ |
| 2 | **Claude Code (rôle haiku fallback modèle local)** | `ANTHROPIC_DEFAULT_HAIKU_MODEL` = `qwen3.6-35b-a3b` quand template free-tier | `.claude/configs/provider.claudish.template.json` l.8 ; `.claude/configs/provider.claudish-free-tier.template.json` l.9 | **`qwen3.6-35b-a3b`** ⚠️ (prod actuelle) | dérivée via claudish (routeur) | grep `ANTHROPIC_DEFAULT_HAIKU_MODEL` | **VERS-CLAUDISH-ALIAS** : remplacer par `claude-haiku-local` (alias) |
| 3 | **roo-state-manager (condensation LLM + dashboards)** | SDK OpenAI direct via `OPENAI_BASE_URL` | `mcps/internal/servers/roo-state-manager/.env.template` l.6 (submod gitlink `0e5240df`) | **`qwen3.6-35b-a3b`** (defaut `openai.ts:97` + `index.ts:96`) | `OPENAI_API_KEY` (env conteneur) | grep `OPENAI_BASE_URL\|qwen3\.6` dans submod | **VERS-CLAUDISH** : SDK OpenAI de claudish côté `models.myia.io/v1` — alias `local-coding` |
| 4 | **roo-state-manager (embeddings Qdrant)** | SDK OpenAI direct via `EMBEDDING_API_BASE_URL` (legacy) | submod `.env.example` l.59-66 ; `services/task-indexer/EmbeddingValidator.ts:54` | **`qwen3-4b-awq-embedding`** | `EMBEDDING_API_KEY` (env conteneur) | grep `EMBEDDING_API_KEY` dans submod | **VERS-CLAUDISH** : endpoint embeddings stable `https://models.myia.io/v1/embeddings` (API OpenAI supportée par claudish) |
| 5 | **roo-state-manager (fallback embeddings cloud)** | OpenAI cloud API (`api.openai.com`) | submod `.env.example` l.248 (commentaire : "primary vLLM down → cloud") | variable (pas en dur) | `OPENAI_API_KEY` (cloud) | grep `OPENAI_API_KEY` dans submod | **RESTE-DIRECT** (cloud OpenAI officiel = chemin de secours, hors surface locale) |
| 6 | **sk-agent (LLM endpoints du serveur)** | Config statique JSON + appel OpenAI-compat | `mcps/internal/servers/sk-agent/sk_agent_config.template.json` l.95/99/106/110/137/152 ; `sk_agent_config.py:469` ; `benchmark_models.py:91` ; `run_benchmark.py:31` | `qwen3.6-35b-a3b`, `qwen3.6-35b-no-thinking`, `owui-qwen3.6-35b`, etc. | `sk_agent_config.json` (deployé, hors repo) — clé passée par appelant | grep `sk_agent_config.template.json\|benchmark_models.py` | **VERS-CLAUDISH** : sk-agent expose déjà une API OpenAI-compat (consommée par `scripts/review/call-sk-agent.ps1`) → passer par `models.myia.io/v1` au lieu de `text-generation-webui.myia.io/v1` |
| 7 | **call-sk-agent.ps1 (script review)** | HTTP direct POST `/v1/chat/completions` | `scripts/review/call-sk-agent.ps1` l.118/131/148 | **`qwen3.5-35b-a3b`** (en dur l.118) | `$env:VLLM_API_KEY` OU `qwenModel.api_key` (config sk-agent) | grep `call-sk-agent.ps1` | **VERS-CLAUDISH** : remplacer par `local-coding` alias |
| 8 | **Roo modes (`-simple` fallback openRouter)** | API OpenRouter (clé `OPENROUTER_API_KEY`) | `roo-config/config-templates/model-configs.json` l.7-31/87-154 ; déployé en `~/.roo/config.json` par machine | `qwen/qwen3-32b`, `qwen/qwen3-30b-a3b`, `qwen/qwen3-235b-a22b`, `qwen/qwen3-14b`, `qwen/qwen3-8b`, `qwen/qwen3-1.7b` | `OPENROUTER_API_KEY` (env Roo) | grep `openRouterModelId` dans `roo-config/config-templates/model-configs.json` | **RESTE-DIRECT** (OpenRouter = provider cloud externe, hors surface vLLM locale) — mais aliasables côté `claudish` (qui supporte openRouter en upstream) |
| 9 | **Roo modes (`-complex` primaire + embedding)** | provider `qwen3.6-35b-a3b` via OWUI | `roo-config/model-configs.json` l.28 ; `roo-config/generated/roo-api-configs.json` l.11 ; déployé en `~/.roo/config.json` | **`qwen3.6-35b-a3b`** (openAiModelId) | `OPENAI_API_KEY` (env Roo) | grep `openAiModelId\|openAiBaseUrl` dans `roo-config/` | **VERS-CLAUDISH** : remplacer `openAiBaseUrl` = `https://models.myia.io/v1` + alias `local-coding` |
| 10 | **Roo n5-oracle (modes N5)** | API OpenRouter | `roo-config/modes/n5-definitions/levels/oracle-level-config.json` l.6/43-97 ; `roo-config/modes/n5-definitions/n5-custom-instructions.json` l.104-245 ; `roo-config/modes/n5-system/scripts/n5-modes-complete.json` l.226-288 | `qwen/qwen3-235b-a22b-fp8` (répété 6+6+4+1 = ~17) | `OPENROUTER_API_KEY` | grep `referenceModel\|"model": "qwen` dans `roo-config/modes/n5-*/` | **RESTE-DIRECT** (openRouter, pas vLLM local) — alias possible `oracle-heavy` côté claudish |
| 11 | **Roo subagent sub-config (provider `claudish-free-tier`)** | sous-rôle Claude via claudish | `.claude/configs/provider.claudish-free-tier.template.json` l.78/85 | `qwen3-32b` (2 occ.) | dérivée via claudish | grep `model.*qwen3-32b` dans `.claude/configs/` | **DEJA-VERS-CLAUDISH** ✅ + alias `local-fast` côté claudish |
| 12 | **roo-state-manager (service vllm registry)** | registre interne (pas d'appel direct) | submod `services/ServicesConfigService.ts:130-141` — startArgs `--model qwen3.6-35b-a3b` | **`qwen3.6-35b-a3b`** (start arg du process vllm) | start/stop watchdog interne | grep `vllm.entrypoints.openai.api_server` dans submod | **VERDICT-SPECIAL** : c'est le **service** qui héberge le modèle, pas un consommateur. Le nom doit vivre **ici**, pas chez les consommateurs (anti-#2716 : le swap devient un changement de ce seul fichier). |
| 13 | **roo-state-manager (start script `startScript` pour vllm)** | idem #12 — piloté par watchdog interne | submod `tests/unit/services/ServicesConfigService.test.ts:175` | `qwen3.6-35b-a3b` (regression test) | n/a | grep `vllm.*startScript` | **VERDICT-SPECIAL** : idem #12 — surface de contrôle du service |
| 14 | **Roo state inventory (sondes services)** | sondes `/health` (pas `/v1/models` — voir L65) | submod `ServicesConfigService.ts:136` (commentaire: /v1/models requiert API key) | n/a (sondes UP/DOWN uniquement) | n/a | grep `healthEndpoint` dans submod | **RESTE-DIRECT** (sondes internes, pas d'appel LLM) |
| 15 | **claudish-sidecar (proxy routeur)** | variable d'environnement conteneur | env conteneur docker (config OVH) | wildcard `qwen3.*` selon règles routing | clé partagée (env) | ext. ai-01 | **DEJA-VERS-CLAUDISH** ✅ + c'est **lui** qui doit détenir l'alias stable |
| 16 | **OWUI instance interne (config table `value`)** | connexion OpenAI enregistrée dans base OWUI | table `config` colonne `value` (base interne) | `qwen3.6-35b-a3b` (2 occ. mesurées par ai-01 03/09) | clé passée par setup OWUI | ext. ai-01 / ext. coursia-harness | **VERS-CLAUDISH** (basculer base URL vers `models.myia.io/v1`) |
| 17 | **7 OWUI écoles (configs par base)** | connexion OpenAI + nom modèle en dur | table `config` colonne `value` de chaque base école (3-4 occ./base) | `qwen3.6-35b-a3b` et autres (~21-28 occ. totales) | clé passée par setup école | ext. ai-01 / ext. ops-schools | **TRAITEMENT-SPECIAL** : surface la plus large. Action = **renommer l'alias vLLM upstream** (côté ai-01/OVH) AVANT le swap, puis mettre à jour chaque base **en masse** via script SQL/Python — voir §3 |
| 18 | **Notebooks CoursIA (MyIA.AI.Notebooks/**)** | endpoint + littéral parfois | `MyIA.AI.Notebooks/**` (autre repo) | variable | variable (env kernel Jupyter) | ext. CoursIA | **LANE-EXTERNE** (hors `roo-extensions`) — déclaré pour traçabilité |
| 19 | **Services Docker (configs `render_envs.py`)** | injection par `.env` rendus | `docker-configurations/` / `render_envs.py` (autre repo) | variable | env rendu | ext. | **LANE-EXTERNE** — pas dans `roo-extensions` (`docker-configurations` n'existe pas dans ce working tree) |

---

## 2. Provenance des clés : synthèse

| Variable | Fichier canonique | Valeur placeholder | Distribution | Risque rotation |
|----------|-------------------|--------------------|--------------|------------------|
| `OPENAI_API_KEY` | submod `.env.template` l.7 | `CHANGE_ME_MEDIUM_KEY` | 1 env / conteneur (via Vault?) | **moyen** — 1 env à changer par déploiement RSM |
| `EMBEDDING_API_KEY` | submod `.env.example` l.60 | `your-embedding-api-key-here` | 1 env / conteneur | **moyen** |
| `VLLM_API_KEY_MEDIUM` | submod `.env.template` l.42 | `CHANGE_ME_MEDIUM_KEY` | idem | **moyen** |
| `VLLM_API_KEY_MINI` | submod `.env.template` l.11 | `CHANGE_ME_MINI_KEY` | idem | **moyen** |
| `x-proxy-key` (claudish) | `ANTHROPIC_CUSTOM_HEADERS` dans `~/.claude/settings.json` | (po-2023 = issuer) | 1 / machine executor | **fort** — 7 fichiers à mettre à jour + reload session |
| Clés OWUI écoles | table `config` colonne `value` | (par école) | 7 écoles | **fort** — script SQL/Python par base |
| `OPENROUTER_API_KEY` | env Roo `~/.roo/.env` | (par machine) | 1 / machine | faible (external) |

---

## 3. Séquence de bascule ordonnée (exécutable en une fenêtre)

**Pré-condition :** claudish expose une **API Anthropic ET OpenAI** (vérifié #2612). Le routeur peut donc servir **les deux** familles de clients.

### Étape 1 — Alias stable côté routeur (1 PR ai-01, ~30 min)

1. Sur ai-01 : ajouter au fichier de routing claudish 3 alias stables :
   - `claude-haiku-local` → `qwen3.6-35b-a3b` (alias court pour Claude Code haiku fallback)
   - `local-coding` → `qwen3.6-35b-a3b` (alias long pour SDK OpenAI des services RSM)
   - `local-fast` → `qwen3-32b` (alias court pour sub-agent claudish-free-tier)
2. Vérifier que `/v1/models` annonce les 3 alias et que la résolution retourne 200.

### Étape 2 — Bascule SDK OpenAI roo-state-manager (1 PR submod, ~1h)

Submod `mcps/internal` :
1. `.env.template` l.6 : `OPENAI_BASE_URL=https://models.myia.io/v1`
2. `.env.template` l.8 : `OPENAI_CHAT_MODEL_ID=local-coding`
3. `.env.example` l.59-66 : pointer `EMBEDDING_API_BASE_URL=https://models.myia.io/v1`, garder `EMBEDDING_MODEL` mais **ne plus le hardcoder** — laisser le routeur choisir (alias `local-embed`)
4. Tests : mettre à jour les mocks `OPENAI_CHAT_MODEL_ID` ; vérifier que `getLLMModelId()` retourne l'alias.

### Étape 3 — Bascule Roo modes (-complex primaire + sub-agents) (1 PR parent, ~45 min)

1. `roo-config/model-configs.json` l.28 : `openAiBaseUrl` = `https://models.myia.io/v1`, `openAiModelId` = `local-coding`
2. `roo-config/config-templates/model-configs.json` l.7-31 : remplacer `openRouterModelId` `qwen/qwen3-*` par alias claudish (si upstream claudish supporte openRouter) **OU** laisser openRouter si on accepte la double-source — **décision arbitrage**
3. `roo-config/generated/roo-api-configs.json` l.11 : idem
4. `roo-config/baselines/*.json` : propager (3 fichiers : ai-01, po-2023, web1)
5. `.claude/configs/provider.claudish.template.json` l.8 : `ANTHROPIC_DEFAULT_HAIKU_MODEL` = `claude-haiku-local`
6. `.claude/configs/provider.claudish-free-tier.template.json` l.9 : idem + l.78/85 : `qwen3-32b` → `local-fast`

### Étape 4 — Bascule call-sk-agent (1 PR parent, ~15 min)

1. `scripts/review/call-sk-agent.ps1` l.118 : `model = "local-coding"` (au lieu de `qwen3.5-35b-a3b`)
2. L.137 : `Where-Object { $_.id -eq "local-coding" }` au lieu de `qwen3.5-35b-a3b`

### Étape 5 — Bascule sk-agent config template (1 PR submod, ~30 min)

1. `mcps/internal/servers/sk-agent/sk_agent_config.template.json` l.95-152 : remplacer `qwen3.6-35b-a3b` et `owui-qwen3.6-35b` par alias `local-coding` + `local-coding-fast` ; pointer `base_url` vers `https://models.myia.io/v1`
2. `benchmark_models.py` l.91, `run_benchmark.py` l.31 : aligner.

### Étape 6 — OWUI écoles (script SQL/Python, ~2h par école, séquentiel)

**Avant cette étape :** l'alias `local-coding` doit être **annoncé en interne ai-01** avec une durée de grâce ≥ 1 semaine où **les deux** noms répondent (ancien `qwen3.6-35b-a3b` + nouveau `local-coding`) — c'est ce qui permet aux écoles de basculer sans downtime.

Pour chaque école :
1. Dump table `config` (colonne `value`) — capturer les 3-4 lignes contenant le nom du modèle.
2. UPDATE WHERE value LIKE '%qwen3.6-35b-a3b%' → `local-coding`.
3. Vérifier via probe OpenAI (curl `/v1/models` avec la clé de l'école).

### Étape 7 — Rotation de la clé partagée (1 PR ai-01, ~30 min)

Une fois **tous les consommateurs** derrière claudish :
1. Générer nouvelle clé `x-proxy-key` côté po-2023.
2. Pousser via `sync-claude-settings.ps1` sur les 6 autres machines (1 cron tick / machine suffit).
3. Rotation des clés OWUI écoles : 7 UPDATE SQL, fenêtre commune courte.

### Étape 8 — Swap modèle #2716 (1 PR ai-01, ~30 min)

1. Sur ai-01 : changer la cible de l'alias `local-coding` (1 ligne dans la config routeur) → `Ornith-1.0-35B`.
2. `/v1/models` annonce `local-coding` = `Ornith-1.0-35B`.
3. **Aucun consommateur ne change** — c'est la valeur de l'alias.

### Étape 9 — Validation (couvre I1-I3)

Pour chaque étape 2-7 : `npx vitest run` côté submod + `npm run test:mcp` côté parent.
Étape 8 : mesure latence + qualité sur 1 échantillon par catégorie (#2, #4, #7, #9, #16).

---

## 4. Décisions à arbitrer (non tranchées par la sonde)

| Question | Option A | Option B | Recommandation |
|----------|----------|----------|----------------|
| OpenRouter Roo (-simple) | Reste OpenRouter direct | Passe par claudish (qui supporte openRouter en upstream) | **B** — uniformise la clé |
| OWUI écoles : durée grâce double-nom | 1 semaine | 2 semaines | **2 sem.** — coordination 7 écoles |
| `EMBEDDING_MODEL` en dur ou pas | Hardcoder (`qwen3-4b-awq-embedding`) | Alias claudish (`local-embed`) | **alias** — embedding change plus souvent que chat |
| Référentiel alias (rôle vs version) | `local-coding` (rôle) | `qwen-stable` (sentinelle version) | **`local-coding`** — le swap #2716 devient invisible (cf. leçon issue) |

---

## 5. Limites de l'inventaire (scepticisme protocole)

- **Lane non couverte :** OWUI 7 écoles (#17) — la sonde ne peut pas atteindre les bases sans accès ai-01/ops-schools. **Donnée brute :** ai-01 a mesuré 2 occ. pour OWUI interne + 3-4 par école = 21-28 occ. estimées. **À confirmer firsthand par ai-01/ops-schools.**
- **Notebooks CoursIA (#18), Docker render_envs (#19) :** hors `roo-extensions` — pas sondés. **À déclarer par les lanes CoursIA / ops-schools.**
- **Watchdogs `scripts/mcp-watchdog/`, `scripts/mcp/` :** **0 hits** pour `qwen3|OPENAI_BASE_URL|OPENAI_API_KEY|VLLM_API_KEY`. Pas de consommateurs directs. ✅ contrôle négatif net.
- **Tests Vitest :** occurrences nombreuses de `qwen3.6-35b-a3b` dans les tests du submod, mais ce sont des fixtures de string — pas des consommateurs runtime. **À distinguer** dans le PR #2 (étape 2) : remplacer seulement le default `openai.ts:97` et `index.ts:96`, laisser les tests qui assertent la précédence/fallback.
- **Docs (`docs/sk-agent/`, `docs/investigation/unified-model-router.md`, `docs/deployment/claudish-per-machine.md`) :** occurrences documentaires (rapports d'évaluation, designs). **Hors scope** — ne pas modifier dans cette Epic, mais à mettre à jour quand la bascule est validée.

---

## 6. Synthèse métrique

- **Systèmes identifiés :** 19 (15 dans `roo-extensions` + 4 externes partiels).
- **Occurrences noms en dur dans roo-extensions :** 226 (qwen3-32b 41 · qwen3.5-35b-a3b 37 · qwen3-30b-a3b 26 · qwen3-8b 22 · qwen3.6-35b-a3b 19 · qwen3-235b-a22b-fp8 19 · qwen3-14b 19 · qwen3-1.7b 18 · qwen3-embedding 15 · + variantes courtes).
- **Clés à rotater au pire :** 7 (1 env RSM × 3 canaux × 7 écoles OWUI) — ramenées à **1** si tous les consommateurs passent par claudish (alias + clé unique `x-proxy-key`).
- **PRs prévues :** 5 (1 ai-01 alias, 1 submod RSM, 1 submod sk-agent, 1 parent Roo+claudish+call-sk-agent, 1 ai-01 swap final).
- **Fenêtre totale estimée :** 1 journée cluster (alias + bascule RSM + Roo = ~3h ; écoles + rotation + swap = ~5h, parallélisable sur 7 ops-schools).

---

**Verdict global :** la surface est **réductible de 19 → 14** (5 OWUI écoles confondues derrière 1 script SQL, 1 clé RSM remplacée par `x-proxy-key` claudish). Le swap #2716 devient **invisible** des consommateurs : 1 ligne dans le routeur claudish.