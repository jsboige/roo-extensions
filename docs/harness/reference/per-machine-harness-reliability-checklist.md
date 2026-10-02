# Checklist de fiabilité du harnais — par machine

**Version :** 1.0.0
**Date :** 2026-10-02
**Provenance :** reliquat de #1069 (fermée le 02/10 sur décision utilisateur, tri de l'epic #1298), reporté sur #2307 par ai-01.
**Surface de référence :** 17 outils roo-state-manager, vérifiée firsthand le 02/10 (deux instruments concordants : `allToolDefinitions` dans `tool-definitions.ts` **et** la surface `tools/list` exposée en session).

---

## Pourquoi ce document existe

Le corps de #1069 portait un **référentiel 「34 outils」** — la liste des outils à tester un par un, avec la commande de test et le résultat attendu. Cette liste décrit une surface qui **n'existe plus** : la consolidation (CONS-8 #603, #1841, #1935, #457) a fusionné ou retiré 17 entrées sur 34.

Redistribuer la checklist en l'état ferait tester des outils absents : chaque machine rapporterait une majorité d'échecs qui ne sont pas des pannes, et les **vraies** pannes se noieraient dedans. Ce document remplace le référentiel avant redispatch.

---

## §1 — Référentiel courant : 17 outils actifs

Colonne *Test* = appel minimal qui doit rendre une réponse utile (jamais une erreur de schéma). Un outil qui rend une erreur **métier** lisible (store absent, index froid) est **conforme** ; un outil qui rend `tool not found`, une erreur de validation de schéma, ou rien du tout est **en panne**.

### Conversation & Recherche (5)

