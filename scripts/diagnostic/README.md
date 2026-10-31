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

- **Succès d'indexation sous ses DEUX formes, et `0` n'est pas un échec** (crit. 4, mesure ai-01 28/10) : le chemin en ligne (`queued:false`) répond en **Markdown** — `# Indexation sémantique terminée` + `**Chunks indexés:** N` (`index-task.tool.ts:108`) — et, depuis ms#1560, y ajoute un **bloc JSON embarqué** (`{success, chunksExtracted, subChunksBuilt, dedupSkipped, chunksIndexed, missingVectors, reason}`). Exiger `success:true` dans un JSON faisait donc lire **tout succès inline comme une panne** : premier `--index` live sur ai-01 → exit 2 `INSTRUMENT_ERROR` alors que l'indexation avait abouti (verdict faux, mesure saine — 3e variante de la classe « verdict masqué »). La sonde normalise les deux formes (`form: "json"|"markdown"`, clé `chunks_indexed` unifiée) et **poursuit vers VERIFY sur 0 chunk** : 0 veut le plus souvent dire « déjà indexée pour cette tâche » (dédup ms#1557), et c'est la recherche qui tranche — jamais un compteur. Le succès Markdown seul reste couvert (serveurs antérieurs à ms#1560) ; une réponse `# Erreur d'indexation`, un `success:false` ou un texte vide restent des échecs. **Précédence** : quand un bloc JSON **portant une clef `success`** accompagne l'en-tête Markdown, c'est lui qui fait foi — un `success:false` derrière « terminée » est un échec, pas un succès (cas aujourd'hui injoignable côté serveur, rendu impossible ici, file `20261028i` suivi 1) ; un JSON **sans clef `success`** est du contenu cité (aperçu de résultat d'outil) et ne prime pas sur l'en-tête.
- **Résolution de session** via `conversation_browser(list)` — fenêtre 24 h et 10 Ko-2 Mo (au-delà, l'indexation synchrone risque le timeout outil 300 s, trou g3) ; **jamais de lecture directe du JSONL** (#1785).
- **`source: "claude-code"` obligatoire à l'indexation** : le défaut du service est `roo`, qui résout `<location>/tasks/<id>` — un **répertoire** de tâche. Une session Claude Code est un `.jsonl` plat, résolu par l'autre branche : sans ce champ l'indexation échoue à coup sûr (« Task directory for '…' not found in any storage location », mesuré 28/10 sur 3 candidats). La sonde le déduit de `source` au listing.
- **Borne dure 300 s nommée, pas subie** : au-delà de la taille, `roosync_indexing` rend `-32603 « timed out after 300s »` — le transport MCP coupe **avant** toute réponse d'indexation. La sonde étiquette l'essai `[g3: indexation SYNCHRONE bornée à 300 s]` et propose `--task-id` sur une session plus petite, au lieu de rendre « instrument en panne ».
- **`queued:false` explicite** (#4352 g3) : depuis ms#1543 l'indexation **met en file par défaut** et rend aussitôt — « en file » n'est pas « indexé », or la sonde a besoin d'un index **terminé** avant d'extraire sa phrase. Dans un enfant spawné le défaut échoue même franchement (`isError:true`, « queued (défaut) exige le state du processus hôte »). La sonde demande donc explicitement le chemin en ligne ; son timeout reste alors borné par la limite 300 s du transport (défaut g3, nommé dans le label d'échec).
- **Extraction de phrase** distinctive par balayage inversé (contenu tardif = plus spécifique) sur l'**arbre texte multi-lignes** du `view` (`detail_level: "summary"` — le vocabulaire de `view` est `skeleton|summary|full` SEULEMENT, garde #3187 ; « Compact » appartient à `summarize`). Le **préfixe de rendu `| `** est retiré avant tout filtre : le renderer préfixe chaque ligne de message `<indent>    | <ligne>` (`view-conversation-tree.ts:1245`), et le filtre markdown `|` (juste par ailleurs) rejetterait **toute la prose réelle**. Les **lignes du renderer** sont exclues (`[🛠️ …] → success (hh:mm:ss)`, `[⚙️ …]`, `[NOTIF]`, `[⏱`, `[... N message(s) omise(s) ...]`, `• ` diagnostics de troncature, `▶️ Task:`, `====`) : elles ne sont pas indexées telles quelles (un tool est stocké sous `Tool call: <name> with args …`, `ChunkExtractor.ts:1031`) — en retenir une donne un FAIL garanti ou un PASS accidentel (review #4398 r3 : mesuré 3 candidats sur 3 chez ai-01). S'y ajoutent les filtres anti-secrets (`API_KEY`, `sk-`, `ghp_`, `BEGIN … PRIVATE`…), anti-bruit non sémantique (lignes d'outil, markdown lourd) et **préfixes d'erreur serveur** `Erreur:`/`Error:` — un message d'erreur fait 60-240 caractères et passe toutes les autres bornes, il ne doit jamais devenir la phrase de sonde (review #4398).
- **Sorties d'outil génériques refusées + rareté mesurée** (file 20261028i, mesure ai-01 28/10) : le verify live a FAIL sur « Message ajouté au dashboard 'workspace-roo-extensions' » — la ligne de succès standard de **chaque** append, présente dans des centaines de sessions : ce FAIL ne mesurait rien. Désormais (1) `pick_phrase` refuse statiquement les sorties d'outil génériques (`Message ajouté au dashboard`, `Message envoyé`, en-têtes de boîte) et les en-têtes gras (`**Tâche:**`, `**Status**`…), **sur la ligne nue** — les décorations `✅`/`[OK]`/`Succès :` sont retirées avant le test (review #4412 : `✅ Message ajouté…` passait le `startswith` brut), et une ligne de tableau markdown dont le premier `|` a été consommé par le préfixe de rendu est refusée par sa signature ` | ` ×2 ; (2) la phrase retenue doit être **rare** : un **scan verbatim local** (`--corpus-dir`, défaut `~/.claude/projects`) la retrouve dans **exactement 1 session** (la cible), sinon la candidate suivante est essayée (≤ 5 essais, puis échec bruyant qui nomme chaque candidate et son compteur, en séparant « trop banale » de « absente du corpus local ») ; un texte où TOUTE ligne est refusée statiquement échoue avec un message distinct (« filtrage statique », 0 mesure consommée) — pas comme un échec de rareté. **Pourquoi pas la recherche texte** (review ai-01 sur `81fd1c93`) : `roosync_search(action:"text")` découpe la requête en jetons et matche sur **n'importe lequel** (`search-fallback.tool.ts:76-79`, « match ANY token ») en rendant `totalFound = cleanResults.length` (`:247`) — un compte **plafonné** de tâches qui partagent au moins un mot commun ; une phrase présente dans sa seule session y « apparaissait » dans toutes celles contenant « session » ou « dashboard », les 5 candidates s'épuisaient et le verify ne tournait jamais. Le scan lit les transcripts `.jsonl` eux-mêmes, en forme brute **et** échappée JSON (un guillemet y est `\"` : sous-compter serait le sens dangereux, celui qui fait passer une phrase banale pour rare). **Fail-closed** : corpus absent ou vide, session illisible, candidate sans mesure → erreur, jamais un compte nul implicite. **Un spread de 0 est refusé** : la phrase vient de la cible, donc le scan doit la retrouver au moins chez elle ; 0 = corpus incomplet ou phrase mangée par le rendu. La mesure est rapportée dans `rarity` (champs `corpus_sessions` et `spread`) — un verdict live dit alors sur quel corpus et avec quel spread la phrase a été retenue. **Une entrée = une session** : les transcripts de sous-agents (`<session>/subagents/*.jsonl`) sont **écartés, pas lus** — une session est représentée par son transcript de tête seul, le contenu des sous-agents n'est ni balayé ni fusionné (seul leur nombre est rapporté dans l'erreur de corpus vide) ; comptés comme des sessions, ils feraient 2 pour une phrase présente chez la seule cible et l'arme « spread ≤ 1 » refuserait la bonne phrase. **Le compte est par session, PAS par ligne** (review ai-01 r4, 29/10) : une phrase qui réapparaît sur plusieurs lignes du même transcript (une session qui cite sa propre réponse ou un écho d'outil) y compte **une seule fois** — l'ancien incrément par ligne saturait le spread à 2 et refusait une phrase qui n'existait que chez elle. **Éligibilité du corpus** (observation de la même review) : un `.jsonl` n'est une session que s'il est posé dans le layout réel d'une session indexable (`<projets>/<hash>/<uuid>.jsonl`, ou directement dans le répertoire projet) ; `memory/…` et les sous-dossiers plus profonds sont **écartés** et comptés dans le message d'erreur — aucun fichier n'est supprimé. **Lecture linéaire et bornée** (review ai-01 #4412) : le transcript est parcouru **par `readline(plafond + 1)`**, jamais en un bloc — un `for line in fh` aurait encore alloué la ligne entière avant qu'on puisse la mesurer, donc un unique enregistrement géant aurait coûté sa taille. Plafond de ligne 32 Mo ; plafond de fichier **4 Go, garde anti-dérive seulement**. **Mesure web1 29/10** (transcript synthétique de 315 Mo) : pic tracemalloc **0,04 Mo** en lecture linéaire contre **945 Mo** pour l'ancien `read_text` — ~3× la taille du fichier, ratio **21 000** ; 315 Mo balayés en 12,6 s, tracemalloc actif. **Contrôle du cas pathologique** : une **unique** ligne de 100 Mo picote à 67 Mo (bornée par le plafond de ligne) et lève `InstrumentLimit` — elle n'est jamais chargée entière. C'est pourquoi le plafond de fichier n'est **pas** ramené à 100-256 Mo : la mémoire ne dépend plus de lui, et un plafond bas rendrait la sonde inutilisable sur le siège qui a motivé la review (ai-01 porte un transcript de **737 Mo** — à 256 Mo, chaque run y sortirait en exit 2 sans rien mesurer). Un fichier ou une ligne au-delà **ne fait pas sauter le fichier puis PASS** : la mesure lève `InstrumentLimit` et le processus sort en **exit 2 (INSTRUMENT)** en nommant le compte et le volume des exclusions ; `MemoryError` est également mappé en exit 2 (il sortait en exit 1 = FAIL alors que la mesure n'avait pas eu lieu). Depuis le mandat ai-01 du 29/10, `InstrumentLimit` est en outre un **abort global en phase d'index** : elle se propage **immédiatement** hors de la boucle par candidat (elle hérite de `RuntimeError`, le gestionnaire par essai l'avalait — le candidat suivant re-balayait le corpus et re-payait un appel d'index pour le même verdict), un **seul scan** et **aucun appel d'index suivant** ; un wrapper CI (`scripts/testing/python/test_probe_semantic_known_answer.py`) exécute le selftest hors ligne **plus un témoin négatif** — une copie de la sonde privée de la clause d'abort doit faire échouer le selftest, sinon le job CI devient rouge. **Coût** : **une passe par ensemble de ≤ 5 phrases de chaque essai** (un essai = un candidat tenté, ≤ 3 par run — la boucle d'index appelle le scan une fois par candidat), et non une passe par phrase. Repères : web1 315 Mo → 12,6 s (25 Mo/s, tracemalloc actif, donc plancher) ; **ai-01, mesure de la review** : 73-83 s par passe complète sur 7 486 fichiers / 16,1 Go, là où l'ancien chemin en faisait jusqu'à trois (~8 min). Le balayage va au bout du corpus — une phrase rare ne sature jamais — et reste sous le timeout de la phase.
- **Repli textuel refusé** : si le backend d'embeddings tombe, `roosync_search` bascule en recherche **textuelle** et le signale (`semantic_degraded`, `fallback_used`, `actual_search_mode: "text"` — `roosync-search.tool.ts:289-316`). Ces lignes portent aussi un `taskId`, donc une phrase verbatim peut ranker en top 5 : un PASS textuel certifierait le critère 4 avec le **mauvais backend**. La sonde lève un verdict **DEGRADED** (exit 2, mode dans le label), jamais un PASS (review #4398 r2).
- **Erreurs serveur rendues en contenu** (`isError: true`) : `call_tool` lève — sans cette garde le texte d'erreur deviendrait une donnée de sonde (mesuré par Hermes, review #4398 : la sonde continuait vers VERIFY avec le message d'erreur comme requête sémantique). Le drapeau est lu **au niveau du résultat** (`{content: […], isError: true}` — `conversation-browser.ts:351/373/473`, `index.ts:755`), pas par bloc de contenu : la forme testée par le selftest est celle que le serveur émet réellement (review #4398 r2).
- **Transport autonome** : spawn d'un enfant RSM en stdio (JSON-RPC), entrée résolue via `build-current` — aucun état de session hôte n'est supposé, la sonde marche depuis un checkout quelconque avec `--rsm-dir`.
- **Résultats d'outil parsés depuis le JSON pretty-printé embarqué** dans `content[0].text` (première `{` à dernière `}`), avec trailers `[NOTIF]`/timing tolérés — le piège qui a fait échouer la sonde §1.4 de #4131 deux fois avant correction.
- **Fail-closed** : réponse non parsable, indexation en échec, recherche non sémantique ou enfant muet = exit 2 (erreur d'instrument / DEGRADED), jamais un FAIL silencieux ; le selftest hors ligne couvre phrase (fixture `view` en **forme de renderer réelle**, avec assertions anti-renderer), rejet erreur-comme-phrase, refus des sorties d'outil génériques + rareté **verbatim** mesurée (spread e2e sans aucun `roosync_search` : la ligne à 3 sessions écartée, la prose cible retenue à 1 ; une phrase dont seuls les **jetons** sont partagés reste à 1 et non 4 ; guillemet échappé reconnu ; corpus absent ou vide refusé ; **répétition d'une même phrase sur plusieurs lignes d'une session comptée UNE fois** (le compte est par session) ; la même phrase dans deux sessions distinctes sature toujours ; des **candidates répétées** ne changent pas la mesure et l'arrêt précoce après saturation reste atteint ; un `.jsonl` hors layout de session est écarté du corpus), vocabulaire + arguments du `view` et `source:"all"` du `list`, `createdAt` non-texte écarté, parsing, rang top-5, refus du repli textuel (drapeau **et** mode seul), timeout d'enfant muet et `isError` au niveau résultat.

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

### `g6-pass-bound.py` (#4352, critère g6)

Juge une **passe d'indexation** contre le **paceur**, pas contre une horloge plate. Le critère « 10 min, 5/5 » condamnait un worker sain : la passe de 655 s mesurée sur po-2028 (28/10) vaut `109 requêtes × 6 s` à `EMBEDDING_OPS_PER_MINUTE=10`, soit exactement ce que le paceur autorise.

- **Borne dérivée sur les REQUÊTES** : `Δrequests × (60 000 / EMBEDDING_OPS_PER_MINUTE) × marge (1,5)` — `Δrequests` lu sur une fenêtre qui **contient** la passe (dernière `[EMB-METRICS]` avant le début, première après la fin). **Pas `called`** : `called` compte des **sub-chunks** (`+= batch.length`, `VectorIndexer.ts:1067`) quand le paceur compte des **requêtes** (`acquireEmbeddingSlot:216`) — au batch de 16 par défaut la borne sur `called` était 16× trop généreuse, donc aveugle (revue ai-01, 29/10 ; défaut mesuré, pas théorique).
- **Vivacité jugée séparément** : `[EMB-METRICS]` est émis à chaque intervalle même quand rien ne passe ; une passe de N intervalles doit montrer ~N de ces lignes. Plus de `--max-missing` (défaut 2) intervalles muets = violation, la borne seule ne suffit pas.
- **Recouvrement assumé, pas masqué** : la fenêtre du paceur est **par process**, donc les requêtes d'un callback concurrent sortent du même plafond. `Δrequests` est le plafond du temps mural — la question posée est « retenu seulement par son propre débit ? », jamais « cette tâche était-elle lente ».
- **Fail-closed** : fenêtre non fermée, reset de compteur (redémarrage), ligne sans horodatage nécessaire à la fermeture, **ou métriques sans `requests=` (build antérieur au compteur)** → verdict `INSTRUMENT` (exit 2), jamais `PASS` par silence. Un log sans `pass done`, une entrée malformée (`ValueError`), **une source de taux non numérique, un `--env-file` illisible, un `--env-file` sans la clé faute d'env opérateur, et un paceur désactivé (taux 0 → borne vacante)** sont aussi des exit 2. Nuance sur le dernier point : le refus « sans la clé » ne vaut que **tant que le rang 2 (env opérateur) ne la porte pas** — quand il la porte, c'est lui qui s'applique et l'absence dans le fichier est sans effet (l'outil ne devine pas, il applique le rang supérieur). Un `pass done` **sans horodatage** rend tout le run `INSTRUMENT` (follow-up 1, 31/10) — une passe violante enregistrée sans son horloge ne doit pas disparaître du verdict.
- **`VIOLATION` prime sur `INSTRUMENT`** dans le verdict global (follow-up 2, 31/10) : un log portant les deux sort **1**, pas 2 — masquer une violation mesurée derrière un trou d'instrument est la panne la plus grave. Les lignes sont jugées par **ordre d'horodatage**, pas par ordre du fichier (follow-up 5).
- **Le taux vient du RSM mesuré, avec provenance** (CHANGES ai-01 29/10) : précédence `--ops-per-minute` > **env opérateur (portée hôte)** > `--env-file <rsm>/.env` > défaut 10/min — miroir de la résolution du RSM lui-même (host > `.env`, #2719 ; follow-up 3, 31/10 — la première version avait les rangs 2-3 inversés). Quand l'env et l'env-file portent la clé, la valeur env-file est rendue **`SHADOWED`**, jamais utilisée. `export KEY=VALUE` est accepté dans l'env-file (follow-up 4). La source est toujours rendue (`rate: N/min (source: …)`, champ `rate_provenance` en JSON). La conversion env se faisait à la construction du parser et s'échappait en traceback (**exit 1 lu comme VIOLATION**) — résolue paresseusement, surchargeable par CLI.
- **`rate_limited=` est un témoin, pas une clé** : un delta positif dans une fenêtre jugée dit que le paceur a attendu ; il n'identifie jamais le plafond configuré.
- **La borne n'établit pas la cause exclusive** : les consommateurs non pacés (search/query) partagent l'embedder et leur latence peut gonfler le temps mural sans apparaître dans `Δrequests`.
- **`pass done` est la ligne qui rend la borne calculable** (ms#1572) : sans elle, la durée de passe ne se déduisait qu'après coup des deltas de `called=`.
- **Selftest branché en CI** : `scripts/testing/python/test_g6_pass_bound.py` (job statique, `unittest discover`). La fixture qui reproduit le défaut du 29/10 — 655 s, 400 sub-chunks, 5 requêtes → `VIOLATION` là où la borne sur `called` disait `PASS` — et celle du paceur désactivé (taux 0 → `INSTRUMENT`, jamais `PASS` à allocation infinie) ne peuvent plus pourrir en silence. Les cinq follow-ups de la revue (31/10) ont chacun leur fixture et leur test wrapper : untimed `pass done`, violation non masquée, précédence host > env-file + `SHADOWED`, syntaxe `export`, log hors ordre.

```bash
python scripts/diagnostic/g6-pass-bound.py --log <log RSM>
python scripts/diagnostic/g6-pass-bound.py --log <f> --json
python scripts/diagnostic/g6-pass-bound.py --log <f> --env-file <rsm>/.env
python scripts/diagnostic/g6-pass-bound.py --selftest    # 11 fixtures hors ligne
```

Exit codes : 0 toutes les passes dans la borne et cadence préservée / 1 au moins une violation (dépassement **ou** tick affamé — prime sur `INSTRUMENT`) / 2 erreur d'instrument.

## Store partagé RooSync (GDrive)

### `measure-gdrive-write-freeze.ps1` (#4131, Phase D)

Instrument **lecture seule** du critère de bascule PG : les familles `inventories*`, `messages*` et `.machine-registry*` du shared state G: sont-elles **gelées (aucune écriture) depuis 24 h** ? Tant qu'un siège écrit, GDrive reste dans le chemin critique et la rétrogradation en export n'est pas acquise. Le script ne décide de rien d'autre : il mesure des mtimes et rend un verdict, sans interprétation.

- **Les jumeaux comptent comme des instances à part entière** (`inventories (2)`, `messages (2)`, `.machine-registry (1).json`). Un siège lié à un jumeau écrit exactement pareil : un instrument qui ne regarderait que le nom canonique annoncerait `FROZEN` pendant qu'un jumeau est chaud. **Le suffixe est l'ordre de matérialisation LOCAL de DriveFS** — le même dossier s'appelle `(2)` sur un siège et `(1)` sur un autre (mesuré 30/10) : la mesure s'agrège **par siège, puis se somme**, jamais par un nom supposé flotte.
- **La décision lit l'âge BRUT**, l'arrondi n'est que l'affichage : 23 h 58 s'affiche `24,0` et reste ACTIVE sous un seuil de 24 h.
- **Exit codes** : 0 `FROZEN` (critère atteint) / 1 `ACTIVE` (critère non atteint, chaque instance chaude est nommée avec son âge) / 2 **erreur d'instrument** — chemin partagé illisible, famille sans aucune instance (sinon un nom disparu passerait pour un gel), **ou une énumération en échec**.
- **Fail-closed sur l'énumération** : une entrée de famille lisible au niveau parent mais illisible dedans (jonction cassée, répertoire inaccessible) rend `[INSTRUMENT] enumeration inside <chemin> errored: …` + exit 2. Sans cette garde, la récursion rend 0 fichier et le mtime de l'entrée — sa date de création, donc « maintenant » — fabrique un `ACTIVE` sur une écriture qui n'a jamais eu lieu (mutation vérifiée : suite (e) rouge sur le script privé de la garde).
- **Suite Pester** : `scripts/diagnostic/measure-gdrive-write-freeze.Tests.ps1` (5 cas, exécutés par `marshall-scripts-pester` sur `windows-latest` — l'enfant est `powershell.exe` 5.1, absent des runners ubuntu) : (a) gel → `MET` en listant les familles vues, (b) jumeau chaud → `NOT-MET` en le nommant, (c) famille absente → exit 2 en la nommant, (d) âge brut vs arrondi, (e) énumération en échec → exit 2.

```powershell
# Verdict Phase D sur le shared state par défaut (G:\Mon Drive\...\RooSync\.shared-state)
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\measure-gdrive-write-freeze.ps1

# Store et seuil explicites (l'instrument est aussi pilotable en fixture)
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\measure-gdrive-write-freeze.ps1 -SharedPath <chemin> -FreezeHours 24
```

Lecture seule de bout en bout : aucun fichier écrit, aucune purge, aucun resync forcé — le calendrier de bascule appartient à #4131, pas à l'instrument. Verdicts datés publiés sur #4131 (30/10 19:52Z et 31/10 07:53Z sur le siège po-2025 : `NOT-MET 6/6`).

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
