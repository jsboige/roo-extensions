# Leçons de terrain — GitHub, gh et la CI

Ces leçons portent sur les outils GitHub que la flotte utilise tous les jours : le CLI `gh`, l'API REST et
GraphQL, les files de GitHub Actions, les références citées dans une issue ou une PR, et ce qu'on écrit
dans le corps et les labels d'une issue. Elles se lisent
avant d'agir sur une PR, une issue ou un check, et surtout avant de conclure qu'un résultat est vide,
complet ou en échec.

**Provenance :** fiches de la mémoire locale du coordinateur ai-01, sorties vers le dépôt le
2026-11-13. Chaque leçon porte en commentaire le nom de sa fiche d'origine, et a été relue contre
cette fiche par un agent distinct de son rédacteur. Les numéros de ligne cités sous « Déjà dans le
dépôt » valent à cette date : s'ils ont bougé, chercher le passage par son sujet. Les leçons
marquées `src: session 13/11/2026` ne viennent pas d'une fiche : elles viennent de la session du
coordinateur de ce jour-là, et ont été vérifiées le jour même contre l'arbre et l'API GitHub.

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

## GitHub, gh et les files de CI

### Le quota de mutation d'un projet GitHub est un compteur distinct du quota GraphQL général
<!-- src: reference_project_v2_mutation_quota -->
- **Quand :** une écriture dans un projet GitHub (`updateProjectV2ItemFieldValue`) rend `RATE_LIMIT`
  alors que `rateLimit.remaining` affiche encore large.
- **Règle :** le solde général ne juge pas la mutation ; un `RATE_LIMIT` sur un projet se lit comme le
  compteur du projet et s'attend, il ne se rejoue pas en boucle. Un exit 0 sur l'écriture ne prouve rien :
  seul un readback par requête ciblée montre les champs réellement posés.
