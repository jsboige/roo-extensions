# Cycle du coordinateur — pourquoi les règles sont ce qu'elles sont

**Créé :** 2026-11-13 (campagne #2368 : la règle reste dans la commande, le récit vient ici)

Les règles du cycle de coordination sont dans
[`.claude/commands/coordinate.md`](../../../.claude/commands/coordinate.md). Ce document porte ce
qui les justifie : provenance, paroles du user, mesures, incidents. Il ne prescrit rien de plus que
la commande. Si les deux se contredisent, la commande fait foi et ce document est à corriger.

Les sections reprennent les titres de la commande.

---

## Balayage des dettes

### Provenance

La section vient de deux emprunts.

- **CoursIA, `continue.md`, Phase 2 P0** (« Réparer SON PROPRE rouge »). Sa justification vaut mot
  pour mot pour le coordinateur : *« La raison est mécanique, pas disciplinaire : une PR rouge ne
  peut être réparée que par sa lane [...] tant que la lane ne revient pas dessus, elle reste ouverte
  indéfiniment pendant que les PRs du jour, elles, mergent. »*
- **La position dans le cycle** (solder avant de distribuer) vient de la commande de coordination
  d'un autre dépôt de la flotte, dont la phase « Merger ce qui est mergeable » précède la phase
  « Dispatcher ».

Le rôle de coordinateur ajoute un axe que le worker CoursIA n'a pas : l'approbation CODEOWNERS.
Une PR d'un autre qui attend ma review est bloquée par moi.

### Incident fondateur (2026-09-02)

Le coordinateur rapportait la flotte comme saine. Au même moment :

- 4 PRs attendaient une review. L'une bloquait nommément po-2026 (« je n'agis pas avant
  l'approbation formelle d'un approver flotte ») ;
- 2 messages étaient non lus ;
- une question posée à la lane du coordinateur sur l'Epic #3188 était restée 5 jours sans réponse.

### Brouillons : une dette fabriquée (mesure du 07/09)

La PR submodule #861 était un brouillon en conflit depuis le 14/07. Le champ `reviewDecision` d'un
brouillon vaut `REVIEW_REQUIRED`, comme pour une vraie dette. Sans lire `isDraft`, le balayage l'a
remontée en dette d'approbation pendant deux mois. Un brouillon est bloqué sur son auteur.

### Deux variantes de la même cécité (mesures du 2026-09-04)

Le point 4 du balayage (« ce que j'ai envoyé et que personne n'a pris ») a deux formes moins
visibles.

- **Une levée de gel n'est pas un dispatch.** L'issue #2368 a calé deux fois : 49 h parce que le
  gel n'était pas levé, puis 72 h parce qu'il l'était. Après la levée, personne n'avait reçu
  l'obligation de reprendre.
- **Le miroir : reclasser son propre travail en attente du user.** Trois points rapportés le même
  jour comme « attente utilisateur » étaient ceux du coordinateur : un diagnostic chez un
  fournisseur externe, une relance de po-2027, le dispatch des attestations #3405.

### Claims anciens : chercher la PR déjà livrée

La règle « avant de relancer ou de libérer un claim de plus de 72 h, chercher une PR déjà livrée »
vient d'un balayage qui ne listait que les PRs ouvertes. Une lane avait livré, sa PR était mergée,
et le balayage la voyait comme silencieuse. L'état d'une livraison se lit avec `--state all`.

---

## Chef d'équipe (mobiliser les lanes, entretenir le pool)

Paroles du user, 20/10/2026 :

> « tu es le coordinateur dont le travail est le plus mauvais, et tu es pourtant celui qui a accès
> au plus de workers disponibles »

> « Ce sont surtout les workers interactif des machines qu'il faut que tu mobilises. Si tu te
> concentres sur tes workers schtasks locaux, tu te regardes le nombril. Vous êtes une équipe, et
> tu es le chef »

Mesure du même jour, vers 15:30Z : sept lanes sur huit avaient livré, et 10 PRs et 3 décisions
attendaient le coordinateur. Le goulot était le coordinateur, pas les lanes.

---

## Sortie de tour

