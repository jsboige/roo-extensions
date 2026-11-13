# Leçons de terrain — PowerShell, shells, tâches planifiées et Windows

Ces leçons viennent d'incidents mesurés sur les postes Windows de la flotte : un script qui marche
dans un shell et échoue dans l'autre, une tâche planifiée qui annonce un succès sans livrable, un
instrument qui rend un chiffre crédible mais faux. Elles se lisent avant d'écrire un script destiné
à plusieurs machines, avant de faire confiance à un code de retour, et avant d'auditer une panne
d'infrastructure sous Windows.

**Provenance :** fiches de la mémoire locale du coordinateur ai-01, sorties vers le dépôt le
2026-11-13. Chaque leçon porte en commentaire le nom de sa fiche d'origine, et a été relue contre
cette fiche par un agent distinct de son rédacteur. Les numéros de ligne cités sous « Déjà dans le
dépôt » valent à cette date : s'ils ont bougé, chercher le passage par son sujet.

**Les cinq volets :** [mesurer et prouver](field-lessons-measurement.md) ·
[relire, fermer, tester](field-lessons-review-tests.md) ·
[GitHub, gh et la CI](field-lessons-github-ci.md) ·
[dashboards, messagerie, Drive et moniteurs](field-lessons-store-dashboard.md) ·
[PowerShell, shells et Windows](field-lessons-shell-windows.md).

**Vocabulaire :** `#1234` désigne une issue ou une PR du dépôt roo-extensions, `ms#1234` de son
sous-module (le dépôt `jsboige-mcp-servers`, monté sous `mcps/internal`, qui porte le serveur MCP
roo-state-manager, « RSM »). Une *lane* est une session d'agent identifiée par `machine:workspace` ; un
*siège*, une machine de la flotte ; un *worker*, un agent lancé par une tâche planifiée, sans humain. Un
*claim* est le commentaire qu'un agent pose sur une issue pour dire qu'il y travaille. « PG » est la base
PostgreSQL de la flotte ; le *dashboard* est le tableau de messages partagé que chaque agent lit et écrit
par un outil MCP.

## PowerShell 5.1, bash et les couches d'échappement

### Un script destiné à la flotte se valide sous Windows PowerShell 5.1
<!-- src: feedback_validate_fleet_scripts_under_powershell_51 -->
- **Quand :** avant de livrer un `.ps1` que d'autres machines exécuteront, ou de conclure qu'une
  commande validée « chez soi » l'est aussi ailleurs.
- **Règle :** exécuter l'artefact avec `powershell -ExecutionPolicy Bypass -File <script>` et
  vérifier que la version affichée est `5.1.x` ; plusieurs succès dans le même shell ne sont
  qu'une mesure répétée, et le shell parent fait partie de la preuve.
- **Cas mesuré :** 07/09/2026, la sonde `[CLAIMED]` du processus qui nettoie les verrous échouait
  22 fois sur 22 après six validations réussies sous `pwsh` 7 ; le 15/09,
  `return ,@($raw | ConvertFrom-Json)` rendait sous 5.1 un tableau de `Count=1` au lieu de deux
  objets (Pester vert 32/32 sous `pwsh`, rouge 31/32 sous 5.1).
- **Déjà dans le dépôt :** `.claude/rules/shell-fallback.md` — dit d'invoquer les scripts par
  `powershell` 5.1 et rappelle que `pwsh` manque à certaines machines ; ne porte pas la porte de
  validation avant livraison.
- **Essayé et rejeté :** valider sous `pwsh` 7 — absent de certaines machines et de sémantique
  différente.

### Sous PowerShell 5.1, un texte passé au `stdin` d'un programme natif commence par un BOM
<!-- src: reference_ps51_native_pipe_bom -->
- **Quand :** un script 5.1 alimente par un tube un serveur MCP, `python`, `cmd` ou tout programme
  qui lit du JSON ou des octets exacts.
- **Règle :** suspecter le BOM d'abord ; écrire la charge utile dans un fichier avec
  `[IO.File]::WriteAllText($f, $s, (New-Object Text.UTF8Encoding $false))` puis rediriger ce
  fichier. Ni `$OutputEncoding` ni `[Console]::OutputEncoding` ne retirent le BOM du tube, et un
  rejeu sous `pwsh` 7 passe sans BOM, donc masque le défaut.
