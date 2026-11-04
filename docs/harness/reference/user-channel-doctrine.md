# Canaux de communication — l'échelle des six niveaux

**Version :** 1.0.0 · **Question d'origine :** Q20 (registre user, lane `myia-po-2023:roo-extensions`) · **MAJ :** 2026-11-04
**Source canonique :** ce fichier. La doctrine est un arbitrage **user** ; le corps des règles du harnais
(`~/.claude/CLAUDE.md`, skills `/executor` et `/coordinate`) n'en porte qu'une ligne de renvoi ici.

---

## Ce que la question demandait

Trois confusions mesurées en octobre 2026 : un dispatch annoncé « par inbox » qui n'est jamais parti, un
`[DONE]` posté au mauvais lien, un append dashboard à 5 s dont la condensation a pris 143 s. La lane a
demandé s'il fallait **un** canal, **trois**, ou une hiérarchie — et laquelle porte quoi.

## La réponse (verbatim user, session interactive du 04/11/2026)

> « Q20 — On a plusieurs canaux, par ordre décroissant d'instantanéité et de transience :
>
> - **Messages Claude-code** : N'atteignent que les sessions en vol et sont transient, mais sont instantanés et réveillent automatiquement une session endormie en attente du prochain cron. Ne laisse aucune trace. Parfait pour une urgence, pour une info qui demande une coordination instantanée, pour annoncer un reboot, demander quelque chose dont on a besoin tout de suite. C'est du jetable, pas très fiable mais le plus rapide en première intention, c'est le whatsapp de la flotte
> - **Message RooSync** : Persiste, et on est sûr que le message finira par être lu, mais pas avant que le destinataire n'utilise un outil RSM où il sera notifié que sa boite contient de nouveaux messages. Ce sont les emails de la flotte
> - **Dashboards** : Persiste et est consulté régulièrement par toute le monde, et puis les messages importants attérissent dans le statut du dashboard pendant autant de cycle où ils restent pertinents (enfin quand le mécanisme de condensation fonctionne bien, ce qui est sous la responsabilité de votre dépôt)
> - **issues git** : Très persistant et fiable de tous. Sera peut-être lu dans plusieurs jours quand un autre agent seront confrontés à la problématique concernée, mais ils devront y passer. Si c'est critique, ne pas se contenter d'un commentaire qui peut être parfois ignoré, mais carrément réécrire le body, typiquement si l'issue présente une dérive des agents qui la traitent et doit être traitée différemment par les prochains agents qui la prennent en charge
> - **Documentation des dépôts et règles du harnais**. Avec plusieurs niveaux de visibilité selon où on met l'info. Peut être encore plus persistant qu'une issue qui se ferme. Une règle sera relue inlassablement jusqu'à ce qu'on la change.
> - **Règles de CI** : Si des erreurs sont commises malgré les règles qui tentent de les prévenir, la solution est de rajouter un organe au CI. Il n'est plus possible de contourner la règle qui devient un passage obligatoire. Typiquement à mettre en place si un problème s'y prête ou si un durcissement du harnais n'a pas suffi. »

---

## L'échelle, et l'usage de chaque niveau

| # | Canal | Persistance | Qui le lit, et quand | Usage |
|---|-------|-------------|----------------------|-------|
| 1 | **Messages Claude Code** | nulle — jetable | la session **en vol** ; réveille une session endormie qui attend son cron | urgence, coordination immédiate, annonce de reboot, « j'ai besoin de ça tout de suite » |
| 2 | **RooSync** | durable | le destinataire, à sa prochaine utilisation d'un outil RSM (il est notifié d'un message en attente) | ce qui doit **finir** par être lu, sans urgence |
| 3 | **Dashboards** | durable, consulté | tout le monde, régulièrement ; le **statut** porte les messages importants tant qu'ils sont pertinents | coordination de flotte, état des chantiers, restitution de fin de session |
| 4 | **Issues git** | très durable | l'agent **confronté** au problème, parfois des jours plus tard | la décision et sa preuve, au locus du sujet |
| 5 | **Docs des dépôts + règles du harnais** | plus durable qu'une issue fermée | toute lane, **à chaque session** (une règle est relue jusqu'à ce qu'on la change) | la règle, la doctrine, le mode d'emploi |
| 6 | **CI** | contraignante | personne ne la « lit » : elle **bloque** | quand la règle existe mais n'a pas suffi |

