# `gh` et la concurrence multi-processus

**Créé le** 2026-08-05 — clôture de #3032, sur cadrage utilisateur.
**Amendé le** 2026-09-16 — sérialisation des actions publiques au sein d'une session.

---

## Le fait, tel que l'utilisateur l'a posé

> « Vous êtes + de 5 instances vscode+claude-code qui tournez de front sur cette machine + des
> schedulers windows + plein de container. Il n'y a pas de fantômes mais une activité
> multi-processus à prendre en compte. »

Ce n'est pas un incident. C'est le régime normal d'`myia-ai-01` : plusieurs sessions Claude Code
interactives, le worker planifié, le listener dashboard, les tâches Windows, les conteneurs — tous
susceptibles d'appeler `gh` au même instant.

## Pourquoi ça frotte

`gh` garde l'identité active dans **un seul fichier machine-globale** :
`%APPDATA%\GitHub CLI\hosts.yml`. `gh auth switch` le réécrit. Il n'y a **ni verrou, ni session par
processus, ni variable d'environnement** qui isolerait un appelant d'un autre : `gh` n'a pas de
modèle de concurrence.

Conséquence directe : entre deux commandes `gh` d'une même session, **un autre processus a pu changer
l'identité**. Ce n'est ni un bug de `gh` à signaler, ni une dérive à traquer — c'est une propriété du
système tel qu'il est utilisé ici.

Observé le 2026-08-04 : un worker local a changé l'identité entre deux de mes commandes. La garde
décrite ci-dessous a fait son travail ; rien n'a été mergé sous la mauvaise identité.

## L'adaptation retenue — garde inline + actions publiques séquentielles dans la session

Deux invariants complémentaires tiennent face à ça :

1. **Ne jamais séparer « choisir l'identité » de « agir ».** La vérification d'identité doit être
   dans la même commande shell que l'action.
2. **Une même session ne lance jamais deux actions GitHub publiques en parallèle si elles font
   chacune `gh auth switch`.** Les lectures peuvent rester parallèles ; reviews, commentaires,
   merges, fermetures et créations sont sérialisés par la session qui les orchestre.

```bash
# ✅ un seul bloc public à la fois dans cette session
gh auth switch --user myia-ai-01 \
  && [ "$(gh api user --jq .login)" = "myia-ai-01" ] \
  && gh pr review N --approve --body-file review.md
```

```bash
# ❌ deux commandes : un autre processus peut passer entre les deux
gh auth switch --user myia-ai-01
gh pr merge N --squash          # sous quelle identité, réellement ?
```

Corollaire : `gh auth status` lu au début d'une session ne dit **rien** de l'identité qu'aura la
commande suivante. Une identité n'est vraie qu'au moment où elle est asserted, dans la commande qui
agit.

### Pourquoi deux blocs gardés en parallèle restent dangereux

La garde inline ne constitue pas une transaction sur `hosts.yml`. Deux blocs parallèles d'une même
session peuvent s'entrelacer ainsi : A bascule et vérifie A ; B bascule vers B ; A exécute ensuite
son action sous B. C'est arrivé le 2026-09-16 avec deux commentaires Evidence lancés ensemble : l'un
a été publié sous l'identité humaine `jsboige` malgré son assertion préalable de `myia-ai-01`. Une
clarification publique a immédiatement établi que ce commentaire ne valait ni approbation ni consentement
humain.

Le correctif est local à l'orchestrateur : il groupe toujours les **lectures** indépendantes, mais
émet les **actions publiques** une par une. Ce n'est ni un verrou de la machine ni une tentative de
contrôler les autres sessions ; un autre processus peut toujours basculer l'identité, raison pour
laquelle la garde inline reste obligatoire sur chaque action.

## Ce qu'on ne fait **pas** — et pourquoi

Le cadrage utilisateur est explicite : *« Ne cherche pas à contrôler trop de choses dans ce
capharnaüm nécessaire […] ne prends pas de risques d'étouffement. »* Sont donc écartés :

| Piste écartée | Raison |
|---|---|
| Verrou global sur `hosts.yml` | sérialiserait tous les `gh` de la machine — un worker bloqué gèle le reste |
| Sérialiser les appels `gh` via une file | même effet, plus de pièces mobiles à casser |
| Tuer / suspendre les processus concurrents | l'activité multi-processus est **voulue** ; l'automatisation de kill exige preuve + GO utilisateur |
| Copies par-processus de `hosts.yml` | non supporté par `gh` ; contiendrait des tokens dupliqués sur disque |
| Détecter et alerter à chaque changement d'identité | du bruit permanent sur un comportement normal |

La garde in-command coûte un `&&` et couvre le cas réel. C'est suffisant, et c'est le point d'arrêt.

## Rappels de sécurité qui restent en vigueur

- **Ne jamais afficher le contenu de `hosts.yml`** — il contient des tokens. Utiliser
  `gh auth status`, qui les rédige.
- Ne jamais approuver du travail écrit par un agent sous l'identité personnelle **`jsboige`** :
  choisir une identité bot éligible, et **dire dans le corps de la revue que ce n'est pas un second
  avis**.
- La garde est aussi **relationnelle** : l'identité active ≠ une identité éligible. Vérifier que le
  compte qui approuve n'est pas l'auteur de la PR.

---

**Voir aussi :** `.claude/rules/pr-mandatory.md` (workflow PR), `.claude/rules/security.md` (secrets).
