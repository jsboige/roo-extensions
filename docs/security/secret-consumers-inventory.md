# Inventaire durable des consommateurs de secrets

**Issue:** #3401 (volet inventaire, dispatch ai-01 cycle 11 du 11/10)
**Source:** relevés par empreinte du fil global `ai01-leak-proxykey-vllm-preset-20261011` (11/10) — po-2023, po-2024, po-2025 (roo-extensions + vllm), po-2027, web1, ai-01 ; **web2** ajouté le 19/10 (relevé par noms de variables, sans empreinte — voir Provenance) ; **po-2028** ajouté le 24/10 (même méthode noms-seuls).
**Règle absolue:** ce fichier vit dans un dépôt **public** — chemins et noms de variables **uniquement**. Aucune valeur, aucune empreinte, aucun endpoint authentifié. Les empreintes sha256[:16] restent dans le fil global (GDrive, privé).

**Pourquoi ce fichier:** la rotation d'une clé partagée coûte proportionnellement au nombre de copies (énoncé #3401). Cet inventaire rend ce coût **connu à l'avance** : par secret, qui le détient, où, sous quelle forme, et ce qu'un basculement exige comme geste et comme redémarrage. Il vit dans le dépôt pour survivre aux sessions ; il se met à jour **à chaque relevé nouveau** (une machine qui découvre un consommateur ajoute sa ligne au prochain cycle).

---

## Secret A — Clé du hub (x-proxy-key), exposée publiquement depuis le 07/10

**Propriétaire:** lane claudish (hub, po-2025). **Exposée depuis le 07/10 17:00Z** (commit public `c728a4186d`, repo `jsboige/vllm` — date du commit = fait source) ; découverte et rotation décidées le 11/10 (GO user, plan P0–P4, porteur po-2023:claudish).
**Usage:** authentification des appels LLM vers le hub (API Anthropic + OpenAI relayées).

