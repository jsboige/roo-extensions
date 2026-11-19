# Grain Supervisor — invocation en arrière-plan

**Issue :** #4833 · **Définition :** `.claude/configs/agents/grain-supervisor.md`
**Portée :** un grain déjà arbitré, une PR, un coordinateur qui décide du merge.

## Quand l'invoquer

Utiliser `grain-supervisor` quand la lane principale peut confier un grain borné sans attendre la production : critères exécutables, périmètre et arrêts écrits, aucune décision ouverte, aucune PR non fusionnée requise. Ne pas l'utiliser pour un arbitrage, un geste d'infrastructure, une preuve live inaccessible au siège, ou du code critique que la lane doit garder.

Le brief suit le [grain template et le protocole de délégation](https://github.com/jsboige/claudish/blob/main/docs/reference/delegation-protocol.md). Il doit nommer le dépôt, l'issue, la base, le prédicat, les fichiers inclus/exclus, les commandes d'acceptation et les gardes cibles. Les gardes Grain/`prev`/nav-chain/README/twin ne s'appliquent que si le dépôt cible les déclare.

## Déploiement

La source est déployée globalement, donc disponible dans les autres workspaces :

```powershell
powershell.exe -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target agents -DryRun
powershell.exe -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1 -Target agents
```

Exécuter le déploiement depuis le checkout principal après fusion, jamais depuis un worktree jetable. `-DryRun` ne copie rien. La définition installée est `~/.claude/agents/grain-supervisor.md`. Vérifier sa présence dans l'inventaire d'agents de la session consommatrice ; ne pas confondre fichier déployé et agent effectivement invoqué.

## Invocation non bloquante

```text
Agent(
  subagent_type: "grain-supervisor",
  model: "sonnet",
  run_in_background: true,
  prompt: "<grain complet + identité machine:workspace + coordinateur>"
)
```

`run_in_background:true` est le contrat qui libere le tour de la lane. Les appels `call_agent` / `run_conversation` faits **à l'intérieur** du superviseur restent synchrones pour lui ; ils ne bloquent pas le parent parce que c'est le superviseur entier qui est en arrière-plan. Ne pas ajouter de cron ou de tâche planifiée pour simuler cette asynchronie.

La lane continue un autre grain. Elle reprend le superviseur sur sa notification de terminaison (ou via `ListAgents`/`SendMessage` si un complément est nécessaire), avec un seul observateur par condition. Elle ne pollue pas le superviseur de polls et ne lance pas un doublon du même grain.

## Mapping difficulté → modèles

| Profil | Production | Vérification indépendante |
|---|---|---|
| simple | Luna (`notebook-coder-luna`) ou Swift (`notebook-coder`, capacity gate) | MiniMax / rôle Sonnet |
| standard | MiniMax (`notebook-coder-minimax`) ou rôle Sonnet | GLM / Terra |
| difficile | GLM (`agent_spec` avec `model:"glm-5.3"`) ou Terra exposé | Opus / Sol après approbation du coût ; sinon handoff sans PASS |
| tres difficile | rôle Opus / Sol après justification et approbation écrites | coordinateur ou second vérificateur distinct |

Cette table route une intention, elle ne prouve pas la disponibilité. Avant chaque famille d'appels, le superviseur exécute `list_agents` ; il contrôle ensuite `model_used`, `effective_config` ou `effective_conversation`. Un id absent, un mauvais paramètre (`agent_id` au lieu de `agent`) ou un fallback vers `analyst` est un blocage, pas une mesure du modèle demandé. Voir le [guide sk-agent](sk-agent-usage-guide.md) pour transports et limites.

Sur un siège `always-sonnet-subagent`, l'appel `Agent` du parent reste explicitement `model:"sonnet"`. Opus/Fable natif exige necessite, cout approuve et justification ecrite. Le superviseur ne contourne jamais cette politique via un héritage de modèle.

## Comment la lane supervise le superviseur

1. **Avant production** : vérifier claims/PRs, brief, worktree dédié et modèle effectivement disponible. Le superviseur ne doit pas écrire avant ces contrôles.
2. **Pendant** : une notification par superviseur, pas de second timer. Une pause sk-agent se reprend avec le même `conversation_id` et `options.continue` ; une passe saturée utilise `pass-resumer` avec un résumé de 4 000 caractères maximum, jamais l'historique entier.
3. **Avant PR** : le producteur n'est pas son vérificateur. Le vérificateur reçoit issue/source/diff, rejoue les acceptations et note les mutations. Le superviseur relit les claims et le dashboard frais avant livraison.
4. **Après PR** : vérifier commit, branche distante, URL PR et CI au head. Le coordinateur reçoit la PR ; le superviseur ne merge pas, ne s'approuve pas et ne ferme pas l'issue.
5. **Au compte rendu** : exiger verdict, PR, modèles/fallback, tests/gardes, durées murales, tokens et coûts réellement exposés. `NOT_EXPOSED` ou `UNVERIFIED` sont des résultats valides ; une estimation présentée comme mesure ne l'est pas.

## Preuve d'acceptation #4833

Les tests Pester `scripts/testing/unit/grain-supervisor-contract.Tests.ps1` valident hors ligne le frontmatter, le déploiement, le mapping, l'invocation background et les garde-fous. Ils ne lancent ni Agent, ni workflow sk-agent, ni appel payant.

Le critère de bout en bout reste distinct : une lane tierce invoque réellement le superviseur en arrière-plan, continue un autre travail, obtient une PR et rapporte tokens/murs. Tant que ce run et son coût ne sont pas observés, #4833 ne peut pas etre declare entierement accepte.
