# sk-agent — Guide d'usage pour les lanes

**Version:** 1.0.0 (volet D de #4085)
**MAJ:** 2026-10-15
**Portée:** ce que chaque lane doit savoir pour appeler sk-agent — quel agent pour quoi, par quel transport, et les limites mesurées. Ne remplace pas la doc serveur (`mcps/internal/servers/sk-agent/`).

---

## Les deux transports

| Transport | Comment | Config servie | Monde visible de l'agent |
|---|---|---|---|
| **stdio (session)** | MCP `sk-agent` dans la session Claude Code (`call_agent`, `list_agents`…) | La config **live locale** de la machine (gitignored, pattern établi ; canon = template du submodule) | La machine locale : un agent porteur d'`open_terminal` exécute son shell **sur votre machine**, avec vos fichiers |
| **conteneur `:8100` (via proxy)** | Route `myia-mcp-proxy` `/sk-agent` → `127.0.0.1:8100/mcp` (ai-01), bearer proxy | Le `sk_agent_config.json` **monté en lecture seule** du conteneur | Le conteneur : `/app` et rien d'autre |

Règle flotte en découlant : **les agents disque (shell, lecture de dépôt) ne passent que par stdio**. Le conteneur ne monte que la config RO — ses plugins disque sont cassés et le resteront tant que le volet B de #4085 n'est pas tranché (mesuré 06/10 : `open_terminal` pointe un chemin hôte inexistant, `desktop_commander` dépasse le handshake 30 s à télécharger Chrome, `jupyter_papermill` absent de l'image).

Un agent stdio ne voit que les MCP que sa config lui donne (champ `mcps`) : `open_terminal` (shell), `searxng`, `playwright`, `markitdown`, `roo_state_manager`, `sk_agent` (récursion).

## Quel agent pour quoi

Canon = template `sk_agent_config.template.json` (42 agents). **Toujours `list_agents` avant un premier usage sur un siège** : la config live peut diverger du template, et la divergence est silencieuse — po-2026 a mesuré `coder`/`fast` résolus en `analyst` sans erreur (07/10).

| Besoin | Agent | Modèle | Ordre de grandeur mesuré |
|---|---|---|---|
| **Pré-review de PR** (mandat flotte 07/10) | `coder` **sans outils**, diff **collé dans le prompt** | swift no-thinking (local) | 18 s (ai-01) à ~45 s (po-2023), utile | 
| Vision (image, PDF, capture) | `vision-analyst` / `vision-local` | swift-1.5-27b (**jamais le hub**, il strip les images — #794) | — |
| Résumé / classification / formatage local | `summarizer-local`, `classifier-local`, `formatter-local` | swift no-thinking | secondes |
| Diagnostic code mono-fichier | `coder` outillé (shell+repo) | swift no-thinking | boucle d'outils — budget ≥ 240 s |
| Analyse de logs / dérive config | `terminal-analyst`, `log-analyzer` (log-analyzer = hub, LAN only) | swift / glm-5.3 | — |
| Économie de tokens — lecture, recalcul à critères objectifs | tier mini : `mini-repo-scan`, `mini-summarizer`… | frognano-4b (hub → **LAN only**) | 21 s / ~0,9 K tok (mission correctif réelle, po-2025) |
| Revue multi-perspectives (rapport, décision) | `critic`, `devils-advocate`, `optimist`, `mediator`… | glm-5.3(-flash) (hub → **LAN only**) | — |
| Recherche web structurée | `researcher` (hub) ou `analyst` (local) | glm-5.3 / swift | — |

**Pièces jointes :** office/média uniquement (images, PDF, DOCX…). `.txt`, `.diff`, `.ps1`, `.py` sont refusés — **le code et les diffs vont dans le prompt** (mesuré 06/10 et 07/10, volet C : c'est la forme canonique des presets mini aussi).

## Routage modèles — ce qui répond depuis votre siège

Trois familles, deux réalités réseau :

| Famille | Modèles (config) | `base_url` | Depuis un siège **LAN** (ai-01, po-2023/24/25/26) | Depuis un siège **hors LAN** (web1/OVH, po-2027 mobile) |
|---|---|---|---|---|
| Medium local | `swift-1.5-27b` (+ no-thinking ; alias dépréciés `qwen3.6-35b-*` jusqu'à ~2026-11-10) | public `api.medium.…myia.io` | OK | **OK** |
| OWUI proxied | `owui-qwen3.6-35b`, `owui-expert-analyste`, `owui-redacteur-technique` | public `open-webui.myia.io` | OK | **OK** |
| Hub (claudish) | `glm-5.3`, `glm-5.3-flash`, `frognano-4b` (tout le tier mini) | **LAN** `192.168.0.50:3000` | OK | **MORT par construction** — connect blackhole |

**23/42 agents du template (55 %) sont câblés au hub LAN** (14 glm-5.3 + 5 glm-5.3-flash + 4 frognano) : morts depuis web1 et po-2027, mesuré 13-14/10 (#4085, web1 + po-2027). Le gel est pire qu'un échec propre : l'appel **ne rend jamais la main**, `wait_for` ne tire pas, et **le spawn entier meurt pour les appels suivants**. Le fix (borne de connect + test du second appel, propriétaire web1, décision ai-01 14/10) rendra l'échec propre en < 10 s — il ne rendra pas le hub joignable. Le routage des sièges hors LAN vers le front public est une question de config séparée, non tranchée.

Conséquence pratique pour un siège hors LAN : utilisez les agents **swift et owui** (19/42). Le tier mini et la famille glm sont inutilisables tant que le routage n'est pas arbitré.

## Limites connues (mesurées, #4085)

1. **`ok:true` dans `usage.jsonl` = « une réponse a été rendue », pas « le modèle a réussi ».** web1 a mesuré des appels `ok:true` dont le contenu était `error: OpenAIChatCompletion`. Lisez la réponse, pas le seul indicateur.
2. **`review_pr(tier=1)` avec un agent surchargé n'injecte pas le diff** (ai-01, 06/10) — et `fast-reviewer` (cloud) a timeout à 240 s. Préférez `call_agent` + diff collé.
3. **Un agent outillé pour une revue de diff = 240 s de boucle d'outils insuffisantes** (po-2026, 07/10). Le profil utile en pré-review est un agent **sans outils**.
4. **`owui-qwen3.6-35b` rend une réponse vide** sur un prompt de code moyen (ai-01, 06/10) — à instruire avec la lane vllm avant d'y compter.
5. **Le conteneur n'exécute pas les agents disque** (volet B non tranché) : voir tableau transports.
6. **Vision jamais via le hub** (#794) : le hub strip les `image_url` avant z.ai. Vision = swift local ou OWUI.
7. **Le mini brûle son budget en reasoning** : `thinking:false` + `max_tokens` 4096 (plancher mesuré) sont portés par la config, pas par les presets — ne les surchargez pas à la baisse.
8. **Récursion validée 2 niveaux en technique** (`swift-delegator`, swift→swift) ; la **délégation medium→mini n'est pas encore éprouvée** (volet C pending). Attendez-vous à ce qu'un mini délégué échoue silencieusement en sortie vide si le budget est rogné.

## Recette — pré-review de PR (la plus utilisée)

```
call_agent(agent="coder", system_prompt="Tu relis un diff. Réponds: findings numérotés + sévérité (MINOR/MAJOR) + pourquoi. Pas de reformulation du diff.",
           prompt="<le diff complet collé ici>", timeout=240)
```

Puis **vérifiez chaque finding firsthand** avant d'agir — les trois retours d'adoption mesurés (po-2023, po-2025, ai-01) ont tous contenu au moins un finding valide **et** au moins un finding à rejeter après vérification. Un finding de sk-agent est une hypothèse, pas une review.

---

**Sources:** #4085 (volets A-D, datapoints 06-14/10), #4107 (presets mini), #794 (vision hub), template `mcps/internal/servers/sk-agent/sk_agent_config.template.json`. Docs voisines : [`claude-code-auto-approve.md`](../../../docs/sk-agent/claude-code-auto-approve.md), [`AGENT_INVENTORY.md`](../../../docs/sk-agent/AGENT_INVENTORY.md), [`escalation-protocol.md`](escalation-protocol.md).
