# Fermeture d'Issues — Regles Strictes

**Version:** 1.5.0 (slim 2 — gabarit Evidence + narratives bot relocalisés, #2368)
**MAJ:** 2026-09-26

---

## Regle Absolue

**Une issue ne peut etre fermee que si le travail est REELLEMENT TERMINE.**

## Checklist avant fermeture

- Travail termine (pas "en cours" ni "partiel")
- Criteres d'acceptation remplis
- Si "superseded" : remplacement couvre TOUT
- Si "duplicate" : autre issue OUVERTE, meme scope exact
- Si "resolved by PR" : PR MERGE (pas juste cree), couvre tout le scope
- **Bloc Evidence** avec PR URL, commit SHA, ou user approval — gabarit : doc detaillee
- **Issue user-originated** : grille de marqueurs → si aucun marqueur agent, presumer user-originated → exiger confirmation humaine

## Hard Cap

**Max 3 fermetures/session** sans approbation utilisateur. Au-dela : poster `[ASK]` sur dashboard.

## Bloc Evidence (OBLIGATOIRE)

Toute fermeture cite sa preuve : **PR merge** (URL + date) · **commit** SHA reachable depuis origin/main · **user approval** (comment + date) · **obsolete** (SHA + grep → 0 hits) · **duplicate** (#MMM ouverte, scope identique).

**Interdits :** "Resolved by recent improvements", "Superseded" sans ref, `[CLAIMED]` d'un agent.

## Fermer n'est pas fermé (#3033, #3225)

Le bot de checklist **rouvre** l'issue ~4 min plus tard si des cases restent décochées — pour les **deux** chemins de fermeture :

| Chemin | Ce qui rend « succès » tout de suite | Le bot statue |
|---|---|---|
| `gh issue close N` | le code de retour de la commande | ~4 min après |
| **un merge portant `Closes #NNN`** | **le merge de la PR** | ~4 min après, pareil |

1. **Cocher les cases AVANT** — avant le `gh issue close`, et avant le **merge** de la PR qui porte `Closes #NNN`. Pas après : au merge, le compte à rebours du bot a déjà commencé.
2. **Relire l'état ≥ 5 min APRÈS** : `gh issue view N --json state,closedAt`.
3. Ne citer la fermeture dans un `[DONE]`, un bilan ou un décompte **qu'après** cette relecture.

Après trois réouvertures la boucle du bot s'arrête (#1487) : une issue peut finir `CLOSED` avec checklist vide. Une issue rouverte par le bot **n'a jamais été fermée** — vaut aussi pour le décompte du hard cap.

## Interdictions

- JAMAIS "not planned" pour contourner le bot checklist
- JAMAIS fermer sur un CLAIM sans RESULT
- JAMAIS batch-close sans lire chaque issue
- JAMAIS commentaire generique copie-colle

## Qui peut fermer "won't fix" / "not planned" ?

**Uniquement** le coordinateur interactif avec approbation utilisateur, ou l'utilisateur directement.

---

**Grille marqueurs, gabarit Evidence, incidents fondateurs (#3216, #1487), test bash, audit /coordinate, historique :** [`docs/harness/reference/issue-closure-detailed.md`](../../docs/harness/reference/issue-closure-detailed.md)