Arbitrage user du 14/09/2026 (#3647) :

> « le problème, pour le coordinateur, est de ne pas s'arrêter et d'attendre le prochain cron quand
> les lanes sont déjà bien provisionnées en son absence et qu'il ne reste que des gains de
> coordination marginaux »

La règle a un second bord, écrit dans la commande : elle n'autorise pas à s'arrêter avec une lane à
sec ni à finir après une PR bloquée. Le harnais avait déjà payé l'excès inverse.

---

## Analyse des traces scheduler

La chaîne d'escalade (`code-simple` → `code-complex` → `orchestrator-complex` → `claude -p`) avait
un objectif de long terme : pousser le scheduler Roo vers de plus en plus de tâches `-complex`, le
modèle le plus capable reprenant ce qui échoue. Depuis le 08/11/2026 le scheduler Zoo (ex-Roo) est
désactivé sur toute la flotte (décision user citée dans la section Mission de la commande) ; cet
objectif est en sommeil.

---

## Audit de configuration au démarrage

L'issue #614, qui a introduit l'audit, annonçait une réduction d'environ 70 % des incidents de
configuration. Ce chiffre est **rapporté par l'issue**. Il n'a pas été remesuré depuis, et la
commande ne le cite plus.

---

## Self-Authored PR Merge Protocol

Le premier usage du protocole a débloqué 11 PRs du coordinateur planifié en un cycle, par une
approbation sous l'identité propriétaire. C'est ce cycle qui a fixé les conditions strictes et les
red flags.

Jusqu'au 13/11/2026 le gabarit de la commande basculait d'identité sur une ligne et agissait sur la
suivante. C'est la forme que
[`gh-identity-concurrency.md`](../reference/gh-identity-concurrency.md) donne comme défaut
(observation du 2026-08-04 : un worker local a changé l'identité entre deux commandes). Le gabarit
met maintenant la bascule, la vérification et l'action dans la même commande.

**Ce que GitHub verrouille réellement (mesure du 13/11/2026).** Lue sous le compte propriétaire, la
protection de `main` exige une review approbatrice (`required_approving_review_count: 1`). Elle
n'exige pas la review d'un code owner, n'impose aucun check de CI et ne s'applique pas aux
administrateurs ; aucun ruleset ne s'y ajoute. Jusque-là, la commande attribuait le blocage à
`.github/CODEOWNERS`, et [`pr-review-policy.md`](pr-review-policy.md) décrivait 0 review requise et
un check `build-and-test` imposé. D'où la précision portée dans la commande : la condition « CI
entièrement verte » est le seul verrou contre un merge sur CI rouge.

---

## Ce que la commande ne recopie plus

Retirés de la commande le 13/11/2026 parce qu'une autre source fait foi :

| Retiré | Source qui fait foi |
|---|---|
| Tableau des machines (7 lignes) | `.claude/configs/fleet-manifest.json` (9 machines) |
| Liste des sub-agents | [`agents-inventory.md`](../reference/agents-inventory.md) |
| IDs de champs du Project #67 (liste partielle) | [`github-cli.md`](../reference/github-cli.md) § « Field IDs (Project #67) » |
| Claim par le champ Machine du Project | [`agent-claim-discipline.md`](../../../.claude/rules/agent-claim-discipline.md) : le verrou est sur l'issue |
| Procédure de review `run_conversation("code-review")` | [`pr-review-policy.md`](pr-review-policy.md) : outil `review_pr` par paliers |
| « Après modif MCP : redémarrage VS Code » | [`mcp-diagnosis.md`](../../../.claude/rules/mcp-diagnosis.md) dit l'inverse ; la ligne est supprimée, sans remplacement |
| Source de vérité n° 7, `DASHBOARD.md` | Magasin monolithique hérité ([`roosync-tools-guide.md`](../reference/roosync-tools-guide.md)) ; remplacé par le dashboard workspace |
| « SUPPRIMER le rapport (pas archiver) » | [`no-deletion-without-proof.md`](../../../.claude/rules/no-deletion-without-proof.md) : fusionner d'abord, preuve citée, retrait ensuite |
| « L'objectif long terme est de pousser Roo vers de plus en plus de tâches `-complex` » | Ce document, § « Analyse des traces scheduler » : objectif en sommeil depuis la désactivation du scheduler Zoo |
