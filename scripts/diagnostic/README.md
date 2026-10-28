# Scripts de Diagnostic

Ce dossier contient des outils pour effectuer des diagnostics techniques sur l'environnement et la configuration de l'application Roo.

## Contexte de la Refactorisation

Auparavant, ce dossier contenait un mélange de scripts de diagnostic technique et de validation fonctionnelle. Pour clarifier les responsabilités, les scripts ont été réorganisés :

-   Les outils de **diagnostic technique** (vérification de l'environnement, des chemins, des dépendances, etc.) ont été consolidés dans `run-diagnostic.ps1`.
-   Les scripts de **validation métier** (ex: "est-ce que la configuration des Modes est logique ?", "est-ce que le déploiement a réussi fonctionnellement ?") ont été déplacés dans le nouveau répertoire `../validation`.

## Script Principal

### `run-diagnostic.ps1`

C'est le point d'entrée unique pour le diagnostic technique. Il exécute une série de vérifications pour s'assurer que l'environnement est sain et que les configurations sont structurellement correctes.

#### Fonctionnalités

*   **Vérifications Multiples :** Exécute une suite de tests, incluant la vérification des chemins d'accès, la validité de l'encodage des fichiers de configuration, et la structure des fichiers JSON.
*   **Rapports Clairs :** Génère un rapport indiquant les succès et les échecs, aidant l'utilisateur à identifier rapidement les problèmes.
*   **Extensibilité :** Conçu pour pouvoir ajouter facilement de nouvelles routines de diagnostic.

#### Utilisation

Pour lancer une analyse complète de l'environnement :

```powershell
.\run-diagnostic.ps1
```

Pour cibler le diagnostic sur un aspect spécifique (si le script le supporte via des paramètres) :
```powershell
.\run-diagnostic.ps1 -Check "Encoding"
```

## Scanners de sessions Claude Code

### `scan-duplicate-tool-use.py`

Détecte la signature du bug harness #3276 (même `tool_use` émis puis exécuté deux fois — fork en deux nœuds transcript distincts) qui produit des effets de bord dupliqués (ex. 2 issues GitHub créées pour 1 seule intendue : CoursIA #13089/#13090, récidive #13108/#13109).

*   **EMIT_FORK :** le même id de bloc `tool_use` émis sur ≥ 2 nœuds à uuids DISTINCTS (le fork transcript ; lien parent-enfant rapporté quand présent).
*   **EXEC_DOUBLE :** ≥ 2 `tool_result` à uuids distincts pour un même id `tool_use`, avec contenu DIFFÉRENT — vraie double exécution.
*   **EXEC_COPY** (`--strict` uniquement) : ≥ 2 `tool_result` à uuids distincts au contenu identique — artefact de copie probable.

Ground truth structurel (vérifié sur transcripts réels, 2026-08-26 — ne pas régresser vers ces faux positifs) :

*   *Un nœud par content block* : une réponse assistant API est décomposée en un nœud par bloc (thinking → text → tool_use…), tous partageant le même `message.id`. « Deux nœuds même `message.id` » est la **norme**, pas la signature du bug.
*   *Ré-écriture au resume/fork* : reprendre une session ré-appende verbatim des plages antérieures — mêmes nœuds, **mêmes uuids**. Le scanner déduplique par uuid (comptés dans `rewritten nodes`) : ces copies ne sont PAS des ré-exécutions.

Le correctif racine est côté runtime Claude Code — ce scanner est l'instrumentation de détection, pas le fix. Tant que #3276 est ouverte, toute lane publiant des issues depuis un harnais Claude Code doit post-verify chaque `gh issue create` (re-lister le titre ~15 s après, supprimer la copie byte-identique vierge).

```powershell
# Scan complet des sessions locales (~/.claude/projects)
python scripts/diagnostic/scan-duplicate-tool-use.py

# Une session précise (ex. vérifier un transcript suspect)
python scripts/diagnostic/scan-duplicate-tool-use.py --file "<chemin>/session.jsonl"

# Sortie machine-readable (CI, scheduler) — exit 0 propre / 2 findings
python scripts/diagnostic/scan-duplicate-tool-use.py --json

# Validation autonome (fixture synthétique signature #3276)
python scripts/diagnostic/scan-duplicate-tool-use.py --selftest
```

### `audit-stale-mcp-disables.py`

Audit **lecture seule** des désactivations MCP fantômes de `~/.claude.json` (#4195, volet 3). L'emplacement `projects[<workspace>].disabledMcpServers` est indexé par le chemin absolu du workspace : après un déménagement (`C:\dev`→`D:\Dev`), la désactivation ne s'applique plus et le MCP est **réactivé silencieusement** (incident po-2024 09/10 : fenêtre OAuth ouverte sans demande, consigne user « svp ne faites pas ça »). Le résidu est invisible de l'intérieur d'une session.

- **STALE-GHOST** — clé `projects[chemin]` dont le chemin n'existe plus ET qui porte des `disabledMcpServers` (exit 2).
- **ACTIVE** — clé de chemin existant portant des désactivations (état légitime, informatif — c'est le contrôle gratuit d'ouverture de session, volet 1 de #4195).

```powershell
# Audit de ~/.claude.json
python scripts/diagnostic/audit-stale-mcp-disables.py

# Sortie machine-readable / fixture synthétique — exit 0 propre / 2 findings / 1 erreur
python scripts/diagnostic/audit-stale-mcp-disables.py --json
python scripts/diagnostic/audit-stale-mcp-disables.py --selftest
```

### `verify-fleet-manifest.py` (#2416 — prototype « fleet extension manifest »)

Vérification **lecture seule** du siège Claude Code de la machine contre le manifeste déclaratif `.claude/configs/fleet-manifest.json` (pattern source : devstack `pi-packages.json`). Le manifeste déclare l'état attendu (`required` / `allowed` / `retired`) ; le vérificateur lit les **trois emplacements** d'état MCP de `~/.claude.json` (#3137) — dont l'emplacement 3 `projects[<path>].disabledMcpServers`, qui **prime** sur l'activation. Complément de `audit-stale-mcp-disables.py` (qui audite les chemins fantômes en détail) : ici on compare à l'état attendu flotte, là-bas on détecte les résidus de déménagement.

- **MANIFEST_UNKNOWN / MISSING_REQUIRED / REQUIRED_DISABLED / RETIRED_PRESENT** (exit 2) — la machine ou sa config vivante dévie du manifeste. `required` est vérifié sur la **seule location 1** (user-scope, le contrat de `semantics.required`) — une install workspace-scope sous un autre projet ne le satisfait pas (#4336, réserve (A) de #4338) ; `retired`/`allowed` et les résidus restent mesurés sur l'union des locations 1+2.
- **UNEXPECTED_SERVER / GHOST_DISABLE_PATH / DISABLE_OF_UNINSTALLED** (warns ; exit 2 avec `--strict`) — serveur hors inventaire, désactivations sous chemin disparu (#4195), désactivation résiduelle d'un serveur non installé.

```powershell
# Vérifier la machine courante (machine = COMPUTERNAME, workspace = cwd)
python scripts/diagnostic/verify-fleet-manifest.py

# Machine / workspace / config explicites, sortie JSON, warns bloquants, fixture synthétique
python scripts/diagnostic/verify-fleet-manifest.py --machine myia-po-2024 --json
python scripts/diagnostic/verify-fleet-manifest.py --strict
python scripts/diagnostic/verify-fleet-manifest.py --selftest
```

**Exclusion `claude.ai`** (mesurée au rollout #4336, ai-01 26/10) — un **connecteur** claude.ai désactivé pour un workspace apparaît dans `disabledMcpServers` mais **jamais** dans `mcpServers` (son registre est `claudeAiMcpEverConnected`) : sans exclusion, `DISABLE_OF_UNINSTALLED` se déclenche sur tout siège ayant éteint un connecteur, et `--strict` en fait une erreur. Le même nom reste signalé tant qu'**aucune** entrée de registre ne le porte (résidu réel) — la paire est testée des deux côtés.

**Décision de câblage (#4336)** — contrôle **au pré-vol de session**, pas en CI : `executor-preflight.ps1` lance le vérificateur en lecture seule (**0,117 s médiane sur 5 runs ai-01**, même posture WARN-never-block que `[OAUTH-EXPIRED]`/`[DENY-FALLBACK]`). La CI ne peut pas le faire : la dérive porte sur le `~/.claude.json` **d'un siège**, qu'un runner GitHub n'a pas — un job CI n'exécuterait que `--selftest`, déjà couvert par `executor-preflight-manifest.Tests.ps1` (9 tests, dont 4 qui **exécutent** le vérificateur).

### `../transcript/Find-DuplicateToolUse.ps1` (PR #3498)

Variante PowerShell du même détecteur, ajoutée post-#3278. Mêmes signatures (`EMIT_FORK` / `EXEC_DOUBLE` / `EXEC_COPY`) sur un transcript unique, avec sortie `Object` / `Json` / `Summary` — utile quand le harnais cible est Windows natif (`powershell`) et que le Python n'est pas disponible. Tests Pester dans `scripts/testing/unit/Find-DuplicateToolUse.Tests.ps1` (12/12 verts).

```powershell
# Walk tous les transcripts sous ~/.claude/projects
Get-ChildItem ~/.claude/projects/*/*.jsonl | ForEach-Object {
    powershell -ExecutionPolicy Bypass -File scripts/transcript/Find-DuplicateToolUse.ps1 `
        -Path $_.FullName -OutputFormat Summary
}
```

Les deux outils sont **complémentaires**, pas redondants : le scanner Python fait le balayage de masse (exit codes CI-friendly), le script PowerShell est l'analyseur forensic d'un transcript précis (sortie structurée pour triage).

### `scan-approval-waits.py`

Instrument **côté transcript** des attentes d'approbation malgré bypass (#4214, mandat user 15/10). Apparie chaque `tool_use` Bash/PowerShell avec son `tool_result` dans `~/.claude/projects/**/*.jsonl` : entre les deux il n'y a **aucune génération modèle** (l'appel API suivant n'a lieu qu'après retour du résultat), donc l'écart = attente d'approbation + exécution + overhead client. Complément de `tool-gap.py` côté hub (claudish#474) : le hub voit l'écart mais pas la ligne de prompt ; le transcript porte la commande et sa forme.

- **Formes classifiées :** `composed-cd` (composé commençant par `cd` — forme dominante flotte, médiane 121 s des deux côtés), `composed`, `rm-rf`, `wsl`, `elevated`, `multiline`, `plain`.
- **Réduction de secrets (volet 1b + follow-up c.27) :** tout extrait de commande passe un réducteur avant sortie — `sk-`, `ghp_`/`gho_`/`ghu_`/`ghs_`, `Bearer`, `x-proxy-key`/`x-api-key`, familles d'assignation `*api_key*`/`*token*`/`*secret*`/`*password*` **insensibles à la casse** y compris formes drapeau (`--token=`), et **crédentials d'URL** (`scheme://user:pass@host` → `scheme://[REDACTED]@host`) : le **nom** reste, la **valeur** devient `[REDACTED]`, valeur quotée masquée entière (`"k1 k2"`) — la réduction précède la troncature pour qu'un extrait coupé ne fuie jamais une valeur partielle. Sortie collable sur dashboard/issue/PR par construction. Faux positifs possibles (ex. `--max-tokens=4096` masqué) : coût d'affichage seulement, assumé.
- **Déduplication resume :** mêmes uuids re-appendés = copies, sautées (comptées `rewritten nodes`) — même ground truth que scan-duplicate-tool-use.py.
- **Adjudication `--hook-log` (volet 3b) :** joint chaque finding au journal du hook `log-tool-start.js` (clé `(session_id, tool, commande brute)` + fenêtre) → `pre_exec_s` (approbation + overhead) / `exec_s` (exécution), étiquette `approval|exec`. Contrôle positif requis avant toute conclusion (dispatch c.28 : une commande délibérément soumise à approbation doit montrer `pre_exec_s` > 0).
- **Limite explicite :** l'écart ne départage PAS approbation vs exécution sans `--hook-log` (un `npx vitest run` de 320 s est une exécution) — le corpus headless (volet 2 de #4214) borne le plateau, la jointure tranche.

```powershell
# Fenêtre 24 h, seuil 120 s, top 30 par écart décroissant
python scripts/diagnostic/scan-approval-waits.py --min-wait 120 --since-hours 24 --top 30

# Sortie machine-readable — exit 0 propre / 2 findings
python scripts/diagnostic/scan-approval-waits.py --json

# Validation autonome (fixtures synthétiques)
python scripts/diagnostic/scan-approval-waits.py --selftest
```

### `detect-approval-stalls.py`

Détecteur **live** des sessions gelées en attente d'approbation (#4243, volet 3 — priorité user 18/10 : 2-3 agents gelés/jour, dont ~16 h sur ai-01:CoursIA). Tandis que `scan-approval-waits.py` mesure **a posteriori** les écarts refermés, celui-ci répond à la question opérationnelle : **qu'est-ce qui est bloqué MAINTENANT ?** Signature : dernier `tool_use` shell du transcript **jamais refermé** par un `tool_result` en fin de fichier — pendant l'attente silencieuse, plus rien n'est écrit dans le JSONL, donc le mtime du fichier date le début du gel. L'agent ne sait pas qu'il attend ; le cron suivant ne le débloque pas ; ce détecteur rend le gel visible depuis n'importe quel siège (ou sur transcripts copiés d'un incident).

- **Fenêtre active** (`--active-hours`, défaut 168) : seuls les fichiers modifiés dans la fenêtre sont lus — une session gelée n'écrit rien, son mtime EST le début de l'attente. Un gel de 16 h ou 3 j reste dans la fenêtre par défaut.
- **Seuil** (`--min-minutes`, défaut 10) : sous le seuil, une queue fraîche (tour en cours) n'est pas signalée ; un timeout d'exécution flotte est ≤ 600 s, donc 10 min ne confond pas une exécution longue avec une attente.
- **Adjudication `--hook-log`** (jointure #4214, optionnelle) : un marqueur d'exécution `log-tool-start.js` à/après le `tool_use` → `executing` (lag de transcript) ; pas de marqueur → `waiting-suspected`. Sans `--hook-log`, toute queue pendante = `waiting-suspected`.
- **Sidechains orphelines → `abandoned`** (nit review #4245, cas réel `2d17885a`) : un `tool_use` sidechain qui pend alors que la session **parente** a écrit après lui = sous-agent orphelin — personne ne répondra jamais, mais la queue lisait « live » jusqu'à la sortie de la fenêtre 168 h (des jours). Jointure même-fichier (les sidechains vivent dans le JSONL parent, flag `isSidechain` par enregistrement) : activité parent après le `tool_use` → `abandoned`. Signalé pour visibilité, compteur séparé, **ne déclenche pas l'exit 2** (comme `executing`).
- **Processus mort → `abandoned-process`** (facette détecteur #4243, demande ai-01 27/10) : la queue pendante d'une session dont le **processus n'existe plus** est textuellement identique à celle d'une session gelée — c'est justement la définition d'un gel, rien n'est écrit. L'ancienne version ré-annonçait donc la même session morte à chaque tick, aussi longtemps que le fichier restait dans la fenêtre mtime (cas rapporté : une session du 24/10 encore annoncée le 27/10). La vivacité se lit dans la **table des processus**, pas dans le transcript : *une attente créée à T ne peut être répondue que par un processus qui existait à T et tourne encore*. Aucun processus Claude vivant né à/avant T → l'attente est **morte** : classée `abandoned-process`, **enregistrée une seule fois** dans `~/.roo-state-manager/detect-approval-stalls/classified.json` (écriture atomique, rétention 30 j, clé = hôte + session + horodatage + outil — une nouvelle attente de la même session reste donc signalable), puis **plus jamais re-signalée** (compteur `already_classified`, et le tick suivant ne l'imprime plus). Au moins un processus né à/avant T → l'attente est **peut-être vivante** et continue de signaler : la jointure est **par hôte, pas par session**, donc la règle **prouve la mort** et ne peut que manquer de prouver la vie. Cette asymétrie est délibérée — une alerte en trop coûte une ligne, un gel manqué coûte une lane. **Limites avouées** : un transcript copié scanné sur un autre siège donne `unknown` (jamais `dead`) — appliqué par la règle *un `--root` autre que `~/.claude/projects` local force `unknown` quand la table des processus est celle de l'hôte* (review #4397 pt 2) ; une table illisible (énumération en échec) donne `unknown` = comportement d'avant, conservateur. **Une ligne de table indatable ne compte pas comme « aucun processus vivant »** (review #4397 pt 1) : la fraction 7 chiffres du format PowerShell `o` est tronquée à 6 (lisible sur tout Python, `fromisoformat` ≤ 3.10 n'acceptant que 3 ou 6), et une ligne qui reste illisible dégrade **toute la table** en `unknown` — jamais `[]`. Les deux sont le **défaut**, sans flag. **Une énumération qui imprime sans imprimer une seule ligne `pid|début` ne vaut pas mieux** (suite W1 de la review #4397) : rc=0 avec une sortie inexploitable rendait `[]`, donc « aucun processus vivant », donc tout `dead` — elle rend désormais `unknown` ; une sortie **vide** reste une table vide légitime (tick planifié sur un siège sans session vivante). Seams de test, non exposés en CLI : `STALL_DETECTOR_LIVE_PROCESSES` (`none` ou `pid@epoch,...`) et `STALL_DETECTOR_STATE_DIR` — une valeur mal formée du premier dégrade en `unknown` au lieu de crasher le tick.
- **Signal dashboard `--dashboard`** (#4243 attendu 3) : quand des stalls **en attente** sont trouvés, `--dashboard` poste une note WARN sur le dashboard de la lane (`workspace` par défaut) via le chemin JSON-RPC canonique des bots (`initialize` → `initialized` → `tools/call roosync_dashboard append`, pattern `Publish-FleetNote` du mcp-chain-watchdog). `messageId` idempotent (hôte + empreinte des stalls + bucket 15 min — un scheduler qui tique dans un incident converge vers UNE note par bucket) ; best-effort — un échec de signal n'altère **jamais** l'exit code ; `executing`/`abandoned`/`abandoned-process` ne signalent pas. **Le corps de la réponse `tools/call` est lu** : un `result.isError` derrière un HTTP 200 échoue la note (framing SSE toléré ; un corps non-JSON-RPC ne l'échoue pas — seule une erreur explicite compte). Bearer : `--dashboard-bearer` ou env `MCP_PROXY_BEARER` ; URL : `--dashboard-url` ou env `MCP_PROXY_BASE_URL` (défaut `https://mcp-tools.myia.io`). **L'activation planifiée (cron, câblage bearer) reste au coordinateur.** Délai par requête : `--dashboard-timeout` (défaut 10 s).
- **Activation planifiée : `run-approval-stall-detector.ps1`.** Le lanceur lit `MCP_PROXY_BEARER` et `MCP_PROXY_BASE_URL` dans le `.env` du bot au moment de l'exécution (même source et même parseur que `mcp-chain-watchdog.ps1`). Il les place dans l'environnement de son seul processus : le jeton n'apparaît ni dans la définition de la tâche, ni dans le journal. Défauts calés pour un tick toutes les 2 h :
  - `-ActiveHours 6` : une queue gelée sort de la fenêtre après environ trois ticks. Une fenêtre fermée ou une session morte n'est donc pas ré-annoncée pendant une semaine, ce que ferait le défaut de 168 h, une note par tick.
  - `-MinMinutes 15`.
  - `-DashboardTimeout 60` : sur le chemin proxifié, les appels dashboard de plus de 5 s avaient une médiane de 23 s le 19/10, et une note de test à 10 s a été perdue.

  Journal : `outputs/stall-detector/stall-detector.log`. Chaque tick y écrit une ligne d'en-tête (horodatage, code retour, état du signal), suivie de la sortie du détecteur. Code retour : celui du détecteur. `-DryRun` lance la détection sans signal et dit si le jeton a été trouvé.
- **Réduction de secrets** : extraits de commande passés par le même réducteur que `scan-approval-waits.py` (source unique, chargée par chemin) — collable sur dashboard par construction.
- **Exit codes** : 0 propre / 1 erreur / 2 stalls **en attente** (avec `--hook-log`, une queue adjudiquée `executing` ne déclenche pas l'exit 2 — lag de transcript ≠ gel ; idem `abandoned` et `abandoned-process`) — un scheduler peut se contenter du code retour. Le JSON expose les compteurs `waiting`/`executing`/`abandoned`/`abandoned_process`/`already_classified`.

```powershell
# Balayage du siège (défauts : ~/.claude/projects, seuil 10 min, fenêtre 7 j)
python scripts/diagnostic/detect-approval-stalls.py

# Transcripts d'incident copiés localement (ex. session 2d17885a d'un autre siège)
python scripts/diagnostic/detect-approval-stalls.py --root <dossier> --min-minutes 5

# Avec signal dashboard (stalls en attente -> note WARN sur le dashboard de la lane)
python scripts/diagnostic/detect-approval-stalls.py --dashboard --dashboard-bearer <tok>

# Tick planifie (jeton lu dans le .env du bot) ; -DryRun = detection sans signal
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\run-approval-stall-detector.ps1 -DryRun

# Sortie machine-readable / validation autonome
python scripts/diagnostic/detect-approval-stalls.py --json
python scripts/diagnostic/detect-approval-stalls.py --selftest
```

### `classify-machine-usability.ps1` (#4327)

Classifieur **par machine** lancé depuis ai-01, en **lecture seule sur les cibles** : `healthy` / `unreachable` / `reachable-but-unusable`. Le troisième verdict est le sujet : une machine peut répondre sur le réseau et être morte pour le travail — po-2028 s'est bloquée deux fois le 23/10, logon mort 3,5 à 4,5 min après un boot propre, WinRM répondant (~10 s), six demandes d'arrêt acceptées par `wininit` et jamais exécutées. Aucun organe existant ne le dit : `check-all-listeners.ps1` annonce « listener STALE » après 2 h (même ligne sur une machine saine au listener mort), `detect-approval-stalls.py` ne voit que les sessions vivantes et gelées.

- **Entrée décisive : le journal Système de la cible**, pas la latence WinRM. Au moins 5 événements `7031`/`7034` pour des instances de service suffixées `_<5 hex>` (LUID de session) dans la même seconde, dans la fenêtre `[boot+2 min, boot+20 min]` : mesuré 3/3 sur les blocages (T+3 min 28 s, 4 min 31 s, 3 min 38 s, ×6) et 0 sur les trois contrôles négatifs.
- **Latence** : aller-retour `Invoke-Command { 1 }` **authentifié**, anormal au-delà de 3 s sur 2 de 3 sondes (sain mesuré 249-445 ms ; bloqué ~10 s). WS-Identify (non authentifié) est une **reachabilité seule** — un 401 est une réponse, jamais un silence — et ne nourrit aucun verdict de blocage.
- **Barre de liveness à deux moitiés** (spec `ai-01:Maintenance`, 24/10 §2) : heartbeat du listener **plus vieux que 30 min** **ET** aucun append dashboard d'aucune lane de la machine. Une seule moitié fraîche suffit à écarter la corroboration ; une moitié **non mesurée** ne corrobore pas et est nommée (`dashboard-append-unknown`). Auteurs synthétiques exclus de la lecture des dashboards (`system` = condenseur, `listener`, `classifier` — sinon une alerte se corroborerait elle-même au tour suivant).
- **Verdict** : `unreachable` = 5985 **et** 3389 fermés (22 pour les sièges Linux) ; `reachable-but-unusable` = joignable **et** (burst, suffisant seul, **ou** latence anormale **et** les deux moitiés silencieuses) ; sinon `healthy` avec les findings (`listener-stale`, `heartbeat-unknown`, `dashboard-append-unknown`, `driving-channel-slow`, `system-log-unavailable`, `external-4624-logons`…). `heartbeat-unknown` (fichier absent) reste `healthy` + exit 0 **délibérément** : l'absence du fichier est une mesure de l'entrée, et po-2028 vit et publie sans ce fichier (mesuré 25/10) — la replier dans l'exit 3 signalerait une machine qui travaille.
- **Alerte** : un seul `[FLEET-ALERT]` sur le dashboard de la machine **affectée** (cross-post `workspace:Maintenance`), première ligne nommant la machine, corps nommant chaque entrée et son seuil. **Le levier dur n'est pas tiré ici** — il reste à la lane Maintenance (`fleet_remote_reboot.ps1 -Hard`), qui répond sur le même fil.
- **Rejeu** : `-ReplayFile` rejoue un relevé enregistré (même détecteur que le chemin live) et **mesure** le délai de détection depuis la mort de logon enregistrée — rejeu du 23/10 sur la fixture issue du CSV Maintenance : `reachable-but-unusable`, détecté **1,3 min** après le burst, cible 10 min.
- **Exit codes** : 0 tout va bien / 1 une machine injoignable / 2 au moins une `reachable-but-unusable` / 3 mesure incomplète (instrument absent, journal Système illisible sur un siège Windows, **fichier de credential absent/invalide** — il échoue loud avant toute sonde, jamais de repli silencieux sans credential) — jamais « tout va bien » sur une mesure manquante.
- **Tir planifié (RX122)** : `scripts/scheduling/install-usability-classifier-task.ps1` (à exécuter une fois par l'utilisateur, sans élévation) enregistre `Claude-UsabilityClassifier` — 5 min, utilisateur courant, fenêtre cachée (VBS `wscript` de la convention `harden-hidden-tasks`) — avec un fichier de credential DPAPI (`~\.roo-state-manager\winrm-classifier.cred.xml`, `Import-Clixml` via `-CredentialFile`) ; le lanceur `start-usability-classifier.ps1` journalise dans `outputs/scheduling/logs/usability-classifier.log`. L'installation refuse d'enregistrer si `system-log-unavailable` persiste sur **tous** les sièges Windows joignables (le credential ne marche pas). **Une alerte par incident** : l'id `classifier-4327-<machine>-unusable-<boot yyyyMMddTHHmm>` (+ la minute du burst mesuré quand il existe — un second blocage sur le même boot est un incident nouveau) est stable tant que l'incident ne change pas ; la déduplication du post machine est un **état local** sur le siège détecteur (`outputs/diagnostic/state/classifier-incidents.json`, gitignored, écrit seulement après le post accepté, absent/corrompu → on poste, jamais silencieux) et non le fichier du dashboard (qui se condense et ferait défiler l'id hors du fichier vivant) ; le cross-post `workspace:Maintenance` tourne à chaque tir, idempotent par `--message-id <id>-maint`, et une entrée d'état est retirée quand la machine redevient `healthy`. **La tâche ne tire que pendant qu'une session utilisateur est ouverte** (logon Interactive, sans mot de passe stocké) : machine verrouillée/déconnectée = pas de tir.

```powershell
# Balayage live de la flotte (aucune alerte, JSON)
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\classify-machine-usability.ps1 -NoAlert -Json

# Rejeu du 23/10 (fixture générée depuis le CSV de la spec Maintenance)
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\classify-machine-usability.ps1 -ReplayFile scripts\diagnostic\fixtures\po2028-20261023.json -NoAlert

# Tir planifié : preview de l'installation (rien n'est écrit)
powershell -ExecutionPolicy Bypass -File scripts\scheduling\install-usability-classifier-task.ps1 -DryRun
```

### `check-deny-fallback.py`

Sonde **deny-sans-repli** au démarrage (#4340, mandat user 24/10 — incident po-2027 : le repli `jupyter-papermill` désigné par la règle n'a jamais été provisionné, indétecté des semaines, fallback interdit normalisé à la place). Pour chaque outil deny dont une règle désigne un repli canonique unique (`DENY_FALLBACK_MAP`, démarre à `NotebookEdit` → `jupyter-papermill`) : le serveur repli est-il configuré et **répond-il** ? La vérification est un **handshake stdio réel** (`initialize` → `tools/list`) — jamais les drapeaux : `disabled: true` dans une entrée `.mcp.json` est inert sur un siège Claude Code (mesuré po-2025 24/10), seul `projects[<ws>].disabledMcpServers` désactive effectivement.

- **Statuts** : `INERT` (outil non deny — le workspace décide) / `OK` / `DENY-WITHOUT-FALLBACK` (l'incident po-2027) / `FALLBACK-DISABLED-SEAT` / `FALLBACK-DEAF` (handshake muet ou 0 outil).
- **Exit codes** : 0 rien à signaler / 1 erreur d'instrument / 2 ≥1 finding — c'est le contrat sur lequel branche le pré-vol executor (`scripts/claude/executor-preflight.ps1`, WARN-never-block posture #3169 : la **capacité** est bloquée, jamais de workaround ; le cycle continue).
- **Timeout défaut 30 s**, délibéré sur le `CONNECT_TIMEOUT` de l'hôte : un serveur plus lent que le cutoff de l'hôte est un repli effectivement absent, pas lent.
- Le provisioning reste une **décision par workspace** (arbitrage user 24/10) — pas de déploiement flotte aveugle.

```powershell
# Sonder un siege (le deny actif EST le signal d'opt-in de la verification)
python scripts/diagnostic/check-deny-fallback.py --workspace <chemin>

# Fixtures synthetiques + handshake reel contre un fake serveur MCP (7 scenarios)
python scripts/diagnostic/check-deny-fallback.py --selftest
```

Détail complet (câblage canonique `jupyter-papermill`, intégration pré-vol, conduite sur finding) : [`docs/harness/reference/deny-fallback-probe.md`](../../docs/harness/reference/deny-fallback-probe.md).

### `probe-hermes-liveness.py`

Sonde **lecture seule** du « statut de liveness menteur » des crons Hermes (#4247, action #3 — « re-mesurer la proportion de faux `ok` »). Le champ `last_status` de `~/.hermes/cron/jobs.json` est un champ **dernier-écrivain, sans lien avec le fire courant** ; le ledger `executions.db` porte, lui, l'état **par fire** (`claimed`/`running`/`completed`/`failed`/`unknown`, ce dernier écrit par le reaper). Une sonde qui ne lit que `last_status` peut donc voir `ok` — l'estampille d'un run antérieur — pendant qu'un fire est bloqué, sans aucune contradiction visible dans ce champ.

Croise les deux instruments par `job_id` et ventile les faux `ok` par famille :

- **`wedged`** — dernier fire encore `claimed`/`running` au-delà de `--wedged-minutes` (défaut 30) ;
- **`reaped`** — dernier fire `unknown` (le reaper a repris la main) ;
- **`failed`** — dernier fire `failed` alors que le job dit `ok` ;
- **`errored`** — dernier fire porteur d'une erreur alors que le job dit `ok` ;
- **`ok-last-error`** — le job dit `ok` mais `last_error` est renseigné.

Un statut de ledger **hors vocabulaire connu** (`claimed`/`running`/`completed`/`failed`/`unknown`) n'est ni un finding ni un silence : il est surfacé dans `latest_unrecognized_status` — l'instrument ne suppose pas un état qu'il ne sait pas lire.

**`false_ok_pct` est une métrique de croisement ledger** : son numérateur ne compte que des jobs que le ledger a réellement vérifiés. Un signal `ok-last-error` sur un job **sans** ledger reste un finding (contradiction interne à `jobs.json`), compté à part dans `ok_last_error_without_ledger`, mais n'entre jamais dans le pourcentage — qui ne peut pas dépasser 100.

Les familles (a) `no_agent` sans preuve et (b) agent muet de l'issue **ne sont pas mesurables par le ledger** : elles sont silencieuses-**par conception**, et le rappel anti-pendule du diagnostic du 20/10 tient — le correctif est de rendre le silence **distinguable** d'un run qui a rapporté, jamais de transformer le silence en erreur. La sonde ne les invente pas : elle mesure la moitié que le ledger prouve et dit quelle part de la population reste inexpliquée.

- **Schéma tolérant** : la table et les colonnes sont découvertes (`job_id`/`jobid`/`job`, `status`/`state`, `error`/`err`, `finished_at`/`updated_at`/`started_at`…), et `jobs.json` est accepté en liste, `{"jobs": [...]}` ou `{"jobs": {id: {...}}}` — l'instrument ne suppose pas une forme qu'il n'a pas vérifiée.
- **Fail-closed** : entrée absente ou illisible = exit 1, jamais « aucune contradiction » (exit 0) ; pas de table exploitable = erreur, pas un résultat vide. **Gardié par le selftest au niveau CLI** (deux appels subprocess assert exit 1) — un mutant qui remapperait le chemin d'erreur sur exit 0 rend le selftest rouge.
- **Lecture seule** : `executions.db` est ouvert en mode SQLite `mode=ro` + `PRAGMA query_only` (le runtime appartient au siège qui héberge Hermes) ; le selftest vérifie qu'une écriture **échoue**.
- **Aucun secret en sortie** : les payloads des jobs (prompts) et le **texte** des erreurs ne sont jamais imprimés — seulement ids, noms, statuts et la **longueur** de l'erreur.

```powershell
# Sur le siege qui heberge Hermes (defauts ~/.hermes/cron/)
python scripts/diagnostic/probe-hermes-liveness.py

# Cibles explicites + seuil de blocage + sortie machine
python scripts/diagnostic/probe-hermes-liveness.py --jobs <jobs.json> --executions-db <executions.db> --wedged-minutes 60 --json

# Fixture synthetique : une famille par cas + controles negatifs (fire anterieur, fire
# en vol, job sans ledger, statut hors vocabulaire, fail-closed au niveau CLI)
python scripts/diagnostic/probe-hermes-liveness.py --selftest
```

Exit codes : 0 aucune contradiction / 2 findings / 1 erreur d'instrument.

## Sondes d'indexation sémantique

### `probe-semantic-known-answer.py` (#4352, critère 4)

Sonde à réponse connue pour la recherche sémantique : **indexe une session connue, puis vérifie qu'une requête `roosync_search(semantic)` sur une phrase de cette session la classe dans le top 5**. Deux phases, deux sièges — la phase INDEX vit sur le siège qui possède la session, la phase VERIFY peut tourner sur n'importe quel siège (contrôle cross-siege du trou de partition flotte #4352).

- **Résolution de session** via `conversation_browser(list)` — fenêtre 24 h et 10 Ko-2 Mo (au-delà, l'indexation synchrone risque le timeout outil 300 s, trou g3) ; **jamais de lecture directe du JSONL** (#1785).
- **`source: "claude-code"` obligatoire à l'indexation** : le défaut du service est `roo`, qui résout `<location>/tasks/<id>` — un **répertoire** de tâche. Une session Claude Code est un `.jsonl` plat, résolu par l'autre branche : sans ce champ l'indexation échoue à coup sûr (« Task directory for '…' not found in any storage location », mesuré 28/10 sur 3 candidats). La sonde le déduit de `source` au listing.
- **Borne dure 300 s nommée, pas subie** : au-delà de la taille, `roosync_indexing` rend `-32603 « timed out after 300s »` — le transport MCP coupe **avant** toute réponse d'indexation. La sonde étiquette l'essai `[g3: indexation SYNCHRONE bornée à 300 s]` et propose `--task-id` sur une session plus petite, au lieu de rendre « instrument en panne ».
- **`queued:false` explicite** (#4352 g3) : depuis ms#1543 l'indexation **met en file par défaut** et rend aussitôt — « en file » n'est pas « indexé », or la sonde a besoin d'un index **terminé** avant d'extraire sa phrase. Dans un enfant spawné le défaut échoue même franchement (`isError:true`, « queued (défaut) exige le state du processus hôte »). La sonde demande donc explicitement le chemin en ligne ; son timeout reste alors borné par la limite 300 s du transport (défaut g3, nommé dans le label d'échec).
- **Extraction de phrase** distinctive par balayage inversé (contenu tardif = plus spécifique) sur l'**arbre texte multi-lignes** du `view` (`detail_level: "summary"` — le vocabulaire de `view` est `skeleton|summary|full` SEULEMENT, garde #3187 ; « Compact » appartient à `summarize`), filtres anti-secrets (`API_KEY`, `sk-`, `ghp_`, `BEGIN … PRIVATE`…) et anti-bruit non sémantique (lignes d'outil, markdown lourd, **préfixes d'erreur serveur** `Erreur:`/`Error:` — un message d'erreur fait 60-240 caractères et passe toutes les autres bornes, il ne doit jamais devenir la phrase de sonde, review #4398).
- **Repli textuel refusé** : si le backend d'embeddings tombe, `roosync_search` bascule en recherche **textuelle** et le signale (`semantic_degraded`, `fallback_used`, `actual_search_mode: "text"` — `roosync-search.tool.ts:289-316`). Ces lignes portent aussi un `taskId`, donc une phrase verbatim peut ranker en top 5 : un PASS textuel certifierait le critère 4 avec le **mauvais backend**. La sonde lève un verdict **DEGRADED** (exit 2, mode dans le label), jamais un PASS (review #4398 r2).
- **Erreurs serveur rendues en contenu** (`isError: true`) : `call_tool` lève — sans cette garde le texte d'erreur deviendrait une donnée de sonde (mesuré par Hermes, review #4398 : la sonde continuait vers VERIFY avec le message d'erreur comme requête sémantique). Le drapeau est lu **au niveau du résultat** (`{content: […], isError: true}` — `conversation-browser.ts:351/373/473`, `index.ts:755`), pas par bloc de contenu : la forme testée par le selftest est celle que le serveur émet réellement (review #4398 r2).
- **Transport autonome** : spawn d'un enfant RSM en stdio (JSON-RPC), entrée résolue via `build-current` — aucun état de session hôte n'est supposé, la sonde marche depuis un checkout quelconque avec `--rsm-dir`.
- **Résultats d'outil parsés depuis le JSON pretty-printé embarqué** dans `content[0].text` (première `{` à dernière `}`), avec trailers `[NOTIF]`/timing tolérés — le piège qui a fait échouer la sonde §1.4 de #4131 deux fois avant correction.
- **Fail-closed** : réponse non parsable, indexation en échec, recherche non sémantique ou enfant muet = exit 2 (erreur d'instrument / DEGRADED), jamais un FAIL silencieux ; le selftest hors ligne couvre phrase, rejet erreur-comme-phrase, vocabulaire + arguments du `view`, parsing, rang top-5, refus du repli textuel (drapeau **et** mode seul), timeout d'enfant muet et `isError` au niveau résultat.

```bash
# Auto-contrôle local (index + verify sur le même siège)
python scripts/diagnostic/probe-semantic-known-answer.py

# Contrôle cross-siège : phase A sur le siège propriétaire…
python scripts/diagnostic/probe-semantic-known-answer.py --index
# …copier task_id + phrase, puis sur un AUTRE siège :
python scripts/diagnostic/probe-semantic-known-answer.py --verify \
    --task-id claude-c--dev-roo-extensions--<uuid> --phrase "..."

python scripts/diagnostic/probe-semantic-known-answer.py --selftest   # fixtures hors ligne
```

Exit codes : 0 PASS (top 5 atteint) **ou INDEXED** (phase `--index` seule réussie — un wrapper qui enchaine A puis B ne doit pas s'arrêter après A, review #4398) / 1 FAIL (sonde saine, critère non tenu — phase verify) / 2 erreur d'instrument **ou recherche servie par un mode non sémantique (verdict `DEGRADED`)**.

## Compteurs mémoire

### `log-commit-charge.ps1` (#2992)

Logger read-only du commit charge Windows (`CommittedBytes` / `CommitLimit`), écrit pour mesurer le **pic de commit pendant le chargement d'un modèle vLLM** — jamais mesuré car rien sur l'hôte ne logge ces compteurs en continu. Une ligne JSON par échantillon (`samples.jsonl`) + un `_summary.json` écrit en sortie **y compris sur Ctrl+C** (bloc `finally`), avec pour chaque échantillon : commit, limite, `FreeVirtualMemory` (KB), pagefile alloué, pools, somme du commit privé des processus, et le solde **non attribué** (commit − processus − pools — page tables, sections, driver-locked).

- **Locale-proof par construction :** lit uniquement des classes CIM aux noms de propriétés anglais sur toute locale (`Win32_PerfFormattedData_PerfOS_Memory`, `Win32_OperatingSystem`, `Win32_PageFileUsage`). L'original archivé (`_archive/cleanup-3323-2026-08-31/`) lisait les compteurs perf par nom anglais via `Get-Counter` → silencieusement vide sur locale FR (défaut connu #2992). `Get-Counter` est ici interdit par les tests.
- **Auto-validation :** chaque échantillon porte les deux sources de l'identité `FreeVirtualMemory ≈ CommitLimit − CommittedBytes` (vérifiée sur machine FR : écart ~0,14 % de la limite) — un échantillon incohérent se voit sans instrument externe.

```powershell
# Runbook #2992 (avant le prochain restart vLLM sur ai-01) :
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\log-commit-charge.ps1 `
    -OutputDir C:\temp\memdiag\peak -IntervalSec 10
# puis, dans un autre terminal : docker start myia_vllm-...
# stop par Ctrl+C une fois le modèle chargé ; poster samples.jsonl sur #2992.
```

Tests Pester : `scripts/testing/unit/log-commit-charge.Tests.ps1` (13 tests — contrat statique toutes plateformes + micro-run live Windows avec l'identité sémantique à 2 % de tolérance).