- **Cas mesuré :** 26/10/2026, ai-01 : quota général à 1 828/5 000 et mutation refusée,
  `gh project item-list` échouant en `RATE_LIMIT` là où la requête ciblée passe. Les champs Agent et
  Machine sont restés vides malgré des commandes sorties en 0 (#4376).
- **Déjà dans le dépôt :** `docs/harness/reference/github-cli.md:207` — le texte y traite le quota
  GraphQL face au REST `GET /rate_limit` ; cette leçon y ajoute le compteur de mutation propre au projet.

### Une exécution « en file » peut être bloquée par la concurrence, et la file d'un pool est FIFO
<!-- src: reference_gh_actions_queue_waiting_state_and_fifo -->
- **Quand :** on veut annuler des exécutions en file pour faire démarrer une PR, ou promettre à une lane
  qu'on lui libère un slot de runner.
- **Règle :** un `409 Cannot cancel a workflow run that has not been queued yet` signifie que l'exécution
  est en attente d'un bloc `concurrency`, pas d'un runner ; le levier est `cancel-in-progress: true` pour
  la tête bloquée ; l'annulation d'API ne mord que sur la rafale récente. Libérer un slot sert le plus
  ancien du pool, jamais celui pour qui on a fait le geste.
- **Cas mesuré :** 27/10/2026, CoursIA : 16 exécutions sur 17 antérieures au 20/10 répondent 409 au
  cancel. Deux slots libérés sont repris immédiatement par d'autres exécutions, et les checks de la PR
  visée, en file depuis 23:29Z, n'ont pas démarré.

### Un push posé pendant un incident GitHub peut ne déclencher aucun workflow
<!-- src: reference_push_during_github_incident_loses_pull_request_event -->
- **Quand :** un observateur de checks expire, ou `gh pr checks` reste vide.
- **Règle :** interroger d'abord `actions/runs?head_sha=<sha>` : `total_count: 0` signifie que
  l'événement a été perdu, pas que la CI est lente, et attendre n'y changera rien. Le remède qui ne
  déplace pas la tête est `gh pr close` puis `gh pr reopen` sur sa propre PR.
- **Cas mesuré :** 04/11/2026, ms#1651 : tête poussée pendant un incident GitHub « Pull Requests, Git
  Operations and Issues », visible par `ls-remote` et par la PR, mais 0 exécution ; l'observateur de 48
  min a conclu TIMEOUT. Après close/reopen, l'exécution apparaît en quelques secondes. Variante mesurée
  les 11-12/11 : des exécutions existaient mais restaient en file avec zéro job, cancel et force-cancel en
  409, et le même remède a recréé des exécutions en quelques secondes.
- **Essayé et rejeté :** diagnostiquer un épuisement des minutes Actions sur `jsboige/roo-extensions` ou
  `jsboige/jsboige-mcp-servers` : ils sont publics, les minutes hébergées y sont gratuites.

### `gh search` fait de la recherche plein-texte : il ne résout pas un numéro d'issue
<!-- src: reference_github_search_does_not_resolve_an_issue_by_number -->
- **Quand :** on veut savoir si une issue ou une PR existe, ou retrouver ce qui cite un numéro.
- **Règle :** adresser la ressource par son numéro
  (`gh issue view N --repo <owner>/<repo> --json state,createdAt,title,labels`), le seul instrument qui
  tranche ; un résultat de recherche se borne à ce qu'il couvre (« aucune PR ni commit citant N »), jamais
  à l'existence de N.
- **Cas mesuré :** 12-13/09/2026 : une requête `15666` remonte #15631, CLOSED, sans rapport, et fait
  conclure « aucune trace » ; `gh issue view 15666` montre l'issue OPEN, créée le 11/09. Le mode d'échec
  n'est pas une erreur : c'est un résultat plausible, voisin de celui d'une ancre réellement absente.

### Un scope manquant sur un jeton se lit comme une donnée absente, pas comme un refus
<!-- src: reference_missing_token_scope_reads_as_absent_data -->
- **Quand :** une lecture GitHub rend un champ vide ou une liste vide, et on s'apprête à conclure
  « absent ».
- **Règle :** vérifier les scopes (`gh auth status`) et passer la sonde sur un cas connu-positif. Le même
  scope manquant se tait sur `gh issue view` et échoue bruyamment sur `gh issue list`, donc le silence
  d'une commande ne dit rien des autres ; isoler un champ gardé par scope dans un appel séparé.
- **Cas mesuré :** 17/09/2026 : `gh issue view --json projectItems` rend 0 sous un compte sans scope
  `project`, et une sonde sur cinq issues anciennes rend 0 elle aussi. La friction « items absents du
  Project #67 » a vécu 14 h, alors que la remesure sous le compte portant le scope donnait 6 rattachées
  sur 6.
- **Déjà dans le dépôt :** `docs/harness/reference/github-cli.md:13` — le texte y pose le scope
  `project` comme prérequis ; cette leçon ajoute qu'un scope manquant rend une absence crédible, pas une
  erreur.

### En jq, la chaîne vide est vraie : un défaut appliqué à `conclusion` fabrique un rouge
<!-- src: reference_empty_string_conclusion_defeats_jq_default -->
- **Quand :** on écrit un moniteur qui mappe `.statusCheckRollup[].conclusion` avec une valeur par défaut,
  par exemple `.conclusion // "PENDING"`.
- **Règle :** un check en cours rend `""` et non `null`, donc le défaut ne s'applique jamais. Brancher sur
  `.status` (`COMPLETED`, `IN_PROGRESS`, `QUEUED`) ou, mieux, sur le code de sortie de `gh pr checks` :
  0 = tout passe, 8 = en attente, autre = échec.
- **Cas mesuré :** 06/09/2026, PRs #1110 et #3485 sur deux dépôts différents : la même construction a
  rendu RED sur les deux à la fois, alors que `gh pr checks` affichait « pending » et que les deux ont
  fini GREEN. Deux rouges simultanés auraient dû accuser l'instrument avant le monde.

### Une lecture `gh` groupée peut rendre un récit cohérent et entièrement faux
<!-- src: reference_batched_gh_reads_fabricated_a_coherent_false_record -->
- **Quand :** un commentaire, une rectification, une fermeture ou un dispatch s'apprête à être publié sur
  la foi d'une boucle `for` ou d'un chaînage `cmd; echo; cmd`.
- **Règle :** refaire la lecture en appels unitaires, un objet par appel ; vérifier le dépôt avant le
  numéro, car une lecture dans le mauvais dépôt répond quand même au lieu d'échouer. Une ligne que la
  commande ne pouvait pas produire invalide toute la sortie, y compris ses parties plausibles.
- **Cas mesuré :** 21/09/2026 : quatre objets lus en boucle sont revenus avec des titres, des corps et un
  fil de quatre commentaires qui n'existent pas ; trois des quatre erreurs venaient d'une lecture dans le
  mauvais dépôt. Un garde d'identité posé pour une autre raison a arrêté la rectification fausse avant
  publication.
- **Déjà dans le dépôt :** `docs/harness/global-rules-detail.md:39` — il y est dit que l'instrument de
  lecture tronque (`jq` externe, `tail -N`) ; cette leçon ajoute les lectures groupées, qui fabriquent un
  récit cohérent plutôt que de tronquer.

### Une pagination cassée ne rend pas trop peu : elle re-sert la même page
<!-- src: reference_broken_pagination_returns_too_much_not_nothing -->
- **Quand :** on s'apprête à rapporter un total obtenu par `gh api graphql --paginate` ou par
  `gh project item-list`.
- **Règle :** `--paginate` n'injecte le curseur que dans une variable nommée exactement `endCursor`, sans
  aucune erreur si le nom diffère. Afficher pages, items, `hasNextPage` final et compte de doublons : la
  dernière page doit rendre `hasNextPage` faux et les doublons doivent être à zéro. Sur `item-list`, le
  seul signal est un compte exactement égal à la limite demandée ; élargir la limite une fois, garder le
  résultat dans un fichier, et ne pas re-tirer l'ensemble (quatre énumérations complètes déclenchent une
  limite GraphQL secondaire que `gh api rate_limit` ne voit pas).
