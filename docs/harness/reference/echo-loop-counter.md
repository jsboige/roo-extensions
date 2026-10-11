# Hook `echo-loop-counter` — compteur et disjoncteur des boucles de tool_use identiques (#3724)

**Script :** [`scripts/hooks/echo-loop-counter.js`](../../../scripts/hooks/echo-loop-counter.js)
**Tests :** [`scripts/hooks/tests/echo-loop-counter.test.js`](../../../scripts/hooks/tests/echo-loop-counter.test.js)
**Origine :** session Maintenance 17/09/2026 servie en DeepSeek Flash PAYG (4e fallback claudish) — issue #3724
**Statut :** option (b) — **disjoncteur**, seuil réglable. Décision user 11/10 : « oui, on ne peut pas accepter des boucles d'appels identiques ». La phase de mesure (option 3, compteur log-only, 23/09 → 11/10) a rendu son verdict : le phénomène n'est pas un glitch Kimi, il traverse au moins cinq modèles.

---

## Ce que ça mesure

L'incident fondateur (VERIFIÉ via `conversation_browser`, compression 97,5 %) : une session headless
cron 12h est entrée en **boucle d'échos** — dizaines de tool_use `echo` quasi identiques
(`STOP-ECHO-LOOP-FINAL-NOW-REAL-16`, `HALT-ECHOES-FINAL-NOW-REAL-16`, …), chacun précédé de la même
annonce « J'arrête cette boucle d'échos » **sans jamais invoquer l'outil d'envoi annoncé**. La sortie
s'est faite par exit 1 accidentel, pas par une garde du harnais. ~160 k chars de contexte brûlés en PAYG.

Le hook compte, attribue, journalise — **et coupe au-delà du seuil configuré** :

- compte les appels d'outil **consécutifs identiques** (même `tool_name` + `tool_input` normalisé,
  clé ordonnée, sha256) **par session** ;
- attribue chaque événement au **modèle servi** (dernier `"model":"…"` du transcript, lecture des
  64 derniers KB) — c'est le discriminateur du re-scope : si les boucles ne surviennent que sur les
  échelons de fallback faibles, le compteur le montre ;
- journalise `threshold` quand une série atteint le seuil de mesure, `blocked` quand le disjoncteur
  tire, puis `run-end` avec le décompte final quand la série s'arrête (signature change).
  **Un seul événement `threshold` et un seul `blocked` par série** — pas de spam ligne par ligne ;
- **refuse** l'appel (exit 2, message sur stderr) dès que la série atteint le seuil de blocage.

## La cause, par famille (relevés des sept sièges, 03/10 → 10/10)

Le re-scope du 23/09 pariait sur « un glitch Kimi ». Les relevés l'ont falsifié : les séries longues
viennent toutes des **marches de secours** — le phénomène est celui d'un modèle faible lâché dans le
harnais, pas celui d'un fournisseur.

| Famille | Exemples mesurés | Ce que fait le modèle |
|---|---|---|
| Chargement d'outil répété | `ToolSearch "noop"` 1 615× (po-2024, sous-agent claudish), `ToolSearch "select:…roosync_messages"` 380× et 373× (po-2027) | Il recharge un outil différé au lieu de l'appeler : il ne comprend pas qu'après le chargement l'outil est appelable par son nom. |
| Écriture retentée | `roosync_dashboard append` 80× (web1) | Il retente à l'aveugle un append qui a expiré, contre la règle « relire, jamais retenter ». |
| Appel MCP mal émis | commentaires Bash « I will now emit the MCP call directly » (web2) | Il essaie d'émettre l'appel MCP comme une commande shell. |
| Divers | `CronList {}` 91×, `echo` 95× | Il attend sans outil d'attente. |

**Presque toutes les séries viennent des marches de secours** (k3, kimi-for-coding, deepseek-flash,
glm). La plus longue série sur **Sonnet nominal fait 48** appels (po-2025) — c'est ce relevé qui fixe
le seuil par défaut à **60** : au-dessus de tout ce qu'un modèle nominal a produit d'observé, sous
tout runaway réel.

Le disjoncteur ne se contente pas de borner : le message de refus **dit quoi faire selon la famille**
(cf § Contrat), parce que le user a demandé de comprendre la cause, pas seulement de l'arrêter.

## Contrat du script

