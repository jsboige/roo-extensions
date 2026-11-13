# Leçons de terrain — relire, fermer, tester

Ces leçons viennent d'incidents mesurés en coordination de flotte. Elles disent quoi vérifier avant
de conclure sur une pull request, une dette ou une issue fermée, et ce qu'un test vert prouve
réellement. Chaque leçon donne la règle, la situation qui la déclenche et le cas qui l'a produite.

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

## Relire une PR, tenir une dette, fermer une issue

### Un blocage que seul le bloqueur peut lever est une dette du bloqueur
<!-- src: reference_a_remedy_only_the_reviewer_can_apply_is_the_reviewers_debt -->
- **Quand :** une review `CHANGES_REQUESTED` demande un correctif que l'auteur n'a pas le droit de
  produire — écrire dans `.github/workflows/`, poster un état de review, toucher une protection de
  branche, merger. Il répond qu'il acquiesce et ne pousse rien.
- **Règle :** le signal n'est pas « qui a agi en dernier », il est de droit : si le remède exige un
  privilège que l'auteur n'a pas, c'est au reviewer de l'appliquer, puis de retirer sa propre review
  sans approuver. Approuver serait se relire soi-même ; retirer la review est le seul geste qui
  débloque mécaniquement sans usurper la relecture.
- **Cas mesuré :** ms#1120, 08/09/2026. Ma review du 07/09 exigeait une ligne dans
  `.github/workflows/ci.yml` ; la lane a acquiescé en déclarant une contrainte de jeton
  « commentaire seulement » et n'a rien poussé, donc le dernier commit restait antérieur à la review
  et l'état de la PR disait « camp de l'auteur ». Ni un push ni un changement d'état : l'auteur acquiesce, et
  rien dans l'état de la PR ne le montre.
- **Déjà dans le dépôt :** `docs/harness/coordinator-specific/pr-review-policy.md:181-196` — la
  dette de review après un re-push y est écrite ; manque la troisième voie, celle où l'auteur
  acquiesce et où rien ne bouge.

### Un balayage limité aux PR ouvertes est aveugle au travail déjà livré
<!-- src: reference_claim_sweep_on_open_prs_is_blind_to_delivered_work -->
- **Quand :** on veut prouver qu'aucun claim n'a été posé sur un dispatch, ou qu'un travail annoncé
  n'a jamais commencé.
