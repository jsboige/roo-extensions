# Hook log-tool-start — horodatage du début d'exécution (#4214 volet 3a)

**Script :** [`scripts/hooks/log-tool-start.js`](../../../scripts/hooks/log-tool-start.js)
**Issue :** #4214 (volet 3) — design [c.6204283891](https://github.com/jsboige/roo-extensions/issues/4214#issuecomment-6204283891)
**Créé :** 2026-10-16 (web1, pilote)

## Pourquoi

Le scanner [`scan-approval-waits.py`](../../../scripts/diagnostic/scan-approval-waits.py)
apparie chaque `tool_use` shell à son `tool_result` dans le transcript. Entre les deux il n'y a
aucune génération modèle, donc l'écart couvre **approbation + exécution + overhead client** sans
départage — un `npx vitest run` de 320 s est une exécution, pas une attente. Le volet 2 (corpus
headless, 231 findings, 0 `certain`) a borné le plateau ~600 s comme plafond d'exécution, mais la
zone grise en dessous reste indécidable **par transcript seul**.

Ce hook pose le marqueur manquant : l'instant où l'outil **commence** à tourner. La jointure
(volet 3b, option `--hook-log` du scanner — **livrée**) scinde l'écart en :

- `pre_exec_s` = tool_use → hook_ts (attente d'approbation + overhead)
- `exec_s` = hook_ts → tool_result (exécution réelle)

et étiquette chaque finding `adjudication: approval|exec` (l'exécution tient la majorité de
l'écart → `exec` ; sinon `approval`). La clé de jointure est `(session_id, tool, commande
brute)` + fenêtre `[tool_use, tool_use+gap_s]` — l'empreinte brute ne sort jamais de l'index,
seules les secondes calculées atteignent la sortie. Les entrées sans `session_id` sont
comptées (`hook_log_unscoped`), pas indexées.

```powershell
# Volet 3b — adjudication sur les findings du scanner
python scripts/diagnostic/scan-approval-waits.py --hook-log ~/.claude/tool-start-log.jsonl --min-wait 120
```

**Condition du dispatch c.28 (ai-01, 17/10) — contrôle positif AVANT toute conclusion.**
L'hypothèse « PreToolUse tire APRÈS l'approbation » n'est pas vérifiée : une commande
délibérément soumise à approbation doit montrer un `pre_exec_s` > 0 avant de conclure quoi
que ce soit d'un « pas de composante d'approbation ». Aucun verdict de mesure ne s'appuie
sur des données armées sans ce témoin.

## Contrat

| Entrée/sortie | Comportement |
|---|---|
| stdin | payload JSON du PreToolUse (`session_id`, `tool_name`, `tool_input`) |
| stdout / stderr | **rien** — un hook de log ne parle jamais au modèle |
| exit code | **0 TOUJOURS** — y compris sur payload non parsable ou échec d'écriture (fail-open par contrat : l'horodatage ne doit jamais bloquer ni retarder l'outil) |

Journal : `~/.claude/tool-start-log.jsonl` (surcharge `TOOL_START_LOG` pour tests), une ligne par
invocation d'outil shell :

```json
{"ts":"2026-10-16T07:30:00.123Z","session_id":"<id>","tool":"Bash","command":"npx vitest run"}
```

- **Outils journalisés :** `Bash`, `PowerShell`, `mcp__win-cli__execute_command`,
  `mcp__win-cli__ssh_execute` — les seuls que le scanner apparie ; les autres appels ne
  produiraient que du bruit pour la même taxe de spawn.
- **Rotation :** à 5 Mo (surcharge `TOOL_START_ROTATE_BYTES`) le fichier devient `.1` — une seule
  génération gardée, un pilote pluri-hebdomadaire ne croît pas sans borne.

## Confidentialité

La commande est stockée **brute** (l'empreinte exacte sert à la jointure) dans un fichier local du
profil — jamais publiée. La réduction de secrets s'applique à la **sortie du scanner**
(`redact()`, PR #4227 + follow-up #4228), pas à ce journal privé. Un pilote qui publie des
findings passe TOUJOURS par le scanner, jamais par un `cat` du JSONL.

## Câblage (déploiement = pilote web1 d'abord)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|PowerShell|mcp__win-cli__execute_command|mcp__win-cli__ssh_execute",
        "hooks": [{ "type": "command", "command": "node C:/dev/roo-extensions/scripts/hooks/log-tool-start.js" }]
      }
    ]
  }
}
```

**C'est un changement de harnais** : annoncer sur le dashboard workspace AVANT de l'armer sur un
siège. Taxe de spawn node mesurée ailleurs sur la flotte : ~100-300 ms par appel d'outil — le
pilote web1 mesure le coût réel (durée de cycle avant/après) avant toute extension. Si la taxe
s'avère rédhibitoire, le fallback est un échantillonnage (matcher restreint à `Bash` seul).

## Mesures attendues du pilote

1. Taxe réelle par cycle (durée moyenne des Bash tool_use avant/après armement).
2. Couverture de la jointure : % des findings du scanner qui trouvent un marqueur (fenêtre +
   empreinte commande) — cible ≥ 90 % sur un siège actif.
3. Décision : extension flotte, maintien pilote, ou arrêt (taxe > bénéfice).
