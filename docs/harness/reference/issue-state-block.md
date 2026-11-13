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

1. **Pas de syntaxe de case à cocher dans un bloc.** `checklist-enforce.yml` compte `- [ ]`
   partout dans le corps et rouvre une issue fermée tant qu'une case reste ouverte. Il compte
   aussi la pastille ⬜ comme une case ouverte : l'outil ne la refuse pas, ne l'écrivez pas.
   Une étape se numérote (`1.`), elle ne se coche pas.
2. **Rien de privé.** Le dépôt est public. Pas d'adresse IP, d'e-mail, de nom de personne
   (écrire « le user »), de nom d'hôte hors `myia-*`, de nom de domaine, de fragment de clé ou
   de jeton, de nom de fichier de clé, de chemin de profil Windows, de valeur de variable
   d'environnement. Pas non plus les deux jetons d'escalade de
   [`degraded-escalation.md`](../../../.claude/configs/rules/degraded-escalation.md), qui ont
   un sens mécanique. L'outil refuse ce qu'il sait détecter. Les motifs propres à la flotte (un
   nom de fichier de clé, par exemple) ne sont pas versionnés : une regex par ligne dans
   `.tmp/issue-state-blocks/forbidden-local.txt`, ignoré par git.
3. **Rafraîchir quand l'état change**, avec la nouvelle date dans le titre du bloc.
4. **L'énoncé d'origine reste dessous, inchangé.** Seule exception : une case nommée par
   `--tick`, cochée avec une note (« — PR #NNNN »).
5. **Une décision reçoit aussi un commentaire d'une ligne.** Éditer un corps ne notifie
   personne et ne laisse aucune trace dans le fil.

## Commande

Le bloc de l'issue N s'écrit dans `.tmp/issue-state-blocks/blocks/<N>.md` (ignoré par git).
D'abord à blanc, puis sous l'identité du coordinateur, fixée dans la même commande :

```bash
python scripts/github/apply_issue_state_block.py --dry-run 1171 1297
export GH_TOKEN=$(gh auth token --user myia-ai-01) && [ "$(gh api user --jq .login)" = "myia-ai-01" ] \
  && python scripts/github/apply_issue_state_block.py --tick 1171:"première étape"::"PR #4686" 1171 1297; unset GH_TOKEN
```

Pour chaque N, dans l'ordre : bloc absent = `SKIP` ; motif interdit, ou bloc qui ne commence
pas par `### État au` = `REFUSED` ; lecture du corps actuel ; sauvegarde unique du corps dans
`.tmp/issue-state-blocks/backup/<N>.md` (la première version vue est gardée, c'est la source
d'une restauration) ; remplacement du bloc marqué, ou insertion en tête ; cases `--tick`.
Puis `REFUSED` si une case visée manque, si le nombre de cases change, ou si le corps
dépasse 64 000 caractères. Sinon écriture, relecture et comparaison (`WRITTEN` ou
`READBACK-DIFFERS`). Une pull request est sautée.

Options : `--repo` (défaut `jsboige/roo-extensions`), `--blocks-dir`, `--backup-dir`,
`--local-patterns`, `--expect-login` (défaut `myia-ai-01` ; toute autre identité est refusée
avant la première écriture), `--dry-run`, `--tick N:"sous-chaîne"[::note]` (répétable).

Sortie : `0` si chaque issue nommée est écrite, passe à blanc ou est une pull request ;
`1` si au moins une est refusée, sautée faute de bloc, ou diffère à la relecture, ou si le
passage s'est arrêté (identité, échec de `gh`).

## État

Depuis le 13/11/2026, les issues ouvertes du dépôt portent un bloc (71 issues ce jour-là).
