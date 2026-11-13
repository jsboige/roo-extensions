# Leçons de terrain — dashboards, messagerie RooSync, Drive et moniteurs

Le « dashboard » est un tableau Markdown partagé, lu par chaque agent de la flotte à travers un outil
MCP. « RooSync » est la boîte aux lettres inter-machines. Les deux sont stockés comme fichiers sur un
Google Drive partagé, répliqué dans une base PostgreSQL (« PG »).

Ces leçons portent sur ce magasin commun et sur les moniteurs qui réveillent des agents. Elles se lisent
avant de conclure qu'un message n'a pas de réponse, qu'un dashboard est perdu ou qu'une alerte appelle
une correction.

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

**Mots propres à ce volet :** l'*intercom* est le fil de messages d'un dashboard, le *statut* son bloc de
tête. La *condensation* se déclenche quand un dashboard approche de sa taille limite : des appels à un
modèle résument et archivent les messages anciens, une *jambe* (ou *passe*) par produit — le résumé des
messages archivés et le nouveau statut. Le *primaire* est le modèle auto-hébergé de la flotte, le *cloud*
un modèle distant ; le *plancher* est la troncature mécanique appliquée quand le statut rendu dépasse
encore le plafond. Un *fork* est la copie de conflit que le client Drive crée avec un suffixe « (1) », un
*jumeau* le dossier en double qui en résulte. Le *marqueur* est l'indicateur, relu par chaque processus à
son démarrage, qui dit si la base peut servir de magasin primaire ; tant qu'il vaut « inconnu »,
l'écriture part vers le Drive. Le *gel d'inventaire* est un critère de la bascule vers la base : 24 h sans
aucune écriture du fichier d'inventaire sur le Drive (le *miroir*). `inbox deep:true` lit toute la boîte
aux lettres (le *pool*) au lieu de la tranche récente ; un *gitlink* est le commit du sous-module épinglé
par le dépôt parent.

## Le magasin partagé (dashboards, messagerie, Drive)

### Un message re-posté avec le même identifiant après archivage reste invisible pour les lecteurs PG
<!-- src: reference_archived_message_id_repost_is_pg_invisible_false_fork -->
- **Quand :** une alerte de fork apparaît sur un re-post portant un identifiant stable, par exemple un
  identifiant quotidien dérivé de l'incident.
- **Règle :** le contrôle d'idempotence ne regardait que l'intercom vivant ; l'écriture en base ne remet
  jamais à zéro la date d'archivage, et le lecteur ne rend que les lignes non archivées. Chercher
  l'identifiant dans l'ensemble archivé avant de suspecter le magasin. Une alerte dont la ligne a perdu
  ses champs fait suspecter le journaliseur avant le producteur.
