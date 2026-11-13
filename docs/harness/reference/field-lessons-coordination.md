# Leçons de terrain — coordination de la flotte

Ces leçons viennent de la mémoire du coordinateur de la flotte (siège myia-ai-01) : conduite des
lanes interactives, tenue des claims et du registre des questions au user, ce qui justifie une
demande au user et ce qui compte comme preuve, puis quelques faits propres au siège du
coordinateur. Chaque leçon se lit seule : la règle d'abord, le cas mesuré ensuite.

**Provenance :** fiches de la mémoire locale du coordinateur ai-01, sorties vers le dépôt le
2026-11-13. Chaque leçon porte en commentaire le nom de sa fiche d'origine.

## Mener les lanes interactives

### Un chantier relayé n'est pas un chantier avancé — il reste la dette du coordinateur jusqu'à fin vérifiée
<!-- src: feedback_never_leave_a_chantier_incomplete -->
- **Quand :** on relaye, dispatche ou « met en suivi » un chantier long, puis passe au suivant.
- **Règle :** un chantier est terminé quand le résultat est vérifié en production (état, trace,
  mesure), sinon il est en cours et reste la dette de celui qui l'a relayé. Tout chantier touché
  entre dans le suivi du coordinateur jusqu'à preuve de fin ; une deuxième relance sans progrès
  vaut exécution par le coordinateur lui-même ou escalade avec le blocage précis — jamais une
  troisième relance identique.
- **Parole du user (17/09/2026) :** « tu as été relancé au moins 10 fois » (directive donnée en
  colère — le relais répété d'un chantier est une forme d'abandon déguisée en délégation).
- **Cas mesuré :** le chantier Zoo→claudish (traces Zoo hors vue centrale) relayé au moins 10 fois
  à une lane exécutante sans jamais être mené à terme (17/09).

### Une lane sans grain actionnable est la dette du coordinateur, pas celle de la lane
<!-- src: feedback_lanes_must_never_idle_and_dogfood_sk_agent -->
- **Quand :** des lanes enchaînent des cycles sans travail actionnable, ou un tour de coordination
  s'apprête à dispatcher.
- **Règle :** mesurer le pool actionnable par lane avant chaque dispatch ; si une lane n'a reçu aucun
  grain, c'est une dette du coordinateur. Nourrir dans l'ordre : merger les PRs qui l'attendent, convertir
  les constats vérifiés en issues (ce mandat vaut accord du user pour ces issues d'alimentation ; hors de
  lui, `issue-creation.md` exige un accord explicite), étiqueter le travail actionnable et l'assigner.
  Chaque file profonde inclut du travail délégué aux modèles locaux via sk-agent (reviews, analyse), à
  faire dogfooder.
- **Parole du user (07/10/2026) :** « Pas mal d'agents sont en stall. Ça ne devrait pas arriver,
  fais une gestion proactive des projets et issues github pour que toutes les lanes soient bien
  alimentées » puis « Et n'oubliez pas de faire usage de sk-agent avec nos modèles locaux, qu'il
  faut dog fooder ».
