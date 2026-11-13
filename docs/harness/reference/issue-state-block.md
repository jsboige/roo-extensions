# Bloc d'état d'issue

**Créé :** 13/11/2026 · **Outil :** `scripts/github/apply_issue_state_block.py` ·
**Tests :** `scripts/github/tests/test_apply_issue_state_block.py` (job CI `scheduling-harness`)

## Ce que c'est

En tête du corps d'une issue, un bloc daté dit où elle en est. Il tient entre deux marqueurs
invisibles au rendu, `<!-- etat:debut -->` et `<!-- etat:fin -->`. Une ligne de pied le signe.
Un séparateur `---` le sépare de l'énoncé d'origine, qui suit, inchangé.

```markdown
### État au JJ/MM/AAAA
**Fait** : ce qui est acquis, avec sa preuve (PR, commentaire daté, mesure).
**Reste à faire**, dans l'ordre :
1. L'étape — critère de fin : <ce qu'on peut vérifier> — siège : <machine, lane, user ou coordinateur>.
**Bloqué par** : ce qui attend quelqu'un d'autre, ou « rien ».
**Pour reprendre sans relire le fil** : les commentaires datés qui portent les décisions.
```

Chaque étape du « Reste à faire » a un critère de fin testable et un siège.

## Pourquoi

- Une lane lit le bloc au lieu du fil entier.
- Éditer le corps d'une issue ne déclenche aucun workflow. Vérifié le 13/11/2026 dans
  `.github/workflows/` : deux workflows réagissent aux issues, `checklist-enforce.yml`
  (`issues: closed`) et `sync-project.yml` (`issues: opened`). Le seul `edited` du dossier,
  dans `pr-negation-autoclose.yml`, écoute les pull requests, pas les issues.

## Règles

1. **Pas de case à cocher dans un bloc.** `checklist-enforce.yml` compte `- [ ]` et la
   pastille ⬜ partout dans le corps. Quand on ferme une issue où il en reste une, il la
   rouvre et le dit en commentaire. Il le fait au plus 3 fois (`MAX_REOPENS = 3` dans le
   workflow) ; ensuite, il laisse l'issue fermée avec un avertissement. L'outil refuse donc
   dans un bloc la pastille ⬜ et toute case, cochée ou non : `- [ ]`, `* [ ]`, `+ [ ]`, et
   les cases de liste numérotée (`1. [ ]`, `1) [ ]`). Une étape se numérote (`1.`), elle ne
   se coche pas.
2. **Rien de privé.** Le dépôt est public. Pas d'adresse IP, d'e-mail, de nom de personne
   (écrire « le user »), de nom d'hôte hors `myia-*`, de nom de domaine, de fragment de clé ou
   de jeton, de nom de fichier de clé, de chemin de profil Windows, de valeur de variable
   d'environnement. Pas non plus les deux jetons d'escalade de
   [`degraded-escalation.md`](../../../.claude/configs/rules/degraded-escalation.md), qui ont
   un sens mécanique. L'outil refuse ce qu'il sait détecter, dans le bloc et dans la note
   d'un `--tick`. La liste d'admission des domaines tient en deux noms, `github.com` et
   `claude.com` : l'outil les compare en entier, en majuscules ou non, et refuse un domaine
   qui se termine seulement par l'un d'eux. Les motifs propres à la flotte (un nom de fichier
   de clé, par exemple) ne sont pas versionnés : une regex par ligne dans
   `.tmp/issue-state-blocks/forbidden-local.txt`, ignoré par git.
   Les filtres refusent aussi des textes sans danger : un nom de fichier comme
   `settings.local.json` (lu comme un domaine), une version épinglée `outil@1.2.3` (lue comme
   un e-mail), le mot « Bearer » suivi d'un mot (lu comme un jeton). Un refus est le côté
   sûr : reformuler la phrase.
3. **Pas de marqueur dans un bloc.** Un bloc qui contient `<!-- etat:debut -->` ou
   `<!-- etat:fin -->` est refusé.