- **Cas mesuré :** 01/11/2026 sur ai-01 (5.1.26100, page de code système 65001), `$str | & cmd /c ...`
  écrit `EF BB BF` avant la chaîne et le serveur rejette `json_invalid` ; la sonde
  `Test-SkAgentAvailable` a lu un service sain comme arrêté — 14 exécutions en échec, 0 réussie,
  corrigé par la PR #4487.
- **Déjà dans le dépôt :** `docs/harness/global-rules-detail.md:566` — donne l'écriture de fichier
  sans BOM ; ne dit rien du BOM qu'un tube 5.1 ajoute au `stdin` d'un programme natif.

### `powershell.exe -File` ne passe pas un paramètre de type tableau
<!-- src: reference_powershell_file_cannot_pass_an_array_parameter -->
- **Quand :** une tâche planifiée ou un appel `-File` passe plusieurs valeurs à un paramètre
  `[string[]]`.
- **Règle :** ne pas faire passer un tableau par `-File` ; corriger le défaut du paramètre dans le
  script, ou appeler par `-Command "& sonde.ps1 -Roots 'D:\','C:\dev'"`. Depuis bash,
  `'D:\','C:\dev'` est un seul mot, car les chaînes citées adjacentes sont collées — même panne,
  autre couche.
- **Cas mesuré :** 21/09/2026 sur ai-01, `-File sonde.ps1 -Roots D:\,C:\dev` reçoit une seule
  valeur `<D:\,C:\dev>` et `-File sonde.ps1 -Roots D:\ C:\dev` jette la seconde sans un mot ; le
  même audit a rendu 0 ferme avec exit 0 par `-File`, contre 106 worktrees et exit 1 en processus.
- **Essayé et rejeté :** ajouter un slash final ou des guillemets à la valeur ne sauve rien ;
  `-Command` fonctionne, avec deux valeurs correctes.

### Sous PowerShell 5.1, c'est la redirection de `stderr` qui arme l'erreur fatale
<!-- src: reference_stderr_redirection_arms_the_native_command_error -->
- **Quand :** un script 5.1 tourne avec `$ErrorActionPreference = 'Stop'` et appelle un exécutable
  natif avec une redirection de `stderr`.
- **Règle :** baisser `$ErrorActionPreference` autour de l'appel et juger sur `$LASTEXITCODE` ;
  l'appel nu (`& exe`) ne lève jamais, alors que `& exe 2>&1 | Out-Null` et `& exe 2>$null` lèvent.
  `2>$null` n'est donc pas une protection mais le déclencheur.
- **Cas mesuré :** 18/09/2026 sur ai-01 (5.1.26100.9444), un message purement informatif tuait le
  script de sauvegarde à chaque exécution, et la sonde `docker ps` rendait la branche « Docker pas
  accessible » inatteignable — la sonde censée détecter l'absence de Docker mourait de cette
  absence.
- **Piège de validation :** un `-DryRun` qui court-circuite le bloc réparé ne valide rien.
- **Déjà dans le dépôt :** `.claude/configs/scripts/Deploy-GlobalConfig.ps1:223-229` — le commentaire
  énonce qu'une `stderr` native est promue en `NativeCommandError` terminant sous
  `$ErrorActionPreference = 'Stop'` « even when redirected with `2>$null` », et le code applique le
  remède. Il n'établit pas que l'appel nu ne lève jamais, ni que la redirection est le déclencheur,
  ni le piège du `-DryRun`.

### Passer par `cmd /c` transforme les entrées d'`argv` en une seule ligne de commande
<!-- src: reference_cmd_layer_fix_turns_argv_entries_into_one_command_line -->
- **Quand :** un correctif déplace une redirection vers `& cmd /c "..."` pour éviter l'erreur
  `NativeCommandError`.
- **Règle :** doubler les guillemets autour de chaque jeton interpolé —
  `cmd /c "python ""$helper"" ""$Database"" 2>&1"` — dès que la valeur peut contenir un espace :
  un chemin de fichier, `$env:TEMP`, un paramètre fourni par l'appelant.