- **Cas mesuré :** 02/09/2026, Project #67 : première passe à 467 pages et 46 700 items, tous faux — la
  même page re-demandée 467 fois ; réel après correction : 16 pages, 1 543 items. Le miroir mesuré le
  08/09 : `--limit 500` rend 500 items, `--limit 2000` en rend 1 716.

### Une action GitHub publique qui ne rend rien a généralement réussi
<!-- src: reference_silent_success_of_a_github_action_reads_as_failure -->
- **Quand :** un `gh pr review --approve`, un commentaire ou une fermeture rend une sortie vide, ou une
  sortie que `| tail -2` a avalée.
- **Règle :** relire l'état par l'API avant de conclure quoi que ce soit, et jamais retenter d'abord. Une
  action publique n'est pas idempotente : le retry poste un doublon que sept machines lisent. Ne pas
  coiffer une commande agissante d'un `| tail -N` qui peut avaler sa confirmation.
- **Cas mesuré :** 22/09/2026, ai-01 : `gh pr review 3779 --approve --body-file` ne rend rien ; le
  réflexe « la garde a refusé » était armé par un échec de garde plus tôt dans la même session. La
  relecture montre `decision=APPROVED`, signé à 16:51 : un retry aurait posé une deuxième review.
- **Déjà dans le dépôt :** `.claude/rules/intercom-protocol.md:44` — la règle « ne jamais retenter à
  l'aveugle, relire » y vit pour l'`append` dashboard ; cette leçon l'étend au canal `gh` et au cas du
  silence, qui invite plus fortement à la répétition qu'une erreur.

### Un merge dont la réponse se perd peut avoir posé le commit sur `main` sans fermer la PR
<!-- src: reference-lost-merge-response-duplicates-squash-commit -->
- **Quand :** `gh pr merge` rend un 502 ou un timeout — un échec ambigu, pas un refus net.
- **Règle :** fetch puis `git log origin/main -3` avant de re-tenter ; si un commit portant le message de
  la PR y figure déjà, ne pas marteler : laisser un seul nouvel essai clore la PR si GitHub reste coincé.
  Un « Merge already in progress » qui dure plus de 2 à 3 minutes signale son propre merge à moitié fait,
  pas un verrou tiers.