### Niveau 1 — Messages Claude Code (« le whatsapp de la flotte »)

Le seul canal qui **réveille** une lane endormie. En contrepartie il ne laisse aucune trace : un message
non lu au moment où la session s'arrête est perdu. C'est le bon premier réflexe par rapidité, jamais le
support d'une décision qu'on voudra retrouver.

### Niveau 2 — RooSync (« les emails »)

Persiste et **finira par être lu**, mais pas avant que le destinataire ne touche un outil RSM. Ce délai
est une propriété du canal, pas une négligence : ne pas le lire comme « le message est ignoré ».

### Niveau 3 — Dashboards

Persiste et est consulté par tout le monde. Le mécanisme qui fait vivre un message important — sa
reprise dans le **statut** tant qu'il reste pertinent — est la **condensation**, et son bon
fonctionnement est la responsabilité de **ce dépôt** (chantier #4434) : quand elle régresse, le niveau 3
perd sa mémoire et les messages importants disparaissent sans que personne ne les ait lus.

### Niveau 4 — Issues git, et la règle qui ne va pas de soi

Très persistant, lu par l'agent **confronté** au problème. La règle arbitrée :

> **Si c'est critique, ne pas se contenter d'un commentaire — réécrire le body.**

Un commentaire peut être ignoré (on lit le corps d'une issue, pas toujours ses trente commentaires).
Le cas typique : l'issue montre une **dérive des agents qui la traitent** et doit être traitée
différemment par les suivants — c'est le corps qu'il faut réécrire, pour que le prochain lecteur parte
de la bonne consigne.

### Niveau 5 — Docs des dépôts et règles du harnais

Plusieurs niveaux de visibilité selon l'emplacement (règle auto-chargée, doc on-demand, `docs/harness/`).
**Plus persistant qu'une issue fermée** : une règle est relue inlassablement jusqu'à ce qu'on la change.
C'est là que vit une décision qui doit s'appliquer sans qu'on ait à la retrouver.

### Niveau 6 — Règles de CI

Quand des erreurs persistent **malgré** les règles qui tentaient de les prévenir, la réponse n'est plus
d'écrire une règle de plus : c'est d'**ajouter un organe au CI**. La règle devient alors un passage
obligatoire, qu'on ne peut plus contourner. À mettre en place si le problème s'y prête, ou si un
durcissement du harnais n'a pas suffi.

---

## Les deux corollaires

**Escalade de dureté.** On ne monte d'un niveau que lorsque le niveau inférieur a échoué ou est
inadapté par nature : un message instantané pour une décision durable est un mauvais choix de canal, pas
un manque d'insistance. Réciproquement, une urgence postée seulement dans une issue n'arrivera pas à temps.

**Lecture.** Un dispatch absent d'un canal se cherche dans **l'autre** avant de conclure à son absence.
Trois confusions d'octobre venaient de là : chercher dans le fil un message parti par RooSync (ou
l'inverse), puis rapporter une panne qui n'existait pas.

---

## Portée et déploiement

- **Décision** (les six niveaux, l'usage de chacun, la règle du body) : ce fichier.
- **Une ligne de renvoi** vers ce fichier dans `~/.claude/CLAUDE.md` (source `.claude/configs/user-global-claude.md`)
  et dans les skills `/executor` et `/coordinate` — porté par ai-01 après le merge de ce document.
- **Chaque workspace amincit ses propres règles** (campagne 04/11) : ce fichier ne recopie aucune règle
  locale, il ne fait que fixer l'échelle.