- **Cas mesuré :** 19/09/2026 sur ai-01 (`powershell 5.1.26100.9444`), sonde
  `…\sp ace probe\my db.vscdb` : la forme PowerShell reçoit le chemin intact, la forme `cmd` non
  quotée coupe au premier espace, la forme `cmd` quotée le reçoit intact. Trois relecteurs
  indépendants avaient classé la régression « nit mineur » sur la PR #3740.
- **Non concerné :** les refs git et les numéros d'issue — git refuse les espaces dans les noms de
  ref, donc l'interpolation nue y est sûre par construction.

### Un backtick PowerShell dans une commande lancée depuis bash est une substitution de commande
<!-- src: reference_bash_eats_powershell_backticks_as_substitution -->
- **Quand :** on écrit du PowerShell en ligne dans une commande bash, surtout entre guillemets
  doubles.
- **Règle :** écrire le PowerShell dans un fichier `.ps1` (heredoc à délimiteur quoté) et l'appeler
  par `-File` avec des paramètres ; à défaut, séparer par un caractère qui n'est pas un backtick.
  Et un `\\` dans un heredoc quoté est réduit avant l'interpréteur.
- **Cas mesuré :** 08/09/2026, un A/B du service de mémoire a rendu `A_defaut,2071` au lieu de
  `A_defaut,2009,2089` : bash avait exécuté le backtick (« command not found »), substitué vide,
  et collé le tag à une seule métrique. Code de sortie 0, sortie plausible.
- **Portée :** c'est le même mécanisme que la règle `--body-file` de `pr-mandatory.md` ; elle
  n'avait été écrite que pour `gh`, alors qu'il frappe toute commande à guillemets doubles passée
  depuis bash.

### Un jeton contenant une barre oblique inverse, un guillemet ou un dollar se construit par programme
<!-- src: reference_escaping_layer_rewrote_my_probe_into_a_plausible_number -->
- **Quand :** une sonde cherche un littéral qui contient `\`, `"` ou `$`, ou rend un zéro.
- **Règle :** construire le jeton avec `chr(92)` (`BS = chr(92)` puis `tok = BS + "vert"`) et
  exiger un contrôle positif avant de lire un zéro comme un résultat ; le quoting du shell ne
  protège pas, car le `\\` est réduit avant bash.
- **Cas mesuré :** 13/09/2026, une sonde sur le payload de #3621 a rendu `\vert : 0` alors que le
  jeton était présent : `"\vert"` était arrivé comme `\x0b` suivi de `ert`. Remesurée sans littéral
  de barre oblique, elle rend 3.
- **Piège de diagnostic :** l'avertissement Python (`SyntaxWarning`) désignait le jeton voisin
  inoffensif, pas la ligne empoisonnée.
- **Essayé et rejeté :** construire une expression régulière avec `BS` —
  `BS + r"(?:mid|vert)[A-Za-z]"` produit `\(?:…` et lève `unbalanced parenthesis`. Une boucle
  `str.find` avec test `.isalpha()` sur le caractère suivant ne peut pas être mal formée.

### Sous Git Bash, `git show <rev>:<chemin>` est mutilé par la conversion de chemins
<!-- src: reference_msys_path_conversion_mangles_git_rev_colon_path -->
- **Quand :** on lit un fichier du dépôt avec `git show origin/main:chemin` depuis Git Bash, puis on
  compte le résultat.
- **Règle :** poser `MSYS_NO_PATHCONV=1` au plus près du `git` concerné, et garder un garde qui
  prouve que la lecture a mordu avant de compter (`git show … || { echo "…"; exit 1; }`, puis test
  de sortie non vide).
- **Cas mesuré :** 06/09/2026,
  `git show origin/main:.claude/commands/coordinate.md | grep -c '23 \*/8 \* \* \*'` a affiché
  `0` ; le `0` venait de `grep` comptant sur une entrée vide, car `git show` avait échoué sur
  `origin\main;...`. L'échec de l'instrument porte la même signature que le succès du geste.
- **Le correctif est un piège :** un `export MSYS2_ARG_CONV_EXCL='*'` désarme la conversion pour
  tous les exécutables Windows suivants ; un jeton lu par `jq` est ressorti vide et l'appel a rendu
  401 — authentique et trompeur. Asserter la longueur attendue du secret avant tout appel.

