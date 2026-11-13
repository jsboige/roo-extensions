# Sessions cloud hors flotte — protocole de contribution

**Version :** 1.0.0 · **MAJ :** 2026-11-13
**Portée :** `jsboige/roo-extensions` et son sous-module `jsboige/jsboige-mcp-servers`.

Une **session hors flotte** est une session d'agent qui ne tourne sur aucune machine `myia-*`.
Elle est hébergée chez un fournisseur cloud, quel qu'il soit, et le mainteneur lui confie un
chantier. Ce document dit comment ce chantier se cadre, se verrouille, se relit et se termine,
et ce que fait la flotte quand aucune session cloud n'est disponible.

Le protocole ne dépend ni du fournisseur ni du modèle. Il dépend de deux faits : la session
**ne voit pas** les outils de coordination de la flotte, et elle **écrit sur GitHub sous
l'identité du mainteneur**.

**D'où viennent les mesures.** Deux chantiers hors flotte menés en novembre 2026 sur le dépôt
voisin `jsboige/CoursIA` (issues CoursIA#25670 et CoursIA#26070, et le body d'une PR qui en est
sortie, CoursIA#26097), lus en lecture seule le 2026-11-13 ; et une sonde locale de notre garde
de claim, le même jour. À cette date, aucune PR
des deux dépôts de la portée ne porte la marque d'une session hors flotte : les règles
ci-dessous n'ont pas encore été exercées ici.

**Vocabulaire.** Le **parrain** est la lane de la flotte qui écrit le cadre, tient les verrous,
relit et merge — par défaut le coordinateur, `myia-ai-01:roo-extensions`. L'**issue-cadre** est
l'issue qui porte le mandat de la session.

---

## Ce que la session ne voit pas

| Elle n'a pas | Conséquence | Ce qui remplace |
|---|---|---|
| Le MCP de coordination (dashboards, inbox RooSync) | Un `[TASK]`, un `[STOP]` ou une réponse postés sur un dashboard ne lui parviennent jamais | L'issue-cadre : son body et ses commentaires |
| Les disques de la flotte, partagés ou locaux | Un chemin identique ne prouve pas un fichier partagé ; ses preuves locales ne sont lisibles par personne d'autre | Ce qui doit rester vérifiable est dans la PR ou dans un commentaire d'issue |
| Les services de la flotte (modèles locaux, base, index) | Elle ne peut pas rejouer ce qui en dépend | Le cadre exclut ces périmètres, ou une lane de la flotte rejoue |
| Les autres systèmes d'exploitation | Ses validations locales tournent sur un seul système | La CI du dépôt fait foi |
| Une identité de lane `machine:workspace` | Notre garde de claim ne sait pas la représenter (§ Le verrou) | Le verrou est posé par le parrain |
| Un compte GitHub à elle | L'auteur affiché est `jsboige`, comme pour les PRs des sessions interactives d'ai-01 | La première ligne du body (règle 2) |

Ces six lignes sont lues dans les textes des deux chantiers : aucune mention d'un dashboard ; un
lecteur de la flotte « non monté dans cet espace » ; un service local dont la sonde rend
« connexion refusée » ; « Windows/macOS sont documentés mais n'ont pas été exécutés dans cette
session » (body de CoursIA#26097) ; des preuves gardées dans l'espace de la session, jamais
ajoutées au dépôt.

Dans l'[échelle des canaux](user-channel-doctrine.md), une session hors flotte n'atteint que les
niveaux 4 à 6 : les issues, les documents et règles du dépôt, la CI. Tout ce que la flotte veut
lui dire passe par là.

---

## Les règles, côté session

1. **Pas de cadre, pas de session.** Le parrain écrit l'issue-cadre avant le premier geste
   (gabarit en fin de document). La session ne commence pas sur une consigne donnée ailleurs.
2. **Marquer l'origine.** La première ligne de chaque body de PR et de chaque commentaire est
   `Hors flotte — <nom de session>, cadre #<N>.` C'est le seul discriminant : le champ auteur ne
   distingue rien. Le relecteur vérifie cette ligne.
3. **Publier sa partition avant d'agir.** La liste des numéros d'issue ou des chemins que la
   session va toucher, en commentaire de l'issue-cadre, avant tout verrou, correction ou
   fermeture — et de nouveau à chaque reprise. Une partition est un périmètre de lecture, pas un
   verdict.
4. **Ne pas écrire `[CLAIMED]` en début de ligne.** La session demande ses verrous dans
   l'issue-cadre ; le parrain les pose (§ Le verrou). Elle annonce de même la fin d'un grain ;
   le parrain lève.
5. **Ni merge, ni push sur `main`.** Une PR depuis une branche. L'approbation de la flotte, à la
   tête exacte, précède tout merge ; le merge est fait par la flotte. Le délai peut se compter
   en jours.
6. **Pas de fermeture sans preuve, ni au-delà du cadre.** Une issue ne se ferme que si le cadre
   l'autorise, avec le bloc Evidence de [`issue-closure.md`](../../../.claude/rules/issue-closure.md),
   dans la limite écrite au cadre. Un critère non tenu : ne pas fermer, dire ce qui manque.
7. **Un garde qui refuse n'est pas contourné.** Le verdict bloquant d'un organe (claim, CI, gate
   de fermeture) se rapporte tel quel dans l'issue-cadre. Pas de contrôle maison à la place, pas
   d'édition du garde, pas de `--no-verify`. La session ne s'attribue pas non plus la levée de
   la réserve d'un relecteur.
8. **Ménager la CI et le quota.** Une classe de correction par PR. Pousser une fois, quand la
   PR est prête : chaque push relance la CI. Ne pas relancer un job sans avoir lu sa panne.
   Tenir le plafond de PRs ouvertes écrit au cadre. Le quota GitHub est celui du compte, partagé
   avec toute la flotte : grouper les appels, ne pas boucler par issue sur l'API de recherche,
   suspendre sous le seuil écrit au cadre.
9. **L'état vit dans l'issue-cadre.** Après chaque lot, une table `issue | verdict | preuve |
   PR`. Une preuve qui ne vit que dans l'espace de la session ne compte pas : ce qui doit rester
   vérifiable après la fin de la session est dans la PR (un test, une sortie de commande citée)
   ou dans un commentaire.
10. **Surface publique.** Aucun secret, aucune adresse, aucun nom de personne dans une PR, un
    commentaire ou un commit ([`security.md`](../../../.claude/rules/security.md)).

---

## Le verrou : posé par le parrain

Le verrou d'une issue est un commentaire `[CLAIMED] <lane> — <intention>`
([ADR 017](../adr/017-issue-claim-locus.md)). Notre garde, `scripts/github/check_issue_claim.py`,
ne reconnaît comme lane qu'un nom de machine de la flotte. Sonde du 2026-11-13 (fonctions pures
du garde, aucun appel GitHub) :

| Ligne écrite sur l'issue | Ce que le garde en fait |
|---|---|
| `[CLAIMED] lane astra:roo-extensions — …` (aucune machine `myia-*`) | Verrou **sans propriétaire**. Il bloque toutes les lanes, **sans péremption** (encore bloquant à 72 h), y compris la session qui l'a posé |
| puis `[RELEASED] myia-ai-01:roo-extensions` | **Ne le lève pas** : une levée ferme le verrou de la lane nommée sur sa propre ligne |
| puis un `[CLAIMED] <machine:workspace>` bien formé, seul | **Ne le lève pas** : un second verrou s'ouvre, le premier reste actif |
| puis un marqueur de fermeture (`[RELEASED]`, `[DONE]`, `[RESULT]`) sans aucun nom de machine sur sa ligne | Le lève |
| `[CLAIMED] myia-ai-01:roo-extensions — réservé à la session hors flotte … (cadre #N)` | Verrou ordinaire du parrain : bloque les autres lanes 24 h, puis `STALE_CLAIM` (avertit sans bloquer) |
| le même mot au milieu d'une phrase | Rien : seul un marqueur en début de ligne est un événement |

Hors flotte, le nom de la machine ne commence pas par `MYIA-` : le garde n'en déduit aucune
identité et refuse de poser un verrou sans `--agent`.

D'où la règle :

- **Le parrain pose**, à la publication de la partition :
  `python scripts/github/check_issue_claim.py <N> --claim "réservé à la session hors flotte <nom> (cadre #<F>)"`.
- **Le parrain renouvelle** tant que la session travaille sur l'issue : passé 24 h, un verrou
  n'arrête plus personne. Re-poser suffit, le dernier marqueur d'une lane fait foi.
- **Le parrain lève** (`--release`) à la livraison ou à l'abandon.
- **Un marqueur sans propriétaire posé par erreur** se répare en deux lignes, dans cet ordre :
  un commentaire dont la première ligne est `[RELEASED]` suivi d'un texte **sans nom de
  machine**, puis le verrou du parrain. Le premier commentaire s'écrit à la main : `--release`
  compose toujours `[RELEASED] <lane>`, qui nomme une machine et n'atteint donc pas l'entrée
  sans propriétaire. Le faire seulement après avoir lu qui a posé le marqueur : lever le verrou
  d'un inconnu n'est pas une réparation.

---

## Côté flotte : ce que fait le parrain

1. **Il écrit le cadre** sur mandat du mainteneur — créer une issue exige sa validation
   ([`issue-creation.md`](../../../.claude/rules/issue-creation.md)). Un cadre qui autorise plus
   que les règles du dépôt (plus de trois fermetures, par exemple) cite la décision qui
   l'autorise.
2. **Il annonce** le début et la fin du chantier sur le dashboard `workspace`, avec l'effet de
   bord attendu : des PRs en plus dans la file de CI.
3. **Il répond dans l'issue-cadre.** Jamais seulement sur un dashboard, que la session ne lit
   pas.
4. **Il relit chaque PR à la tête exacte** : body complet, commentaires, reviews, diff, checks
   ([`pr-review-policy.md`](../coordinator-specific/pr-review-policy.md)). Il vérifie la
   première ligne. Il approuve et merge sous une identité de la flotte autre que `jsboige`,
   puisque l'auteur ne peut pas s'approuver.
5. **Il échantillonne ce qui ne passe pas par une PR.** Dans le chantier mesuré, une fermeture
   sur cinq était relue contre la source par une lane de la flotte ; une fermeture fausse est
   rouverte.
6. **Il ne compte pas une validation locale de la session comme une preuve.** La CI du dépôt,
   ou un rejeu par une lane.
7. **Il clôt.** Verrous restants levés, ce qui reste et qui le reprend écrit dans l'issue-cadre,
   issue-cadre fermée avec son bloc Evidence.

---

## Dimensionner : ce qui a coincé

Lu dans les textes des deux chantiers :

- **La file de CI.** Environ une heure d'attente au moment du mandat ; des gates annulés faute
  de runners ; un worker de test mort sans test fautif.
- **Le quota de l'installation GitHub.** Dépassé pendant la publication de résultats de CI ; la
  session a noté que ce n'était pas un résultat.
- **Deux plafonds pour un seul dépôt.** Un chantier fixait « au plus 15 PRs » ouvertes, un autre
  demandait « au moins 50 PRs en vol ». Aucun texte ne disait lequel primait.
- **L'attribution.** Un garde a d'abord vu la PR de la session comme une collision, parce que
  son body ne nommait pas sa lane.

Ce qu'on en retient pour un cadre écrit ici :

- **Un seul plafond de PRs ouvertes par dépôt**, compté contre la capacité de CI partagée. Si
  deux cadres coexistent, le parrain écrit dans les deux lequel prime.
- **Un nombre d'agents simultanés borné** (six ou sept dans les chantiers mesurés).
- **Les périmètres qui ne coûtent ni CI ni relecture d'abord** : tri, requalification,
  fermetures sur preuve.

---

## Avec ou sans

Rien dans la flotte n'attend une session cloud.

- **Sans.** Le même cadre se donne à des lanes de la flotte : l'issue-cadre devient un Epic, la
  partition une file de numéros d'issue adressée `@machine:workspace`. Les règles 5 à 10 valent
  telles quelles ; le verrou est celui de la lane.
- **Avec.** La session est une capacité en plus, pas un maillon. Un grain de sa partition resté
  sans activité 72 h est repris : le parrain lève le verrou et le redistribue, comme pour tout
  claim qui dort (seuil du balayage des dettes de
  [`coordinate.md`](../../../.claude/commands/coordinate.md) ; le garde, lui, cesse de bloquer
  sur un verrou nommé dès 24 h).
- **À l'arrêt de la session**, tout ce qu'elle seule savait doit déjà être dans GitHub
  (règle 9). Une lane qui reprend ne lit que l'issue-cadre et les PRs.

Un outil tiers lancé **par la flotte** sur une machine de la flotte (le dispatcher Copilot) est
un autre cas : il a un siège, un label de désignation et un plafond de budget, décrits dans
[`connector-v3-spec.md`](../../scheduler/connector-v3-spec.md).

---

## Ce que le dépôt ne sait pas encore faire

1. **Représenter une lane hors flotte dans le garde de claim.** Tant que ce n'est pas fait, le
   verrou passe par le parrain. Critère d'un changement : un jeton de lane hors flotte qui se
   pose, se reprend et se lève sous sa propre identité, sans élargir ce qu'une ligne de prose
   peut déclencher. Les tests du garde épinglent le comportement actuel
   (`test_off_fleet_lane_token_is_unowned`).
2. **Désigner une issue de partition par un label.** Les filtres des workers planifiés ne
   l'écartent que si elle porte un verrou frais.
3. **Tenir un verrou plusieurs jours.** La péremption de 24 h est réglée pour des cycles de
   quatre heures ; le renouvellement est manuel.
4. **Garder les preuves d'une session.** Ce qu'elle ne publie pas disparaît avec elle.

---

## Gabarit d'issue-cadre

```markdown
Titre : [HORS-FLOTTE] <objet> — cadre de session

Hors flotte — cadre écrit par <lane du parrain>, sur mandat du mainteneur du <date>.

## Objectif et condition d'arrêt
<ce qui doit être vrai à la fin, comment on le compte, quand cette issue se ferme>

## Périmètres
<P1…Pn : classes d'issues ou chemins, ceux qui ne coûtent ni CI ni relecture d'abord>

## Exclusions
- toute issue portant un verrou actif (`python scripts/github/check_issue_claim.py <N>`)
- les issues `harness-change`, `needs-approval`, `frozen`, `deferred`, `epic`
- ce qui dépend des services ou des disques de la flotte
- <gels en cours, questions en arbitrage>

## Standard d'une PR
Première ligne du body : `Hors flotte — <nom de session>, cadre #<N>.` Puis `Part of #<N>`,
une ligne `Closes #M` par issue fermée, une classe de correction par PR, un seul push.

## Fermetures
<autorisées ou non ; combien ; bloc Evidence ; part relue par la flotte>

## Plafonds
<PRs ouvertes en même temps ; agents simultanés ; seuil de quota sous lequel la session
suspend (`gh api rate_limit`)>

## Verrous
La session publie sa partition ici. <lane du parrain> pose et lève les verrous. La session
n'écrit pas `[CLAIMED]`.

## Rapport
Après chaque lot, une table : issue | verdict | preuve | PR.

Règles : docs/harness/reference/off-fleet-cloud-sessions.md
```

---

**Voir aussi :** [`connector-v3-spec.md`](../../scheduler/connector-v3-spec.md) (identité, claim,
budget des lanes outillées) · [`agent-claim-discipline.md`](../../../.claude/rules/agent-claim-discipline.md)
· [`user-channel-doctrine.md`](user-channel-doctrine.md) · [ADR 017](../adr/017-issue-claim-locus.md)
