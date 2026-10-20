# No Deletion Without Proof + Surgical Changes

**Version:** 3.1.0 (garde outillé pré-suppression de tâches planifiées, #4097)
**MAJ:** 2026-10-20

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

## Tâches planifiées (schtasks) — la charge utile décide, pas le nom (#4097)

Suppression d'une tâche planifiée `Claude*` (ou assimilée) : **le nom ne suffit jamais**.
Deux audits (06/10, po-204 + po-203) ont supprimé des lanceurs protégés en se fiant au nom alors
que le `.vbs` embarquait `scripts/scheduling/start-*.ps1`. Avant tout `Unregister-ScheduledTask` /
`schtasks /delete` :

```powershell
powershell -ExecutionPolicy Bypass -File scripts\scheduling\check_scheduled_task_safe_to_delete.ps1 "<TaskName>"
```

- **`[REFUSED:PROTECTED]`** (exit 1) : une cible résolue vit sous `roo-extensions\scripts\scheduling\`
  — les **deux** séparateurs comptent, `\` comme `/` — lanceurs générés par `harden-hidden-tasks.ps1` :
  **ne pas supprimer**.
- **`[REFUSED:NO-BACKUP]`** (exit 1) : exiger l'XML pré-op dans `~\.roo-state-manager\preop-backup\`
  (la ligne `Export-ScheduledTask` est imprimée au refus).
- **`[INSTRUMENT]`** (exit 2) : tâche introuvable au jeton courant, lanceur illisible, **ou lanceur
  lu dont aucune cible script n'a pu être extraite** (contenu opaque : `-EncodedCommand`, chaîne
  `.cmd` sans chemin). « Lisible » n'est pas « compris » : un garde muet ne valide rien
  (« absent » en non-élevé n'est pas une mesure).
- **`[SAFE]`** (exit 0) : supprimable — la suppression elle-même reste un geste UAC discipliné
  (dry-run, règle `uac-dryrun-discipline`).

La liste d'exception n'est pas une liste de noms : c'est le **prédicat de charge utile**
(`roo-extensions\scripts\scheduling\`), aligné sur `harden-hidden-tasks.ps1` — un nouveau lanceur
généré est couvert sans mise à jour de liste.

## Deletion legitime

Fichier cree par erreur, feature abandonnee (documentee), migration avec forwarding 30 jours.