| Machine | Fichier(s) porteur(s) | Variable / champ | Type de stockage | Geste de mise à jour | Redémarrage requis |
|---|---|---|---|---|---|
| po-2024 | `~/.claude/settings.json` | bloc `env` (header proxy) | fichier config harnais | swap de la valeur | sessions Claude Code ouvertes (au prochain spawn sinon) |
| po-2023 | `D:\Dev\claudish\.env` + `~/.claude/settings.json` | header proxy | `.env` + config harnais | swap des deux | sessions + service lisant le `.env` |
| po-2025 (siège roo-extensions) | `<repo>/.env` · `<repo>/mcps/internal/servers/roo-state-manager/.env` | `ZAI_API_KEY` · `zaiApiKey` · `CLAUDISH_PROXY_KEY` · `ZAI_API_KEY` (RSM) | `.env` (×2 fichiers, 5 entrées) | swap des 5 entrées | hôtes sk-agent (1/session), hôte RSM, spawns lisant le `.env` racine |
| po-2025 (siège roo-extensions) | `<repo>/mcps/internal/servers/sk-agent/sk_agent_config.json` | `models[*].api_key` (×3) | fichier config JSON live (le **template** est propre : placeholder `api_key_env`) | swap des 3 champs | redémarrage de l'hôte MCP sk-agent (le process garde la clé en mémoire — sinon 401 rendus en WARN) |
| po-2025 (lane vllm) | `<repo>/.env` | `ZAI_API_KEY` | `.env` | swap + relance | hôte MCP sk-agent (chaîne des délégations mini) |
| po-2027 | `C:\Users\<user>\.claude\settings.json` | `env.ANTHROPIC_CUSTOM_HEADERS` (`x-proxy-key`) | config harnais | swap de la valeur | sessions Claude Code de la machine |
| po-2027 | `C:\Users\<user>\.claude\settings.json.{backup,bak}-*` (×19) | idem | **sauvegardes inertes** | purge à la bascule (aucun service ne les lit) | aucun |
| po-2027 | `D:\dev\CoursIA\.secrets\master.env` | `CLAUDISH_PROXY_KEY` | `.env` gitignoré (non tracké — vérifié) | éditer + `render_envs.py` | `docker compose restart` des services rendus |
| web1 | `~/.claude/settings.json` | `env.ANTHROPIC_AUTH_TOKEN` | config harnais | swap de la valeur | relance sessions Claude Code |
| web1 | `<repo>/mcps/internal/servers/roo-state-manager/.env` | `ZAI_API_KEY` | `.env` live du serveur RSM | swap de la valeur | **recyclage de l'hôte RSM** — une valeur changée n'est PAS relue au spawn d'enfant, seul le restart la prend (mesuré, c.439) |
| web1 | `<repo>/…roo-state-manager/.env.bak-*` (×4) | — | sauvegardes inertes (gitignored) | purge post-coupure | aucun |
| **web2** | `~/.claude/settings.json` | `env.ANTHROPIC_CUSTOM_HEADERS` (`x-proxy-key`) + `env.ANTHROPIC_BASE_URL` (hub `models.myia.io`) | config harnais | swap de la valeur | sessions Claude Code de la machine |
| web2 | `<repo>/.env` (non tracké — vérifié) | `ZAI_API_KEY` | `.env` root | swap + relance | spawns lisant le `.env` racine (RSM, sk-agent, scripts) |
| web2 | `<repo>/…/sk-agent/sk_agent_config.json` (live, non tracké) | `models[*].api_key` (×13 littéral) + `api_key_env: ZAI_API_KEY` (×3, résolus par l'env) | config JSON live | swap des 13 champs littéraux (les 3 `api_key_env` suivent l'env) | redémarrage de l'hôte MCP sk-agent |
| web2 | `~/.claude/settings.json.{backup,bak}-*` (×8) + `<repo>/…/sk-agent/sk_agent_config.json.bak-*` (×2) | idem | **sauvegardes inertes** — 10 fichiers confirmés porteurs de l'ancienne clé par scan d'empreinte (14/10) | purge post-coupure, **user-gated** (registre Q10) — manifeste exigé au geste | aucun |
| **po-2028** | `~/.claude/settings.json` | `env.ANTHROPIC_CUSTOM_HEADERS` (`x-proxy-key`) + `env.ANTHROPIC_AUTH_TOKEN` ; `ANTHROPIC_BASE_URL` = `http://localhost:3000` (sidecar claudish du siège, qui relaie vers le hub LAN — upstream `CLAUDISH_RELAY_UPSTREAM`, ligne suivante) | config harnais | swap de la valeur | sessions Claude Code de la machine |
| po-2028 | `C:\dev\claudish\.env` (non tracké) | `CLAUDISH_PROXY_KEY` (+ `CLAUDISH_RELAY_UPSTREAM`) | `.env` du checkout claudish local (sidecar/relay) | swap + relance du service lisant le `.env` | service sidecar/relay claudish du siège |
| po-2028 | `~/.claude/settings.json.bak-{20261021-131339,lane-temoin-20261022,q57-align-20261021}` (×3) | idem | **sauvegardes inertes** — les 2 autres backups (19-20/10) ne portent pas le header | purge post-coupure | aucun |
| **ai-01** (plus gros portefeuille flotte, **4 lanes**) | `~/.claude/settings.json` · `~/.claude/settings.claudish.json` | `env.ANTHROPIC_CUSTOM_HEADERS` | config harnais + profil alternatif | swap des deux | sessions Claude Code (profil alt : à son utilisation) |
| ai-01 (lane claudish) | `<claudish>/.env` | `CLAUDISH_PROXY_KEY` | `.env` non tracké | swap + compose restart | **conteneur `claudish-sidecar`** |
| ai-01 (lane nanoclaw) | `<nanoclaw>/.env` | `ANTHROPIC_CUSTOM_HEADERS` | `.env` non tracké | swap de la valeur | hôte NanoClaw |
| ai-01 (lane roo-extensions) | `<repo>/.env` · `<repo>/mcps/internal/servers/roo-state-manager/.env` | `ZAI_API_KEY` (×2) | `.env` root + `.env` live RSM | swap des 2 | spawns lisant le root + **recyclage hôte RSM** (valeur changée non relue au spawn d'enfant) |
| ai-01 (lane roo-extensions) | `<repo>/…/sk-agent/sk_agent_config.json` | `models[*].api_key` (×3) | config JSON live | swap des 3 champs | hôtes stdio sk-agent (prochain spawn) **+ conteneur public `sk-agent`** (monte ce fichier, le lit au démarrage) |
| ai-01 | `settings.json.{backup,bak}-*` (×12) · `settings.claudish.json.bak-*` (×1) · `<claudish>/.env.bak-*` (×2) · `~/.claudish/env-*` (×2) · `sk_agent_config.json.bak*` (×4) | idem | **sauvegardes inertes** (~21 fichiers) | purge post-coupure | aucun |
| po-2026 | — | — | — | — | **hors service (réparateur) — non relevé à date** ; à relever à son retour (dernière ligne attendue pour la rotation) |

**Négatifs vérifiés (11/10, par empreinte):** po-2025 `settings.json` (pas d'en-tête proxy sur ce siège) ; web1 `.claude.json` / win-cli / Zoo / `state.vscdb` ; po-2027 tous `.env` de l'arbre + env des process ; po-2024 `.claude.json` / schtasks / RSM `.env` / template sk-agent ; **ai-01** : `.claude.json`, win-cli, VS Code `User/`, repo+configs vllm, qdrant, searxng, CoursIA/CoursIA-2 (y compris `.secrets/`), Argumentum, Dify, Docker, Jupyter. **Négatifs web2 (19/10, par noms de variables):** `~/.claude.json` (aucun en-tête proxy), `<repo>/…/roo-state-manager/.env` (**absent** de cette machine — le RSM y lit sa config par variables d'environnement du process), `<repo>/.env.bak*` (aucun). **Négatifs po-2028 (24/10, par noms de variables):** `<repo>/.env` racine **absent** ; `~/.claude.json` (aucun champ clé inline) ; `~/.claudish/env-*` (aucun) ; configs Roo/Zoo **absentes** ; **ferme CoursIA (~50 worktrees sous `C:\dev\CoursIA*`) : 0 fichier `.env` porteur** d'un nom de clé partagée (census maxdepth 3) — les mentions `x-proxy-key` y sont docs/notebooks/git-pack uniquement ; `<repo>/…/sk-agent/sk_agent_config.json.bak*` (aucun).

**Limite structurelle (toutes machines):** le **stockage secret VS Code/Zoo** est chiffré et invisible à tout grep — seuls les réglages Zoo ou le relevé 401/403 post-coupure (filet prévu) peuvent le révéler.

## Secret B — Clé Open Terminal (open-terminal service, ai-01), exposée publiquement depuis le 07/10

**Propriétaire:** service open-terminal (ai-01). Même commit public que le Secret A (`c728a4186d`, 07/10 17:00Z).

| Machine | Fichier(s) porteur(s) | Variable / champ | Type de stockage | Geste de mise à jour | Redémarrage requis |
|---|---|---|---|---|---|
| po-2024 | `<repo>/mcps/internal/servers/sk-agent/sk_agent_config.json` (LOCAL, pas le template) | `models[*].api_key` (×2) | fichier config JSON live | swap des 2 champs | hôte MCP sk-agent |
| ai-01 (propriétaire — lane Open-WebUI) | `<open-webui>/{ece,epf,epf-genai,epita,esg,myia,pauwels}.env` (×7 tenants) | `OPEN_TERMINAL_API_KEY` | `.env` tenants non trackés (le repo public ne tracke que `*.env.example` — vérifié) | swap dans les 7 | **les 7 conteneurs OWUI tenants** |
| ai-01 (lane roo-extensions) | `<repo>/…/sk-agent/sk_agent_config.json` | `OPEN_TERMINAL_API_KEY` | config JSON live | swap | hôtes sk-agent + conteneur public |
| ai-01 | `<open-webui>/backups/**/*.env*` (×15) · `sk_agent_config.json.bak*` (×4) | idem | **sauvegardes inertes** | purge post-coupure | aucun |
| web2 | `<repo>/…/sk-agent/sk_agent_config.json` (live, non tracké) | `OPEN_TERMINAL_API_KEY` | config JSON live | swap du champ | redémarrage de l'hôte MCP sk-agent |

**Négatifs vérifiés:** po-2023, po-2025, po-2027, web1, **po-2028** — **0 consommateur** (po-2028 : les 2 occurrences `OPEN_TERMINAL_API_KEY` du `sk_agent_config.json` sont le placeholder template `YOUR_OPEN_TERMINAL_API_KEY_HERE`, pas une clé live). po-2026 : hors service, non relevé. web2 : **positif** (ligne ci-dessus) ; ses 2 sauvegardes `sk_agent_config.json.bak-*` sont comptées dans la ligne « sauvegardes inertes » du Secret A, mais leur contenu Secret B n'a **pas** été mesuré dans cette passe.

## Secret C — Clés sœurs citées dans le fil (hors périmètre rotation, classées pour mémoire)

| Clé (rôle) | Machine(s) | Statut |
|---|---|---|
| `VLLM_API_KEY_MEDIUM` (`.env` root) | po-2025, web2 | **saine** — non concernée par la fuite |
| `VLLM_API_KEY_MEDIUM` · `VLLM_API_KEY_MINI` · `ZAI_API_KEY` · `QDRANT_API_KEY` · `EMBEDDING_API_KEY` · `FALLBACK_API_KEY` · `OPENAI_API_KEY` (`.env` live RSM — pas de `.env` racine sur ce siège) | po-2028 | **saines** — non concernées par la fuite ; relevées pour exhaustivité (le RSM de ce siège condense via `api.medium` en repli, cf. #3962). Rattachement Secret A vs C non tranchable par la méthode noms-seuls (empreintes dans le fil global) |
| `sk_agent_config.json` live : `api_key` littéral (×3) + `api_key_env` (`ZAI_API_KEY` ×3, `VLLM_API_KEY_MEDIUM` ×4, `OWUI_API_KEY` ×4) | po-2028 | idem — valeurs non relevées (méthode noms-seuls) |
| Profil dormant `settings.zai.json` (clé « Claude-Code » pré-bascule) | po-2023, po-2024, + classe flotte | **dormante** — purge post-révocation uniquement ; po-2023 a posé la question de son statut de révocation (29/09) à l'opérateur |

## Secret D — Bearer du proxy MCP public (`mcp-tools.myia.io`), non exposé

**Propriétaire:** proxy MCP d'ai-01 (jeton côté serveur dans son lanceur `run-proxy.cmd`). **Copie flotte autorisée par le user le 20/10 (RX110, option a)**, pour le détecteur de sessions gelées (#4243 volet 3) : transport **RooSync uniquement** (pièce jointe auto-détruite après 1 j, jamais git ni corps de message), une ligne ci-dessous par copie. Suite prévue (RX110, option c) : un jeton dédié au détecteur si le proxy en accepte plusieurs — à la rotation, ces lignes sont la checklist.

| Machine | Fichier(s) porteur(s) | Variable / champ | Type de stockage | Geste de mise à jour | Redémarrage requis |
|---|---|---|---|---|---|
| ai-01 (propriétaire) | `<proxy>/run-proxy.cmd` | jeton d'authentification du proxy | lanceur non tracké | swap | **redémarrage du proxy** (préavis flotte) |
| ai-01 (lane nanoclaw) | `<nanoclaw>/.env` | `MCP_PROXY_BEARER` (+ `MCP_PROXY_BASE_URL` interne Docker) | `.env` non tracké | swap | conteneur NanoClaw ; la tâche `Claude-ApprovalStallDetector` relit à chaque tick |
| po-2023, po-2024, po-2025, po-2027, po-2028, web1, web2 | `%USERPROFILE%\.roo-state-manager\stall-detector.env` | `MCP_PROXY_BEARER` + `MCP_PROXY_BASE_URL=https://mcp-tools.myia.io` | fichier hors dépôt | swap | aucun (relu à chaque tick) — **copie envoyée le 20/10, pose à confirmer par chaque siège** sur le fil `ai01-c31bis-dispatch-20261020` |

**Négatifs:** po-2026 hors service, non destinataire.

---

## Procédure de mise à jour de cet inventaire

1. **Un relevé nouveau = une ligne nouvelle.** La machine qui mesure ajoute sa ligne au prochain cycle (chemin + variable + geste + restart) ; les négatifs vérifiés se mettent à jour pareillement.
2. **À une rotation:** le porteur de la rotation (ici po-2023:claudish) utilise la colonne « Geste / Redémarrage » comme checklist de bascule ; chaque machine confirme ses swaps sur le fil global (empreintes OK, jamais de valeurs).
3. **Règles de rédaction:** rôle du secret, pas de nom de valeur ; chemins avec `<repo>` / `<user>` génériques ; les empreintes vivent dans le fil global privé.
4. **Purge des sauvegardes:** uniquement **post-coupure** (une sauvegarde portant l'ancienne clé est un filet de rollback tant que la bascule n'est pas vérifiée — cf. plan P4 du porteur).

## Provenance des mesures

- Fil global `ai01-leak-proxykey-vllm-preset-20261011` (dashboard GDrive, 11/10) : relevés po-2024 (c.198), po-2025:roo-extensions (15:17Z), po-2025:vllm (15:07Z), po-2027 (19:17Z), web1 (17:43Z), synthèse condensée po-2023.
- **ai-01** : c.6114760742 (11/10 ~22:45Z) — 4 lanes de la machine (roo-extensions, claudish, nanoclaw, Open-WebUI), 4 786 fichiers scannés, contrôle positif validé.
- **web2** : relevé **19/10** (cycle executor) — sonde **par noms de variables** (`grep -o` sur les clés, valeurs jamais affichées) dans `~/.claude/settings.json`, `<repo>/.env` (non tracké), `sk_agent_config.json` (live, non tracké) et `~/.claude.json` ; contrôle positif `x-proxy-key` dans `settings.json`, contrôle négatif `.claude.json`. Le décompte des 10 sauvegardes portant l'ancienne clé provient du scan **par empreinte** du 14/10 (rotation RX96), pas de cette passe.
- **po-2028** : relevé **24/10** (cycle executor, lane inaugurée le 20/10 — postérieure au mandat du 11/10) — même sonde par noms de variables dans `~/.claude/settings.json` (+ ses 5 backups), `C:\dev\claudish\.env`, `<repo>/…/roo-state-manager/.env`, `sk_agent_config.json` (live), `~/.claude.json`, `~/.claudish/`, `%USERPROFILE%\.roo-state-manager\stall-detector.env`, configs Roo/Zoo et ferme `C:\dev\CoursIA*` (~50 worktrees, census `.env` maxdepth 3) ; contrôle positif `x-proxy-key` dans `settings.json` et `CLAUDISH_PROXY_KEY` dans `claudish/.env`, contrôles négatifs racine `.env` absent / CoursIA 0 porteur / Secret B placeholder. **Secret D : pose confirmée sur disque** (`stall-detector.env` présent avec `MCP_PROXY_BEARER` + `MCP_PROXY_BASE_URL`) — confirmation rendue sur le fil `ai01-c31bis-dispatch-20261020`.
- **Date d'exposition** : commit public `c728a4186d` du repo `jsboige/vllm`, daté **07/10 17:00:32Z** — lu à l'API GitHub le 12/10.
- Méthode commune: scan par **empreinte sha256[:16]** des valeurs du commit fuité, jamais de valeur manipulée en clair au-delà du strict besoin local.
