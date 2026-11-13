# Leçons de terrain — mesurer et prouver

Deux familles de leçons, toutes deux tirées de vérifications réelles faites en flotte. La première traite
des instruments qui ne peuvent pas voir ce qu'on leur demande de mesurer ; la seconde, de ce qu'un chiffre
dit et de ce qu'il ne dit pas. Chaque leçon donne la situation qui doit la rappeler, la règle à appliquer,
et le cas mesuré qui l'a produite.

**Provenance :** fiches de la mémoire locale du coordinateur ai-01, sorties vers le dépôt le
2026-11-13. Chaque leçon porte en commentaire le nom de sa fiche d'origine, et a été relue contre
cette fiche par un agent distinct de son rédacteur. Les numéros de ligne cités sous « Déjà dans le
dépôt » valent à cette date : s'ils ont bougé, chercher le passage par son sujet.

**Les cinq volets :** [mesurer et prouver](field-lessons-measurement.md) ·
[relire, fermer, tester](field-lessons-review-tests.md) ·
[GitHub, gh et la CI](field-lessons-github-ci.md) ·
[dashboards, messagerie, Drive et moniteurs](field-lessons-store-dashboard.md) ·
[PowerShell, shells et Windows](field-lessons-shell-windows.md).

## Un instrument qui ne peut pas voir l'échec

### Une mesure qui rend « rien » se suspecte elle-même avant de conclure
<!-- src: reference_measurement_returning_nothing_suspects_itself -->
- **Quand :** une commande rend 0, vide, « absent » ou « refusé », et la conclusion serait que l'objet
  n'existe pas ou ne fonctionne pas.
- **Règle :** afficher d'abord la longueur de ce qui a été extrait, le répertoire courant et le chemin
  résolu : un zéro d'extraction et un zéro de résultat sont indiscernables dans la sortie finale. Un zéro
  net est plus dangereux qu'un compte bizarre — il se lit comme un fait, et on construit dessus.
- **Cas mesuré :** 25/08/2026, les assertions de six harnais comptées par `grep -c '^PASS:'` rendent zéro
  partout avec code retour 0 ; l'ancre `^` ratait les lignes indentées et quatre harnais imprimaient `OK`.
  Réel après correction : 172 assertions, 0 échec. Le 23/08, un `head -6` sur `gh auth status`
  montrait trois comptes sur six et avait fait conclure à la disparition d'un compte (#3032).
- **Déjà dans le dépôt :** `docs/harness/global-rules-detail.md:39` — y traite la troncature d'un flux de
  lecture (`| jq` qui fragmente) ; la leçon en tire la règle générale : toute mesure qui rend « rien » se
  suspecte d'abord elle-même.

### Un artefact que seul le chemin d'échec écrit ne peut jamais montrer un taux de succès
<!-- src: reference_instrument_that_can_only_see_failure -->
- **Quand :** on compte un artefact pour mesurer un taux de réussite ou d'échec.
- **Règle :** demander d'abord « le cas nominal écrit-il cet artefact ? ». Si non, le taux est une
  constante de construction, pas une mesure ; la mesure honnête vient d'une source écrite dans les deux
  cas. Un parseur qui exige une forme que le producteur n'émet jamais lit chaque succès comme une panne.