| Entrée/Sortie | Comportement |
|---|---|
| stdin | payload JSON du PreToolUse — lit `session_id`, `transcript_path`, `tool_name`, `tool_input` |
| stdout | rien |
| stderr | message de refus, **uniquement** quand le disjoncteur tire (remonté au modèle) |
| exit 0 | laisser passer — pour tout le comptage, **et fail-open** (parse cassé, transcript absent, disque plein : rien ne casse, rien ne se bloque) |
| exit 2 | **BLOCAGE** — la série atteint `ECHO_LOOP_BREAK_THRESHOLD` (même contrat que [`block-placeholder.js`](block-placeholder-hook.md) / [`pdf-read-guard`](pdf-read-guard.md)) |
| événement | append JSONL dans le log durable au franchissement du seuil de mesure, au premier refus de la série, puis à sa fin |

Le refus est écrit par `fs.writeSync(2, …)` et non `console.error` : `process.exit()` tronque les
écritures asynchrones sur un pipe, et c'est précisément cette ligne qui doit atteindre le modèle.

- **Seuil de mesure :** `ECHO_LOOP_THRESHOLD` (env, défaut **5**) — moment où la série est journalisée.
- **Seuil de blocage :** `ECHO_LOOP_BREAK_THRESHOLD` (env, défaut **60**) — moment où l'appel est refusé.
  **`0` = comptage seul** (comportement du 25/09, aucune valeur de blocage à zéro), le reste
  (négatif, non numérique) retombe sur le défaut.
