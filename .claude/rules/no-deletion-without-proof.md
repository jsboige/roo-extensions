# No Deletion Without Proof + Surgical Changes

**Version:** 3.0.0 (adds surgical changes guard from #1936 Karpathy analysis)
**MAJ:** 2026-05-10

## Regle 1 : Pas de suppression sans preuve

**Aucun fichier ou fonction exporte ne peut etre supprime sans PREUVE de preservation.**

"Code mort" est un label dangereux. Le code peut etre : temporairement debranche, appele dynamiquement, ou un stub d'implementation cible.

## Regle 2 : Changements chirurgicaux (#1936)

**Chaque ligne modifiee doit pouvoir tracer directement a la demande utilisateur.** Ne pas "ameliorer" le code adjacent, ne pas refactorer au passage, ne pas ajouter des fonctionnalites non demandees.

**Pourquoi :** Les regressions viennent rarement du code demande — elles viennent des modifications non demandees "en passant". Incident type : context explosion 43% sur coverage tasks (#2083).

## Preuve requise

### Suppression de fichier
1. Equivalent fonctionnel (fichier/lignes de remplacement)
2. Migration des imports
3. Tests preserves
4. `git grep "old-name"` = zero resultats

### Suppression de fonction
1. `git grep "functionName"` = zero appelants
2. `git log -S "functionName" --since="30 days ago"` — si recent, probablement en cours
3. Verifier registres, dispatch tables, invocations dynamiques

## Prevention chaines circulaires (#815)

A importe B → B supprime ("consolide dans C") → A n'a plus d'importateurs → A supprime.
**Prevention :** Verifier si les importateurs ont ete supprimes recemment (30 jours). Si oui, le code N'EST PAS mort — il a ete debranche.

## Repertoires PROTEGES (approbation utilisateur obligatoire)

- `src/services/synthesis/` — Pipeline LLM (3 destructions)
- `src/services/narrative/` — Stubs = cibles d'IMPLEMENTATION

## Deletion legitime

Fichier cree par erreur, feature abandonnee (documentee), migration avec forwarding 30 jours.
