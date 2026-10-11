# Inventaire durable des consommateurs de secrets

**Issue:** #3401 (volet inventaire, dispatch ai-01 cycle 11 du 11/10)
**Source:** relevés par empreinte du fil global `ai01-leak-proxykey-vllm-preset-20261011` (11/10) — po-2023, po-2024, po-2025 (roo-extensions + vllm), po-2027, web1, ai-01.
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
| **ai-01** (plus gros portefeuille flotte, **4 lanes**) | `~/.claude/settings.json` · `~/.claude/settings.claudish.json` | `env.ANTHROPIC_CUSTOM_HEADERS` | config harnais + profil alternatif | swap des deux | sessions Claude Code (profil alt : à son utilisation) |
| ai-01 (lane claudish) | `<claudish>/.env` | `CLAUDISH_PROXY_KEY` | `.env` non tracké | swap + compose restart | **conteneur `claudish-sidecar`** |
| ai-01 (lane nanoclaw) | `<nanoclaw>/.env` | `ANTHROPIC_CUSTOM_HEADERS` | `.env` non tracké | swap de la valeur | hôte NanoClaw |
| ai-01 (lane roo-extensions) | `<repo>/.env` · `<repo>/mcps/internal/servers/roo-state-manager/.env` | `ZAI_API_KEY` (×2) | `.env` root + `.env` live RSM | swap des 2 | spawns lisant le root + **recyclage hôte RSM** (valeur changée non relue au spawn d'enfant) |
| ai-01 (lane roo-extensions) | `<repo>/…/sk-agent/sk_agent_config.json` | `models[*].api_key` (×3) | config JSON live | swap des 3 champs | hôtes stdio sk-agent (prochain spawn) **+ conteneur public `sk-agent`** (monte ce fichier, le lit au démarrage) |
| ai-01 | `settings.json.{backup,bak}-*` (×12) · `settings.claudish.json.bak-*` (×1) · `<claudish>/.env.bak-*` (×2) · `~/.claudish/env-*` (×2) · `sk_agent_config.json.bak*` (×4) | idem | **sauvegardes inertes** (~21 fichiers) | purge post-coupure | aucun |
| po-2026 | — | — | — | — | **hors service (réparateur) — non relevé à date** ; à relever à son retour (dernière ligne attendue pour la rotation) |

**Négatifs vérifiés (11/10, par empreinte):** po-2025 `settings.json` (pas d'en-tête proxy sur ce siège) ; web1 `.claude.json` / win-cli / Zoo / `state.vscdb` ; po-2027 tous `.env` de l'arbre + env des process ; po-2024 `.claude.json` / schtasks / RSM `.env` / template sk-agent ; **ai-01** : `.claude.json`, win-cli, VS Code `User/`, repo+configs vllm, qdrant, searxng, CoursIA/CoursIA-2 (y compris `.secrets/`), Argumentum, Dify, Docker, Jupyter.

**Limite structurelle (toutes machines):** le **stockage secret VS Code/Zoo** est chiffré et invisible à tout grep — seuls les réglages Zoo ou le relevé 401/403 post-coupure (filet prévu) peuvent le révéler.

## Secret B — Clé Open Terminal (open-terminal service, ai-01), exposée publiquement depuis le 07/10

**Propriétaire:** service open-terminal (ai-01). Même commit public que le Secret A (`c728a4186d`, 07/10 17:00Z).

| Machine | Fichier(s) porteur(s) | Variable / champ | Type de stockage | Geste de mise à jour | Redémarrage requis |
|---|---|---|---|---|---|
| po-2024 | `<repo>/mcps/internal/servers/sk-agent/sk_agent_config.json` (LOCAL, pas le template) | `models[*].api_key` (×2) | fichier config JSON live | swap des 2 champs | hôte MCP sk-agent |
| ai-01 (propriétaire — lane Open-WebUI) | `<open-webui>/{ece,epf,epf-genai,epita,esg,myia,pauwels}.env` (×7 tenants) | `OPEN_TERMINAL_API_KEY` | `.env` tenants non trackés (le repo public ne tracke que `*.env.example` — vérifié) | swap dans les 7 | **les 7 conteneurs OWUI tenants** |
| ai-01 (lane roo-extensions) | `<repo>/…/sk-agent/sk_agent_config.json` | `OPEN_TERMINAL_API_KEY` | config JSON live | swap | hôtes sk-agent + conteneur public |
| ai-01 | `<open-webui>/backups/**/*.env*` (×15) · `sk_agent_config.json.bak*` (×4) | idem | **sauvegardes inertes** | purge post-coupure | aucun |

**Négatifs vérifiés:** po-2023, po-2025, po-2027, web1 — **0 consommateur**. po-2026 : hors service, non relevé.

## Secret C — Clés sœurs citées dans le fil (hors périmètre rotation, classées pour mémoire)

| Clé (rôle) | Machine(s) | Statut |
|---|---|---|
| `VLLM_API_KEY_MEDIUM` (`.env` po-2025) | po-2025 | **saine** — non concernée par la fuite |
| Profil dormant `settings.zai.json` (clé « Claude-Code » pré-bascule) | po-2023, po-2024, + classe flotte | **dormante** — purge post-révocation uniquement ; po-2023 a posé la question de son statut de révocation (29/09) à l'opérateur |

---

## Procédure de mise à jour de cet inventaire

1. **Un relevé nouveau = une ligne nouvelle.** La machine qui mesure ajoute sa ligne au prochain cycle (chemin + variable + geste + restart) ; les négatifs vérifiés se mettent à jour pareillement.
2. **À une rotation:** le porteur de la rotation (ici po-2023:claudish) utilise la colonne « Geste / Redémarrage » comme checklist de bascule ; chaque machine confirme ses swaps sur le fil global (empreintes OK, jamais de valeurs).
3. **Règles de rédaction:** rôle du secret, pas de nom de valeur ; chemins avec `<repo>` / `<user>` génériques ; les empreintes vivent dans le fil global privé.
4. **Purge des sauvegardes:** uniquement **post-coupure** (une sauvegarde portant l'ancienne clé est un filet de rollback tant que la bascule n'est pas vérifiée — cf. plan P4 du porteur).

## Provenance des mesures

- Fil global `ai01-leak-proxykey-vllm-preset-20261011` (dashboard GDrive, 11/10) : relevés po-2024 (c.198), po-2025:roo-extensions (15:17Z), po-2025:vllm (15:07Z), po-2027 (19:17Z), web1 (17:43Z), synthèse condensée po-2023.
- **ai-01** : c.6114760742 (11/10 ~22:45Z) — 4 lanes de la machine (roo-extensions, claudish, nanoclaw, Open-WebUI), 4 786 fichiers scannés, contrôle positif validé.
- **Date d'exposition** : commit public `c728a4186d` du repo `jsboige/vllm`, daté **07/10 17:00:32Z** — lu à l'API GitHub le 12/10.
- Méthode commune: scan par **empreinte sha256[:16]** des valeurs du commit fuité, jamais de valeur manipulée en clair au-delà du strict besoin local.