- **Cas mesuré :** 07/10 — le sélecteur tirait toujours la même issue liée à une lane (#4025)
  pendant que les autres issues ouvertes étaient gelées ; lanes à vide depuis 3 cycles et plus.
- **Déjà dans le dépôt :** `docs/harness/reference/sk-agent-usage-guide.md` (pré-review sk-agent,
  mandat 07/10) — ce texte ajoute le mandat « aucune lane à vide » et la mesure du pool par lane
  avant chaque dispatch.

### « Pool vide » déclaré par les lanes avec un inventaire plein : défaut du sélecteur, pas manque de travail
<!-- src: reference_idle_lanes_with_a_full_pool_is_a_picker_defect -->
- **Quand :** plusieurs lanes rapportent « aucun grain actionnable » (un grain est l'issue que le
  sélecteur `pick_idle_grain.py` propose à une lane au repos) alors que l'inventaire des issues
  ouvertes compte du travail faisable.
- **Règle :** compter soi-même les issues actionnables (REST, les deux dépôts), puis comparer à ce que le
  sélecteur rend (`pick_idle_grain.py --dry-run --json`) avant de croire le « pool vide ». Graine par
  défaut fixe, urne de labels étroite (le sélecteur ne tire que parmi quelques labels), claims non sautés (état du sélecteur mesuré le 07/10, avant son
  correctif) : le défaut est côté sélecteur. Levier rapide : étiqueter `approved` les issues actionnables.
  Le correctif structurel (#4103 : graine dérivée par lane, saut des claims) est entré depuis ; l'urne de
  labels reste étroite, et une file explicite par lane dans le dispatch reste le moyen sûr de répartir le
  travail.
- **Cas mesuré :** 07/10 — plusieurs lanes ont tiré la même issue #4025 pendant 3 cycles et plus
  (graine fixe, urne limitée à trois labels, claims non sautés) alors que 24 issues sur 95
  ouvertes étaient actionnables par n'importe quelle lane.

### Un avis d'inactivité inter-sessions marque une fin de tour, pas une lane inactive
<!-- src: feedback_cross_session_idle_is_turn_boundary -->
- **Quand :** le harnais émet un « cross-session idle notice » sur une session voisine, et qu'on
  s'apprête à la décrire « idle ».
- **Règle :** cet avis prouve seulement que la session a atteint une frontière de tour et peut
  traiter les messages en file. L'état de charge se lit dans le rapport de la lane, son dashboard
  ou une déclaration explicite ; une lane peut travailler en fenêtres bornées entre crons puis se
  taire pendant que des observateurs tournent — ce silence est un budget gardé, pas une preuve
  de panne. Réserver « idle » à une absence de travail vérifiée, « stalled » à une condition ou
  échéance nommée manquée.
- **Cas mesuré :** une lane voisine décrite « idle » sur la foi de l'avis travaillait en fenêtres
  bornées de 1 à 1,5 h entre des crons de 4 h, avec des mesures déléguées encore actives.

### Lire le dashboard global à chaque cycle de coordination
<!-- src: feedback_read_global_dashboard_every_cycle -->
- **Quand :** démarrage d'un tour de coordination, après la lecture du dashboard workspace.
- **Règle :** lire l'intercom du dashboard `global` à chaque cycle, puis trier en trois groupes :
  ce qui est adressé à la lane ou au coordinateur (répondre sur le point de rendez-vous que le
  post nomme), ce qui est adressé à une autre lane (le noter, ne pas agir), le bruit de
  surveillance. Les escalades cross-workspace atterrissent là par conception et ne produisent pas
  toujours de mention dans l'inbox.
- **Parole du user (11/10/2026) :** « Pense bien à lire le dashboard global régulièrement, car je
  pense que les agents y écrivent souvent des messages qui te sont réellement adressés. »
- **Cas mesuré :** 11/10 — deux posts globaux adressés à la lane restés sans réponse pendant des
  heures (une tâche flotte relayée comme mandat user, une demande de correction du statut
  global), aucun `[MENTION]` dans l'inbox.
- **Déjà dans le dépôt :** `.claude/configs/user-global-claude.md` (le global est le canal
  d'escalade cross-workspace) — ce texte ajoute le devoir de lecture par cycle du coordinateur.

### Le périmètre CoursIA ne se gère pas depuis roo-extensions
<!-- src: feedback-roo-extensions-coordinator-does-not-manage-coursia-prs -->
- **Quand :** un balayage de dettes ou un tour de coordination fait apparaître des PR du dépôt
  CoursIA.
- **Règle :** ne pas auditer, trier, reviewer, relancer les gates, approuver, mettre en file ni
  gérer ces PR — le périmètre appartient à l'adjoint CoursIA. Une dépendance cross-workspace
  réelle se signale au coordinateur CoursIA via le point de rendez-vous approprié, sans auditer
  ni agir sur la PR ; jamais de cron, d'observateur ou de sous-agent armé sur une PR CoursIA
  depuis cette lane.
- **Cas mesuré :** un balayage CoursIA lancé depuis roo-extensions a créé du
  scope creep, du travail dupliqué et une activité opaque pour le user, alors qu'un adjoint
  dédié existait déjà.

### Écrire Zoo, pas Roo, dans tout ce qu'un humain lit
<!-- src: feedback_say_zoo_not_roo_roo_is_retired -->
- **Quand :** rédiger une question, une entrée de registre, un post de dashboard, un titre ou un
  body d'issue, un body de PR.
- **Règle :** le compagnon extension/scheduler de la flotte s'appelle Zoo ; Roo est retiré de la
  flotte. Garder « Roo » uniquement comme identifiant littéral (noms de dépôt `roo-extensions` et
  `roo-state-manager`, `.roomodes`, symboles de code, traces historiques), marqué legacy au
  besoin. Avant de poster, chercher « Roo » dans le brouillon et justifier chaque occurrence
  comme identifiant littéral.
- **Parole du user (03/10/2026) :** « OK mais on parle de zoo, hein, roo est retired » — deuxième
  correction du même type (la première le 25/09).
- **Cas mesuré :** écrire « Roo » force le user à revérifier si l'on parle d'un composant mort,
  et montre que la décision de retrait n'est pas arrivée jusqu'au vocabulaire de l'agent.
- **Déjà dans le dépôt :** `docs/harness/reference/zoo-migration-runbook.md` (la migration est
  documentée, pas la règle de nommage). Le `CLAUDE.md` du projet garde la ligne « Claude DIRIGE,
  Roo ASSISTE » ; depuis le 13/11/2026 (#4682) il précise que « Roo » y désigne l'extension
  compagnon, Zoo Code aujourd'hui, et que cette extension est désactivée sur la flotte.

## Claims et registre des questions

### Ne pas s'endormir sur un claim que l'on tient : le balayer à chaque cycle
<!-- src: feedback_never_fall_asleep_on_a_claim_i_hold -->
- **Quand :** je tiens un claim (issue, epic) et plus aucun échange ne m'y est adressé.
- **Règle :** un claim tenu et laissé sans suite ne produit aucune trace — « personne n'attend »
  et « le porteur a décroché » laissent la même empreinte. Balayer les epics ouvertes par auteur
  et date du dernier commentaire (les deux dépôts) : une dernière ligne de moi et ancienne est
  une dette à mon nom. Au garde de claim, une ligne « own claim … resuming » de plus de 24 h est
  une dette, pas un feu vert : libérer ou agir dans le cycle. Ne jamais répondre à ce défaut par
  une promesse — ce qui manque est un balayage, pas une intention.
- **Parole du user (21/09/2026) :** « OK je te fais confiance pour solder l'issue dans les
  prochains jours. STP ne t'endors plus dessus (sur aucune issue soit dit en passant, mais
  celle-là en particulier). »
- **Cas mesuré :** Epic #3188 — deux silences sur le même claim (14 h, puis 3 jours, avec 1,2 Go
  retenus sur un disque à 88 % chez la lane qui attendait ma confirmation) alors qu'une promesse
  écrite de confirmer chaque artefact venait d'être postée. Premier passage du balayage (21/09,
  16 epics) : deux epics dormantes de plus détectées, dont #2307 sans commentaire d'un autre
  depuis 3 mois et demi.
- **Déjà dans le dépôt :** `.claude/rules/agent-claim-discipline.md` (vérifications avant claim
  et avant livraison) et `.claude/commands/coordinate.md` §Balayage des dettes (points 3 à 5 :
  questions des autres sur mes epics, mes dispatchs sortants, claims anciens des autres) — ce
  texte ajoute l'angle mort : mes propres claims silencieux.

### Le format d'un claim identifie son auteur — worker headless ou lane interactive
<!-- src: reference_worker_claim_format_identifies_the_headless_worker -->
- **Quand :** un claim apparaît sans intention écrite, ou un `[RESULT]` de worker arrive sur une
  issue que je tiens.
- **Règle :** `[CLAIMED] by claude on <machine> at <heure locale>` vient du worker planifié
  (`scripts/scheduling/claim-lock.ps1`) ; une lane interactive écrit
  `[CLAIMED] <machine>:<workspace> — <intention>`. Ce format prouve que la tâche headless tourne
  encore, même quand les rapports la disent désactivée : ne rien ordonner à la session headless,
  faire désactiver la tâche par la lane roo-extensions de la machine, faire reprendre le claim
  par la lane interactive. Un worker tué en plein cycle laisse un verrou permanent (seule la fin
  normale retire l'assignee) : libérer sous la même identité de lane, puis décider explicitement
  du sort de l'assignee.
- **Cas mesuré :** 08/10, #4131 claimée par le worker 14 s avant la décision du coordinateur ;
  20/10, #4293 — le worker d'ai-01 porte la même identité de lane que la session interactive,
  prend l'issue et poste un PASS sur une PR de rebut (#4295) : un PASS de worker n'est jamais une
  livraison, relire la PR citée puis corriger le fil ; 02/11, #4481 — verrou permanent après gel
  de la machine en plein cycle.
- **Déjà dans le dépôt :** `docs/harness/HARNESS-OVERVIEW.md` (le filtre worker lit ce motif
  exact) — ce texte ajoute la conduite à tenir et les deux variantes mesurées.

### Une porte user antérieure au registre ne vit que dans son commentaire d'issue
<!-- src: reference_pre_registry_user_gate_lives_only_in_an_issue_comment -->
- **Quand :** une lane rapporte « en attente d'arbitrage user » sur un sujet ancien.
- **Règle :** le registre des questions existe depuis le 15/09 (#3656) ; une porte posée avant ne
  vit que dans le commentaire d'issue qui l'a soulevée, et rien ne la re-présente. Chercher le
  sujet dans le registre avant de la traiter comme vivante : absente = orpheline, l'inscrire ou
  la trancher. Quand une règle générale nouvelle tombe, balayer les vieux commentaires « reste
  chez l'utilisateur » qu'elle pourrait couvrir. Une porte orpheline peut aussi être devenue sans
  objet : vérifier qu'un fait postérieur n'a pas retiré sa cause avant de l'inscrire.
- **Cas mesuré :** une porte du 31/08 (#3147) portée 25 jours comme « arbitrage user » sans jamais figurer
  au registre (0 hit au grep du 25/09), exécutée seulement parce qu'une règle générale du 25/09 la
  couvrait par hasard ; second cas le 27/09 (#3713), porte devenue sans objet : l'architecture qu'elle
  arbitrait avait changé dès le lendemain de sa pose (17/09 → 18/09).

### Marquer l'issue elle-même quand sa fermeture attend le user
<!-- src: reference_worker_closes_issue_pending_in_coordinator_registry -->
- **Quand :** la fermeture d'une issue dépend d'une réponse du user (entrée de registre ouverte).
- **Règle :** le registre vit dans la mémoire par machine ; workers et autres lanes lisent GitHub
  et le dashboard, jamais ce fichier. Poser sur l'issue une ligne-marqueur (« fermeture en
  attente d'arbitrage user — ne pas fermer ») pour que le claim-and-close d'un worker la voie.
  Quand le user répond, vérifier l'état de l'issue d'abord : elle peut déjà être fermée, et la
  condition du user doit alors être satisfaite après coup. Quand le user répond à une porte
  qu'une autre lane a préparée, relayer la réponse comme une tâche adressée à cette lane dans le
  même cycle (dashboard avec mention plus DM, le DM survit à la condensation), en restatuant
  tout le dossier — les messages de la lane ont pu être archivés entre-temps.
- **Cas mesuré :** 24/09, #2957 fermée par le worker pendant que la question de fermeture était
  encore ouverte au registre, la condition du user n'était pas remplie au moment de la fermeture ;
  29/09, une lane ne savait plus ce qu'était l'entrée qu'on lui citait (« Il ne sait pas de quoi
  tu parles, il faut vous entendre entre vous ! », user).

### Un identifiant de registre ne s'écrit jamais sans sa machine
<!-- src: reference_registry_id_without_its_machine_collides_across_lanes -->
- **Quand :** citer une entrée de registre de questions hors de son registre, ou lire un
  « RXnn répondue » sur un dashboard partagé.
- **Règle :** chaque machine numérote ses entrées indépendamment ; un identifiant n'existe
  qu'avec la machine dont le registre le porte. Écrire « ai-01 RX92 », jamais « RX92 » nu.
  Avant d'agir sur un « RXnn répondue » lu sur le dashboard, vérifier que la réponse est
  consignée dans le registre de la lane qui agira : un faux « répondue » déverrouille un geste
  que le user n'a jamais approuvé — l'enjeu est asymétrique.
- **Cas mesuré :** 08/10 — deux RX92 distincts coexistaient (ai-01 : écriture d'un rattrapage en
  base ; po-2024 : portée flotte d'une consigne worker) ; le statut condensé du dashboard
  portait un « RX92 » nu, sans propriétaire.
- **Déjà dans le dépôt :** `.claude/configs/user-global-claude.md` §User Arbitration et
  `docs/harness/global-rules-detail.md` (registre par machine, jamais commité) — ce texte ajoute
  la règle de citation qualifiée et le contrôle avant action.

### Chercher la réponse du user dans toutes les sessions de la machine avant de restituer une question
<!-- src: feedback_capture_user_answers_given_in_any_workspace_session -->
- **Quand :** restitution des questions ouvertes, fin de session, ou le user dit « je t'ai déjà
  répondu ».
- **Règle :** le user parle à plusieurs sessions de la même machine en parallèle ; une réponse
  donnée à une session voisine n'atteint jamais le registre de la mienne. Toute réponse reçue
  dans ma session va au registre avant tout autre geste, verbatim. Avant chaque restitution,
  balayer les transcripts des autres projets de la machine depuis la dernière restitution. Si le
  user a déjà donné une direction ailleurs, la question devient une tâche : ne pas lui reposer
  un choix plus étroit. Quand il dit « je t'ai déjà répondu », le croire — exécuter, puis chercher
  où la réponse s'est perdue, seulement pour corriger le processus.
- **Parole du user (02/10/2026) :** « Je t'ai déjà répondu OK hier, tu ne prend pas les bonnes
  notes de mes réponses. Pour un coordinateur c'est très inquiétant »
- **Cas mesuré :** 02/10 — deux réponses restituées comme ouvertes alors que l'une avait été
  donnée la veille dans une autre session de la même machine, et que l'autre n'a été retrouvée
  dans aucun transcript local.

## Ce qui est demandé au user, et quand

### Finir un travail déjà décidé est une exécution, pas un arbitrage
<!-- src: feedback_finishing_the_work_is_not_a_permission_to_request -->
- **Quand :** remplir la colonne « à décider » d'un rapport ou une entrée du registre.
- **Règle :** tester chaque item par « si je le fais et le raconte ensuite, le user peut-il être
  en désaccord avec le résultat, ou seulement avec la façon de faire ? » — seul le premier cas
  est un arbitrage. Ne sont jamais des arbitrages : la conséquence mécanique d'une décision déjà
  rendue, ce pour quoi une procédure canonique existe déjà, un geste local réversible et
  mesurable, la lutte contre l'entropie et l'obsolescence. Le doute se lève en faisant la partie
  non controversée et en ne remontant que le résidu. Restent des arbitrages : une valeur en jeu,
  un risque irréversible ou tourné vers l'extérieur, un conflit de mandats.
- **Parole du user (07/09/2026) :** « Bien sûr envoyez (vous avez une procédure canonique…), je
  ne comprends pas qu'un jour après la bascule, tu sois encore en train de me demander la
  permission de finir le travail, c'est systémique. »
- **Parole du user (06/10/2026) :** « Oui de façon générale, tu peux prendre l'initiative qui
  lutte contre l'entropie et l'obsolescence, ce genre de MAJ est le travail de maintenance
  nécessaire »
- **Cas mesuré :** le 07/09, trois des six « décisions » présentées au user n'en étaient pas
  (propager un secret déjà tourné, aligner deux fichiers d'environnement locaux sur la valeur qui
  répond, relancer un chantier gelé par le coordinateur lui-même). Sur-demander et
  ne-pas-demander produisent le même résultat — le travail n'avance pas — mais sur-demander
  déguise l'inaction en prudence.

### La lane lance les scripts ; le user ne fournit que ce que lui seul peut donner
<!-- src: feedback_agents_run_the_scripts_user_only_clicks -->
- **Quand :** une entrée de registre ou un paragraphe « ce qui vous attend » commence par
  « geste user : lancer `<script>` ».
- **Règle :** ne jamais écrire « geste user : lancer le script ». La lane lance le script
  elle-même (dry-run posté d'abord, chaîne entière passée en non-élevé), et le user n'a plus que
  le clic UAC ou le mot de passe à taper — seul ce qui exige physiquement le user reste à lui.
  Si le user est absent, ne pas ouvrir de fenêtre qui l'attendra : relancer à son prochain
  passage. Dans le rapport final, écrire « la lane X lance le script ; vous cliquez l'UAC quand
  elle le demande » — nommer la lane quand le script appartient à une autre, et ne pas prescrire
  la ligne de commande.
- **Parole du user (28/10/2026) :** « Lance un UAC au besoin, c'est vous qui exécutez les scripts ».
- **Cas mesuré :** récidive le 12/11 (compaction qdrant) — deux lanes avaient écrit au user de lancer
  lui-même un script en console élevée, la lane qdrant pendant 24 h ; le user a tranché en accordant l'UAC
  à l'agent qui exécutait le script lui-même.

### Le geste du user vient en dernier, après ma propre preuve de bout en bout
<!-- src: feedback_user_gesture_is_last_after_my_own_end_to_end_proof -->
- **Quand :** une chaîne exige du user un mot de passe ou un clic.
- **Règle :** le geste du user n'est jamais un instrument de test. Avant de demander, prouver
  chaque maillon côté serveur avec ses propres instruments (lecture élevée sèche d'abord,
  journaux, droits sur l'endpoint). Si un maillon ne se teste qu'avec le secret du user, le dire
  d'avance et demander une seule tentative, tous journaux capturés, arrêt au premier échec. Une
  réparation n'est pas une réparation vérifiée : jamais de nouvelle saisie enchaînée juste après
  un correctif. Quand le user signale un danger, arrêter immédiatement et rassurer avec des faits
  mesurés — ce qui a changé, comment revenir, ce qui est intact.
- **Parole du user (28/10/2026) :** « Attention stp tu va nous faire briquer le truc !!! » puis
  « Ca fait 3 fois que tu me fait faire une connerie !!! »
- **Cas mesuré :** trois demandes de mot de passe successives un même soir, dont aucune ne
  pouvait aboutir (compte deviné refusé par le service, jeton réseau filtré, étape suivante
  jamais testée) — chaque saisie a dépensé le temps du user et présenté l'échec comme un risque
  pour le système (détail local non publié).

## Ce qui compte comme preuve

### Écrire « non exercé » tant qu'aucun appel de bout en bout n'a exercé le sous-système
<!-- src: feedback_no_nominal_without_an_end_to_end_probe -->
- **Quand :** avant tout `[DONE]`, bilan ou phrase contenant « nominal », « sain », « OK »,
  « fonctionne ».
- **Règle :** nommer l'appel exact qui a exercé le sous-système — le geste que l'utilisateur
  final fait, pas un endpoint de santé ni un compte d'objets — avec son résultat. Un compte
  d'objets existants n'est pas une mesure d'objets qui marchent ; si l'effet dépend d'un
  credential, sonder le credential, jamais le réglage. Sans cet appel nommé, le mot juste est
  « non exercé ».
- **Parole du user (07/09/2026) :** « visiblement ça ne rentre pas » (au moins la troisième
  relance sur le même défaut).
- **Cas mesuré :** 07/09 — « les 16 outils répondent, rien n'est cassé » rapporté pendant que la
  recherche sémantique échouait sur la plupart des workspaces et que le service d'embeddings
  rejetait toute clé ; l'endpoint de santé répondait 200 pendant que 100 % des appels
  authentifiés étaient refusés : un service debout et un service utilisable sont deux mesures
  distinctes, et la première ne dit rien de la seconde.
- **Déjà dans le dépôt :** `docs/harness/reference/tool-start-hook.md` (contrôle positif avant
  toute conclusion) — ce texte ajoute l'interdiction du mot « nominal » sans appel nommé.

### Un contrôle positif valide la cible, jamais la sélection
<!-- src: reference_positive_control_validates_the_target_not_the_selection -->
- **Quand :** on a sondé à la main le bon couple clé/endpoint et on veut en conclure que le code
  corrigé marche.
- **Règle :** la sonde manuelle prouve que la cible est utilisable, jamais que le code
  sélectionne cette cible — les deux propositions sont indépendantes, et c'est la non testée qui
  est l'objet du correctif. Le contrôle positif réussi retire un confondant (il distingue « le
  fix ne marche pas » de « l'endpoint est mort ») ; celui qui échoue annule la mesure ; aucun ne
  remplace l'exercice du chemin.
- **Cas mesuré :** 12-13/09, fix #1147 (le code doit cesser de retomber sur la mauvaise clé de
  chat) — la complétion de contrôle a répondu 200 avec le bon couple, ce qui restait compatible
  avec un code présentant toujours l'autre clé en production ; le seul qualificatif juste était
  « chargé, non exercé » jusqu'à ce que la condensation réelle passe.
- **Déjà dans le dépôt :** `docs/harness/reference/tool-start-hook.md` (contrôle positif requis)
  — ce texte ajoute la distinction cible/sélection.

### Une sonde d'acceptance exerce la transition que la flotte exécutera, pas le régime permanent
<!-- src: reference_acceptance_probe_must_exercise_the_transition_the_fleet_will_perform -->
- **Quand :** une sonde d'acceptance est citée comme emportant une décision de déploiement.
- **Règle :** demander quelle transition la sonde exerce et laquelle la flotte exécutera en
  premier ; si elles diffèrent, la seconde n'est pas couverte, quelle que soit la qualité de la
  première. Déduire la chaîne réellement exercée de l'URL et du point d'émission de la sonde,
  jamais de son message de verdict.
- **Cas mesuré :** 18/09, revue de #1172 (#3713) — la sonde démontrait un échange de build
  millésime vers millésime, alors que le premier geste de chaque machine serait le passage
  legacy vers millésime avec des hôtes vivants (60 hôtes sur ai-01) ; la transition était
  traitée par conception, mais pas prouvée par ce qu'on montrait. Variante 05/10 (#1357) : une
  sonde « PASS full public chain » n'avait traversé ni le pont conteneur ni le proxy, son
  verdict était codé en dur (correctif #4068).

### Relayer les pré-vols des autres machines ne mesure pas le sien
<!-- src: reference_relayed_preflight_is_not_my_preflight -->
- **Quand :** agréger les pré-vols et états « sync » des autres machines dans un bilan de flotte.
- **Règle :** faire ses propres vérifications (état de l'arbre, révision du sous-module) dans le
  même tour que la collecte des autres. Plus les rapporteurs concordent, plus l'omission du
  sien devient invisible : trois « sync » lus couvrent trois machines, jamais celle qui lit. Le
  coordinateur est structurellement l'angle mort de son propre tableau de bord — il agrège les
  états des autres et n'apparaît dans aucun rapport entrant.
- **Cas mesuré :** 27/08 — trois machines ouvraient leur rapport par « main et submod sync » ;
  relayé trois cycles durant comme état de flotte, alors que ai-01 était la seule machine
  désynchronisée (arbre de travail et main du sous-module sur deux révisions différentes), et
  qu'un cycle entier de review et de merge s'est fait depuis un arbre qui n'était pas celui de
  main.

### Constater qu'un artefact n'est pas chez soi retire un candidat — ça n'en désigne aucun
<!-- src: reference_verifying_an_absence_at_home_does_not_designate_a_holder -->
- **Quand :** attribuer la détention d'un artefact à une machine par élimination.
- **Règle :** un porteur se désigne par une trace qui le nomme — fil d'issue ou de PR,
  identifiant de conversation, commit, `[CLAIMED]` horodaté, mesure faite sur la machine
  candidate. À défaut, la réponse est « porteur inconnu », et la seule question qui porte une
  preuve est de demander le fil d'origine à celui qui réclame. Le coût est asymétrique :
  affirmer coûte une phrase, réfuter coûte à la lane interrogée une recherche exhaustive.
  Avant de router vers une autre machine, épuiser les autres lanes de la machine concernée, à
  commencer par les siennes — même machine ne veut pas dire même dashboard.
- **Cas mesuré :** 17/09 et 21/09, deux fois relevées par myia-po-2026 (« un fait inter-machines
  attribué à cette machine sans en-tête vérifiable ») ; le 21/09, l'attribution était fausse,
  le demandeur était une autre lane de la propre machine du coordinateur, et la question avait
  été promenée sur sept machines.

### Un secours qui « ne mord pas » : chercher d'abord ce qui interdit l'appel
<!-- src: reference_shared_circuit_breaker_gates_its_own_fallback -->
- **Quand :** un mécanisme de repli censé prendre le relais ne produit aucun effet pendant une
  panne du primaire.
- **Règle :** chercher ce qui gate l'appel (disjoncteur partagé, garde en amont) avant de
  soupçonner le secours lui-même — un secours non appelé et un secours défaillant produisent le
  même silence. Un disjoncteur unique couvrant primaire et secours les coupe ensemble au moment
  précis où le secours sert, et détruit la trace qui aurait nommé le fautif ; la forme correcte
  est un disjoncteur par fournisseur.
- **Cas mesuré :** 02/09, condensation du dashboard — le repli cloud vivait après la ligne que
  le disjoncteur court-circuitait ; une fois ouvert, plus aucun appel n'était émis, donc plus
  aucune statistique de repli : « le failover n'a pas mordu » était indécidable de l'extérieur.
  Corrigé le 22/09 (ms#1194, une PR du sous-module `jsboige-mcp-servers` : disjoncteur ouvert, seul le primaire est sauté et le palier cloud
  est tenté).

## Harmoniser les réglages de la flotte

### Une campagne de réglages harmonise par le haut, jamais en recopiant un canon non relu
<!-- src: feedback_harmonize_upward_never_copy_a_canon_unread -->
- **Quand :** créer une campagne de réglages qui alignera des sièges sur un canon.
- **Règle :** relire chaque valeur du canon contre le siège le plus récent avant toute création ;
  une campagne successeur n'est pas un travail de copie. Un outil qui compare des identifiants
  de rôle entre sièges sans canon de valeurs lit le siège le plus moderne comme le divergent et
  le ramène à la majorité — la direction est toujours « par le haut ».
- **Parole du user (24/10/2026) :** « Un peu déçu de voir réapparaitre Haiku 4.5 dans le
  sélecteur de modèle, (modèle obsolète), visiblement l'harmonisation ne se fait pas dans le bon
  sens » puis « C'est une grave erreur d'avoir fait un retour dans le passé de la sorte ».
- **Cas mesuré :** 24/10 — canon recopié clé pour clé sans lecture des valeurs, certifiant
  flotte-wide un identifiant de modèle obsolète comme « 8/8 confirmé » ; effet mesuré : perte du
  réglage du niveau de réflexion du rôle haiku (chaque requête partait avec un budget de
  réflexion sans niveau d'effort, 8 687 requêtes sur 8 687). Réparation : canari sur un siège,
  PR #4346, campagne de valeur sur la seule clé, revue par la lane propriétaire du sujet, puis
  canon de valeurs dans l'outil de comparaison.

## Faits propres à ai-01 et à la recherche sémantique

### Le port 3002 en local sur ai-01 est un relais vers le hub, pas une sortie hors hub
<!-- src: reference_ai01_localhost_3002_is_the_claudish_sidecar -->
- **Quand :** classer un siège « non proxifié » parce que son URL de base est locale, ou décréter
  qu'une consigne hub ne s'applique pas à ai-01.
- **Règle :** sur ai-01, l'URL de base locale pointe vers le conteneur `claudish-sidecar`, qui relaie vers
  le hub (le relais de modèles commun à la flotte) — ai-01 est derrière le hub, et les consignes flotte sur les rôles du hub s'y appliquent. Avant
  de classer un siège « non proxifié », identifier ce qui écoute sur le port (connexion TCP vers
  processus, conteneurs) et lire l'amont du relais ; ne jamais déduire la route de la seule adresse
  locale. Second fait du siège : le modèle de sous-agent par défaut est un modèle local au contexte servi
  inférieur à la fenêtre de compaction du siège (la plus haute de la flotte) — jusqu'à ce que le
  propriétaire de la config le change, passer explicitement un autre modèle (p. ex. haiku) à chaque
  sous-agent lancé depuis ce siège.
- **Cas mesuré :** 29/10 — consigne hub déclarée « non applicable » à ai-01 sur la foi de l'URL
  locale. Parole du user (29/10/2026) : « je pense que tu te trompes (votre seuil de condensation
  est le plus élevé de la flotte, incompatible avec vllm) ».

### Write/Edit refusés et écritures Bash bloquées : il reste un canal d'écriture
<!-- src: reference_write_channel_when_write_tools_are_denied -->
- **Quand :** un agent (typiquement une session headless de moniteur) se voit refuser Write/Edit
  et les écritures via Bash.
- **Règle :** le canal restant est `powershell -ExecutionPolicy Bypass -Command` invoqué depuis
  Bash — vu comme une seule commande, il passe le garde de composition, qui refuse par ailleurs
  certaines combinaisons de caractères (accolade avec guillemet, expansion `$`, blanc échappé
  par backslash, `#` après un saut de ligne dans un argument quoté, crochets) : encoder la
  charge utile par marqueurs substitués ensuite. Écrire par index calculé est fragile (un
  IndexOf à -1 réécrit le fichier décalé tout en affichant ok) : tester l'ancre avant, relire le
  fichier après écriture. Ce canal contourne la revue de l'outil d'écriture : garder le diff
  lisible et vérifier par relecture ; le push sans arrangement d'authentification y échoue
  (détail local non publié).
- **Cas mesuré :** 26/10, session headless sur myia-ai-01:roo-extensions — Write refusé sur le
  worktree et sur `%TEMP%`, copies et redirections bloquées ; écriture effective en une
  vingtaine de commandes.

### Les collections ws-* (index de code) ne sont écrites que par Zoo — gelées sur ai-01
<!-- src: reference_ws_collections_are_written_by_zoo_not_rsm -->
- **Quand :** la recherche de code (`codebase_search`) ne trouve pas de contenu récent, ou on
  envisage de réactiver Zoo ou un script d'harmonisation sur ai-01.
- **Règle :** le seul écrivain des collections `ws-*` est l'indexeur de code de l'extension Zoo ;
  le roo-state-manager ne fait que les lire (son leader d'indexation traite les conversations,
  pas le code). Zoo étant décommissionné sur ai-01, l'index de code d'ai-01 est gelé
  structurellement — ce n'est pas une panne. Ne jamais réactiver Zoo sur ai-01 ni y exécuter les
  scripts qui réécriraient ses réglages MCP. Avant de citer une décision du user, chercher ses
  mots exacts dans le fichier qu'on nomme : un « trouvé dans l'archive X » de mémoire n'est pas
  une citation.
- **Parole du user (29/10/2026) :** « Zoo décommissionné sur ai-01 (après 2 reboots +
  réinstallation Docker) : apport marginal ; sk-agent conservé pour harnais légers, priorité
  Claude Code et bots. Extensions VS Code désactivées (liste non inventoriée). Ne pas réactiver
  zoo ni réinstaller ses MCP par harmonisation. »
- **Cas mesuré :** avant le 31/10, le statut du dashboard créditait le leader d'indexation de la
  production des `ws-*` (faux) ; le 31/10, la décision de décommission avait d'abord été citée
  depuis le mauvais fichier d'archive, corrigée ensuite. Pour les autres sièges, la réponse est
  venue après : l'état désactivé d'ai-01 s'y est recopié par la synchronisation des réglages
  VS Code (mesuré sur deux sièges, #4025), et le user a confirmé le 08/11/2026 que cet arrêt est
  voulu pour l'instant.
- **Déjà dans le dépôt :** `.claude/commands/coordinate.md` (section Qdrant : `ws-*` vides,
  cause d'environnement) — ce texte ajoute le fait d'unique écrivain et la décision de
  décommission ; l'état décrit dans la commande est antérieur.

### Un `index` délégué sur une tâche saine est un no-op silencieux — demander `repair:"headless"`
<!-- src: reference_delegated_index_on_healthy_task_is_a_noop -->
- **Quand :** une session suiveuse demande la réindexation d'une tâche que le leader tient en
  état de succès (le leader est le processus roo-state-manager qui détient le verrou
  d'indexation ; les autres sessions, suiveuses, lui écrivent des requêtes).
- **Règle :** la requête `index` d'un suiveur réinitialise sa propre copie et écrit une requête ;
  le leader ne réinitialise que les états d'échec et de nouvelle tentative — sur une tâche en
  succès sous TTL, elle est mise en file puis sautée sans trace, alors que la réponse du suiveur
  dit `reset_indexing_state:true`. Utiliser `repair:"headless"` (contournement ponctuel qui
  préserve l'état de succès). Et jamais de second écrivain : l'indexation appartient au leader,
  les correctifs à la lane qui le possède.
- **Cas mesuré :** 01/11 — requête simple : 0 point indexé, aucune tentative, pendant 78 minutes.

### Une requête d'indexation consommée n'est pas une indexation en cours — elle peut mourir de faim
<!-- src: reference_operator_index_request_starves_behind_backlog -->
- **Quand :** remettre une tâche en file d'indexation après un déploiement à chaud du serveur (hot-swap : le
  processus du serveur est remplacé par le nouveau build) et la rapporter « en cours ».
- **Règle :** la requête consommée part en queue de file, traitée par passes de 5 tâches toutes
  les 5 minutes ; avec k éléments devant elle, elle attend environ k/5 passes, et une passe sur
  de grosses sessions prend environ 5 heures. Remettre en file reste nécessaire après un hot-swap
  (la file en mémoire est perdue), mais ne rapporter un remplacement comme « en cours » qu'après
  avoir lu l'arriéré. Le correctif de fond — mettre les identifiants consommés en tête de file
  et journaliser la consommation — appartient à la lane qui possède l'indexeur (#4352).
- **Cas mesuré :** 09/11 — requête consommée en une minute, puis aucune ligne de traitement
  jusqu'au timeout de l'observateur : la tâche n'était pas perdue, elle était affamée.

### Un outil de recherche n'est livré que par une sonde à réponse connue sur le serveur déployé
<!-- src: project_search_tools_must_work_mandate_20261025 -->
- **Quand :** rapporter « les outils de recherche fonctionnent », ou imputer leur inefficacité à
  l'embedder.
- **Règle :** exiger des assertions sur la réponse métier (la recherche rend-elle le document
  attendu ?), des contrôles négatifs et des témoins de ré-introduction du défaut ; distinguer
  les contrats unitaires, l'intégration sur service réel isolé, et la sonde lecture-seule
  post-déploiement à réponse connue. Mesurer à la sortie de l'outil, jamais sur le magasin brut ;
  qualifier la couverture et la fraîcheur du corpus avant d'attribuer une cause ou d'ajouter une
  couche de recherche. Un `try { sonde; action } catch { "not found" }` transforme toute erreur
  d'action en absence permanente : garder la sonde dans son propre try.
- **Parole du user (25/10/2026) :** « Les recherches émantique de code et de conversation
  semblent encore et toujours absolument inutiles et non fonctionnelles. Je rappelle que tu DOIS
  rendre ls outils fonctionnels ».
- **Parole du user (29/10/2026) :** « Il faut prévoir les tests unitaires exigeants qui
  permettront de valider le bon fonctionnement des outils ».
- **Cas mesuré :** 25/10 — sur le siège, 235 sessions indexées sur 1 066 ; 73 erreurs étiquetées
  « session introuvable » alors que les 73 fichiers existaient sur disque : le catch relayait
  toute erreur d'indexation en non-trouvé, une classe jamais remise en file.
- **Déjà dans le dépôt :** `docs/harness/reference/tool-start-hook.md` (contrôle positif avant
  conclusion) — ce texte ajoute le mandat user et la typologie des preuves exigées.