- **Cas mesuré :** 12/09/2026, les répertoires `_cond-*` ne sont écrits que par la branche de repli du
  dashboard : « 17/17 replis = 100 % », alors que les archives, écrites dans les deux cas, donnent
  27/66 = 40,9 %. Le 28/10, une sonde a rendu « erreur d'instrument » alors que l'indexation avait abouti,
  parce qu'elle exigeait un JSON que le chemin inline n'émet jamais (#4352, correctif ms#1560 et #4408).
- **Déjà dans le dépôt :** `docs/harness/reference/lessons-archive.md:16` — y demande un changement
  positif qui prouve que le composant a tourné ; la leçon ajoute l'artefact écrit par le seul chemin
  d'échec, et le parseur qui exige une forme jamais émise.

### Un coût « par élément » mesuré en lançant un processus externe se lit contre un contrôle local
<!-- src: reference_per_item_benchmark_needs_a_local_control -->
- **Quand :** un benchmark boucle un processus (`head`, `cat`, `stat`) par élément et attribue le résultat
  à une ressource distante.
- **Règle :** publier la même boucle sur disque local ; la différence est la mesure, le chiffre brut ne
  l'est pas. Sinon on attribue à la ressource distante un coût que le shell paie de toute façon.
- **Cas mesuré :** 01/09/2026, ouverture de fichiers sur DriveFS : 66 ms par fichier en boucle naïve,
  22 ms pour la même boucle en local — l'essentiel était le lancement d'un processus, pas la ressource
  distante, dont le coût marginal réel, à chaud, tombe à 7-11 ms. Une version avec `timeout` par appel mesurait
  81 ms, parce que chaque tour lançait deux processus.

### Une métrique de preuve doit être une que l'hypothèse nulle ne peut pas déplacer
<!-- src: reference_proof_metric_the_null_hypothesis_can_also_move -->
- **Quand :** on s'engage publiquement sur un nombre qui doit bouger après un correctif.
- **Règle :** demander « qu'est-ce qui, à part le correctif, peut déplacer ce nombre, et dans quel
  sens ? ». Un ratio normalisé n'est immunisé contre l'activité que si son dénominateur est un invariant
  du comportement de l'acteur, pas une sortie de ce comportement. Quand c'est possible, chercher un
  changement de signature plutôt qu'une baisse de magnitude.
- **Cas mesuré :** 06/09/2026, chantier PG #2427 : le ratio promis comme preuve a monté de 7 202:1 à 11
  209:1 pendant que le débit absolu baissait, sans aucun déploiement. La signature retenue ensuite —
  lectures de tuples par parcours d'index passant de ≈1,0 à bien plus que 1 — ne peut pas être produite
  par une flotte au repos ; la mesure de l'état d'alors, avant tout déploiement, rendait 0,9997 tuple par
  scan sur 99 387 729 scans.

### Un contrôle qui passe peut avoir échantillonné précisément le cas sain
<!-- src: reference_passing_control_may_have_sampled_the_exception -->
- **Quand :** on généralise un contrôle fait sur un seul échantillon, ou on lit un « 0 différence » comme
  un certificat.
- **Règle :** avant de généraliser, demander « si le défaut existait, mon échantillon l'aurait-il
  forcément touché ? ». Sinon le vert ne dit rien du reste. Un contrôle négatif à zéro différence
  détecte une recopie intégrale ; ce n'est pas un certificat de conformité.
- **Cas mesuré :** 24/08/2026, le contrôle `ar/fr 0/38` d'un document a été lu comme « ce document est
  propre » : la langue contrôlée était la seule à avoir un rendu distinct, les 38 pages des autres langues
  étant la recopie du français. La contre-mesure a changé de discriminant — recoupement du pool d'images,
  174 sur 174 du jeu français, une seule partagée — au lieu d'ajouter un contrôle du même type.

### Une sonde ne réfute une panne que si elle traverse réellement le composant accusé
<!-- src: reference_passing_probe_may_bypass_the_component_under_test -->
- **Quand :** on veut écrire « je ne reproduis pas », ou l'inverse, « ce composant est mort ».
- **Règle :** lire la route configurée de sa propre pile et vérifier qu'elle passe par la couche accusée.
  Dans les deux sens, c'est la route de la sonde qui détermine ce qu'elle teste, jamais son résultat : un
  succès qui contourne la couche blanchit à tort, un échec qui ne l'atteint pas incrimine à tort.
- **Cas mesuré :** 25/08/2026 (#3264), un 401 signalé en flotte : une recherche lancée depuis ai-01
  réussissait, ce qui allait blanchir la couche partagée — mais l'URL configurée du client pointait
  vers une instance locale et ne traversait jamais le reverse proxy, qui refusait bel et bien. Le miroir
  le même jour : une sonde muette sur un nom voisin visait l'adresse de sortie du poste, pas le VPS ; la
  production était debout et seul un processus de veille était mort.

### Un repli de confort retire au test sa capacité d'échouer sur la condition testée
<!-- src: reference_convenience_fallback_masks_the_condition_under_test -->
- **Quand :** un test touche une ressource d'environnement (variable, chemin, service) et passe en local.
- **Règle :** demander « quelle machine de cette flotte n'a pas ce prérequis ? ». Si la réponse est
  « aucune », l'exécution locale n'est pas une contre-épreuve : seul le runner l'est.
- **Cas mesuré :** 24/08/2026, PR ms#1032 : trois tests verts chez l'auteur et chez le relecteur, rouges en
  CI — une variable absente faisait jeter le code, mais un repli de confort lisait un fichier de
  configuration local non versionné, présent sur les six machines et sur aucun runner. Le rapport de
  l'époque annonçait « CI 658 fichiers, 0 échec » : le nombre était exact et l'étiquette fausse, c'était
  une exécution locale.

### « Introuvable » et « accès refusé » sont deux réponses différentes
<!-- src: reference_absent_and_denied_are_different_answers -->
- **Quand :** un objet doit exister — une preuve indépendante le dit — et l'outil le déclare absent.
- **Règle :** changer de famille d'instrument, pas de requête. Une requête nominative peut rendre une
  erreur de permission là où une énumération rend une omission silencieuse. Ne pas écrire « la tâche
  n'existe pas », écrire « je ne la vois pas », puis chercher pourquoi.
- **Cas mesuré :** 04/09/2026, une tâche planifiée existante a été déclarée absente par trois instruments
  — énumération, requête par nom, recherche dans le répertoire des tâches qui rendait zéro fichier sur
  un répertoire illisible ; seul `schtasks /query /tn` a rendu « Accès refusé ». Re-mesuré le 07/10 : un
  `Test-Path` rend faux dans les deux cas, le refus ne vivant que sur le flux d'erreur (#4116).

### Un nom absent n'est pas un comportement absent
<!-- src: reference_absent_symbol_name_is_not_absent_behaviour -->
- **Quand :** on conclut qu'une fonctionnalité manque parce que son symbole ne figure pas sur la branche
  principale, notamment pour décider de recycler un stash.
- **Règle :** un contrôle positif prouve que le grep voit les noms qui existent, pas qu'un nom manquant
  signifie un comportement manquant — les réécritures renomment. Chercher le comportement sous d'autres
  noms, et vérifier que le code du stash tourne dans son propre arbre avant de proposer un port.
- **Cas mesuré :** 25/09/2026 (#3827), 13 symboles à zéro occurrence classés « à livrer » : la revue par
  comportement, faite par la lane propriétaire, a trouvé 1 delta réel sur environ 45 symboles — la branche
  principale avait réécrit presque toutes les fonctions sous un autre nom, et plusieurs réécritures du
  stash ne pouvaient pas tourner dans leur propre arbre.

### Le refus d'un instrument ne prouve pas l'incapacité de mesurer
<!-- src: reference_refusal_of_one_instrument_is_not_incapacity_to_measure -->
- **Quand :** plusieurs formes de commande sont refusées par les permissions et on s'apprête à publier
  « remesure impossible ».
- **Règle :** tenter l'instrument canonique du dépôt en premier — c'est le même chemin que la sonde, la
  forme la plus souvent autorisée, et la seule qui réponde à la question « qu'a vu la sonde ». Un refus
  structurel se constate, il ne se présume pas depuis l'échec d'une autre forme.
- **Cas mesuré :** 27/10/2026, une session avait publié « remesure impossible » et requalifié un 502 en
  « rapporté, pas vérifié » après le refus de `curl` et d'`Invoke-WebRequest` ; la session suivante, le
  script de surveillance canonique du dépôt a rendu le 502 en une commande, donc vérifié. La correction de
  provenance a été postée comme un message à part entière.

### Un critère de clôture formulé sur la sortie d'un instrument mesure l'instrument, pas l'objet
<!-- src: reference_conformity_instrument_measured_a_projection_of_the_file -->
- **Quand :** on ferme une campagne de conformité sur un verdict d'outil, du type « 7/7 alignés ».
- **Règle :** comparer le périmètre de l'instrument à l'objet réel — taille, nombre de clés — sur
  au moins une machine avant de fermer, et déclarer les divergences voulues au lieu de les aplatir.
- **Cas mesuré :** 21/09/2026, #3544 fermée sur un verdict d'harmonisation à 7/7 alignés ; le snapshot lu
  faisait environ 1 200 octets quand le vrai fichier de réglages en fait 3 400 avec environ 35 clés
  feuilles, et « aligné » ne portait que sur les clés projetées. L'utilisateur a constaté les fichiers
  hétérogènes le 29/09 et l'issue a été rouverte.

### Compter des définitions n'est pas compter les outils servis
<!-- src: reference_tool_count_definitions_are_not_served_tools -->
- **Quand :** on recompte les outils d'un serveur MCP par un grep sur le fichier de définitions.
- **Règle :** lire le compte aux deux endroits qui mordent — la constante attendue, verrouillée par la CI,
  et le handshake de la session. Un instrument qui sur-compte et sous-compte à la fois ne se corrige par
  aucun facteur : le nombre qu'il rend n'a aucune relation monotone avec la grandeur voulue.
- **Cas mesuré :** 02/09/2026, après l'ajout d'un outil (#3391) : le grep rendait 27 quand la surface
  servie en comptait 16 — il ramassait des définitions désenregistrées et ratait un outil utilisé dans la
  même session. Le dépôt documentait déjà ce piège et son guide technique dit que le compte serveur fait
  foi ; la leçon est d'avoir mesuré avant de lire ce qui était déjà écrit.
- **Déjà dans le dépôt :** `docs/harness/reference/per-machine-harness-reliability-checklist.md:6` — y
  fixe la surface de référence à 17 outils, vérifiés le 02/10 par deux instruments concordants ; la leçon
  ajoute que l'instrument fautif est le grep sur les définitions, faux dans les deux sens.

### Une sonde dont le secret est deviné par heuristique doit porter un contrôle positif
<!-- src: reference_auto_discovered_credential_needs_a_positive_control -->
- **Quand :** une sonde choisit un identifiant par une règle sur le nom du champ, et toutes les cibles
  répondent la même erreur.
- **Règle :** asserter la provenance du secret avant l'appel, par une empreinte de longueur et de hachage,
  jamais par la valeur. Un contrôle positif qui échoue n'annule pas seulement la mesure : il interdit
  toute conclusion sur la cible.
- **Cas mesuré :** 06/09/2026 23:06Z, re-sonde d'un service après une panne 401 : la sonde avait pris le
  premier champ dont le nom contenait « key », et rendait 401 sur les trois cibles, contrôle positif
  compris. La bonne clé rendait 200 partout ; la panne était résolue depuis 20:01Z.

### Un zéro mesuré sur un sous-ensemble ne se rapporte pas à l'ensemble qu'on nomme
<!-- src: reference_zero_on_a_subset_does_not_report_on_the_superset -->
- **Quand :** on a mesuré une surface étroite et la phrase conclut sur un ensemble plus large —
  « nulle part », « sur aucune machine ». Le même défaut vaut pour un repli : une affirmation sur un repli
  doit nommer le chemin d'appel, car deux chemins du même composant ont des budgets et des issues
  différents.
- **Règle :** vérifier que la mesure a couvert l'ensemble nommé, ou nommer le sous-ensemble dans la phrase.
- **Cas mesuré :** 02/09/2026, un grep de « checkout » dans le fichier de règles globales rend 0 et le
  rapport annonce « nulle part dans le global ni dans les 19 règles » : il y avait 3 occurrences dans
  2 fichiers du répertoire de règles, non mesuré — diffusé deux fois avant rattrapage, sur un canal lu par
  sept machines. Le 06/09, « la condensation bascule d'elle-même sur le repli » était vrai pour un
  appel et faux pour l'autre.

### Un garde dont le chemin d'échec est cassé ne tombe pas : il ment
<!-- src: reference_broken_failure_path_lies_instead_of_failing -->
- **Quand :** on corrige un défaut situé sur le chemin d'échec d'un garde, ou on lit un garde rouge.
- **Règle :** quand deux défauts partagent un chemin, les corriger dans la même passe — corriger le premier
  seul convertit un plantage honnête en faux verdict. Le discriminant est un `output.title` vide sur le
  check-run : le garde n'a jamais atteint son propre organe de rapport.
- **Cas mesuré :** 13/09/2026, PR #3627, workflow `pr-negation-autoclose.yml` : une apostrophe de trop
  fermait la chaîne et aucune ligne de logique n'a jamais tourné ; une permission en lecture seule sur les
  pull requests produisait ensuite un 403 sur la publication du commentaire explicatif. Un auteur voyait
  rouge et lisait « violation détectée ». Mesure de population : 200 PRs mergées, 11 portent une
  référence de fermeture, soit 5,5 % — le garde s'exerce rarement.

## Ce qu'un chiffre dit, et ce qu'il ne dit pas

### Un taux agrégé n'a pas une cause mais une distribution
<!-- src: reference_aggregate_rate_has_a_distribution_not_a_cause -->
- **Quand :** un pourcentage global d'échec est sur le point de devenir une cause, ou un correctif.
- **Règle :** décomposer selon les dimensions naturelles — qui, quand — avant d'attribuer. Un contributeur
  à 100 % tous les jours est un trou de déploiement, une fenêtre contiguë est un incident, un taux étal est
  du bruit de fond. Ne jamais classer sur des volumes quand la question porte sur un taux.
- **Cas mesuré :** 01/09/2026, 7,5 % des messages absents de Postgres rapportés comme « le dual-write perd
  des messages » (#3151) : le chiffre était juste, la cause fausse. La décomposition a montré trois
  phénomènes sans rapport — une machine à 100 % sans le flag, deux machines sur une fenêtre de dix heures,
  trois machines à 1-3 % — dont le dominant n'appelait aucune ligne de code.

### Un instantané dit ce qui est maintenant, jamais ce qui va suivre
<!-- src: reference_snapshot_extrapolated_into_a_trend -->
- **Quand :** on ajoute un verbe de tendance — « croissant », « à l'arrêt », « systématique » —
  à un point unique.
- **Règle :** demander « combien de points ai-je ? ». Un seul point n'autorise aucun verbe de tendance ;
  deux donnent une direction, pas un rythme. Pour recommander une action corrective, il faut une série sur
  plusieurs mesures espacées.
- **Cas mesuré :** 01-02/09/2026, trois énoncés faux dans un seul cycle : « au moins 100 créés contre
  29 terminés » (réel : 408 et 350 sur 60 minutes), « aucune PR ne verra sa CI démarrer » (retard de
  45 minutes, CI verte 6/6), « latence croissante » (file passée de 434 à 365). Le troisième allait
  déclencher un dispatch d'urgence sur un phénomène déjà en résorption.

### Un instantané pris pendant qu'une charge s'hydrate encore n'est pas une valeur
<!-- src: reference_snapshot_of_a_load_still_in_flight_is_not_a_value -->
- **Quand :** on mesure une empreinte, un compte ou un coût à T+n pendant qu'un chargement asynchrone
  tourne encore.
- **Règle :** ne citer aucun point d'estimation pour la branche instable ; préférer un ancrage observé en
  production ; et inclure toujours une branche où rien ne charge — c'est elle qui sépare « instrument
  cassé » de « grandeur non stationnaire ».
- **Cas mesuré :** 07-08/09/2026, même protocole, même délai de 70 secondes, même métrique : la
  configuration avec préchauffage a rendu 3 217 Mo puis 2 009 Mo, le préchauffage lisant le service de
  synchronisation sans avoir fini. La branche sans chargement s'est reproduite à 2 Mo près (142 puis 144),
  ce qui a disculpé l'instrument et condamné la grandeur.

### Énoncer la limite d'une mesure ne dispense pas de la respecter en concluant
<!-- src: reference_stating_a_measurement_limit_does_not_honour_it -->
- **Quand :** la phrase qui conclut est plus large que la mesure, même si la limite est écrite juste à
  côté.
- **Règle :** une question posée à un système dont la charge varie à l'heure appelle une réponse sur une
  fenêtre, jamais sur un point ; si la mesure rejouée dans une heure pouvait dire l'inverse, elle n'est pas
  terminée et la recommandation attend. Tout adjectif qualifiant les conditions — « fraîche », « au
  repos », « isolé » — est une assertion à vérifier, jamais un décor.
- **Cas mesuré :** 29/08/2026, un point à 5 jobs en cours et 120 en file a produit la recommandation « ne
  pas ajouter de capacité », alors que le message écrivait lui-même « ma mesure est instantanée ». Une
  heure plus tard : 120 en file et 19 jobs concurrents, au plafond ; une fenêtre de dix minutes a montré la
  file drainer de 115 à 47. Le même jour, un test prédit sur des sessions dites « fraîches » ne prédisait
  rien, les sessions ayant démarré à chaud.

### Un compte de lignes ne prouve pas un backfill ; l'empan temporel tranche
<!-- src: reference_row_span_not_count_proves_backfill -->
- **Quand :** on veut savoir si un backfill a tourné, ou si une classe de données est encore alimentée.
- **Règle :** demander « depuis quand ? » et lire le minimum d'horodatage. Un empan qui s'arrête pile à
  l'heure du backfill signifie qu'il n'y a jamais eu d'écriture sur ce chemin. Et un store partiellement
  rempli est pire qu'un store vide : le vide se remarque, le partiel se croit.
- **Cas mesuré :** 22-23/08/2026 (#3230), 882 lignes en base pour environ 21 800 fichiers : ambigu comme
  compte, tranché par un minimum d'horodatage égal à la mise en service du dual-write, donc un backfill
  jamais exécuté. Après backfill, 1 287 messages d'un producteur hors chemin ont fait dire « la base a
  cette classe » alors que leur empan s'arrête à l'instant du backfill.

### Quand un changement retire des éléments, il faut échantillonner ce qui a été retiré
<!-- src: reference_sample_what_a_filter_removed_not_the_aggregate -->
- **Quand :** un filtre, une exclusion ou un `skip` fait baisser un compte et la suite de tests passe.
- **Règle :** échantillonner les éléments supprimés un par un, et écrire un contrôle positif d'un cas qui
  doit survivre au filtre ; une garde `> 0` contre une suppression en masse ne garde rien. Devant un
  compte nul à l'extrémité d'une distribution, poser les deux lectures — rien n'est arrivé jusque-là, ou
  quelque chose a nettoyé jusque-là — et trancher sur l'état du mécanisme, jamais sur l'agrégat.
- **Cas mesuré :** 29/08/2026, un masque à deux règles faisait passer un corpus de 210 à 157 éléments,
  plus propre que les 183 de la variante à liens seuls, avec les 104 tests verts. L'échantillon de
  12 éléments supprimés a montré une divergence mesurée entre deux bibliothèques de calcul, exactement
  ce que le scanner existe pour trouver. Livré avec les liens seuls et deux contrôles positifs.

### Un compteur d'alertes émis à chaque tick mesure une durée, pas un nombre d'incidents
<!-- src: reference_alert_count_is_not_an_incident_count -->
- **Quand :** un compteur est incrémenté à chaque tick tant qu'une condition dure.
- **Règle :** grouper les alertes par motif. Si un motif domine et que son libellé décrit un état plutôt
  qu'une transition, le compteur est un chronomètre déguisé : il multiplie la gravité par le rapport entre
  la durée de l'état et la période du tick. Compter les transitions.
- **Cas mesuré :** 03/09/2026, 40 alertes dans l'heure lues comme un incident actif aux réparations qui ne
  tiennent pas : un seul incident, une réparation ratée puis une réussie, et huit alertes produites
  mécaniquement par un cooldown de 15 minutes sur un tick de 2 minutes. Sur la journée, 32 des 51 alertes
  portaient le même motif d'attente, celui qui n'apporte aucune information nouvelle (#3395).

### Un agrégat qui nomme son ensemble bloquant le nomme à son heure de calcul
<!-- src: reference_named_blocking_set_read_before_its_members_finished -->
- **Quand :** on lit une liste de gates bloquants pour savoir quels rouges comptent.
- **Règle :** vérifier que l'instantané de l'agrégat est postérieur à tous ses membres. Un nom absent d'un
  ensemble périmé ne prouve ni qu'il est non bloquant ni qu'il est vert, et un agrégat ne se recalcule pas
  parce qu'un de ses membres a changé.
- **Cas mesuré :** 13/09/2026, un agrégat « PR gate » ne nommait qu'un rouge ; trois autres rouges, dont un
  analyseur de code, ont été déclarés non bloquants dans une arbitration publique. Le même agrégat
  relancé a nommé cet analyseur, qui avait terminé sept secondes avant le calcul de la liste.

### Quand mon chiffre est l'aberrant d'un tableau de pairs, je suspecte d'abord ma méthode
<!-- src: reference_my_outlier_number_was_my_method_not_my_machine -->
- **Quand :** on publie un nombre qui tranche avec ceux des autres machines, ou on compte des processus.
- **Règle :** vérifier son propre instrument avant de faire de l'objet un cas à part, et faire voyager la
  définition avec le nombre. Pour compter des processus, filtrer sur ce qui identifie le rôle — ligne de
  commande, chemin du script — jamais sur le seul nom d'image.
- **Cas mesuré :** 06/09/2026, « 64 instances » publiées pour ai-01 contre 25 chez la deuxième machine : le
  compte brut de processus, là où les autres publiaient une ventilation — 32 hôtes plus 32 lanceurs, soit
  1,3 fois la deuxième et non 2,6. Trois lanes ont repris le chiffre tel quel. Le même jour, la même erreur
  refaite sur un compte de processus portant une clé révoquée : 66 au lieu de 33.

### Le qualificatif de portée posé puis jeté dans la même phrase laisse un universel faux
<!-- src: reference_scoped_qualifier_discarded_in_the_same_sentence -->
- **Quand :** une phrase contient la version bornée ET la version universelle.
- **Règle :** quand la version bornée est déjà écrite, ne rien ajouter — « absent sur les 4 machines
  mesurées » se suffit. Un universel se paie au prix d'un recensement complet, jamais d'un échantillon.
  Quand une contradiction arrive, contre-vérifier sa propre mesure avec un contrôle positif avant de la
  maintenir.
- **Cas mesuré :** 08/09/2026, « le cap est absent partout où on a regardé — le levier n'existe sur aucune
  machine de la flotte » : la première moitié était vraie sur quatre machines, la seconde falsifiée trois
  minutes plus tard sur une cinquième. Une re-sonde sur quatre ruches du registre avec contrôle positif a
  confirmé que l'absence sur ai-01 était réelle.

### Un verdict « propre » mesure souvent l'absence de résidus, pas la présence de la cible
<!-- src: reference_clean_verdict_measures_absence_not_the_target -->
- **Quand :** on compte des lignes « PROPRE » dans un tableau de flotte comme un progrès.
- **Règle :** nommer la propriété que chaque mot de verdict mesure et la comparer à la cible que l'issue
  porte maintenant, après la dernière décision utilisateur — pas le corps d'origine. Demander une colonne
  « à la cible : oui/non » séparée de « propre ».
- **Cas mesuré :** 23/09/2026 (#1171), trois lignes « PROPRE » sur l'autologon et la reprise des
  conteneurs : deux machines n'avaient pas l'autologon activé, donc n'étaient pas à la cible, et la seule
  machine à la cible aurait été lue comme différente plutôt que comme faite.

### Une confiance auto-déclarée par un sous-agent ne mesure rien
<!-- src: reference_self_reported_confidence_does_not_discriminate -->
- **Quand :** on veut filtrer des productions de sous-agents sur un champ de confiance.
- **Règle :** toute propriété du dispositif — entrée tronquée, outil indisponible, budget épuisé — se
  marque côté orchestrateur, qui la connaît à l'émission. Ne demander au sous-agent que ce qu'il est
  seul à savoir : ce qu'il a lu, ce qu'il a conclu. Le champ reste lisible qualitativement, jamais
  utilisable en sélection automatique.
- **Cas mesuré :** 21/09/2026, audit de 147 issues : 27 issues ont été envoyées amputées de leurs
  commentaires, avec la consigne explicite de ne pas coter VERIFIE ; 26 sur 27 l'ont fait quand même. Le
  champ rendait 140 VERIFIE sur 147, un taux qui ressemble à de la rigueur et ne sépare pas les issues lues
  en entier de celles lues à trous.

### Un objet cassé imite une contention générale ; un frère sous le même parent les sépare
<!-- src: reference_sibling_measurement_separates_broken_object_from_systemic_cause -->
- **Quand :** plusieurs accès d'entrée-sortie bloquent et on s'apprête à accuser le disque, le réseau ou la
  synchronisation.
- **Règle :** mesurer un voisin de même nature sous le même parent, même seconde, avec un délai maximal par
  ligne ; quatre lignes de shell invalident ou confirment toute une classe d'hypothèses. Un délai maximal
  qui ne tue pas le processus indique une attente non interruptible, pas de la lenteur.
- **Cas mesuré :** 21/08/2026, trois commandes bloquées plus de 120 secondes sur le répertoire partagé,
  attribuées à une contention générale de la synchronisation cloud avant même d'être mesurées. Trois
  sous-répertoires frères répondaient en 187 à 190 ms, le quatrième expirait : le blocage était
  confiné à un répertoire. Attribution retirée publiquement (#3205).

### Un interblocage se présente comme de la lenteur
<!-- src: reference_deadlock_presents_as_latency -->
- **Quand :** un travail expire systématiquement et toutes les hypothèses portent sur la vitesse.
- **Règle :** la première question n'est pas « qu'est-ce qui est lent ? » mais « à quel moment exact le
  flux s'arrête-t-il, et qu'est-ce qui venait juste avant ? ». Un arrêt à 0,5 % du budget n'est pas un
  problème de budget, quoi qu'en dise le message d'erreur.
- **Cas mesuré :** 29/08/2026, cinq jours d'expirations sur la flotte : mort à T+9 secondes d'un budget de
  1 800, succès en 15 secondes pendant la panne, et défaut reproduit sur une autre machine — trois
  hypothèses de vitesse refutées. La forme du silence a tranché : dernier signe de vie figé à T+9 puis
  rien pendant 1 791 secondes, l'agent attendant une réponse à une demande de permission à laquelle le client
  ne répondait jamais.

### Un timeout client transforme un régime de latence en panne imaginaire et nomme une cause fausse
<!-- src: reference_client_timeout_fabricates_an_outage_and_names_a_false_cause -->
- **Quand :** un rapport de flotte dit « backend en panne, cause réseau » parce qu'un client a abandonné.
- **Règle :** le nom de l'erreur est produit par la bibliothèque cliente, pas par une mesure de la couche
  accusée. Re-sonder avec un délai plus long que celui de n'importe quel client, et lire un compteur de
  succès côté serveur ; deux points de mesure valent mieux qu'un pour distinguer un régime d'un pic.
- **Cas mesuré :** 25/08/2026, un backend d'embeddings rapporté « en panne, cause réseau » : santé en
  4 ms, modèle chargé, 9,8 heures de disponibilité, plus de 20 000 succès au compteur, et une réponse en
  45,8 puis 43,6 secondes. Le réseau était à 3-5 ms et la latence de 44 secondes dépassait le seuil
  d'abandon du client, fixé à environ 33 secondes.

### Un budget de sonde plus court que la latence réelle fabrique une panne
<!-- src: reference_probe_timeout_below_latency_manufactures_false_down -->
- **Quand :** une sonde de surveillance rend des échecs alternés, ou une alerte demande un redémarrage.
- **Règle :** mesurer la latence de l'endpoint joignable et la comparer au budget avant de conclure « en
  panne » ; un service qui répond lentement est vivant, et un redémarrage par-dessus est un geste
  destructif. Le signal utile a trois états — lent, dégradé, en échec — pas un booléen.
- **Cas mesuré :** 26/10/2026, une sonde d'embeddings à 15 secondes face à un service répondant en 26 à
  31 secondes : huit fausses alertes en une journée, le backend étant sain et répondant en 32 ms en direct.
  Les journaux montrent les échecs alterner sur le seul passage de la latence sous le budget. Le correctif
  est mergé et son contrôle positif rend « lent » là où l'ancienne version rendait « en panne » (#4366).

### Un timeout systématique accuse parfois le budget, pas le fournisseur
<!-- src: reference_budget_smaller_than_the_task_it_executes -->
- **Quand :** un harnais expire à 100 % et la tentation est d'incriminer l'API.
- **Règle :** chercher où la tâche déclare elle-même le temps qu'elle veut, et comparer au budget accordé.
  Quand plusieurs couches portent un timeout — enveloppe, driver, spécification de la tâche — les lire
  toutes et repérer l'intruse ; le correctif est alors le nombre que la tâche déclarait déjà. Une
  étiquette de diagnostic qui ne transmet que son nom, jamais la valeur mesurée, envoie des valeurs
  très différentes sous le même mot.
- **Cas mesuré :** 29/08/2026, trois nombres du même dépôt se contredisaient : la tâche demandait
  30 minutes, le driver accordait 900 secondes et la tâche planifiée 55 minutes. Le nombre contraignant
  valait la moitié de la demande ; l'agent mourait en phase de contexte, avant de produire, pour
  0,135 dollar par exécution. Le libellé « API stall pattern » couvrait aussi bien 61 secondes que
  800 secondes de silence.
