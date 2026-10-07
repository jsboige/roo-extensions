# ADR 016: Anti-tarissement des lanes — convergence CoursIA (picker 3 urnes, deep-queue, test-resultat)

**Date:** 2026-09-15 (renuméroté 016 le 2026-09-16 — 014 réservé à #3680 « claim locus », 015 pris par #3684 « plans progress » ; double collision résolue côté rework #3681)
**Status:** Accepted
**Issue:** #3675 (Epic #3111 phase 2, candidat #2)
**Related:** #2185 (cap IDLE 3), #2509 (`--limit 15` faux drain), #3111 (Epic convergence),
#3155 (PR audit filesystem CoursIA), #1417 (catalogue idle I1-I8), #3680 (ADR 017 claim locus)

## Context

L'observation user n°1 (recurrence 2025-2026) : **les lanes executor roo-extensions se tarissent**.
Le cap IDLE 3 (#2185), le re-arm cron/WAKE et la discipline `gh issue list --limit 100` (PIEGE #2509)
ont amelioré le faux drain mais n'ont pas resolu le tarissement.

L'audit filesystem CoursIA (PR #3155, passe 2) a documente les contre-mesures qui fonctionnent
la-bas : picker 3 urnes ponderees, test de fin de cycle base sur le resultat (pas le vocabulaire),
deep-queue par lane pour les mandates durables.

### Problemes identifies

1. **Monoculture des issues recentes.** `gh issue list` plafonne a `--limit N` retourne les N PLUS
   RECENTES issues. Si les 15/30 dernieres sont toutes `needs-approval` ou meta, l'agent conclut
   faussement « pool draine » alors que des dizaines de grains actionnables existent plus bas.
   Bug local documente : #2509 (`--limit 15` faux drain).

2. **Vocabulaire d'idle contournable.** Le test « idle-honnete » actuel repose sur des labels
   (`needs-approval`, `blocked-on-gate`, etc.). Un agent peut apprendre a les poser pour justifier
   l'idle sans avoir transforme de grain en PR. Le test doit etre sur le RESULTAT, pas le label.

3. **Lane = etiquette de reporting, pas frontiere de travail.** CoursIA R4 (coordinator-discipline)
   l'enonce explicitement : le pool est GLOBAL cross-lane, et le picker tire dedans sans prejudice
   de lane. Le regime « picker-first » du 20/08 cote CoursIA a valide l'approche.

4. **Cap IDLE 3 (#2185) ne suffit pas.** Sans test-resultat, l'agent peut declarer IDLE honnete
   meme quand le pool contient des grains ; le cap penalise la forme mais pas le fond.

## Decision

### 1. Picker 3 urnes ponderees — `scripts/scheduling/pick_idle_grain.py`

Le picker tire dans 3 urnes :

| Urne | Source | Label set | Poids par defaut |
|------|--------|-----------|------------------|
| `grain` | Issues actionnables | `approved`, `bug`, `investigation` | 7 |
| `umbrella` | Issues parentes/epics | `epic` | 2 |
| `delivered` | PRs ouvertes livrables (toutes — pas de lecture de verrou : une PR ouverte n'est pas encore un grain transforme) | (n/a) | 1 |

**Parametres :**
- `--limit 300` (defaut) : corrige #2509, echantillonne le backlog reel.
- Graine : par defaut **derivee de la machine et du creneau UTC** (`sha256(machine)[:8] ^ slot`,
  `slot = epoch_utc // 3600`) — deux lanes tirent des listes differentes sur le meme pool (#4103 ;
  la graine fixe 42 servait le meme grain a toutes les lanes). `--seed N` explicite pour la
  reproductibilite (tests) ; `--reroll` decale la graine d'un cran (compat). Jamais `hash()` :
  le hash Python d'une chaine est sale par processus (PYTHONHASHSEED).
- `--top K` (defaut 5) : liste ordonnee de K candidats distincts **tirés sans remise** selon les
  poids des urnes ; la lane parcourt la liste jusqu'au premier grain libre. Tous les K pris ->
  elargissement au pool entier dans l'ordre du tirage ; rien de libre -> verdict `ALL_CLAIMED`
  (exit 0, liste des ecarts et raisons) — ni `IDLE_REAL` ni `ERROR`.
- `--weights "grain:7,umbrella:2,delivered:1"` : override.
- Collecte **REST** une fois par depot (`gh api repos/{repo}/issues?state=open`, paginee) :
  issues ET PRs dans la meme reponse (une PR y porte la cle `pull_request`), les 3 urnes et le
  compteur `unlabelled_open` servis sans appel supplementaire. Le quota GraphQL, partage par
  toute la flotte, n'est plus consomme (#4103).
- Scan les 2 depots (anti-double-claim #3407) : `jsboige/roo-extensions` + `jsboige/jsboige-mcp-servers`.

**Fail-closed (reviews #3681, etendu #4103) :** toute panne instrument — gh exit non-nul, timeout,
JSON invalide, sur la collecte OU sur une verification de claim — rend un verdict `ERROR` avec
**exit 2**, jamais un verdict de fond. Un instrument muet ne peut pas declarer le pool vide, ni un
claim illisible passer pour un grain libre. Le stdout gh est decode en UTF-8 (`errors="replace"`) :
les titres accentues ne crashent plus le reader sous Windows cp1252.

**Sans filtre machine par flag — exclusion sur donnees qui EXISTENT (#4103) :** le champ Machine de
ce depot vit dans le Project #67 (fields), pas en labels ni assignees — un filtre local sur ce champ
ne matchera jamais (mesure po-2027 16/09), et le flag a ete SUPPRIME plutot qu'implemente a moitie
(section « Non-buts reaffirmes » ci-dessous, garde Pester). Le rework #4103 n'en reintroduit aucun : les exclusions du
picker s'appuient sur des donnees reellement presentes sur l'issue — le **verrou de claim** (ADR 017,
commentaires `[CLAIMED]`, peremption 24 h, logique reutilisee depuis `check_issue_claim.py`) et les
**etiquettes de lane `myia-*`** posees dans le depot. La difference est celle-ci : l'ancien filtre
cherchait une donnee absente ; la nouvelle exclusion lit des donnees existantes. La machine courante
vient de l'environnement (`COMPUTERNAME` en minuscules), jamais d'un flag. Le prefixe de titre
`[CLAUDE-<machine>]` n'est pas consulte : il designe la machine qui a cree l'issue, pas celle qui
doit la porter.

**Verdict IDLE-REAL :** declenche UNIQUEMENT si `grain + umbrella + delivered = 0` APRES collecte
reussie sur les 2 depots. Sinon PICK.

### 2. Test de fin de cycle — `scripts/scheduling/test_cycle_end.py`

Remplace « idle-honnete » (vocabulaire) par **test-resultat** (sortie).

```
verdict = PASS   si backlog_grain == 0 (urne grain REELLEMENT vide, collecte reussie)
        |  PASS   si prs_delivered_fleet > 0 dans la fenetre
        |  FAIL   sinon (echec de methode) → exit 1
        |  ERROR  si panne instrument gh (fail-closed) → exit 2
```

**Sortie :** exit 0 (PASS) / exit 1 (FAIL) / exit 2 (ERROR), JSON pour CI.

**Portee FLOTTE assumee (reviews #3681) :** les PRs comptees sont celles de toute la flotte sur les
2 depots. L'attribution par machine vit dans le Project #67 (champ Machine) et l'auteur gh est un
compte partage (`jsboige`) — un filtre par auteur ne distingue pas les lanes. Ce test est un signal
flotte ; la conformite de LA lane passe par la discipline `[CLAIMED]`/`[DONE]` dashboard. Le champ
de sortie s'appelle `prs_delivered_fleet` et le compteur backlog ne mesure QUE l'urne grain
(labels `approved`/`bug`/`investigation`) — le test ne rapporte que ce qu'il mesure.

**Autorite des verdicts (asymetrie documentee) :** le picker (`IDLE_REAL` = 3 urnes vides) est un
outil de SELECTION ; le test de fin de cycle (`PASS`-idle = grain==0 seul) est l'AUTORITE de fin de
cycle. En cas de divergence, c'est le test qui fait foi.

**Integration executor :** le SKILL.md executor gagne une section « Test de fin de cycle » qui
invoque le test avant de basculer sur le catalogue idle I1-I8. Si FAIL → l'agent doit reprendre
Phase 2 (relire le picker, prendre un grain reel).

### 3. Deep-queue par lane — pattern documente (non code)

Pour les lanes a mandate durable (ex. Vibe, myia-po-2025), la file est PRE-AUTORISEE par le
coordinateur : `outputs/vibe/feeder-queue.json` (gitignored) contient les grains tries par
priorite avec `baseSha`, `finding`, et `contract`. Le picker Vibe lit cette file directement
sans repasser par `gh issue list`.

**Rationale :** le pool global cross-lane (picker 3 urnes) coexiste avec les files locales
deep-queue par lane. La lane Vibe a un domaine precis (markdown table syntax) que le pool
global ne couvre pas.

**Non-but explicite :** ne PAS importer la cadence CoursIA (30 min cron vs 4 h schtask). Les
gardes #2185 (cap IDLE 3) et le re-arm cron/WAKE restent la cadence locale de roo-extensions.

## Consequences

### Positives

- **Anti-tarissement reel.** Le test-resultat bloque la sortie facile « idle honnete ».
- **Anti-monoculture.** `--limit 300` + 3 urnes elargit l'espace de recherche.
- **Reproductibilite.** `--seed` deterministe, `--reroll` pour explorer, `--json` pour CI.
- **Fail-closed.** Une panne gh (rate-limit GraphQL #3623, auth, reseau) se lit comme ERROR
  exit 2, jamais comme un pool vide.
- **Compatibilite ascendante.** Le picker est un outil, pas un remplacement du Phase 2 du SKILL.md.
  Les priorites 1-6 (instructions directes, Machine=*, TODO detaille, bug, in-progress) restent.

### Negatives / trade-offs

- **Cout `gh` API plus eleve.** `--limit 300` x 2 depots = 600 issues + 600 PRs par appel.
  Mitigation : cache local possible (futur), et le picker n'est PAS dans la boucle chaude
  du worker (1 fois par cycle).
- **Verdict FAIL peut surprendre.** Un agent peut se voir refuser IDLE alors qu'il pensait
  avoir respecte Phase 2. C'est le but — forcer la reflexion.
- **Test-resultat a portee flotte.** Une livraison d'une autre lane fait PASSER le test pour
  toutes — limite documentee, l'attribution fine exige le Project #67 (non implemente ici).

### Non-buts reaffirmes

- Pas de migration cadence CoursIA (30 min cron).
- Pas de modification `#2185` cap IDLE 3 (garde fleche, test-resultat s'y superpose).
- Pas de suppression des priorites 1-6 du Phase 2.
- Pas de requetage du Project #67 dans ces scripts v1 (le filtre `--machine` a ete SUPPRIME
  plutot qu'implemente a moitie : labels `machine:*` inexistants, mesure po-2027 16/09).

## Implementation

| Fichier | Role |
|---------|------|
| `scripts/scheduling/pick_idle_grain.py` | Picker 3 urnes (grain/umbrella/delivered), --limit 300, graine machine+creneau (#4103) ou --seed explicite, --top K sans remise, saut claims (ADR 017) + etiquettes myia-*, collecte REST, verdict ALL_CLAIMED, fail-closed ERROR exit 2 |
| `scripts/scheduling/test_cycle_end.py` | Test-resultat flotte : PASS si 0 backlog grain OU >0 livraison ; FAIL exit 1 ; ERROR exit 2 |
| `.claude/skills/executor/SKILL.md` | Sections picker + « Test de fin de cycle » : invoquer le test avant I1-I8 |
| `.claude/commands/executor.md` | Section picker : commande canonique et exemple sortie |
| `scripts/testing/python/test_lane_antitarissement.py` | Tests unitaires (unittest, mock subprocess) : pannes gh, UTF-8, verdicts/exit codes |
| `scripts/testing/unit/lane-antitarissement.Tests.ps1` | Garde Pester (contenu + invocation des tests Python) — câblée au job CI `unit-pester` |

## References

- CoursIA `proactive-coordination.md` (7 regles HARD), `coordinator-discipline.md` R4
- CoursIA `pick_idle_grain.py` (inspiration directe)
- Issue #2509 (bug `--limit 15` faux drain)
- Issue #2185 (cap IDLE 3 — reste en place)
- Issue #3111 (Epic convergence)
- Issue #3675 (candidat #2 de la phase 2, ce document)
- Issue #3676 (candidat #3 — claim sur issue GitHub, livre par po-2026 #3680, ADR 017)
- Issue #3678 (candidat #8 — alertes survivantes, lien cross-pollinisation)
- Reviews #3681 : ai-01 CHANGES_REQUESTED 15/09 23:12Z, po-2027 16/09 05:43Z (fail-open,
  cp1252, `--machine`, collision ADR 014 — corrigés dans le rework)
