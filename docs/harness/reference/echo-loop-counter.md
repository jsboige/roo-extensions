# Hook `echo-loop-counter` — compteur log-only des boucles de tool_use identiques (#3724)

**Script :** [`scripts/hooks/echo-loop-counter.js`](../../../scripts/hooks/echo-loop-counter.js)
**Origine :** session Maintenance 17/09/2026 servie en DeepSeek Flash PAYG (4e fallback claudish) — issue #3724
**Statut :** option 3 (**compteur d'abord**) — re-scope user 23/09 (RX28 item 13) : « C'était un glitch Kimi je crois 3 en tout cas, on mesure et on verra »

---

## Ce que ça mesure

L'incident fondateur (VERIFIÉ via `conversation_browser`, compression 97,5 %) : une session headless
cron 12h est entrée en **boucle d'échos** — dizaines de tool_use `echo` quasi identiques
(`STOP-ECHO-LOOP-FINAL-NOW-REAL-16`, `HALT-ECHOES-FINAL-NOW-REAL-16`, …), chacun précédé de la même
annonce « J'arrête cette boucle d'échos » **sans jamais invoquer l'outil d'envoi annoncé**. La sortie
s'est faite par exit 1 accidentel, pas par une garde du harnais. ~160 k chars de contexte brûlés en PAYG.

**Ce hook ne corrige rien** — il rend le phénomène **mesurable** avant toute décision :

- compte les appels d'outil **consécutifs identiques** (même `tool_name` + `tool_input` normalisé,
  clé ordonnée, sha256) **par session** ;
- attribue chaque événement au **modèle servi** (dernier `"model":"…"` du transcript, lecture des
  64 derniers KB) — c'est le discriminateur demandé par le re-scope : si les boucles ne surviennent
  que sur les échelons de fallback faibles, le compteur le montrera ;
- journalise `threshold` quand une série atteint le seuil, puis `run-end` avec le décompte final
  quand la série s'arrête (signature change). **Un seul événement `threshold` par série** — pas de
  spam ligne par ligne.

La décision suivante (option 1, circuit breaker) n'est reconsidérée **que si** le compteur montre
plus d'un cas réel par mois.

## Contrat du script

| Entrée/Sortie | Comportement |
|---|---|
| stdin | payload JSON du PreToolUse — lit `session_id`, `transcript_path`, `tool_name`, `tool_input` |
| exit 0 | **TOUJOURS** — log-only par design (#3724) et fail-open (parse cassé, transcript absent, disque plein : rien ne casse, rien ne se bloque) |
| événement | append JSONL dans le log durable quand une série consécutive identique atteint le seuil, puis à sa fin |

- **Seuil :** `ECHO_LOOP_THRESHOLD` (env, défaut **5**).
- **Log :** `ECHO_LOOP_LOG` (env, défaut `~/.claude/echo-loop-counter.jsonl`) — **hors `$TEMP`**
  (rotation : le scratchpad #3828 de po-2023 a été balayé par la rotation `$TEMP`, 25/09).
- **État :** `$TMP/echo-loop-counter/<session_id>.json` — éphémère par design (perdre l'état d'une
  session morte ne coûte rien).
- `tool_input` normalisé par **clé triée récursive** : `{a:1,b:2}` ≡ `{b:2,a:1}` (les echoes de
  l'incident ne différaient que par le libellé — tout reste capté).

Format d'événement :

```json
{"ts":"…","session_id":"…","model":"…","tool_name":"Bash","phase":"threshold",
 "run":5,"threshold":5,"input_preview":"{\"command\":\"echo STOP-NOW\"}","log_path":"…"}
```

`phase` ∈ `threshold` (série qui franchit le seuil) / `run-end` (série terminée, `run` = total final).

## Rapport mensuel (la livraison du compteur)

Chaque lane qui arme le hook rapporte sur #3724, une fois par mois : nombre d'événements
`threshold`, décomptes `run-end`, répartition par `model`. **0 événement est un résultat** —
c'est la falsification de « plus d'un cas réel par mois », qui clôt la piste du circuit breaker.

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
- Adapter le chemin au clone local. Seuil personnalisé : variable d'environnement système
  `ECHO_LOOP_THRESHOLD` (défaut 5), log personnalisé : `ECHO_LOOP_LOG`.
- Après édition : **restart de la session** (les hooks se chargent au démarrage).
- Précédent d'interception : les hooks PreToolUse interceptent bien avant l'exécution
  ([pdf-read-guard](pdf-read-guard.md) § Statut d'interception, VÉRIFIÉ 11/09 sur Claude Code 2.1.41).

## Tests synthétiques (payloads directs — reproduits dans la PR)

Séquence de référence (session unique, entrée identique ×7 puis une entrée différente) :

```bash
H=scripts/hooks/echo-loop-counter.js
export ECHO_LOOP_LOG=$TMP/echo-test.jsonl; rm -f $ECHO_LOOP_LOG
P='{"session_id":"s-test","transcript_path":"'"$TMP/fake-transcript.jsonl"'","tool_name":"Bash","tool_input":{"command":"echo STOP-NOW-REAL-16"}}'
for i in 1 2 3 4 5 6 7; do echo "$P" | node $H || echo "FAIL exit=$?"; done
echo '{"session_id":"s-test","tool_name":"Bash","tool_input":{"command":"ls"}}' | node $H
cat $ECHO_LOOP_LOG
```

Attendu : exit 0 partout ; **exactement 2 lignes** de log — `threshold` (run 5) puis `run-end`
(run 7). Voir la PR pour les résultats réels, y compris : stdin invalide (exit 0, silencieux),
sessions indépendantes (états séparés), transcript absent (`model: "unknown"`).

## Limites connues (déclarées, pas corrigées)

- **« consécutifs » au niveau session, pas au niveau tour** : une série interrompue par un appel
  différent puis reprise est comptée comme deux séries. Simplification assumée — l'incident était
  une suite ininterrompue en fin de session.
- **Série terminée par la mort de la session** : l'événement `run-end` n'est jamais écrit (aucun
  appel ultérieur n'observe le changement de signature). L'événement `threshold` existe, avec le
  décompte au franchissement — borne inférieure du total réel.
- **`threshold` dédupliqué par série** : une série qui continue après le seuil ne re-log pas
  (le `run-end` porte le total).
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