- **Cas mesuré :** 31/10/2026, PR #4453 : `gh pr merge --squash` rend 502 à 04:48Z et GitHub a posé
  `57b4e37` sur `main` sans terminer la fermeture ; la tentative suivante recrée un second squash
  (`39efe339`, même message) et `git diff` entre les deux est vide, donc doublon bénin. Le doublon se
  mesure et ne se corrige jamais par réécriture.
- **Déjà dans le dépôt :** `docs/harness/reference/api-error-handling.md:4` — il y est question de la
  spirale de retries sur 502 ; cette leçon ajoute que la mutation a peut-être abouti, et qu'il faut
  fetch puis log avant de re-tenter.

### Une mutation en erreur peut avoir eu lieu : vérifier sur un autre chemin de code
<!-- src: reference_failed_mutation_verify_on_a_different_code_path -->
- **Quand :** `gh pr create`, ou toute autre mutation distante, rend un 502 ou un timeout.
- **Règle :** vérifier avant de retenter, et sur un chemin distinct de celui qui a échoué — REST quand
  GraphQL a rendu 502, avec en plus un listing récent au cas où le filtre ne morde pas. Deux lectures
  par le tuyau cassé n'en font qu'une.
- **Cas mesuré :** 13/09/2026 : `gh pr create` rend un 502 ; la première vérification repasse par GraphQL
  et rend « rien », indistinguable de « rien créé ». Les deux sondes REST, ciblée sur la branche et
  listing récent, étaient vides ; le retry sûr a rendu la PR #3618.
- **Essayé et rejeté :** câbler un repli automatique `create || (vérifier && POST REST)` : sans attente
  utilisable, impossible d'écarter le retard de lecture, et un retry automatique sur une vérification en
  retard est la fabrique à doublon.
- **Déjà dans le dépôt :** `docs/harness/reference/api-error-handling.md:4` — même renvoi que la leçon
  précédente ; cette leçon ajoute que le vérificateur doit emprunter un chemin de code distinct.

### Le plafond de jobs GitHub Actions est un budget de compte, pas de dépôt
<!-- src: reference_ci_concurrency_is_an_account_budget_not_a_repo_one -->
- **Quand :** une CI traîne sans raison lisible, ou plusieurs dépôts de la flotte restent à zéro job en
  cours alors qu'un autre tourne.
- **Règle :** ne pas regarder le job, regarder le compte : compter `in_progress` et `queued` dépôt par
  dépôt, et ne pas lire l'âge de la file du dépôt saturé, qui reste perpétuellement jeune. Un groupe
  `concurrency` dédoublonne un workflow sur une branche, il ne réduit pas le nombre de workflows
  déclenchés. Le levier le moins cher est de réduire le nombre de PR simultanées, pas de toucher aux
  workflows.
- **Cas mesuré :** 21/08/2026, deux échantillons à 20 s : le dépôt au fort fan-out passe de 18 à 20 jobs
  en cours, au plafond, avec au moins 100 en file, tandis que roo-extensions reste à 0 en cours et 2 en
  file ; un job de 8 secondes a attendu 40 minutes. Le 24/08, à 14 jobs actifs sous le plafond documenté
  de 20, quatre dépôts restaient sans slot — point qualifié de SUPPOSÉ dans la fiche, à ne pas
  présenter comme la cause complète.

### Tous les dépôts en file avec zéro job en cours et un statut GitHub vert : la famine vient du compte
<!-- src: reference_all_repos_queued_zero_in_progress_is_account_pool_starvation -->
- **Quand :** ses propres dépôts ont des exécutions en file et aucune en cours, alors que le statut
  public de GitHub annonce Actions opérationnel.
- **Règle :** compter `in_progress` et `queued` sur les dépôts du compte avant d'accuser GitHub. Le
  correctif appartient au dépôt qui tient le pool, puisque ce sont ses workflows ; on escalade sur le
  dashboard global avec un cross-post, et on n'annule jamais les exécutions d'un autre workspace.