| # | Outil | Actions | Test minimal | Attendu |
|---|-------|---------|--------------|---------|
| 1 | `conversation_browser` | `list`, `tree`, `current`, `view`, `summarize`, `rebuild` | `action:"current"` | Une conversation (la courante) |
| 2 | `roosync_search` | `semantic`, `text`, `diagnose` | `action:"diagnose"` | État de l'index Qdrant |
| 3 | `roosync_indexing` | `index`, `reset`, `rebuild`, `diagnose`, `archive`, `status`, `repair_gaps`, `repair_workspace`, `cleanup`, `garbage_scan`, `cleanup_orphans`, `cleanup_failed` | `action:"status"` | Statut de l'indexeur |
| 4 | `codebase_search` | *(pas d'enum — `query` + `workspace` requis)* | `query:"dashboard append", workspace:"<chemin absolu>"` | Résultats, ou `collection_not_found` |
| 5 | `read_vscode_logs` | *(pas d'enum — `lines`)* | `lines:5` | Dernières lignes de log VS Code |

> **Piège documenté** : `codebase_search` **exige** `workspace` explicite (hard-fail #1861) — l'auto-détection pointe vers le répertoire du serveur MCP. Un test sans `workspace` doit **échouer avec un message explicite**, c'est le comportement attendu, pas une panne.

### Coordination (3)

| # | Outil | Actions | Test minimal | Attendu |
|---|-------|---------|--------------|---------|
| 6 | `roosync_dashboard` | `read`, `write`, `append`, `list`, `delete`, `merge`, `read_archive`, `read_overview`, `refresh`, `update`, `scrub` | `read`, `type:"workspace"`, `section:"intercom"`, `intercomLimit:20` | Messages intercom |
| 7 | `roosync_messages` | `send`/`reply`/`amend` (mutations) · `inbox`/`message` (lectures) · `mark_read`/`archive`/`bulk_mark_read`/`bulk_archive`/`cleanup`/`stats` · `attachments_list`/`get`/`delete` | `action:"inbox"`, `status:"unread"` | Liste de messages (même vide) |
| 8 | `roosync_inventory` | *(pas d'enum — `type`)* : `machine`, `heartbeat`, `all`, `machines`, `status`, `health` | `type:"status"` | État synchronisation compact |

> Les 4 outils historiques `roosync_send` / `roosync_read` / `roosync_manage` / `roosync_attachments` sont **fusionnés** dans `roosync_messages` (voir §2) : tester les anciens noms ne teste rien.

### Configuration (4)

| # | Outil | Actions | Test minimal | Attendu |
|---|-------|---------|--------------|---------|
| 9 | `roosync_config` | `collect`, `publish`, `apply`, `apply_profile` (`scope`: `user`/`project`/`settings`) | `action:"collect"`, `scope:"user"` | Config collectée |
| 10 | `roosync_compare_config` | *(pas d'enum — `granularity`)* : `mcp`, `mode`, `settings`, `claude-settings`, `claude`, `modes-yaml`, `boot-resilience`, `full` | `granularity:"mcp"`, `detail:"values"` | Diff par serveur MCP |
| 11 | `roosync_baseline` | `update`, `version`, `restore`, `export`, `list_versions`, `current_version` | `action:"current_version"` | Version courante de la baseline |
| 12 | `roosync_harmonization` | `create`, `dispatch`, `remind`, `apply`, `confirm`, `status`, `list`, `close` | `action:"list"` | Campagnes d'harmonisation |

> `roosync_baseline` est **rarement utilisé opérationnellement** — un échec ici doit être qualifié avant d'être traité comme panne.

### Infrastructure & Diagnostic (5)

| # | Outil | Actions | Test minimal | Attendu |
|---|-------|---------|--------------|---------|
| 13 | `roosync_mcp_management` | `manage`, `rebuild`, `touch` (`subAction`) | `action:"manage"`, `subAction:"read"` | Config MCP du siège |
| 14 | `roosync_storage_management` | `storage` (`detect`/`stats`), `maintenance` (`cache_rebuild`/`diagnose_bom`/`repair_bom`/`rebuild_index`) | `action:"storage"`, `storageAction:"stats"` | Statistiques de stockage |
| 15 | `roosync_diagnose` | `env`, `debug`, `reset`, `test`, `health`, `lifecycle`, `recovery`, `analyze`, `best-practices`, `reload` | `action:"test"` | Statut MCP |
| 16 | `claudish_traffic` | *(pas d'enum — `bucket_minutes` **requis**)* | `bucket_minutes:15` | Histogramme de trafic |
| 17 | `export_data` | *(pas d'enum — `target`/`format`)* : `task`/`conversation`/`project` × `xml`/`json`/`csv`/`markdown`/`debug` | `format:"markdown"`, `target:"conversation"` | Export markdown |

---

## §2 — Carte des retraits (ancien référentiel → cible)

Pour chaque entrée de l'ancienne liste 「34」 : ce qu'elle est devenue. **Aucune n'est une panne** — toutes sont des fusions ou des retraits délibérés, tracés dans `allToolDefinitions` (`tool-definitions.ts:817-860`).

| Ancien outil | Devenu | Réf. |
|---|---|---|
| `task_export` | `export_data(format:"markdown"|"debug")` | #1841 |
| `view_task_details` | `conversation_browser(action:"view", detail_level:"Full")` | #1841 |
| `get_raw_conversation` | `export_data(format:"json", target:"task")` | #1841 |
| `export_config` | `export_data` (settings) | #1841 |
| `analyze_roosync_problems` | `roosync_diagnose(action:"analyze")` | #1935 |
| `get_mcp_best_practices` | `roosync_diagnose(action:"best-practices")` + doc statique | #1935 |
| `roosync_get_status` | `roosync_inventory(type:"status")` | #1935 |
| `roosync_refresh_dashboard` | `roosync_dashboard(action:"refresh")` | #1935 |
| `roosync_update_dashboard` | `roosync_dashboard(action:"update")` | #1935 |
| `roosync_heartbeat` | **auto-heartbeat** sur tout appel d'outil | #1609 |
| `roosync_init` | *mort* — toutes les machines initialisées | CONS-8 #603 |
| `roosync_list_diffs` | `roosync_compare_config` (thin wrapper) | CONS-8 #603 |
| `roosync_decision` / `roosync_decision_info` | *pipeline mort*, jamais opérationnalisé | CONS-8 #603 |
| `roosync_claim` | *jamais adopté* | #1836 |
| `roosync_send` / `roosync_read` / `roosync_manage` / `roosync_attachments` | `roosync_messages` (toutes les sous-actions) | #1841 |
| `roosync_machines` | `roosync_inventory(type:"machines")` | — |
| `roosync_health_view` | `roosync_inventory(type:"health")` | #2224 |

> Les redirections de compatibilité ascendante vivent dans `registry.ts` : un appel à un ancien nom **ne rend pas** `tool not found`, il est routé. Tester un ancien nom ne prouve donc **rien** sur la surface courante.

---

## §3 — Items par machine (hors outils MCP)

Ces items viennent de #1069 (leçon #1068 : un composant du harnais peut casser en silence sans qu'aucun autre ne le voie).

| # | Item | Instrument | Seuil / Attendu |
|---|------|------------|-----------------|
| 1 | **RAM** | `Get-CimInstance Win32_OperatingSystem` | usage **< 80 %** |
| 2 | **Tâches planifiées** | `Get-ScheduledTask` filtré `Claude*`/`Vibe*` | listener `Claude-DashboardListener` **présent** ; tout lanceur headless recensé nommément (état, action, trigger) |
| 3 | **Liveness du listener** | fraîcheur du heartbeat `listener-heartbeats/<machine>.heartbeat` | **< 10 min** (cadence nominale ~5 min). *Ne pas juger sur le bloc status du dashboard* |
| 4 | **Cron de session** | `CronList` | **exactement 1** job `/executor`, à la cadence de la lane (`41 */4` pour les exécuteurs, `23 */5` pour ai-01) |
| 5 | **`gh`** | `gh auth status` + `gh api user --jq .login` | identité attendue pour la machine, **API répond** (un 401 sur SSH est attendu sur web2) |
| 6 | **`git`** | `git status --porcelain`, branche, `git ls-tree HEAD mcps/internal` | worktree **propre**, branche par défaut, gitlink submodule aligné sur le build servi |
| 7 | **Claim worker** | `python scripts/github/check_issue_claim.py <NNN> --claim "<une ligne>"` | **claim posé** (le test réel de la leçon #1068 : un worker qui ne peut pas claimer est un harnais mort) |
| 8 | **Surface MCP** | `tools/list` du serveur en session | **17 outils** (§1) ; toute divergence = drift à signaler |

### Artefact attendu par machine

Un rapport, pas un verdict : pour chaque item, **la valeur mesurée** et l'instrument. Un item non mesurable se déclare **non mesuré** avec la raison — jamais « OK » par défaut.

Format de rapport (une ligne par item, plus le détail des anomalies) :

```
machine:workspace — RAM x% | tâches: <n> (<liste>) | heartbeat x min | cron <id> | gh <login> | git <sha> propre | claim <OK/KO> | surface <n> outils
```

---

## §4 — Ce qu'un audit NE doit pas conclure

- **« L'outil X est en panne »** parce qu'un **ancien nom** ne répond pas → §2 : c'est une fusion, la redirection est le comportement nominal.
- **« Le listener est mort »** parce que le bloc status du dashboard est vide → l'instrument est le **heartbeat**, pas le status.
- **« La tâche est cassée »** sur un `LastTaskResult` non nul d'une instance **Running** (`0x800710E0`) → artefact connu, partagé par plusieurs sièges ; le juge est la fraîcheur du heartbeat.
- **« L'absence est prouvée »** par l'échec d'une installation → l'absence se prouve par **énumération** (`Get-ScheduledTask`), jamais par déduction.
