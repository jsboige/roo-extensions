# ADR 017: Claim locus — le verrou vit sur l'issue GitHub, le dashboard garde le récit

**Date :** 2026-09-15 (renummering 014→017 le 2026-09-16 : le 014 brièvement occupé par
le livrable #3675/#3681 pendant la revue croisée, renumeroté 016 à son merge — le 017
écarte toute re-collision sans reoccuper le numero historique)
**Status :** Accepted (GO user, 2026-09-15)
**Issue :** #3676 (livrable) — Epic #3111 phase 2, candidat #3
**Source :** Convergence ← CoursIA `lane-claim-protocol.md` (HARD) + `scripts/check_lane_claim.py`
**Related :** #3678 (candidat #8 — résilience canal), #3155 (outage GDrive 16/08), audit passe 2 (`docs/harness/reports/harness-convergence-audit-2026-08-17.md` §7 candidat #3), #1786 (incident fondateur roo-ext), incident CoursIA #10169 (tie-break), incident CoursIA #9774 (organe d'origine)

---

## Contexte

Le verrou anti-collision (claim) de roo-extensions vit aujourd'hui sur le **dashboard workspace**
(`agent-claim-discipline.md` v1.6 : `[CLAIMED]` sur `roosync_dashboard`). Trois défauts mesurés :

1. **Silo par lane** — chaque machine lit son dashboard ; le signal ne croise pas nativement les
   lanes (défaut fondateur de l'organe CoursIA, incident #9774 : deux livraisons du même travail
   alors que chaque worker avait passé son garde `gh pr list`, qui ne voit que le travail *poussé*).
2. **Auto-condensation du canal** — à 92 % (~46 KB), l'intercom est condensé par LLM : un
   `[CLAIMED]` peut disparaître du registre pendant la fenêtre critique
   « j'ai décidé de travailler sur X » → « j'ai poussé ».
3. **Mélange heure locale/UTC** — un stamp corporel `...Z` écrit en heure locale inverse
   l'ordering croisé (défaut 2 de #9774).

**Résilience outage (mesuré en live, 16/08, PR #3155)** : pendant la coupure GDrive (~15 min,
occurrence n°7+), CoursIA a conservé registre de verrous, pool de travail et capacité merge — tout
vit sur GitHub. roo-extensions a perdu commandement + claims + dispatch : le dashboard est un
**SPOF** partagé par l'essentiel des organes critiques.