### Un pipeline PowerShell rend le code de sortie du dernier segment, pas celui du test
<!-- src: reference_pipelined_exit_code_reports_the_last_command_not_the_child -->
- **Quand :** une porte de commit ou un rapport lit l'exit d'un pipeline
  `powershell -Command "... | Select-Object ..."`.
- **Règle :** ne jamais gaté sur l'exit d'un pipeline dont le dernier segment n'est pas le test ;
  capturer le résultat et sortir explicitement —
  `$r = Invoke-Pester ... -PassThru; if ($r.FailedCount -gt 0) { exit 1 }` — ou lire le compte
  imprimé en plus de l'exit.
- **Cas mesuré :** 26/10/2026 (#4336), une commande `powershell -Command` qui terminait un run
  `Invoke-Pester` par `| Select-Object PassedCount,FailedCount` a rendu exit 0 avec 6 tests en
  échec sur 1153 passés ; la ligne `FailedCount 6` était bien imprimée.
- **Famille :** même classe qu'une tâche planifiée dont le code de retour masque la mort du
  processus fils — ici le compte était rouge, seul l'exit mentait.

### `pkill -f` tue le shell qui le porte quand le motif figure dans sa propre ligne de commande
<!-- src: reference_pkill_f_matches_its_own_shell -->
- **Quand :** on chaîne un `pkill -f <motif>` et un contrôle (echo, compte) dans le même `sh -c`.
- **Règle :** séparer en deux invocations, et vérifier avec un motif qui ne se matche pas lui-même :
  `ps -eo args | grep "[R]unner\."`.
- **Cas mesuré :** le `echo` final d'un
  `wsl -u root -e sh -c 'pkill -9 -f "Runner\." ; echo …'` n'a jamais affiché — le shell s'était
  tué au milieu de sa propre chaîne, sans erreur. La commande « réussit », seule la sortie finale
  manque.
- **Corollaire :** arrêter une unité systemd ne tue pas ce qui s'en est échappé — un arrêt
  d'exécuteur CI a laissé 8 processus vivants qui se renouvelaient. Compter les processus après,
  jamais avant.

### Un script PowerShell passé par `stdin` à `ssh` devient un no-op muet en arrière-plan
<!-- src: reference_backgrounded_ssh_stdin_script_is_a_silent_noop -->
- **Quand :** on exécute un script distant par `ssh … "powershell -Command -" < script.ps1` et
  l'appel peut être détaché.
- **Règle :** déposer le script par `scp` puis l'exécuter par `-File` sur la cible ; `-File` lit le
  disque distant et ne dépend pas de l'état de `stdin`. Ne jamais rapporter un déploiement distant
  sur le seul code de retour : relire l'effet sur la cible.
- **Cas mesuré :** 21/09/2026 (#3188), le même appel a réussi au premier plan (3 installeurs
  installés et vérifiés dans IIS) et rendu, en arrière-plan, exit 0 avec zéro ligne de sortie et
  rien fait ; le répertoire de la cible ne contenait que les fichiers de l'étape précédente.
- **Essayé et rejeté :** `-EncodedCommand` — la ligne d'environ 9,6 Ko de base64 a été refusée
  (`The command line is too long.`).

### `write_text` tronque le fichier avant d'encoder, donc une erreur d'encodage le laisse vide
<!-- src: reference_write_text_truncates_before_it_encodes -->
- **Quand :** un script Python réécrit un fichier qu'on ne peut pas reconstituer — mémoire, index,
  configuration.
- **Règle :** écrire dans un fichier temporaire puis `os.replace`, et vérifier la taille après
  écriture ; ne jamais utiliser un échappement `\uXXXX` manuel pour un caractère hors BMP.
- **Cas mesuré :** 22/09/2026, `p.write_text(t, encoding="utf-8", newline="")` a levé
  `UnicodeEncodeError` sur des surrogates isolés (`"\ud83d\udd34"` écrit pour un emoji) et laissé
  `MEMORY.md` à 0 octet ; le run suivant a échoué sur une ancre introuvable, indiscernable d'une
  ancre mal orthographiée.
- **Ce qui a sauvé le fichier :** son contenu figurait dans un rappel de contexte du tour — un
  filet conjoncturel qui n'existe pas pour un fichier de projet.

### Le code HTTP se lit dans l'exception d'`Invoke-RestMethod`, si l'on teste d'abord l'absence de réponse
<!-- src: reference_powershell_http_status_accessor -->
- **Quand :** un script de surveillance appelle un service HTTP et doit distinguer une erreur
  d'authentification d'une panne.
- **Règle :** traiter le timeout d'abord, puis tester `$null -ne $_.Exception.Response` avant
  `.Response.StatusCode` ; sous 5.1 l'exception est une `WebException` (`Status` = `ProtocolError` s'il y
  a une réponse, `Timeout` ou `ConnectionClosed` sinon), sous 7 une `HttpResponseException` (le timeout y
  est une `TaskCanceledException`), où la propriété `.Status` n'existe pas.
