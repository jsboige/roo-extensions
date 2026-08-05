# Fermeture d'Issues — Regles Strictes

**Version:** 1.3.0 (slim)
**MAJ:** 2026-04-25

---

## Regle Absolue

**Une issue ne peut etre fermee que si le travail est REELLEMENT TERMINE.**

## Checklist avant fermeture

- Travail termine (pas "en cours" ni "partiel")
- Criteres d'acceptation remplis
- Si "superseded" : remplacement couvre TOUT
- Si "duplicate" : autre issue OUVERTE, meme scope exact
- Si "resolved by PR" : PR MERGE (pas juste cree), couvre tout le scope
- **Bloc Evidence** avec PR URL, commit SHA, ou user approval
- **Issue user-originated** : grille de marqueurs → si aucun marqueur agent, presumer user-originated → exiger confirmation humaine

## Hard Cap

**Max 3 fermetures/session** sans approbation utilisateur. Au-dela : poster `[ASK]` sur dashboard.

## Bloc Evidence (OBLIGATOIRE)

```markdown
## Evidence
- **PR merge** : URL (merged DATE)
- **Commit** : SHA (reachable from origin/main)
- **User approval** : comment by jsboige on DATE
- **Obsolete** : commit SHA + grep → 0 hits
- **Duplicate** : #MMM (ouverte, scope identique)
```

**Interdits :** "Resolved by recent improvements", "Superseded" sans ref, `[CLAIMED]` d'un agent.

## `gh issue close` n'est PAS la fermeture (#3033)

La commande retourne un succès **avant** que le bot de checklist ait statué. Le bot **rouvre** l'issue
~4 min plus tard si des cases restent décochées. Une session qui rapporte « fermée » sur le retour de
la commande rapporte donc régulièrement du faux.

1. **Cocher les cases AVANT** `gh issue close` — pas après, pas « je cocherai ensuite ».
2. **Relire l'état ≥ 5 min APRÈS** : `gh issue view N --json state,closedAt`.
3. Ne citer la fermeture dans un `[DONE]`, un bilan ou un décompte **qu'après** cette relecture.

Vaut aussi pour le décompte du hard cap : une issue rouverte par le bot n'a jamais été fermée.

## Interdictions

- JAMAIS "not planned" pour contourner le bot checklist
- JAMAIS fermer sur un CLAIM sans RESULT
- JAMAIS batch-close sans lire chaque issue
- JAMAIS commentaire generique copie-colle

## Qui peut fermer "won't fix" / "not planned" ?

**Uniquement** le coordinateur interactif avec approbation utilisateur, ou l'utilisateur directement.

---

**Grille marqueurs detaillee, test bash, audit /coordinate, historique :** [`docs/harness/reference/issue-closure-detailed.md`](../../docs/harness/reference/issue-closure-detailed.md)
