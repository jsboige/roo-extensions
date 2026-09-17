# Inventaire des consommateurs du modèle local — Issue #3401

**Date :** 2026-09-03 · **Dernière rév. :** 2026-09-17 (§8 — re-mesure du gate po-203 : alias `local-coding`/`local-fast` désormais **annoncés sur les DEUX catalogues** (local + hub po-2025), mais complétion **401** spécifique aux alias — blocage déplacé de « non déployé » vers « résolution hub cassée » ; précédente 2026-09-15 : §7.1 qualifiée **instances de siège** avec mapping vers les systèmes §1, ligne doublon du système #7 retirée, coordonnées du défaut alignées sur la mesure fraîche `openai.ts:102`/`index.ts:97` en §1/§5 — po-2024 ; 2026-09-14 : lane po-2024 §7 — déclaration de siège + re-mesure du gate end-to-end (toujours fermé) + provenance des clés ; 2026-09-13 : étape 1 instance locale po-203 + topologie relais → hub autoritaire po-2025 — po-2023)
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
| 3 | **roo-state-manager (condensation LLM + dashboards)** | SDK OpenAI direct via `OPENAI_BASE_URL` | `mcps/internal/servers/roo-state-manager/.env.template` l.6 (submod gitlink `0e5240df`) | **`qwen3.6-35b-a3b`** (defaut `openai.ts:102` + `index.ts:97`, vérifié 15/09) | `OPENAI_API_KEY` (env conteneur) | grep `OPENAI_BASE_URL\|qwen3\.6` dans submod | **VERS-CLAUDISH** : SDK OpenAI de claudish côté `models.myia.io/v1` — alias `local-coding` |
| 4 | **roo-state-manager (embeddings Qdrant)** | SDK OpenAI direct via `EMBEDDING_API_BASE_URL` (legacy) | submod `.env.example` l.59-66 ; `services/task-indexer/EmbeddingValidator.ts:54` | **`qwen3-4b-awq-embedding`** | `EMBEDDING_API_KEY` (env conteneur) | grep `EMBEDDING_API_KEY` dans submod | **VERS-CLAUDISH** : endpoint embeddings stable `https://models.myia.io/v1/embeddings` (API OpenAI supportée par claudish) — **GELÉ 06/09** : l'inférence « API OpenAI supportée ⇒ `/v1/embeddings` servi » est contredite par la sonde (404) ; bascule différée jusqu'à relais effectif (arbitrage user) |
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

### Étape 1 — Alias stable côté routeur (hub, ~30 min)

**Rév. 13/09 (po-203, exécution + sondes firsthand) : la topologie a changé APRÈS la correction du 08/09.** Le port fleet-facing `192.168.0.46:3000` (conteneur `claudish-proxy` po-2023) tourne en **mode relais** : `POST` chat → `http://host.docker.internal:18182` (relais TCP node, `D:\Production\claudish-relay-po2025\relay.js`, créé 05/09) → **hub autoritaire `192.168.0.50:3000` sur po-2025**. Seul `GET /v1/models` est servi par l'instance locale po-2023 (route fork `model-discovery.ts` relit `~/.claudish/config.json` à chaque requête ; le chemin chat snapshot la config au boot ET résout désormais chez po-2025). Conséquence : **l'annonce catalogue et la résolution chat peuvent diverger sur le même port** — la vérification de gate doit être **end-to-end** (complétion 200 via `192.168.0.46:3000`), jamais catalog-only.

1. **Fait 13/09 sur l'instance locale po-2023** (sert le catalogue + le fallback local quand le forward relais échoue) : ajout `local-coding` → `vllm-myia@qwen3.6-35b-a3b` et `local-fast` → `vllm-myia@qwen3.6-35b-a3b` dans `routing` (backup `config.json.bak-alias-local-20260913-085642`), `docker restart claudish-proxy` (opération routinière — le watchdog la pratique chaque nuit). Catalogue local : 23 modèles, 2 alias annoncés.
2. **Divergences vs plan initial :**
   - `local-fast` → `qwen3-32b` **impossible** : `qwen3-32b` n'existe plus dans aucun catalogue (hub 21 modèles, sondé 13/09). Aliased vers le seul modèle local ; retarget = 1 ligne quand un modèle local « rapide » existera.
   - `claude-haiku-local` **REJETÉ** : tout nom `claude-*` est capturé par le mappage de rôle du hub (empirique : requête `claude-haiku-local` → rôle haiku → `MiniMax-M3` cloud, jamais le vLLM local — le glob défaut `"claude-*"` + ComposedHandler précèdent la résolution d'alias). Un alias annoncé mais routé vers le cloud est exactement la panne silencieuse que cette Epic combat : ne pas créer. Le besoin « haiku Claude Code → local » est une décision de **profil hub** (rôle haiku), pas un alias.
3. **Reste à faire — même runbook sur le hub autoritaire po-2025** (lane po-2025) : backup `~/.claudish/config.json` → ajouter `local-coding`/`local-fast` dans `routing` vers l'endpoint vLLM local **tel que nommé dans SA config** (vérifier le nom du customEndpoint, pas recopier `vllm-myia` aveuglément) → `docker restart` de son conteneur claudish → vérifier end-to-end : `/v1/models` sur `192.168.0.46:3000` annonce les 2 alias **ET** complétion 200 à travers `192.168.0.46:3000` (pas seulement en direct sur `.50`).
4. **Critère de gate (vague 1) :** `local-coding` + `local-fast` — annoncés dans `/v1/models` **et** complétion 200 end-to-end via `192.168.0.46:3000`. `local-embed` reste gelé (étape 2 point 3). `claude-haiku-local` retiré (cf. point 2).

### Étape 2 — Bascule SDK OpenAI roo-state-manager (1 PR submod, ~1h)

Submod `mcps/internal` :
1. `.env.template` l.6 : `OPENAI_BASE_URL=https://models.myia.io/v1`
2. `.env.template` l.8 : `OPENAI_CHAT_MODEL_ID=local-coding`
3. **GELÉ (arbitrage user 06/09) — NE PAS EXÉCUTER en l'état.** claudish ne sert pas `/v1/embeddings` (sonde ai-01 06/09 : 404 sur hub po-2023, sidecar ai-01 et `models.myia.io` ; 0 route `/v1/embeddings` sur 99 refs du dépôt claudish). Le mode de défaillance est **silencieux** : `codebase_search` ne remonte pas d'erreur, il remonte zéro résultat. `EMBEDDING_API_BASE_URL` reste sur son endpoint actuel (po-2026 `:8004`) jusqu'à ce qu'un ingress `/v1/embeddings` existe dans claudish. Verbatim user : *« on ne basculera embedding que quand il aura été bien relayé »*. Les points 1, 2 et 4 de cette étape restent exécutables à l'ouverture du gate.
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
| `EMBEDDING_MODEL` en dur ou pas | Hardcoder (`qwen3-4b-awq-embedding`) | Alias claudish (`local-embed`) | **alias** — embedding change plus souvent que chat *(GO 04/09 ; exécution gelée 06/09 — non arbitrable tant que le relais `/v1/embeddings` n'existe pas)* |
| Référentiel alias (rôle vs version) | `local-coding` (rôle) | `qwen-stable` (sentinelle version) | **`local-coding`** — le swap #2716 devient invisible (cf. leçon issue) |

---

## 5. Limites de l'inventaire (scepticisme protocole)

- **Lane non couverte :** OWUI 7 écoles (#17) — la sonde ne peut pas atteindre les bases sans accès ai-01/ops-schools. **Donnée brute :** ai-01 a mesuré 2 occ. pour OWUI interne + 3-4 par école = 21-28 occ. estimées. **À confirmer firsthand par ai-01/ops-schools.**
- **Notebooks CoursIA (#18), Docker render_envs (#19) :** hors `roo-extensions` — pas sondés. **À déclarer par les lanes CoursIA / ops-schools.**
- **Watchdogs `scripts/mcp-watchdog/`, `scripts/mcp/` :** **0 hits** pour `qwen3|OPENAI_BASE_URL|OPENAI_API_KEY|VLLM_API_KEY`. Pas de consommateurs directs. ✅ contrôle négatif net.
- **Tests Vitest :** occurrences nombreuses de `qwen3.6-35b-a3b` dans les tests du submod, mais ce sont des fixtures de string — pas des consommateurs runtime. **À distinguer** dans le PR #2 (étape 2) : remplacer seulement le default `openai.ts:102` et `index.ts:97` (coordonnées vérifiées 15/09, cf. §7.1), laisser les tests qui assertent la précédence/fallback.
- **Docs (`docs/sk-agent/`, `docs/investigation/unified-model-router.md`, `docs/deployment/claudish-per-machine.md`) :** occurrences documentaires (rapports d'évaluation, designs). **Hors scope** — ne pas modifier dans cette Epic, mais à mettre à jour quand la bascule est validée.

---

## 6. Synthèse métrique

- **Systèmes identifiés :** 19 (15 dans `roo-extensions` + 4 externes partiels). Les instances de siège §7.1 (po-2024) sont des déploiements locaux de ces systèmes — elles n'ajoutent pas au total.
- **Occurrences noms en dur dans roo-extensions :** 226 (qwen3-32b 41 · qwen3.5-35b-a3b 37 · qwen3-30b-a3b 26 · qwen3-8b 22 · qwen3.6-35b-a3b 19 · qwen3-235b-a22b-fp8 19 · qwen3-14b 19 · qwen3-1.7b 18 · qwen3-embedding 15 · + variantes courtes).
- **Clés à rotater au pire :** 7 (1 env RSM × 3 canaux × 7 écoles OWUI) — ramenées à **1** si tous les consommateurs passent par claudish (alias + clé unique `x-proxy-key`).
- **PRs prévues :** 5 (1 ai-01 alias, 1 submod RSM, 1 submod sk-agent, 1 parent Roo+claudish+call-sk-agent, 1 ai-01 swap final).
- **Fenêtre totale estimée :** 1 journée cluster (alias + bascule RSM + Roo = ~3h ; écoles + rotation + swap = ~5h, parallélisable sur 7 ops-schools).

---

## 7. Lane po-2024 — déclaration firsthand (14/09) + re-mesure du gate vague 1

**Sonde :** lecture directe des fichiers de config du siège (`~/.claude/settings.json`, `.env` RSM déployé, `sk_agent_config.json` déployé) + sondes HTTP live. **Clés jamais lues en clair** (longueur + sha8 seulement).

### 7.1 Consommateurs du siège po-2024 — instances de siège des systèmes §1

**Ces lignes sont les instances DE CE SIÈGE de systèmes déjà comptés dans le tableau fleet-level §1 — elles n'ajoutent AUCUN système au total de 19.** Mapping : 20→#1, 21→#3, 22→#4, 25→#6. Les lignes 23 (mini) et 24 (fallback cloud) sont des **canaux secondaires du déploiement RSM #3** (mêmes `.env`/verdicts RESTE-DIRECT hors surface de réduction, comme #5 et #8-#10). La ligne `call-sk-agent.ps1` de la rév. 14/09 a été retirée : **doublon exact du système fleet-level #7** (même script, mêmes l.118/137, même verdict — étape 4).

| # | Système §1 | Système (siège) | Mode d'accès | Emplacement config | Nom de modèle | Provenance de la clé | Sonde | Verdict |
|---|------------|-----------------|--------------|--------------------|---------------|----------------------|-------|---------|
| 20 | #1 | **Claude Code po-2024** | `ANTHROPIC_BASE_URL=http://192.168.0.50:3000` (hub po-2025, LAN direct) | `~/.claude/settings.json` clé `env` | rôles `claude-*[1m]` — **aucun nom qwen en dur** | `x-proxy-key` dans `ANTHROPIC_CUSTOM_HEADERS` (len 64) | `grep ANTHROPIC_BASE_URL settings.json` | **DEJA-VERS-CLAUDISH** ✅ |
| 21 | #3 | **RSM po-2024 — condensation LLM** | SDK OpenAI → `http://192.168.0.47:5002/v1` (`OPENAI_BASE_URL`) | `.env` RSM déployé (`mcps/internal/servers/roo-state-manager/.env`) | pas de `OPENAI_CHAT_MODEL_ID` → défaut code **`qwen3.6-35b-a3b`** (`index.ts:97`, `openai.ts:102`) | **`VLLM_API_KEY_MEDIUM`** — le build lit ce nom **en premier** (`chat-key.ts:37`) | `POST /v1/chat/completions` @ `.47:5002` | **RESTE-DIRECT** tant que le gate est fermé — cible `local-coding` (étape 2) |
| 22 | #4 | **RSM po-2024 — embeddings Qdrant** | SDK OpenAI → `http://192.168.0.51:8004/v1` (`EMBEDDING_API_BASE_URL`) | idem | `qwen3-4b-awq-embedding` (`EMBEDDING_MODEL`) | `EMBEDDING_API_KEY` (len 64) | `POST /v1/embeddings` → **200**, `qwen3-4b-awq-embedding` | **RESTE-DIRECT** (gel 06/09 : pas d'ingress `/v1/embeddings` côté claudish) |
| 23 | #3 · canal mini | **RSM po-2024 — vLLM mini** | SDK OpenAI → `https://api.mini.text-generation-webui.myia.io/v1` | idem | `zwz-8b` (`VLLM_MINI_MODEL_ID`) | `VLLM_API_KEY_MINI` | `grep VLLM_MINI` dans `.env` | hors surface prod |
| 24 | #3 · canal fallback cloud | **RSM po-2024 — fallback cloud** | z.ai | idem | `glm-4.7` (`FALLBACK_LLM_MODEL_ID`) | `ZAI_API_KEY` | idem | **RESTE-DIRECT** (cloud) |
| 25 | #6 | **sk-agent po-2024** | config JSON + appel OpenAI-compat, 3 endpoints | `mcps/internal/servers/sk-agent/sk_agent_config.json` **déployé** (hors repo, 49 KB) | 17 entrées dont **10 locales** : `qwen3.6-35b-a3b`, `qwen3.6-35b-no-thinking`, `omnicoder-9b`, 6 `owui-*` | clés inline **par entrée** — **3 provenances distinctes** (voir 7.3) | `json.load(…)['models']` | **VERS-CLAUDISH** (étape 5) — **2 entrées actuellement cassées**, cf. 7.3 |

**Contrôle négatif :** `schtasks /query` du siège → **0** tâche claude/executor/watchdog/mcp ; `~/.claude.json` → aucune URL `192.168.0.*` / `myia.io` hormis le roster `ROO_FLEET_ROSTER`.

### 7.2 Re-mesure du gate vague 1 (14/09) — **TOUJOURS FERMÉ**

Le **catalogue** annonce désormais les alias (changement depuis le 13/09), mais **la résolution chat ne suit pas** :

| Vantage | `GET /v1/models` | `POST /v1/chat/completions` `model=local-coding` |
|---|---|---|
| hub po-2025 `192.168.0.50:3000` | **200**, 23 modèles, `local-coding` + `local-fast` présents | **401** `{"error":{"message":"x-api-key header is required","type":"authentication_error"}}` |
| relais po-203 `192.168.0.46:3000` | idem | **401** idem |
| edge public `https://models.myia.io` | idem (23 modèles) | **401** idem |

**Contrôles appariés (requêtes identiques, mêmes en-têtes) :**

- `qwen3.6-35b-a3b` (baseline) → **200** sur le hub **et** sur le relais.
- nom **volontairement bidon** (`totally-bogus-xyz`) → **401 aux mêmes octets** que `local-coding` ; `local-fast` idem. ⇒ l'alias **ne résout pas** — il tombe dans le même chemin que « modèle inconnu », exactement la panne silencieuse que cette Epic combat.
- en-tête `x-api-key` (forme Anthropic) sur `/v1/chat/completions` → **401** identique ;
- route Anthropic `/v1/messages` (`x-api-key` + `anthropic-version`) : `claude-sonnet-4-6` → **200** (rôle servi `deepseek-flash`), `local-coding` → **401** identique.

**Conclusion :** le critère de gate (annoncé **ET** complétion 200 end-to-end via `192.168.0.46:3000`) **n'est pas satisfait**. Une lecture **catalog-only** conclurait « gate ouvert » **à tort** : c'est précisément le piège documenté §3 étape 1, ici mesuré sur les **3 vantages**. Les étapes 2-5 restent **gated**.

### 7.3 Provenance des clés — une clé morte dupliquée que le build ne lit pas

Le `.env` RSM déployé de po-2024 porte **deux** clés chat de 32 caractères, de **valeurs différentes** :

| Variable | sha8 | `POST .47:5002/v1/chat/completions` (l'endpoint que `OPENAI_BASE_URL` désigne) | lue par le build ? |
|---|---|---|---|
| `VLLM_API_KEY_MEDIUM` | `299ad00b` | **200**, complétion réelle | **oui** — `chat-key.ts:37` la lit **en premier** |
| `OPENAI_API_KEY` | `1c6a3bc7` | **401** `{"error":"Unauthorized"}` | non — repli seulement si `VLLM_API_KEY_MEDIUM` est absent |

La même valeur morte `1c6a3bc7` est **dupliquée** dans `sk_agent_config.json` déployé sur les **deux** entrées vLLM direct :

| Entrée sk-agent | `base_url` | sha8 clé configurée | `POST` sur cet endpoint |
|---|---|---|---|
| `qwen3.6-35b-a3b` | `api.medium.text-generation-webui.myia.io/v1` | `1c6a3bc7` | **401** `{"error":"Unauthorized"}` |
| `qwen3.6-35b-no-thinking` | idem | `1c6a3bc7` | (idem entrée ci-dessus) |
| *contrôle* : même endpoint, clé flotte | idem | `299ad00b` | **200** |

**Deux conséquences pour l'inventaire :**

1. **Méthode — nommer la variable que le BUILD lit.** Un audit qui teste la clé au nom le plus générique (`OPENAI_API_KEY`) conclut « consommateur cassé, 401 » et « corrige » le mauvais levier ; le build lit `VLLM_API_KEY_MEDIUM` (`chat-key.ts:37`), acceptée. C'est la même classe que #1147 (« la clé de chat doit correspondre à son endpoint »), vue depuis l'autre bout : ici la clé *morte* est présente, co-localisée, et **silencieusement inoffensive** pour RSM.
2. **Surface de rotation — `1c6a3bc7` est une copie morte en 3 emplacements** (1 var RSM + 2 entrées sk-agent) : elle n'apparaît dans **aucun** inventaire dérivé d'un `.env` unique. Les 2 entrées sk-agent concernées sont **actuellement non fonctionnelles** (401 sur leur propre endpoint) — à traiter en **étape 5** (aucune correction appliquée ici : la mutation de config est gated par le plan synchronisé §3, cette Epic porte un recensement, pas une bascule).

---

## 8. Lane po-2023 — re-mesure du gate vague 1 (17/09) : annonces apparues, résolution cassée

Troisième re-mesure end-to-end du gate (après po-2023 08/09, web1 09/09 et 11/09, po-2024 14/09 — toutes **fermées** sur « alias absents des catalogues »). **L'état a changé de nature** : les alias sont désormais annoncés, mais leur résolution échoue. Sondes firsthand po-203, 17/09 ~15:0xZ — aucune valeur de clé lue ni affichée (codes HTTP et noms de modèles seulement).

### 8.1 Sondes

| # | Sonde | Périmètre | Résultat |
|---|---|---|---|
| 1 | `GET http://192.168.0.46:3000/v1/models` | catalogue **local** po-203 (relais) | `local-coding` + `local-fast` **présents** (23 modèles) |
| 2 | `GET http://192.168.0.50:3000/v1/models` | catalogue **hub** po-2025 (autoritaire) | `local-coding` + `local-fast` **présents** (24 modèles ; `zai-glm-5-3` absent du local → les deux catalogues sont bien des snapshots distincts, les sondes 1 et 2 ne mesurent pas la même chose) |
| 3 | `POST :46:3000/v1/chat/completions` model `qwen3.6-35b-a3b`, header `x-proxy-key` | **contrôle positif** — chaîne complète relais → hub → vLLM + clé cluster | **200**, complétion réelle (0,7 s) |
| 4 | `POST :46:3000` model `local-coding` — 3 schémas d'auth : `x-proxy-key` / `x-api-key` / `Authorization: Bearer` | résolution end-to-end via le relais (gate vague 1) | **401** `{"error":{"message":"x-api-key header is required","type":"authentication_error"}}` — **identique pour les 3 schémas** |
| 5 | `POST :50:3000` (hub direct) model `local-coding`, `x-proxy-key` puis `x-api-key` | résolution hub seule, relais exclu | **401** identique |
| 6 | `POST :46:3000` model `local-fast`, `x-proxy-key` | second alias | **401** identique |

### 8.2 Lecture

- **Le gate vague 1 reste FERMÉ** : le critère « annoncé **ET** complétion 200 end-to-end via `192.168.0.46:3000` » (§3 étape 1 point 4) échoue sur la seconde moitié.
- **Le blocage a changé de nature.** Au 14/09 (§7.2) : alias absents des catalogues — « pas déployés ». Au 17/09 : alias **annoncés des deux côtés**, mais toute demande sur un alias échoue **avant la résolution** avec une erreur d'auth. Le contrôle positif (sonde 3) prouve que la sonde, le relais, le hub et la clé cluster sont fonctionnels : l'échec est **spécifique aux entrées `local-*`**.
- **L'erreur est mensongère en première lecture** : « x-api-key header is required » est renvoyé **même quand `x-api-key` est présent** (sondes 4-5). C'est une erreur de forme Anthropic émise par la chaîne de routage, pas un simple header manquant.
- **Hypothèse de cause (SUPPOSÉ — non vérifiable depuis po-203)** : les entrées de routing `local-*` du hub référencent un fournisseur absent/mal défini dans la config po-2025 (p. ex. `vllm-myia` déployé sur po-203 en étape 1 mais pas défini côté hub), et la résolution retombe sur une chaîne par défaut exigeant une auth Anthropic que la clé cluster ne satisfait pas. À qualifier sur le siège po-2025 (`~/.claudish/config.json` at-rest + logs du conteneur au moment d'une demande `local-coding`).
- **Propriétaire du fix :** lane **po-2025** (hub autoritaire). DM diagnostic envoyé 17/09. Les étapes 2-8 restent gated.

---

**Verdict global :** la surface est **réductible de 19 → 14** (5 OWUI écoles confondues derrière 1 script SQL, 1 clé RSM remplacée par `x-proxy-key` claudish) — total inchangé par les instances de siège §7.1 (cf. §6). Le swap #2716 devient **invisible** des consommateurs : 1 ligne dans le routeur claudish.
