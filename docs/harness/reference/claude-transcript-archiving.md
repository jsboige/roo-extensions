# Archivage des transcripts Claude Code

**Créé :** 2026-08-28 · **Origine :** perte de données mesurée sur myia-ai-01

---

## Le défaut qui a motivé ce dispositif

Claude Code purge lui-même ses transcripts. En l'absence d'une clé `cleanupPeriodDays`
explicite dans `~/.claude/settings.json`, il supprime **tout ce qui dépasse 30 jours**, au
démarrage de chaque session, sans journal ni avertissement.

Mesure ai-01 du 2026-08-28 :

| | |
|---|---|
| `cleanupPeriodDays` | **absent** → défaut 30 j |
| JSONL le plus ancien survivant | **2026-07-29** (soit exactement 30 j) |
| Répertoires de projets vides | **387 sur 484** |
| Récupéré depuis les clichés VSS | 31 fichiers, 13,8 Mo, 26→29 juillet |

Les 31 fichiers récupérés ont été **remis en place** sous `~/.claude/projects` (dates de
modification d'origine rétablies) plutôt qu'archivés à part : ils sont ainsi couverts par
chaque passage suivant, et non par un geste unique que personne ne rejouerait.


**Et l'archivage existant ne couvrait pas ces fichiers.** `task-archive/` sur GDrive contient
**7 648 archives, 100 % `source: roo`, zéro Claude Code** (vérifié trois fois : `préfixe_claude=0`
par machine, `find -iname '*claude*'` = 0, 24 fichiers échantillonnés). L'index Qdrant conserve
des *chunks* interrogeables, pas les originaux.

Autrement dit : on archivait intégralement Roo, pas du tout Claude, et **rien ne l'a jamais
signalé**. C'est le défaut de fond documenté par l'Épic #3293.

## Ce que fait le script

[`scripts/backup/backup-claude-transcripts.ps1`](../../../scripts/backup/backup-claude-transcripts.ps1)

1. **Répare la rétention.** Si `cleanupPeriodDays` est absent ou `< 3650`, il est réécrit à
   `36500` (backup horodaté du fichier avant modification). C'est la garde qui manquait : la
   purge ne peut plus reprendre en silence.
2. **Archive le delta.** Les transcripts nouveaux ou modifiés depuis le dernier passage sont
   compressés dans `transcripts-<machine>-<horodatage>.7z`, vérifiés par `7z t`, puis copiés
   vers `G:\Mon Drive\Backups-Cloud\claude-transcripts\<machine>\`.
3. **Écrit un manifeste** local et distant : machine, rétention effective, nombre de transcripts
   suivis, date du plus ancien et du plus récent, dernière archive, et si l'envoi distant a
   réussi.

### Deux invariants

**Append-only.** Le script ne supprime, ne déplace et ne réécrit **jamais** rien sous
`~/.claude/projects`. C'est la différence délibérée avec `compress-captures.ps1` de claudish,
sur lequel il est modelé : les captures du proxy sont jetables une fois compressées, les
transcripts ne le sont pas.

**L'état n'avance qu'après vérification.** `state.json` n'est mis à jour qu'une fois l'archive
passée par `7z t`. Un échec de compression ou de vérification laisse l'état inchangé — le
prochain passage réessaiera le même delta. Un échec de copie GDrive laisse l'archive en local
et `shippedOffsite: false` dans le manifeste.

## Installation (par machine)

Le créneau **04:41** est décalé de celui de claudish (04:17) pour ne pas se disputer la fenêtre
d'upload GDrive, et évite l'heure ronde.

```powershell
$repo    = 'D:\roo-extensions'   # adapter au chemin local du dépôt
$ps      = (Get-Command pwsh.exe -EA SilentlyContinue).Source
if (-not $ps) { $ps = 'powershell.exe' }
$action  = New-ScheduledTaskAction -Execute $ps `
             -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$repo\scripts\backup\backup-claude-transcripts.ps1`""
$trigger = New-ScheduledTaskTrigger -Daily -At ([datetime]'04:41')
$set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd `
             -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
$princ   = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'ClaudeTranscriptArchive' -Action $action `
             -Trigger $trigger -Settings $set -Principal $princ -Force
```

Retrait : `Unregister-ScheduledTask -TaskName 'ClaudeTranscriptArchive' -Confirm:$false`

**Sur une machine où la purge n'a pas encore été corrigée, lancer le script une fois à la main
avant d'attendre le premier créneau** — chaque jour écoulé détruit une journée d'historique
supplémentaire.

## Vérifier la couverture — sans faire confiance au script

C'est le point qui distingue ce dispositif de celui qu'il remplace. La couverture flotte se lit
d'un coup, depuis n'importe quelle machine, dans les manifestes :

```powershell
Get-ChildItem 'G:\Mon Drive\Backups-Cloud\claude-transcripts' -Directory | ForEach-Object {
  $m = Join-Path $_.FullName 'manifest.json'
  if (Test-Path $m) { Get-Content $m -Raw | ConvertFrom-Json } else { [pscustomobject]@{ machine = $_.Name; retention = 'AUCUN MANIFESTE' } }
} | Format-Table machine, retention, transcriptsTracked, oldestTranscript, newestTranscript, shippedOffsite
```

**Trois signaux qui doivent déclencher une action :**

| Signal | Ce qu'il veut dire |
|---|---|
| `retention` ≠ `ok-36500` (ou `repaired-*`) | la purge est encore active, ou `settings.json` manque |
| `oldestTranscript` qui **avance** d'un passage à l'autre | des transcripts disparaissent malgré tout |
| `shippedOffsite: false` répété | GDrive inaccessible, les archives s'entassent en local |
| Machine **absente** du listing | le job n'y tourne pas — c'est le cas le plus dangereux, car il est silencieux |

Un manifeste absent n'est pas une machine saine : c'est une machine dont on ne sait rien.

## Restaurer

```powershell
& 'C:\Program Files\7-Zip\7z.exe' x 'transcripts-<machine>-<stamp>.7z' -o'<destination>'
```

Les chemins sont relatifs à `~/.claude/projects`, la hiérarchie par projet est préservée. En
cas de restauration multiple, extraire **par ordre chronologique croissant** : une session
active est archivée à chaque passage où elle a grandi, et la version la plus récente doit
gagner.

## Ce que ce dispositif ne couvre pas

- Les tâches **Roo/Zoo** — déjà couvertes par `task-archive/` (`roosync_indexing action:"archive"`).
- L'index sémantique **Qdrant** — sauvegarde distincte, voir [`docs/qdrant/backup-layer-1.md`](../../qdrant/backup-layer-1.md).
- Les captures du proxy **claudish** — `scripts/compress-captures.ps1` dans le dépôt claudish.

---

**Voir aussi :** Épic **#3293** (amnésie structurelle) · règle
[`no-deletion-without-proof`](../../../.claude/rules/no-deletion-without-proof.md)