- **Log :** `ECHO_LOOP_LOG` (env, défaut `~/.claude/echo-loop-counter.jsonl`) — **hors `$TEMP`**
  (rotation : le scratchpad #3828 de po-2023 a été balayé par la rotation `$TEMP`, 25/09).
- **État :** `$TMP/echo-loop-counter/<session_id>.json` — éphémère par design (perdre l'état d'une
  session morte ne coûte rien). Un état écrit par la version log-only (sans champ `blocked`) se
  relit sans erreur.
- `tool_input` normalisé par **clé triée récursive** : `{a:1,b:2}` ≡ `{b:2,a:1}` (les echoes de
  l'incident ne différaient que par le libellé — tout reste capté).

Message de refus, selon la famille détectée sur `tool_name` + `tool_input` :

| Famille | Détection | Consigne donnée au modèle |
|---|---|---|
| `toolsearch` | `tool_name` contient `ToolSearch` | l'outil est déjà chargé : l'appeler directement par son nom |
| `append` | `tool_name` contient `dashboard` et `tool_input.action == "append"` | relire le dashboard ; un append échoué se relit, il ne se retente pas à l'identique |
| `generic` | tout le reste | changer d'approche ou terminer le tour |

Format d'événement :

```json
{"ts":"…","session_id":"…","model":"…","tool_name":"Bash","phase":"threshold",
 "run":5,"threshold":5,"break_threshold":60,"input_preview":"{\"command\":\"echo STOP-NOW\"}","log_path":"…"}
{"ts":"…","session_id":"…","model":"…","tool_name":"ToolSearch","phase":"blocked","family":"toolsearch",
 "run":60,"threshold":5,"break_threshold":60,"input_preview":"{\"query\":\"noop\"}","log_path":"…"}
```

`phase` ∈ `threshold` (série qui franchit le seuil de mesure) / `blocked` (premier refus de la série,
avec la `family` détectée) / `run-end` (série terminée, `run` = total final). `break_threshold` est
porté par **tous** les événements : un relevé se relit sans deviner la configuration du siège.

## Rapport mensuel (la livraison du compteur)

Chaque lane qui arme le hook rapporte sur #3724, une fois par mois : nombre d'événements
`threshold`, nombre d'événements `blocked` (quelles familles, quels modèles), décomptes `run-end`,
répartition par `model`. **0 événement est un résultat** — c'est la falsification écrite de
« le phénomène n'existe pas sur ce siège ».

## Câblage (settings harness — [INTERACTIVE-ONLY] sur la machine hôte)

Dans le `~/.claude/settings.json` (harness de la machine, jamais dans le repo) :

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          { "type": "command",
            "command": "node \"c:\\dev\\roo-extensions\\scripts\\hooks\\echo-loop-counter.js\"" }
        ]
      }
    ]
  }
}
```

- **Matcher absent = tous les outils** (l'incident n'était pas spécifique à `echo` : toute paire
  outil/entrée répétée en boucle est la pathologie).
- Adapter le chemin au clone local. Seuils personnalisés par variable d'environnement système :
  `ECHO_LOOP_THRESHOLD` (défaut 5, mesure), `ECHO_LOOP_BREAK_THRESHOLD` (défaut 60, blocage ;
  `0` = comptage seul) ; log personnalisé : `ECHO_LOOP_LOG`.
- **Un siège qui veut le disjoncteur doit avoir un hook à jour** : une session vivante sert le
  script chargé à son démarrage. Un siège encore sur la version log-only du 25/09 continue de
  compter sans bloquer — c'est le comportement voulu tant que la PR n'est pas mergée et le
  re-démarrage pas fait.
- Après édition : **restart de la session** (les hooks se chargent au démarrage).
- Précédent d'interception : les hooks PreToolUse interceptent bien avant l'exécution
  ([pdf-read-guard](pdf-read-guard.md) § Statut d'interception, VÉRIFIÉ 11/09 sur Claude Code 2.1.41).

## Tests

```bash
node scripts/hooks/tests/echo-loop-counter.test.js    # exit 0 = tout vert
```

Sans dépendance (rien à ajouter à `package.json`) : le fichier spawne le hook avec des payloads
PreToolUse synthétiques et vérifie les codes de sortie, le contenu du refus et les événements
journalisés.

| Cas | Ce qui est vérifié |
|---|---|
| défaut | 59 appels `ToolSearch` identiques passent, le 60e est refusé (exit 2) avec la consigne `toolsearch` ; `threshold` (run 5) puis `blocked` (run 60, `family: toolsearch`) ; un appel différent passe et ferme la série (`run-end` run 60) |
| `append` | seuil abaissé à 3 → refus au 3e, message « relis le dashboard », `family: append` |
| générique | seuil abaissé à 3 → refus au 3e, message « change d'approche ou termine » |
| `0` | 70 appels identiques passent tous, aucun `blocked`, aucun stderr, la mesure reste active |
| fail-open | stdin illisible → exit 0, stderr vide |
| sessions | l'état d'une session ne bloque pas une autre session |

`ECHO_LOOP_LOG` est redirigé vers un répertoire temporaire par cas ; les états `$TMP` créés sont
supprimés en fin de run, fichier par fichier.

## Limites connues (déclarées, pas corrigées)

- **« consécutifs » au niveau session, pas au niveau tour** : une série interrompue par un appel
  différent puis reprise est comptée comme deux séries. Simplification assumée — l'incident était
  une suite ininterrompue en fin de session.
- **Série terminée par la mort de la session** : l'événement `run-end` n'est jamais écrit (aucun
  appel ultérieur n'observe le changement de signature). L'événement `threshold` existe, avec le
  décompte au franchissement — borne inférieure du total réel.
- **`threshold` et `blocked` dédupliqués par série** : une série qui continue après le seuil, ou
  après le refus, ne re-log pas (le `run-end` porte le total). Le **nombre de refus** n'est donc pas
  journalisé ligne par ligne — c'est voulu : un disjoncteur qui refuse 900 fois n'écrit pas 900
  lignes.
- **Le refus ne se ré-arme pas dans la série** : après un `blocked`, tout appel identique est refusé
  jusqu'à ce que la signature change. C'est ce qui garantit qu'un modèle qui insiste ne passe pas par
  épuisement — mais cela signifie aussi qu'un outil légitime appelé 60 fois à l'identique dans **une
  même session** serait refusé au 60e. Aucun relevé flotte ne montre un tel cas (le maximum légitime
  observé est très en deçà), et `ECHO_LOOP_BREAK_THRESHOLD` est là pour ça.
- **Ne voit que les ATTEMPTS PreToolUse** : un tool_use bloqué par un autre hook compte quand
  même — c'est voulu (la boucle de l'incident était faite de tentatives).
- **Attribution modèle = dernier modèle du transcript** : si la cascade claudish a basculé
  MID-BOUCLE, l'événement porte le modèle du dernier message avant l'appel courant — le plus
  souvent le bon (la bascule précède la boucle).

## Historique

| Date | Événement |
|---|---|
| 17/09 | Incident : session Maintenance en DeepSeek Flash PAYG, >=16 echoes, sortie par exit 1 |
| 18/09 | Découverte meta-analyste ; #3724 ouvert (VERIFIÉ via conversation_browser) |
| 23/09 | Re-scope user (RX28 item 13) : option 3, compteur log-only, mesure avant décision |
| 25/09 | Réattribué à po-2027 (dispatch ai-01 08:44Z, 0 activité du porteur initial) ; script + doc livrés |
| 27/09 → 05/10 | Armement opt-in par lane (po-2027, po-2026, web2, po-204, web1, po-2023, po-2025, ai-01) |
| 10/10 | Phase de mesure close : sept sièges ont relevé ; les séries longues sont toutes sur des marches de secours (1613, 380, 373, 273…), la plus longue sur Sonnet fait 48 |
| 11/10 | Décision user : **on bloque** (option b). Le compteur devient disjoncteur — `ECHO_LOOP_BREAK_THRESHOLD` (défaut 60, `0` = comptage seul), refus par famille, tests |