- **Cas mesuré :** 04/11/2026, ai-01 (#4434), correctif ms#1651 : une copie archivée par la condensation,
  re-postée avec le même identifiant, atterrit dans le fichier du Drive et reste archivée en base ; les
  lecteurs servis par PG ne la voient jamais et l'alerte de fork se déclenche à chaque re-post. L'alerte
  avait perdu ses champs parce que le deuxième argument du journaliseur, un objet, était converti en
  `[object Object]` sur vingt appels répartis dans quatre fichiers.
- **Déjà dans le dépôt :** `docs/harness/reference/intercom-v3-mentions.md` — le format `messageId` v3 y
  est documenté ; la déduplication des identifiants archivés n'y figure pas.

### Une route n'est pas un secours : changer le défaut oblige à relire ce qui en déduit un échec
<!-- src: reference_status_leg_primary_never_finishes_route_cloud_first -->
- **Quand :** une jambe de la condensation ne réussit jamais sur le modèle primaire, et on la route vers
  le cloud par défaut.
- **Règle :** mesurer avant d'accuser le serveur, qui peut répondre en 3 ms alors que le coût est
  l'admission et le décodage. En changeant le défaut, exclure la nouvelle route de tout indicateur de
  repli, nommer la route dans l'avis et l'inscrire dans l'archive : une route n'est pas un sauvetage.
- **Cas mesuré :** 02-04/11/2026, ai-01 : la jambe « statut » sur le primaire a fait 52 appels, 0 réussi
  et 38 timeouts, quand la jambe « résumé » faisait 10 sur 38 ; un statut de 4 à 6 K tokens demande
  100 à 300 secondes de décodage là où l'échéance n'en laissait que 90. Correctif ms#1652, statut cloud
  d'abord.

### Un plancher de troncature qui coupe par le haut ampute les sections de tête, et la perte est permanente
<!-- src: reference_status_floor_dropped_head_sections_and_numeric_target_backfired -->
- **Quand :** un statut condensé revient sans son résumé, sans l'état des systèmes ou sans les décisions
  actées.
- **Règle :** garder un plancher par sections plutôt qu'une coupe par le haut : chaque titre et sa
  dernière ligne conservés, les blocages entiers, la plus grosse section rendant ses lignes de corps en
  commençant par la plus haute. La passe suivante hérite de ce que le plancher a laissé.
- **Cas mesuré :** 04/11/2026, ai-01 : sept passes de statut sur sept finissaient sur le plancher ; le
  mécanisme génère environ 19,5 Ko, le cloud ne descend qu'à 16-18,8 Ko pour un plafond de 15 Ko, et
  l'ancien plancher gardait tête, blocages et queue — Résumé, État des systèmes et Décisions actées
  disparaissaient. Correctif ms#1649 (#4434) ; rejeu réel : 9 titres sur 9, contre 3 sections perdues à
  chaque fois auparavant.
- **Essayé et rejeté :** donner au prompt cloud une cible chiffrée (caractères, mots, pourcentage de
  coupe, « garde chaque titre ») rend une sortie plus grosse, 17,5-17,9 Ko contre 15,9-16,9 Ko sans,
  trois fois sur trois et sans chevauchement. Ne pas retenter sans nouvelle mesure.
- **Déjà dans le dépôt :** `docs/harness/reports/condensation-status-quality-2026-10-29.md:11` — le
  rapport y documente la troncature déterministe par le haut ; cette leçon ajoute que la cible chiffrée
  dans le prompt se retourne contre le but.

### Un lecteur de l'intercom vivant ne distingue pas « jamais répondu » de « répondu puis archivé »
<!-- src: reference_condensed_reply_reads_as_unanswered -->
- **Quand :** une lane s'apprête à relayer ou à escalader un « sans réponse » qui date de plus d'une
  condensation.
- **Règle :** chercher dans les fichiers d'archive nommés (`dashboards/archive/<clé>-<date>*.md`), fichier
  par fichier — jamais une recherche récursive sur le magasin pendant une tempête d'accès au DriveFS. La
  recherche textuelle du service ne rend rien sur ces archives, qui n'y sont pas indexées.
- **Cas mesuré :** 21-23/09/2026 : une lane a porté une question « sans réponse » pendant quatre cycles
  de douze heures et l'a fait escalader. Les réponses existaient, datées du 21/09 à 17:04:20Z, 17:04:58Z
  et 17:32Z ; la condensation les avait sorties de l'intercom vivant, elles étaient toujours dans
  `dashboards/archive/global-2026-09-21T21-41-16.md`.

### Un dashboard qui disparaît du magasin est le plus souvent dans la corbeille du Drive, pour 30 jours
<!-- src: reference_vanished_dashboard_is_in_drive_trash_for_30_days -->
- **Quand :** une lane rapporte un dashboard « introuvable » ou « disparu ».
- **Règle :** interroger la corbeille du Drive avant de déclarer le journal perdu, puis télécharger et
  préserver la copie, en deux emplacements avec un manifeste. Le tri se fait sur les dates : création
  très antérieure à la modification signale un fichier écrit sur place puis jeté par une synchronisation,
  donc un candidat à la perte ; création proche de la modification signale une version supplantée par
  une écriture atomique, environ une centaine par jour, toutes normales.
- **Cas mesuré :** 26/09/2026 : un dashboard disparaît entre deux appends ; l'original, créé le 06/04,
  était intact dans la corbeille avec ses 20 messages jusqu'à 10:48:51Z. Deux fenêtres de requête
  successives ont trouvé 7 dashboards de longue vie, toutes préservées. Le 27/09, l'utilisateur a vidé la
  corbeille : les copies jetées avant cette date sont perdues, et la règle des 30 jours ne vaut plus que
  pour ce qui est jeté ensuite.

### Plusieurs fichiers Drive au nom d'un dashboard sont le plus souvent le churn d'écriture atomique
<!-- src: reference_drive_homonym_dashboards_are_atomic_write_churn -->
- **Quand :** une lane signale un dashboard « éclaté » en plusieurs fichiers homonymes et demande une
  fusion.
- **Règle :** lister les homonymes avec leur statut de corbeille, puis comparer les en-têtes de messages
  de la copie non canonique à l'union du canonique et des archives de condensation du jour ; ne fusionner
  que ce qui manque vraiment, et ne jamais supprimer la copie périmée. Ne pas lancer la fusion depuis une
  machine dont le lecteur Drive est en retard : elle peut elle-même écrire un fichier périmé et re-forker.
- **Cas mesuré :** 27/09/2026 : sur quatre fichiers homonymes signalés, deux étaient déjà à la corbeille
  avec des fichiers temporaires, parce que l'écriture atomique écrit un temporaire puis renomme par
  dessus, ce qui rend un nouvel identifiant et jette l'ancien. Des deux fichiers vivants, le plus ancien
  était un sous-ensemble périmé : 21 messages sur 21 présents, 6 dans le canonique et 15 dans l'archive
  de condensation — une comparaison au seul canonique vivant montrait 15 messages « manquants » qui
  étaient simplement condensés.

### Une rétention qui supprime à travers Drive ne libère rien : la corbeille compte encore
<!-- src: reference_retention_deleting_through_g_drive_frees_no_quota -->
- **Quand :** un script de rétention annonce une suppression et on attend une baisse d'espace, ou une
  alerte de quota Drive arrive.
- **Règle :** interroger l'API du Drive pour les gros fichiers récents et pour les fichiers à la corbeille
  avant d'accuser le lecteur ou un artefact ; la libération réelle est une suppression définitive par
  l'API, fichier par fichier — sinon le fichier reste 30 jours dans la corbeille et compte encore. Pour
  les sauvegardes, la suppression définitive est une décision de l'utilisateur, et le changement du script
  revient à la lane qui les produit. Ne jamais vider la corbeille en bloc : elle contient aussi les copies
  de récupération des dashboards.
- **Cas mesuré :** 26/09/2026 : la sauvegarde nocturne de l'index sémantique dépose environ 30,6 GiB par
  nuit et sa suppression passe par le lecteur Drive ; 19 sauvegardes à la corbeille représentaient
  534 GiB et 13 vivantes 340 GiB, soit 30,6 GiB de plus par jour. Remesure du 10/11 : 9 sauvegardes à la
  corbeille, 542,2 GB (#3893). Correction du même jour : sur ai-01, la taille et l'espace libre affichés par le
  lecteur sont un artefact de volume virtuel, seuls les chiffres de l'API sont des faits de quota.

### Un dossier Drive partagé depuis un autre compte apparaît comme un fichier `.lnk`
<!-- src: reference_drive_shortcut_from_another_account_is_a_lnk_file -->
- **Quand :** un listing d'un dossier DriveFS qui peut contenir des partages inter-comptes fait lire une
  machine comme absente.
- **Règle :** énumérer aussi les fichiers `.lnk` et résoudre chacun avec l'objet COM `WScript.Shell`
  (vérifié sous PowerShell 5.1), au lieu de conclure à une absence depuis un listing de dossiers ou un
  glob `*/fichier`.
- **Cas mesuré :** 25/09/2026, ai-01 : un dossier partagé depuis le compte d'une autre machine et ajouté
  en raccourci apparaît comme `myia-web1.lnk`, un fichier de 4 096 octets, et non comme un dossier ; son
  contenu réel vit sous la cible du raccourci et se lit très bien. Aucun fichier ne manquait : l'alarme
  venait de l'instrument.

### Juste après une republication de build, une lecture partielle de la boîte n'est pas une mesure
<!-- src: reference_inbox_deep_after_hot_swap_can_return_the_slice -->
- **Quand :** un `inbox deep:true` répond « tranche récente, pool complet non scanné » après un
  redémarrage ou un hot-swap.
- **Règle :** répéter l'appel `deep:true` jusqu'à ce que le suffixe de portée disparaisse avant de
  déclarer « zéro non lu ». Une passe complète a un budget de 60 secondes, et une passe tronquée est
  écartée en gardant le cache existant — qui est désormais la tranche : la suivante repart de zéro.
- **Cas mesuré :** 04/10/2026, ai-01 : juste après la republication du build au gitlink `2284ad7d`, un
  premier `deep:true` a pris 95 secondes et rendu 3 messages ; le second a pris 59,6 secondes et rendu
  802 messages, zéro non lu.

### L'état de lecture est par lecteur : un `mark_read` de la lane ne marque rien pour le worker
<!-- src: reference_worker_and_lane_readers_keep_separate_read_states -->
- **Quand :** on veut conclure qu'un message ou une tâche adressée à une machine a été traité.
- **Règle :** lire la boîte comme le consommateur la lit, avec le CLI d'inbox du service filtré sur les
  tâches non lues ; la vue de son propre inbox ne prouve rien pour le worker. Rien ne marque une tâche
  servie comme consommée sur le canal PG, donc elle repart à chaque cycle ; le palliatif pour un message
  périmé est `roosync_messages archive`, qui le retire pour tous les lecteurs.
- **Cas mesuré :** 25/10/2026 : une demande adressée à une machine a été servie six fois en 30 h. Dans
  l'inbox MCP elle apparaissait lue ; par le CLI, tel que le worker la lit, elle apparaissait non lue.

### Un identifiant de message sans date n'est pas du stock ancien : c'est une clé d'idempotence
<!-- src: reference_undated_message_id_is_live_idempotency_traffic -->
- **Quand :** on veut classer ou fenêtrer des messages d'après leur nom, ou placer les identifiants non
  datés en dernier au démarrage à froid.
- **Règle :** mesurer les dates de création de ces identifiants dans la base avant de les vieillir. Un
  nom prouve une date quand il en porte une ; quand il n'en porte pas, il ne prouve rien dans un sens ni
  dans l'autre.
- **Cas mesuré :** 08/10/2026 à 10:58Z sur la base centrale : 1 756 identifiants non datés, dont 1 753
  créés dans les 30 derniers jours et 616 dans les 7 derniers, le plus récent à 10:55:41Z. Ils viennent
  de la clé d'idempotence de l'envoi (#1170), persistée telle quelle comme identifiant et comme nom de
  fichier ; la proposition de les classer en dernier (#4131) a été rejetée par la mesure.

### Une écriture sur le Drive depuis un hôte démarré dans la même seconde est la barrière du marqueur
<!-- src: reference_cold_host_first_write_lands_on_g_drive -->
- **Quand :** une écriture sur le lecteur Drive apparaît là où la base devrait servir, dans les secondes
  qui suivent un démarrage de serveur.
- **Règle :** distinguer les deux cas dans le journal : un repli légitime est précédé d'une ligne
  d'échec d'insertion ou de base impossible, alors que le défaut de la barrière froide n'en a aucune et
  porte un démarrage de serveur dans la même seconde. Les suffixes de fork du Drive sont en plus numérotés
  par client : un verdict de jumeau lu par nom de dossier sur un siège n'est pas une mesure de la flotte.
- **Cas mesuré :** 03/11/2026, ai-01 : deux envois sur les 109 du jour ont journalisé une sauvegarde sur
  le lecteur Drive ; les deux hôtes avaient démarré au même moment, une seconde avant l'envoi, et l'état
  du marqueur rend « inconnu » sur un processus neuf, ce qui ferme toutes les barrières primaires.
  Correctif ms#1643. Le même jour, un fichier d'inventaire de 0 octet avec une date fraîche était un
  artefact du lecteur, pas un écrivain actif.

### Un déploiement qui redémarre tous les processus d'un hôte ensemble relève le gel d'inventaire
<!-- src: reference_deploy_herd_resets_phase_d_inventory_freeze -->
- **Quand :** une écriture sur le Drive apparaît dans les minutes qui suivent un rebuild, ou on cherche
  pourquoi un gel d'inventaire de 24 h ne tient pas.
- **Règle :** lire le journal de l'hôte pour une ligne d'échec de sauvegarde en base juste après son
  rebuild, avant de conclure qu'une ancienne version écrit encore. Le correctif ms#1629 rafraîchit une
  fois par hôte et par jour UTC, avec une réservation atomique et un délai hors de la fenêtre de hot-swap ;
  tant qu'il n'est pas déployé sur un siège, le déploiement de ce siège peut à lui seul relever le gel.
- **Cas mesuré :** 02/11/2026, ai-01 : après le rebuild `3729b7db` à 12:09:55Z, deux lignes d'erreur à
  12:10:40Z, une sauvegarde en base impossible et une relecture de registre expirée ; à la même seconde,
  le miroir d'inventaire était réécrit sur le lecteur Drive. Environ 20 processus redémarrés ensemble,
  un upsert en expiration, et le gel de 24 h repartait.

### Nettoyer une collision de dossiers partagés exige de prouver la préservation avant de retirer
<!-- src: reference-shared-state-collision-repair -->
- **Quand :** des copies de conflit suffixées `(1)` ou `(2)` apparaissent dans le magasin partagé et on
  veut faire le ménage.
- **Règle :** contenir avant d'archiver : extraire les en-têtes des deux fichiers et vérifier que chaque
  entrée du fork existe dans le principal ; si une entrée manque, ne pas archiver (la divergence peut être
  un message qui n'existe que là) ; fusionner un registre de machines par union, jamais par écrasement ;
  rapatrier les inventaires échoués, ne jamais les jeter ; ne supprimer un dossier de conflit qu'après
  zéro fichier récursivement, et mesurer son absence. Écrire un `MANIFEST.md` daté dans l'archive : c'est
  la preuve de préservation. L'archive vit hors des dossiers énumérés par le service, et le ménage ne se
  refait pas : il se fait une fois, quand les dates de modification des sièges sont gelées depuis 24 h.
- **Cas mesuré :** 29/10/2026 : 9 artefacts, dont 3 registres de machines portant chacun un sous-ensemble
  différent ; 11 entrées de fork sur 11 déjà présentes dans le principal. Le 30/10, les 3 collisions
  retirées la veille à 22:31Z sont revenues, `inventories (1)` 13 minutes plus tard. Le 06/11, la cause
  de fond : `Synchronisation` existe deux fois à la racine du Drive, et regarder dans le dossier ne
  montre jamais le doublon.

### Poster pour une autre machine est refusé par le tampon d'auteur ; publier en global avec un cross-post
<!-- src: reference_dashboard_post_across_machines_and_stateless_proxy -->
- **Quand :** une lane veut répondre sur le dashboard d'une autre machine, ou croit le canal mort parce
  que son client exige un en-tête de session.
- **Règle :** publier `type: "global"` avec un `crossPost` vers le workspace de la destinataire : le
  cross-post écrit bien chez elle, seul le tampon principal est contraint. Le proxy canonique est sans
  état et ne rend pas d'en-tête de session, donc un client qui l'exige conclut à tort que la chaîne est
  morte ; la preuve de vie est `result` avec `serverInfo`.
- **Cas mesuré :** 26/10/2026, ai-01 : un append pour une autre machine est refusé, la machine n'étant
  pas assertable sur ce processus (#4135) ; la raison est bonne, un tampon périmé fabriquerait une
  machine « en ligne » fantôme dans la santé de la flotte. Le même jour, deux faux négatifs : refuser de
  publier à cause du tampon, et déclarer la chaîne morte parce qu'un en-tête optionnel manquait.
- **Déjà dans le dépôt :** `docs/harness/global-rules-detail.md:360-365` — le cross-post y est décrit comme
  point de rendez-vous d'escalade ; cette leçon ajoute que le tampon d'auteur refuse de poster pour une
  autre machine, et le cas du proxy sans état.

## Moniteurs et alertes qui réveillent un agent

### Un moniteur qui lance un agent à chaque échec multiplie les agents, même quand le texte est corrigé
<!-- src: reference_alert_multiplier_is_the_spawn_not_the_wording -->
- **Quand :** une alerte de monitoring est fausse ou trop fréquente, et on s'apprête à corriger son
  texte.
- **Règle :** un identifiant de message stable dérivé de l'incident rend le re-post sans effet, mais ne
  coupe pas le lancement, car le script lance l'agent avant de poster. Couper le multiplicateur demande
  un post direct par le CLI, sans passer par un agent. Ne pas s'appuyer sur un tag : le tag d'alerte est
  informatif et aucun filtre de routage ne le lit.
- **Cas mesuré :** 27/10/2026, incident des embeddings : 35 lignes d'échec ont produit jusqu'à 35 agents
  pour un seul incident ; la correction de formulation, mergée le 27/10 (#4381), a rendu les alertes
  justes sans faire baisser le nombre d'agents. Piège de vérification : l'agent lancé ne voit que son
  prompt, et c'est ce prompt comparé au script sur `main` qui établit la version réellement déployée.

### Une alerte de monitoring qui appelle une IA ne produit pas qu'un faux positif : elle produit un concurrent
<!-- src: reference_false_alert_spawns_an_agent -->
- **Quand :** un script de surveillance teste un service avec un budget de temps et lance un agent en cas
  d'échec.
- **Règle :** calibrer le seuil sur la latence réelle mesurée, pas sur un délai de confort, et
  distinguer trois états : lent, dégradé quand le premier essai expire mais qu'une confirmation à budget
  plus long répond, mort quand les deux expirent. Un timeout ne vaut pas « redémarre le service ». Le
  remède n'est pas de dire à l'agent de se méfier, c'est de ne pas produire l'alerte.
- **Cas mesuré :** 26/10/2026, ai-01 : un budget de 15 secondes pour un service qui répond en 31 à 34
  secondes, et 10 échecs sur 14 tirages ; les lignes hors horaires planifiés étaient des sessions filles
  qui relançaient le script, soit environ 10 sessions IA créées par heure, plusieurs modifiant le même
  fichier en parallèle. Sur une machine qui porte cette tâche, la liste des sessions vivantes n'est pas
  un indicateur d'activité humaine : c'est un compteur d'alertes.