4. **Rafraîchir quand l'état change**, avec la nouvelle date dans le titre du bloc.
5. **L'énoncé d'origine reste dessous, inchangé.** Seule exception : une case nommée par
   `--tick`, cochée avec une note (« — PR #NNNN »).
6. **Une décision reçoit aussi un commentaire d'une ligne.** Éditer un corps ne notifie
   personne et ne laisse aucune trace dans le fil.

## Commande

Le bloc de l'issue N s'écrit dans `.tmp/issue-state-blocks/blocks/<N>.md` (ignoré par git).
Ce fichier et celui des motifs locaux se lisent en UTF-8, avec ou sans BOM (un fichier écrit
par Windows PowerShell 5.1 en porte un). Lancer l'outil depuis le clone principal : les
sauvegardes vivent sous son `.tmp/`. D'abord à blanc, puis sous l'identité du coordinateur,
fixée dans la même commande :

```bash
python scripts/github/apply_issue_state_block.py --dry-run 1171 1297
export GH_TOKEN=$(gh auth token --user myia-ai-01) && [ "$(gh api user --jq .login)" = "myia-ai-01" ] \
  && python scripts/github/apply_issue_state_block.py --tick 1171:"première étape"::"PR #4686" 1171 1297; unset GH_TOKEN
```

Avant tout appel réseau, l'outil vérifie ses arguments. Un numéro d'issue avec `#` ou un zéro
de tête est une erreur d'argument, comme un `--tick` à sous-chaîne vide. Un `--tick` qui nomme
une issue absente de la liste arrête le passage (`ABORTED`). Une écriture exige `GH_TOKEN`
exporté : sans lui, l'identité viendrait du fichier d'hôtes partagé de `gh`, et l'outil
s'arrête (`ABORTED`). L'identité doit ensuite être celle de `--expect-login`. À blanc
(`--dry-run`), l'outil n'écrit rien : ni corps, ni sauvegarde, ni répertoire.

Pour chaque N, dans l'ordre : bloc absent = `SKIP` ; `REFUSED` si le bloc contient un motif
interdit ou un marqueur, s'il ne commence pas par `### État au`, ou si la note d'un `--tick`
contient un motif interdit ; lecture du corps actuel ; sauvegarde unique du corps dans
`.tmp/issue-state-blocks/backup/<N>.md` ; remplacement du bloc de tête, ou insertion en tête ;
cases `--tick`. Puis `REFUSED` si une case visée manque, si le nombre de cases change, ou si
le corps dépasse 64 000 caractères. Sinon écriture, relecture et comparaison (`WRITTEN` ou
`READBACK-DIFFERS`). Si la relecture échoue après l'écriture, la sortie dit
`WRITTEN-UNVERIFIED` : l'écriture a peut-être eu lieu, et le passage s'arrête. Une pull
request est sautée.

Le bloc remplacé est seulement celui qui ouvre le corps : le corps commence par
`<!-- etat:debut -->`, et un `<!-- etat:fin -->` suit. Ailleurs, des marqueurs sont du texte
de l'énoncé (une citation, par exemple) : le nouveau bloc s'insère en tête, et l'énoncé reste
intact dessous.

La sauvegarde est le corps tel que l'outil l'a vu la première fois sur ce checkout. Pour les
blocs posés le 13/11/2026 avant que l'outil existe, l'énoncé d'origine est la partie du corps
sous le bloc, inchangée.

Options : `--repo` (défaut `jsboige/roo-extensions`), `--blocks-dir`, `--backup-dir`,
`--local-patterns`, `--expect-login` (défaut `myia-ai-01` ; toute autre identité est refusée
avant la première écriture), `--dry-run`, `--tick N:"sous-chaîne"[::note]` (répétable).

Sortie : `0` si chaque issue nommée est écrite, passe à blanc ou est une pull request ;
`1` si au moins une est refusée, sautée faute de bloc, diffère à la relecture ou n'a pas pu
être relue, ou si le passage s'est arrêté (`--tick` hors liste, `GH_TOKEN` absent, identité,
échec de `gh`) ; `2` pour une erreur d'argument.

## État

Le 13/11/2026, les 71 issues ouvertes ce matin-là ont reçu un bloc. Une issue créée ensuite
en reçoit un quand son état ne se lit plus dans son énoncé.
