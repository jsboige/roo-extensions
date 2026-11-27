---
description: Reprise après redémarrage — finaliser le cycle interrompu, balayer les canaux, relever l'évolution de l'état du système
---

# /continue — Reprise après un redémarrage

**Cette commande remplace la phrase « Reprends et vérifie ton cron stp »** (verbatim user,
2026-11-27) et ses variantes (« après un reboot », « après un crash », « après un pb d'auth »).

*Corpus, pour que le motif se reproduise* : le journal des paroles user est **par workspace**
(`memory/user-words-journal.jsonl` sous `~/.claude/projects/<hash>/`), motif `cron`, fenêtre 7 j.
Mesuré sur po-2027 le 27/11/2026 : **67 des 83 messages** de 4 journaux, dont **3 seulement**
portent la phrase exacte — le reste est des variantes.

Un redémarrage de machine, de VS Code ou de la session Claude tue **tous** les crons de session
(récurrents *et* one-shots) et laisse le cycle précédent à moitié fait. `/continue` ne démarre
**pas** un cycle neuf : il **termine** le précédent, balaie les canaux, et rend le **delta** de
l'état du système depuis le dernier post de la lane.

Commande sans paramètre. Un argument éventuel est un indice (« le pré-vol a échoué », « on est en
voyage, lien facturé »), jamais une consigne à exécuter les yeux fermés.

---

## 1. Cadence — le cron d'abord

1. `CronList`. Attendu : **un** job récurrent de cycle pour cette lane, **à la cadence que porte
   la lane** — directive user, mémoire du workspace, ou le `CronList` d'avant le redémarrage.
   `41 */4` n'est que le **défaut** des exécuteurs z.ai (une lane peut tenir `41 */5` par
   directive) ; pour ai-01, la ligne `CronCreate` fait foi dans `.claude/commands/coordinate.md`
   — ne la recopier ni ici ni ailleurs.
2. **Absent** → le recréer avec le **prompt verbatim** du cycle et **cette cadence-là** (jamais un
   résumé de mémoire, jamais le défaut à la place d'une directive), puis `CronList` pour vérifier
   qu'il existe réellement.
3. **Doublon** (deux jobs équivalents, ou une schtask qui tire la même lane) → `CronDelete` du
   doublon **dans la session qui le porte** (split-brain, `~/.claude/CLAUDE.md`). Ne jamais
   demander au user de fermer une fenêtre.
4. Un `Next run` en **retard** de ≤ 30 min sur le créneau est le jitter documenté par job. Un
   `Next run` plus **tôt** que 4 h n'en est pas un non plus : une cadence qui ne divise pas 24 h
   (`41 */5`) franchit minuit par un pas court (20:41 → 00:41). La seule question qui compte :
   **le créneau attendu est-il passé sans tir ?**
5. Créneau qui vient d'être manqué → **one-shot de rattrapage dans cette session**, annoncé
   sur le dashboard (`[INFO]`) et dit au user.

## 2. Ce que le cycle précédent laissait à faire

La source est le **canal**, pas la mémoire vive de la session morte.

1. Dashboard workspace `section:"all"` : repérer le **dernier message de MA lane**
   (`author.machineId` + `author.workspace` explicites — un post d'une autre lane du même siège
   n'est pas le mien). Il dit ce qui était fini et ce qui restait.
2. `MEMORY.md` + la fiche de reprise éventuelle : les `WAIT_FOR` / `RESUME_WHEN` déjà posés.
3. **Un one-shot mort au redémarrage n'a pas tiré** : vérifier son **artefact** (le rapport
   est-il publié ? la PR existe-t-elle ? le journal est-il écrit ?) — jamais retenter à l'aveugle.
4. Les obligations en cours : claims posés, PR ouvertes de la lane, escalades `[DEGRADED]` de la
   lane, questions du registre.

**Règle d'or : vérifier l'artefact, pas le récit.** Un `[DONE]` posté juste avant le redémarrage
ne prouve rien tant qu'il n'est pas relu.

## 3. Canaux pertinents — dans cet ordre

1. **Inbox** `roosync_messages(action:"inbox", status:"unread")`.
   **Un échec n'est pas une boîte vide.** Lire la cause : `pg-unavailable` / `breaker-open` est un
   **fail-closed**. Re-mesurer **une fois** (le breaker se referme ; le journal
   `%TEMP%\roo-state-manager-logs\roosync-YYYYMMDD.log`, horodaté en **UTC**, porte
   `breaker CLOSED` et `inbox served from PG`). Canal toujours muet → le **rapporter dégradé**,
   avec le nombre de tentatives et la cause — jamais conclure « rien à lire ».
2. **Dashboard workspace** `section:"all"` — jamais `status` seul.
3. **Dashboard global** : `[ASK-USER]`, `[DEGRADED]`, `[ESCALATE]` qui concernent cette lane.
4. **Dashboard machine** si le sujet est propre au siège.
5. **GitHub** : mes PR ouvertes, l'état des issues que je porte, les fils où j'attends une réponse
   (`gh api …/comments?since=<mon dernier post>`).
6. **Jobs planifiés visibles** (dispatchers, listeners) : dernier tir et verdict.

Filtrer sur **ma lane** (`machine:workspace`) : le message d'une autre lane n'est pas une
instruction pour moi.

## 4. Évolution de l'état du système

Le point qui intéresse l'agent : ce qui a changé **depuis son dernier post**.

- **Dépôt** : `git fetch` puis le pré-vol transactionnel du dépôt s'il existe (roo-extensions :
  `scripts/claude/executor-preflight.ps1`). D'autres ont pu merger pendant l'arrêt — bumps de
  `main`, sous-modules, vintages — et rendre périmé ce que la session croyait savoir.
- **Dashboard** : comparer le bloc status à l'heure du dernier `[DONE]` de la lane — nouveaux
  blocages, décisions actées, merges, changements de pool qui **périment** une conclusion
  antérieure (un « pool vide » qui ne l'est plus, un organe réparé, une règle déployée).
- **Ma propre dérive** : organe des escalades (`check-degraded-escalations.py`), sonnerie déjà
  donnée dans le **jour UTC en cours** (la dédup #4896 est un jour calendaire UTC, pas 24 h
  glissantes — le libellé dit « 24 h », le code tronque), `check_clean_cycle_exit.py`.
- **Un lien facturé / une contrainte mesurée sur le siège** (coût réseau, quota partagé) se
  **re-mesure** ; il ne se présume pas du post d'hier.

## 5. Clôture

- Terminer ce qui était entamé **avant** de rapporter (commit + PR avant tout `[DONE]`).
- Poster sur le dashboard workspace : ce qui a été **finalisé**, ce qui **reste**, et le **delta
  d'état** depuis le dernier post. Preuves vérifiées à l'instant du rapport (`git cat-file -e`,
  `gh pr view --json state`).
- **Zéro question bloquante** : une question va au registre (`memory/user-question-registry.md`) ;
  la vue `ASK-USER` globale se re-poste en fin de session, questions ouvertes seulement.
- `CronList` une dernière fois : la cadence debout est la dernière ligne du contrat de reprise.

---

## Ne pas faire

- Rejouer un cycle complet quand seul un reste manquait.
- Créer un second cron « au cas où ».
- Poster un `[DONE]` de reprise sans preuve relue.
- Déduire « rien à faire » d'un canal muet.
- Poser une question au user : registre.