- **Cas mesuré :** 26/10/2026 sur ai-01 (5.1.26100.9711 et pwsh 7.6.6), un 401 et un 503 portaient
  `.Response` non nul et leur code, tandis qu'un timeout ou une connexion morte rendaient
  `.Response = $null` ; avec `-TimeoutSec 30`, le même 401 a rendu `Status=Timeout` parce que le
  serveur avait mis environ 37 s à répondre.
- **À retenir :** « pas de réponse » (`RESP_NULL`) ne signifie pas « 4xx/5xx ». Un 401 veut dire
  « le service répond, la clé est refusée » : le remède est de rejouer la clé, pas de redémarrer
  un backend sain.

### Un script généré qui recopie ses commandes dans un `echo` saute une ligne sur deux
<!-- src: reference_generated_script_echo_of_command_swallows_next_line -->
- **Quand :** on génère un script bash qui affiche chaque commande avant de l'exécuter, surtout
  pour des gestes GitHub en masse.
- **Règle :** ne jamais faire écho au texte brut d'une commande ; imprimer une étiquette fixe
  (`printf '%s#%s\n' "$repo" "$n"`). Écrire les gestes en « vérifier puis agir » idempotent, et
  rejouer le script comme vérificateur : il ne doit rien faire.
- **Cas mesuré :** 19/10/2026 sur ai-01, sur 19 tickets, un nombre impair de guillemets dans
  l'`echo` ouvrait la chaîne et avalait la ligne de commande suivante ; environ un geste sur deux
  n'a pas tourné, et le script a quand même affiché `ALL-DONE` avec un code de retour 0. La
  relecture par ticket, avec deux instruments, l'a rattrapé.
- **Autre couche :** `subprocess.run(["bash", …])` depuis Python sur ai-01 lance le bash de WSL, où
  `gh` n'est pas authentifié ; écrire un fichier `.sh` et le lancer avec l'outil Bash (Git Bash).

## Tâches planifiées : un code de retour n'est pas un résultat

### Pour une tâche à lanceur VBS, `LastTaskResult=0` ne prouve pas que le travail a été fait
<!-- src: reference_scheduled_task_exit_zero_masks_child_death -->
- **Quand :** une tâche planifiée passe par un lanceur caché (VBS) et le scheduler annonce un
  succès.
- **Règle :** ne faire confiance qu'à l'artefact attendu — fichier frais, taille, date. Et avant de
  concevoir un script qui « désarme » d'autres tâches, vérifier son `RunLevel` : sous
  `RunLevel Limited`, aucun désarmement n'est possible.