- **Cas mesuré :** 23/09/2026 à partir de 20:06Z : 11 exécutions en file sur un dépôt, 4 sur un autre, 7
  sur un troisième, toutes à zéro en cours ; un dépôt du même compte tenait 20 exécutions en cours avec
  au moins 100 en file, dont au moins 7 occupées par des agrégateurs de verdicts qui attendent dans un
  runner les checks qu'ils agrègent, donc la file s'alimente elle-même.
- **Déjà dans le dépôt :** `docs/harness/reference/github-rate-limit-instrument.md:106` — le texte y
  traite le budget par compte pour le routage des jetons ; cette leçon ajoute le diagnostic « zéro job
  en cours partout », qui distingue une famine d'une panne.

### Un agrégat rouge peut n'être qu'un plancher d'attente, et re-pousser le remet à zéro
<!-- src: reference_merge_dwell_floor_resets_on_every_push -->
- **Quand :** un check agrégateur est rouge alors qu'aucune de ses jambes ne l'est.
- **Règle :** lire le `summary` de l'agrégat avant de conclure ; si la seule sortie non verte est
  l'agrégat lui-même, il n'y a rien à réparer et la bonne action est de ne rien faire — un re-push remet
  le plancher à zéro depuis la nouvelle tête — sauf si `main` est rouge : la sortie d'urgence documentée
  est le label `merge-dwell-waived`, réservé aux urgences réelles. Les durées relatives du texte sont
  datées de leur rédaction, seuls les horodatages absolus restent lisibles, et aucune approbation ne fait
  avancer une horloge.
- **Cas mesuré :** 13/09/2026, CoursIA #15946 : plancher de 120 minutes depuis la tête, levée au
  balayage horaire suivant. Sur CoursIA #15975, le plancher expirait à 14:39:42Z mais la levée réelle
  était vers 15:07Z : annoncer l'expiration promet une demi-heure qui n'existe pas.

### Une référence citée se vérifie en trois niveaux : existe, état, motif
<!-- src: reference_cited_artifact_needs_exists_then_state_then_why -->
- **Quand :** une issue, une PR ou un commentaire renvoie à « traité séparément ailleurs », et on
  s'apprête à approuver ou à bloquer dessus.
- **Règle :** vérifier le type d'abord, une référence peut être une PR là où on lit « issue » ; puis
  l'état ; puis le motif. Ne jamais s'arrêter à un état négatif : un artefact fermé a toujours un motif,
  et le motif renverse souvent la lecture. Suivre la chaîne jusqu'à un artefact vivant et mesurer son
  état à lui.
- **Cas mesuré :** 13/09/2026, revue de roo-extensions #3621 : la référence CoursIA #15979 existe, donc le
  premier niveau passe en silence ; c'est une PR `CLOSED` jamais mergée, donc le deuxième niveau fabrique
  une fausse alerte « réserve abandonnée » ; son commentaire de fermeture dit « repliée dans #15975 », et
  le commit `690e4a5a8` y est vérifié dans la liste de commits. Le troisième niveau apprend en plus que
  CoursIA #15975 est OPEN et bloquée.

## Écrire dans le corps et les labels d'une issue

### Le bot de checklist compte les cases dans tout le corps, pastilles comprises
<!-- src: session 13/11/2026 -->
- **Quand :** on ajoute au corps d'une issue un bloc d'état, un tableau de suivi ou un extrait recopié.
- **Règle :** `checklist-enforce.yml` cherche ses motifs dans le corps entier, sans ancrage de ligne et
  sans exception pour une citation ou un bloc de code. Il compte `- [ ]` et la pastille ⬜ comme cases
  ouvertes, `- [x]`, ✅ et ❌ comme cases fermées. À la fermeture, une seule case ouverte fait rouvrir
  l'issue (sauf `[FORCE-CLOSE]` en commentaire, ou après trois réouvertures, #1487). Dans un texte
  ajouté au corps, numéroter les étapes (`1.`), ne pas les cocher, et n'écrire aucune de ces pastilles.
  Après l'écriture, vérifier que le nombre de cases du corps n'a pas changé.
