# Archive — analyses `docs/roo-code/` d'octobre 2025

Snapshot **verbatim** de 5 fichiers de `docs/roo-code/`, écrits lors d'une **seule** session de
travail sur une PR « autosave draft » du message editor (sous-module `roo-code/`, référence seule).
Aucun n'a été retouché depuis, et aucun ne décrit l'état actuel du dépôt.

| Fichier | Origine | Âge au 08/11/2026 | Octets |
|---|---|---|---|
| `message-editor-fix-summary.md` | `docs/roo-code/` | 402 j | 5 999 |
| `message-editor-pr-guide.md` | `docs/roo-code/` | 402 j | 4 846 |
| `race-condition-manual-verification.md` | `docs/roo-code/` | 402 j | 7 748 |
| `send-message-flow-analysis.md` | `docs/roo-code/` | 402 j | 6 945 |
| `PARSING_XML_ASSISTANT_MESSAGES.md` | `docs/roo-code/` | 388 j | 44 |

## Pourquoi

Mesuré le 08/11/2026 (lane `myia-web1:roo-extensions`, cycle c.771) : sur les 18 fichiers `.md` de
`docs/roo-code/`, ces 5 sont les seuls à dépasser 365 jours **et** à n'avoir aucun consommateur.
`docs/INDEX.md` les déclarait tous « active » — un index qui ne vieillit pas avec son contenu.

## Preuve de préservation

- **Déplacements purs** : les 5 fichiers sont des `git mv` (renames 100 %, aucune ligne modifiée,
  rien supprimé).
- **Zéro consommateur hors index** : `git grep -F` sur les 4 chemins (`roo-code/message-editor`,
  `roo-code/race-condition`, `roo-code/send-message`, `roo-code/PARSING_XML`) → **0 hit** hors
  `docs/archive` et `docs/_archive`. La seule liste qui les citait était `docs/INDEX.md`, mis à
  jour dans le même commit.
- Les sous-modules ne consomment pas ces fichiers (ce sont des notes de session, pas de la spec).

## Cas particulier : `PARSING_XML_ASSISTANT_MESSAGES.md`

Le fichier ne contient **aucune** note de parsing XML. Contenu intégral (44 octets, commit
`f4ae8da7` du 2025-10-16, « chore: add missing files from phase 3b session ») :

```js
function hello() {
  console.log("world");
}
```

Un extrait de code égaré dans un `.md`, vraisemblablement ramassé par un `add` trop large. Il est
**conservé ici tel quel** plutôt que supprimé : sa présence dans l'archive documente le fait, et
supprimer un fichier du dépôt demande une preuve de préservation — l'archive la fournit.

## Décision

- **#2877** (Epic consolidation doc, sous-chantier W9 nouveau), lane `myia-web1:roo-extensions`,
  cycle c.771, 08/11/2026.
- Les 8 workstreams d'origine W1-W8 sont tous fermés ; ce lot est un **résidu neuf** trouvé par
  re-mesure de l'audit #2876 (07/2026), qui comptait 718 fichiers `.md` là où l'arbre en porte 779.

*Fichiers gelés : on ne répare pas les liens d'un snapshot (consolider ≠ archiver).*