- **Règle :** interroger `--state all`, jamais `--state open` seul, et garder la frontière de mot
  `([^0-9]|$)` — sans elle, `#109` matche `#1091`. Le filtre d'état choisi décide la réponse avant la
  recherche : tout filtre qui exclut les états terminaux transforme « c'est fini » en « ça n'existe pas ».
  Symétriquement, demander `isDraft` dans le `--json` et exclure les brouillons : un brouillon porte
  `REVIEW_REQUIRED` exactement comme une vraie dette d'approbation et en fabrique une à chaque cycle
  (ms#861, brouillon en conflit depuis le 14/07, remontait en dette d'approbation depuis deux mois).
- **Cas mesuré :** 12/09/2026, épic #3188 : j'ai re-dispatché en concluant « aucun claim depuis
  4 jours », alors que la PR #3546 était mergée depuis le 08/09 à 23:11:46Z, 33 minutes après mon
  dispatch — branche distante auto-supprimée, aucun rapport au dashboard. Le même jour et avec la
  même frontière de mot, `--state open` rendait vide et `--state all` rendait `MERGED #3546`.
- **Déjà dans le dépôt :** `.claude/commands/coordinate.md` § « Balayage des dettes » — la moitié
  `isDraft` y est, avec la mesure du 07/09 ; la moitié `--state all` n'y était pas au 13/11/2026
  (les deux commandes du balayage interrogent `--state open`).

### Un champ d'état répond à sa propre question, jamais à « est-ce que ça attend sur moi »
<!-- src: reference_pr_state_fields_are_not_a_debt_register -->
- **Quand :** on décide sur quoi agir en lisant le bloc `## Status` d'un dashboard,
  `reviewDecision`, `mergeStateStatus` ou la liste des reviews d'une PR.
- **Règle :** lire les PRs, pas les champs. `mergeStateStatus=UNKNOWN` veut dire « pas encore
  calculé » et un re-poll rend `CLEAN` ; `CLEAN` ne dit rien des organes bloquants hors de la liste
  des checks requis ; une review périmée ne s'affiche pas comme périmée, son `commit_id` précède la
  tête sans que la liste le signale. Lire le rollup des checks avant de poser un verdict ou un
  merge.
- **Cas mesuré :** 13/09/2026, le `## Status` d'un dashboard s'est révélé faux dans les deux sens le
  même jour sur trois assertions (#3624, #3618, #3620) : il annonçait des dettes soldées et taisait
  des dettes vivantes. Le 15/09, une PR d'une autre lane affichait `CLEAN` et `APPROVED` pendant
  qu'un organe déclaré bloquant était rouge sur la tête depuis 07:29Z ; j'ai approuvé à 08:25:30Z
  sans lire le rollup.
- **Déjà dans le dépôt :** `docs/harness/coordinator-specific/pr-review-policy.md:181-196` (dette
  après re-push) et `.claude/commands/coordinate.md:118-122` (lecture de `reviewDecision` et
  `isDraft`) — manque que ces champs ne sont pas un registre de dettes.

### Une dette portée de cycle en cycle se périme sans signal
<!-- src: reference_carried_debt_list_decays_faster_than_it_is_reread -->
- **Quand :** une dette vit dans une note, un résumé de session ou une passation, et on s'apprête à
  la citer dans un rapport, un dispatch ou une décision.
- **Règle :** re-mesurer la dette sur l'instrument, jamais la relire dans la note : une mémoire est
  un enregistrement de ce qui était vrai quand elle a été écrite, jamais un état. Le coût de la
  vérification est toujours inférieur au coût du geste inutile qu'elle évite ; quand une dette est
  éteinte, l'écrire dans la fiche, sinon elle revient au cycle suivant.
- **Cas mesuré :** 21/09/2026, trois dettes portées depuis plusieurs jours, les trois déjà éteintes :
  un fichier de règles déjà corrigé en v1.0.1 par une autre machine sur une issue que je ne suivais
  pas, « 27 issues en attente de moi » qui se réduisaient à une seule une fois les marqueurs filtrés,
  et un gel levé par une PR livrée le 04/09. Récidive le 08/10 : 6 items « en vol » transmis lors
  d'une passation, tous soldés depuis 7 h.
- **Déjà dans le dépôt :** `.claude/commands/coordinate.md:88` — le balayage des dettes existe déjà
  comme étape du début de cycle ; manque qu'une dette portée se périme et se re-mesure avant d'être
  citée.

### Une fermeture proposée par un audit se relit en posture de réfutation
<!-- src: reference_adversarial_verification_overturned_two_thirds_of_closures -->
- **Quand :** un audit ou un balayage propose des fermetures d'issues.
- **Règle :** faire relire chaque candidate par un agent dont la consigne est d'essayer de la
  réfuter ; `GARDER` est le défaut. Exiger un bloc Evidence que cet agent a vérifié lui-même : PR
  `MERGED` avec sa SHA, grep avec le nombre de hits, numéro **et** état du doublon. La posture de
  réfutation ne coûte pas plus cher qu'une relecture ordinaire — c'est la même lecture avec la
  charge de la preuve inversée.
- **Cas mesuré :** 21/09/2026, audit du backlog par 20 agents sur 147 issues et deux dépôts :
  31 fermetures proposées, 9 ont survécu, 22 sont tombées ; sur un lot entier de 7 méta-analyses du
  submodule, 7 sur 7 ont été réfutées. Les modes de chute : un symptôme disparu lu comme une
  réparation, une barre de fermeture écrite dans l'issue et remplie à moitié, une décision user
  antérieure qui dit déjà non, un critère d'acceptation non couvert.
- **Déjà dans le dépôt :** `.claude/rules/issue-closure.md:26-45` — le bloc Evidence obligatoire et les
  interdits y sont ; manquent la relecture en posture de réfutation et le taux mesuré (22 propositions sur
  31 tombent, soit 71 %).

### L'accord de plusieurs agents ne réfute que la formulation d'un ticket
<!-- src: feedback_converging_refutations_of_a_misframed_ticket -->
- **Quand :** un ticket porte une inquiétude venue du user, le code conteste le mécanisme qu'il
  énonce, et plusieurs lectures indépendantes concluent « le problème n'existe pas ».
- **Règle :** chercher d'abord le mécanisme qui rendrait la crainte vraie avant de déclarer la
  question réfutée, et ne proposer la fermeture qu'après. L'accord entre agents mesure la cohérence
  de leurs lectures entre elles, pas si la bonne question a été lue.
- **Cas mesuré :** 09/10/2026, #4154 : trois lectures indépendantes ont réfuté le mécanisme annoncé
  (le service de condensation compte en octets et plafonne vers 20k tokens) et j'ai proposé de
  fermer. Le user a répondu que la crainte portait sur l'auto-compaction de Claude Code, qui
  déclenche à 0,95 × sa fenêtre configurée (330k sur ai-01, 280k ailleurs) et dépasse par
  construction le contexte de 262 144 tokens d'un des modèles du routeur ; le chiffre de 266 000 que
  nous avions expliqué était la crainte.

### Une mesure juste ne rend pas vraie la phrase qu'on en tire
<!-- src: feedback_semantic_before_conclusion_family -->
- **Quand :** toute phrase de conclusion tirée d'une mesure : un delta, un `exit 1`, une relance
  verte, un compte, un état lu dans un index sémantique.
- **Règle :** séparer explicitement ce qui est mesuré de ce qui est déduit ; si la déduction porte
  sur autre chose que la mesure (autre machine, autre période, autre couche), elle est suspecte par
  construction. Chercher un contrôle qui la falsifierait, le faire, et si aucun contrôle n'est
  possible, écrire « supposé » ou « rapporté par », jamais comme un fait.
- **Cas mesuré :** neuf occurrences recensées, dont sept sur les cinq premiers cycles, toutes de la même
  forme : la mesure est juste, la phrase qu'on en tire ne l'est pas — un `exit 1` lu « ça a échoué » alors
  que c'est un code d'alerte, une seule machine portant une tâche planifiée lue « rollout à 1/6 » alors
  que le reste était extrapolé d'une note de la veille. Les six premières ont dû être rétractées ou
  corrigées.
- **Essayé et rejeté :** écrire « je ne peux pas mesurer ça d'ici » et déléguer — une de ces
  occurrences s'est résolue en 30 s en essayant soi-même.

### Un organe se juge sur sa dernière vérification de bout en bout, pas sur sa construction
<!-- src: feedback_verify_survival_not_construction -->
- **Quand :** on s'apprête à écrire qu'un mécanisme « marche », « est en place » ou « est vérifié ».
- **Règle :** deux questions avant tout rapport d'état : quand cet organe a-t-il été vérifié de bout
  en bout sur des données réelles, et qui crierait s'il cassait ? Si la réponse est « à sa
  construction » ou « personne », l'état n'est pas sain, il est non vérifié — et c'est ce mot-là
  qu'on écrit. Ne pas rapporter de satisfaction : rapporter ce qui a été mesuré, quand, et par quel
  instrument indépendant.
- **Cas mesuré :** 28/08/2026 : l'archiveur de traces avait 7 648 archives, toutes de l'agent Roo (auquel
  Zoo a succédé) et aucune de Claude Code ; la purge à 30 jours avait vidé 387 projets sur 484 ; le
  protocole SDDD était écrit 3 fois dans le dépôt mais appliqué 60 fois en 12 semaines ; et le dashboard
  répondait `success: true` après une écriture de 402 s dont la condensation avait échoué. Le lendemain,
  22 runs sur 24 avaient bien écrit leur livrable et 4 fichiers seulement avaient survécu (320 785 octets
  perdus) : la trace d'écriture prouve la construction, pas la survie.

### Une échéance passée est une mesure manquante, pas une résolution
<!-- src: reference_passed_deadline_is_unmeasured_not_resolved -->
- **Quand :** un triage propose de fermer des issues datées parce que leur fenêtre d'action est
  passée.
- **Règle :** avant de proposer la fermeture, écrire la commande qui mesure son état aujourd'hui sur
  la machine concernée ; si aucune commande ne peut le mesurer, l'issue reste ouverte et on le dit.
  L'ancienneté ne mesure rien : elle trie l'ignorance par date, et « la fenêtre est passée » laisse
  exactement la même trace que « le travail est fait » — aucune.
- **Cas mesuré :** 18/09/2026, trois issues datées proposées à la fermeture (#2450, #2708, #3103) et
  zéro fermable après mesure : #3103 RAM à 4200 MT/s pour une cible de 5200, #2708 moitié du correctif déployée,
  et #2450 3 mois sans sauvegarde. `updatedAt` ne mesure pas non plus la souffrance : la vague de
  commentaires du 07/09 était une revue de preuves du balayage #3325, pas une relance.

### Une cellule de déploiement est livrée quand son résultat est dans le registre
<!-- src: feedback-posted-cell-is-not-a-delivered-cell -->
- **Quand :** on dispatche « exécute l'outil sur ta machine et rapporte », ou une lane poste un résultat
  avec l'entrée proposée et se déclare libérée. Une « cellule » est la case d'une machine dans le tableau
  de déploiement d'un outil sur la flotte.
- **Règle :** nommer le registre — manifeste ou configuration — comme ligne d'arrivée, et le vérifier
  lui, pas le nombre de commentaires. Quand une lane poste un résultat avec une entrée proposée,
  l'intégrer au même cycle : une cellule libérée est une passation au coordinateur, pas un item
  clos.
- **Cas mesuré :** #4336, relevé le 29/10/2026 : la lane myia-web1 avait exécuté le vérificateur le
  26/10/2026, posté le résultat complet avec le JSON exact à intégrer, puis s'est déclarée libérée ;
  personne ne l'a intégré et le tableau de bord a lu « web1 non vérifié » pendant trois jours. Le dispatch
  offrait « ouvre la PR toi-même, ou laisse le résultat sur le dashboard et ai-01 l'intégrera » : les deux
  côtés ont cru que l'autre le portait.
- **Déjà dans le dépôt :** `docs/harness/reference/per-machine-harness-reliability-checklist.md:110-118`
  — le format de rapport par machine y est (« un rapport, pas un verdict ») ; manque que le registre
  soit la ligne d'arrivée.

## Un test vert qui n'exerce rien

### Une suite verte qui ne lit que le texte du code n'exerce rien
<!-- src: reference_green_tests_can_exercise_nothing -->
- **Quand :** on s'apprête à citer « N tests verts » comme preuve d'un correctif.
- **Règle :** lire ce que le test exerce : appelle-t-il la fonction, ou cherche-t-il une chaîne ?
  Deux questions : quel objet est appelé, et le test passerait-il au rouge si la logique était
  cassée ? Un test de comportement se construit sans réseau, en instanciant les objets d'exception et
  en appelant la fonction de classification. Un test qui simule un transport n'exerce rien non plus
  si sa fixture invente une forme que le serveur ne rend jamais.
- **Cas mesuré :** 26/10/2026, PR #4365 : 10 assertions Pester, 10 passées, 0 échec, toutes des
  `Should -Match` sur le texte du script ; la même PR laissait deux défauts réels — un 401 classé
  `FAIL` avec alerte « restart », et sous PowerShell 7 un timeout qui ne passe pas par la branche
  `DEGRADED` — et les 10 tests seraient passés à l'identique. Corrigé par #4366, qui sort la
  classification dans des fonctions pures et fait instancier les exceptions par les tests ; récidive
  le 12/11/2026 (#4665 → #4643), où un autotest simulait une réponse que le serveur ne rend jamais,
  ce qui rendait sa branche inatteignable.
- **Déjà dans le dépôt :** `docs/harness/reference/lessons-archive.md:23` — la règle voisine (un PASS
  qui lit le seed est vacant, asserter un changement positif) y est ; cette leçon y ajoute le vert
  qui ne lit que le texte du code et le corollaire de revue.

### Un témoin de suppression couvre `src` et `tests`
<!-- src: reference_deletion_witness_must_cover_tests -->
- **Quand :** on donne un GO de suppression ou on écrit « zéro appelant » dans le submodule.
- **Règle :** `git grep -w <nom> -- src tests`, sur les deux portées, et énoncer la portée à côté du
  nombre. Pour un prédicat de revue fondé sur un compteur, tracer chaque site d'incrément avant de
  l'écrire : un prédicat doit nommer un compteur dont la portée a été tracée, pas un champ dont le
  nom sonne juste.
- **Cas mesuré :** 12/11/2026, ms#1735 (#1395) : mon GO annonçait 7 occurrences toutes dans le
  pivot, mesurées sur `src/` seulement ; sur la tête de PR, `src` en comptait 0 mais `tests/` en
  portait 190 dans 41 fichiers, et la CI était verte 7 sur 7 parce que `tsconfig.json` n'inclut que
  `src/**/*.ts` et qu'esbuild élide les usages de type. Même cycle, ms#1736 : le prédicat
  `dedupSkipped >= pending` aurait été désarmé, le compteur s'incrémentant avant que `pending` soit
  posé (30 266 pré-vols contre 516 en attente).
- **Déjà dans le dépôt :** `.claude/rules/no-deletion-without-proof.md:24` — exige `git grep "old-name"` =
  zéro résultat ; manquent la portée `src tests` et sa raison (les tests ne sont pas type-checkés).

### Un test qui passe un filtre vide passe par construction
<!-- src: reference_vacuous_test_from_an_empty_filter_array -->
- **Quand :** un harness PowerShell teste une fonction dont un paramètre de filtre optionnel accepte
  le vide, ou plus généralement tout cas « faux » d'un harness.
- **Règle :** poser la question de la mutation la moins chère : qu'est-ce qui échouerait si le code
  sous test était remplacé par un stub ? Si la réponse est « rien », le cas est vacant, quel que
  soit son titre. Sous PowerShell 5.1, `-not @()`, `-not $null`, `-not ""` et `-not 0` valent tous
  `$True`.
- **Cas mesuré :** 13/09/2026, PR #3627 : 13 tests sur 13 passés ; le test 6 appelait la fonction
  avec `@()`, le `continue` sautait toutes les références et la fonction rendait la chaîne vide quel
  que soit le corps — il serait passé avec le prédicat remplacé par `return $null`. Le fichier
  énonçait la bonne règle dans sa docstring et citait un extracteur naïf qui n'existe nulle part ;
  le rapport de livraison recopiait la même affirmation.
- **Déjà dans le dépôt :** `docs/harness/reference/lessons-archive.md:23` — la règle « asserter un
  changement positif » y est ; manque le piège du tableau de filtre vide.

### Un test qui lit un répertoire partagé doit prouver que le contenu vient de son appel
<!-- src: reference_second_granularity_shared_dir_makes_a_test_vacuous_in_suite -->
- **Quand :** un test asserte sur le contenu d'un répertoire horodaté ou partagé entre cas, et il est
  vert dans la suite.
- **Règle :** l'isoler (`Filter.FullName`) — isolé rouge et suite verte signifient vacuité, pas
  robustesse. Un contrat de retour qui ne peut pas exprimer son propre échec oblige les tests à
  passer par le système de fichiers ; ajouter un champ au retour ferme les deux trous à la fois.
- **Cas mesuré :** 19/09/2026, review de la PR #3737 : le même test, sur le même code défectueux,
  était rouge isolé et 30 sur 30 vert en suite. Le répertoire de sauvegarde était horodaté à la
  seconde ; le test précédent y avait écrit 5 fichiers dans la même seconde, et le test suivant les
  trouvait sans avoir rien écrit. La CI ne rattrapait rien : le test Windows-only est sauté là où la
  suite Pester tourne sous Linux.

### Un test de refus ne vaut que si le chemin d'échec ne produit pas le même état
<!-- src: reference_refusal_test_cannot_distinguish_refusal_from_failure -->
- **Quand :** on écrit ou relit un test qui vérifie qu'une garde refuse.
- **Règle :** poser la question « si je supprimais la garde, ce test deviendrait-il rouge ? » ; si la
  réponse n'est pas un oui mécanique, le test documente une intention. Un test de refus asserte le
  refus par sa signature propre — le collaborateur n'a jamais été construit (mock et
  `assert_not_called`), ou le log de refus a été émis — jamais par une valeur de retour que le chemin
  d'erreur produit aussi.
- **Cas mesuré :** 04/09/2026, PR ms#1088 (#3409) : mutation `return True` en tête de la garde,
  vérifiée comme ayant mordu, puis 7 échecs et 14 succès — les 7 sont les tests de fonction pure,
  les 14 verts incluent tous les tests d'intégration et de non-contournement, et 9 ne gardent rien.
  Deux causes cumulées : une variable d'environnement posée après un import de valeur figé, et trois
  assertions satisfaites à l'identique par un composant privé de sous-processus ; ces 21 tests
  n'étaient lancés par aucun job CI, qui nommait une liste de fichiers explicite.

### Un correctif d'état persistant n'est pas validé par ses propres fixtures
<!-- src: reference_new_fixtures_are_blind_to_legacy_stock -->
- **Quand :** on change la sémantique d'un état qui survit au processus — messages, colonnes, caches,
  fichiers de configuration — et on écrit de nouvelles fixtures.
- **Règle :** lancer la suite complète, jamais le seul fichier ajouté : c'est le seul instrument qui
  voit le stock hérité. Avant d'écrire les tests, se demander quel état la production porte que la
  fixture n'aura pas ; un test rouge préexistant sur un correctif de migration est un signal, pas
  une friction à ajuster.
- **Cas mesuré :** 01/09/2026, #1073 : 6 tests neufs, 6 verts, puis la suite complète au rouge sur
  2 fichiers préexistants et 5 tests. Le stock portait `status: 'read'` sans le nouveau champ par
  workspace ; la première version concluait « non lu » et ressuscitait tous les messages
  machine-large jamais lus sur les 7 machines.

### Un mock prouve que la requête est construite, jamais que la base l'accepte
<!-- src: reference_mock_proves_sql_not_acceptance -->
- **Quand :** une suite d'écriture en base est verte sur un writer mocké.
- **Règle :** la contre-épreuve est une ligne sonde poussée à travers toutes les transitions contre
  le schéma réel, puis supprimée et la table re-comptée ; vérifier aussi ce qui n'est pas là
  (contraintes `CHECK`, types énumérés), car une absence est un fait à établir. Vaut pour tout
  écrivain qui avale ses erreurs : plus l'écriture est isolée par contrat, moins un échec réel est
  visible.
- **Cas mesuré :** 18/08/2026, #3151 : 26 tests verts sur un writer mocké, du type
  `expect(sql).toContain('status = $1')`, prouvent que la clause est construite, pas que PostgreSQL
  accepte la valeur. Si le schéma avait posé `CHECK (status IN ('unread','read'))`, chaque
  archivage aurait échoué en production silencieusement, le dual-write avalant ses erreurs par
  contrat.

### Une fixture écrite de mémoire prouve le parseur contre une croyance
<!-- src: reference_fixture_in_a_shape_the_producer_never_writes -->
- **Quand :** on teste un extracteur, un parseur ou un client contre des fixtures écrites à la main.
- **Règle :** construire la fixture en copiant une ligne réelle anonymisée, et compter la sortie sur
  un échantillon réel — un zéro sur des données qui en contiennent est le signal. Quand une colonne
  est vide partout, chercher toute la chaîne producteur, extracteur, writer : un trou peut en cacher
  un second en amont.
- **Cas mesuré :** 07/10/2026, #2191 : l'extracteur ne lisait les `tool_use` que sous une forme
  imbriquée `block.toolUse`, et son test était vert, alors que le producteur écrit
  `{type:'tool_use', id, name, input}` à plat — 2 508 blocs sur 2 508 dans une session réelle,
  0 imbriqué. Résultat : 0 action extraite sur 816 sessions d'ai-01, 256 313 après correctif.

### Un nouvel import nommé casse les mocks partiels du module
<!-- src: reference_new_module_imports_break_partial_mocks -->
- **Quand :** on ajoute un import nommé à un module tôt dans le graphe (tools, services) dont des
  tests font `vi.mock(...)` avec une factory partielle.
- **Règle :** `grep -rln "vi.mock(.*<module>" src tests` avant d'étaler le nouvel import ; préférer
  réutiliser la surface déjà mockée (un probe en try/catch), sinon compléter chaque factory avec
  l'export manquant et une valeur neutre. Vérifier avec la config CI, pas seulement les tests
  ciblés : les fichiers touchés ne sont pas ceux qu'on modifie.
- **Cas mesuré :** 20/10/2026, ms#1467 (#4293) : `[vitest] No "X" export is defined on the mock`,
  vu par la CI GitHub deux cycles de suite alors que les tests ciblés locaux passaient. La factory
  partielle gèle la surface d'exports et l'erreur n'apparaît qu'à l'exécution du nouveau code.

### Un rouge isolé sur le test crossPost de `dashboard.test.ts` n'est pas une régression
<!-- src: reference_dashboard_crosspost_test_is_a_race_flake -->
- **Quand :** ce test rougit sur une PR qui ne touche pas `src/tools/roosync/`.
- **Règle :** rejouer le fichier en local avec la config CI (environ 44 s, 133 tests attendus), puis
  `gh run rerun --failed`. Ne pas corriger son propre diff pour cela, ne pas bloquer le merge sur ce
  test seul, et ne pas conclure « flake » avant le rejeu local : si le fichier échoue aussi en
  local, c'est un vrai défaut.
- **Cas mesuré :** 01/11/2026, ms#1613 : le job `roo-state-manager` a rougi sur une PR qui ne touchait que
  `src/tools/search/`, avec `Format dashboard invalide: frontmatter manquant (machine-other-machine)` ; le
  re-run du même commit est passé sans changement de code. Le test scénarise une course avec de vrais
  timers (injection à 150 ms, libération du verrou à 250 ms, assertion `waited >= 200`) et lit le fichier
  cible au milieu d'une écriture quand le runner est chargé.

### Un garde posé sur le transport lit la forme du transport
<!-- src: reference_guard_reads_the_wire_before_the_sdk_decodes -->
- **Quand :** on écrit ou relit un garde qui intercepte une réponse HTTP au niveau du `fetch` ou du
  corps brut, ou qui lit une réponse après passage par le SDK.
- **Règle :** poser la question « mon garde lit-il la même chose que ce que mon appelant reçoit ? ».
  Au niveau du transport, il doit traiter la forme sur le fil, par exemple une chaîne base64 ; au
  niveau du client, la forme rendue par le SDK. Le test doit construire la réponse dans la forme
  réellement servie, pas matcher le nom de la fonction dans le source.
- **Cas mesuré :** 26/10/2026, ms#1523 : le SDK d'embeddings demande `encoding_format: 'base64'` par
  défaut et ne décode qu'après le `fetch` ; le garde testait `Array.isArray(first)` sur le corps
  brut, renvoyait `null` en production et ne se déclenchait donc jamais. Mesure sur l'endpoint réel :
  base64 rend 13 656 caractères pour 2 560 éléments en `float`, exactement la dimension attendue ;
  le garde payait en plus un `clone()` et un `JSON.parse` complets à chaque appel réussi, pour
  toujours rendre `null`.