- **Cas mesuré :** 13/11/2026, le jour où un bloc d'état a été posé en tête de 71 issues, lecture du
  workflow : les motifs sont aux lignes 24-29 et s'appliquent à `issue.body` entier. L'outil
  d'écriture des blocs (PR #4702, ouverte ce jour-là) refuse la syntaxe `- [ ]` et compare le nombre
  de cases avant et après l'écriture. Il ne refuse pas la pastille ⬜, que le bot compte pourtant.
- **Déjà dans le dépôt :** `.claude/rules/issue-closure.md` (cocher avant de fermer) et
  `docs/harness/reference/issue-closure-detailed.md` (réouverture par le bot) — cette leçon ajoute que
  le bot lit tout le corps, texte ajouté compris, et qu'il compte aussi les pastilles.

### Modifier le corps d'une issue ne déclenche aucun workflow du dépôt
<!-- src: session 13/11/2026 -->
- **Quand :** on écrit une décision, un état ou une consigne dans le corps d'une issue, et on compte
  qu'un automate ou une lane la verra.
- **Règle :** deux workflows seulement réagissent aux événements d'issue : `checklist-enforce.yml`
  (`issues: closed`) et `sync-project.yml` (`issues: opened`). Aucun n'écoute `edited`, `labeled` ni
  `issue_comment` ; le seul `edited` du dossier, dans `pr-negation-autoclose.yml`, écoute les pull
  requests. Une édition de corps n'ajoute rien non plus au fil des commentaires, que les lanes et le
  garde de claim (`scripts/github/check_issue_claim.py`) lisent. Une décision écrite dans le corps se
  double donc d'un commentaire court qui la nomme.
- **Cas mesuré :** 13/11/2026, le jour où les blocs d'état ont été posés, lecture des cinq fichiers
  de `.github/workflows/`. Le même jour, sept décisions du coordinateur (#1587, #2307, #2566, #4343,
  #4503, #4565, #4657) ont été écrites dans le bloc de l'issue et dans un commentaire.

### Retirer le seul label d'une issue la déplace dans les deux sélecteurs
<!-- src: session 13/11/2026 -->
- **Quand :** on retire un label de porte (`needs-approval`, `deferred`, `blocked-on-gate`) parce que
  la porte est levée.
- **Règle :** relire les labels juste après le retrait, ou poser les labels de destination dans la
  même passe. Une issue sans aucun label sort des exclusions des deux sélecteurs, et pas de la même
  façon. Le filtre du worker planifié (`start-claude-worker.ps1`) ne demande aucun label : il peut la
  prendre si elle n'est pas assignée et qu'aucun champ du Project #67 ne l'écarte. Le sélecteur des
  lanes au repos (`pick_idle_grain.py`) ne la sert pas : il la compte dans `unlabelled_open`. Les
  deux listes d'exclusion sont comparées dans [coordination de la flotte](field-lessons-coordination.md).
- **Cas mesuré :** 13/11/2026, #4224 et #4596 : `needs-approval` était leur seul label. Retiré à
  12:03Z, il les a laissées sans label et sans assignee jusqu'à 12:09Z, quand de nouveaux labels ont
  été posés (événements des deux issues, relus le même jour).

### Un bloc recopié d'un rapport peut porter un préfixe de citation
<!-- src: session 13/11/2026 -->
- **Quand :** on recopie dans le corps d'une issue, dans un commentaire ou dans un fichier un bloc
  préparé dans un rapport markdown.
- **Règle :** passer l'écriture à blanc d'abord, et lire la première ligne de chaque bloc. Un rapport
  qui cite un bloc préfixe chacune de ses lignes par `> ` : le titre attendu n'est plus en tête, et le
  texte posé s'afficherait comme une citation. Une garde qui exige le titre exact en première ligne
  refuse ces blocs au lieu de les écrire.
- **Cas mesuré :** 13/11/2026 : sur six rapports de tri, un seul citait ses blocs, et ses 12 titres
  commençaient par `> ### État au`. L'outil d'écriture, qui exige `### État au` en tête, les a refusés
  à l'essai à blanc. Relu le même jour : aucune issue modifiée ce jour-là ne porte un titre de bloc
  sous cette forme.