CoursIA a résolu ces trois défauts en déplaçant le claim **sur l'issue GitHub** : locus cross-lane
par construction, `createdAt` serveur UTC (jamais un stamp de corps), organe de check
`check_lane_claim.py` exécutable avec `gh` seul. Côté roo-ext, l'organe MCP équivalent
(`roosync_claim`) est déjà déprécié (CONS-8 #603) et persistait lui aussi dans le shared-path
GDrive (`claims/active-claims.json`, `claim.tool.ts:96`) — le dashboard restait donc le seul
registre vivant, et le plus fragile.

## Décision

**Le verrou déménage sur l'issue ; le dashboard reste le canal de narration.**

1. **Claim = commentaire d'issue.** Forme canonique : ligne débutant par
   `[CLAIMED] <machine> — <intention en une ligne>`. Pas de timestamp dans le corps : le
   `createdAt` serveur fait foi. Levée : `[RELEASED]` (ou `[DONE]` à la livraison).
2. **Organe de check AVANT mutation** :
   ```bash
   python scripts/github/check_issue_claim.py <N>            # exit 1 si une AUTRE machine tient un claim actif
   python scripts/github/check_issue_claim.py <N> --claim "intention"   # pose le verrou
   python scripts/github/check_issue_claim.py <N> --release             # lève le verrou
   ```
   Validation par `createdAt` serveur uniquement ; péremption `--stale-threshold` (défaut 24 h) —
   un claim étranger plus vieux que le seuil ne bloque plus mais avertit (`STALE_CLAIM`) ; le
   nouveau claimant DOIT quand même poser son propre `[CLAIMED]` (pas de bypass silencieux).
   Défaut 24 h : intermédiaire entre le 48 h CoursIA (grains longs) et la convention 2 h du
   dashboard (canal qui se condense de toute façon) — ajustable par flag.
3. **Tie-break (HARD)** : un claim-issue **prime sur un claim-dashboard, même antérieur**.
   Incident fondateur CoursIA #10169 : 12 minutes d'avance perdues parce que deux locus se
   disputaient l'antériorité. Un seul locus fait foi : l'issue.
4. **Fail-closed** : un `[CLAIMED]` sans machine identifiable bloque (claim « sans propriétaire »)
   — on répare le marqueur, on ne l'ignore pas. Un marker cité en milieu de prose n'est PAS un
   événement (line-anchored, incident #10228 côté CoursIA) ; « dernier marqueur gagne » par
   machine.
5. **Migration par surface, pas de big-bang.** Surface couverte dès maintenant : la discipline
   pre-claim de `agent-claim-discipline.md` (tout travail rattaché à une issue GitHub). Le
   `[CLAIMED]` dashboard reste **bienvenu comme narration** ; il cesse d'être le registre de
   verrous.
6. **`roosync_claim` (MCP)** : déjà **deprecated** (CONS-8 #603, `registry.ts:795`) — organe mort
   dont le stockage vivait de toute façon dans le shared-path GDrive (`claims/active-claims.json`,
   `claim.tool.ts:96`) : même SPOF que le dashboard, et double registre. Sa notice de dépréciation
   (« Use dashboard `[CLAIMED]` tags ») est périmée par la présente décision — le message du
   registre devra pointer vers le locus issue lors de la prochaine PR submod touchant
   `registry.ts` (follow-up noté, hors périmètre #3676 : pas de bump submodule pour un message).

## Conséquences

- Le claim survit à un outage GDrive : pose, lecture et levée via GitHub uniquement.
- Le coût par claim est un `gh issue comment` + un check local (une commande) — inchangé par
  rapport au dashboard en nominal, disponible en dégradé.
- Le tie-break supprime l'ambiguïté dashboard-vs-issue ; les claims dashboard antérieurs au
  basculement ne font plus foi contre un claim-issue.
- `createdAt` serveur supprime la classe d'erreur « heure locale avec suffixe Z » par
  construction.

## Croisement candidat #8 — résilience du canal (#3678)

Le verrou hors GDrive est **la moitié** du gain d'outage : il garantit qu'aucune collision n'est
produite pendant la coupure. L'autre moitié est le **canal de commandement** (dispatch, alerte
survivante — #2875) : sans lui, les machines tournent mais sans coordination fraîche. Les deux
candidats sont complémentaires et se référencent mutuellement ; #3678 reste à traiter sur sa
propre surface.

## Non-buts / suivis hors périmètre

- **Fenêtre TOCTOU claim↔claim (réserve explicitée, review #3680)** : « check puis pose » n'est
  pas atomique — deux lanes peuvent passer le check dans la même seconde et poser chacune leur
  `[CLAIMED]`. Le tie-break reste le `createdAt` serveur des commentaires : le poster le plus
  tardif **rend la main** dès qu'il relit l'issue (le check de pre-delivery #3224 re-detecte le
  claim concurrent). Fermer la fenêtre par verrou atomique vrai exigerait une écriture
  conditionnelle que l'API commentaires GitHub n'expose pas ; la garde CI ci-dessous en serait
  le palliatif partiel. Non-corrigé par choix : la fenêtre est de l'ordre de la seconde, contre
  des cycles de plusieurs heures.
- **Garde CI** (équivalent `lane-claim-guard.yml` CoursIA, refus d'une PR sans claim-issue) :
  follow-up possible si dérive observée — ne pas l'imposer avant mesure.
- **Clause `paths:` fnmatch** (partitionnage multi-lanes par fichier) : non portée — roo-extensions
  partitionne par machine (une machine = un workspace), pas par fichier. À revisiter si une
  collision par fichier entre lanes apparaît.
- Le dashboard ne change pas pour le reste (narration, `[DONE]`, arbitrages) : voir
  `intercom-protocol.md`.

---

**Deciders :** jsboige (GO 2026-09-15), claude-interactive po-2026 (implémentation #3676)