- **Cas mesuré :** 01/10/2026 sur ai-01 (#2450), la chaîne `wscript //B` puis
  `sh.Run(powershell …, 0, True)` puis `WScript.Quit rc` a rendu 0 alors que l'export était mort en
  cours de route : transcript gelé à 2421 octets, staging vide, rien sur la destination, environ
  163 Go partiels écrits puis supprimés. Les `Disable-ScheduledTask` lancés par le script échouaient
  tous en « Accès refusé ».
- **Acteur oublié :** une tâche de vérification à cadence de 2 minutes a tenté de redémarrer la
  distribution pendant l'export — à inventorier avant toute fenêtre de maintenance.
- **Déjà dans le dépôt :** `docs/harness/reference/lessons-archive.md:29` — couvre le lanceur VBS
  sans `WorkingDirectory` et la mort silencieuse par exit 1 avec `stderr` détruit ; n'établit pas
  que `LastTaskResult=0` ment sur le sort du processus fils.

### Un code de retour de tâche planifiée ne dit rien de l'exploitabilité d'une sauvegarde
<!-- src: reference_task_return_code_is_not_backup_usability -->
- **Quand :** on audite une sauvegarde pilotée par une tâche planifiée, ou on déclare une
  sauvegarde saine.
- **Règle :** lire la cadence avec `Get-ScheduledTaskInfo`, puis la destination réelle avec
  `Get-ChildItem` : existence, date et ordre de grandeur du fichier. Un dernier fichier de plus
  d'un mois signe une panne.
- **Cas mesuré :** 18/09/2026 sur ai-01, la tâche `Backup-Ubuntu-WSL` tirait à l'heure
  (`NumberOfMissedRuns=0`) et rendait `LastTaskResult=1` depuis juin : 3 mois sans sauvegarde
  exploitable, trois exécutions automatiques (01/07, 01/08, 01/09) échouées en silence. La cause
  était un appel natif (`Docker Desktop.exe --quit`) qui lève sous
  `$ErrorActionPreference='Stop'`.
- **Ce que la fiche souligne :** le commentaire du script annonçait déjà ce diagnostic ; il s'est
  réalisé sans que personne ne le lise. Un échec qui ne réveille personne coûte exactement le
  temps qu'il met à être découvert.

### Après un redémarrage, l'infrastructure revient seule ; les agents attendent un état des lieux
<!-- src: feedback_post_reboot_agent_resume_needs_a_state_check -->
- **Quand :** on conçoit ou on modifie ce qui démarre au boot d'un poste — Docker, VS Code, agents.
- **Règle :** ne jamais proposer ni poser un démarrage automatique de VS Code ou d'un agent à
  l'ouverture de session avant que l'utilisateur ait demandé la conception de l'état des lieux
  post-redémarrage. Docker, lui, se juge sur le résultat « debout sans personne au clavier », jamais
  sur un verdict « propre ».
- **Cas mesuré :** décision utilisateur du 25/09/2026 : Docker doit redémarrer seul sans attendre la
  connexion de l'utilisateur, mais Zoo (l'extension d'agent de VS Code, qui a succédé à Roo) et Claude
  Code ne doivent pas reprendre spontanément tant que les contours d'un état des lieux ne sont pas
  maîtrisés. #1261 porte ce cadrage, le retour au boot de Docker relève de #1171.
- **Vocabulaire :** dire **Zoo**, pas Roo — l'utilisateur veut Roo disparu partout.

## Cas d'infrastructure à garder sous la main

### La consommation réseau de Windows ne compte pas le trafic redirigé vers WSL
<!-- src: reference_srum_blind_to_wsl_nat_traffic -->
- **Quand :** on cherche à borner la consommation d'une machine, ou à innocenter un poste sur la
  base d'un total Windows.
- **Règle :** utiliser les compteurs bruts de la carte réseau (`Get-NetAdapterStatistics` sur la carte qui
  porte la connexion, plus les compteurs `vEthernet (WSL*)` pour la part de la VM) et comparer des deltas
  sur une fenêtre ; SRUM (l'historique Windows de consommation par application) ne sert qu'à classer des
  processus Windows, jamais à faire un total.
- **Cas mesuré :** 26/10/2026 sur ai-01, depuis le boot : 1 267,6 Go reçus par la carte contre environ 380
  Go attribués par SRUM ; l'écart de 887 Go correspond au trafic transféré vers WSL à 0,2 % près. Cela
  invalide la conclusion d'un poste qui avait lu 2,36 Gio sur le partage de connexion et en avait déduit
  que les 20 Go n'étaient pas passés par ce PC.
- **Piège voisin :** l'API de SRUM ne fonctionne que sous Windows PowerShell 5.1, et `-StartUtc …Z`
  passé en argument de `-File` y est décalé en heure locale ; utiliser
  `([datetimeoffset]'…Z').UtcDateTime`.
- **Déjà dans le dépôt :** `scripts/monitoring/metered-link-watch.ps1:6-14` — l'en-tête porte la
  mesure du 26/10/2026 (887 Go reçus par la carte et absents de SRUM, à 0,2 % près) et la règle des
  compteurs bruts de la carte. Il ne porte ni les compteurs `vEthernet (WSL*)`, ni la réfutation du
  « 2,36 Gio », ni le piège `-StartUtc …Z`.

### Sur un OS client, IIS plafonne à dix requêtes simultanées exécutées par worker
<!-- src: reference_iis_windows11_pro_10conn_cap -->
- **Quand :** un site IIS sur Windows 11 (ou un autre OS client) devient lent alors que le backend
  répond vite en direct.
- **Règle :** mesurer le nombre de sockets que le worker ouvre vers le backend ; ne pas retoucher
  les limites du reverse proxy, qui étaient larges et sans effet — file d'attente 1000,
  `maxConnections` à 4 294 967 295, aucune limite de connexions côté ARR (le module de reverse
  proxy d'IIS).
- **Cas mesuré :** 26/10/2026, site IIS du service d'embeddings sur le siège po-2023 : 41 à 51 s
  par le site contre 15 à 33 ms en direct sur le backend du réseau local, avec exactement 10
  sockets ouverts par le seul `w3wp` (le processus worker d'IIS). Un essai à blanc sur un site et
  un backend jetables (ports 18080 et 18099) a montré 10 sockets avec un worker et 20 avec
  `maxProcesses=2`.
- **Essayé et rejeté :** `maxProcesses=2` recycle le pool et coupe les requêtes d'indexation en
  vol ; le levier retenu est de borner l'émetteur de requêtes à 10 concurrences (ms#1526).

### `Debugger.pause` nomme la ligne JavaScript d'un processus figé, même dans une expression régulière
<!-- src: reference_inspector_pause_finds_a_regex_freeze -->
- **Quand :** un processus Node — ici un hôte de serveur MCP — est à 100 % et toutes les requêtes
  expirent, tandis que le profil CPU ne montre que `(program)`.
- **Règle :** activer l'inspecteur sur le processus vivant
  (`node -e "process._debugProcess(PID)"`), puis `Debugger.enable` et `Debugger.pause` pour lire la
  pile et les variables ; `Runtime.terminateExecution` sur le thread principal tue le processus, à
  n'utiliser que si perdre l'hôte est acceptable.
- **Cas mesuré :** 10/11/2026 sur ai-01 (#4636), deux pauses sur deux hôtes successifs ont donné
  la même ligne, `hierarchy-reconstruction-engine.js:677:95`, avec `contentAny.length = 1 136 815` ;
  un banc sur tailles doublées a montré un facteur ×45 par doublement, donc exponentiel.
- **Conséquence pour les tests :** une expression régulière synchrone ne peut pas être arrêtée par
  le timeout de vitest ; dimensionner le test de régression pour que l'ancienne version échoue sur
  l'assertion en secondes.

### Sous Windows, Node (>= 20.12) refuse de lancer un `.cmd` par `execFile` sans `shell`
<!-- src: reference_execfile_cmd_without_shell_einval -->
- **Quand :** une review remplace `exec('npm run build', {cwd})` par
  `execFile('npm.cmd', ['run','build'])` au nom du « argv sans shell ».
- **Règle :** lister chaque programme lancé ; tout `.cmd` ou `.bat` (`npm`, `npx`, `yarn`, `pnpm`,
  `code`) se teste par un `node -e` réel sur un siège Windows avant approbation. Pour lancer Node,
  `process.execPath` avec des arguments évite le problème.
- **Cas mesuré :** 03/11/2026 sur ai-01 (Node v24.14.1), `execFile('npm.cmd', ['--version'])` lève
  `spawn EINVAL` au spawn, `execFile('npm', ['--version'])` rend `ENOENT` car la bibliothèque
  n'essaie que `.com` et `.exe`, et `{shell:true}` fonctionne mais DEP0190. ms#1634 (#4149) aurait
  cassé la reconstruction sur tout poste Windows ; deux reviews avaient conclu bon parce que les
  tests moquent `child_process` et que la CI tourne sous Ubuntu.
- **Pourquoi la conversion n'apporte rien :** une chaîne de commande constante n'est pas un site
  d'injection.

### Une variable d'environnement Windows de portée User bat silencieusement le fichier `.env`
<!-- src: reference_user_env_var_shadows_dotenv -->
- **Quand :** un processus utilise une URL ou une valeur différente de celle écrite dans le `.env`
  du projet.
- **Règle :** lire les quatre couches dans cet ordre : variable User ou Machine, section
  `mcpServers.<serveur>.env` de la configuration MCP globale du client,
  `projects.<chemin>.mcpServers.<serveur>.env`, puis le `.env` — qui perd contre les trois autres,
  car `dotenv.config()` n'a pas l'option `override`.
- **Cas mesuré :** 28/10/2026 sur ai-01, une variable User pointait vers une URL servie par un
  poste éteint (délai de 5 s) alors que les deux `.env` donnaient l'URL du site d'embeddings : le
  processus résident du serveur MCP recevait la bonne valeur par la configuration globale, mais
  l'extension Zoo, les shells de scripts et un autre projet du poste recevaient l'URL morte. Un
  agent de fond a conclu à tort que le `.env` d'ai-01 était faux.
- **Réparation :** remettre la variable User à la bonne valeur, après avoir sauvegardé l'ancienne
  dans un fichier ignoré par git.

### Après une suppression, `git restore` ne ramène que les fichiers suivis
<!-- src: reference_git_restore_after_deletion_misses_ignored_config -->
- **Quand :** un nettoyage destructif (jonction suivie, suppression) a touché un checkout, et on
  déclare le checkout réparé après un `git restore`.
- **Règle :** vérifier aussi la configuration locale ignorée par git, puis démarrer une instance
  neuve ou parser ce fichier avant de déclarer la réparation faite ; comparer des empreintes,
  jamais le contenu.
- **Cas mesuré :** 26/10/2026 sur ai-01, la jonction d'auto-dépendance
  `node_modules/roo-state-manager` a fait supprimer des fichiers du paquet ; les 144 fichiers
  suivis sont revenus par git, mais le fichier de configuration local ignoré n'est pas revenu. Le
  processus résident l'avait déjà chargé, donc personne ne l'a vu ; ce sont les nouvelles
  instances qui ont démarré avec la clé de condensation manquante, quelques heures plus tard et
  depuis un autre espace de travail de la flotte.
- **Ce que la fiche ajoute :** une remise en place depuis une copie canonique hors dépôt,
  sauvegardée chaque jour, a permis de retrouver 42 clés parsées — sans jamais afficher le contenu.

### Une purge confirmée ne se fonde jamais sur la seule parole d'un outil qui dit « orphelin »
<!-- src: reference_cleanup_orphans_uuid_lookup -->
- **Quand :** `roosync_indexing cleanup_orphans`, ou une autre purge, propose de supprimer des
  objets et que le dry-run les dit orphelins.
- **Règle :** quand deux instruments divergent sur la vivacité — le dry-run dit orphelin, la
  recherche et le disque disent vivant — le destructif ne gagne jamais : trancher par le disque
  avant de purger. Exiger un hôte qui sert un build incluant `ms#1313`, qui corrige le lookup par
  suffixe d'uuid.
- **Cas mesuré :** 02/10/2026 sur ai-01, le dry-run annonçait 561 orphelins sur 6 548 identifiants,
  dont un identifiant vivant sur disque. La cause : le contrôle cherchait `<taskId>.jsonl` alors
  que les identifiants par session portent le préfixe `claude-{projet}--` et que le fichier est
  nommé par l'uuid nu — la clé ne pouvait jamais correspondre, soit 100 % des identifiants par
  session.
- **Ce qui aurait dû alerter :** la garde d'arrêt à 50 % (#694) ne s'arme pas à 8,6 %
  d'orphelins ; un run confirmé aurait supprimé du rappel vivant. Et le conseil d'un autre outil
  prescrivait cette purge pour un problème qu'elle ne couvre pas : elle n'opère que sur les
  conversations, jamais sur les collections `ws-*` (les index de code par workspace).
